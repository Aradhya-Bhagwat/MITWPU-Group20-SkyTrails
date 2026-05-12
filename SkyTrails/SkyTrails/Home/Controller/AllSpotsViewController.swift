
import UIKit
import CoreLocation

class AllSpotsViewController: UIViewController {
    
    var watchlistData: [PopularSpotResult] = []
    var recommendationsData: [PopularSpotResult] = []
    var userCoordinate: CLLocationCoordinate2D?
    private var isEBirdLoading = false
    private var cachedItemSize: NSCollectionLayoutSize?
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Explore Hotspots"
        setupTraitChangeHandling()
        applySemanticAppearance()
        setupCollectionView()
        fetchLiveHotspots()
    }


    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
        collectionView.reloadData()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }
    
    private func setupCollectionView() {
        collectionView.collectionViewLayout = createLayout()
        collectionView.register(
            UINib(nibName: GridSpotsToVisitCollectionViewCell.identifier, bundle: nil),
            forCellWithReuseIdentifier: GridSpotsToVisitCollectionViewCell.identifier
        )
        
        collectionView.register(
            UINib(nibName: "PredictionButtonCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: PredictionButtonCollectionViewCell.identifier
        )
        
        collectionView.register(
            UINib(nibName: "SectionHeaderCollectionReusableView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderCollectionReusableView.identifier
        )
        
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "LoadingCell")
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
    }

    private func applySemanticAppearance() {
        view.backgroundColor = .systemBackground
        collectionView?.backgroundColor = .clear
    }
    

        
    @objc private func didTapPredict() {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        if let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController {
            navigationController?.pushViewController(predictMapVC, animated: true)
        }
    }
    
    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            let containerWidth = layoutEnvironment.container.effectiveContentSize.width

            if self.cachedItemSize == nil {
                let padding: CGFloat = 16.0
                let spacing: CGFloat = 16.0
                let maxCardWidth: CGFloat = 300.0
                let minColumns = 2

                var columnCount = minColumns
                var calculatedWidth = (containerWidth - (spacing * CGFloat(columnCount - 1)) - (2 * padding)) / CGFloat(columnCount)
                
                while calculatedWidth > maxCardWidth {
                    columnCount += 1
                    calculatedWidth = (containerWidth - (spacing * CGFloat(columnCount - 1)) - (2 * padding)) / CGFloat(columnCount)
                }
                
                let heightMultiplier: CGFloat = 195.0 / 176.0
                let calculatedHeight = max(100, calculatedWidth * heightMultiplier)
    
                self.cachedItemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(max(50, calculatedWidth)),
                    heightDimension: .absolute(calculatedHeight)
                )
            }
            
            let fixedSize = self.cachedItemSize ?? NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .estimated(200))
            
            let itemWidth = fixedSize.widthDimension.dimension
            let interItemSpacing: CGFloat = 8
            let estimatedColumns = Int((containerWidth + interItemSpacing) / (itemWidth + interItemSpacing))
            let actualColumns = max(1, estimatedColumns)
            let groupItemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0/CGFloat(actualColumns)),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: groupItemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
            let groupHeight = fixedSize.heightDimension.dimension
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(groupHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 24, trailing: 8)
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(44))
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            return section
        }
    }

    private func fetchLiveHotspots() {
        guard let coord = userCoordinate else { return }
        isEBirdLoading = true
        collectionView.reloadSections(IndexSet(integer: 1))
        
        let existingIds = recommendationsData.compactMap { $0.hotspotId }
        
        Task {
            do {
                let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
                async let liveRequest = SkyTrailsAPIService.shared.fetchLiveHotspots(
                    lat: coord.latitude,
                    lon: coord.longitude,
                    existingIds: existingIds
                )
                async let regionalRequest = SkyTrailsAPIService.shared.fetchRegionalTrends(
                    lat: coord.latitude,
                    lon: coord.longitude,
                    week: currentWeek
                )

                let live = try await liveRequest
                let regionalSpecies = (try? await regionalRequest) ?? []
                let preliminarySpecies = Self.edgeSpecies(from: regionalSpecies, week: currentWeek)

                await MainActor.run {
                    self.isEBirdLoading = false
                    let mapped = live.map { h in
                        PopularSpotResult(
                            id: UUID(),
                            title: h.name,
                            location: h.name,
                            latitude: h.lat,
                            longitude: h.lon,
                            speciesCount: h.checklistCount,
                            observedCount: 0,
                            radius: 2.0,
                            imageName: nil,
                            edgeSpecies: preliminarySpecies,
                            hotspotId: h.hotspotId
                        )
                    }
                    self.recommendationsData.append(contentsOf: mapped)
                    self.collectionView.reloadSections(IndexSet(integer: 1))
                }
            } catch {
                await MainActor.run {
                    self.isEBirdLoading = false
                    self.collectionView.reloadSections(IndexSet(integer: 1))
                }
            }
        }
    }

    private static func edgeSpecies(from trendItems: [RegionalTrendSpeciesItem], week: Int) -> [NearbyHotspotEdgeSpecies] {
        let weekText = "Week \(week)"
        return trendItems.prefix(50).map { item in
            NearbyHotspotEdgeSpecies(
                commonName: item.name,
                scientificName: nil,
                imageName: WatchlistManager.shared.findBird(byName: item.name)?.staticImageName,
                probability: max(1, min(99, Int((item.score * 100).rounded()))),
                weekNumber: weekText,
                residencyStatus: "Expected",
                ebirdSpeciesCode: item.id
            )
        }
    }

    @discardableResult
    private func navigateToSpotDetails(
        name: String,
        lat: Double,
        lon: Double,
        radius: Double,
        predictions: [FinalPredictionResult]
    ) -> PredictMapViewController? {
        var inputData = PredictionInputData()
        inputData.locationName = name
        inputData.latitude = lat
        inputData.longitude = lon
        inputData.areaValue = Int(radius)
        inputData.startDate = Date()
        inputData.endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())

        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let predictMapVC = storyboard.instantiateViewController(withIdentifier: "PredictMapViewController") as? PredictMapViewController else {
            return nil
        }

        navigationController?.pushViewController(predictMapVC, animated: true)
        predictMapVC.loadViewIfNeeded()
        predictMapVC.navigateToOutput(inputs: [inputData], predictions: predictions)
        return predictMapVC
    }
}

extension AllSpotsViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return watchlistData.count + 1 }
        else { return recommendationsData.count + (isEBirdLoading ? 1 : 0) }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 && indexPath.row == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PredictionButtonCollectionViewCell.identifier,
                for: indexPath
            ) as? PredictionButtonCollectionViewCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: UIImage(named: "upcomingspots"), title: "Find Your Spots")

            return cell
        }
        
        if indexPath.section == 1 && indexPath.row == recommendationsData.count && isEBirdLoading {
            return createLoadingCell(for: indexPath)
        }

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GridSpotsToVisitCollectionViewCell.identifier,
            for: indexPath
        ) as? GridSpotsToVisitCollectionViewCell else {
            return UICollectionViewCell()
        }

        let item = (indexPath.section == 0) ? watchlistData[indexPath.row - 1] : recommendationsData[indexPath.row]
        
        cell.configure(
            image: UIImage(named: item.imageName ?? "placeholder_image"),
            imageName: item.imageName,
            title: item.title,
            speciesCount: item.speciesCount,
            latitude: item.latitude,
            longitude: item.longitude
        )

        
        return cell
    }
    
    private func createLoadingCell(for indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LoadingCell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
        spinner.startAnimating()
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderCollectionReusableView.identifier, for: indexPath) as? SectionHeaderCollectionReusableView else {
            return UICollectionReusableView()
        }
        
        if indexPath.section == 0 {
            header.isHidden = watchlistData.isEmpty
            header.configure(title: "Your Saved Spots")
        } else {
            header.isHidden = false
            header.configure(title: "Trending Hotspots")
        }
        return header
    }
}

extension AllSpotsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row == 0 {
            didTapPredict()
            return
        }
        if indexPath.section == 1 && indexPath.row >= recommendationsData.count {
            return
        }

        let item = (indexPath.section == 0) ? watchlistData[indexPath.row - 1] : recommendationsData[indexPath.row]

        let lat = item.latitude
        let lon = item.longitude

        let initialPredictions: [FinalPredictionResult]
        if let edgeSpecies = item.edgeSpecies, !edgeSpecies.isEmpty {
            initialPredictions = HomeManager.shared.predictionResults(
                from: edgeSpecies,
                lat: lat,
                lon: lon
            )
        } else {
            initialPredictions = []
        }

        let mapVC = navigateToSpotDetails(
            name: item.title,
            lat: lat,
            lon: lon,
            radius: item.radius,
            predictions: initialPredictions
        )

        Task { @MainActor [weak mapVC] in
            let outputVC = mapVC?.children.first?.children.first as? PredictOutputViewController
            outputVC?.showUpdatingBanner()

            let predictions = await HomeManager.shared.getSpeciesForHotspot(
                lat: lat,
                lon: lon,
                hotspotId: item.hotspotId
            )
            
            if !predictions.isEmpty {
                mapVC?.refreshOutputPredictions(predictions)
            }
            
            outputVC?.hideUpdatingBanner()
        }
    }
}
