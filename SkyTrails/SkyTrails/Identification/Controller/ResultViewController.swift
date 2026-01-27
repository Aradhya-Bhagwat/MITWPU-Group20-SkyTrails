import UIKit

class ResultViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ResultCellDelegate {
    
    @IBOutlet weak var resultCollectionView: UICollectionView!
    
    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?
    
    var historyItem: History?
    var historyIndex: Int?
    
    var selectedResult: Bird?
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

        viewModel.onResultsUpdated = { [weak self] in
            DispatchQueue.main.async {
                self?.resultCollectionView.reloadData()
            }
        }
        
        if let history = historyItem {
            print("DEBUG: Loading from history - specieName: \(history.specieName)")
            if let match = viewModel.birdResults.first(where: { $0.commonName == history.specieName }) {
                selectedResult = match
                print("DEBUG: Found match in birdResults: \(match.commonName)")
            } else if var dbBird = viewModel.getBird(byName: history.specieName) {
                dbBird.confidence = 1.0
                dbBird.scoreBreakdown = "From History"
                selectedResult = dbBird
                viewModel.birdResults = [selectedResult!]
                print("DEBUG: Loaded from DB: \(dbBird.commonName)")
            }
        } else {
//            print("DEBUG: Filtering birds - shape: \(viewModel.selectedShapeId ?? "nil"), size: \(viewModel.selectedSizeCategory ?? "nil"), location: \(viewModel.selectedLocation ?? "nil")")
//            print("DEBUG: fieldMarks count: \(viewModel.selectedFieldMarks?.count ?? 0)")
            viewModel.filterBirds(
                shape: viewModel.selectedShapeId,
                size: viewModel.selectedSizeCategory,
                location: viewModel.selectedLocation,
                fieldMarks: viewModel.selectedFieldMarks
            )
        }

        if let result = selectedResult,
           let index = viewModel.birdResults.firstIndex(where: { $0.id == result.id }) {
            selectedIndexPath = IndexPath(item: index, section: 0)
        }
        
        print("ResultViewController: \(viewModel.birdResults.count) birds loaded")
        resultCollectionView.reloadData()
    }
    
    private func setupCollectionViewLayout() {
        let layout = UICollectionViewFlowLayout()

        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)

        resultCollectionView.collectionViewLayout = layout
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {

        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return .zero
        }

        let minItemWidth: CGFloat = 120
        let maxItemsPerRow: CGFloat = 4
        let interItemSpacing = layout.minimumInteritemSpacing
        let sectionLeftInset = layout.sectionInset.left
        let sectionRightInset = layout.sectionInset.right

        let availableWidth = collectionView.bounds.width - sectionLeftInset - sectionRightInset
        
        var itemsPerRow: CGFloat = 1
        while true {
            let potentialTotalSpacing = interItemSpacing * (itemsPerRow - 1)
            let potentialWidth = (availableWidth - potentialTotalSpacing) / itemsPerRow
            if potentialWidth >= minItemWidth {
                itemsPerRow += 1
            } else {
                itemsPerRow -= 1
                break
            }
            if itemsPerRow == 0 {
                itemsPerRow = 1
                break
            }
        }
        
        if itemsPerRow < 1 { itemsPerRow = 1 }
        if itemsPerRow > maxItemsPerRow { itemsPerRow = maxItemsPerRow }

        let actualTotalSpacing = interItemSpacing * (itemsPerRow - 1)
        let itemWidth = (availableWidth - actualTotalSpacing) / itemsPerRow
        
        return CGSize(width: itemWidth, height: itemWidth * 1.4)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { [weak self] context in
            self?.resultCollectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    

    @IBAction func nextTapped(_ sender: Any) {
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
    }
  
    @IBAction func restartTapped(_ sender: Any) {
        delegate?.didTapLeftButton()
    }
    
    func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("DEBUG: numberOfItemsInSection returning \(viewModel.birdResults.count)")
        return viewModel.birdResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let result = viewModel.birdResults[indexPath.item]
        print("DEBUG: cellForItemAt loading bird: \(result.commonName), image: \(result.staticImageName)")
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ResultCollectionViewCell", for: indexPath) as! ResultCollectionViewCell
        
        let img = UIImage(named: result.staticImageName)
        let percentString = String(Int((result.confidence ?? 0.0) * 100))
        
        cell.configure(
            image: img,
            name: result.commonName,
            percentage: percentString
        )

        if selectedIndexPath == indexPath {
            cell.isSelectedCell = true
            cell.contentView.layer.borderWidth = 3
            cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
            cell.contentView.layer.cornerRadius = 12
            cell.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        } else {
            cell.isSelectedCell = false
            cell.contentView.layer.borderWidth = 1
            cell.contentView.layer.borderColor = UIColor.systemGray4.cgColor
            cell.contentView.layer.cornerRadius = 12
            cell.contentView.backgroundColor = .white
            
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
        guard let birdSelectionVC = storyboard.instantiateViewController(withIdentifier: "BirdSelectionViewController") as? BirdSelectionViewController else {
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
    
    private func convertToSavedBird(from result: Bird) -> Bird {
		return Bird(
			id: UUID(),
			name: result.name,
			scientificName: result.scientificName,
			staticImageName: result.staticImageName,
			validLocations: result.validLocations,
			validMonths: result.validMonths,
			rarity: result.rarity,
			fieldMarks: result.fieldMarks,
			confidence: result.confidence,
			scoreBreakdown: result.scoreBreakdown,
			isUserCreated: true,
			observationStatus: .toObserve
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
