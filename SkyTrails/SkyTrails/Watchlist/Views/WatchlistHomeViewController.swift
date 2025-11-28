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
	
	var viewModel: WatchlistViewModel?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.title = "Watchlist"
		self.navigationItem.largeTitleDisplayMode = .always
		
		viewModel = WatchlistViewModel()
		
			// 1. Set the Compositional Layout first
		SummaryCardCollectionView.collectionViewLayout = createCompositionalLayout()
		
			// 2. Assign Data Source and Delegate (must be done after layout change)
		SummaryCardCollectionView.dataSource = self
		SummaryCardCollectionView.delegate = self
		
			// Disable clipping for the collection view to allow shadows to show

		
			// 3. Register Cells
		registerCells()
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
					return self.createCustomWatchlistSectionLayout()
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
	
	private func createCustomWatchlistSectionLayout() -> NSCollectionLayoutSection {
		let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
		
			// Cards are ~45% width to allow for scrolling
		let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.45), heightDimension: .absolute(160))
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
		
		guard let vm = viewModel else {
			return collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
		}
		
		guard let sectionType = WatchlistSection(rawValue: indexPath.section) else {
			return collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
		}
		
		switch sectionType {
			case .summary:
				return configureSummaryCardCell(collectionView: collectionView, indexPath: indexPath, viewModel: vm)
			case .myWatchlist:
				return configureMyWatchlistCell(collectionView: collectionView, indexPath: indexPath, viewModel: vm)
			case .customWatchlist:
				return configureCustomWatchlistCell(collectionView: collectionView, indexPath: indexPath, viewModel: vm)
			case .sharedWatchlist:
				return configureSharedWatchlistCell(collectionView: collectionView, indexPath: indexPath, viewModel: vm)
		}
	}
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return WatchlistSection.allCases.count
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		guard let vm = viewModel else { return 0 }
		guard let sectionType = WatchlistSection(rawValue: section) else { return 0 }
		
		switch sectionType {
			case .summary: return 3
			case .myWatchlist: return 1
			case .customWatchlist: return min(6, max(0, vm.watchlists.count - 1))
			case .sharedWatchlist: return vm.sharedWatchlists.count
		}
	}
	
	
	private func configureSummaryCardCell(collectionView: UICollectionView, indexPath: IndexPath, viewModel vm: WatchlistViewModel) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SummaryCardCollectionViewCell", for: indexPath) as! SummaryCardCollectionViewCell
		let data = [(vm.totalSpeciesCount, "Watchlist", UIColor.systemGreen),
					(vm.totalObservedCount, "Observed", UIColor.systemBlue),
					(vm.totalRareCount, "Rare", UIColor.systemOrange)]
		let item = data[indexPath.item]
		cell.configure(number: "\(item.0)", title: item.1, color: item.2)
		return cell
	}
	
	private func configureMyWatchlistCell(collectionView: UICollectionView, indexPath: IndexPath, viewModel vm: WatchlistViewModel) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MyWatchlistCollectionViewCell", for: indexPath) as! MyWatchlistCollectionViewCell
		
		if let watchlist = vm.watchlists.first {
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
		}
		return cell
	}
	
	private func configureCustomWatchlistCell(collectionView: UICollectionView, indexPath: IndexPath, viewModel vm: WatchlistViewModel) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as! CustomWatchlistCollectionViewCell
		
		if indexPath.item + 1 < vm.watchlists.count { // Custom Watchlist section excludes the first watchlist
			let watchlist = vm.watchlists[indexPath.item + 1]
			cell.configure(with: watchlist)
		}
		return cell
	}
	
	private func configureSharedWatchlistCell(collectionView: UICollectionView, indexPath: IndexPath, viewModel vm: WatchlistViewModel) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath) as! SharedWatchlistCollectionViewCell
		
		if let sharedItem = vm.sharedWatchlists[safe: indexPath.item] {
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
        guard let vm = viewModel else { return }
        guard let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }
        
        switch sectionType {
        case .myWatchlist:
            // Assuming the first watchlist is "My Watchlist"
            if let watchlist = vm.watchlists.first {
                performSegue(withIdentifier: "ShowSmartWatchlist", sender: watchlist)
            }
            
        case .customWatchlist:
            // Custom Watchlists start from index 1 (index 0 is My Watchlist)
            let watchlistIndex = indexPath.item + 1
            if watchlistIndex < vm.watchlists.count {
                let watchlist = vm.watchlists[watchlistIndex]
                performSegue(withIdentifier: "ShowSmartWatchlist", sender: watchlist)
            }
            
        case .sharedWatchlist:
            if let sharedWatchlist = vm.sharedWatchlists[safe: indexPath.item] {
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
			// Section 2 is "Custom Watchlist"
		if sectionType == .customWatchlist {
			performSegue(withIdentifier: "ShowCustomWatchlistGrid", sender: self)
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
		header.configure(title: sectionType.title, sectionIndex: indexPath.section, delegate: self)
		
		return header
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "ShowCustomWatchlistGrid" {
				// If you needed to pass the ViewModel or specific data, do it here
			if let destinationVC = segue.destination as? CustomWatchlistViewController {
					destinationVC.viewModel = self.viewModel
			}
		} else if segue.identifier == "ShowSmartWatchlist" {
            guard let destVC = segue.destination as? SmartWatchlistViewController else { return }
            
            if let watchlist = sender as? Watchlist {
                destVC.watchlistTitle = watchlist.title
                destVC.observedBirds = watchlist.observedBirds
                destVC.toObserveBirds = watchlist.toObserveBirds
            } else if let sharedWatchlist = sender as? SharedWatchlist {
                destVC.watchlistTitle = sharedWatchlist.title
                destVC.observedBirds = sharedWatchlist.observedBirds
                destVC.toObserveBirds = sharedWatchlist.toObserveBirds
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

