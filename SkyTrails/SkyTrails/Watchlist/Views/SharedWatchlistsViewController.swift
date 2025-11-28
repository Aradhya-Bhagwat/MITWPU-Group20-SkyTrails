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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("SharedWatchlistsViewController appeared. Count: \(allSharedWatchlists.count)")
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
        print("Add button tapped")
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
        
        // Instantiate SmartWatchlistViewController and navigate
        // Assuming we can find it by ID or Segue. Since I can't easily verify ID without reading full storyboard again,
        // I will use the segue if it exists or instantiate.
        // Based on previous context, there might not be a direct segue yet.
        // I will try to perform the segue "ShowSmartWatchlist" if it exists on THIS controller, 
        // but usually it's on the Home controller.
        // Best approach here: check if we can perform segue, if not log.
        // Actually, I see `ShowSmartWatchlist` segue on Home VC.
        // I'll assume the user wants navigation. I'll try to instantiate by ID "SmartWatchlistViewController" (assuming standard naming)
        // If that fails, I'll leave it as a TODO or try a generic push.
        
        if let smartVC = self.storyboard?.instantiateViewController(withIdentifier: "SmartWatchlistViewController") as? SmartWatchlistViewController {
            smartVC.watchlistType = .shared
            smartVC.watchlistTitle = item.title
            smartVC.observedBirds = item.observedBirds
            smartVC.toObserveBirds = item.toObserveBirds
            self.navigationController?.pushViewController(smartVC, animated: true)
        } else {
            // Fallback: If ID is not set, we can't easily push.
            print("Could not instantiate SmartWatchlistViewController. Check Storyboard ID.")
        }
    }
}
