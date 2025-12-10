//
//  SharedWatchlistsViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class SharedWatchlistsViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {

    // MARK: - Outlets
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchBar: UISearchBar!

    // MARK: - Properties
    var viewModel: WatchlistViewModel?
    weak var coordinator: WatchlistCoordinator?
    
    // Computed property to access shared watchlists from viewModel
    var allSharedWatchlists: [SharedWatchlist] {
        return viewModel?.sharedWatchlists ?? []
    }
    
    var filteredWatchlists: [SharedWatchlist] = []
    var currentSortOption: SortOption = .nameAZ
    
    enum SortOption {
        case nameAZ
        case nameZA
        case date // Using date generically for dateRange string
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // If viewModel wasn't injected (e.g. independent run), create one
        if viewModel == nil {
            viewModel = WatchlistViewModel()
        }
        
        filteredWatchlists = allSharedWatchlists
        collectionView.reloadData()
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state != .began { return }
        
        let point = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: point) {
            let shared = filteredWatchlists[indexPath.row]
            showOptions(for: shared, at: indexPath)
        }
    }
    
    func showOptions(for shared: SharedWatchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: shared.title, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { _ in
            guard let vm = self.viewModel else { return }
            self.coordinator?.showEditSharedWatchlist(shared, viewModel: vm)
        }))
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.confirmDelete(shared: shared)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            if let cell = collectionView.cellForItem(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
    
    func confirmDelete(shared: SharedWatchlist) {
        let alert = UIAlertController(title: "Delete Watchlist", message: "Are you sure you want to delete '\(shared.title)'?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.viewModel?.deleteSharedWatchlist(id: shared.id)
            // Refresh
            self.filteredWatchlists = self.allSharedWatchlists
            self.collectionView.reloadData()
        }))
        
        present(alert, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("SharedWatchlistsViewController appeared. Count: \(allSharedWatchlists.count)")
        
        // Refresh data to reflect any changes (e.g. new watchlist added)
        if let text = searchBar.text, !text.isEmpty {
            filteredWatchlists = allSharedWatchlists.filter { $0.title.lowercased().contains(text.lowercased()) }
        } else {
            filteredWatchlists = allSharedWatchlists
        }
        sortWatchlists(by: currentSortOption)
    }
    
    private func setupUI() {
        // Navigation Bar
        self.title = "Shared Watchlists"
        self.view.backgroundColor = .systemGroupedBackground
        self.navigationItem.largeTitleDisplayMode = .never
        
        // Collection View Layout
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        // Full width cards, so just vertical spacing
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        
        // Register Cell
        let nib = UINib(nibName: SharedWatchlistCollectionViewCell.identifier, bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: SharedWatchlistCollectionViewCell.identifier)
        
        // Search Bar
        searchBar.backgroundImage = UIImage()
        searchBar.delegate = self
    }
    
    // MARK: - Actions
    @IBAction func addTapped(_ sender: Any) {
        coordinator?.showCreateWatchlist(type: .shared, viewModel: viewModel)
    }
    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
        
        let options: [(String, SortOption)] = [
            ("Name (A-Z)", .nameAZ),
            ("Name (Z-A)", .nameZA),
            ("Date", .date)
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
            popoverController.permittedArrowDirections = .up
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
        case .date:
            // Basic string comparison for dateRange
            filteredWatchlists.sort { $0.dateRange < $1.dateRange }
        }
        collectionView.reloadData()
    }

    // MARK: - UISearchBarDelegate
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredWatchlists = allSharedWatchlists
        } else {
            filteredWatchlists = allSharedWatchlists.filter { $0.title.lowercased().contains(searchText.lowercased()) }
        }
        sortWatchlists(by: currentSortOption)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowSpeciesSelection",
           let destVC = segue.destination as? SpeciesSelectionViewController {
            destVC.coordinator = self.coordinator
            destVC.viewModel = self.viewModel
        }
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension SharedWatchlistsViewController {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredWatchlists.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath) as? SharedWatchlistCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        let item = filteredWatchlists[indexPath.row]
        
        // Convert SF Symbol strings to UIImages
        let userImages = item.userImages.compactMap { imageName -> UIImage? in
            return UIImage(systemName: imageName)?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        }
        
        cell.configure(
            title: item.title,
            location: item.location,
            dateRange: item.dateRange,
            mainImage: UIImage(named: item.mainImageName),
            stats: item.stats,
            userImages: userImages
        )
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Full width card: Screen width - Left Padding - Right Padding
        let width = collectionView.bounds.width - 32
        return CGSize(width: width, height: 140) // Height matching design/XIB
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = filteredWatchlists[indexPath.row]
        
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        if let smartVC = storyboard.instantiateViewController(withIdentifier: "SmartWatchlistViewController") as? SmartWatchlistViewController {
            smartVC.watchlistType = .shared
            smartVC.watchlistTitle = item.title
            smartVC.observedBirds = item.observedBirds
            smartVC.toObserveBirds = item.toObserveBirds
            smartVC.currentWatchlistId = item.id
            smartVC.viewModel = self.viewModel
            smartVC.coordinator = self.coordinator
            
            self.navigationController?.pushViewController(smartVC, animated: true)
        } else {
            print("Could not instantiate SmartWatchlistViewController.")
        }
    }
}
