
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
    func didApplyFilters(
        sort: PredictionSortOption,
        minRange: Int,
        maxRange: Int,
        selectedWeek: Int?
    )
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
    
    var onPageChanged: ((Int, Int) -> Void)?
    
    private var allWeeksPerSpot: [Int: [Int]] = [:]

    // Navigation Controls
    private lazy var pageControl: UIPageControl = {
        let pc = UIPageControl()
        pc.currentPageIndicatorTintColor = .systemBlue
        pc.pageIndicatorTintColor = .systemGray4
        pc.hidesForSinglePage = true
        pc.addTarget(self, action: #selector(pageControlValueChanged), for: .valueChanged)
        return pc
    }()
    
    private lazy var leftChevronItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(didTapPrev)
        )
        item.tintColor = .systemBlue
        return item
    }()
    
    private lazy var rightChevronItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "chevron.right"),
            style: .plain,
            target: self,
            action: #selector(didTapNext)
        )
        item.tintColor = .systemBlue
        return item
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
        setupNavigationControls()
        prepareData()
        setupCollectionView()
        updateLocationHeader(forPageAt: currentPageIndex)
        Task {
            await loadYearlyTrends()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        onPageChanged?(currentPageIndex, groupedPredictions.count)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionHeightForCurrentSheetPosition()
        updateHeaderLabelTypography()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Auto-select and show the map for the first matching bird
        if let first = groupedPredictions.first?.first {
            if let mapVC = navigationController?.parent as? PredictMapViewController {
                mapVC.filterMapForBird(first)
            }
        }

        AppTourManager.shared.trackViewControllerAppeared(self)
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
        
        // Calculate weeks for each spot independently
        allWeeksPerSpot.removeAll()
        for (index, input) in inputData.enumerated() {
            var weeks: [Int] = []
            if let start = input.startDate,
               let end = input.endDate {
                var current = start
                let calendar = Calendar.current
                while current <= end {
                    let week = calendar.component(.weekOfYear, from: current)
                    if !weeks.contains(week) {
                        weeks.append(week)
                    }
                    current = calendar.date(byAdding: .day, value: 7, to: current) ?? end
                }
                allWeeksPerSpot[index] = weeks.sorted()
            } else {
                // Fallback to current + next 2
                let current = Calendar.current.component(.weekOfYear, from: Date())
                allWeeksPerSpot[index] = [current, (current % 52) + 1, ((current + 1) % 52) + 1]
            }
            print("DEBUG WEEKS: spot \(index) weeks = \(allWeeksPerSpot[index] ?? [])")
        }

        
        // Update page control
        pageControl.numberOfPages = groupedPredictions.count
        pageControl.currentPage = currentPageIndex
        updateNavigationButtonsState()
        onPageChanged?(currentPageIndex, groupedPredictions.count)
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
            
            // Forward update to each visible page cell
            for cell in self.collectionView?.visibleCells ?? [] {
                if let pageCell = cell as? PredictLocationResultPageCell,
                   let indexPath = self.collectionView?.indexPath(for: pageCell) {
                    let spotWeeks = self.allWeeksPerSpot[indexPath.item] ?? []
                    pageCell.updatePredictions(newPredictions, allWeeks: spotWeeks)
                }
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
        navigationItem.title = nil
        navigationItem.leftBarButtonItem = leftChevronItem
        navigationItem.rightBarButtonItem = rightChevronItem
    }

    private func setupNavigationControls() {
        navigationItem.titleView = pageControl
    }

    @objc private func pageControlValueChanged() {
        scrollToPage(pageControl.currentPage)
    }

    @objc private func didTapPrev() {
        let target = max(0, currentPageIndex - 1)
        scrollToPage(target)
    }

    @objc private func didTapNext() {
        let target = min(groupedPredictions.count - 1, currentPageIndex + 1)
        scrollToPage(target)
    }

    private func scrollToPage(_ page: Int) {
        guard page != currentPageIndex, groupedPredictions.indices.contains(page) else { return }
        let offset = CGPoint(x: CGFloat(page) * collectionView.bounds.width, y: 0)
        collectionView.setContentOffset(offset, animated: true)
        
        // Note: scrollViewDidEndScrollingAnimation or scrollViewDidScroll will update headers
        currentPageIndex = page
        updateLocationHeader(forPageAt: page)
        pageControl.currentPage = page
        updateNavigationButtonsState()
        onPageChanged?(currentPageIndex, groupedPredictions.count)
    }

    func navigateToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        scrollToPage(currentPageIndex - 1)
    }

    func navigateToNextPage() {
        guard currentPageIndex < groupedPredictions.count - 1 else { return }
        scrollToPage(currentPageIndex + 1)
    }

    private func updateNavigationButtonsState() {
        let total = groupedPredictions.count
        leftChevronItem.isEnabled = currentPageIndex > 0
        rightChevronItem.isEnabled = currentPageIndex < total - 1
        
        // Hide buttons if only 1 page
        if total <= 1 {
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = nil
        } else {
            navigationItem.leftBarButtonItem = leftChevronItem
            navigationItem.rightBarButtonItem = rightChevronItem
        }
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
        collectionView.clipsToBounds = true
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

        let storyboard = UIStoryboard(name: "Birdspred", bundle: nil)
        if let mapVC = storyboard.instantiateViewController(withIdentifier: "BirdMapResultViewController") as? BirdspredViewController {
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
        let spotWeeks = allWeeksPerSpot[indexPath.item] ?? []
        cell.configure(
            predictions: results,
            yearlySeries: yearlySeriesByBird,
            selectedIndex: nil,
            allWeeks: spotWeeks,
            presentingVC: self
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
        
        print("DEBUG PARENT: cellForItemAt index=\(indexPath.item) spot=\(groupedPredictions[indexPath.item].first?.likelySpot ?? "unknown")")
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updatePageIndexFromScroll(scrollView)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updatePageIndexFromScroll(scrollView)
    }

    private func updatePageIndexFromScroll(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        if page != currentPageIndex {
            currentPageIndex = page
            pageControl.currentPage = page
            updateLocationHeader(forPageAt: currentPageIndex)
            updateNavigationButtonsState()
            
            if let first = groupedPredictions[currentPageIndex].first,
               let mapVC = navigationController?.parent as? PredictMapViewController {
                mapVC.filterMapForBird(first)
            }
            onPageChanged?(currentPageIndex, groupedPredictions.count)
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
    
    struct SpotFilterState {
        var searchText: String = ""
        var sortOption: PredictionSortOption = .sightabilityDesc
        var minSightability: Int = 1
        var maxSightability: Int = 99
        var selectedWeek: Int? = nil
    }

    private var allPredictions: [FinalPredictionResult] = []
    private var filteredPredictions: [FinalPredictionResult] = []
    private var filterState = SpotFilterState()
    private var allWeeks: [Int] = []
    private var yearlySeriesByBird: [String: [Int]] = [:]
    private var selectedIndex: Int?
    weak var presentingViewController: UIViewController?
    
    var onPredictionSelected: ((FinalPredictionResult, Int) -> Void)?
    var onBirdPathTapped: ((FinalPredictionResult) -> Void)?
    var onWatchlistTapped: ((FinalPredictionResult) -> Void)?

    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "No birds match your filter"
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let subLabel = UILabel()
        subLabel.text = "Try adjusting your search or filters"
        subLabel.font = UIFont.systemFont(ofSize: 13)
        subLabel.textColor = .tertiaryLabel
        subLabel.textAlignment = .center
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView(arrangedSubviews: [imageView, label, subLabel])
        stack.axis = .vertical

        stack.spacing = 8
        
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 48),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
        ])
        return view
    }()

    private lazy var searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "Search birds..."
        bar.searchBarStyle = .minimal
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.delegate = self
        return bar
    }()

    private lazy var filterButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        btn.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle", withConfiguration: config), for: .normal)
        btn.tintColor = .systemBlue
        btn.backgroundColor = .secondarySystemBackground
        btn.layer.cornerRadius = 20
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        btn.showsMenuAsPrimaryAction = true
        btn.menu = createFilterMenu()
        return btn
    }()

    private func createFilterMenu() -> UIMenu {
        let nameAsc = UIAction(title: "Name (A-Z)", image: UIImage(systemName: "textformat.abc")) { [weak self] _ in
            self?.updateSort(.alphaAZ)
        }
        let nameDesc = UIAction(title: "Name (Z-A)", image: UIImage(systemName: "textformat.abc")) { [weak self] _ in
            self?.updateSort(.alphaZA)
        }
        let probHigh = UIAction(title: "Finding % (High)", image: UIImage(systemName: "arrow.up.circle")) { [weak self] _ in
            self?.updateSort(.sightabilityDesc)
        }
        let probLow = UIAction(title: "Finding % (Low)", image: UIImage(systemName: "arrow.down.circle")) { [weak self] _ in
            self?.updateSort(.sightabilityAsc)
        }
        
        return UIMenu(title: "Sort Birds", children: [nameAsc, nameDesc, probHigh, probLow])
    }
    
    private func updateSort(_ option: PredictionSortOption) {
        filterState.sortOption = option
        applyFilter()
    }

    private lazy var searchStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [searchBar, filterButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.register(UINib(nibName: "SpotsToVisitOutputCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SpotsToVisitOutputCollectionViewCell")
        cv.clipsToBounds = true
        return cv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(searchStack)
        contentView.addSubview(collectionView)
        contentView.addSubview(emptyStateView)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            searchStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            searchStack.heightAnchor.constraint(equalToConstant: 40),

            collectionView.topAnchor.constraint(equalTo: searchStack.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            emptyStateView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
        ])
        contentView.clipsToBounds = true
        clipsToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset ALL state so reused cell starts clean
        allPredictions = []
        filteredPredictions = []
        filterState = SpotFilterState()
        allWeeks = []
        presentingViewController = nil
        
        // Clear search bar UI
        searchBar.text = ""
        searchBar.resignFirstResponder()
        
        // Reset collection view
        collectionView.reloadData()
        
        // Hide empty state
        emptyStateView.isHidden = true
        collectionView.isHidden = false
        
        print("DEBUG REUSE: cell \(ObjectIdentifier(self)) reused — state cleared")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(
        predictions: [FinalPredictionResult],
        yearlySeries: [String: [Int]],
        selectedIndex: Int?,
        allWeeks: [Int],
        presentingVC: UIViewController?
    ) {
        // Always reset filter state on new configure
        // This ensures a clean slate whether the cell
        // is newly created or reused
        filterState = SpotFilterState()
        searchBar.text = ""
        
        // Now set new data
        self.allPredictions = predictions
        self.filteredPredictions = predictions
        self.yearlySeriesByBird = yearlySeries
        self.selectedIndex = selectedIndex
        self.allWeeks = allWeeks
        self.presentingViewController = presentingVC
        
        print("DEBUG CONFIGURE: cell \(ObjectIdentifier(self)) spot=\(predictions.first?.likelySpot ?? "?") weeks=\(allWeeks)")
        
        applyFilter()
    }

    func updatePredictions(_ newPredictions: [FinalPredictionResult], allWeeks: [Int]) {
        self.allWeeks = allWeeks
        var mergedMap: [String: FinalPredictionResult] = [:]
        for pred in allPredictions {
            let key = "\(pred.ebirdSpeciesCode ?? pred.birdName)_\(pred.matchedInputIndex)"
            mergedMap[key] = pred
        }
        for pred in newPredictions {
            let key = "\(pred.ebirdSpeciesCode ?? pred.birdName)_\(pred.matchedInputIndex)"
            if let existing = mergedMap[key] {
                let higherProb = max(existing.spottingProbability, pred.spottingProbability)
                mergedMap[key] = FinalPredictionResult(
                    birdName: existing.birdName,
                    imageName: existing.imageName.isEmpty ? pred.imageName : existing.imageName,
                    likelySpot: existing.likelySpot,
                    matchedInputIndex: existing.matchedInputIndex,
                    matchedLocation: existing.matchedLocation,
                    spottingProbability: min(99, higherProb),
                    weekNumber: existing.weekNumber ?? pred.weekNumber,
                    residencyStatus: existing.residencyStatus,
                    ebirdSpeciesCode: existing.ebirdSpeciesCode ?? pred.ebirdSpeciesCode,
                    weekScores: existing.weekScores,
                    peakWeek: existing.peakWeek
                )
            } else {
                mergedMap[key] = pred
            }
        }
        allPredictions = Array(mergedMap.values)
        applyFilter()
    }

    private func applyFilter() {
        var result = allPredictions
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())

        // Search filter
        if !filterState.searchText.isEmpty {
            result = result.filter { 
                $0.birdName.localizedCaseInsensitiveContains(filterState.searchText)
            }
        }
        
        // Week filter
        if let week = filterState.selectedWeek {
            result = result.compactMap { prediction in
                let weekKey = "\(week)"
                
                if let weekScores = prediction.weekScores, !weekScores.isEmpty {
                    guard let weekScore = weekScores[weekKey],
                          weekScore > 0
                    else { return nil }
                    
                    return FinalPredictionResult(
                        birdName: prediction.birdName,
                        imageName: prediction.imageName,
                        likelySpot: prediction.likelySpot,
                        matchedInputIndex: prediction.matchedInputIndex,
                        matchedLocation: prediction.matchedLocation,
                        spottingProbability: weekScore,
                        weekNumber: "Week \(week)",
                        residencyStatus: prediction.residencyStatus,
                        ebirdSpeciesCode: prediction.ebirdSpeciesCode,
                        weekScores: prediction.weekScores,
                        peakWeek: prediction.peakWeek
                    )
                } else {
                    // Fallback: Check if prediction.weekNumber contains this week number, or if peakWeek == week.
                    let matchesWeekString = prediction.weekNumber?.localizedCaseInsensitiveContains("\(week)") ?? false
                    let matchesPeakWeek = prediction.peakWeek == week
                    
                    guard matchesWeekString || matchesPeakWeek else {
                        return nil
                    }
                    
                    return prediction
                }
            }
        } else {
            // No week filter — show peak sightability
            result = result.map { prediction in
                var displayProb = prediction.spottingProbability
                var displayWeek = prediction.weekNumber
                
                if let weekScores = prediction.weekScores, !weekScores.isEmpty {
                    let maxScore = weekScores.values.max() ?? 0
                    let peakWeeks = weekScores.filter { $0.value == maxScore }.keys.compactMap { Int($0) }.sorted()
                    let closest = peakWeeks.min(by: { abs($0 - currentWeek) < abs($1 - currentWeek) }) ?? peakWeeks.first ?? currentWeek
                    displayProb = maxScore
                    displayWeek = "Week \(closest)"
                }
                
                return FinalPredictionResult(
                    birdName: prediction.birdName,
                    imageName: prediction.imageName,
                    likelySpot: prediction.likelySpot,
                    matchedInputIndex: prediction.matchedInputIndex,
                    matchedLocation: prediction.matchedLocation,
                    spottingProbability: displayProb,
                    weekNumber: displayWeek,
                    residencyStatus: prediction.residencyStatus,
                    ebirdSpeciesCode: prediction.ebirdSpeciesCode,
                    weekScores: prediction.weekScores,
                    peakWeek: prediction.peakWeek
                )
            }
        }
        
        // Range filter
        result = result.filter {
            $0.spottingProbability >= filterState.minSightability &&
            $0.spottingProbability <= filterState.maxSightability
        }
        
        // Sort
        result = result.sorted { lhs, rhs in
            switch filterState.sortOption {
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
        
        filteredPredictions = result
        
        let isEmpty = filteredPredictions.isEmpty
        collectionView.isHidden = isEmpty
        emptyStateView.isHidden = !isEmpty
        collectionView.reloadData()
        
        print("DEBUG FILTER APPLY: cell \(ObjectIdentifier(self)) spot=\(allPredictions.first?.likelySpot ?? "?") results=\(filteredPredictions.count)")
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredPredictions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "SpotsToVisitOutputCollectionViewCell",
            for: indexPath
        ) as? SpotsToVisitOutputCollectionViewCell else {
            return UICollectionViewCell()
        }

        let prediction = filteredPredictions[indexPath.item]
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
        let prediction = filteredPredictions[indexPath.item]
        let previousIndex = selectedIndex
        
        if previousIndex == indexPath.item {
            selectedIndex = nil
        } else {
            selectedIndex = indexPath.item
        }
        
        // 1. Update the state of visible cells directly to avoid 'reloadItems' choppiness
        if let prev = previousIndex, let prevCell = collectionView.cellForItem(at: IndexPath(item: prev, section: 0)) as? SpotsToVisitOutputCollectionViewCell {
            prevCell.setCardSelected(false, animated: true)
        }
        
        if let currentCell = collectionView.cellForItem(at: indexPath) as? SpotsToVisitOutputCollectionViewCell {
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

extension PredictLocationResultPageCell: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterState.searchText = searchText
        applyFilter()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}



