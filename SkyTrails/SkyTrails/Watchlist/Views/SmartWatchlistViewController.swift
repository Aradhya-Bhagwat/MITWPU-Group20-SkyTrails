//
//  SmartWatchlistViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

enum WatchlistType {
    case myWatchlist
    case custom
    case shared
}

class SmartWatchlistViewController: UIViewController, UISearchBarDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var headerView: UIView! // Optional: To add shadow or styling
    
    // MARK: - Properties
    var watchlistType: WatchlistType = .custom
    var watchlistTitle: String = "Watchlist"
    
    // --- Data Source for My Watchlist (Multi-Section) ---
    var allWatchlists: [Watchlist] = []
    var filteredSections: [[Bird]] = []
    
    // --- Data Source for Custom/Shared (Single Section) ---
    var observedBirds: [Bird] = []
    var toObserveBirds: [Bird] = []
    var currentList: [Bird] = []
    
    // State
    var currentSegmentIndex: Int = 0 // 0 = Observed, 1 = To Observe
    var currentSortOption: SortOption = .nameAZ // Track sort option
    
    // Dependencies
    // var viewModel: WatchlistViewModel? // Removed
    var currentWatchlistId: UUID?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        		applyFilters()
        	}
            
            @IBAction func didTapEdit(_ sender: Any) {        guard let id = currentWatchlistId else { return }
        let manager = WatchlistManager.shared
        
        if watchlistType == .custom {
            if let watchlist = manager.watchlists.first(where: { $0.id == id }) {
                let vc = UIStoryboard(name: "Watchlist", bundle: nil).instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as! EditWatchlistDetailViewController
                vc.watchlistType = .custom
                // vc.viewModel = manager // Removed
                vc.watchlistToEdit = watchlist
                navigationController?.pushViewController(vc, animated: true)
            }
        } else if watchlistType == .shared {
            if let shared = manager.sharedWatchlists.first(where: { $0.id == id }) {
                let vc = UIStoryboard(name: "Watchlist", bundle: nil).instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as! EditWatchlistDetailViewController
                vc.watchlistType = .shared
                // vc.viewModel = manager // Removed
                vc.sharedWatchlistToEdit = shared
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh data
        let manager = WatchlistManager.shared
        if watchlistType == .myWatchlist {
            self.allWatchlists = manager.watchlists
            applyFilters()
        } else if let id = currentWatchlistId {
            if let updatedWatchlist = manager.watchlists.first(where: { $0.id == id }) {
                self.observedBirds = updatedWatchlist.observedBirds
                self.toObserveBirds = updatedWatchlist.toObserveBirds
                // Update Title
                self.title = updatedWatchlist.title
                applyFilters()
            } else if let updatedShared = manager.sharedWatchlists.first(where: { $0.id == id }) {
                self.observedBirds = updatedShared.observedBirds
                self.toObserveBirds = updatedShared.toObserveBirds
                // Update Title
                self.title = updatedShared.title
                applyFilters()
            }
        }
    }
    
    private func setupUI() {
        // 1. Navigation Bar Styling
        self.title = watchlistTitle
        self.view.backgroundColor = .systemGroupedBackground
        self.navigationItem.largeTitleDisplayMode = .never
        
        // 2. TableView Setup
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none // Cleaner look for card-style cells
        
        // 3. Search Bar Styling (Matching CustomWatchlistViewController)
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        
        // 4. Segmented Control Styling
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.setTitle("Observed", forSegmentAt: 0)
        segmentedControl.setTitle("To Observe", forSegmentAt: 1)
    }
    
    // MARK: - Filter Logic
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        currentSegmentIndex = sender.selectedSegmentIndex
        applyFilters()
    }
    
    func applyFilters() {
        let searchText = searchBar.text ?? ""
        let isObserved = (currentSegmentIndex == 0)
        
        if watchlistType == .myWatchlist {
            // Filter each watchlist in allWatchlists
            filteredSections = allWatchlists.map { watchlist in
                let source = isObserved ? watchlist.observedBirds : watchlist.toObserveBirds
                return source.filter { bird in
                    if searchText.isEmpty { return true }
                    return bird.name.lowercased().contains(searchText.lowercased())
                }
            }
        } else {
            // Single List Logic
            let sourceList = isObserved ? observedBirds : toObserveBirds
            currentList = sourceList.filter { bird in
                if searchText.isEmpty { return true }
                return bird.name.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Apply current sort
        sortBirds(by: currentSortOption)
    }
    
    func sortBirds(by option: SortOption) {
        currentSortOption = option
        
        // Helper to sort in-place
        let sortClosure: (Bird, Bird) -> Bool = { b1, b2 in
            switch option {
            case .nameAZ: return b1.name < b2.name
            case .nameZA: return b1.name > b2.name
            case .date:
                let d1 = b1.date.first ?? Date.distantPast
                let d2 = b2.date.first ?? Date.distantPast
                return d1 > d2 // Newest first
            case .rarity:
                let isRare1 = b1.rarity.contains(.rare)
                let isRare2 = b2.rarity.contains(.rare)
                return isRare1 && !isRare2
            }
        }
        
        if watchlistType == .myWatchlist {
            // Sort each section
            for i in 0..<filteredSections.count {
                filteredSections[i].sort(by: sortClosure)
            }
        } else {
            // Sort single list
            currentList.sort(by: sortClosure)
        }
        
        tableView.reloadData()
    }
    
    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilters()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    enum SortOption { case nameAZ, nameZA, date, rarity }
    
    @IBAction func didTapAdd(_ sender: Any) {
        // Only allow adding if we have a valid context (e.g. Custom Watchlist with an ID)
        guard let id = currentWatchlistId else {
            print("Cannot add: Missing Watchlist ID or context.")
            return
        }
        
        let alert = UIAlertController(title: "Add to Watchlist", message: nil, preferredStyle: .actionSheet)
        
        // 1. Add to Observed -> Direct Flow
        alert.addAction(UIAlertAction(title: "Add to Observed", style: .default, handler: { _ in
            // Direct call to show detail with nil bird (indicating Create Mode)
            self.showObservedDetail(bird: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "Add to Unobserved", style: .default, handler: { _ in
            self.showSpeciesSelection(mode: .unobserved)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popoverController = alert.popoverPresentationController {
            if let barButtonItem = sender as? UIBarButtonItem {
                popoverController.barButtonItem = barButtonItem
            } else if let sourceView = sender as? UIView {
                popoverController.sourceView = sourceView
                popoverController.sourceRect = sourceView.bounds
            } else {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
        }
        present(alert, animated: true)
    }
    
    // Helper to replace coordinator calls
    func showObservedDetail(bird: Bird?) {
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ObservedDetailViewController") as! ObservedDetailViewController
        vc.bird = bird
        vc.watchlistId = currentWatchlistId
        // vc.viewModel = self.viewModel // Removed
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func showSpeciesSelection(mode: WatchlistMode) {
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SpeciesSelectionViewController") as! SpeciesSelectionViewController
        vc.mode = mode
        // vc.viewModel = self.viewModel // Removed
        vc.targetWatchlistId = currentWatchlistId
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        showSortOptions(sender: sender)
    }
    
    private func showSortOptions(sender: UIButton) {
        let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Name (A-Z)", style: .default) { [weak self] _ in
            self?.sortBirds(by: .nameAZ)
        })
        
        alert.addAction(UIAlertAction(title: "Name (Z-A)", style: .default) { [weak self] _ in
            self?.sortBirds(by: .nameZA)
        })
        
        alert.addAction(UIAlertAction(title: "Date", style: .default) { [weak self] _ in
            self?.sortBirds(by: .date)
        })
        
        alert.addAction(UIAlertAction(title: "Rarity", style: .default) { [weak self] _ in
            self?.sortBirds(by: .rarity)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
            popoverController.permittedArrowDirections = .up // Optional: specify arrow direction
        }
        
        present(alert, animated: true)
    }
    
    
    private func addReminder(for bird: Bird) {
        // Implement logic to add reminder
        print("Adding reminder for bird: \(bird.name)")
    }
}

// MARK: - TableView Extensions
extension SmartWatchlistViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if watchlistType == .myWatchlist {
            return allWatchlists.count
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if watchlistType == .myWatchlist {
            return filteredSections[section].count
        }
        return currentList.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if watchlistType == .myWatchlist {
            let watchlist = allWatchlists[section]
            // Optional: Add count to header? e.g. "Title (5)"
            // For now, just title per requirements
            return watchlist.title
        }
        return nil
    }
    
    // Optional: Customize Header View if needed
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        header.textLabel?.textColor = .label
        // header.contentView.backgroundColor = .systemGroupedBackground
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Ensure you set this Identifier in Storyboard
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BirdSmartCell", for: indexPath) as? BirdSmartCell else {
            return UITableViewCell()
        }
        
        let bird: Bird
        if watchlistType == .myWatchlist {
            bird = filteredSections[indexPath.section][indexPath.row]
        } else {
            bird = currentList[indexPath.row]
        }
        
        cell.shouldShowAvatars = (watchlistType == .shared)
        
        cell.configure(with: bird)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100 // Or UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let bird: Bird
        let wId: UUID?
        
        if watchlistType == .myWatchlist {
            bird = filteredSections[indexPath.section][indexPath.row]
            wId = allWatchlists[indexPath.section].id
        } else {
            bird = currentList[indexPath.row]
            wId = currentWatchlistId
        }
        
        guard let id = wId else { return }
        
        // Always show Observed Detail as per new requirement (Move/Convert flow)
        // Pass bird and ID together to ensure correct ID is used
        performSegue(withIdentifier: "ShowObservedDetail", sender: (bird, id))
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let bird: Bird
        let wId: UUID?
        
        if watchlistType == .myWatchlist {
            bird = filteredSections[indexPath.section][indexPath.row]
            wId = allWatchlists[indexPath.section].id
        } else {
            bird = currentList[indexPath.row]
            wId = currentWatchlistId
        }
        
        guard let id = wId else { return nil }
        
        // Delete Action
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
            self?.deleteBird(bird, watchlistId: id)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        deleteAction.backgroundColor = .systemRed
        
        // Edit Action
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] (_, _, completion) in
            if self?.currentSegmentIndex == 1 {
                // To Observe -> Unobserved Detail
                self?.performSegue(withIdentifier: "ShowUnobservedDetailFromWatchlist", sender: (bird, id))
            } else {
                // Observed -> Observed Detail
                self?.performSegue(withIdentifier: "ShowObservedDetail", sender: (bird, id))
            }
            completion(true)
        }
        editAction.image = UIImage(systemName: "pencil") // Using pencil for edit
        editAction.backgroundColor = .systemBlue
        
        // Optional: Reminder Action for To Observe (if needed, keeping it as requested previously, but user only mentioned Edit/Delete specifically in this turn? 
        // User said "Rename info to edit...". Previously there was "Reminder". I'll keep Reminder if it doesn't conflict, or just strictly follow "Rename Info to Edit".
        // Let's keep Reminder for To Observe as it adds value and wasn't explicitly forbidden, just "Info" was renamed.
        
        var actions = [deleteAction, editAction]
        
        if currentSegmentIndex == 1 {
            let reminderAction = UIContextualAction(style: .normal, title: "Remind") { [weak self] (_, _, completion) in
                self?.addReminder(for: bird)
                completion(true)
            }
            reminderAction.image = UIImage(systemName: "bell")
            reminderAction.backgroundColor = .systemOrange
            actions.append(reminderAction)
        }
        
        return UISwipeActionsConfiguration(actions: actions)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        var targetBird: Bird?
        var targetId: UUID?
        
        if let bird = sender as? Bird {
            targetBird = bird
            targetId = self.currentWatchlistId
        } else if let tuple = sender as? (Bird, UUID) {
            targetBird = tuple.0
            targetId = tuple.1
        }
        
        if segue.identifier == "ShowObservedDetail",
           let vc = segue.destination as? ObservedDetailViewController,
           let bird = targetBird {
            vc.bird = bird
            vc.watchlistId = targetId
            // vc.viewModel = self.viewModel // Removed
        } else if segue.identifier == "ShowUnobservedDetailFromWatchlist",
                  let vc = segue.destination as? UnobservedDetailViewController,
                  let bird = targetBird {
            vc.bird = bird
            vc.watchlistId = targetId
            // vc.viewModel = self.viewModel // Removed
        }
    }
    
    // Updated deleteBird to use Manager
    private func deleteBird(_ bird: Bird, watchlistId: UUID) {
        let manager = WatchlistManager.shared
        manager.deleteBird(bird, from: watchlistId)
        
        // Refresh UI
        if watchlistType == .myWatchlist {
             // Reload all watchlists from Manager to get updated state
            self.allWatchlists = manager.watchlists
            applyFilters()
        } else {
             // Single Watchlist Refresh
             if let updatedWatchlist = manager.watchlists.first(where: { $0.id == watchlistId }) {
                 self.observedBirds = updatedWatchlist.observedBirds
                 self.toObserveBirds = updatedWatchlist.toObserveBirds
             } else if let updatedShared = manager.sharedWatchlists.first(where: { $0.id == watchlistId }) {
                 self.observedBirds = updatedShared.observedBirds
                 self.toObserveBirds = updatedShared.toObserveBirds
             }
             applyFilters()
        }
    }
}