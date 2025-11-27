	//
	//  WatchlistHomeViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 24/11/25.
	//

import UIKit

class WatchlistHomeViewController: UIViewController {
	
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
			
			switch sectionIndex {
				case 0: // SUMMARY (Row of 3)
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
					
				case 1: // MY WATCHLIST (Full Width, Large)
					let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
					let item = NSCollectionLayoutItem(layoutSize: itemSize)
					
					let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(180))
					let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
					
					let section = NSCollectionLayoutSection(group: group)
					section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 20, trailing: 16)
					
					return section
					
				case 2: // CUSTOM WATCHLIST (Horizontal Scroll)
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
					
				default: // SHARED WATCHLIST (Vertical List)
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
		}
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
		
		switch indexPath.section {
			case 0:
					// ... (Summary Card Logic) ...
				let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SummaryCardCollectionViewCell", for: indexPath) as! SummaryCardCollectionViewCell
				let data = [(vm.totalSpeciesCount, "Watchlist", UIColor.systemGreen),
							(vm.totalObservedCount, "Observed", UIColor.systemBlue),
							(vm.totalRareCount, "Rare", UIColor.systemOrange)]
				let item = data[indexPath.item]
				cell.configure(number: "\(item.0)", title: item.1, color: item.2)
				return cell
				
			case 1:
					// ... (My Watchlist Logic) ...
				let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MyWatchlistCollectionViewCell", for: indexPath) as! MyWatchlistCollectionViewCell
				
				if let watchlist = vm.watchlists.first {
					let observedCount = watchlist.birds.filter { $0.isObserved }.count
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
				
			case 2:
					// ... (Custom Watchlist Logic) ...
				let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as! CustomWatchlistCollectionViewCell
				
				if indexPath.item + 1 < vm.watchlists.count {
					let watchlist = vm.watchlists[indexPath.item + 1]
					cell.configure(with: watchlist)
				}
				return cell
				
			case 3:
					// --- SECTION 3: SHARED WATCHLIST (UPDATED WITH REAL ASSETS) ---
				let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath) as! SharedWatchlistCollectionViewCell
				
					// Helper to get dummy avatars (System images)
				let person1 = UIImage(systemName: "person.crop.circle.fill")!.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
				let person2 = UIImage(systemName: "person.crop.circle")!.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
				let person3 = UIImage(systemName: "person.circle.fill")!.withTintColor(.darkGray, renderingMode: .alwaysOriginal)
				
				if indexPath.item == 0 {
						// Card 1: Canopy Wanderers
					cell.configure(
						title: "Canopy Wanderers",
						location: "Vetal tekdi",
						dateRange: "8th Oct - 7th Nov",
						mainImage: UIImage(named: "AsianFairyBluebird"), // <-- Real Asset Name
						stats: (18, 7),
						userImages: [person1, person2, person3, person1, person2]
					)
				} else {
						// Card 2: Feather Trail
					cell.configure(
						title: "Feather Trail",
						location: "Singhad Valley",
						dateRange: "12th Oct - 15th Nov",
						mainImage: UIImage(named: "HimalayanMonal"), // <-- Real Asset Name
						stats: (10, 2),
						userImages: [person3, person2, person1, person2]
					)
				}
				
				return cell
			default:
				let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
				return cell
		}
	}
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 4 // Summary, MyWatchlist, Custom, Shared
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		guard let vm = viewModel else { return 0 }
		
		switch section {
			case 0: return 3
			case 1: return 1
			case 2: return min(6, max(0, vm.watchlists.count - 1))
			case 3: return 2 // Hardcoded 2 items for Shared demo
			default: return 0
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		guard kind == UICollectionView.elementKindSectionHeader else { return UICollectionReusableView() }
		
		let header = collectionView.dequeueReusableSupplementaryView(
			ofKind: kind,
			withReuseIdentifier: SectionHeaderCollectionReusableView.identifier,
			for: indexPath
		) as! SectionHeaderCollectionReusableView
		
		switch indexPath.section {
			case 0: header.configure(title: "Summary")
			case 2: header.configure(title: "Custom Watchlist")
			case 3: header.configure(title: "Shared Watchlist")
			default: header.configure(title: "")
		}
		
		return header
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		print("Tapped cell in Section \(indexPath.section), Item \(indexPath.item)")
	}
}
