
import UIKit
import CoreLocation
import MapKit

protocol ModalSheetHeightAware: AnyObject {
    func updateVisibleSheetHeight(_ height: CGFloat)
}

enum PredictionSortOption: String, CaseIterable {
    case sightabilityDesc = "Sightability (High to Low)"
    case sightabilityAsc = "Sightability (Low to High)"
    case alphaAZ = "Alphabetical (A-Z)"
    case alphaZA = "Alphabetical (Z-A)"
}

protocol PredictionFilterDelegate: AnyObject {
    func didApplyFilters(sort: PredictionSortOption, minRange: Int, maxRange: Int)
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
    private var searchText: String = ""
    private var filteredGroupedPredictions: [[FinalPredictionResult]] = []
    
    // Filter State
    private var currentSortOption: PredictionSortOption = .sightabilityDesc
    private var minSightability: Int = 1
    private var maxSightability: Int = 99

    private lazy var searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "Search birds..."
        sb.searchBarStyle = .minimal
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.delegate = self
        return sb
    }()
    
    private lazy var filterButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        btn.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle", withConfiguration: config), for: .normal)
        btn.tintColor = .systemBlue
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 22
        
        // Apple Native Shadow
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowOpacity = 0.12
        btn.layer.shadowRadius = 4
        
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(didTapFilter), for: .touchUpInside)
        return btn
    }()
    
    private lazy var searchStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [searchBar, filterButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    private lazy var updatingBanner: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Updating with live sightings..."
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }()



    override func viewDidLoad() {
        super.viewDidLoad()
        setupTraitChangeHandling()
        applySemanticAppearance()

        setupNavigation()
        setupSearchBar()
        prepareData()
        setupCollectionView()
        updateLocationHeader(forPageAt: currentPageIndex)
        Task {
            await loadYearlyTrends()
        }
    }

    private func setupSearchBar() {
        view.addSubview(searchStackView)
        
        NSLayoutConstraint.activate([
            searchStackView.topAnchor.constraint(equalTo: selectedLocationDetailLabel.bottomAnchor, constant: 12),
            searchStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchStackView.heightAnchor.constraint(equalToConstant: 44),
            
            filterButton.widthAnchor.constraint(equalToConstant: 44),
            filterButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        if let collectionView = collectionView {
            if let superview = collectionView.superview {
                let existingTop = superview.constraints.filter { 
                    ($0.firstItem as? UIView == collectionView && $0.firstAttribute == .top) ||
                    ($0.secondItem as? UIView == collectionView && $0.secondAttribute == .top)
                }
                NSLayoutConstraint.deactivate(existingTop)
            }
            
            collectionView.translatesAutoresizingMaskIntoConstraints = false
            collectionView.topAnchor.constraint(equalTo: searchStackView.bottomAnchor, constant: 8).isActive = true
        }
    }

    @objc private func didTapFilter() {
        let filterVC = PredictionFilterViewController()
        filterVC.currentSort = currentSortOption
        filterVC.minRange = Float(minSightability)
        filterVC.maxRange = Float(maxSightability)
        filterVC.delegate = self
        
        if let sheet = filterVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        
        present(filterVC, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionHeightForCurrentSheetPosition()
        updateHeaderLabelTypography()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Auto-select and show the map for the first matching bird
        if let first = filteredGroupedPredictions.first?.first {
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
        
        filterData()

        // We now fetch yearly trends asynchronously in loadYearlyTrends()
    }

    func filterData() {
        // 1. First filter by search text and sightability range
        let baseFiltered = groupedPredictions.map { group in
            group.filter { prediction in
                let matchesSearch = searchText.isEmpty || prediction.birdName.localizedCaseInsensitiveContains(searchText)
                let inRange = prediction.spottingProbability >= minSightability && prediction.spottingProbability <= maxSightability
                return matchesSearch && inRange
            }
        }
        
        // 2. Then apply sorting to each group
        filteredGroupedPredictions = baseFiltered.map { group in
            group.sorted { lhs, rhs in
                switch currentSortOption {
                case .sightabilityDesc:
                    if lhs.spottingProbability == rhs.spottingProbability { return lhs.birdName < rhs.birdName }
                    return lhs.spottingProbability > rhs.spottingProbability
                case .sightabilityAsc:
                    if lhs.spottingProbability == rhs.spottingProbability { return lhs.birdName < rhs.birdName }
                    return lhs.spottingProbability < rhs.spottingProbability
                case .alphaAZ:
                    return lhs.birdName < rhs.birdName
                case .alphaZA:
                    return lhs.birdName > rhs.birdName
                }
            }
        }
        
        collectionView?.reloadData()
    }

    private func loadYearlyTrends() async {
        let uniqueSpecies = predictions.compactMap { p -> (String, Double, Double)? in
            guard let code = p.ebirdSpeciesCode else { return nil }
            return (code, p.matchedLocation.lat, p.matchedLocation.lon)
        }
        
        await withTaskGroup(of: (String, [Int]).self) { group in
            for (code, lat, lon) in uniqueSpecies {
                group.addTask {
                    let scores = (try? await SkyTrailsAPIService.shared
                        .fetchYearlyTrends(lat: lat, lon: lon, speciesCode: code)) ?? []
                    return (code, scores)
                }
            }
            for await (code, scores) in group {
                yearlySeriesByBird[code] = scores
            }
        }
        
        await MainActor.run {
            collectionView.reloadData()
        }
    }


    func updatePredictions(_ newPredictions: [FinalPredictionResult]) {
        // Merge new predictions with existing ones
        // Unique key = ebirdSpeciesCode + matchedInputIndex
        // If same key exists — keep higher probability
        // If new key — append it
        
        var mergedMap: [String: FinalPredictionResult] = [:]
        
        // First load existing predictions into map
        for pred in predictions {
            let key = "\(pred.ebirdSpeciesCode ?? pred.birdName)_\(pred.matchedInputIndex)"
            mergedMap[key] = pred
        }
        
        // Merge new predictions
        for pred in newPredictions {
            let key = "\(pred.ebirdSpeciesCode ?? pred.birdName)_\(pred.matchedInputIndex)"
            if let existing = mergedMap[key] {
                // Keep higher probability, prefer new residencyStatus
                // if it is more specific than existing
                let higherProb = max(existing.spottingProbability, pred.spottingProbability)
                let betterStatus = preferredStatus(existing.residencyStatus, pred.residencyStatus)
                // Rebuild with better values
                mergedMap[key] = FinalPredictionResult(
                    birdName: existing.birdName,
                    imageName: existing.imageName.isEmpty ? pred.imageName : existing.imageName,
                    likelySpot: existing.likelySpot,
                    matchedInputIndex: existing.matchedInputIndex,
                    matchedLocation: existing.matchedLocation,
                    spottingProbability: min(99, higherProb),
                    weekNumber: existing.weekNumber ?? pred.weekNumber,
                    residencyStatus: betterStatus,
                    ebirdSpeciesCode: existing.ebirdSpeciesCode ?? pred.ebirdSpeciesCode
                )
            } else {
                // New species not in existing set — add it
                mergedMap[key] = FinalPredictionResult(
                    birdName: pred.birdName,
                    imageName: pred.imageName,
                    likelySpot: pred.likelySpot,
                    matchedInputIndex: pred.matchedInputIndex,
                    matchedLocation: pred.matchedLocation,
                    spottingProbability: min(99, pred.spottingProbability),
                    weekNumber: pred.weekNumber,
                    residencyStatus: pred.residencyStatus,
                    ebirdSpeciesCode: pred.ebirdSpeciesCode
                )
            }
        }
        
        predictions = Array(mergedMap.values)
        prepareData()
        Task {
            await loadYearlyTrends()
        }
        
        currentPageIndex = groupedPredictions.isEmpty
            ? 0
            : min(currentPageIndex, groupedPredictions.count - 1)
            
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
            self.collectionView?.collectionViewLayout.invalidateLayout()
            self.updateLocationHeader(forPageAt: self.currentPageIndex)
            
            if let first = self.groupedPredictions.first?.first,
               let mapVC = self.navigationController?.parent as? PredictMapViewController {
                mapVC.filterMapForBird(first)
            }
        }
    }

    func showUpdatingBanner() {
        guard updatingBanner.superview == nil else { return }
        view.addSubview(updatingBanner)
        NSLayoutConstraint.activate([
            updatingBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            updatingBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            updatingBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            updatingBanner.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    func hideUpdatingBanner() {
        updatingBanner.removeFromSuperview()
    }

    private func preferredStatus(_ a: String?, _ b: String?) -> String? {
        let priority: [String: Int] = [
            "Recently Spotted": 0,
            "Highly Expected": 1,
            "Expected": 2
        ]
        let aP = priority[a ?? ""] ?? 99
        let bP = priority[b ?? ""] ?? 99
        return aP <= bP ? a : b
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
        filteredGroupedPredictions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PredictLocationResultPageCell.identifier,
            for: indexPath
        ) as? PredictLocationResultPageCell else {
            return UICollectionViewCell()
        }

        let results = filteredGroupedPredictions[indexPath.item]
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
            
            if let first = filteredGroupedPredictions[currentPageIndex].first,
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
        let yearly = yearlySeriesByBird[prediction.ebirdSpeciesCode ?? ""] ?? []
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
        let previousIndex = selectedIndex
        
        if previousIndex == indexPath.item {
            selectedIndex = nil
        } else {
            selectedIndex = indexPath.item
        }
        
        // 1. Update the state of visible cells directly to avoid 'reloadItems' choppiness
        if let prev = previousIndex, let prevCell = collectionView.cellForItem(at: IndexPath(item: prev, section: 0)) as? spotsToVisitOutputCollectionViewCell {
            prevCell.setCardSelected(false, animated: true)
        }
        
        if let currentCell = collectionView.cellForItem(at: indexPath) as? spotsToVisitOutputCollectionViewCell {
            currentCell.setCardSelected(indexPath.item == selectedIndex, animated: true)
        }

        // 2. Animate the height changes smoothly
        collectionView.performBatchUpdates(nil, completion: nil)
        
        onPredictionSelected?(prediction, selectedIndex ?? -1)
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

extension PredictOutputViewController: UISearchBarDelegate, PredictionFilterDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        filterData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func didApplyFilters(sort: PredictionSortOption, minRange: Int, maxRange: Int) {
        self.currentSortOption = sort
        self.minSightability = minRange
        self.maxSightability = maxRange
        filterData()
    }
}

