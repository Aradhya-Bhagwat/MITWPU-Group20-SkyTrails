//
//  SmartWatchlistViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit
import SwiftData

enum WatchlistPresentationMode {
    case myWatchlist
    case custom
    case shared
    case allSpecies
}

@MainActor
class SmartWatchlistViewController: UIViewController {

    private let manager = WatchlistManager.shared
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var headerView: UIView!
    
    // MARK: - Properties
    var watchlistType: WatchlistPresentationMode = .custom
    var watchlistTitle: String = "Watchlist"
    var currentWatchlistId: UUID?
    
    // Data Source
    private var allWatchlists: [Watchlist] = []
    private var filteredSections: [[WatchlistEntry]] = []
    private var observedEntries: [WatchlistEntry] = []
    private var toObserveEntries: [WatchlistEntry] = []
    private var currentList: [WatchlistEntry] = []
    
    // State
    private var currentSegmentIndex: Int = 0
    private var currentSortOption: SortOption = .nameAZ
    
    enum SortOption { case nameAZ, nameZA, date, rarity }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDataObservers()
        refreshData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh data whenever the view is about to appear
        refreshData()
        
        manager.onDataLoaded { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshData()
            }
        }
    }

    // MARK: - Setup
    private func setupUI() {
        self.title = watchlistTitle
        self.view.backgroundColor = .systemGroupedBackground
        self.navigationItem.largeTitleDisplayMode = .never
        
        // TableView Configuration
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        
        // Search Bar Configuration
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.placeholder = "Search species..."
        
        // Segmented Control Configuration
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.setTitle("Observed", forSegmentAt: 0)
        segmentedControl.setTitle("To Observe", forSegmentAt: 1)
        
        // Setup Edit Button in Navigation Bar if not in "All Species" mode
        if watchlistType != .allSpecies {
            let editBtn = UIBarButtonItem(image: UIImage(systemName: "slider.horizontal.3"), style: .plain, target: self, action: #selector(didTapEdit))
            navigationItem.rightBarButtonItems?.insert(editBtn, at: 0)
        }
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
        refreshData()
    }

    // MARK: - Data Management
    private func refreshData() {
        switch watchlistType {
        case .myWatchlist:
            self.allWatchlists = manager.fetchWatchlists(type: .custom) + manager.fetchWatchlists(type: .my_watchlist)
            
        case .custom, .shared:
            guard let id = currentWatchlistId else { return }
            let observed = manager.fetchEntries(watchlistID: id, status: .observed)
            let toObserve = manager.fetchEntries(watchlistID: id, status: .to_observe)
            let watchlist = manager.getWatchlist(by: id)
            updateSingleWatchlistData(observed: observed, toObserve: toObserve, title: watchlist?.title ?? "Watchlist")
            
        case .allSpecies:
            let allWls = manager.fetchWatchlists()
            var uniqueObserved: [WatchlistEntry] = []
            var uniqueToObserve: [WatchlistEntry] = []
            var seenObs = Set<String>()
            var seenToObs = Set<String>()
            
            for wl in allWls {
                let obs = manager.fetchEntries(watchlistID: wl.id, status: .observed)
                let toObs = manager.fetchEntries(watchlistID: wl.id, status: .to_observe)
                
                for entry in obs {
                    if let name = entry.bird?.commonName, !seenObs.contains(name) {
                        seenObs.insert(name)
                        uniqueObserved.append(entry)
                    }
                }
                for entry in toObs {
                    if let name = entry.bird?.commonName, !seenToObs.contains(name) {
                        seenToObs.insert(name)
                        uniqueToObserve.append(entry)
                    }
                }
            }
            updateSingleWatchlistData(observed: uniqueObserved, toObserve: uniqueToObserve, title: "All Species")
        }
        
        applyFilters()
    }
    
    private func updateSingleWatchlistData(observed: [WatchlistEntry], toObserve: [WatchlistEntry], title: String) {
        self.observedEntries = observed
        self.toObserveEntries = toObserve
        self.title = title
    }

    // MARK: - Actions
    @objc @IBAction func didTapEdit(_ sender: Any) {
        guard let id = currentWatchlistId else { return }
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
        
        if let watchlist = manager.getWatchlist(by: id) {
            vc.watchlistType = (watchlist.type == .shared) ? .shared : .custom
            vc.watchlistToEdit = watchlist
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        currentSegmentIndex = sender.selectedSegmentIndex
        applyFilters()
    }
    
    @IBAction func didTapAdd(_ sender: Any) {
        guard currentWatchlistId != nil else { return }
        
        let alert = UIAlertController(title: "Add to Watchlist", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Log New Sighting", style: .default) { [weak self] _ in
            self?.showObservedDetail(bird: nil)
        })
        alert.addAction(UIAlertAction(title: "Add Species to Observe", style: .default) { [weak self] _ in
            self?.showSpeciesSelection(mode: .unobserved)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        configurePopover(for: alert, sender: sender)
        present(alert, animated: true)
    }

    @IBAction func filterButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
        let options: [(String, SortOption)] = [
            ("Name (A-Z)", .nameAZ),
            ("Name (Z-A)", .nameZA),
            ("Date (Newest)", .date),
            ("Rarity", .rarity)
        ]
        
        for (title, option) in options {
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.sortBirds(by: option)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configurePopover(for: alert, sender: sender)
        present(alert, animated: true)
    }

    // MARK: - Filter & Sort Logic
    func applyFilters() {
        let searchText = searchBar.text ?? ""
        let isObserved = (currentSegmentIndex == 0)
        
        if watchlistType == .myWatchlist {
            filteredSections = allWatchlists.map { watchlist in
                let entries = manager.fetchEntries(watchlistID: watchlist.id, status: isObserved ? .observed : .to_observe)
                return entries.filter { entry in
                    guard let bird = entry.bird else { return false }
                    return searchText.isEmpty || bird.commonName.localizedCaseInsensitiveContains(searchText)
                }
            }
        } else {
            let sourceList = isObserved ? observedEntries : toObserveEntries
            currentList = sourceList.filter { entry in
                guard let bird = entry.bird else { return false }
                return searchText.isEmpty || bird.commonName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        sortBirds(by: currentSortOption)
    }
    
    func sortBirds(by option: SortOption) {
        currentSortOption = option
        
        let sortClosure: (WatchlistEntry, WatchlistEntry) -> Bool = { e1, e2 in
            guard let b1 = e1.bird, let b2 = e2.bird else { return false }
            switch option {
            case .nameAZ: return b1.commonName < b2.commonName
            case .nameZA: return b1.commonName > b2.commonName
            case .date:
                return (e1.observationDate ?? Date.distantPast) > (e2.observationDate ?? Date.distantPast)
            case .rarity:
                return b1.rarityLevel?.rawValue ?? "0" > b2.rarityLevel?.rawValue ?? "1"
            }
        }
        
        if watchlistType == .myWatchlist {
            for i in 0..<filteredSections.count {
                filteredSections[i].sort(by: sortClosure)
            }
        } else {
            currentList.sort(by: sortClosure)
        }
        tableView.reloadData()
    }

    // MARK: - Navigation
    private func showObservedDetail(bird: Bird?) {
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "ObservedDetailViewController") as? ObservedDetailViewController else { return }
        vc.bird = bird
        vc.watchlistId = currentWatchlistId
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showSpeciesSelection(mode: WatchlistMode) {
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "SpeciesSelectionViewController") as? SpeciesSelectionViewController else { return }
        vc.mode = mode
        vc.targetWatchlistId = currentWatchlistId
        navigationController?.pushViewController(vc, animated: true)
    }

    private func configurePopover(for alert: UIAlertController, sender: Any) {
        if let popover = alert.popoverPresentationController {
            if let barButtonItem = sender as? UIBarButtonItem {
                popover.barButtonItem = barButtonItem
            } else if let sourceView = sender as? UIView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            }
        }
    }

    private func deleteEntry(_ entry: WatchlistEntry) {
        manager.deleteEntry(entryId: entry.id)
        refreshData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let entry = sender as? WatchlistEntry, let bird = entry.bird else { return }
        
        if segue.identifier == "ShowObservedDetail", let vc = segue.destination as? ObservedDetailViewController {
            vc.entry = entry
            vc.watchlistId = currentWatchlistId
        } else if segue.identifier == "ShowUnobservedDetailFromWatchlist", let vc = segue.destination as? UnobservedDetailViewController {
            vc.bird = bird
            vc.watchlistId = currentWatchlistId
        }
    }
}

// MARK: - UISearchBarDelegate
extension SmartWatchlistViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilters()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDelegate & DataSource
extension SmartWatchlistViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return watchlistType == .myWatchlist ? allWatchlists.count : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return watchlistType == .myWatchlist ? filteredSections[section].count : currentList.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return (watchlistType == .myWatchlist && !filteredSections[section].isEmpty) ? allWatchlists[section].title : nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BirdSmartCell", for: indexPath) as? BirdSmartCell else {
            return UITableViewCell()
        }
        let entry = (watchlistType == .myWatchlist) ? filteredSections[indexPath.section][indexPath.row] : currentList[indexPath.row]
        cell.shouldShowAvatars = (watchlistType == .shared)
        cell.configure(with: entry)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = (watchlistType == .myWatchlist) ? filteredSections[indexPath.section][indexPath.row] : currentList[indexPath.row]
        
        if currentSegmentIndex == 0 {
            performSegue(withIdentifier: "ShowObservedDetail", sender: entry)
        } else {
            performSegue(withIdentifier: "ShowUnobservedDetailFromWatchlist", sender: entry)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if watchlistType == .allSpecies { return nil }
        
        let entry = (watchlistType == .myWatchlist) ? filteredSections[indexPath.section][indexPath.row] : currentList[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
            self?.deleteEntry(entry)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] (_, _, completion) in
            if self?.currentSegmentIndex == 1 {
                self?.performSegue(withIdentifier: "ShowUnobservedDetailFromWatchlist", sender: entry)
            } else {
                self?.performSegue(withIdentifier: "ShowObservedDetail", sender: entry)
            }
            completion(true)
        }
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "pencil")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }
}
