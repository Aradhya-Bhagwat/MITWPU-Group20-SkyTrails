import UIKit

class ResultViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ResultCellDelegate {
    
    @IBOutlet weak var resultCollectionView: UICollectionView!
    
    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?
    
    var historyItem: History?
    var historyIndex: Int?
    
    var selectedResult: Bird2?
    var selectedIndexPath: IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        resultCollectionView.register(
            UINib(nibName: "ResultCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "ResultCollectionViewCell"
        )
        
        resultCollectionView.delegate = self
        resultCollectionView.dataSource = self
        
        setupCollectionViewLayout()

        setupLeftResetButton()
        setupRightTickButton()
        

        viewModel.onResultsUpdated = { [weak self] in
            DispatchQueue.main.async {
                self?.resultCollectionView.reloadData()
            }
        }
        
        // If editing history, pre-select the bird
        if let history = historyItem {
            if let match = viewModel.birdResults.first(where: { $0.commonName == history.specieName }) {
                selectedResult = match
            } else if var dbBird = viewModel.getBird(byName: history.specieName) {
                dbBird.confidence = 1.0
                dbBird.scoreBreakdown = "From History"
                selectedResult = dbBird
                viewModel.birdResults = [selectedResult!]
            }
        } else {
            // If not editing history, run the filter once to ensure data is fresh
            viewModel.filterBirds(
                shape: viewModel.selectedShapeId,
                size: viewModel.selectedSizeCategory,
                location: viewModel.selectedLocation,
                fieldMarks: viewModel.selectedFieldMarks
            )
        }
        
        // Restore selection if exists
        if let result = selectedResult,
           let index = viewModel.birdResults.firstIndex(where: { $0.id == result.id }) {
            selectedIndexPath = IndexPath(item: index, section: 0)
        }
    }
    
    private func setupCollectionViewLayout() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
      
        let spacing: CGFloat = 12 + 8 + 8
        let itemWidth = (resultCollectionView.bounds.width - spacing) / 2
        layout.itemSize = CGSize(width: itemWidth, height: 240)
        
        resultCollectionView.collectionViewLayout = layout
    }
    
  
    
    private func setupRightTickButton() {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "checkmark", withConfiguration: config), for: .normal)
       button.tintColor = .black
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }
    
    private func setupLeftResetButton() {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let image = UIImage(systemName: "arrow.trianglehead.counterclockwise", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .black
        button.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        button.addTarget(self, action: #selector(restartTapped), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
    }
    
    @objc private func nextTapped() {
        let birdToSave = selectedResult ?? viewModel.birdResults.first
        
        guard let result = birdToSave else {
            navigationController?.popToRootViewController(animated: true)
            return
        }
        
        print("Saving bird: \(result.commonName)")
        
        let entry = History(
            imageView: result.staticImageName,
            specieName: result.commonName,
            date: today()
        )
        
        if let index = historyIndex {
            viewModel.histories[index] = entry
        } else {
            viewModel.addToHistory(entry)
        }
        
        navigationController?.popToRootViewController(animated: true)
        delegate?.didFinishStep()
    }
    
    @objc private func restartTapped() {
        delegate?.didTapLeftButton()
    }
    
    func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    
    // MARK: - UICollectionViewDataSource 
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.birdResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ResultCollectionViewCell", for: indexPath) as! ResultCollectionViewCell
        
        let result = viewModel.birdResults[indexPath.item]
        let img = UIImage(named: result.staticImageName)
        let percentString = String(Int((result.confidence ?? 0.0) * 100))
        
        cell.configure(
            image: img,
            name: result.commonName,
            percentage: percentString
        )
        
        // Selection state
        if selectedIndexPath == indexPath {
            cell.isSelectedCell = true
          //  cell.setSelected(true)
        } else {
            cell.isSelectedCell = false
            //cell.setSelected(false)
        }
        
        cell.delegate = self
        cell.indexPath = indexPath
        
        return cell
    }
    

    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if selectedIndexPath == indexPath { return }
        
        
        var rowsToReload: [IndexPath] = [indexPath]
        
        if let oldIndexPath = selectedIndexPath {
            rowsToReload.append(oldIndexPath)
        }
        
        selectedResult = viewModel.birdResults[indexPath.item]
        selectedIndexPath = indexPath
        
        collectionView.reloadItems(at: rowsToReload)
    }
    

    
    func didTapPredict(for cell: ResultCollectionViewCell) {
        print("Predict species on map tapped")
        guard let indexPath = cell.indexPath else { return }
        let selectedBird = viewModel.birdResults[indexPath.item]
        
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        guard let birdSelectionVC = storyboard.instantiateViewController(withIdentifier: "birdspredViewController") as? BirdSelectionViewController else {
            print("Error: Could not instantiate BirdSelectionViewController from birdspred.storyboard")
            return
        }
        
        birdSelectionVC.selectedSpecies = [selectedBird.id.uuidString]
        self.navigationController?.pushViewController(birdSelectionVC, animated: true)
    }
    
    func didTapAddToWatchlist(for cell: ResultCollectionViewCell) {
        guard let indexPath = cell.indexPath else { return }
        let result = viewModel.birdResults[indexPath.item]
        let savedBird = convertToSavedBird(from: result)
        saveToWatchlist(bird: savedBird)
    }
    
    private func convertToSavedBird(from result: Bird2) -> Bird {
        return Bird(
            id: UUID(),
            name: result.commonName,
            scientificName: result.scientificName,
            images: [result.staticImageName],
            rarity: [.common],
            location: viewModel.selectedLocation != nil ? [viewModel.selectedLocation!] : [],
            date: [Date()],
            observedBy: nil,
            notes: "Identified via Filter: \(result.scoreBreakdown ?? "N/A")"
        )
    }
    
    private func saveToWatchlist(bird: Bird) {
        let manager = WatchlistManager.shared
        
        if let defaultWatchlist = manager.watchlists.first {
            manager.addBirds([bird], to: defaultWatchlist.id, asObserved: false)
            
            let alert = UIAlertController(
                title: "Added to watchlist",
                message: "\(bird.name) added to My watchlist under to observe",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
            print(" No default watchlist found to save to.")
        }
    }
}
