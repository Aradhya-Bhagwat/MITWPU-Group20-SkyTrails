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
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
            self.birdResults = (history.candidates?.isEmpty == false) ? (history.candidates ?? []) : viewModel.results
            preselectedBirdId = history.bird?.id
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
           let selectedItem = birdResults.firstIndex(where: { $0.bird?.id == preselectedBirdId }) {
            selectedIndexPath = IndexPath(item: selectedItem, section: 0)
            selectedResult = birdResults[selectedItem].bird
        }
        viewModel.results = birdResults
        updateSaveButtonState()
        resultCollectionView.reloadData()
    }

    private func updateSaveButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = (selectedIndexPath != nil)
    }
    
    // MARK: - CollectionView Layout

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
        let imageHeight = imageWidth  // 1:1 square

        let topMargin: CGFloat = 8
        let imageToLabelSpacing: CGFloat = 8
        let nameButtonHeight: CGFloat = 48  // button height governs the row
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

    // MARK: - Actions
    
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

    // MARK: - DataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return birdResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let candidate = birdResults[indexPath.item]
        guard let bird = candidate.bird else { return UICollectionViewCell() }
        
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "ResultCollectionViewCell",
            for: indexPath
        ) as! ResultCollectionViewCell
        
        let confidencePercent = String(Int(candidate.confidence * 100))
        cell.configure(
            image: UIImage(named: bird.staticImageName),
            name: bird.commonName,
            percentage: confidencePercent
        )

        // FIX: Selection appearance is owned by the cell via isSelectedCell.
        // Setting it here (after prepareForReuse has already reset borders)
        // ensures correct state on every dequeue — no stale borders on recycled cells.
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

        // Reload only the affected cells for efficiency
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

    // MARK: - ResultCellDelegate
    
    func didTapPredict(for cell: ResultCollectionViewCell) {
        guard let indexPath = cell.indexPath, let bird = birdResults[indexPath.item].bird else { return }
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        if let birdSelectionVC = storyboard.instantiateViewController(withIdentifier: "BirdSelectionViewController") as? BirdSelectionViewController {
            birdSelectionVC.selectedSpecies = [bird.id.uuidString]
            self.navigationController?.pushViewController(birdSelectionVC, animated: true)
        }
    }
    
    func didTapAddToWatchlist(for cell: ResultCollectionViewCell) {
        guard let indexPath = cell.indexPath, let bird = birdResults[indexPath.item].bird else { return }
        
        let alert = UIAlertController(
            title: "Added",
            message: "\(bird.commonName) added to watchlist",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
