//
//  SmartWatchlistViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

enum WatchlistType {
    case myWatchlist
    case custom
    case shared
}

class SmartWatchlistViewController: UIViewController, UISearchBarDelegate {
    
    weak var coordinator: WatchlistCoordinator?
    
    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var headerView: UIView! // Optional: To add shadow or styling
    
    // MARK: - Properties
    var watchlistType: WatchlistType = .custom
    var watchlistTitle: String = "Watchlist"
    
    // --- Data Source for My Watchlist (Multi-Section) ---
    var allWatchlists: [Watchlist] = []
    var filteredSections: [[Bird]] = []
    
    // --- Data Source for Custom/Shared (Single Section) ---
    var observedBirds: [Bird] = []
    var toObserveBirds: [Bird] = []
    var currentList: [Bird] = []
    
    // State
    var currentSegmentIndex: Int = 0 // 0 = Observed, 1 = To Observe
    var currentSortOption: SortOption = .nameAZ // Track sort option
    
    // Dependencies
    var viewModel: WatchlistViewModel?
    var currentWatchlistId: UUID?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyFilters()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh data if possible
        if let vm = viewModel {
            if watchlistType == .myWatchlist {
                self.allWatchlists = vm.watchlists
                applyFilters()
            } else if let id = currentWatchlistId {
                if let updatedWatchlist = vm.watchlists.first(where: { $0.id == id }) {
                    self.observedBirds = updatedWatchlist.observedBirds
                    self.toObserveBirds = updatedWatchlist.toObserveBirds
                    applyFilters()
                } else if let updatedShared = vm.sharedWatchlists.first(where: { $0.id == id }) {
                    self.observedBirds = updatedShared.observedBirds
                    self.toObserveBirds = updatedShared.toObserveBirds
                    applyFilters()
                }
            }
        }
    }
    
    private func setupUI() {
        // 1. Navigation Bar Styling
        self.title = watchlistTitle
        self.view.backgroundColor = .systemGroupedBackground
        self.navigationItem.largeTitleDisplayMode = .never
        
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
        applyFilters()
    }
    
    func applyFilters() {
        let searchText = searchBar.text ?? ""
        let isObserved = (currentSegmentIndex == 0)
        
        if watchlistType == .myWatchlist {
            // Filter each watchlist in allWatchlists
            filteredSections = allWatchlists.map { watchlist in
                let source = isObserved ? watchlist.observedBirds : watchlist.toObserveBirds
                return source.filter { bird in
                    if searchText.isEmpty { return true }
                    return bird.name.lowercased().contains(searchText.lowercased())
                }
            }
        } else {
            // Single List Logic
            let sourceList = isObserved ? observedBirds : toObserveBirds
            currentList = sourceList.filter { bird in
                if searchText.isEmpty { return true }
                return bird.name.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Apply current sort
        sortBirds(by: currentSortOption)
    }
    
    func sortBirds(by option: SortOption) {
        currentSortOption = option
        
        // Helper to sort in-place
        let sortClosure: (Bird, Bird) -> Bool = { b1, b2 in
            switch option {
            case .nameAZ: return b1.name < b2.name
            case .nameZA: return b1.name > b2.name
            case .date:
                let d1 = b1.date.first ?? Date.distantPast
                let d2 = b2.date.first ?? Date.distantPast
                return d1 > d2 // Newest first
            case .rarity:
                let isRare1 = b1.rarity.contains(.rare)
                let isRare2 = b2.rarity.contains(.rare)
                return isRare1 && !isRare2
            }
        }
        
        if watchlistType == .myWatchlist {
            // Sort each section
            for i in 0..<filteredSections.count {
                filteredSections[i].sort(by: sortClosure)
            }
        } else {
            // Sort single list
            currentList.sort(by: sortClosure)
        }
        
        tableView.reloadData()
    }
    
    enum SortOption { case nameAZ, nameZA, date, rarity }
    
    @IBAction func didTapAdd(_ sender: Any) {
        // Only allow adding if we have a valid context (e.g. Custom Watchlist with an ID)
        if let id = currentWatchlistId {
            coordinator?.showAddOptions(from: self, sender: sender, targetWatchlistId: id, viewModel: viewModel)
        } else {
            // Fallback or handle Shared/MyWatchlist cases where adding might be different or disabled
            print("Cannot add: Missing Watchlist ID or context.")
            coordinator?.showAddOptions(from: self, sender: sender)
        }
    }
    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        showSortOptions(sender: sender)
    }
    
    private func showSortOptions(sender: UIButton) {
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
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
            popoverController.permittedArrowDirections = .up // Optional: specify arrow direction
        }
        
        present(alert, animated: true)
    }
}

// MARK: - TableView Extensions
extension SmartWatchlistViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if watchlistType == .myWatchlist {
            return allWatchlists.count
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if watchlistType == .myWatchlist {
            return filteredSections[section].count
        }
        return currentList.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if watchlistType == .myWatchlist {
            let watchlist = allWatchlists[section]
            // Optional: Add count to header? e.g. "Title (5)"
            // For now, just title per requirements
            return watchlist.title
        }
        return nil
    }
    
    // Optional: Customize Header View if needed
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        header.textLabel?.textColor = .label
        // header.contentView.backgroundColor = .systemGroupedBackground
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Ensure you set this Identifier in Storyboard
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "BirdSmartCell", for: indexPath) as? BirdSmartCell else {
            return UITableViewCell()
        }
        
        let bird: Bird
        if watchlistType == .myWatchlist {
            bird = filteredSections[indexPath.section][indexPath.row]
        } else {
            bird = currentList[indexPath.row]
        }
        
        cell.shouldShowAvatars = (watchlistType == .shared)
        
        cell.configure(with: bird)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100 // Or UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let bird: Bird
        if watchlistType == .myWatchlist {
            bird = filteredSections[indexPath.section][indexPath.row]
        } else {
            bird = currentList[indexPath.row]
        }
        
        if currentSegmentIndex == 0 {
            // Observed
            performSegue(withIdentifier: "ShowObservedDetail", sender: bird)
        } else {
            // To Observe
            performSegue(withIdentifier: "ShowUnobservedDetailFromWatchlist", sender: bird)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowObservedDetail",
           let vc = segue.destination as? ObservedDetailViewController,
           let bird = sender as? Bird {
            vc.bird = bird
            vc.watchlistId = self.currentWatchlistId
            vc.coordinator = self.coordinator
        } else if segue.identifier == "ShowUnobservedDetailFromWatchlist",
                  let vc = segue.destination as? UnobservedDetailViewController,
                  let bird = sender as? Bird {
            vc.bird = bird
            vc.watchlistId = self.currentWatchlistId
            vc.coordinator = self.coordinator
        }
    }
}