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
    var shouldUseRuleMatching: Bool = false
    
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
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        
        searchBar.delegate = self
        
        updateNextButton()
    }
    
    private func loadData() {
        self.allBirds = manager.fetchAllBirds()
        self.filteredBirds = allBirds
        tableView.reloadData()
    }
    
    private func updateNextButton() {
        let iconName = selectedBirds.isEmpty ? Constants.plusIcon : Constants.checkmarkIcon
        let item = UIBarButtonItem(image: UIImage(systemName: iconName), style: .plain, target: self, action: #selector(didTapNext))
        navigationItem.rightBarButtonItem = item
        navigationItem.rightBarButtonItem?.isEnabled = !selectedBirds.isEmpty
    }
}

// MARK: - Navigation Loop Logic
extension SpeciesSelectionViewController {
    
    @objc private func didTapNext() {
        print("➡️  [SpeciesSelectionVC] didTapNext() called")
        print("📊 [SpeciesSelectionVC] Selected birds count: \(selectedBirds.count)")
        
        guard !selectedBirds.isEmpty else {
            print("⚠️  [SpeciesSelectionVC] No birds selected, returning")
            return
        }
        
        // Filter the selected bird objects
        let birdsToProcess = allBirds.filter { selectedBirds.contains($0.id) }
        
        print("🐦 [SpeciesSelectionVC] Birds to process:")
        birdsToProcess.forEach { print("  - \($0.commonName)") }
        print("📋 [SpeciesSelectionVC] Target watchlist ID: \(targetWatchlistId?.description ?? "nil")")
        print("🎯 [SpeciesSelectionVC] Mode: \(mode == .observed ? "observed" : "unobserved")")
        
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
        navigationController?.popViewController(animated: true)
    }
    
    private func showBirdDetail(bird: Bird) {
        let storyboard = UIStoryboard(name: Constants.storyboardName, bundle: nil)
        var nextVC: UIViewController?
        
        // Configure VC based on mode
        if mode == .unobserved {
            let vc = storyboard.instantiateViewController(withIdentifier: Constants.unobservedVCId) as! UnobservedDetailViewController
            vc.bird = bird
            vc.watchlistId = targetWatchlistId
            vc.shouldUseRuleMatching = shouldUseRuleMatching
            vc.onSave = { [weak self] savedBird in
                self?.handleSave(bird: savedBird)
            }
            nextVC = vc
        } else {
            let vc = storyboard.instantiateViewController(withIdentifier: Constants.observedVCId) as! ObservedDetailViewController
            vc.bird = bird
            vc.watchlistId = targetWatchlistId
            vc.shouldUseRuleMatching = shouldUseRuleMatching
            vc.onSave = { [weak self] savedBird in
                self?.handleSave(bird: savedBird)
            }
            nextVC = vc
        }
        
        guard let vc = nextVC else { return }
        updateNavigationStack(pushing: vc)
    }
    
    private func handleSave(bird: Bird) {
        print("✅ [SpeciesSelectionVC] handleSave() called for: \(bird.commonName)")
        print("📊 [SpeciesSelectionVC] Processed so far: \(processedBirds.count)")
        print("📊 [SpeciesSelectionVC] Remaining in queue: \(birdQueue.count)")
        
        processedBirds.append(bird)
        showNextInLoop()
    }
    
    /// Manipulates the stack to replace the current detail view with the next one,
    /// preventing a deep navigation stack (Wizard Pattern).
    private func updateNavigationStack(pushing newVC: UIViewController) {
        guard let navigationController = navigationController else { return }
        
        var vcs = navigationController.viewControllers
        
        // If the top VC is already a detail view, remove it so we replace it instead of stacking
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
        
        cell.configure(with: bird)
        cell.shouldShowAvatars = false
        cell.dateLabel.isHidden = true
        
        // Location label is unused in this screen now that rarity is removed
        cell.locationLabel.text = nil
		
		// Selection State
		cell.accessoryType = selectedBirds.contains(bird.id) ? .checkmark : .none
		if traitCollection.userInterfaceStyle == .dark {
			cell.backgroundColor = .secondarySystemBackground
			cell.contentView.backgroundColor = .secondarySystemBackground
		}
		
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
        
        // Efficiently reload only the tapped row to update the checkmark
        tableView.reloadRows(at: [indexPath], with: .automatic)
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
            filteredBirds = allBirds.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
