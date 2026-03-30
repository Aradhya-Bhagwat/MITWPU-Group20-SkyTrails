
import UIKit
import CoreLocation
import MapKit

protocol ModalSheetHeightAware: AnyObject {
    func updateVisibleSheetHeight(_ height: CGFloat)
}

class PredictOutputViewController: UIViewController {
    var predictions: [FinalPredictionResult] = []
    var inputData: [PredictionInputData] = []

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var selectedLocationNameLabel: UILabel!
    @IBOutlet weak var selectedLocationDetailLabel: UILabel!

    private var displayedPredictions: [FinalPredictionResult] = []
    private var yearlySeriesByBird: [String: [Int]] = [:]
    private var selectedPredictionIndex: Int = 0
    private var headerLocationRequestID: UUID?
    private var dynamicCollectionHeightConstraint: NSLayoutConstraint?
    private var fixedCollectionHeightConstraint: NSLayoutConstraint?
    private var latestVisibleSheetHeight: CGFloat?
    private let watchlistManager = WatchlistManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()
        applySemanticAppearance()

        setupNavigation()
        prepareData()
        setupCollectionView()
        updateLocationHeader(forDisplayedPredictionAt: selectedPredictionIndex)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionHeightForCurrentSheetPosition()
        updateHeaderLabelTypography()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Auto-select and show the map for the first bird
        if let first = displayedPredictions.first {
            if let mapVC = navigationController?.parent as? PredictMapViewController {
                mapVC.filterMapForBird(first)
            }
        }
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        applySemanticAppearance()
        updateHeaderLabelTypography()
        collectionView?.reloadData()
    }

    private func prepareData() {
        displayedPredictions = predictions.sorted { lhs, rhs in
            if lhs.spottingProbability == rhs.spottingProbability {
                return lhs.birdName < rhs.birdName
            }
            return lhs.spottingProbability > rhs.spottingProbability
        }

        for prediction in displayedPredictions {
            guard yearlySeriesByBird[prediction.birdName] == nil else { continue }
            yearlySeriesByBird[prediction.birdName] = yearlySeries(for: prediction)
        }
    }

    private func setupNavigation() {
        navigationItem.title = "Prediction Results"
        let redoButton = UIBarButtonItem(title: "Redo", style: .plain, target: self, action: #selector(didTapRedo))
        navigationItem.rightBarButtonItem = redoButton
        navigationItem.leftBarButtonItem = nil
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColor = .clear
        collectionView.decelerationRate = .normal
        collectionView.showsVerticalScrollIndicator = true
        collectionView.register(
            UINib(
                nibName: spotsToVisitOutputCollectionViewCell.identifier,
                bundle: Bundle(for: spotsToVisitOutputCollectionViewCell.self)
            ),
            forCellWithReuseIdentifier: spotsToVisitOutputCollectionViewCell.identifier
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        configureDynamicCollectionHeightIfNeeded()
    }

    private func configureDynamicCollectionHeightIfNeeded() {
        guard fixedCollectionHeightConstraint == nil else { return }

        fixedCollectionHeightConstraint = view.constraints.first(where: { constraint in
            guard constraint.firstItem as? UIView === collectionView else { return false }
            return constraint.firstAttribute == .height
        })
        fixedCollectionHeightConstraint?.isActive = false

        let dynamic = collectionView.heightAnchor.constraint(equalToConstant: 200)
        dynamic.priority = .required
        dynamic.isActive = true
        dynamicCollectionHeightConstraint = dynamic
    }

    private func updateCollectionHeightForCurrentSheetPosition() {
        configureDynamicCollectionHeightIfNeeded()
        guard let dynamicCollectionHeightConstraint else { return }

        let visibleSheetHeight = latestVisibleSheetHeight ?? view.bounds.height
        let topY = collectionView.frame.minY
        let bottomInset = view.safeAreaInsets.bottom
        let available = visibleSheetHeight - topY - bottomInset
        let newHeight = max(120, floor(available))
        guard abs(dynamicCollectionHeightConstraint.constant - newHeight) > 0.5 else { return }
        dynamicCollectionHeightConstraint.constant = newHeight
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func applySemanticAppearance() {
        view.backgroundColor = .systemBackground
        collectionView?.backgroundColor = .clear
        navigationItem.rightBarButtonItem?.tintColor = .systemBlue
    }

    @objc private func didTapRedo() {
        if let mapVC = self.navigationController?.parent as? PredictMapViewController {
            mapVC.revertToInputScreen(with: inputData)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    private func yearlySeries(for prediction: FinalPredictionResult) -> [Int] {
        let location = CLLocationCoordinate2D(
            latitude: prediction.matchedLocation.lat,
            longitude: prediction.matchedLocation.lon
        )
        return HomeManager.shared.yearlySightabilitySeries(
            forBirdNamed: prediction.birdName,
            near: location
        )
    }

    private func updateLocationHeader(forDisplayedPredictionAt index: Int) {
        guard displayedPredictions.indices.contains(index) else {
            selectedLocationNameLabel.text = "Search Location"
            selectedLocationDetailLabel.text = nil
            return
        }

        let prediction = displayedPredictions[index]
        let inputIndex = prediction.matchedInputIndex
        let input = inputData.indices.contains(inputIndex) ? inputData[inputIndex] : nil
        selectedLocationNameLabel.text = input?.locationName ?? "Search Location"
        if let detail = input?.locationDetail, !detail.isEmpty {
            selectedLocationDetailLabel.text = detail
            return
        }

        guard let lat = input?.latitude, let lon = input?.longitude else {
            selectedLocationDetailLabel.text = nil
            return
        }

        selectedLocationDetailLabel.text = nil
        let requestID = UUID()
        headerLocationRequestID = requestID
        let location = CLLocation(latitude: lat, longitude: lon)
        Task {
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else { return }
                let mapItems = try await request.mapItems
                
                await MainActor.run {
                    guard self.headerLocationRequestID == requestID else { return }
                    guard let mapItem = mapItems.first else { return }
                    
                    // Resilient extraction strategy: Using addressRepresentations for city, but sticking to placemark for state/country for now.
                    let city = mapItem.addressRepresentations?.cityName ?? mapItem.placemark.locality ?? mapItem.placemark.subLocality
                    let state = mapItem.placemark.administrativeArea
                    let name = mapItem.name ?? ""
                    
                    if let city, let state, !city.isEmpty, !state.isEmpty {
                        self.selectedLocationDetailLabel.text = "\(city), \(state)"
                    } else if let city, !city.isEmpty {
                        self.selectedLocationDetailLabel.text = city
                    } else if !name.isEmpty {
                        self.selectedLocationDetailLabel.text = name
                    } else {
                        self.selectedLocationDetailLabel.text = mapItem.placemark.country
                    }
                }
            } catch {
            }
        }
    }

    private func updateHeaderLabelTypography() {
        let containerHeight = max(1, view.bounds.height)
        let heightRatio = containerHeight / 874.0

        let titleSize = max(17, 17 * heightRatio)
        let subtitleSize = max(12, 12 * heightRatio)

        selectedLocationNameLabel.font = .systemFont(ofSize: titleSize, weight: .bold)
        selectedLocationDetailLabel.font = .systemFont(ofSize: subtitleSize, weight: .regular)
    }

    private func navigateToBirdPrediction(_ prediction: FinalPredictionResult) {
        let inputIndex = prediction.matchedInputIndex
        let input = inputData.indices.contains(inputIndex) ? inputData[inputIndex] : nil
        
        let startDate = input?.startDate ?? Date()
        let endDate = input?.endDate ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: startDate) ?? startDate
        let birdID = WatchlistManager.shared.findBird(byName: prediction.birdName)?.bird_id.uuidString ?? UUID().uuidString
        
        let birdInput = BirdDateInput(
            species: SpeciesData(id: birdID, name: prediction.birdName, imageName: prediction.imageName),
            startDate: startDate,
            endDate: endDate
        )

        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? birdspredViewController {
            mapVC.predictionInputs = [birdInput]
            if let mainNav = self.navigationController?.parent?.navigationController {
                mainNav.pushViewController(mapVC, animated: true)
            } else {
                self.navigationController?.pushViewController(mapVC, animated: true)
            }
        }
    }

    private func addToWatchlist(_ prediction: FinalPredictionResult) {
        guard let bird = watchlistManager.findBird(byName: prediction.birdName) else {
            let alert = UIAlertController(title: "Error", message: "Could not find bird in database.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let existingWatchlistIds = watchlistIdsContainingBird(birdId: bird.bird_id)
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(withIdentifier: "UnobservedDetailViewController") as? UnobservedDetailViewController else {
            return
        }

        detailVC.bird = bird
        detailVC.shouldUseRuleMatching = true
        detailVC.watchlistId = nil
        detailVC.onSave = { [weak self] savedBird in
            guard let self else { return }
            let targetWatchlistId = self.resolveDestinationWatchlistId(
                for: savedBird.bird_id,
                existingWatchlistIds: existingWatchlistIds
            )
            self.dismiss(animated: true) { [weak self] in
                self?.navigateToWatchlist(with: targetWatchlistId)
            }
        }

        let modalNav = UINavigationController(rootViewController: detailVC)
        detailVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissPresentedDetail)
        )
        modalNav.modalPresentationStyle = .automatic
        present(modalNav, animated: true)
    }

    @objc
    private func dismissPresentedDetail() {
        presentedViewController?.dismiss(animated: true)
    }

    private func watchlistIdsContainingBird(birdId: UUID) -> Set<UUID> {
        guard let watchlists = try? watchlistManager.fetchWatchlists(type: .custom) else { return [] }
        var ids = Set<UUID>()
        for watchlist in watchlists {
            if (try? watchlistManager.findEntry(birdId: birdId, watchlistId: watchlist.watchlist_id)) != nil {
                ids.insert(watchlist.watchlist_id)
            }
        }
        return ids
    }

    private func resolveDestinationWatchlistId(for birdId: UUID, existingWatchlistIds: Set<UUID>) -> UUID? {
        let updatedWatchlistIds = watchlistIdsContainingBird(birdId: birdId)
        if let newWatchlistId = updatedWatchlistIds.subtracting(existingWatchlistIds).first {
            return newWatchlistId
        }
        return updatedWatchlistIds.first
    }

    private func navigateToWatchlist(with watchlistId: UUID?) {
        guard
            let tabBarController,
            let viewControllers = tabBarController.viewControllers,
            viewControllers.indices.contains(1),
            let watchlistNav = viewControllers[1] as? UINavigationController
        else { return }
        let isCurrentlyOnWatchlistTab = tabBarController.selectedIndex == 1

        guard
            let watchlistId,
            let watchlist = try? watchlistManager.getWatchlist(by: watchlistId)
        else {
            if isCurrentlyOnWatchlistTab {
                watchlistNav.popToRootViewController(animated: true)
            }
            return
        }

        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let smartVC = storyboard.instantiateViewController(withIdentifier: "SmartWatchlistViewController") as? SmartWatchlistViewController else {
            if isCurrentlyOnWatchlistTab {
                watchlistNav.popToRootViewController(animated: true)
            }
            return
        }

        smartVC.watchlistType = (watchlist.type == .shared) ? .shared : .custom
        smartVC.watchlistTitle = watchlist.title ?? "Watchlist"
        smartVC.currentWatchlistId = watchlistId
        
        if isCurrentlyOnWatchlistTab {
            tabBarController.selectedIndex = 1
            watchlistNav.popToRootViewController(animated: false)
            watchlistNav.pushViewController(smartVC, animated: true)
        } else {
            smartVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(dismissPresentedWatchlist)
            )
            let modalNav = UINavigationController(rootViewController: smartVC)
            modalNav.modalPresentationStyle = .automatic
            present(modalNav, animated: true)
        }
    }
    
    @objc
    private func dismissPresentedWatchlist() {
        presentedViewController?.dismiss(animated: true)
    }
}

extension PredictOutputViewController: ModalSheetHeightAware {
    func updateVisibleSheetHeight(_ height: CGFloat) {
        latestVisibleSheetHeight = max(0, height)
        guard isViewLoaded else { return }
        updateCollectionHeightForCurrentSheetPosition()
    }
}

extension PredictOutputViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedPredictions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: spotsToVisitOutputCollectionViewCell.identifier,
            for: indexPath
        ) as? spotsToVisitOutputCollectionViewCell else {
            return UICollectionViewCell()
        }

        let prediction = displayedPredictions[indexPath.item]
        let yearly = yearlySeriesByBird[prediction.birdName] ?? []
        cell.configure(prediction: prediction, yearlyProbabilities: yearly)
        cell.setCardSelected(indexPath.item == selectedPredictionIndex)
        
        cell.onTapBirdPath = { [weak self] selectedPrediction in
            self?.navigateToBirdPrediction(selectedPrediction)
        }
        
        cell.onTapWatchlist = { [weak self] selectedPrediction in
            self?.addToWatchlist(selectedPrediction)
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let oldIndex = selectedPredictionIndex
        selectedPredictionIndex = indexPath.item
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            collectionView.performBatchUpdates(nil)
            
            if let oldCell = collectionView.cellForItem(at: IndexPath(item: oldIndex, section: 0)) as? spotsToVisitOutputCollectionViewCell {
                oldCell.setCardSelected(false)
            }
            if let newCell = collectionView.cellForItem(at: indexPath) as? spotsToVisitOutputCollectionViewCell {
                newCell.setCardSelected(true)
            }
        }

        let prediction = displayedPredictions[indexPath.item]
        if let mapVC = navigationController?.parent as? PredictMapViewController {
            mapVC.filterMapForBird(prediction)
        }
        updateLocationHeader(forDisplayedPredictionAt: selectedPredictionIndex)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let cardWidth = collectionView.bounds.width - 32
        let compactAspectRatio: CGFloat = 6.0 / 17.0
        let calculatedHeight = cardWidth * compactAspectRatio
        var cardHeight: CGFloat

        if cardWidth > 450 {
            cardHeight = min(calculatedHeight, 180)
        } else {
            cardHeight = max(calculatedHeight, 146)
        }

        if indexPath.item == selectedPredictionIndex {
            cardHeight += 56
        }

        return CGSize(width: cardWidth, height: ceil(cardHeight))
    }
}

class BirdResultCell: UITableViewCell {
    private let birdImageView = UIImageView()
    private let birdNameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        birdImageView.contentMode = .scaleAspectFill
        birdImageView.clipsToBounds = true
        birdImageView.layer.cornerRadius = 8

        birdNameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        birdNameLabel.textColor = .label

        contentView.addSubview(birdImageView)
        contentView.addSubview(birdNameLabel)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let height = contentView.bounds.height
        let width = contentView.bounds.width
        let imageSize: CGFloat = 60
        birdImageView.frame = CGRect(x: 16, y: (height - imageSize) / 2, width: imageSize, height: imageSize)
        let labelX = birdImageView.frame.maxX + 16
        let labelWidth = width - labelX - 16
        birdNameLabel.frame = CGRect(x: labelX, y: 0, width: labelWidth, height: height)
    }

    func configure(with name: String, imageName: String) {
        birdNameLabel.text = name
        birdImageView.image = UIImage(named: imageName) ?? UIImage(systemName: "photo")
    }
}
