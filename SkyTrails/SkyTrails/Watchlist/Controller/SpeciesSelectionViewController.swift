//
//  SpeciesSelectionViewController.swift
//  SkyTrails
//
//

import UIKit

@MainActor
class SpeciesSelectionViewController: UIViewController {

    private let manager = WatchlistManager.shared

    // MARK: - Constants
    private struct Constants {
        static let birdCellId = "BirdSmartCell"
        static let storyboardName = "Watchlist"
        static let unobservedVCId = "UnobservedDetailViewController"
        static let observedVCId = "ObservedDetailViewController"
        static let checkmarkIcon = "checkmark"
        static let plusIcon = "plus"
    }

    // MARK: - Outlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Properties
    var mode: WatchlistMode = .observed
    var targetWatchlistId: UUID?
    
    // Data Source
    private var allBirds: [Bird] = []
    private var filteredBirds: [Bird] = []
    private var selectedBirds: Set<UUID> = []
    
    // Wizard/Loop State
    private var birdQueue: [Bird] = []
    private var processedBirds: [Bird] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Select Species"
        view.backgroundColor = .systemBackground
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.separatorStyle = .none
        
        searchBar.delegate = self
        searchBar.placeholder = "Search species library..."
        searchBar.searchBarStyle = .minimal
        
        updateNextButton()
    }
    
    private func loadData() {
        // Flatten all birds from all watchlists to create a "Library"
        let allWatchlists = manager.fetchWatchlists()
        let allEntries = allWatchlists.flatMap { $0.entries ?? [] }
        let allBirdsFromEntries = allEntries.compactMap { $0.bird }
        
        // Deduplicate birds by ID
        var uniqueBirds: [Bird] = []
        var seenIDs: Set<UUID> = []
        
        for bird in allBirdsFromEntries {
            if !seenIDs.contains(bird.id) {
                uniqueBirds.append(bird)
                seenIDs.insert(bird.id)
            }
        }

        self.allBirds = uniqueBirds.sorted { $0.commonName < $1.commonName }
        self.filteredBirds = self.allBirds
        
        tableView.reloadData()
    }
    
    private func updateNextButton() {
        let iconName = selectedBirds.isEmpty ? Constants.plusIcon : Constants.checkmarkIcon
        let item = UIBarButtonItem(image: UIImage(systemName: iconName), style: .plain, target: self, action: #selector(didTapNext))
        navigationItem.rightBarButtonItem = item
        // Enable only if species are selected
        navigationItem.rightBarButtonItem?.isEnabled = !selectedBirds.isEmpty
    }
}

// MARK: - Navigation Loop Logic (Wizard Pattern)
extension SpeciesSelectionViewController {
    
    @objc private func didTapNext() {
        guard !selectedBirds.isEmpty else { return }
        
        // Filter the selected bird objects
        let birdsToProcess = allBirds.filter { selectedBirds.contains($0.id) }
        
        // Start the wizard loop
        startDetailLoop(birds: birdsToProcess)
    }
    
    private func startDetailLoop(birds: [Bird]) {
        self.birdQueue = birds
        self.processedBirds = []
        showNextInLoop()
    }
    
    private func showNextInLoop() {
        // 1. Check if Queue is empty (Base Case)
        guard !birdQueue.isEmpty else {
            finalizeLoop()
            return
        }
        
        // 2. Process next bird
        let bird = birdQueue.removeFirst()
        showBirdDetail(bird: bird)
    }
    
    private func finalizeLoop() {
        // Since the Detail VCs handle their own saving to SwiftData via the manager,
        // we simply pop back to the watchlist view.
        navigationController?.popViewController(animated: true)
    }
    
    private func showBirdDetail(bird: Bird) {
        let storyboard = UIStoryboard(name: Constants.storyboardName, bundle: nil)
        var nextVC: UIViewController?
        
        if mode == .unobserved {
            if let vc = storyboard.instantiateViewController(withIdentifier: Constants.unobservedVCId) as? UnobservedDetailViewController {
                vc.bird = bird
                vc.watchlistId = targetWatchlistId
                vc.onSave = { [weak self] _ in
                    self?.showNextInLoop()
                }
                nextVC = vc
            }
        } else {
            if let vc = storyboard.instantiateViewController(withIdentifier: Constants.observedVCId) as? ObservedDetailViewController {
                vc.bird = bird
                vc.watchlistId = targetWatchlistId
                vc.onSave = { [weak self] _ in
                    self?.showNextInLoop()
                }
                nextVC = vc
            }
        }
        
        if let vc = nextVC {
            updateNavigationStack(pushing: vc)
        }
    }
    
    /// Manipulates the stack to replace the current detail view with the next one.
    /// This prevents the "Back" button from leading to the previous bird in the loop.
    private func updateNavigationStack(pushing newVC: UIViewController) {
        guard let navigationController = navigationController else { return }
        
        var vcs = navigationController.viewControllers
        
        // If the top VC is already a detail view, replace it
        if let last = vcs.last, (last is ObservedDetailViewController || last is UnobservedDetailViewController) {
            vcs.removeLast()
        }
        
        vcs.append(newVC)
        navigationController.setViewControllers(vcs, animated: true)
    }
}

// MARK: - UITableView DataSource & Delegate
extension SpeciesSelectionViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredBirds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Constants.birdCellId, for: indexPath) as? BirdSmartCell else {
            return UITableViewCell()
        }
        
        let bird = filteredBirds[indexPath.row]
        
        // Use a generic entry wrapper for the cell configuration
        cell.configure(with: bird)
        cell.shouldShowAvatars = false
        cell.dateLabel.isHidden = true
        
        // Display Rarity as the subtitle in this mode
        let rarityString = bird.rarityLevel?.rawValue.capitalized
        cell.locationLabel.text = "Rarity: \(rarityString)"
        cell.locationLabel.textColor = .secondaryLabel
        
        // Selection State UI
        let isSelected = selectedBirds.contains(bird.id)
        cell.accessoryType = isSelected ? .checkmark : .none
        cell.backgroundColor = isSelected ? .systemBlue.withAlphaComponent(0.05) : .clear
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let bird = filteredBirds[indexPath.row]
        if selectedBirds.contains(bird.id) {
            selectedBirds.remove(bird.id)
        } else {
            selectedBirds.insert(bird.id)
        }
        
        tableView.reloadRows(at: [indexPath], with: .none)
        updateNextButton()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}

// MARK: - UISearchBar Delegate
extension SpeciesSelectionViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredBirds = allBirds
        } else {
            filteredBirds = allBirds.filter { $0.commonName.localizedCaseInsensitiveContains(searchText) }
        }
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
