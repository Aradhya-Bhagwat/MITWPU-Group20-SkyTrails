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
    weak var coordinator: WatchlistCoordinator?
	
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
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
	}
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state != .began { return }
        
        let point = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: point) {
            let watchlist = filteredWatchlists[indexPath.row]
            showOptions(for: watchlist, at: indexPath)
        }
    }
    
    func showOptions(for watchlist: Watchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: watchlist.title, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { _ in
            guard let vm = self.viewModel else { return }
            self.coordinator?.showEditWatchlist(watchlist, viewModel: vm)
        }))
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.confirmDelete(watchlist: watchlist)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            if let cell = collectionView.cellForItem(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            } else {
                popover.sourceView = collectionView
                popover.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100) // Fallback
            }
        }
        
        present(alert, animated: true)
    }
    
    func confirmDelete(watchlist: Watchlist) {
        let alert = UIAlertController(title: "Delete Watchlist", message: "Are you sure you want to delete '\(watchlist.title)'?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.viewModel?.deleteWatchlist(id: watchlist.id)
            // Refresh
            self.filteredWatchlists = self.allWatchlists
            self.collectionView.reloadData()
        }))
        
        present(alert, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("CustomWatchlistViewController appeared. Watchlist count: \(allWatchlists.count)")
        
        // Refresh data to reflect any changes (e.g. new watchlist added)
        if let text = searchBar.text, !text.isEmpty {
            filteredWatchlists = allWatchlists.filter { $0.title.lowercased().contains(text.lowercased()) }
        } else {
            filteredWatchlists = allWatchlists
        }
        sortWatchlists(by: currentSortOption)
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
		searchBar.searchBarStyle = .minimal
		searchBar.delegate = self
	}
	@IBAction func filterButtonTapped(_ sender: UIButton) {
		let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
		
		let options: [(String, SortOption)] = [
			("Name (A-Z)", .nameAZ),
			("Name (Z-A)", .nameZA),
			("Start Date", .startDate),
			("End Date", .endDate),
			("Rarity", .rarity)
		]
		
		for (title, option) in options {
			alert.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
				self.sortWatchlists(by: option)
			}))
		}
		
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
	
    @IBAction func addTapped(_ sender: Any) {
        performSegue(withIdentifier: "ShowEditCustomWatchlist", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowSpeciesSelection",
           let destVC = segue.destination as? SpeciesSelectionViewController {
            destVC.coordinator = self.coordinator
            destVC.viewModel = self.viewModel
        } else if segue.identifier == "ShowEditCustomWatchlist",
                  let destVC = segue.destination as? EditWatchlistDetailViewController {
            destVC.watchlistType = .custom
            destVC.viewModel = self.viewModel
            destVC.coordinator = self.coordinator
        }
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
        // Padding: 16pt left + 16pt right = 32pt
        let padding: CGFloat = 32
        let availableWidth = collectionView.bounds.width - padding
        
        // Check for iPad / Wide Screen (e.g. > 700pt)
        if availableWidth > 700 {
            // Target: 3 items per row
            // Spacing: 2 gaps of 12pt = 24pt
            let spacing: CGFloat = 12 * 2
            let cellWidth = (availableWidth - spacing) / 3
            return CGSize(width: floor(cellWidth), height: 220)
        } else {
            // Target: 2 items per row (iPhone)
            // Spacing: 1 gap of 12pt = 12pt
            let spacing: CGFloat = 12
            let cellWidth = (availableWidth - spacing) / 2
            return CGSize(width: floor(cellWidth), height: 220)
        }
	}

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = filteredWatchlists[indexPath.row]
        
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        if let smartVC = storyboard.instantiateViewController(withIdentifier: "SmartWatchlistViewController") as? SmartWatchlistViewController {
            
            smartVC.watchlistType = .custom
            smartVC.watchlistTitle = item.title
            smartVC.observedBirds = item.observedBirds
            smartVC.toObserveBirds = item.toObserveBirds
            smartVC.currentWatchlistId = item.id
            smartVC.viewModel = self.viewModel
            smartVC.coordinator = self.coordinator
            
            self.navigationController?.pushViewController(smartVC, animated: true)
        }
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
