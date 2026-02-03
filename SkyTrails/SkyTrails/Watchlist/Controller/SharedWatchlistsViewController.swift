//
//  SharedWatchlistsViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit
import SwiftData

@MainActor
class SharedWatchlistsViewController: UIViewController {

    private let manager = WatchlistManager.shared

    // MARK: - Outlets
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchBar: UISearchBar!

    // MARK: - Types
    enum SortOption {
        case nameAZ, nameZA, date
    }

    // MARK: - Properties
    private var filteredWatchlists: [Watchlist] = []
    private var currentSortOption: SortOption = .nameAZ

    // Computed property to access shared watchlists from Singleton
    var allSharedWatchlists: [Watchlist] {
        return manager.fetchWatchlists(type: .shared)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        setupDataObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure data is refreshed when returning to this screen
        refreshData()
        
        // Handle cases where data might still be loading asynchronously
        manager.onDataLoaded { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshData()
            }
        }
    }

    // MARK: - Setup
    private func setupUI() {
        title = "Shared Watchlists"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        // Search Bar
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.placeholder = "Search shared lists..."

        // Collection View Layout
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear

        // Register Cell
        let nib = UINib(nibName: SharedWatchlistCollectionViewCell.identifier, bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: SharedWatchlistCollectionViewCell.identifier)
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
        refreshData()
    }

    private func setupGestures() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
    }

    // MARK: - Data Management
    func refreshData() {
        var list = allSharedWatchlists

        // Filter
        if let searchText = searchBar.text, !searchText.isEmpty {
            list = list.filter { ($0.title ?? "").localizedCaseInsensitiveContains(searchText) }
        }

        // Sort
        switch currentSortOption {
        case .nameAZ:
            list.sort { ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending }
        case .nameZA:
            list.sort { ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedDescending }
        case .date:
            list.sort { ($0.startDate ?? Date.distantPast) > ($1.startDate ?? Date.distantPast) }
        }

        filteredWatchlists = list
        collectionView.reloadData()
    }

    // MARK: - Actions
    @IBAction func addTapped(_ sender: Any) {
        navigateToEdit(watchlist: nil)
    }

    @IBAction func filterButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)

        let options: [(String, SortOption)] = [
            ("Name (A-Z)", .nameAZ),
            ("Name (Z-A)", .nameZA),
            ("Date (Newest First)", .date)
        ]

        for (title, option) in options {
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.currentSortOption = option
                self?.refreshData()
            }
            // Add checkmark for current selection
            if currentSortOption == option {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }

        present(alert, animated: true)
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: point) {
            let watchlist = filteredWatchlists[indexPath.row]
            showOptions(for: watchlist, at: indexPath)
        }
    }

    // MARK: - Navigation Helpers
    private func navigateToEdit(watchlist: Watchlist?) {
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else {
            return
        }

        vc.watchlistType = .shared
        vc.watchlistToEdit = watchlist
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showOptions(for watchlist: Watchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: watchlist.title, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Edit Details", style: .default, handler: { [weak self] _ in
            self?.navigateToEdit(watchlist: watchlist)
        }))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.confirmDelete(watchlist: watchlist)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let cell = collectionView.cellForItem(at: indexPath), let popover = alert.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }

        present(alert, animated: true)
    }

    private func confirmDelete(watchlist: Watchlist) {
        let alert = UIAlertController(title: "Delete Shared Watchlist",
                                      message: "Are you sure you want to delete '\(watchlist.title ?? "this list")'? This will remove it for all participants.",
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            self.manager.deleteWatchlist(id: watchlist.id)
            self.refreshData()
        }))

        present(alert, animated: true)
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension SharedWatchlistsViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredWatchlists.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath) as? SharedWatchlistCollectionViewCell else {
            return UICollectionViewCell()
        }

        let item = filteredWatchlists[indexPath.row]
        let stats = manager.getStats(for: item.id)

        // Image Handling
        var mainImage: UIImage? = nil
        if let firstImagePath = item.images?.first?.imagePath {
            mainImage = UIImage(named: firstImagePath)
        }

        // Placeholder for participant avatars
        let participantAvatars: [UIImage] = [
            UIImage(systemName: "person.circle.fill")!,
            UIImage(systemName: "person.circle")!
        ].compactMap { $0.withTintColor(.systemBlue, renderingMode: .alwaysOriginal) }

        cell.configure(
            title: item.title ?? "Shared List",
            location: item.location ?? "Global",
            dateRange: formatDateRange(start: item.startDate, end: item.endDate),
            mainImage: mainImage,
            speciesCount: stats.total,
            observedCount: stats.observed,
            userImages: participantAvatars
        )

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 32
        return CGSize(width: width, height: 140)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = filteredWatchlists[indexPath.row]
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)

        guard let smartVC = storyboard.instantiateViewController(withIdentifier: "SmartWatchlistViewController") as? SmartWatchlistViewController else {
            return
        }

        smartVC.watchlistType = .shared
        smartVC.watchlistTitle = item.title ?? "Shared Watchlist"
        smartVC.currentWatchlistId = item.id

        navigationController?.pushViewController(smartVC, animated: true)
    }
    
    // MARK: - Helper
    private func formatDateRange(start: Date?, end: Date?) -> String {
        guard let start = start, let end = end else { return "No Date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - UISearchBarDelegate
extension SharedWatchlistsViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        refreshData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
