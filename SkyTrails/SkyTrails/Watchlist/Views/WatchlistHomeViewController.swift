	//
	//  WatchlistHomeViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 24/11/25.
	//

import UIKit

class WatchlistHomeViewController: UIViewController {
    
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
    
	@IBOutlet weak var SummaryCardCollectionView: UICollectionView!
	
	// var viewModel: WatchlistViewModel? // Removed
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.title = "Watchlist"
		self.navigationItem.largeTitleDisplayMode = .always
		
		// viewModel = WatchlistViewModel() // Removed
        
			// 1. Set the Compositional Layout first
		SummaryCardCollectionView.collectionViewLayout = createCompositionalLayout()
		
			// 2. Assign Data Source and Delegate (must be done after layout change)
		SummaryCardCollectionView.dataSource = self
		SummaryCardCollectionView.delegate = self
		
			// Disable clipping for the collection view to allow shadows to show

		
			// 3. Register Cells
		registerCells()
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        SummaryCardCollectionView.addGestureRecognizer(longPress)
	}
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state != .began { return }
        
        let point = gesture.location(in: SummaryCardCollectionView)
        if let indexPath = SummaryCardCollectionView.indexPathForItem(at: point),
           let sectionType = WatchlistSection(rawValue: indexPath.section) {
            
            let manager = WatchlistManager.shared
            
            if sectionType == .myWatchlist {
                if let watchlist = manager.watchlists.first {
                    showOptions(for: watchlist, at: indexPath)
                }
            } else if sectionType == .customWatchlist {
                // Adjust index as per cell configuration logic (custom excludes first)
                let actualIndex = indexPath.item + 1
                if actualIndex < manager.watchlists.count {
                    let watchlist = manager.watchlists[actualIndex]
                    showOptions(for: watchlist, at: indexPath)
                }
            } else if sectionType == .sharedWatchlist {
                if let shared = manager.sharedWatchlists[safe: indexPath.item] {
                    showOptions(for: shared, at: indexPath)
                }
            }
        }
    }
    
    func showOptions(for watchlist: Watchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: watchlist.title, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { _ in
            self.showEditWatchlist(watchlist)
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            WatchlistManager.shared.deleteWatchlist(id: watchlist.id)
            self.SummaryCardCollectionView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        presentAlert(alert, sourceView: SummaryCardCollectionView.cellForItem(at: indexPath))
    }
    
    func showOptions(for shared: SharedWatchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: shared.title, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { _ in
            self.showEditSharedWatchlist(shared)
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            WatchlistManager.shared.deleteSharedWatchlist(id: shared.id)
            self.SummaryCardCollectionView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        presentAlert(alert, sourceView: SummaryCardCollectionView.cellForItem(at: indexPath))
    }
    
    // MARK: - Navigation Helper
    func showEditWatchlist(_ watchlist: Watchlist) {
        let vc = UIStoryboard(name: "Watchlist", bundle: nil).instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as! EditWatchlistDetailViewController
        vc.watchlistType = .custom
        // vc.viewModel = viewModel // Removed
        vc.watchlistToEdit = watchlist
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func showEditSharedWatchlist(_ shared: SharedWatchlist) {
        let vc = UIStoryboard(name: "Watchlist", bundle: nil).instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as! EditWatchlistDetailViewController
        vc.watchlistType = .shared
        // vc.viewModel = viewModel // Removed
        vc.sharedWatchlistToEdit = shared
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentAlert(_ alert: UIAlertController, sourceView: UIView?) {
        if let popover = alert.popoverPresentationController {
            if let view = sourceView {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            } else {
                popover.sourceView = SummaryCardCollectionView
                popover.sourceRect = CGRect(x: SummaryCardCollectionView.bounds.midX, y: SummaryCardCollectionView.bounds.midY, width: 0, height: 0)
            }
        }
        present(alert, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SummaryCardCollectionView.reloadData()
    }
	
		// --- Compositional Layout Definition ---
	private func createCompositionalLayout() -> UICollectionViewLayout {
		return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
			
			guard let self = self else { return nil }
			guard let sectionType = WatchlistSection(rawValue: sectionIndex) else { return nil }
			
			switch sectionType {
				case .summary:
					return self.createSummarySectionLayout()
				case .myWatchlist:
					return self.createMyWatchlistSectionLayout()
				case .customWatchlist:
                    return self.createCustomWatchlistSectionLayout(layoutEnvironment: layoutEnvironment)
				case .sharedWatchlist:
					return self.createSharedWatchlistSectionLayout()
			}
		}
	}
	
	private func createSummarySectionLayout() -> NSCollectionLayoutSection {
		let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0/3.0), heightDimension: .fractionalHeight(1.0))
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
		
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(110))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 20, trailing: 12)
		
		let header = self.createSectionHeader()
		section.boundarySupplementaryItems = [header]
		
		return section
	}
	
	private func createMyWatchlistSectionLayout() -> NSCollectionLayoutSection {
		let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(180))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 20, trailing: 16)
		
		return section
	}
	
    private func createCustomWatchlistSectionLayout(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
		let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
		
        // Determine available width
        let containerWidth = layoutEnvironment.container.effectiveContentSize.width
        
        // Logic:
        // iPhone (Portrait ~390pt): 0.45 -> ~175pt (2.2 items visible)
        // iPad (Portrait ~744pt+): we want 3.5 items visible. 1.0 / 3.5 = ~0.28
        
        let fraction: CGFloat = containerWidth > 700 ? 0.28 : 0.45
        
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction), heightDimension: .absolute(184))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.orthogonalScrollingBehavior = .continuous
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
		
		let header = self.createSectionHeader()
		section.boundarySupplementaryItems = [header]
		
		return section
	}
	
	private func createSharedWatchlistSectionLayout() -> NSCollectionLayoutSection {
		let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)
		
			// --- UPDATE: Increased height from 100 to 140 to fit new cell content ---
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(140))
		let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
		
		let section = NSCollectionLayoutSection(group: group)
		section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
		
		let header = self.createSectionHeader()
		section.boundarySupplementaryItems = [header]
		
		return section
	}
	
	private func createSectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
		let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(40))
		return NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
	}
	
		// --- Cell Registration ---
	private func registerCells() {
		let headerNib = UINib(nibName: "SectionHeaderCollectionReusableView", bundle: nil)
		SummaryCardCollectionView.register(
			headerNib,
			forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
			withReuseIdentifier: SectionHeaderCollectionReusableView.identifier
		)
		
		let summaryNib = UINib(nibName: "SummaryCardCollectionViewCell", bundle: nil)
		SummaryCardCollectionView.register(summaryNib, forCellWithReuseIdentifier: "SummaryCardCollectionViewCell")
		
		let myWatchlistNib = UINib(nibName: "MyWatchlistCollectionViewCell", bundle: nil)
		SummaryCardCollectionView.register(myWatchlistNib, forCellWithReuseIdentifier: "MyWatchlistCollectionViewCell")
		
		let customWatchlistNib = UINib(nibName: "CustomWatchlistCollectionViewCell", bundle: nil)
		SummaryCardCollectionView.register(customWatchlistNib, forCellWithReuseIdentifier: CustomWatchlistCollectionViewCell.identifier)
		
			// --- UPDATE: Registering the new SharedWatchlistCell ---
		let sharedWatchlistNib = UINib(nibName: SharedWatchlistCollectionViewCell.identifier, bundle: nil)
		
		
		
		SummaryCardCollectionView.register(sharedWatchlistNib, forCellWithReuseIdentifier: SharedWatchlistCollectionViewCell.identifier)
		
		SummaryCardCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "PlaceholderCell")
	}
}

// --- Step 2: Protocol Conformance Extension ---

extension WatchlistHomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
        let manager = WatchlistManager.shared
		
		guard let sectionType = WatchlistSection(rawValue: indexPath.section) else {
			return collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
		}
		
		switch sectionType {
			case .summary:
				return configureSummaryCardCell(collectionView: collectionView, indexPath: indexPath, manager: manager)
			case .myWatchlist:
				return configureMyWatchlistCell(collectionView: collectionView, indexPath: indexPath, manager: manager)
			case .customWatchlist:
				return configureCustomWatchlistCell(collectionView: collectionView, indexPath: indexPath, manager: manager)
			case .sharedWatchlist:
				return configureSharedWatchlistCell(collectionView: collectionView, indexPath: indexPath, manager: manager)
		}
	}
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return WatchlistSection.allCases.count
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		let manager = WatchlistManager.shared
		guard let sectionType = WatchlistSection(rawValue: section) else { return 0 }
		
		switch sectionType {
			case .summary: return 3
			case .myWatchlist: return 1
			case .customWatchlist: return min(6, max(0, manager.watchlists.count - 1))
			case .sharedWatchlist: return manager.sharedWatchlists.count
		}
	}
	
	
	private func configureSummaryCardCell(collectionView: UICollectionView, indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SummaryCardCollectionViewCell", for: indexPath) as! SummaryCardCollectionViewCell
		let data = [(manager.totalSpeciesCount, "Watchlist", UIColor.systemGreen),
					(manager.totalObservedCount, "Observed", UIColor.systemBlue),
					(manager.totalRareCount, "Rare", UIColor.systemOrange)]
		let item = data[indexPath.item]
		cell.configure(number: "\(item.0)", title: item.1, color: item.2)
		return cell
	}
	
	private func configureMyWatchlistCell(collectionView: UICollectionView, indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MyWatchlistCollectionViewCell", for: indexPath) as! MyWatchlistCollectionViewCell
		
		if let watchlist = manager.watchlists.first {
			let observedCount = watchlist.observedCount
			let totalCount = watchlist.birds.count
			
			var coverImage: UIImage? = nil
			if let firstBird = watchlist.birds.first,
			   let imageName = firstBird.images.first {
				coverImage = UIImage(named: imageName)
			}
			
			cell.configure(
				discoveredText: "\(observedCount) species",
				upcomingText: "\(totalCount - observedCount) species",
				dateText: "This Month",
				observedCount: observedCount,
				watchlistCount: totalCount,
				image: coverImage
			)
		} else {
            // Handle empty state
            cell.configure(
                discoveredText: "0 species",
                upcomingText: "0 species",
                dateText: "N/A",
                observedCount: 0,
                watchlistCount: 0,
                image: nil
            )
        }
		return cell
	}
	
	private func configureCustomWatchlistCell(collectionView: UICollectionView, indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as! CustomWatchlistCollectionViewCell
		
		if indexPath.item + 1 < manager.watchlists.count { // Custom Watchlist section excludes the first watchlist
			let watchlist = manager.watchlists[indexPath.item + 1]
			cell.configure(with: watchlist)
		}
		return cell
	}
	
	private func configureSharedWatchlistCell(collectionView: UICollectionView, indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath) as! SharedWatchlistCollectionViewCell
		
		if let sharedItem = manager.sharedWatchlists[safe: indexPath.item] {
			// Convert string array to UIImage array
			let userImages = sharedItem.userImages.compactMap { imageName -> UIImage? in
				return UIImage(systemName: imageName)?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
			}
			
			cell.configure(
				title: sharedItem.title,
				location: sharedItem.location,
				dateRange: sharedItem.dateRange,
				mainImage: UIImage(named: sharedItem.mainImageName),
				stats: sharedItem.stats,
				userImages: userImages
			)
		}
		
		return cell
	}
	

    
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let manager = WatchlistManager.shared
        guard let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }
        
        switch sectionType {
        case .myWatchlist:
            // Pass filtered "My Watchlist" type logic
            // We want to pass ALL watchlists so the detail view can section them
            // sender will be the whole array of watchlists
            performSegue(withIdentifier: "ShowSmartWatchlist", sender: manager.watchlists)
            
        case .customWatchlist:
            // Custom Watchlists start from index 1 (index 0 is My Watchlist)
            let watchlistIndex = indexPath.item + 1
            if watchlistIndex < manager.watchlists.count {
                let watchlist = manager.watchlists[watchlistIndex]
                performSegue(withIdentifier: "ShowSmartWatchlist", sender: watchlist)
            }
            
        case .sharedWatchlist:
            if let sharedWatchlist = manager.sharedWatchlists[safe: indexPath.item] {
                performSegue(withIdentifier: "ShowSmartWatchlist", sender: sharedWatchlist)
            }
            
        default:
            break
        }
	}
}


	// In WatchlistHomeViewController.swift

	// 1. Conform to the new protocol
extension WatchlistHomeViewController: SectionHeaderDelegate {
	
	func didTapSeeAll(in section: Int) {
		guard let sectionType = WatchlistSection(rawValue: section) else { return }
        
        switch sectionType {
        case .customWatchlist:
            performSegue(withIdentifier: "ShowCustomWatchlistGrid", sender: self)
        case .sharedWatchlist:
            performSegue(withIdentifier: "ShowSharedWatchlistGrid", sender: self)
        default:
            break
        }
	}
	
		// 2. Update viewForSupplementaryElementOfKind to assign the delegate
	func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		guard kind == UICollectionView.elementKindSectionHeader else { return UICollectionReusableView() }
		
		let header = collectionView.dequeueReusableSupplementaryView(
			ofKind: kind,
			withReuseIdentifier: SectionHeaderCollectionReusableView.identifier,
			for: indexPath
		) as! SectionHeaderCollectionReusableView
		
		guard let sectionType = WatchlistSection(rawValue: indexPath.section) else { return header }
		
		// UPDATED CALL: Pass sectionIndex and self (as delegate)
        // Hide chevron for Summary (section 0), show for others (or specifically Custom Watchlist)
        let showChevron = (sectionType != .summary)
		header.configure(title: sectionType.title, sectionIndex: indexPath.section, showSeeAll: showChevron, delegate: self)
		
		return header
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "ShowCustomWatchlistGrid" {
				// No data needed to pass
        } else if segue.identifier == "ShowSharedWatchlistGrid" {
            // No data needed to pass
		} else if segue.identifier == "ShowSmartWatchlist" {
            guard let destVC = segue.destination as? SmartWatchlistViewController else { return }
            
            // destVC.viewModel = self.viewModel // Removed
            
            if let watchlists = sender as? [Watchlist] {
                // Case 1: My Watchlist (All aggregated)
                destVC.watchlistType = .myWatchlist
                destVC.watchlistTitle = "My Watchlist"
                destVC.allWatchlists = watchlists
                // Defaulting "My Watchlist" additions to the first watchlist in the array (usually "My Watchlist")
                destVC.currentWatchlistId = watchlists.first?.id
                
            } else if let watchlist = sender as? Watchlist {
                // Case 2: Single Custom Watchlist
                destVC.watchlistType = .custom
                destVC.watchlistTitle = watchlist.title
                destVC.observedBirds = watchlist.observedBirds
                destVC.toObserveBirds = watchlist.toObserveBirds
                destVC.currentWatchlistId = watchlist.id // Pass ID
                
            } else if let sharedWatchlist = sender as? SharedWatchlist {
                // Case 3: Shared Watchlist
                destVC.watchlistType = .shared
                destVC.watchlistTitle = sharedWatchlist.title
                destVC.observedBirds = sharedWatchlist.observedBirds
                destVC.toObserveBirds = sharedWatchlist.toObserveBirds
                destVC.currentWatchlistId = sharedWatchlist.id // Pass ID
            }
        }
	}
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

