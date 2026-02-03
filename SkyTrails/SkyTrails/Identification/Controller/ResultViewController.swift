import UIKit

class ResultViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ResultCellDelegate {

    
    @IBOutlet weak var resultCollectionView: UICollectionView!
    
    var viewModel: IdentificationManager!
    weak var delegate: IdentificationFlowStepDelegate?
    
    // When opened from history, this will be set to the selected session
    var historyItem: IdentificationSession?

   
    var selectedCandidate: IdentificationCandidate?
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

        
        viewModel.runFilter()
        
     
        if let firstCandidate = viewModel.results.first {
            selectedCandidate = firstCandidate
            selectedIndexPath = IndexPath(item: 0, section: 0)
        }
        
        resultCollectionView.reloadData()
    }
    
    private func setupCollectionViewLayout() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        resultCollectionView.collectionViewLayout = layout
    }

 

    @IBAction func nextTapped(_ sender: Any) {
        // Use the manager's built-in save functionality to persist to SwiftData
        viewModel.saveSession(winningCandidate: selectedCandidate)
        navigationController?.popToRootViewController(animated: true)
    }
  
    @IBAction func restartTapped(_ sender: Any) {
        delegate?.didTapLeftButton()
    }
    
   

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.results.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let candidate = viewModel.results[indexPath.item]
        let bird = candidate.bird
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ResultCollectionViewCell", for: indexPath) as! ResultCollectionViewCell
        
        let img = UIImage(named: bird?.staticImageName ?? "placeholder_bird")
        let percentString = String(Int(candidate.confidence * 100))
        
        cell.configure(
            image: img,
            name: bird?.commonName ?? "Unknown Bird",
            percentage: percentString
        )

        
        if selectedIndexPath == indexPath {
            cell.contentView.layer.borderWidth = 3
            cell.contentView.layer.borderColor = UIColor.systemBlue.cgColor
            cell.contentView.layer.cornerRadius = 12
            cell.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        }
        
        cell.delegate = self
        cell.indexPath = indexPath
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if selectedIndexPath == indexPath { return }
        
        var indexPathsToReload = [indexPath]
        if let oldPath = selectedIndexPath {
            indexPathsToReload.append(oldPath)
        }
        
        selectedCandidate = viewModel.results[indexPath.item]
        selectedIndexPath = indexPath
        
        collectionView.reloadItems(at: indexPathsToReload)
    }

   

    func didTapPredict(for cell: ResultCollectionViewCell) {
        guard let indexPath = cell.indexPath,
              let bird = viewModel.results[indexPath.item].bird else { return }
        
        let storyboard = UIStoryboard(name: "birdspred", bundle: nil)
        if let birdSelectionVC = storyboard.instantiateViewController(withIdentifier: "BirdSelectionViewController") as? BirdSelectionViewController {
            birdSelectionVC.selectedSpecies = [bird.id.uuidString]
            self.navigationController?.pushViewController(birdSelectionVC, animated: true)
        }
    }
    
    func didTapAddToWatchlist(for cell: ResultCollectionViewCell) {
        guard let indexPath = cell.indexPath,
              let bird = viewModel.results[indexPath.item].bird else { return }
        
        
     //   saveToWatchlist(bird: bird)
    }

//    private func saveToWatchlist(bird: Bird) {
//      
//        let manager = WatchlistManager.shared
//        if let defaultWatchlist = manager.watchlists.first {
//           
//            manager.addBirds([bird], to: defaultWatchlist.id, asObserved: false)
//            
//            let alert = UIAlertController(title: "Added", message: "\(bird.commonName) added to watchlist.", preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .default))
//            present(alert, animated: true)
//      }
  //  }
}

