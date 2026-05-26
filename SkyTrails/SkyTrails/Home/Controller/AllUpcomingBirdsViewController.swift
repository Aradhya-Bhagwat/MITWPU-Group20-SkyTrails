
import UIKit

class AllUpcomingBirdsViewController: UIViewController {
    
    var watchlistData: [UpcomingBirdUI] = []
    var recommendationsData: [RecommendedBirdResult] = []
    
    private var cachedItemSize: NSCollectionLayoutSize?
        
    @IBOutlet weak var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "This Week's Species"
        setupTraitChangeHandling()
        applySemanticAppearance()
        setupCollectionView()
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
    
    private func setupCollectionView() {
        collectionView.collectionViewLayout = createLayout()
        
        collectionView.register(
            UINib(nibName: "GridUpcomingGridCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: GridUpcomingGridCollectionViewCell.identifier
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
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
    }

    private func applySemanticAppearance() {
        view.backgroundColor = .systemBackground
        collectionView?.backgroundColor = .clear
    }


            
    @objc private func didTapPredict() {
        let storyboard = UIStoryboard(name: "Birdspred", bundle: nil)
        guard let selectionVC = storyboard.instantiateViewController(withIdentifier: "BirdSelectionViewController") as? BirdSelectionViewController else {
            return
        }
        
        let allSpeciesData = WatchlistManager.shared.fetchAllBirds()
        selectionVC.allSpecies = allSpeciesData.map {
            SpeciesData(
                id: $0.bird_id.uuidString, 
                name: $0.commonName, 
                imageName: $0.imageUrl ?? $0.staticImageName,
                ebirdSpeciesCode: $0.ebird_species_code
            )
        }
        let watchlistTitles = watchlistData.map { $0.title }
        let preSelectedIDs = allSpeciesData.filter { watchlistTitles.contains($0.commonName) }.map { $0.bird_id.uuidString }
        selectionVC.selectedSpecies = Set(preSelectedIDs)
        navigationController?.pushViewController(selectionVC, animated: true)
    }
        
    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
        
            let containerWidth = layoutEnvironment.container.effectiveContentSize.width
            if self.cachedItemSize == nil {
                guard let windowScene = self.view.window?.windowScene else { return nil }
                let screenBounds = windowScene.screen.bounds
                let portraitWidth = min(screenBounds.width, screenBounds.height)
                let padding: CGFloat = 16.0
                let spacing: CGFloat = 16.0
                let maxCardWidth: CGFloat = 300.0
                let minColumns = 2
        
                var columnCount = minColumns
                var calculatedWidth = (portraitWidth - (spacing * CGFloat(columnCount - 1)) - (2 * padding)) / CGFloat(columnCount)
                
                while calculatedWidth > maxCardWidth {
                    columnCount += 1
                    calculatedWidth = (portraitWidth - (spacing * CGFloat(columnCount - 1)) - (2 * padding)) / CGFloat(columnCount)
                }
                
                let heightMultiplier: CGFloat = 91.0 / 88.0
                let calculatedHeight = calculatedWidth * heightMultiplier
                self.cachedItemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(calculatedWidth),
                    heightDimension: .absolute(calculatedHeight)
                )
            }
            guard let fixedSize = self.cachedItemSize else { return nil }
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
}

extension AllUpcomingBirdsViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return watchlistData.count + 1 }
        else { return recommendationsData.count }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 && indexPath.row == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PredictionButtonCollectionViewCell.identifier,
                for: indexPath
            ) as? PredictionButtonCollectionViewCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: UIImage(named: "custom.curvepath.magnifying"), title: "Predict Migrations")

            return cell
        }
            
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GridUpcomingGridCollectionViewCell.identifier,
            for: indexPath
        ) as? GridUpcomingGridCollectionViewCell else {
            return UICollectionViewCell()
        }

        if indexPath.section == 0 {
            let item = watchlistData[indexPath.row - 1]
            let upcomingBird = UpcomingBird(
                imageName: item.imageName,
                title: item.title,
                date: item.date
            )
            cell.configure(with: upcomingBird)
        } else {
            let result = recommendationsData[indexPath.row]
            let upcomingBird = UpcomingBird(
                imageName: result.bird.staticImageName,
                title: result.bird.commonName,
                date: result.dateRange
            )
            cell.configure(with: upcomingBird)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderCollectionReusableView.identifier,
                for: indexPath
              ) as? SectionHeaderCollectionReusableView else {
            return UICollectionReusableView()
        }
        
        if indexPath.section == 0 {
            header.isHidden = watchlistData.isEmpty
            header.configure(title: "This Week's Species")
        } else {
            header.isHidden = false
            header.configure(title: "Discover New Birds")
        }
        return header
    }
}

extension AllUpcomingBirdsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row == 0 {
            didTapPredict()
            return
        }

        let storyboard = UIStoryboard(name: "Birdspred", bundle: nil)
        let bird: Bird
        let dateString: String

        if indexPath.section == 0 {
            let item = watchlistData[indexPath.row - 1]
            bird = WatchlistManager.shared.findBird(byName: item.title) ?? WatchlistManager.shared.fetchAllBirds().first!
            dateString = item.date
        } else {
            let result = recommendationsData[indexPath.row]
            bird = result.bird
            dateString = result.dateRange
        }

        let (parsedStart, parsedEnd) = HomeManager.shared.parseDateRange(dateString)
        let finalStart = parsedStart ?? Date()
        let finalEnd = parsedEnd ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: finalStart) ?? finalStart

        let input = BirdDateInput(
            species: SpeciesData(
                id: bird.bird_id.uuidString, 
                name: bird.commonName, 
                imageName: bird.imageUrl ?? bird.staticImageName,
                ebirdSpeciesCode: bird.ebird_species_code
            ),
            startDate: finalStart,
            endDate: finalEnd
        )
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? BirdspredViewController {
            mapVC.predictionInputs = [input]
            self.navigationController?.pushViewController(mapVC, animated: true)
        }
    }
}
