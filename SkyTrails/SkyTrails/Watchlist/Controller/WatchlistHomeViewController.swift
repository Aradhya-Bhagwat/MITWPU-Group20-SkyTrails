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
		case quickActions
		case myWatchlist
		case customWatchlist
		case sharedWatchlist
		
		var title: String {
			switch self {
				case .quickActions: return "Quick Actions"
				case .myWatchlist: return "My Watchlist"
				case .customWatchlist: return "Custom Watchlist"
				case .sharedWatchlist: return "Shared Watchlist"
			}
		}
	}
	
	private struct LayoutConstants {
		static let quickActionsHeight: CGFloat = 140
		static let myWatchlistHeight: CGFloat = 280
		static let customWatchlistHeight: CGFloat = 280
		static let sharedWatchlistHeight: CGFloat = 140
		static let headerHeight: CGFloat = 40
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
			// Headers
		summaryCardCollectionView.register(
			UINib(nibName: WatchlistSectionHeaderCollectionReusableView.reuseIdentifier, bundle: nil),
			forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
			withReuseIdentifier: "WatchlistSectionHeaderCollectionReusableView"
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
				selectedDTO = myWatchlist
			case .customWatchlist:
				if indexPath.item < customWatchlists.count {
					selectedDTO = customWatchlists[indexPath.item]
				}
			case .sharedWatchlist:
				if indexPath.item < sharedWatchlists.count {
					selectedDTO = sharedWatchlists[indexPath.item]
				}
			default: break
		}
		
		if let dto = selectedDTO {
			showOptions(for: dto, at: indexPath)
		}
	}
	
	private func showOptions(for dto: WatchlistSummaryDTO, at indexPath: IndexPath) {
		let alert = UIAlertController(title: dto.title, message: nil, preferredStyle: .actionSheet)
		
		alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
			self?.navigateToEdit(watchlistId: dto.id, type: dto.type)
		})
		
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
			Task {
				do {
					try await self?.repository.deleteWatchlist(id: dto.id)
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
				destVC.currentWatchlistId = dto.id
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
			case .quickActions:
				count = 2
			case .myWatchlist:
				count = myWatchlist != nil ? 1 : 0
			case .customWatchlist:
				count = customWatchlists.count
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
			case .quickActions:
				return configureQuickActionCell(in: collectionView, at: indexPath)
			case .myWatchlist:
				return configureMyWatchlistCell(in: collectionView, at: indexPath)
			case .customWatchlist:
				return configureCustomWatchlistCell(in: collectionView, at: indexPath)
			case .sharedWatchlist:
				return configureSharedWatchlistCell(in: collectionView, at: indexPath)
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }
		
		switch sectionType {
			case .quickActions:
				if indexPath.item == 0 {
					navigateToCreateWatchlist()
				} else {
					let alert = UIAlertController(title: "Add to watchlist", message: nil, preferredStyle: .actionSheet)
					
					alert.addAction(UIAlertAction(title: "Add to observed", style: .default) { [weak self] _ in
						self?.showObservedDetail()
					})
					
					alert.addAction(UIAlertAction(title: "Add to unobserved", style: .default) { [weak self] _ in
						self?.showSpeciesSelection()
					})
					
					alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
					
					if let popover = alert.popoverPresentationController,
					   let sourceView = collectionView.cellForItem(at: indexPath) {
						popover.sourceView = sourceView
						popover.sourceRect = sourceView.bounds
					}
					
					present(alert, animated: true)
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
				if indexPath.item < sharedWatchlists.count {
					performSegue(withIdentifier: "ShowSmartWatchlist", sender: sharedWatchlists[indexPath.item])
				}
		}
	}
}

// MARK: - Cell Configuration Helpers
extension WatchlistHomeViewController {
	
	private func configureQuickActionCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: WatchlistActionCell.identifier, for: indexPath) as! WatchlistActionCell
		
		if indexPath.item == 0 {
			cell.configure(
				icon: "custom.list.bullet.badge.plus",
				title: "Create Watchlist",
				color: .systemYellow
			)
		} else {
			cell.configure(
				icon: "custom.bird.fill.badge.plus",
				title: "Add Bird",
				color: .systemRed
			)
		}
		return cell
	}
	
	private func configureMyWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let cell = cv.dequeueReusableCell(withReuseIdentifier: MyWatchlistCollectionViewCell.reuseIdentifier, for: indexPath) as! MyWatchlistCollectionViewCell
		
		if let watchlist = myWatchlist {
			let images = watchlist.previewImages.compactMap { UIImage(named: $0) }
			
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
				case .quickActions: return self.layoutQuickActionsSection()
				case .myWatchlist: return self.layoutMyWatchlistSection()
				case .customWatchlist: return self.layoutCustomWatchlistSection(env: layoutEnvironment)
				case .sharedWatchlist: return self.layoutSharedWatchlistSection(env: layoutEnvironment)
			}
		}
	}
	
	private func layoutQuickActionsSection() -> NSCollectionLayoutSection {
		let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1.0))
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
		
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.quickActionsHeight))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 20, trailing: 12)
		section.boundarySupplementaryItems = [createHeader()]
		return section
	}
	
	private func layoutMyWatchlistSection() -> NSCollectionLayoutSection {
		// Main watchlist card (full width)
		let itemSize = NSCollectionLayoutSize(
			widthDimension: .fractionalWidth(1.0),
			heightDimension: .fractionalHeight(1.0)
		)
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		
		let groupSize = NSCollectionLayoutSize(
			widthDimension: .fractionalWidth(1.0),
			heightDimension: .absolute(LayoutConstants.myWatchlistHeight)
		)
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
			group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
			group.interItemSpacing = .fixed(12)
		} else {
			// Single column on iPhone
			group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
		}
		
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
			let showChevron = (sectionType != .myWatchlist && sectionType != .quickActions)
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
