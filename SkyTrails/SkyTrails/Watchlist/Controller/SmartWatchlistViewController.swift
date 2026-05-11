
import UIKit
import SwiftData

enum WatchlistPresentationMode {
	case myWatchlist
	case custom
	case shared
	case allSpecies
}

private enum SmartWatchlistFilterOption: Int {
	case all = 0
	case observed = 1
	case unobserved = 2
}

@MainActor
class SmartWatchlistViewController: UIViewController, UISearchBarDelegate {
	
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
	private var currentFilter: SmartWatchlistFilterOption = .all
	private var currentSortOption: SmartWatchlistSortOption = .nameAZ
    
    private var isShowingRecommendations = false
    private var recommendedBirds: [Bird] = []
    
    private var birdEntryViewModels: [BirdEntryCellViewModel] = []
    private var groupedEntryViewModels: [[BirdEntryCellViewModel]] = []
	
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
            isShowingRecommendations = false
            
            let result = try manager.filteringService.fetchEntriesForMode(
                mode: watchlistType,
                watchlistId: currentWatchlistId
            )
            
            observedEntries = result.observed
            toObserveEntries = result.toObserve
            navigationItem.title = result.title
            tabBarItem.title = "Watchlist"
            isShowingRecommendations = result.shouldShowRecommendations
            recommendedBirds = result.recommendedBirds
            
            // Special handling for myWatchlist mode - preserve sourceWatchlists assignment
            if watchlistType == .myWatchlist {
                sourceWatchlists = try manager.fetchWatchlists()
            }
        } catch {
            WatchlistLog.error("Failed to refresh smart watchlist data", error: error)
        }
		
		applyFilters()
	}
	
	private func setupUI() {
		self.navigationItem.title = watchlistTitle
		self.tabBarItem.title = "Watchlist"
		self.view.backgroundColor = .systemGroupedBackground
		self.navigationItem.largeTitleDisplayMode = .never
		
		if watchlistType == .myWatchlist || watchlistType == .allSpecies {
			navigationItem.rightBarButtonItems = nil
		} else {
            let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAdd(_:)))
            let editButton = UIBarButtonItem(image: UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(didTapEdit(_:)))
            
            navigationItem.rightBarButtonItems = [addButton, editButton]
        }
        
		tableView.delegate = self
		tableView.dataSource = self
		tableView.backgroundColor = .clear
		tableView.separatorStyle = .none
		searchBar.searchBarStyle = .minimal
		let searchIsDarkMode = traitCollection.userInterfaceStyle == .dark
		searchBar.searchTextField.backgroundColor = searchIsDarkMode ? .secondarySystemBackground : .systemBackground
		searchBar.delegate = self
		segmentedControl.selectedSegmentIndex = currentFilter.rawValue
		configureFilterButtonMenusIfAvailable()
	}

    @objc private func didTapClear() {
        guard let id = currentWatchlistId else { return }
        
        let alert = UIAlertController(
            title: "Clear Watchlist",
            message: "This will remove all birds from '\(watchlistTitle)'. The watchlist itself will be kept. Proceed?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            do {
                try self?.manager.clearWatchlist(id: id)
                self?.refreshData()
            } catch {
                WatchlistLog.error("Failed to clear watchlist", error: error)
            }
        })
        
        present(alert, animated: true)
	}

	@IBAction func segmentChanged(_ sender: UISegmentedControl) {
		currentFilter = SmartWatchlistFilterOption(rawValue: sender.selectedSegmentIndex) ?? .all
		applyFilters()
	}
	
	func applyFilters() {
		let searchText = searchBar.text ?? ""
		
        if isShowingRecommendations {
            tableView.reloadData()
            return
        }

		if watchlistType == .myWatchlist {
            do {
                let status = statusForCurrentFilter()
                let groupedResults = try manager.filteringService.fetchEntriesGroupedByWatchlist(
                    watchlists: sourceWatchlists,
                    status: status,
                    searchText: searchText.isEmpty ? nil : searchText,
                    sortOption: currentSortOption
                )
                
                allWatchlists = groupedResults.map { $0.0 }
                filteredSections = groupedResults.map { $0.1 }
                
                Task {
                    var allSectionViewModels: [[BirdEntryCellViewModel]] = []
                    for sectionEntries in filteredSections {
                        let viewModels = await manager.loadBirdEntryViewModels(
                            from: sectionEntries,
                            shouldShowAvatars: false
                        )
                        allSectionViewModels.append(viewModels)
                    }
                    self.groupedEntryViewModels = allSectionViewModels
                    tableView.reloadData()
                }
            } catch {
                allWatchlists = []
                filteredSections = []
                groupedEntryViewModels = []
            }
		} else {
            do {
                let result = try manager.filteringService.fetchFilteredEntries(
                    mode: watchlistType,
                    watchlistId: currentWatchlistId,
                    searchText: searchText.isEmpty ? nil : searchText,
                    sortOption: currentSortOption,
                    status: statusForCurrentFilter()
                )
                
                switch currentFilter {
                case .all:
                    currentList = result.observed + result.unobserved
                case .observed:
                    currentList = result.observed
                case .unobserved:
                    currentList = result.unobserved
                }
                
                Task {
                    let shouldShowAvatars = (watchlistType == .shared)
                    birdEntryViewModels = await manager.loadBirdEntryViewModels(
                        from: currentList,
                        shouldShowAvatars: shouldShowAvatars
                    )
                    tableView.reloadData()
                }
            } catch {
                currentList = []
                birdEntryViewModels = []
            }
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
		
		switch currentFilter {
		case .all:
			presentAddOptions(sender: sender)
		case .observed:
			showObservedDetail(bird: nil)
		case .unobserved:
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
		let options: [(String, SmartWatchlistSortOption)] = [
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
	private func makeSortAction(title: String, option: SmartWatchlistSortOption) -> UIAction {
		UIAction(
			title: title,
			state: currentSortOption == option ? .on : .off
		) { [weak self] _ in
			self?.currentSortOption = option
			self?.applyFilters()
			if let self = self {
				self.configureFilterButtonMenusIfAvailable()
			}
		}
	}

	private func statusForCurrentFilter() -> WatchlistEntryStatus? {
		switch currentFilter {
		case .all:
			return nil
		case .observed:
			return .observed
		case .unobserved:
			return .to_observe
		}
	}

	private func presentAddOptions(sender: Any) {
		let alert = UIAlertController(title: "Add Bird", message: nil, preferredStyle: .actionSheet)
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

	private func detailSegueIdentifier(for entry: WatchlistEntry) -> String {
		entry.status == .to_observe ? "ShowUnobservedDetailFromWatchlist" : "ShowObservedDetail"
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
        if isShowingRecommendations { return 1 }
		return watchlistType == .myWatchlist ? allWatchlists.count : 1
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isShowingRecommendations { return recommendedBirds.count }
        
        if watchlistType == .myWatchlist {
            return (section < groupedEntryViewModels.count) ? groupedEntryViewModels[section].count : filteredSections[section].count
        }
		return birdEntryViewModels.isEmpty ? currentList.count : birdEntryViewModels.count
	}
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isShowingRecommendations { return "Recommended For You" }
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
		
        if isShowingRecommendations {
            let bird = recommendedBirds[indexPath.row]
            cell.configure(with: bird)
            cell.shouldShowAvatars = false
            return cell
        }

        if watchlistType == .myWatchlist {
            if indexPath.section < groupedEntryViewModels.count, indexPath.row < groupedEntryViewModels[indexPath.section].count {
                let viewModel = groupedEntryViewModels[indexPath.section][indexPath.row]
                cell.configure(with: viewModel)
            } else {
                let entry = filteredSections[indexPath.section][indexPath.row]
                cell.shouldShowAvatars = false
                cell.configure(with: entry)
            }
        } else {
            if !birdEntryViewModels.isEmpty, indexPath.row < birdEntryViewModels.count {
                let viewModel = birdEntryViewModels[indexPath.row]
                cell.configure(with: viewModel)
            } else {
                let entry = currentList[indexPath.row]
                cell.shouldShowAvatars = (watchlistType == .shared)
                cell.configure(with: entry)
            }
        }
        
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
		
        if isShowingRecommendations {
            let bird = recommendedBirds[indexPath.row]
            showRecommendationAction(for: bird)
            return
        }

		let entry: WatchlistEntry
		
		if watchlistType == .myWatchlist {
			entry = filteredSections[indexPath.section][indexPath.row]
		} else {
			entry = currentList[indexPath.row]
		}
		
		performSegue(withIdentifier: detailSegueIdentifier(for: entry), sender: entry)
	}
	
		func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            if isShowingRecommendations { return nil }
            
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
			self.performSegue(withIdentifier: self.detailSegueIdentifier(for: entry), sender: entry)
			completion(true)
		}
		editAction.image = UIImage(systemName: "pencil")
		editAction.backgroundColor = .systemBlue
		
		var actions = [deleteAction, editAction]
		
		if entry.status == .to_observe, entry.bird != nil {
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
    
    private func showRecommendationAction(for bird: Bird) {
        let alert = UIAlertController(title: bird.name, message: "Add this bird to your watchlist?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Add to Observed", style: .default) { [weak self] _ in
            self?.addBirdToMyWatchlist(bird, observed: true)
        })
        
        alert.addAction(UIAlertAction(title: "Add to Find List", style: .default) { [weak self] _ in
            self?.addBirdToMyWatchlist(bird, observed: false)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func addBirdToMyWatchlist(_ bird: Bird, observed: Bool) {
        Task {
            do {
                let id = try await manager.ensureMyWatchlistExists()
                try manager.addBirds([bird], to: id, asObserved: observed)
                refreshData()
            } catch {
                WatchlistLog.error("Failed to add recommended bird to watchlist", error: error)
            }
        }
    }
}
