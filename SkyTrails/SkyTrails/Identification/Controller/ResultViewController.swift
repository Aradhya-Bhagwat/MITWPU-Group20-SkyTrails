import UIKit
import SwiftData

class ResultViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ResultCellDelegate {
    
    @IBOutlet weak var resultCollectionView: UICollectionView!
    
    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?
    
    var historyItem: IdentificationResult?
    var historyIndex: Int?
    
    var selectedResult: Bird?
    var selectedIndexPath: IndexPath?
    
    var birdResults: [IdentificationCandidate] = []
    private var imageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    private let watchlistManager = WatchlistManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Identification Results"
        self.tabBarItem.title = "Identification"
        setupTraitChangeHandling()

        resultCollectionView.register(
            UINib(nibName: "ResultCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "ResultCollectionViewCell"
        )
        
        resultCollectionView.delegate = self
        resultCollectionView.dataSource = self
        resultCollectionView.backgroundColor = .clear
        setupCollectionViewLayout()
        updateSaveButtonState()

        loadData()
    }

    private func setupTraitChangeHandling() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.handleUserInterfaceStyleChange()
        }
    }

    private func handleUserInterfaceStyleChange() {
        resultCollectionView.reloadData()
    }

    private func loadData() {
        let preselectedBirdId: UUID?
        if let history = historyItem {
            var candidates = (history.candidates?.isEmpty == false) ? (history.candidates ?? []) : viewModel.results
            candidates.sort { ($0.confidence) > ($1.confidence) }
            self.birdResults = candidates
            preselectedBirdId = history.bird?.bird_id
        } else {
            viewModel.filterBirds(
                shape: viewModel.selectedShapeId,
                size: viewModel.selectedSizeCategory,
                location: viewModel.selectedLocation,
                fieldMarks: Array(viewModel.selectedFieldMarks.values)
            )
            self.birdResults = viewModel.results
            preselectedBirdId = nil
        }

        if let preselectedBirdId,
           let selectedItem = birdResults.firstIndex(where: { $0.bird?.bird_id == preselectedBirdId }) {
            selectedIndexPath = IndexPath(item: selectedItem, section: 0)
            selectedResult = birdResults[selectedItem].bird
        }
        viewModel.results = birdResults
        prefetchBirdImages()
        updateSaveButtonState()
        resultCollectionView.reloadData()
    }

    private func prefetchBirdImages() {
        let keys = birdResults.compactMap { $0.bird?.staticImageName }
        Task {
            await IdentificationImageService.shared.prefetch(keys: keys)
        }
    }

    private func updateSaveButtonState() {
        let hasResults = !birdResults.isEmpty
        if hasResults {
            navigationItem.rightBarButtonItem?.isEnabled = selectedIndexPath != nil
        } else {
            navigationItem.rightBarButtonItem?.isEnabled = true
        }
    }

    private func setupCollectionViewLayout() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        resultCollectionView.collectionViewLayout = layout
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
        
        let minItemWidth: CGFloat = 120
        let maxItemsPerRow: CGFloat = 4
        let availableWidth = collectionView.bounds.width
            - layout.sectionInset.left
            - layout.sectionInset.right
        
        var itemsPerRow: CGFloat = 1
        while true {
            let potentialWidth = (availableWidth - (layout.minimumInteritemSpacing * (itemsPerRow - 1))) / itemsPerRow
            if potentialWidth >= minItemWidth && itemsPerRow < maxItemsPerRow {
                itemsPerRow += 1
            } else {
                if potentialWidth < minItemWidth && itemsPerRow > 1 { itemsPerRow -= 1 }
                break
            }
        }
        
        let itemWidth = (availableWidth - (layout.minimumInteritemSpacing * (itemsPerRow - 1))) / itemsPerRow
        
        let imageMargins: CGFloat = 16
        let imageWidth = itemWidth - imageMargins
        let imageHeight = imageWidth

        let topMargin: CGFloat = 8
        let imageToLabelSpacing: CGFloat = 8
        let nameButtonHeight: CGFloat = 48
        let labelSpacing: CGFloat = 4
        let percentageHeight: CGFloat = 17
        let bottomMargin: CGFloat = 8
        
        let totalHeight = topMargin
            + imageHeight
            + imageToLabelSpacing
            + nameButtonHeight
            + labelSpacing
            + percentageHeight
            + bottomMargin
        
        return CGSize(width: itemWidth, height: totalHeight)
    }
    
    @IBAction func nextTapped(_ sender: Any) {
        if viewModel.isReloadFlowActive, viewModel.currentSession != nil {
            showSaveChoiceDialog()
            return
        }

        persistAndExit(updateExisting: true)
    }

    private func showSaveChoiceDialog() {
        let alert = UIAlertController(
            title: "Save Changes",
            message: "Do you want to update this history item or create a new one?",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Update", style: .default) { [weak self] _ in
            self?.persistAndExit(updateExisting: true)
        })
        alert.addAction(UIAlertAction(title: "New", style: .default) { [weak self] _ in
            self?.persistAndExit(updateExisting: false)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    private func persistAndExit(updateExisting: Bool) {
        let candidateToSave: IdentificationCandidate?
        if let selectedPath = selectedIndexPath {
            candidateToSave = birdResults[selectedPath.item]
        } else {
            candidateToSave = birdResults.first
        }

        if !updateExisting {
            viewModel.currentSession = nil
        }
        
        if let candidate = candidateToSave {
            viewModel.saveSession(winningCandidate: candidate)
        }
        
        viewModel.reset()

        if let rootVC = navigationController?.viewControllers.first as? IdentificationViewController {
            rootVC.resetIdentificationOptions()
        }

        navigationController?.popToRootViewController(animated: true)
    }
  
    @IBAction func restartTapped(_ sender: Any) {
        delegate?.didTapLeftButton()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return birdResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let candidate = birdResults[indexPath.item]
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "ResultCollectionViewCell",
            for: indexPath
        ) as! ResultCollectionViewCell

        let confidencePercent = String(format: "%.1f", candidate.confidence * 100)

        if let bird = candidate.bird {
            cell.configure(
                image: UIImage(named: bird.staticImageName) ?? UIImage(systemName: "bird.fill"),
                name: bird.commonName,
                percentage: confidencePercent
            )
            cell.resultImageView.tintColor = .secondaryLabel

            imageLoadTasks[indexPath]?.cancel()
            imageLoadTasks[indexPath] = Task { [weak self, weak collectionView] in
                let loaded = await IdentificationImageService.shared.image(for: bird.staticImageName, shapeId: nil)
                guard !Task.isCancelled else { return }
                guard self != nil, let collectionView else { return }
                guard let liveCell = collectionView.cellForItem(at: indexPath) as? ResultCollectionViewCell else { return }
                guard liveCell.indexPath == indexPath else { return }
                liveCell.resultImageView.image = loaded ?? UIImage(named: bird.staticImageName) ?? UIImage(systemName: "bird.fill")
            }
        } else {
            cell.configure(
                image: UIImage(systemName: "questionmark.circle.fill"),
                name: "Unknown Species",
                percentage: confidencePercent
            )
            cell.resultImageView.tintColor = .secondaryLabel
            imageLoadTasks[indexPath]?.cancel()
            imageLoadTasks[indexPath] = nil
        }

        cell.isSelectedCell = (selectedIndexPath == indexPath)

        cell.delegate = self
        cell.indexPath = indexPath
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let previous = selectedIndexPath
        selectedIndexPath = indexPath
        selectedResult = birdResults[indexPath.item].bird
        updateSaveButtonState()
        var toReload = [indexPath]
        if let prev = previous, prev != indexPath { toReload.append(prev) }
        collectionView.reloadItems(at: toReload)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.resultCollectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    deinit {
        imageLoadTasks.values.forEach { $0.cancel() }
    }
    
    func didTapPredict(for cell: ResultCollectionViewCell) {
        guard let indexPath = cell.indexPath, let bird = birdResults[indexPath.item].bird else { return }
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        if let birdSelectionVC = storyboard.instantiateViewController(withIdentifier: "BirdSelectionViewController") as? BirdSelectionViewController {
            birdSelectionVC.selectedSpecies = [bird.bird_id.uuidString]
            self.navigationController?.pushViewController(birdSelectionVC, animated: true)
        }
    }
    
    func didTapAddToWatchlist(for cell: ResultCollectionViewCell) {
        guard let indexPath = cell.indexPath, let bird = birdResults[indexPath.item].bird else { return }

        let existingWatchlistIds = watchlistIdsContainingBird(birdId: bird.bird_id)
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(withIdentifier: "UnobservedDetailViewController") as? UnobservedDetailViewController else { return }

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
            let watchlistNav = tabBarController.viewControllers?[safe: 1] as? UINavigationController
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
