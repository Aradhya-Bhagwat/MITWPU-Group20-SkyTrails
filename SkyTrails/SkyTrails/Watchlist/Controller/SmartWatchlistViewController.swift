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
    case allSpecies
}

@MainActor
class SmartWatchlistViewController: UIViewController, UISearchBarDelegate {

    private let manager = WatchlistManager.shared
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var headerView: UIView! // Optional: To add shadow or styling
    
    // MARK: - Properties
    var watchlistType: WatchlistType = .custom
    var watchlistTitle: String = "Watchlist"
    var currentWatchlistId: UUID?
    
    // Data Source
    public var allWatchlists: [Watchlist] = []
    private var filteredSections: [[Bird]] = []
    public var observedBirds: [Bird] = []
    public var toObserveBirds: [Bird] = []
    private var currentList: [Bird] = []
    
    // State
    private var currentSegmentIndex: Int = 0
    private var currentSortOption: SortOption = .nameAZ
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDataObservers()
        applyFilters()
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
            
    @IBAction func didTapEdit(_ sender: Any) {
        guard let id = currentWatchlistId else { return }
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        
        guard let vc = storyboard.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
        
        if watchlistType == .custom, let watchlist = manager.watchlists.first(where: { $0.id == id }) {
            vc.watchlistType = .custom
            vc.watchlistToEdit = watchlist
            navigationController?.pushViewController(vc, animated: true)
        } else if watchlistType == .shared, let shared = manager.sharedWatchlists.first(where: { $0.id == id }) {
            vc.watchlistType = .shared
            vc.sharedWatchlistToEdit = shared
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        manager.onDataLoaded { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshData()
            }
        }
    }
    
    private func refreshData() {
        switch watchlistType {
        case .myWatchlist:
            self.allWatchlists = manager.watchlists
            
        case .custom, .shared:
            guard let id = currentWatchlistId else { return }
            
            if let watchlist = manager.watchlists.first(where: { $0.id == id }) {
                updateSingleWatchlistData(observed: watchlist.observedBirds, toObserve: watchlist.toObserveBirds, title: watchlist.title)
            } else if let shared = manager.sharedWatchlists.first(where: { $0.id == id }) {
                updateSingleWatchlistData(observed: shared.observedBirds, toObserve: shared.toObserveBirds, title: shared.title)
            }
            
        case .allSpecies:
            var seen = Set<String>()
            var uniqueObserved: [Bird] = []
            var uniqueToObserve: [Bird] = []
            
            // Helper to process lists
            func process(_ birds: [Bird], target: inout [Bird]) {
                for bird in birds {
                    if !seen.contains(bird.name) {
                        seen.insert(bird.name)
                        target.append(bird)
                    }
                }
            }
            
            // Local
            for list in manager.watchlists {
                process(list.observedBirds, target: &uniqueObserved)
                process(list.toObserveBirds, target: &uniqueToObserve)
            }
            
            // Shared
            for list in manager.sharedWatchlists {
                process(list.observedBirds, target: &uniqueObserved)
                process(list.toObserveBirds, target: &uniqueToObserve)
            }
            
            updateSingleWatchlistData(observed: uniqueObserved, toObserve: uniqueToObserve, title: "All Species")
        }
        
        applyFilters()
    }
    
    private func updateSingleWatchlistData(observed: [Bird], toObserve: [Bird], title: String) {
        self.observedBirds = observed
        self.toObserveBirds = toObserve
        self.title = title
    }
    
    private func setupUI() {
        // Navigation
        self.title = watchlistTitle
        self.view.backgroundColor = .systemGroupedBackground
        self.navigationItem.largeTitleDisplayMode = .never
        
        // TableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        
        // Search Bar
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        
        // Segmented Control
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
            filteredSections = allWatchlists.map { watchlist in
                let source = isObserved ? watchlist.observedBirds : watchlist.toObserveBirds
                return source.filter { bird in
                    searchText.isEmpty || bird.name.localizedCaseInsensitiveContains(searchText)
                }
            }
        } else {
            let sourceList = isObserved ? observedBirds : toObserveBirds
            currentList = sourceList.filter { bird in
                searchText.isEmpty || bird.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        sortBirds(by: currentSortOption)
    }
    
    func sortBirds(by option: SortOption) {
        currentSortOption = option
        
        let sortClosure: (Bird, Bird) -> Bool = { b1, b2 in
            switch option {
            case .nameAZ: return b1.name < b2.name
            case .nameZA: return b1.name > b2.name
            case .date:
                let d1 = b1.observationDates?.first ?? Date.distantPast
                let d2 = b2.observationDates?.first ?? Date.distantPast
                return d1 > d2
            case .rarity:
                let isRare1 = b1.rarity?.contains(.rare) ?? false
                let isRare2 = b2.rarity?.contains(.rare) ?? false
                return isRare1 && !isRare2
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
    
    enum SortOption { case nameAZ, nameZA, date, rarity }

    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilters()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    @IBAction func didTapAdd(_ sender: Any) {
        guard currentWatchlistId != nil else {
            return
        }
        
        let alert = UIAlertController(title: "Add to Watchlist", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Add to Observed", style: .default) { [weak self] _ in
            self?.showObservedDetail(bird: nil)
        })
        
        alert.addAction(UIAlertAction(title: "Add to Unobserved", style: .default) { [weak self] _ in
            self?.showSpeciesSelection(mode: .unobserved)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        configurePopover(for: alert, sender: sender)
        present(alert, animated: true)
    }
    
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
    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        showSortOptions(sender: sender)
    }
    
    private func showSortOptions(sender: UIButton) {
        let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
        
        let options: [(String, SortOption)] = [
            ("Name (A-Z)", .nameAZ),
            ("Name (Z-A)", .nameZA),
            ("Date", .date),
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
    
    private func configurePopover(for alert: UIAlertController, sender: Any) {
        guard let popover = alert.popoverPresentationController else { return }
        
        if let barButtonItem = sender as? UIBarButtonItem {
            popover.barButtonItem = barButtonItem
        } else if let sourceView = sender as? UIView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
            popover.permittedArrowDirections = .any
        } else {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
    }
    
    
    private func addReminder(for bird: Bird) {
    }
    
    private func deleteBird(_ bird: Bird, watchlistId: UUID) {
        manager.deleteBird(bird, from: watchlistId)
        refreshData()
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
        
        if let bird = targetBird {
            if segue.identifier == "ShowObservedDetail",
               let vc = segue.destination as? ObservedDetailViewController {
                vc.bird = bird
                vc.watchlistId = targetId
            } else if segue.identifier == "ShowUnobservedDetailFromWatchlist",
                      let vc = segue.destination as? UnobservedDetailViewController {
                vc.bird = bird
                vc.watchlistId = targetId
            }
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension SmartWatchlistViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return watchlistType == .myWatchlist ? allWatchlists.count : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return watchlistType == .myWatchlist ? filteredSections[section].count : currentList.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return watchlistType == .myWatchlist ? allWatchlists[section].title : nil
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        header.textLabel?.textColor = .label
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BirdSmartCell", for: indexPath) as? BirdSmartCell else {
            return UITableViewCell()
        }
        
        let bird = (watchlistType == .myWatchlist) ? filteredSections[indexPath.section][indexPath.row] : currentList[indexPath.row]
        
        cell.shouldShowAvatars = (watchlistType == .shared)
        cell.configure(with: bird)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
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
            if watchlistType == .allSpecies {
                // Find ID
                if let list = manager.watchlists.first(where: { $0.birds.contains(where: { $0.name == bird.name }) }) {
                    wId = list.id
                } else if let shared = manager.sharedWatchlists.first(where: { $0.birds.contains(where: { $0.name == bird.name }) }) {
                    wId = shared.id
                } else {
                    wId = nil
                }
            } else {
                wId = currentWatchlistId
            }
        }
        
        guard let id = wId else { return }
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
            if watchlistType == .allSpecies {
                return nil
            }
            wId = currentWatchlistId
        }
        
        guard let id = wId else { return nil }
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
            self?.deleteBird(bird, watchlistId: id)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        deleteAction.backgroundColor = .systemRed
        
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] (_, _, completion) in
            guard let self = self else { return }
            if self.currentSegmentIndex == 1 {
                self.performSegue(withIdentifier: "ShowUnobservedDetailFromWatchlist", sender: (bird, id))
            } else {
                self.performSegue(withIdentifier: "ShowObservedDetail", sender: (bird, id))
            }
            completion(true)
        }
        editAction.image = UIImage(systemName: "pencil")
        editAction.backgroundColor = .systemBlue
        
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
}