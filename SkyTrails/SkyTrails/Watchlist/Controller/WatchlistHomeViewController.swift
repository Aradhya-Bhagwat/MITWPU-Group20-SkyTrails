
import UIKit

@MainActor
class WatchlistHomeViewController: UIViewController {
	
	private let repository: WatchlistRepository = WatchlistManager.shared
	private var myWatchlist: WatchlistSummaryDTO?
	private var customWatchlists: [WatchlistSummaryDTO] = []
	private var sharedWatchlists: [WatchlistSummaryDTO] = []
	private var globalStats: WatchlistStatsDTO?
    
    private var myWatchlistViewModel: WatchlistCellViewModel?
    private var customWatchlistViewModels: [CustomWatchlistCellViewModel] = []
    
    private var isInitialLoad: Bool = true
    private var loadDataTask: Task<Void, Never>?
    
    private let profileLocationHeaderView = ProfileLocationHeaderView()
	enum WatchlistSection: Int, CaseIterable {
		case myWatchlist
		case customWatchlist
		case sharedWatchlist
		
		var title: String {
			switch self {
				case .myWatchlist: return "Summary"
				case .customWatchlist: return "Curated Watchlists"
				case .sharedWatchlist: return "Shared Watchlists"
			}
		}
	}
	
	private struct LayoutConstants {
		static let myWatchlistHeight: CGFloat = 280
		static let actionCellHeight: CGFloat = 130
		static let customWatchlistHeight: CGFloat = 220
		static let sharedWatchlistHeight: CGFloat = 140
		static let emptyStateHeight: CGFloat = 200
		static let headerHeight: CGFloat = 60
	}

	private var hasAnyWatchlist: Bool {
		!customWatchlists.isEmpty || !sharedWatchlists.isEmpty
	}

	private var isMyWatchlistEmptyState: Bool {
		if isInitialLoad { return false }
		guard let watchlist = myWatchlist else { return true }
		return watchlist.stats.totalCount == 0 && !hasAnyWatchlist
	}
	
	
	@IBOutlet weak var summaryCardCollectionView: UICollectionView!
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		setupCollectionView()
		setupProfileLocationHeaderView()
		setupDataObservers()
		
		loadData()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		configureNavigationBar()
		profileLocationHeaderView.refreshLocation()
		loadData()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		if AppTourManager.shared.isTourActive {
			AppTourManager.shared.trackViewControllerAppeared(self)
		} else {
			IdentificationTooltipManager.shared.scheduleStepByStepTooltips(in: self.view, steps: [
				(message: "Tap here to view your personal watchlist summary.",
				 targetProvider: { [weak self] in
					 self?.summaryCardCollectionView.cellForItem(at: IndexPath(item: 0, section: 0))
				 }),
				(message: "Tap 'Log Observation' to record a bird sighting.",
				 targetProvider: { [weak self] in
					 self?.summaryCardCollectionView.cellForItem(at: IndexPath(item: 1, section: 0))
				 }),
				(message: "Tap '+' in Curated Watchlists to create a new list.",
				 targetProvider: { [weak self] in
					 self?.summaryCardCollectionView.cellForItem(at: IndexPath(item: 0, section: 1))
				 })
			])
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		IdentificationTooltipManager.shared.cancelTooltip()
	}
	
	private func loadData() {
		guard loadDataTask == nil else { return }
		
		loadDataTask = Task {
			defer { loadDataTask = nil }
			do {
				let wasEmptyState = self.isMyWatchlistEmptyState
				let data = try await repository.loadDashboardData()
				self.myWatchlist = data.myWatchlist
				self.customWatchlists = data.custom
				self.sharedWatchlists = data.shared
				self.globalStats = data.globalStats
				
                if let manager = repository as? WatchlistManager {
                    async let myVM = manager.loadMyWatchlistViewModel()
                    async let customVMs = manager.loadCustomWatchlistViewModels(from: data.custom)
                    
                    let (myWatchlistVM, customWatchlistVMs) = await (
                        try? myVM,
                        customVMs
                    )
                    
                    self.myWatchlistViewModel = myWatchlistVM
                    self.customWatchlistViewModels = customWatchlistVMs
                }
                
				self.prefetchBirdImages()

				let wasInitialLoad = self.isInitialLoad
				self.isInitialLoad = false
				let isNowEmptyState = self.isMyWatchlistEmptyState
				
				if wasEmptyState != isNowEmptyState || wasInitialLoad {
					self.summaryCardCollectionView.setCollectionViewLayout(self.createCompositionalLayout(), animated: false)
				}
				self.summaryCardCollectionView.reloadData()
			} catch {
				self.isInitialLoad = false
                WatchlistLog.error("Failed to load watchlist dashboard data", error: error)
			}
		}
	}

	private func setupDataObservers() {
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleDataLoaded(_:)),
			name: WatchlistManager.didLoadDataNotification,
			object: nil
		)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleLocationChanged(_:)),
			name: LocationPreferences.locationDidChangeNotification,
			object: nil
		)
	}

	@objc private func handleDataLoaded(_ notification: Notification) {
		loadData()
	}

	@objc private func handleLocationChanged(_ notification: Notification) {
		profileLocationHeaderView.refreshLocation()
		loadData()
	}
	
	private func prefetchBirdImages() {
		var imageKeys: Set<String> = []
		
		if let myWatchlist = myWatchlist {
			imageKeys.formUnion(myWatchlist.previewImages)
		}
		
		for custom in customWatchlists {
			if let coverImage = custom.image {
				imageKeys.insert(coverImage)
			}
		}
		
		for shared in sharedWatchlists {
			if let coverImage = shared.image {
				imageKeys.insert(coverImage)
			}
		}
		let uniqueKeys = Array(imageKeys)
		Task.detached(priority: .background) {
			await IdentificationImageService.shared.prefetch(keys: uniqueKeys)
		}
	}
	private func setupUI() {
		self.navigationItem.title = "Watchlist"
		self.tabBarItem.title = "Watchlist"
	}
	
	private func setupProfileLocationHeaderView() {
		profileLocationHeaderView.onTap = { [weak self] in
			self?.navigateToProfile()
		}
        let heightConstraint = profileLocationHeaderView.heightAnchor.constraint(equalToConstant: 44)
        heightConstraint.priority = .init(999)
        heightConstraint.isActive = true
	}
	
	private func configureNavigationBar() {
		navigationItem.largeTitleDisplayMode = .always
		navigationController?.navigationBar.prefersLargeTitles = true
		navigationItem.rightBarButtonItem = UIBarButtonItem(customView: profileLocationHeaderView)
	}
	
	private func navigateToProfile() {
		let storyboard = UIStoryboard(name: "Profile", bundle: nil)
		if let profileVC = storyboard.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController {
			navigationController?.pushViewController(profileVC, animated: true)
		}
	}
	
	private func setupCollectionView() {
		view.sendSubviewToBack(summaryCardCollectionView)
		summaryCardCollectionView.contentInsetAdjustmentBehavior = .always
		summaryCardCollectionView.collectionViewLayout = createCompositionalLayout()
		summaryCardCollectionView.dataSource = self
		summaryCardCollectionView.delegate = self
		
		registerCells()
	}
	
	private func registerCells() {
		summaryCardCollectionView.register(
			UINib(nibName: "WatchlistSectionWithPlusCollectionReusableView", bundle: nil),
			forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
			withReuseIdentifier: WatchlistSectionWithPlusCollectionReusableView.identifier
		)
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
			UINib(nibName: WatchlistEmptyCollectionViewCell.identifier, bundle: nil),
			forCellWithReuseIdentifier: WatchlistEmptyCollectionViewCell.identifier
		)
		
		summaryCardCollectionView.register(SkeletonLoadingCell.self, forCellWithReuseIdentifier: "PlaceholderCell")
	}
}
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
                WatchlistLog.error("Failed to resolve My Watchlist ID", error: error)
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
extension WatchlistHomeViewController {
	
	private func navigateToEdit(watchlistId: UUID, type: WatchlistType) {
		let sb = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = sb.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
		
		vc.watchlistType = (type == .shared) ? .shared : .custom
		vc.watchlistIdToEdit = watchlistId
		
		navigationController?.pushViewController(vc, animated: true)
	}
	
	func navigateToCreateWatchlist() {
		let sb = UIStoryboard(name: "Watchlist", bundle: nil)
		guard let vc = sb.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
		
		vc.watchlistType = .custom
		vc.watchlistIdToEdit = nil
		
		navigationController?.pushViewController(vc, animated: true)
	}
	
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "ShowCustomWatchlistGrid" || segue.identifier == "ShowSharedWatchlistGrid" {
			return
		}
		if segue.identifier == "ShowSmartWatchlist",
		   let destVC = segue.destination as? SmartWatchlistViewController {
			
			if let mode = sender as? String, mode == "allSpecies" {
				destVC.watchlistType = .allSpecies
				destVC.watchlistTitle = "All Species"
				
			} else if let dto = sender as? WatchlistSummaryDTO {
				if dto.type == .my_watchlist {
					destVC.watchlistType = .myWatchlist
					destVC.watchlistTitle = "Summary"
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
extension WatchlistHomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return WatchlistSection.allCases.count
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		guard let sectionType = WatchlistSection(rawValue: section) else {
			return 0
		}
		
		if isInitialLoad {
			switch sectionType {
				case .myWatchlist: return 3
				case .customWatchlist: return 2
				case .sharedWatchlist: return 2
			}
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
		return count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let sectionType = WatchlistSection(rawValue: indexPath.section) else {
			return collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
		}
		
		if isInitialLoad {
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath) as! SkeletonLoadingCell
			cell.startAnimating()
			return cell
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
							return configureAddBirdActionCell(in: collectionView, at: indexPath, title: "Log Observation", color: .systemGreen, icon: "custom.bird.fill.badge.plus")
						} else {
							return configureAddBirdActionCell(in: collectionView, at: indexPath, title: "Species to observe", color: .systemOrange, icon: "custom.bird.badge.plus")
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
		IdentificationTooltipManager.shared.cancelTooltip()
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
extension WatchlistHomeViewController {

	private func myWatchlistEmptyStateActions() -> [(title: String, color: UIColor, icon: String, isEnabled: Bool)] {
		return [
			(title: "Record Sighting", color: .systemGray, icon: "custom.bird.fill.badge.plus", isEnabled: false),
			(title: "Species to observe", color: .systemGray, icon: "custom.bird.fill.badge.plus", isEnabled: false),
			(title: "Start New List", color: .systemBlue, icon: "custom.list.number.badge.plus", isEnabled: true)
		]
	}

	private func configureMyWatchlistEmptyStateCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let dequeuedCell = cv.dequeueReusableCell(withReuseIdentifier: WatchlistActionCell.identifier, for: indexPath)
		guard let cell = dequeuedCell as? WatchlistActionCell else { return dequeuedCell }
		let actions = myWatchlistEmptyStateActions()
		guard actions.indices.contains(indexPath.item) else { return cell }
		let action = actions[indexPath.item]
		cell.configure(icon: action.icon, title: action.title, color: action.color)
		cell.isUserInteractionEnabled = action.isEnabled
		cell.contentView.alpha = action.isEnabled ? 1.0 : 0.75
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
	
	private func configureAddBirdActionCell(in cv: UICollectionView, at indexPath: IndexPath, title: String, color: UIColor, icon: String) -> UICollectionViewCell {
		let dequeuedCell = cv.dequeueReusableCell(withReuseIdentifier: WatchlistActionCell.identifier, for: indexPath)
		guard let cell = dequeuedCell as? WatchlistActionCell else { return dequeuedCell }
		cell.configure(
			icon: icon,
			title: title,
			color: color
		)
		cell.isUserInteractionEnabled = true
		cell.contentView.alpha = 1.0
		return cell
	}

	private func configureWatchlistEmptyStateCell(
		in cv: UICollectionView,
		at indexPath: IndexPath,
		title: String,
		subtitle: String
	) -> UICollectionViewCell {
		let dequeuedCell = cv.dequeueReusableCell(
			withReuseIdentifier: WatchlistEmptyCollectionViewCell.identifier,
			for: indexPath
		)
		guard let cell = dequeuedCell as? WatchlistEmptyCollectionViewCell else { return dequeuedCell }
		cell.configure(
			imageName: "watchlist_empty_bird",
			title: title,
			subtitle: subtitle
		)
		cell.isUserInteractionEnabled = false
		return cell
	}
	
	private func configureMyWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let dequeuedCell = cv.dequeueReusableCell(withReuseIdentifier: MyWatchlistCollectionViewCell.identifier, for: indexPath)
		guard let cell = dequeuedCell as? MyWatchlistCollectionViewCell else { return dequeuedCell }
		
		if let viewModel = myWatchlistViewModel {
			cell.configure(with: viewModel)
		}
		return cell
	}
	
	private func loadImage(_ imagePath: String) -> UIImage? {
		let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let photoDir = documentsDir.appendingPathComponent("ObservedBirdPhotos", isDirectory: true)
		let fileURL = photoDir.appendingPathComponent(imagePath)
		if let diskImage = UIImage(contentsOfFile: fileURL.path) {
			return diskImage
		}
		return UIImage(named: imagePath)
	}
	
	private func configureCustomWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let dequeuedCell = cv.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath)
		guard let cell = dequeuedCell as? CustomWatchlistCollectionViewCell else { return dequeuedCell }
		
		if indexPath.item < customWatchlistViewModels.count {
			let viewModel = customWatchlistViewModels[indexPath.item]
			cell.configure(with: viewModel)
		} else if indexPath.item < customWatchlists.count {
			let dto = customWatchlists[indexPath.item]
			cell.configure(with: dto)
		}
		return cell
	}
	
	private func configureSharedWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
		let dequeuedCell = cv.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath)
		guard let cell = dequeuedCell as? SharedWatchlistCollectionViewCell else { return dequeuedCell }
		
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
				userImages: []
			)
		}
		return cell
	}
}
extension WatchlistHomeViewController: SectionHeaderDelegate {
	
	func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		guard kind == UICollectionView.elementKindSectionHeader else { return UICollectionReusableView() }
		
		let headerView = collectionView.dequeueReusableSupplementaryView(
			ofKind: kind,
			withReuseIdentifier: WatchlistSectionWithPlusCollectionReusableView.identifier,
			for: indexPath
		)
		guard let header = headerView as? WatchlistSectionWithPlusCollectionReusableView else { return headerView }
		
		if let sectionType = WatchlistSection(rawValue: indexPath.section) {
			var showChevron = false
			var showPlus = false
			
			switch sectionType {
			case .myWatchlist:
				showChevron = true
				showPlus = false
			case .customWatchlist:
				showChevron = shouldShowHeader(for: .customWatchlist)
				showPlus = shouldShowHeader(for: .customWatchlist)
			case .sharedWatchlist:
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
			case .myWatchlist:
				if let wl = myWatchlist {
					performSegue(withIdentifier: "ShowSmartWatchlist", sender: wl)
				}
			case .customWatchlist:
				performSegue(withIdentifier: "ShowCustomWatchlistGrid", sender: self)
			case .sharedWatchlist:
				performSegue(withIdentifier: "ShowSharedWatchlistGrid", sender: self)
		}
	}
}
extension UICollectionReusableView {
	static var reuseIdentifier: String {
		return String(describing: self)
	}
}

// MARK: - Programmatic Collection Layout
extension WatchlistHomeViewController {
	private func createCompositionalLayout() -> UICollectionViewLayout {
		return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
			guard let self = self, let sectionType = WatchlistSection(rawValue: sectionIndex) else { return nil }

			switch sectionType {
			case .myWatchlist: return self.layoutMyWatchlistSection(env: layoutEnvironment)
			case .customWatchlist: return self.layoutCustomWatchlistSection(env: layoutEnvironment)
			case .sharedWatchlist: return self.layoutSharedWatchlistSection(env: layoutEnvironment)
			}
		}
	}

	private func layoutMyWatchlistSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
		let containerWidth = env.container.effectiveContentSize.width
		let isWide = containerWidth > 700
		let myWatchlistHeight: CGFloat = env.traitCollection.userInterfaceIdiom == .pad ? 400 : LayoutConstants.myWatchlistHeight

		if !isMyWatchlistEmptyState {
			if isWide {
				let mainCardItem = NSCollectionLayoutItem(
					layoutSize: NSCollectionLayoutSize(
						widthDimension: .fractionalWidth(0.8),
						heightDimension: .fractionalHeight(1.0)
					)
				)
				mainCardItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 4)
				let actionItem = NSCollectionLayoutItem(
					layoutSize: NSCollectionLayoutSize(
						widthDimension: .fractionalWidth(1.0),
						heightDimension: .fractionalHeight(0.5)
					)
				)
				actionItem.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 0)
				let actionGroup = NSCollectionLayoutGroup.vertical(
					layoutSize: NSCollectionLayoutSize(
						widthDimension: .fractionalWidth(0.2),
						heightDimension: .fractionalHeight(1.0)
					),
					subitems: [actionItem, actionItem]
				)
				let containerGroup = NSCollectionLayoutGroup.horizontal(
					layoutSize: NSCollectionLayoutSize(
						widthDimension: .fractionalWidth(1.0),
						heightDimension: .absolute(myWatchlistHeight)
					),
					subitems: [mainCardItem, actionGroup]
				)

				let section = NSCollectionLayoutSection(group: containerGroup)
				section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
				section.boundarySupplementaryItems = shouldShowHeader(for: .myWatchlist) ? [createHeader()] : []
				return section
			}

			let mainCardItem = NSCollectionLayoutItem(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(1.0),
					heightDimension: .absolute(myWatchlistHeight)
				)
			)
			mainCardItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

			let mainCardGroup = NSCollectionLayoutGroup.horizontal(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(1.0),
					heightDimension: .absolute(myWatchlistHeight)
				),
				subitems: [mainCardItem]
			)
			let actionItem = NSCollectionLayoutItem(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(0.5),
					heightDimension: .fractionalHeight(1.0)
				)
			)
			actionItem.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

			let actionGroup = NSCollectionLayoutGroup.horizontal(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(1.0),
					heightDimension: .absolute(LayoutConstants.actionCellHeight)
				),
				subitems: [actionItem, actionItem]
			)
			actionGroup.interItemSpacing = .fixed(8)
			let outerGroup = NSCollectionLayoutGroup.vertical(
				layoutSize: NSCollectionLayoutSize(
					widthDimension: .fractionalWidth(1.0),
					heightDimension: .absolute(myWatchlistHeight + 8 + 130)
				),
				subitems: [mainCardGroup, actionGroup]
			)
			outerGroup.interItemSpacing = .fixed(8)

			let section = NSCollectionLayoutSection(group: outerGroup)
			section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
			section.boundarySupplementaryItems = shouldShowHeader(for: .myWatchlist) ? [createHeader()] : []
			return section
		}

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
		section.boundarySupplementaryItems = []
		return section
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

		let isPad = env.traitCollection.userInterfaceIdiom == .pad
		let cardHeight: CGFloat = isPad ? 340 : LayoutConstants.customWatchlistHeight
		let columns = isPad ? 3 : 2

		let item = NSCollectionLayoutItem(
			layoutSize: NSCollectionLayoutSize(
				widthDimension: .fractionalWidth(1.0),
				heightDimension: .fractionalHeight(1.0)
			)
		)
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 12, trailing: 6)

		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(cardHeight))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)

		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 20, trailing: 10)
		section.boundarySupplementaryItems = shouldShowHeader(for: .customWatchlist) ? [createHeader()] : []
		return section
	}

	private func layoutSharedWatchlistSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
		let containerWidth = env.container.effectiveContentSize.width
		let isWide = containerWidth > 700

		let item = NSCollectionLayoutItem(
			layoutSize: NSCollectionLayoutSize(
				widthDimension: .fractionalWidth(1.0),
				heightDimension: .fractionalHeight(1.0)
			)
		)
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)

		let groupSize = NSCollectionLayoutSize(
			widthDimension: .fractionalWidth(1.0),
			heightDimension: .absolute(LayoutConstants.sharedWatchlistHeight)
		)

		let group: NSCollectionLayoutGroup
		if isWide {
			group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
			group.interItemSpacing = .fixed(12)
		} else {
			group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 1)
		}

		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
		section.boundarySupplementaryItems = shouldShowHeader(for: .sharedWatchlist) ? [createHeader()] : []
		return section
	}

	private func shouldShowHeader(for sectionType: WatchlistSection) -> Bool {
		switch sectionType {
		case .myWatchlist:
			return true
		case .customWatchlist:
			return !customWatchlists.isEmpty
		case .sharedWatchlist:
			return !sharedWatchlists.isEmpty
		}
	}

	private func createHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
		let headerSize = NSCollectionLayoutSize(
			widthDimension: .fractionalWidth(1.0),
			heightDimension: .absolute(LayoutConstants.headerHeight)
		)
		return NSCollectionLayoutBoundarySupplementaryItem(
			layoutSize: headerSize,
			elementKind: UICollectionView.elementKindSectionHeader,
			alignment: .top
		)
	}
}

// MARK: - Skeleton Loading

class SkeletonLoadingCell: UICollectionViewCell {
	private let gradientLayer = CAGradientLayer()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupLayer()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupLayer()
	}
	
	private func setupLayer() {
		contentView.backgroundColor = .systemGray6
		contentView.layer.cornerRadius = 16
		contentView.layer.masksToBounds = true
		
		gradientLayer.colors = [
			UIColor.systemGray5.withAlphaComponent(0.6).cgColor,
			UIColor.systemGray4.withAlphaComponent(0.6).cgColor,
			UIColor.systemGray5.withAlphaComponent(0.6).cgColor
		]
		gradientLayer.locations = [0.0, 0.5, 1.0]
		gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
		gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
		contentView.layer.addSublayer(gradientLayer)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		gradientLayer.frame = contentView.bounds
	}
	
	func startAnimating() {
		let animation = CABasicAnimation(keyPath: "locations")
		animation.fromValue = [-1.0, -0.5, 0.0]
		animation.toValue = [1.0, 1.5, 2.0]
		animation.duration = 1.5
		animation.repeatCount = .infinity
		gradientLayer.add(animation, forKey: "skeletonAnimation")
	}
	
	func stopAnimating() {
		gradientLayer.removeAnimation(forKey: "skeletonAnimation")
	}
}
