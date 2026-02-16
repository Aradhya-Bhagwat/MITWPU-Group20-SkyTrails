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
class SmartWatchlistViewController: UIViewController, UISearchBarDelegate {
	
	private let manager = WatchlistManager.shared
	
		// MARK: - Outlets
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var searchBar: UISearchBar!
	@IBOutlet weak var segmentedControl: UISegmentedControl!
	@IBOutlet weak var headerView: UIView! // Optional: To add shadow or styling
	
		// MARK: - Properties
	var watchlistType: WatchlistPresentationMode = .custom
	var watchlistTitle: String = "Watchlist"
	var currentWatchlistId: UUID?
	
		// Data Source
	private var sourceWatchlists: [Watchlist] = []
	public var allWatchlists: [Watchlist] = []
	private var filteredSections: [[WatchlistEntry]] = []
	public var observedEntries: [WatchlistEntry] = []
	public var toObserveEntries: [WatchlistEntry] = []
	private var currentList: [WatchlistEntry] = []
	
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
		
			// Fetch fresh object to determine type, then pass ID
		if let watchlist = manager.getWatchlist(by: id) {
			vc.watchlistType = (watchlist.type == .shared) ? .shared : .custom
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
                    self.title = "My Watchlist"
                    self.currentWatchlistId = WatchlistConstants.myWatchlistID
                    self.sourceWatchlists = try manager.fetchWatchlists()
                    
                case .custom, .shared:
                    guard let id = currentWatchlistId else { return }
                    let observed = try manager.fetchEntries(watchlistID: id, status: .observed)
                    let toObserve = try manager.fetchEntries(watchlistID: id, status: .to_observe)
                    
                        // Get title safely
                    let title = (try? manager.getWatchlist(by: id))??.title ?? "Watchlist"
                    updateSingleWatchlistData(observed: observed, toObserve: toObserve, title: title)
                    
                case .allSpecies:
                        // This mode aggregates EVERYTHING
                    let allWls = try manager.fetchWatchlists()
                    var uniqueObserved: [WatchlistEntry] = []
                    var uniqueToObserve: [WatchlistEntry] = []
                    var seenObs = Set<String>()
                    var seenToObs = Set<String>()
                    
                    for wl in allWls {
                        let obs = try manager.fetchEntries(watchlistID: wl.id, status: .observed)
                        let toObs = try manager.fetchEntries(watchlistID: wl.id, status: .to_observe)
                        
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
                    
                    updateSingleWatchlistData(observed: uniqueObserved, toObserve: uniqueToObserve, title: "All Species")
            }
        } catch {
            print("❌ [SmartWatchlistViewController] Error refreshing data: \(error)")
        }
		
		applyFilters()
	}
	
	private func updateSingleWatchlistData(observed: [WatchlistEntry], toObserve: [WatchlistEntry], title: String) {
		self.observedEntries = observed
		self.toObserveEntries = toObserve
		self.title = title
	}
	
	private func setupUI() {
			// Navigation
		self.title = watchlistTitle
		self.view.backgroundColor = .systemGroupedBackground
		self.navigationItem.largeTitleDisplayMode = .never
		
		if watchlistType == .myWatchlist || watchlistType == .allSpecies {
			navigationItem.rightBarButtonItems = nil
		}
		
			// TableView
		tableView.delegate = self
		tableView.dataSource = self
		tableView.backgroundColor = .clear
		tableView.separatorStyle = .none
		
			// Search Bar
		searchBar.searchBarStyle = .minimal
		let searchIsDarkMode = traitCollection.userInterfaceStyle == .dark
		searchBar.searchTextField.backgroundColor = searchIsDarkMode ? .secondarySystemBackground : .systemBackground
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
			let filteredResults = sourceWatchlists.compactMap { watchlist -> (Watchlist, [WatchlistEntry])? in
				let entries = (try? manager.fetchEntries(watchlistID: watchlist.id, status: isObserved ? .observed : .to_observe)) ?? []
				let matching = entries.filter { entry in
					guard let bird = entry.bird else { return false }
					return searchText.isEmpty || bird.name.localizedCaseInsensitiveContains(searchText)
				}
				return matching.isEmpty ? nil : (watchlist, matching)
			}
			
			allWatchlists = filteredResults.map { $0.0 }
			filteredSections = filteredResults.map { $0.1 }
		} else {
			let sourceList = isObserved ? observedEntries : toObserveEntries
			currentList = sourceList.filter { entry in
				guard let bird = entry.bird else { return false }
				return searchText.isEmpty || bird.name.localizedCaseInsensitiveContains(searchText)
			}
		}
		
		sortBirds(by: currentSortOption)
	}
	
	func sortBirds(by option: SortOption) {
		currentSortOption = option
		
		if watchlistType == .myWatchlist {
			let sortClosure: (WatchlistEntry, WatchlistEntry) -> Bool = { e1, e2 in
				guard let b1 = e1.bird, let b2 = e2.bird else { return false }
				
				switch option {
					case .nameAZ: return b1.name < b2.name
					case .nameZA: return b1.name > b2.name
					case .date:
						let d1 = e1.observationDate ?? Date.distantPast
						let d2 = e2.observationDate ?? Date.distantPast
						return d1 > d2
					case .rarity:
						let r1 = (b1.rarityLevel == .rare || b1.rarityLevel == .very_rare) ? 1 : 0
						let r2 = (b2.rarityLevel == .rare || b2.rarityLevel == .very_rare) ? 1 : 0
						return r1 > r2
				}
			}
			
			for i in 0..<filteredSections.count {
				filteredSections[i].sort(by: sortClosure)
			}
		} else {
			let sortClosure: (WatchlistEntry, WatchlistEntry) -> Bool = { e1, e2 in
				guard let b1 = e1.bird, let b2 = e2.bird else { return false }
				
				switch option {
					case .nameAZ: return b1.name < b2.name
					case .nameZA: return b1.name > b2.name
					case .date:
						let d1 = e1.observationDate ?? Date.distantPast
						let d2 = e2.observationDate ?? Date.distantPast
						return d1 > d2
					case .rarity:
						let r1 = (b1.rarityLevel == .rare || b1.rarityLevel == .very_rare) ? 1 : 0
						let r2 = (b2.rarityLevel == .rare || b2.rarityLevel == .very_rare) ? 1 : 0
						return r1 > r2
				}
			}
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
		print("➕ [SmartWatchlistVC] didTapAdd() called")
		print("📋 [SmartWatchlistVC] Current watchlist ID: \(currentWatchlistId?.description ?? "nil")")
		
		guard currentWatchlistId != nil else {
			print("❌ [SmartWatchlistVC] No current watchlist ID, aborting")
			return
		}
		
		if currentSegmentIndex == 0 {
			print("👆 [SmartWatchlistVC] Segment is Observed — navigating to Add Observed")
			showObservedDetail(bird: nil)
		} else {
			print("👆 [SmartWatchlistVC] Segment is To Observe — navigating to Species Selection")
			showSpeciesSelection(mode: .unobserved)
		}
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
	
	private func deleteEntry(_ entry: WatchlistEntry) {
		manager.deleteEntry(entryId: entry.id)
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
		
		let entry = (watchlistType == .myWatchlist) ? filteredSections[indexPath.section][indexPath.row] : currentList[indexPath.row]
		
			// Map Entry to Cell Configuration
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
		let wId: UUID? = currentWatchlistId
		
		if watchlistType == .myWatchlist {
			entry = filteredSections[indexPath.section][indexPath.row]
		} else {
			entry = currentList[indexPath.row]
		}
		
		if watchlistType == .allSpecies { return nil } // Read only view usually
		
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
		
		if currentSegmentIndex == 1, let bird = entry.bird {
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
