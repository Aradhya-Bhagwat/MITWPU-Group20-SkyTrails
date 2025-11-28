//
//  SmartWatchlistViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class SmartWatchlistViewController: UIViewController {
	
		// MARK: - Outlets
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var searchBar: UISearchBar!
	@IBOutlet weak var segmentedControl: UISegmentedControl!
	@IBOutlet weak var headerView: UIView! // Optional: To add shadow or styling
	
		// MARK: - Properties
	var watchlistTitle: String = "Watchlist"
	
		// Model Data
    var observedBirds: [Bird] = []
    var toObserveBirds: [Bird] = []
    
    // Computed property for the current list being displayed (filtered/sorted)
    var currentList: [Bird] = []
	
		// State
	var currentSegmentIndex: Int = 0 // 0 = Observed, 1 = To Observe
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupUI()
		applyFilters()
		print("Observed birds; \(observedBirds)")
		print("toObserveBirds: \(toObserveBirds)")
		print("hiii")
	}
	
	private func setupUI() {
			// 1. Navigation Bar Styling
		self.title = watchlistTitle
		self.view.backgroundColor = .systemGroupedBackground
		
			// 2. TableView Setup
		tableView.delegate = self
		tableView.dataSource = self
		tableView.backgroundColor = .clear
		tableView.separatorStyle = .none // Cleaner look for card-style cells
		
			// 3. Search Bar Styling (Matching CustomWatchlistViewController)
		searchBar.backgroundImage = UIImage() // Removes gray border
		searchBar.delegate = self
		
			// 4. Segmented Control Styling
		segmentedControl.selectedSegmentIndex = 0
        segmentedControl.setTitle("Observed", forSegmentAt: 0)
        segmentedControl.setTitle("To Observe", forSegmentAt: 1)
	}

	
		// MARK: - Filter Logic
	@IBAction func segmentChanged(_ sender: UISegmentedControl) {
		currentSegmentIndex = sender.selectedSegmentIndex
        print("Segment changed to index: \(currentSegmentIndex). Observed count: \(observedBirds.count), ToObserve count: \(toObserveBirds.count)")
		applyFilters() 
	}

	func applyFilters() {
		let searchText = searchBar.text ?? ""
        
        // Select the base list based on the segment
        let sourceList = (currentSegmentIndex == 0) ? observedBirds : toObserveBirds
        print("Applying filters. Segment index: \(currentSegmentIndex). Source list count: \(sourceList.count)")
        if currentSegmentIndex == 0 {
            print("Filtering from observedBirds. Count: \(observedBirds.count)")
        } else {
            print("Filtering from toObserveBirds. Count: \(toObserveBirds.count)")
        }
		
		currentList = sourceList.filter { bird in
			if searchText.isEmpty { return true }
            return bird.name.lowercased().contains(searchText.lowercased())
		}
        print("Current list count after filter: \(currentList.count)")
		tableView.reloadData()
	}

    // ... Actions ...

    func sortBirds(by option: SortOption) {
        // Helper to sort in-place
        func sort(list: inout [Bird]) {
            switch option {
            case .nameAZ:
                list.sort { $0.name < $1.name }
            case .nameZA:
                list.sort { $0.name > $1.name }
            case .date:
                list.sort {
                    guard let d1 = $0.date.first else { return false }
                    guard let d2 = $1.date.first else { return true }
                    return d1 > d2
                }
            case .rarity:
                list.sort {
                    let isRare1 = $0.rarity.contains(.rare)
                    let isRare2 = $1.rarity.contains(.rare)
                    return isRare1 && !isRare2
                }
            }
        }
        
        sort(list: &currentList)
        tableView.reloadData()
    }
    
    enum SortOption { case nameAZ, nameZA, date, rarity }
}

	// MARK: - TableView Extensions
extension SmartWatchlistViewController: UITableViewDelegate, UITableViewDataSource {
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return currentList.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
			// Ensure you set this Identifier in Storyboard
		guard let cell = tableView.dequeueReusableCell(withIdentifier: "BirdSmartCell", for: indexPath) as? BirdSmartCell else {
			return UITableViewCell()
		}
		
		let bird = currentList[indexPath.row]
		
		cell.configure(with: bird)
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 100 // Or UITableView.automaticDimension
	}
	
	@IBAction func filterButtonTapped(_ sender: UIButton) {
		showSortOptions()
	}
	
	private func showSortOptions() {
		let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
		
		alert.addAction(UIAlertAction(title: "Name (A-Z)", style: .default) { [weak self] _ in
			self?.sortBirds(by: .nameAZ)
		})
		
		alert.addAction(UIAlertAction(title: "Name (Z-A)", style: .default) { [weak self] _ in
			self?.sortBirds(by: .nameZA)
		})
		
		alert.addAction(UIAlertAction(title: "Date", style: .default) { [weak self] _ in
			self?.sortBirds(by: .date)
		})
		
		alert.addAction(UIAlertAction(title: "Rarity", style: .default) { [weak self] _ in
			self?.sortBirds(by: .rarity)
		})
		
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		
			// For iPad support (action sheets require a source)

		present(alert, animated: true)
	}
}

	// MARK: - Search Bar Delegate
extension SmartWatchlistViewController: UISearchBarDelegate {
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		applyFilters()
	}
	
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		searchBar.resignFirstResponder()
	}
}
