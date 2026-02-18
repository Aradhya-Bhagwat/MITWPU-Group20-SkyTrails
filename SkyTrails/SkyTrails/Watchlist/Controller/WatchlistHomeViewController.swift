	//
	//  WatchlistHomeViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 24/11/25.
	//

import UIKit

@MainActor
class WatchlistHomeViewController: UIViewController {
	
	private let repository: WatchlistRepository = WatchlistManager.shared
	
		// UI State
	private var myWatchlist: WatchlistSummaryDTO?
	private var customWatchlists: [WatchlistSummaryDTO] = []
	private var sharedWatchlists: [WatchlistSummaryDTO] = []
	private var globalStats: WatchlistStatsDTO?
	
		// MARK: - Types
	enum WatchlistSection: Int, CaseIterable {
		case myWatchlist
		case customWatchlist
		case sharedWatchlist
		
		var title: String {
			switch self {
				case .myWatchlist: return "My Watchlist"
				case .customWatchlist: return "Custom Watchlist"
				case .sharedWatchlist: return "Shared Watchlist"
			}
		}
	}
	
	private struct LayoutConstants {
		static let myWatchlistHeight: CGFloat = 280
		static let customWatchlistHeight: CGFloat = 280
		static let sharedWatchlistHeight: CGFloat = 140
		static let emptyStateHeight: CGFloat = 200
		static let headerHeight: CGFloat = 40
	}

	private var isMyWatchlistEmptyState: Bool {
		guard let watchlist = myWatchlist else { return true }
		return watchlist.stats.totalCount == 0
	}
	
	
	@IBOutlet weak var summaryCardCollectionView: UICollectionView!

	
		// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		setupCollectionView()
		
		
		loadData()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		loadData()
	}
	
	private func loadData() {
		print("📱 [ViewController] Starting loadData()...")
		Task {
			do {
				print("📱 [ViewController] Calling repository.loadDashboardData()...")
				let data = try await repository.loadDashboardData()
				
				print("📱 [ViewController] Data received:")
				print("   - My Watchlist: \(data.myWatchlist?.title ?? "nil")")
				print("   - Custom: \(data.custom.count) watchlists")
				print("   - Shared: \(data.shared.count) watchlists")
				print("   - Global Stats: \(data.globalStats.observedCount)/\(data.globalStats.totalCount)")
				self.myWatchlist = data.myWatchlist
				self.customWatchlists = data.custom
				self.sharedWatchlists = data.shared
				self.globalStats = data.globalStats
				
				print("📱 [ViewController] Reloading collection view...")
				self.summaryCardCollectionView.reloadData()
				print("📱 [ViewController] Collection view reloaded")
			} catch {
				print("❌ [ViewController] Error loading data: \(error)")
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
			// Headers - Use new header with plus button
		summaryCardCollectionView.register(
			UINib(nibName: "WatchlistSectionWithPlusCollectionReusableView", bundle: nil),
			forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
			withReuseIdentifier: WatchlistSectionWithPlusCollectionReusableView.identifier
		)
		
			// Cells
		let cells = [
			CustomWatchlistCollectionViewCell.identifier,
			SharedWatchlistCollectionViewCell.identifier,
			WatchlistActionCell.identifier
		]
		
		cells.forEach { identifier in
			summaryCardCollectionView.register(UINib(nibName: identifier, bundle: nil), forCellWithReuseIdentifier: identifier)
		}
		
		summaryCardCollectionView.register(
			UINib(nibName: MyWatchlistCollectionViewCell.identifier, bundle: nil),
			forCellWithReuseIdentifier: MyWatchlistCollectionViewCell.identifier
		)
		summaryCardCollectionView.register(
			UINib(nibName: WatchlitEmptyCollectionViewCell.identifier, bundle: nil),
			forCellWithReuseIdentifier: WatchlitEmptyCollectionViewCell.identifier
		)
		
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
		
		var selectedDTO: WatchlistSummaryDTO?
		
		switch sectionType {
			case .myWatchlist:
				if !isMyWatchlistEmptyState, indexPath.item == 0 {
					selectedDTO = myWatchlist
				}
			case .customWatchlist:
				if indexPath.item < customWatchlists.count {
					selectedDTO = customWatchlists[indexPath.item]
				}
			case .sharedWatchlist:
				if indexPath.item < sharedWatchlists.count {
					selectedDTO = sharedWatchlists[indexPath.item]
				}
		}
		
		if let dto = selectedDTO {
			showOptions(for: dto, at: indexPath)
		}
	}
	
	private func showOptions(for dto: WatchlistSummaryDTO, at indexPath: IndexPath) {
		let alert = UIAlertController(title: dto.title, message: nil, preferredStyle: .actionSheet)
		
		alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
			self?.navigateToEdit(watchlistId: dto.legacyUUID, type: dto.type)
		})
		
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
			Task {
				do {
					try await self?.repository.deleteWatchlist(id: dto.legacyUUID)
					self?.loadData()
				} catch {
					let errorAlert = UIAlertController(
						title: "Delete Failed",
						message: "Unable to delete watchlist. Please try again.",
						preferredStyle: .alert
					)
					errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
					self?.present(errorAlert, animated: true)
				}
			}
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
	
	private func showObservedDetail() {
		Task {
			do {
				let id = try await repository.ensureMyWatchlistExists()
				navigateToObserved(watchlistId: id)
			} catch {
				print("Failed to ensure My Watchlist exists: \(error)")
			}
		}
	}
	
	private func navigateToObserved(watchlistId: UUID) {
		let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = storyboard.instantiateViewController(withIdentifier: "ObservedDetailViewController") as? ObservedDetailViewController else { return }
		vc.bird = nil
		vc.watchlistId = watchlistId
		vc.shouldUseRuleMatching = true
		navigationController?.pushViewController(vc, animated: true)
	}
	
	private func showSpeciesSelection() {
		guard let watchlistId = myWatchlist?.legacyUUID else { return }
		
		let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = storyboard.instantiateViewController(withIdentifier: "SpeciesSelectionViewController") as? SpeciesSelectionViewController else { return }
		vc.mode = .unobserved
		vc.targetWatchlistId = watchlistId
		vc.shouldUseRuleMatching = true
		navigationController?.pushViewController(vc, animated: true)
	}
	
	
	
	
}

// MARK: - Navigation
extension WatchlistHomeViewController {
	
	private func navigateToEdit(watchlistId: UUID, type: WatchlistType) {
		let sb = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = sb.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
		
		vc.watchlistType = (type == .shared) ? .shared : .custom
		vc.watchlistIdToEdit = watchlistId
		
		navigationController?.pushViewController(vc, animated: true)
	}
	
	private func navigateToCreateWatchlist() {
		let sb = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = sb.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
		
		vc.watchlistType = .custom
		vc.watchlistIdToEdit = nil  // nil means creating a new watchlist
		
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
				
			} else if let dto = sender as? WatchlistSummaryDTO {
				if dto.type == .my_watchlist {
					destVC.watchlistType = .myWatchlist
					destVC.watchlistTitle = "My Watchlist"
				} else if dto.type == .shared {
					destVC.watchlistType = .shared
					destVC.watchlistTitle = dto.title
				} else {
					destVC.watchlistType = .custom
					destVC.watchlistTitle = dto.title
				}
				destVC.currentWatchlistId = dto.legacyUUID
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
		guard let sectionType = WatchlistSection(rawValue: section) else {
			print("❌ [DataSource] Invalid section: \(section)")
			return 0
		}
		
		let count: Int
		switch sectionType {
			case .myWatchlist:
				count = isMyWatchlistEmptyState ? myWatchlistEmptyStateActions().count : 3
			case .customWatchlist:
				count = customWatchlists.isEmpty ? 1 : customWatchlists.count
			case .sharedWatchlist:
				count = sharedWatchlists.count
		}
		
		print("📊 [DataSource] Section \(sectionType.title): \(count) items")
		return count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let sectionType = WatchlistSection(rawValue: indexPath.section) else {
			return collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
		}
		
		switch sectionType {
			case .myWatchlist:
				if isMyWatchlistEmptyState {
					return configureMyWatchlistEmptyStateCell(in: collectionView, at: indexPath)
				}
				if indexPath.item == 0 {
					return configureMyWatchlistCell(in: collectionView, at: indexPath)
				} else {
					let actionIndex = indexPath.item - 1
					if actionIndex == 0 {
						return configureAddBirdActionCell(in: collectionView, at: indexPath, title: "Add Observed", color: .systemGreen)
					} else {
						return configureAddBirdActionCell(in: collectionView, at: indexPath, title: "Add Unobserved", color: .systemOrange)
					}
				}
			case .customWatchlist:
				if customWatchlists.isEmpty {
					return configureWatchlistEmptyStateCell(
						in: collectionView,
						at: indexPath,
						title: "No custom watchlists yet",
						subtitle: "Create a watchlist to organize birds you want to track"
					)
				}
				return configureCustomWatchlistCell(in: collectionView, at: indexPath)
			case .sharedWatchlist:
				return configureSharedWatchlistCell(in: collectionView, at: indexPath)
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }
		
		switch sectionType {
			case .myWatchlist:
				if isMyWatchlistEmptyState {
					handleMyWatchlistEmptyStateAction(at: indexPath.item)
					return
				}
				if indexPath.item == 0 {
					if let wl = myWatchlist {
						performSegue(withIdentifier: "ShowSmartWatchlist", sender: wl)
					}
				} else {
					let actionIndex = indexPath.item - 1
					if actionIndex == 0 {
						showObservedDetail()
					} else {
						showSpeciesSelection()
					}
				}
				
			case .customWatchlist:
				guard !customWatchlists.isEmpty else { return }
				if indexPath.item < customWatchlists.count {
					performSegue(withIdentifier: "ShowSmartWatchlist", sender: customWatchlists[indexPath.item])
				}
				
			case .sharedWatchlist:
				guard !sharedWatchlists.isEmpty else { return }
				if indexPath.item < sharedWatchlists.count {
					performSegue(withIdentifier: "ShowSmartWatchlist", sender: sharedWatchlists[indexPath.item])
				}
		}
	}
}

// MARK: - Cell Configuration Helpers
extension WatchlistHomeViewController {

	private func myWatchlistEmptyStateActions() -> [(title: String, color: UIColor, icon: String, isEnabled: Bool)] {
		return [
			(title: "Add Observed", color: .systemGray, icon: "custom.bird.fill.badge.plus", isEnabled: false),
			(title: "Add Unobserved", color: .systemGray, icon: "custom.bird.fill.badge.plus", isEnabled: false),
			(title: "Create Watchlist", color: .systemBlue, icon: "custom.list.number.badge.plus", isEnabled: true)
		]
	}

	private func configureMyWatchlistEmptyStateCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: WatchlistActionCell.identifier, for: indexPath) as! WatchlistActionCell
		let actions = myWatchlistEmptyStateActions()
		guard actions.indices.contains(indexPath.item) else { return cell }
		let action = actions[indexPath.item]
		cell.configure(icon: action.icon, title: action.title, color: action.color)
		cell.isUserInteractionEnabled = action.isEnabled
		return cell
	}

	private func handleMyWatchlistEmptyStateAction(at index: Int) {
		let actions = myWatchlistEmptyStateActions()
		guard actions.indices.contains(index), actions[index].isEnabled else { return }
		switch index {
			case 0:
				showObservedDetail()
			case 1:
				showSpeciesSelection()
			case 2:
				navigateToCreateWatchlist()
			default:
				return
		}
	}
	
	private func configureAddBirdActionCell(in cv: UICollectionView, at indexPath: IndexPath, title: String, color: UIColor) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: WatchlistActionCell.identifier, for: indexPath) as! WatchlistActionCell
		cell.configure(
			icon: "custom.bird.fill.badge.plus",
			title: title,
			color: color
		)
		cell.isUserInteractionEnabled = true
		return cell
	}

	private func configureWatchlistEmptyStateCell(
		in cv: UICollectionView,
		at indexPath: IndexPath,
		title: String,
		subtitle: String
	) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(
			withReuseIdentifier: WatchlitEmptyCollectionViewCell.identifier,
			for: indexPath
		) as! WatchlitEmptyCollectionViewCell
		cell.configure(
			imageName: "watchlist_empty_bird",
			title: title,
			subtitle: subtitle
		)
		cell.isUserInteractionEnabled = false
		return cell
	}
	
	private func configureMyWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: MyWatchlistCollectionViewCell.reuseIdentifier, for: indexPath) as! MyWatchlistCollectionViewCell
		
		if let watchlist = myWatchlist {
			// Load images: bundled assets first, then user photos from disk
			let images = watchlist.previewImages.compactMap { imagePath -> UIImage? in
				// 1. Try bundled asset first
				if let bundledImage = UIImage(named: imagePath) {
					return bundledImage
				}
				// 2. Try loading from Documents/ObservedBirdPhotos/
				let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
				let photoDir = documentsDir.appendingPathComponent("ObservedBirdPhotos", isDirectory: true)
				let fileURL = photoDir.appendingPathComponent(imagePath)
				return UIImage(contentsOfFile: fileURL.path)
			}
			
			let data = WatchlistData(
				title: watchlist.title,
				images: images,
				totalCount: watchlist.stats.totalCount,
				observedCount: watchlist.stats.observedCount,
				totalImageCount: watchlist.stats.totalCount
			)
			
			cell.configure(with: data)
		}
		return cell
	}
	
	private func configureCustomWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as! CustomWatchlistCollectionViewCell
		
		if indexPath.item < customWatchlists.count {
			let dto = customWatchlists[indexPath.item]
			cell.configure(with: dto)
		}
		return cell
	}
	
	private func configureSharedWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath) as! SharedWatchlistCollectionViewCell
		
		if indexPath.item < sharedWatchlists.count {
			let dto = sharedWatchlists[indexPath.item]
			
			var image: UIImage? = nil
			if let path = dto.image {
				image = UIImage(named: path)
			}
			
			cell.configure(
				title: dto.title,
				location: dto.subtitle,
				dateRange: dto.dateText,
				mainImage: image,
				speciesCount: dto.stats.totalCount,
				observedCount: dto.stats.observedCount,
				userImages: [] // Placeholder
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
				case .myWatchlist: return self.layoutMyWatchlistSection()
				case .customWatchlist: return self.layoutCustomWatchlistSection(env: layoutEnvironment)
				case .sharedWatchlist: return self.layoutSharedWatchlistSection(env: layoutEnvironment)
			}
		}
	}
	
	private func layoutMyWatchlistSection() -> NSCollectionLayoutSection {
		if !isMyWatchlistEmptyState {
			// Layout: 80% MyWatchlist card + 20% vertical action cells
			
			// Main card item (80% width)
			let mainCardItem = NSCollectionLayoutItem(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(0.8),
					heightDimension: .fractionalHeight(1.0)
				)
			)
			mainCardItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4)
			
			// Action cell items (each takes 50% of vertical group)
			let actionItem = NSCollectionLayoutItem(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(1.0),
					heightDimension: .fractionalHeight(0.5)
				)
			)
			actionItem.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 0)
			
			// Vertical group for the 2 action cells (20% width)
			let actionGroup = NSCollectionLayoutGroup.vertical(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(0.2),
					heightDimension: .fractionalHeight(1.0)
				),
				subitems: [actionItem, actionItem]
			)
			
			// Horizontal container: main card + action group
			let containerGroup = NSCollectionLayoutGroup.horizontal(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(1.0),
					heightDimension: .absolute(LayoutConstants.myWatchlistHeight)
				),
				subitems: [mainCardItem, actionGroup]
			)
			
			let section = NSCollectionLayoutSection(group: containerGroup)
			section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
			section.boundarySupplementaryItems = [createHeader()]
			return section
			
			} else {
				// Layout: exact 8 + card + 8 + card + 8 + card + 8
				let actionCount = max(myWatchlistEmptyStateActions().count, 1)
				let actionGroup = NSCollectionLayoutGroup.custom(
					layoutSize: NSCollectionLayoutSize(
						widthDimension: .fractionalWidth(1.0),
						heightDimension: .absolute(140)
					)
				) { environment in
					let groupWidth = environment.container.effectiveContentSize.width
					let groupHeight = environment.container.effectiveContentSize.height
					let sideSpacing: CGFloat = 8
					let betweenSpacing: CGFloat = 8
					let totalSpacing = (sideSpacing * 2) + (betweenSpacing * CGFloat(max(actionCount - 1, 0)))
					let itemWidth = (groupWidth - totalSpacing) / CGFloat(actionCount)
					
					return (0..<actionCount).map { index in
						let x = sideSpacing + CGFloat(index) * (itemWidth + betweenSpacing)
						return NSCollectionLayoutGroupCustomItem(
							frame: CGRect(x: x, y: 0, width: itemWidth, height: groupHeight)
						)
					}
				}
				
				let section = NSCollectionLayoutSection(group: actionGroup)
				section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 20, trailing: 0)
				section.boundarySupplementaryItems = [createHeader()]
				return section
			}
		}
	
	private func layoutCustomWatchlistSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
		if customWatchlists.isEmpty {
			let item = NSCollectionLayoutItem(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(1.0),
					heightDimension: .fractionalHeight(1.0)
				)
			)
			let group = NSCollectionLayoutGroup.horizontal(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(1.0),
					heightDimension: .absolute(LayoutConstants.emptyStateHeight)
				),
				subitems: [item]
			)
			let section = NSCollectionLayoutSection(group: group)
			section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
			section.boundarySupplementaryItems = []
			return section
		}

		let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
		
		let containerWidth = env.container.effectiveContentSize.width
		let fraction: CGFloat = containerWidth > 700 ? 0.28 : 0.45
		
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction), heightDimension: .absolute(LayoutConstants.customWatchlistHeight))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.orthogonalScrollingBehavior = .continuous
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
		section.boundarySupplementaryItems = shouldShowHeader(for: .customWatchlist) ? [createHeader()] : []
		return section
	}
	
	private func layoutSharedWatchlistSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
		let containerWidth = env.container.effectiveContentSize.width
		let isWide = containerWidth > 700          // iPad / large-class width
		
		let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
			widthDimension: .fractionalWidth(1.0),
			heightDimension: .fractionalHeight(1.0)
		))
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)
		
		let groupSize = NSCollectionLayoutSize(
			widthDimension: .fractionalWidth(1.0),
			heightDimension: .absolute(LayoutConstants.sharedWatchlistHeight)
		)
		
		let group: NSCollectionLayoutGroup
		if isWide {
			// 2-column grid on iPad
			group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
			group.interItemSpacing = .fixed(12)
		} else {
			// Single column on iPhone
			group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 1)
		}
		
		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
		section.boundarySupplementaryItems = shouldShowHeader(for: .sharedWatchlist) ? [createHeader()] : []
		return section
	}

	private func shouldShowHeader(for sectionType: WatchlistSection) -> Bool {
		switch sectionType {
		case .customWatchlist:
			return !customWatchlists.isEmpty
		case .sharedWatchlist:
			return !sharedWatchlists.isEmpty
		default:
			return true
		}
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
			withReuseIdentifier: WatchlistSectionWithPlusCollectionReusableView.identifier,
			for: indexPath
		) as! WatchlistSectionWithPlusCollectionReusableView
		
		if let sectionType = WatchlistSection(rawValue: indexPath.section) {
			// Determine button visibility based on section
			var showChevron = false
			var showPlus = false
			
			switch sectionType {
			case .myWatchlist:
				// Show only title, no buttons
				showChevron = false
				showPlus = false
			case .customWatchlist:
				// Show both chevron and plus
				showChevron = shouldShowHeader(for: .customWatchlist)
				showPlus = shouldShowHeader(for: .customWatchlist)
			case .sharedWatchlist:
				// Show both chevron and plus
				showChevron = shouldShowHeader(for: .sharedWatchlist)
				showPlus = shouldShowHeader(for: .sharedWatchlist)
			}
			
			header.configure(
				title: shouldShowHeader(for: sectionType) ? sectionType.title : "",
				sectionIndex: indexPath.section,
				showChevron: showChevron,
				showPlus: showPlus,
				delegate: self,
				onPlusButtonTap: { [weak self] in
					guard let self = self, self.shouldShowHeader(for: sectionType) else { return }
					self.navigateToCreateWatchlist()
				}
			)
		}
		
		return header
	}
	
	func didTapSeeAll(in section: Int) {
		guard let sectionType = WatchlistSection(rawValue: section) else { return }
		guard shouldShowHeader(for: sectionType) else { return }
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
