//
//  CustomWatchlistViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit
import SwiftData

@MainActor
class CustomWatchlistViewController: UIViewController {

    private let manager = WatchlistManager.shared

    // MARK: - Outlets
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchBar: UISearchBar!

    // MARK: - Properties
	private var filteredWatchlists: [Watchlist] = []
	private var currentSortOption: SortOption = .nameAZ
	
    private var allWatchlists: [Watchlist] {
        return manager.fetchWatchlists(type: .custom)
    }
    
    enum SortOption {
        case nameAZ, nameZA, startDate, endDate, rarity
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        setupDataObservers()
    }

    private func setupDataObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataLoaded(_:)),
            name: WatchlistManager.didLoadDataNotification,
            object: nil
        )
    }

    @objc private func handleDataLoaded(_ notification: Notification) {
        updateData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        manager.onDataLoaded { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateData()
            }
        }
    }

    // MARK: - Setup
    private func setupUI() {
        title = "Custom Watchlists"
        view.backgroundColor = .systemGroupedBackground
        
        // Search Bar
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        
        // Collection View Layout
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumInteritemSpacing = 12
        flowLayout.minimumLineSpacing = 12
        flowLayout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        
        // Register Cell
        let nib = UINib(nibName: "CustomWatchlistCollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: CustomWatchlistCollectionViewCell.identifier)
    }
    
    private func setupGestures() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
    }

    // MARK: - Data Handling
    private func updateData() {
        // 1. Filter
        if let text = searchBar.text, !text.isEmpty {
            filteredWatchlists = allWatchlists.filter { ($0.title ?? "").localizedCaseInsensitiveContains(text) }
        } else {
            filteredWatchlists = allWatchlists
        }
        
        // 2. Sort & Reload (Now handled by sortWatchlists)
        sortWatchlists(by: currentSortOption)
    }

    private func sortWatchlists(by option: SortOption) {
        currentSortOption = option
        
        switch option {
        case .nameAZ:
            filteredWatchlists.sort { ($0.title ?? "").localizedStandardCompare($1.title ?? "") == .orderedAscending }
        case .nameZA:
            filteredWatchlists.sort { ($0.title ?? "").localizedStandardCompare($1.title ?? "") == .orderedDescending }
        case .startDate:
            filteredWatchlists.sort { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
        case .endDate:
            filteredWatchlists.sort { ($0.endDate ?? Date.distantPast) < ($1.endDate ?? Date.distantPast) }
        case .rarity:
            filteredWatchlists.sort {
                let rareCount1 = ($0.entries ?? []).filter { $0.bird?.rarityLevel == .rare || $0.bird?.rarityLevel == .very_rare }.count
                let rareCount2 = ($1.entries ?? []).filter { $0.bird?.rarityLevel == .rare || $0.bird?.rarityLevel == .very_rare }.count
                return rareCount1 > rareCount2
            }

        }
        
        // Ensure UI is updated when this is called
        collectionView.reloadData()
    }

    // MARK: - Actions & Navigation
    @IBAction func addTapped(_ sender: Any) {
        performSegue(withIdentifier: "ShowEditCustomWatchlist", sender: nil)
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
            alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                // Directly calling sortWatchlists now handles the reload automatically
                self?.sortWatchlists(by: option)
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowEditCustomWatchlist",
           let destVC = segue.destination as? EditWatchlistDetailViewController {
            // Updated to use the correct model enum if EditWatchlistDetailViewController uses it,
            // or we might need to fix that VC too. Assuming it uses WatchlistType from Models.
            destVC.watchlistType = .custom
        }
    }
}

// MARK: - CollectionView DataSource & Delegate
extension CustomWatchlistViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredWatchlists.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as? CustomWatchlistCollectionViewCell else {
            return UICollectionViewCell()
        }
        let item = filteredWatchlists[indexPath.row]
        cell.configure(with: item)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = filteredWatchlists[indexPath.row]
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        
        if let smartVC = storyboard.instantiateViewController(withIdentifier: "SmartWatchlistViewController") as? SmartWatchlistViewController {
            smartVC.watchlistType = .custom // Enum case matches
            smartVC.watchlistTitle = item.title ?? "Watchlist"
            // REMOVED array passing, smartVC fetches entries by ID now
            smartVC.currentWatchlistId = item.id
            navigationController?.pushViewController(smartVC, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 32
        let availableWidth = collectionView.bounds.width - padding
        let spacing: CGFloat = 12
        
        if availableWidth > 700 {
            let totalSpacing = spacing * 2
            let cellWidth = (availableWidth - totalSpacing) / 3
            return CGSize(width: floor(cellWidth), height: 220)
        } else {
            let cellWidth = (availableWidth - spacing) / 2
            return CGSize(width: floor(cellWidth), height: 220)
        }
    }
}

// MARK: - SearchBar Delegate
extension CustomWatchlistViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - Context Menu (Long Press)
extension CustomWatchlistViewController {
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let point = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: point) {
            let watchlist = filteredWatchlists[indexPath.row]
            showOptions(for: watchlist, at: indexPath)
        }
    }
    
    func showOptions(for watchlist: Watchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: watchlist.title, message: nil, preferredStyle: .actionSheet)
        
        // Edit Action
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController {
                vc.watchlistType = .custom
                vc.watchlistToEdit = watchlist
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }))
        
        // Delete Action
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.confirmDelete(watchlist: watchlist)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            if let cell = collectionView.cellForItem(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            } else {
                popover.sourceView = collectionView
                popover.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
        }
        
        present(alert, animated: true)
    }
    
    func confirmDelete(watchlist: Watchlist) {
        let alert = UIAlertController(title: "Delete Watchlist", message: "Are you sure you want to delete '\(watchlist.title ?? "this list")'?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.manager.deleteWatchlist(id: watchlist.id)
            self?.updateData()
        }))
        
        present(alert, animated: true)
    }
}

// MARK: - UIView Extensions