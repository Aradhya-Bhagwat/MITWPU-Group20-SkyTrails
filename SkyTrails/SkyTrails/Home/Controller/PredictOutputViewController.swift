
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

    private var groupedPredictions: [[FinalPredictionResult]] = []
    private var yearlySeriesByBird: [String: [Int]] = [:]
    private var currentPageIndex: Int = 0
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
        updateLocationHeader(forPageAt: currentPageIndex)

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionHeightForCurrentSheetPosition()
        updateHeaderLabelTypography()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Auto-select and show the map for the first bird
        if let first = groupedPredictions.first?.first {
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
        yearlySeriesByBird.removeAll()
        
        // Group by matchedInputIndex
        let grouped = Dictionary(grouping: predictions) { $0.matchedInputIndex }
        
        // Sort groups by index to match input order
        let sortedIndices = grouped.keys.sorted()
        groupedPredictions = sortedIndices.map { index in
            grouped[index]?.sorted { lhs, rhs in
                if lhs.spottingProbability == rhs.spottingProbability {
                    return lhs.birdName < rhs.birdName
                }
                return lhs.spottingProbability > rhs.spottingProbability
            } ?? []
        }

        for prediction in predictions {
            guard yearlySeriesByBird[prediction.birdName] == nil else { continue }
            yearlySeriesByBird[prediction.birdName] = yearlySeries(for: prediction)
        }
    }


    func updatePredictions(_ newPredictions: [FinalPredictionResult]) {
        predictions = newPredictions
        prepareData()
        currentPageIndex = groupedPredictions.isEmpty
            ? 0
            : min(currentPageIndex, groupedPredictions.count - 1)
        collectionView?.reloadData()
        collectionView?.collectionViewLayout.invalidateLayout()
        updateLocationHeader(forPageAt: currentPageIndex)

        if let first = groupedPredictions.first?.first,
           let mapVC = navigationController?.parent as? PredictMapViewController {
            mapVC.filterMapForBird(first)
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
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        collectionView.collectionViewLayout = layout
        collectionView.isPagingEnabled = true
        collectionView.backgroundColor = .clear
        collectionView.decelerationRate = .fast
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(
            PredictLocationResultPageCell.self,
            forCellWithReuseIdentifier: PredictLocationResultPageCell.identifier
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

    private func updateLocationHeader(forPageAt index: Int) {
        guard groupedPredictions.indices.contains(index) else {
            selectedLocationNameLabel.text = "Search Location"
            selectedLocationDetailLabel.text = nil
            return
        }

        let results = groupedPredictions[index]
        guard let first = results.first else { return }
        
        let inputIndex = first.matchedInputIndex
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
                    
                    let city = mapItem.addressRepresentations?.cityName
                    let cityWithContext = mapItem.addressRepresentations?.cityWithContext
                    let region = mapItem.addressRepresentations?.regionName
                    let name = mapItem.name ?? ""
                    
                    if let cityWithContext, !cityWithContext.isEmpty {
                        self.selectedLocationDetailLabel.text = cityWithContext
                    } else if let city, !city.isEmpty {
                        self.selectedLocationDetailLabel.text = city
                    } else if let region, !region.isEmpty {
                        self.selectedLocationDetailLabel.text = region
                    } else if !name.isEmpty {
                        self.selectedLocationDetailLabel.text = name
                    } else {
                        self.selectedLocationDetailLabel.text = mapItem.address?.shortAddress ?? mapItem.address?.fullAddress
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
        let bird = WatchlistManager.shared.findBird(byName: prediction.birdName)
        let birdID = bird?.bird_id.uuidString ?? UUID().uuidString
        
        let birdInput = BirdDateInput(
            species: SpeciesData(
                id: birdID, 
                name: prediction.birdName, 
                imageName: prediction.imageName,
                ebirdSpeciesCode: bird?.ebird_species_code
            ),
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
        groupedPredictions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PredictLocationResultPageCell.identifier,
            for: indexPath
        ) as? PredictLocationResultPageCell else {
            return UICollectionViewCell()
        }

        let results = groupedPredictions[indexPath.item]
        cell.configure(
            predictions: results,
            yearlySeries: yearlySeriesByBird,
            selectedIndex: nil as Int?
        )

        
        cell.onPredictionSelected = { [weak self] prediction, index in
            if let mapVC = self?.navigationController?.parent as? PredictMapViewController {
                mapVC.filterMapForBird(prediction)
            }
        }

        
        cell.onBirdPathTapped = { [weak self] selectedPrediction in
            self?.navigateToBirdPrediction(selectedPrediction)
        }
        
        cell.onWatchlistTapped = { [weak self] selectedPrediction in
            self?.addToWatchlist(selectedPrediction)
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        if page != currentPageIndex {
            currentPageIndex = page
            updateLocationHeader(forPageAt: currentPageIndex)
            
            if let first = groupedPredictions[currentPageIndex].first,
               let mapVC = navigationController?.parent as? PredictMapViewController {
                mapVC.filterMapForBird(first)
            }
        }
    }
}


class BirdResultCell: UITableViewCell {
    private let birdImageView = UIImageView()
    private let birdNameLabel = UILabel()
    private var currentImageTask: Task<Void, Never>?

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
        currentImageTask?.cancel()
        birdImageView.image = UIImage(named: "placeholder_bird") 
                           ?? UIImage(systemName: "bird.fill")
        currentImageTask = Task { @MainActor in
            let image = await ImageService.shared.image(for: imageName)
            if !Task.isCancelled && birdNameLabel.text == name {
                if let loaded = image {
                    self.birdImageView.image = loaded
                }
            }
        }
    }
}

class PredictLocationResultPageCell: UICollectionViewCell, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    static let identifier = "PredictLocationResultPageCell"
    
    private var predictions: [FinalPredictionResult] = []
    private var yearlySeriesByBird: [String: [Int]] = [:]
    private var selectedIndex: Int?
    
    var onPredictionSelected: ((FinalPredictionResult, Int) -> Void)?
    var onBirdPathTapped: ((FinalPredictionResult) -> Void)?
    var onWatchlistTapped: ((FinalPredictionResult) -> Void)?

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.register(UINib(nibName: "spotsToVisitOutputCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "spotsToVisitOutputCollectionViewCell")
        return cv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(predictions: [FinalPredictionResult], yearlySeries: [String: [Int]], selectedIndex: Int?) {
        self.predictions = predictions
        self.yearlySeriesByBird = yearlySeries
        self.selectedIndex = selectedIndex
        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return predictions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "spotsToVisitOutputCollectionViewCell",
            for: indexPath
        ) as? spotsToVisitOutputCollectionViewCell else {
            return UICollectionViewCell()
        }

        let prediction = predictions[indexPath.item]
        let yearly = yearlySeriesByBird[prediction.birdName] ?? []
        cell.configure(prediction: prediction, yearlyProbabilities: yearly)
        cell.setCardSelected(indexPath.item == selectedIndex)
        
        cell.onTapBirdPath = { [weak self] selectedPrediction in
            self?.onBirdPathTapped?(selectedPrediction)
        }
        
        cell.onTapWatchlist = { [weak self] selectedPrediction in
            self?.onWatchlistTapped?(selectedPrediction)
        }
        
        return cell
    }

    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let prediction = predictions[indexPath.item]
        selectedIndex = indexPath.item
        collectionView.reloadData()
        onPredictionSelected?(prediction, indexPath.item)
    }

    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cardWidth = collectionView.bounds.width - 32
        let compactAspectRatio: CGFloat = 6.0 / 17.0
        let calculatedHeight = cardWidth * compactAspectRatio
        var cardHeight: CGFloat
        
        if cardWidth > 450 {
            cardHeight = min(calculatedHeight, 180)
        } else {
            cardHeight = max(calculatedHeight, 146)
        }

        if indexPath.item == selectedIndex {
            cardHeight += 56
        }

        return CGSize(width: cardWidth, height: ceil(cardHeight))
    }
}

