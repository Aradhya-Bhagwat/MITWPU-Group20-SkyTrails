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
					
					let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(180)) // Matches your XIB height
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
					
						// Using a list-style group
					let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(100))
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
			// ... (Registration logic provided by user) ...
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
		
		SummaryCardCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "PlaceholderCell")
	}
}

// --- Step 2: Protocol Conformance Extension ---
// This is what was missing, causing the protocol error.

extension WatchlistHomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
	
		// In WatchlistHomeViewController.swift inside 'extension ... UICollectionViewDataSource'
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
		guard let vm = viewModel else {
			return collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
		}
		
		switch indexPath.section {
			case 0:
					// ... (Summary Card Logic remains the same) ...
				let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SummaryCardCollectionViewCell", for: indexPath) as! SummaryCardCollectionViewCell
				let data = [(vm.totalSpeciesCount, "Watchlist", UIColor.systemGreen),
							(vm.totalObservedCount, "Observed", UIColor.systemBlue),
							(vm.totalRareCount, "Rare", UIColor.systemOrange)]
				let item = data[indexPath.item]
				cell.configure(number: "\(item.0)", title: item.1, color: item.2)
				return cell
				
			case 1:
					// --- SECTION 1: MY WATCHLIST ---
				let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MyWatchlistCollectionViewCell", for: indexPath) as! MyWatchlistCollectionViewCell
				
					// Get the first watchlist (simulating the "Main" one)
				if let watchlist = vm.watchlists.first {
					let observedCount = watchlist.birds.filter { $0.isObserved }.count
					let totalCount = watchlist.birds.count
					
						// IMAGE LOGIC:
						// 1. Try to get the first bird in the list
						// 2. Try to get the first image name from that bird
						// 3. Load the UIImage
					var coverImage: UIImage? = nil
					
					if let firstBird = watchlist.birds.first,
					   let imageName = firstBird.images.first {
						coverImage = UIImage(named: imageName)
					}
					
						// Configure the cell with the real image
					cell.configure(
						discoveredText: "\(observedCount) species",
						upcomingText: "\(totalCount - observedCount) species",
						dateText: "This Month",
						observedCount: observedCount,
						watchlistCount: totalCount,
						image: coverImage // <-- Passing the real image here
					)
				}
				return cell
				
			case 2:
					// --- SECTION 2: CUSTOM WATCHLIST ---
				let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as! CustomWatchlistCollectionViewCell
				
					// Assuming the custom watchlists are from the second item onwards
				if indexPath.item + 1 < vm.watchlists.count {
					let watchlist = vm.watchlists[indexPath.item + 1]
					cell.configure(with: watchlist)
				}
				return cell
				
			default:
					// ... (Placeholders remain the same) ...
				let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
				cell.contentView.backgroundColor = indexPath.section == 2 ? .systemIndigo.withAlphaComponent(0.2) : .systemGreen.withAlphaComponent(0.2)
				cell.contentView.layer.cornerRadius = 12
				return cell
		}
	}
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 4 // Summary, MyWatchlist, Custom, Shared
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		guard let vm = viewModel else { return 0 }
		
		switch section {
			case 0: return 3 // Summary stats
			case 1: return 1 // "My Watchlist" card
			case 2: return min(6, max(0, vm.watchlists.count - 1)) // Custom lists (max 6)
			case 3: return 2 // Placeholder: 2 shared lists (Vertical List)
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
		
			// Titles based on Screenshot
		switch indexPath.section {
			case 0: header.configure(title: "Summary")
			case 2: header.configure(title: "Custom Watchlist")
			case 3: header.configure(title: "Shared Watchlist")
			default: header.configure(title: "") // Section 1 ("My Watchlist") uses an internal title label, no header needed.
		}
		
		return header
	}
	
		// Add didSelectItemAt to make cells tappable, even placeholders
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		print("Tapped cell in Section \(indexPath.section), Item \(indexPath.item)")
			// Navigation logic goes here
	}
}
