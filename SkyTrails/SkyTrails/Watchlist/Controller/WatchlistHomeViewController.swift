	//
	//  WatchlistHomeViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 24/11/25.
	//

import UIKit
import SwiftData

@MainActor
class WatchlistHomeViewController: UIViewController {

	private let manager = WatchlistManager.shared
    
    // Local Cache for UI
    private var myWatchlist: Watchlist?
    private var customWatchlists: [Watchlist] = []
    private var sharedWatchlists: [Watchlist] = []
	
		// MARK: - Types
	enum WatchlistSection: Int, CaseIterable {
		case summary
		case myWatchlist
		case customWatchlist
		case sharedWatchlist
		
		var title: String {
			switch self {
				case .summary: return "Summary"
				case .myWatchlist: return "My Watchlist"
				case .customWatchlist: return "Custom Watchlist"
				case .sharedWatchlist: return "Shared Watchlist"
			}
		}
	}
	
	private struct LayoutConstants {
		static let summaryHeight: CGFloat = 110
		static let myWatchlistHeight: CGFloat = 320
		static let customWatchlistHeight: CGFloat = 184
		static let sharedWatchlistHeight: CGFloat = 140
		static let headerHeight: CGFloat = 40
	}
	
	
	@IBOutlet weak var summaryCardCollectionView: UICollectionView!
	@IBOutlet weak var addFloatingButton: UIButton!
	
		// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		setupCollectionView()
		addFloatingButton.configuration = .glass()
		addFloatingButton.tintColor = .blue
		let image = UIImage(named: "custom.bird.fill.badge.plus")
		addFloatingButton.setImage(image, for: .normal)
	
		setupDataObservers()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		refreshDataIfNeeded()
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
		refreshDataIfNeeded()
	}
	
	private func refreshDataIfNeeded() {
		manager.onDataLoaded { [weak self] success in
			guard success, let self = self else { return }
            
            // Fetch Data
            self.myWatchlist = self.manager.fetchWatchlists(type: .my_watchlist).first
            self.customWatchlists = self.manager.fetchWatchlists(type: .custom)
            self.sharedWatchlists = self.manager.fetchWatchlists(type: .shared)
            
			DispatchQueue.main.async {
				self.summaryCardCollectionView.reloadData()
			}
		}
	}
	
		// MARK: - Setup
	private func setupUI() {
		self.title = "Watchlist"
		self.navigationItem.largeTitleDisplayMode = .always
	}
	
	private func setupCollectionView() {
			// Layout must be set before data source assignments
		summaryCardCollectionView.collectionViewLayout = createCompositionalLayout()
		summaryCardCollectionView.dataSource = self
		summaryCardCollectionView.delegate = self
		
		registerCells()
	}
	
	private func registerCells() {
			// Headers
		summaryCardCollectionView.register(
			UINib(nibName: WatchlistSectionHeaderCollectionReusableView.reuseIdentifier, bundle: nil),
			forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
			withReuseIdentifier: "WatchlistSectionHeaderCollectionReusableView"
		)
		
			// Cells
		let cells = [
			"SummaryCardCollectionViewCell",
			"MyWatchlistCollectionViewCell",
			CustomWatchlistCollectionViewCell.identifier,
			SharedWatchlistCollectionViewCell.identifier
		]
		
		cells.forEach { identifier in
			summaryCardCollectionView.register(UINib(nibName: identifier, bundle: nil), forCellWithReuseIdentifier: identifier)
		}
		
		summaryCardCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "PlaceholderCell")
	}
}

// MARK: - User Actions
extension WatchlistHomeViewController {
	
	@IBAction func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
		guard gesture.state == .began else { return }
		
		let point = gesture.location(in: summaryCardCollectionView)
		guard let indexPath = summaryCardCollectionView.indexPathForItem(at: point),
			  let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }
		
		switch sectionType {
			case .myWatchlist:
				if let watchlist = myWatchlist {
					showOptions(for: watchlist, at: indexPath)
				}
				
			case .customWatchlist:
				if indexPath.item < customWatchlists.count {
					let watchlist = customWatchlists[indexPath.item]
					showOptions(for: watchlist, at: indexPath)
				}
				
			case .sharedWatchlist:
				if let shared = sharedWatchlists[safe: indexPath.item] {
					showOptions(for: shared, at: indexPath)
				}
				
			default: break
		}
	}
	
	private func showOptions(for watchlist: Watchlist, at indexPath: IndexPath) {
		let alert = UIAlertController(title: watchlist.title, message: nil, preferredStyle: .actionSheet)
		
		alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
			self?.navigateToEdit(watchlist: watchlist)
		})
		
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
			self?.manager.deleteWatchlist(id: watchlist.id)
			self?.refreshDataIfNeeded()
		})
		
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		presentAlert(alert, at: indexPath)
	}
	
	private func presentAlert(_ alert: UIAlertController, at indexPath: IndexPath) {
		if let popover = alert.popoverPresentationController {
			if let cell = summaryCardCollectionView.cellForItem(at: indexPath) {
				popover.sourceView = cell
				popover.sourceRect = cell.bounds
			} else {
				popover.sourceView = summaryCardCollectionView
				popover.sourceRect = CGRect(x: summaryCardCollectionView.bounds.midX, y: summaryCardCollectionView.bounds.midY, width: 0, height: 0)
			}
		}
		present(alert, animated: true)
	}
	
	// MARK: - Floating Action Button
	@IBAction func addFloatingButtonTapped(_ sender: UIButton) {
		let alert = UIAlertController(title: "Add to watchlist", message: nil, preferredStyle: .actionSheet)
		
		alert.addAction(UIAlertAction(title: "Add to observed", style: .default) { [weak self] _ in
			self?.showObservedDetail()
		})
		
		alert.addAction(UIAlertAction(title: "Add to unobserved", style: .default) { [weak self] _ in
			self?.showSpeciesSelection()
		})
		
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		
		if let popover = alert.popoverPresentationController {
			popover.sourceView = sender
			popover.sourceRect = sender.bounds
		}
		
		present(alert, animated: true)
	}
	
	private func showObservedDetail() {
        // Use myWatchlist ID or create/fetch it via manager
        // For now, let's try to get My Watchlist from cache
        guard let watchlistId = myWatchlist?.id else {
            manager.addRoseRingedParakeetToMyWatchlist() // Triggers creation if missing
            refreshDataIfNeeded() // Async refresh, might not be ready immediately.
            return
        }
		
		let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = storyboard.instantiateViewController(withIdentifier: "ObservedDetailViewController") as? ObservedDetailViewController else { return }
		vc.bird = nil
		vc.watchlistId = watchlistId
		navigationController?.pushViewController(vc, animated: true)
	}
	
	private func showSpeciesSelection() {
		guard let watchlistId = myWatchlist?.id else { return }
		
		let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = storyboard.instantiateViewController(withIdentifier: "SpeciesSelectionViewController") as? SpeciesSelectionViewController else { return }
		vc.mode = .unobserved
		vc.targetWatchlistId = watchlistId
		navigationController?.pushViewController(vc, animated: true)
	}


	

}

// MARK: - Navigation
extension WatchlistHomeViewController {
	
	private func navigateToEdit(watchlist: Watchlist) {
		let sb = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = sb.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
        
        vc.watchlistType = (watchlist.type == .shared) ? .shared : .custom
        // vc.sharedWatchlistToEdit = ... // Logic removed as Watchlist is unified
        vc.watchlistToEdit = watchlist
        
		navigationController?.pushViewController(vc, animated: true)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
			// Handle Grid Segues
		if segue.identifier == "ShowCustomWatchlistGrid" || segue.identifier == "ShowSharedWatchlistGrid" {
			return
		}
		
			// Handle Detail Segue
		if segue.identifier == "ShowSmartWatchlist",
		   let destVC = segue.destination as? SmartWatchlistViewController {
			
			if let mode = sender as? String, mode == "allSpecies" {
				destVC.watchlistType = .allSpecies
				destVC.watchlistTitle = "All Species"
				
            } else if let watchlist = sender as? Watchlist {
                // Unified logic for all watchlist types
                if watchlist.type == .my_watchlist {
                    destVC.watchlistType = .myWatchlist
                    destVC.watchlistTitle = "My Watchlist"
                } else if watchlist.type == .shared {
                    destVC.watchlistType = .shared
                    destVC.watchlistTitle = watchlist.title ?? "Shared Watchlist"
                } else {
                    destVC.watchlistType = .custom
                    destVC.watchlistTitle = watchlist.title ?? "Custom Watchlist"
                }
                destVC.currentWatchlistId = watchlist.id
            }
		}
	}
}

// MARK: - UICollectionViewDataSource & Delegate
extension WatchlistHomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return WatchlistSection.allCases.count
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		guard let sectionType = WatchlistSection(rawValue: section) else { return 0 }
		
		switch sectionType {
			case .summary: return 0
			case .myWatchlist: return myWatchlist != nil ? 1 : 0
			case .customWatchlist: return min(6, customWatchlists.count)
			case .sharedWatchlist: return sharedWatchlists.count
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let sectionType = WatchlistSection(rawValue: indexPath.section) else {
			return collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
		}
		
		switch sectionType {
			case .summary:
				return configureSummaryCell(in: collectionView, at: indexPath, manager: manager)
			case .myWatchlist:
				return configureMyWatchlistCell(in: collectionView, at: indexPath, manager: manager)
			case .customWatchlist:
				return configureCustomWatchlistCell(in: collectionView, at: indexPath, manager: manager)
			case .sharedWatchlist:
				return configureSharedWatchlistCell(in: collectionView, at: indexPath, manager: manager)
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }
		
		switch sectionType {
			case .summary:
				if indexPath.item == 0 {
					performSegue(withIdentifier: "ShowSmartWatchlist", sender: "allSpecies")
				}
				
			case .myWatchlist:
                if let wl = myWatchlist {
                    performSegue(withIdentifier: "ShowSmartWatchlist", sender: wl)
                }
				
			case .customWatchlist:
				if indexPath.item < customWatchlists.count {
					performSegue(withIdentifier: "ShowSmartWatchlist", sender: customWatchlists[indexPath.item])
				}
				
			case .sharedWatchlist:
				if let sharedWatchlist = sharedWatchlists[safe: indexPath.item] {
					performSegue(withIdentifier: "ShowSmartWatchlist", sender: sharedWatchlist)
				}
				
			default: break
		}
	}
}

// MARK: - Cell Configuration Helpers
extension WatchlistHomeViewController {
	
	private func configureSummaryCell(in cv: UICollectionView, at indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: "SummaryCardCollectionViewCell", for: indexPath) as! SummaryCardCollectionViewCell
        
        // Dynamic stats calculation
        let observedCount = manager.fetchGlobalObservedCount()
        // For total species in watchlists (unique) or just total entries?
        // Assuming 'Watchlist' count means total species across lists for now
        // Or simply sum of all lists. Let's use total entries count for simplicity or add a manager method.
        // For now: Total observed, Total Custom Lists, Shared Lists?
        // The UI labels are "Watchlist", "Observed", "Rare"
        
        let allWatchlists = manager.fetchWatchlists()
        let totalEntriesCount = allWatchlists.reduce(0) { $0 + ($1.entries?.count ?? 0) }
        
        // Rare count: Iterate all observed entries and check rarity
        // This might be expensive on main thread for large datasets, consider optimizing later
        // or adding a cached property on Manager.
        var rareCount = 0
        for wl in allWatchlists {
            if let entries = wl.entries {
                for entry in entries {
                    if entry.status == .observed, let rarity = entry.bird?.rarityLevel, (rarity == .rare || rarity == .very_rare) {
                        rareCount += 1
                    }
                }
            }
        }
        
		let data = [
			(totalEntriesCount, "Watchlist", UIColor.systemGreen),
			(observedCount, "Observed", UIColor.systemBlue),
			(rareCount, "Rare", UIColor.systemOrange)
		]
		
		let item = data[indexPath.item]
		cell.configure(number: "\(item.0)", title: item.1, color: item.2)
		return cell
	}
	
	private func configureMyWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: "MyWatchlistCollectionViewCell", for: indexPath) as! MyWatchlistCollectionViewCell
		
		if let watchlist = myWatchlist {
            // Stats via Manager
            let stats = manager.getStats(for: watchlist.id)
			let observedCount = stats.observed
			let totalCount = stats.total
			let toObserveCount = totalCount - observedCount
			
            // Images from entries
            // Limit to 4
            let birds = (watchlist.entries ?? []).prefix(4).compactMap { $0.bird }
			let images = birds.compactMap { bird -> UIImage? in
                return UIImage(named: bird.staticImageName)
			}
			
			cell.configure(
				observedCount: observedCount,
				toObserveCount: toObserveCount,
				images: images
			)
		} else {
			cell.configure(
				observedCount: 0,
				toObserveCount: 0,
				images: []
			)
		}
		return cell
	}
	
	private func configureCustomWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as! CustomWatchlistCollectionViewCell
		
		if indexPath.item < customWatchlists.count {
			cell.configure(with: customWatchlists[indexPath.item])
		}
		return cell
	}
	
	private func configureSharedWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath) as! SharedWatchlistCollectionViewCell
		
		if let sharedItem = sharedWatchlists[safe: indexPath.item] {
            // Avatar placeholders
            let userImages: [UIImage] = [] // Placeholder
			
            let stats = manager.getStats(for: sharedItem.id)
            
            // Image
            var image: UIImage? = nil
            if let path = sharedItem.images?.first?.imagePath {
                image = UIImage(named: path)
            }
            
			cell.configure(
				title: sharedItem.title ?? "Shared Watchlist",
				location: sharedItem.location ?? "Unknown",
				dateRange: "Oct - Nov", // Format from dates if needed or use placeholder
				mainImage: image,
				speciesCount: stats.total,
                observedCount: stats.observed,
				userImages: userImages
			)
		}
		return cell
	}
}

// MARK: - Compositional Layout
extension WatchlistHomeViewController {
	
	private func createCompositionalLayout() -> UICollectionViewLayout {
		return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
			guard let self = self, let sectionType = WatchlistSection(rawValue: sectionIndex) else { return nil }
			
			switch sectionType {
				case .summary: return self.layoutSummarySection()
				case .myWatchlist: return self.layoutMyWatchlistSection()
				case .customWatchlist: return self.layoutCustomWatchlistSection(env: layoutEnvironment)
				case .sharedWatchlist: return self.layoutSharedWatchlistSection()
			}
		}
	}
	
	private func layoutSummarySection() -> NSCollectionLayoutSection {
		let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0/3.0), heightDimension: .fractionalHeight(1.0))
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
		
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.summaryHeight))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 20, trailing: 12)
		section.boundarySupplementaryItems = [createHeader()]
		return section
	}
	
	private func layoutMyWatchlistSection() -> NSCollectionLayoutSection {
		let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
		
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.myWatchlistHeight))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
		return section
	}
	
	private func layoutCustomWatchlistSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
		let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
		
		let containerWidth = env.container.effectiveContentSize.width
		let fraction: CGFloat = containerWidth > 700 ? 0.28 : 0.45
		
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction), heightDimension: .absolute(LayoutConstants.customWatchlistHeight))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.orthogonalScrollingBehavior = .continuous
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
		section.boundarySupplementaryItems = [createHeader()]
		return section
	}
	
	private func layoutSharedWatchlistSection() -> NSCollectionLayoutSection {
		let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)
		
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.sharedWatchlistHeight))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
		section.boundarySupplementaryItems = [createHeader()]
		return section
	}
	
	private func createHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
		let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.headerHeight))
		return NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
	}
}

// MARK: - Header Delegate
extension WatchlistHomeViewController: SectionHeaderDelegate {
	
	func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		guard kind == UICollectionView.elementKindSectionHeader else { return UICollectionReusableView() }
		
		let header = collectionView.dequeueReusableSupplementaryView(
			ofKind: kind,
			withReuseIdentifier: WatchlistSectionHeaderCollectionReusableView.reuseIdentifier,
			for: indexPath
		) as! WatchlistSectionHeaderCollectionReusableView
		
		if let sectionType = WatchlistSection(rawValue: indexPath.section) {
			let showChevron = (sectionType != .summary && sectionType != .myWatchlist)
			header.configure(title: sectionType.title, sectionIndex: indexPath.section, showSeeAll: showChevron, delegate: self)
		}
		
		return header
	}
	
	func didTapSeeAll(in section: Int) {
		guard let sectionType = WatchlistSection(rawValue: section) else { return }
		switch sectionType {
			case .customWatchlist:
				performSegue(withIdentifier: "ShowCustomWatchlistGrid", sender: self)
			case .sharedWatchlist:
				performSegue(withIdentifier: "ShowSharedWatchlistGrid", sender: self)
			default: break
		}
	}
}

// MARK: - Extensions

// Helper to avoid hardcoding reuse identifiers
extension UICollectionReusableView {
	static var reuseIdentifier: String {
		return String(describing: self)
	}
}

// Safe Array Access
extension Collection {
	subscript (safe index: Index) -> Element? {
		return indices.contains(index) ? self[index] : nil
	}
}
