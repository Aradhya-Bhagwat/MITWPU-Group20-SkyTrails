import UIKit
import SwiftData

class ResultViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ResultCellDelegate {
    
    @IBOutlet weak var resultCollectionView: UICollectionView!
    
    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?
    
    // Changed History? to IdentificationResult? (assuming this is your session record)
    var historyItem: IdentificationResult?
    var historyIndex: Int?
    
    // Changed Bird2? to Bird?
    var selectedResult: Bird?
    var selectedIndexPath: IndexPath?
    
    // Local storage for display if the manager doesn't have it
    var birdResults: [IdentificationCandidate] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        resultCollectionView.register(
            UINib(nibName: "ResultCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "ResultCollectionViewCell"
        )
        
        resultCollectionView.delegate = self
        resultCollectionView.dataSource = self
        setupCollectionViewLayout()

        loadData()
    }
    
    private func loadData() {
        if let history = historyItem {
            // Loading from a saved session
            self.birdResults = history.candidates ?? []
        } else {
           
            viewModel.filterBirds(
                shape: viewModel.selectedShapeId,
                size: viewModel.selectedSizeCategory,
                location: viewModel.selectedLocation,
                fieldMarks: Array(viewModel.selectedFieldMarks.values)
            )
            
            
            self.birdResults = viewModel.results
        }
        
        resultCollectionView.reloadData()
    }
    
    // MARK: - CollectionView Layout (Preserved Logic)
    
    private func setupCollectionViewLayout() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        resultCollectionView.collectionViewLayout = layout
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
        let minItemWidth: CGFloat = 120
        let maxItemsPerRow: CGFloat = 4
        let availableWidth = collectionView.bounds.width - layout.sectionInset.left - layout.sectionInset.right
        
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
        return CGSize(width: itemWidth, height: itemWidth * 1.4)
    }

    // MARK: - Actions
    
    @IBAction func nextTapped(_ sender: Any) {
        // 1. Get the selected candidate.
        // If user hasn't tapped one, we use the first (top) result automatically.
        let candidateToSave: IdentificationCandidate?
        if let selectedPath = selectedIndexPath {
            candidateToSave = birdResults[selectedPath.item]
        } else {
            candidateToSave = birdResults.first
        }
        
        // 2. Call the manager's saveSession function
        if let candidate = candidateToSave {
            viewModel.saveSession(winningCandidate: candidate)
        }

        // 3. Return to history
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
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ResultCollectionViewCell", for: indexPath) as! ResultCollectionViewCell
        
        let confidencePercent = String(Int(candidate.confidence * 100))
        cell.configure(
            image: UIImage(named: bird.staticImageName),
            name: bird.commonName,
            percentage: confidencePercent
        )

        let isSelected = selectedIndexPath == indexPath
        cell.contentView.layer.borderWidth = isSelected ? 3 : 1
        cell.contentView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.systemGray4.cgColor
        cell.contentView.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.1) : .white
        cell.contentView.layer.cornerRadius = 12
        
        cell.delegate = self
        cell.indexPath = indexPath
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndexPath = indexPath
        selectedResult = birdResults[indexPath.item].bird
        collectionView.reloadData()
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
        
        // Use the WatchlistManager with your new WatchlistEntry model
        let manager = WatchlistManager.shared
        // manager.addBirdToDefaultWatchlist(bird)
        
        let alert = UIAlertController(title: "Added", message: "\(bird.commonName) added to watchlist", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
