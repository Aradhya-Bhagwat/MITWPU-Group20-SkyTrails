
import UIKit

@MainActor
class SpeciesSelectionViewController: UIViewController {

    private let manager = WatchlistManager.shared
    private struct Constants {
        static let birdCellId = "BirdSmartCell"
        static let storyboardName = "Watchlist"
        static let unobservedVCId = "UnobservedDetailViewController"
        static let observedVCId = "ObservedDetailViewController"
        static let checkmarkIcon = "checkmark"
    }
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    var mode: WatchlistMode = .observed
    var targetWatchlistId: UUID?
    var shouldUseRuleMatching: Bool = false
    
    private var allBirds: [Bird] = []
    private var filteredBirds: [Bird] = []
    private var selectedBirds: Set<UUID> = []
    
    private var coordinator: SpeciesSelectionCoordinator?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDataObservers()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func setupDataObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataLoaded(_:)),
            name: WatchlistManager.didLoadDataNotification,
            object: nil
        )
    }

    @objc private func handleDataLoaded(_ notification: Notification) {
        loadData()
    }
    private func setupUI() {
        title = "Select Species"
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        
        searchBar.delegate = self
        
        updateNextButton()
    }
    
    private func loadData() {
        self.allBirds = manager.fetchAllBirds()
        let searchText = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if searchText.isEmpty {
            self.filteredBirds = allBirds
        } else {
            self.filteredBirds = allBirds.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        tableView.reloadData()
    }
    
    private func updateNextButton() {
        if selectedBirds.isEmpty {
            navigationItem.rightBarButtonItem = nil
            return
        }
        let item = UIBarButtonItem(image: UIImage(systemName: Constants.checkmarkIcon), style: .plain, target: self, action: #selector(didTapNext))
        navigationItem.rightBarButtonItem = item
    }
}
extension SpeciesSelectionViewController {
    
    @objc private func didTapNext() {
        guard !selectedBirds.isEmpty else {
            return
        }
        
        let birdsToProcess = allBirds.filter { selectedBirds.contains($0.bird_id) }
        
        if coordinator == nil {
            coordinator = SpeciesSelectionCoordinator(
                navigationController: self.navigationController,
                targetWatchlistId: self.targetWatchlistId,
                shouldUseRuleMatching: self.shouldUseRuleMatching,
                mode: self.mode
            )
        }
        
        coordinator?.startDetailLoop(with: birdsToProcess)
    }
}
extension SpeciesSelectionViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredBirds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Constants.birdCellId, for: indexPath) as? BirdSmartCell else {
            return UITableViewCell()
        }
        
        let bird = filteredBirds[indexPath.row]
        
        cell.configure(with: bird)
        cell.shouldShowAvatars = false
        cell.dateLabel.isHidden = true
        cell.locationLabel.text = nil
		cell.accessoryType = selectedBirds.contains(bird.bird_id) ? .checkmark : .none
		if traitCollection.userInterfaceStyle == .dark {
			cell.backgroundColor = .secondarySystemBackground
			cell.contentView.backgroundColor = .secondarySystemBackground
		}
		
		return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let bird = filteredBirds[indexPath.row]
        if selectedBirds.contains(bird.bird_id) {
            selectedBirds.remove(bird.bird_id)
        } else {
            selectedBirds.insert(bird.bird_id)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
        updateNextButton()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}
extension SpeciesSelectionViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredBirds = allBirds
        } else {
            filteredBirds = allBirds.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
