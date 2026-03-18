
import UIKit
import SwiftData

enum WatchlistPresentationMode {
	case myWatchlist
	case custom
	case shared
	case allSpecies
}

@MainActor
class SmartWatchlistViewController: UIViewController, UISearchBarDelegate {
	private enum SortOption {
		case nameAZ
		case nameZA
		case newestFirst
		case month
		case startDate
		case endDate
		case rarity
	}
	
	private let manager = WatchlistManager.shared
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var searchBar: UISearchBar!
	@IBOutlet weak var segmentedControl: UISegmentedControl!
	@IBOutlet weak var headerView: UIView!
	var watchlistType: WatchlistPresentationMode = .custom
	var watchlistTitle: String = "Watchlist"
	var currentWatchlistId: UUID?
	private var sourceWatchlists: [Watchlist] = []
	public var allWatchlists: [Watchlist] = []
	private var filteredSections: [[WatchlistEntry]] = []
	public var observedEntries: [WatchlistEntry] = []
	public var toObserveEntries: [WatchlistEntry] = []
	private var currentList: [WatchlistEntry] = []
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
		if let watchlist = try? manager.getWatchlist(by: id) {
			vc.watchlistType = (watchlist.type == .shared) ? .shared : .custom
			vc.watchlistIdToEdit = id
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
        do {
            switch watchlistType {
                case .myWatchlist:
                    self.navigationItem.title = "Your Favorites"
                    self.tabBarItem.title = "Watchlist"
                    self.currentWatchlistId = WatchlistConstants.myWatchlistID
                    self.sourceWatchlists = try manager.fetchWatchlists()
                    
                case .custom, .shared:
                    guard let id = currentWatchlistId else { return }
                    let observed = try manager.fetchEntries(watchlistID: id, status: .observed)
                    let toObserve = try manager.fetchEntries(watchlistID: id, status: .to_observe)
                    let title = (try? manager.getWatchlist(by: id))??.title ?? "Watchlist"
                    updateSingleWatchlistData(observed: observed, toObserve: toObserve, title: title)
                    
                case .allSpecies:
                    let allWls = try manager.fetchWatchlists()
                    var uniqueObserved: [WatchlistEntry] = []
                    var uniqueToObserve: [WatchlistEntry] = []
                    var seenObs = Set<String>()
                    var seenToObs = Set<String>()
                    
                    for wl in allWls {
                        let obs = try manager.fetchEntries(watchlistID: wl.watchlist_id, status: .observed)
                        let toObs = try manager.fetchEntries(watchlistID: wl.watchlist_id, status: .to_observe)
                        
                        for entry in obs {
                            if let name = entry.bird?.name, !seenObs.contains(name) {
                                seenObs.insert(name)
                                uniqueObserved.append(entry)
                            }
                        }
                        for entry in toObs {
                            if let name = entry.bird?.name, !seenToObs.contains(name) {
                                seenToObs.insert(name)
                                uniqueToObserve.append(entry)
                            }
                        }
                    }
                    
                    updateSingleWatchlistData(observed: uniqueObserved, toObserve: uniqueToObserve, title: "Universal Index")
            }
        } catch {
        }
		
		applyFilters()
	}
	
	private func updateSingleWatchlistData(observed: [WatchlistEntry], toObserve: [WatchlistEntry], title: String) {
		self.observedEntries = observed
		self.toObserveEntries = toObserve
		self.navigationItem.title = title
		self.tabBarItem.title = "Watchlist"
	}
	
	private func setupUI() {
		self.navigationItem.title = watchlistTitle
		self.tabBarItem.title = "Watchlist"
		self.view.backgroundColor = .systemGroupedBackground
		self.navigationItem.largeTitleDisplayMode = .never
		
		if watchlistType == .myWatchlist || watchlistType == .allSpecies {
			navigationItem.rightBarButtonItems = nil
		}
		tableView.delegate = self
		tableView.dataSource = self
		tableView.backgroundColor = .clear
		tableView.separatorStyle = .none
		searchBar.searchBarStyle = .minimal
		let searchIsDarkMode = traitCollection.userInterfaceStyle == .dark
		searchBar.searchTextField.backgroundColor = searchIsDarkMode ? .secondarySystemBackground : .systemBackground
		searchBar.delegate = self
		segmentedControl.selectedSegmentIndex = 0
		segmentedControl.setTitle("Sightings", forSegmentAt: 0)
		segmentedControl.setTitle("To Discover", forSegmentAt: 1)
		if #available(iOS 14.0, *) {
			configureFilterButtonMenusIfAvailable()
		}
	}
	@IBAction func segmentChanged(_ sender: UISegmentedControl) {
		currentSegmentIndex = sender.selectedSegmentIndex
		applyFilters()
	}
	
	func applyFilters() {
		let searchText = searchBar.text ?? ""
		let isObserved = (currentSegmentIndex == 0)
		
		if watchlistType == .myWatchlist {
			let filteredResults = sourceWatchlists.compactMap { watchlist -> (Watchlist, [WatchlistEntry])? in
				let entries = (try? manager.fetchEntries(watchlistID: watchlist.watchlist_id, status: isObserved ? .observed : .to_observe)) ?? []
				let matching = entries.filter { entry in
					guard let bird = entry.bird else { return false }
					return searchText.isEmpty || bird.name.localizedCaseInsensitiveContains(searchText)
				}
				return matching.isEmpty ? nil : (watchlist, matching)
			}
			
			allWatchlists = filteredResults.map { $0.0 }
			filteredSections = filteredResults.map { sortEntries($0.1) }
		} else {
			let sourceList = isObserved ? observedEntries : toObserveEntries
			currentList = sourceList.filter { entry in
				guard let bird = entry.bird else { return false }
				return searchText.isEmpty || bird.name.localizedCaseInsensitiveContains(searchText)
			}
			currentList = sortEntries(currentList)
		}
		
        tableView.reloadData()
	}
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
		
		if currentSegmentIndex == 0 {
			showObservedDetail(bird: nil)
		} else {
			showSpeciesSelection(mode: .unobserved)
		}
	}
	
	private func showObservedDetail(bird: Bird?) {
		let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = storyboard.instantiateViewController(withIdentifier: "ObservedDetailViewController") as? ObservedDetailViewController else { return }
		vc.bird = bird
		vc.watchlistId = currentWatchlistId
		vc.shouldUseRuleMatching = false
		navigationController?.pushViewController(vc, animated: true)
	}
	
	private func showSpeciesSelection(mode: WatchlistMode) {
		let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = storyboard.instantiateViewController(withIdentifier: "SpeciesSelectionViewController") as? SpeciesSelectionViewController else { return }
		vc.mode = mode
		vc.targetWatchlistId = currentWatchlistId
		vc.shouldUseRuleMatching = false
		navigationController?.pushViewController(vc, animated: true)
	}
	
	@IBAction func filterButtonTapped(_ sender: UIButton) {
		guard #unavailable(iOS 14.0) else { return }
		let alert = UIAlertController(title: "Filter", message: nil, preferredStyle: .actionSheet)
		let options: [(String, SortOption)] = [
			("Name (A to Z)", .nameAZ),
			("Name (Z to A)", .nameZA),
			("Month", .month),
			("Start Date", .startDate),
			("End date", .endDate),
			("Rarity", .rarity),
			("Recently Added", .newestFirst)
		]
		for (title, option) in options {
			alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
				self?.currentSortOption = option
				self?.applyFilters()
			}))
		}
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		configurePopover(for: alert, sender: sender)
		present(alert, animated: true)
	}

	@available(iOS 14.0, *)
	private func configureFilterButtonMenusIfAvailable() {
		let buttons = allButtons(in: view).filter { button in
			let actions = button.actions(forTarget: self, forControlEvent: .touchUpInside) ?? []
			return actions.contains("filterButtonTapped:")
		}
		for button in buttons {
			button.menu = buildFilterMenu()
			button.showsMenuAsPrimaryAction = true
		}
	}

	private func allButtons(in root: UIView) -> [UIButton] {
		var result: [UIButton] = []
		if let button = root as? UIButton {
			result.append(button)
		}
		for subview in root.subviews {
			result.append(contentsOf: allButtons(in: subview))
		}
		return result
	}

	@available(iOS 14.0, *)
	private func buildFilterMenu() -> UIMenu {
		return UIMenu(
			title: "Filter",
			children: [
				makeSortAction(title: "Name (A to Z)", option: .nameAZ),
				makeSortAction(title: "Name (Z to A)", option: .nameZA),
				makeSortAction(title: "Month", option: .month),
				makeSortAction(title: "Start Date", option: .startDate),
				makeSortAction(title: "End date", option: .endDate),
				makeSortAction(title: "Rarity", option: .rarity),
				makeSortAction(title: "Recently Added", option: .newestFirst)
			]
		)
	}

	@available(iOS 14.0, *)
	private func makeSortAction(title: String, option: SortOption) -> UIAction {
		UIAction(
			title: title,
			state: currentSortOption == option ? .on : .off
		) { [weak self] _ in
			self?.currentSortOption = option
			self?.applyFilters()
			if #available(iOS 14.0, *), let self = self {
				self.configureFilterButtonMenusIfAvailable()
			}
		}
	}

	private func sortEntries(_ entries: [WatchlistEntry]) -> [WatchlistEntry] {
		switch currentSortOption {
		case .nameAZ:
			return entries.sorted {
				($0.bird?.name ?? "").localizedCaseInsensitiveCompare($1.bird?.name ?? "") == .orderedAscending
			}
		case .nameZA:
			return entries.sorted {
				($0.bird?.name ?? "").localizedCaseInsensitiveCompare($1.bird?.name ?? "") == .orderedDescending
			}
		case .newestFirst:
			return entries.sorted { $0.addedDate > $1.addedDate }
		case .month:
			return entries.sorted { monthValue(for: $0) < monthValue(for: $1) }
		case .startDate:
			return entries.sorted {
				($0.toObserveStartDate ?? $0.observationDate ?? Date.distantFuture) <
				($1.toObserveStartDate ?? $1.observationDate ?? Date.distantFuture)
			}
		case .endDate:
			return entries.sorted {
				($0.toObserveEndDate ?? $0.observationDate ?? Date.distantFuture) <
				($1.toObserveEndDate ?? $1.observationDate ?? Date.distantFuture)
			}
		case .rarity:
			return entries.sorted { rarityRank(for: $0) < rarityRank(for: $1) }
		}
	}

	private func monthValue(for entry: WatchlistEntry) -> Int {
		if let observationDate = entry.observationDate {
			return Calendar.current.component(.month, from: observationDate)
		}
		if let startDate = entry.toObserveStartDate {
			return Calendar.current.component(.month, from: startDate)
		}
		return entry.bird?.validMonths?.min() ?? 13
	}

	private func rarityRank(for entry: WatchlistEntry) -> Int {
		let rarity = entry.bird?.conservation_status?.lowercased() ?? ""
		let order: [String: Int] = [
			"critically endangered": 0,
			"endangered": 1,
			"vulnerable": 2,
			"near threatened": 3,
			"least concern": 4
		]
		return order[rarity] ?? 5
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
	
	
	private func addReminder(for entry: WatchlistEntry) {
		let newValue = !entry.notify_upcoming
		try? manager.updateEntryNotifyUpcoming(entryId: entry.id, notify: newValue)
		refreshData()
	}
	
	private func deleteEntry(_ entry: WatchlistEntry) {
		try? manager.deleteEntry(entryId: entry.id)
		refreshData()
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		var targetBird: Bird?
		var targetId: UUID?
		
		if let entry = sender as? WatchlistEntry {
			targetBird = entry.bird
			targetId = self.currentWatchlistId
			
			if segue.identifier == "ShowObservedDetail",
			   let vc = segue.destination as? ObservedDetailViewController {
				vc.entry = entry
				vc.bird = entry.bird
				vc.watchlistId = targetId
				return
			} else if segue.identifier == "ShowUnobservedDetailFromWatchlist",
				let vc = segue.destination as? UnobservedDetailViewController {
				vc.entry = entry
				vc.bird = entry.bird
				vc.watchlistId = targetId
				return
			}
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
		
		let entry = (watchlistType == .myWatchlist) ? filteredSections[indexPath.section][indexPath.row] : currentList[indexPath.row]
		cell.shouldShowAvatars = (watchlistType == .shared)
		cell.configure(with: entry)
		if traitCollection.userInterfaceStyle == .dark {
			cell.backgroundColor = .secondarySystemBackground
			cell.contentView.backgroundColor = .secondarySystemBackground
		}
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 100
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		let entry: WatchlistEntry
		
		if watchlistType == .myWatchlist {
			entry = filteredSections[indexPath.section][indexPath.row]
		} else {
			entry = currentList[indexPath.row]
		}
		
		performSegue(withIdentifier: "ShowObservedDetail", sender: entry)
	}
	
		func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
			let entry: WatchlistEntry
			
			if watchlistType == .myWatchlist {			entry = filteredSections[indexPath.section][indexPath.row]
		} else {
			entry = currentList[indexPath.row]
		}
		
		if watchlistType == .allSpecies { return nil }
		
		let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
			self?.deleteEntry(entry)
			completion(true)
		}
		deleteAction.image = UIImage(systemName: "trash")
		deleteAction.backgroundColor = .systemRed
		
		let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] (_, _, completion) in
			guard let self = self else { return }
			if self.currentSegmentIndex == 1 {
				self.performSegue(withIdentifier: "ShowUnobservedDetailFromWatchlist", sender: entry)
			} else {
				self.performSegue(withIdentifier: "ShowObservedDetail", sender: entry)
			}
			completion(true)
		}
		editAction.image = UIImage(systemName: "pencil")
		editAction.backgroundColor = .systemBlue
		
		var actions = [deleteAction, editAction]
		
		if currentSegmentIndex == 1, entry.bird != nil {
			let reminderAction = UIContextualAction(style: .normal, title: "Remind") { [weak self] (_, _, completion) in
				self?.addReminder(for: entry)
				completion(true)
			}
			let iconName = entry.notify_upcoming ? "bell.fill" : "bell"
			reminderAction.image = UIImage(systemName: iconName)
			reminderAction.backgroundColor = entry.notify_upcoming ? .systemGreen : .systemOrange
			
			actions.append(reminderAction)
		}
		
		return UISwipeActionsConfiguration(actions: actions)
	}
}
