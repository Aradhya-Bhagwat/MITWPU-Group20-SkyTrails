	//
	//  CustomWatchlistViewController.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 27/11/25.
	//

import UIKit

class CustomWatchlistViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {
	
		// MARK: - Outlets
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var searchBar: UISearchBar!
	
		// MARK: - Properties
	var viewModel: WatchlistViewModel?
    
    // Computed property to access watchlists from viewModel
    var allWatchlists: [Watchlist] {
        return viewModel?.watchlists ?? []
    }
    
    var filteredWatchlists: [Watchlist] = []
    var currentSortOption: SortOption = .nameAZ
    
    enum SortOption {
        case nameAZ
        case nameZA
        case startDate
        case endDate
        case rarity
    }
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
        filteredWatchlists = allWatchlists
		// No need to loadData() internally if we inject viewModel
        collectionView.reloadData()
	}
	
	    private func setupUI() {
				// Navigation Bar styling to match image
			self.title = "Custom Watchlists"
			self.view.backgroundColor = .systemGroupedBackground // Light gray background
	        
				// Collection View Setup with Flow Layout
			let flowLayout = UICollectionViewFlowLayout()
			flowLayout.scrollDirection = .vertical
			flowLayout.minimumInteritemSpacing = 12 // Space between columns
			flowLayout.minimumLineSpacing = 12 // Space between rows
			flowLayout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
			
			collectionView.collectionViewLayout = flowLayout
			collectionView.delegate = self
			collectionView.dataSource = self
			collectionView.backgroundColor = .clear // Let the grey background show through
			
			let nib = UINib(nibName: "CustomWatchlistCollectionViewCell", bundle: nil)
			collectionView.register(nib, forCellWithReuseIdentifier: CustomWatchlistCollectionViewCell.identifier)
			
				// Remove the default search bar background for a cleaner look
			searchBar.backgroundImage = UIImage()
	        searchBar.delegate = self
		}
	    
	    @IBAction func addTapped(_ sender: Any) {
	        // Handle add action
	        print("Add button tapped")
	    }    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Name (A-Z)", style: .default, handler: { _ in
            self.sortWatchlists(by: .nameAZ)
        }))
        
        alert.addAction(UIAlertAction(title: "Name (Z-A)", style: .default, handler: { _ in
            self.sortWatchlists(by: .nameZA)
        }))
        
        alert.addAction(UIAlertAction(title: "Start Date", style: .default, handler: { _ in
            self.sortWatchlists(by: .startDate)
        }))
        
        alert.addAction(UIAlertAction(title: "End Date", style: .default, handler: { _ in
            self.sortWatchlists(by: .endDate)
        }))
        
        alert.addAction(UIAlertAction(title: "Rarity", style: .default, handler: { _ in
            self.sortWatchlists(by: .rarity)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    func sortWatchlists(by option: SortOption) {
        currentSortOption = option
        switch option {
        case .nameAZ:
            filteredWatchlists.sort { $0.title < $1.title }
        case .nameZA:
            filteredWatchlists.sort { $0.title > $1.title }
        case .startDate:
            filteredWatchlists.sort { $0.startDate < $1.startDate }
        case .endDate:
            filteredWatchlists.sort { $0.endDate < $1.endDate }
        case .rarity:
            // Sorting by number of rare birds (descending)
            filteredWatchlists.sort {
                let rareCount1 = $0.birds.filter { $0.rarity.contains(.rare) }.count
                let rareCount2 = $1.birds.filter { $0.rarity.contains(.rare) }.count
                return rareCount1 > rareCount2
            }
        }
        collectionView.reloadData()
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredWatchlists = allWatchlists
        } else {
            filteredWatchlists = allWatchlists.filter { $0.title.lowercased().contains(searchText.lowercased()) }
        }
        sortWatchlists(by: currentSortOption) // Re-apply sort
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension CustomWatchlistViewController {
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return filteredWatchlists.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as! CustomWatchlistCollectionViewCell
		let item = filteredWatchlists[indexPath.row]
		cell.configure(with: item)
		return cell
	}
	
	// MARK: - Flow Layout (The 2-Column Grid Logic)
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		// Logic: (Screen Width - Left Padding - Right Padding - Space Between) / 2
		// Padding: 16pt left + 16pt right = 32pt
		// Space between columns: 12pt
		// Total to subtract: 32 + 12 = 44pt
		
		let totalHorizontalSpacing: CGFloat = 16 + 16 + 12 // left + right + middle
		let availableWidth = collectionView.bounds.width - totalHorizontalSpacing
		let cellWidth = availableWidth / 2
		
		return CGSize(width: cellWidth, height: 220) // Height to match your design
	}
}




extension UIView {
	@IBInspectable var shadow: Bool {
		get { layer.shadowOpacity > 0 }
		set {
			if newValue {
				self.layer.shadowColor = UIColor.black.cgColor
				self.layer.shadowOpacity = 0.1  // Subtle shadow like the screenshot
				self.layer.shadowOffset = CGSize(width: 0, height: 2)
				self.layer.shadowRadius = 4
				self.layer.masksToBounds = false
			}
		}
	}
}
