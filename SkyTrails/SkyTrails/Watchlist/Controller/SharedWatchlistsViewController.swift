//
//  SharedWatchlistsViewController.swift
//  SkyTrails
//
//  Merged / cleaned version
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
    var filteredWatchlists: [Watchlist] = []
    var currentSortOption: SortOption = .nameAZ

    // Computed property to access shared watchlists from Singleton
    var allSharedWatchlists: [Watchlist] {
        return (try? manager.fetchWatchlists(type: .shared)) ?? []
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
        refreshData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

        // Collection View Layout
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear

        // Register Cell (if using nib)
        let nib = UINib(nibName: SharedWatchlistCollectionViewCell.identifier, bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: SharedWatchlistCollectionViewCell.identifier)
    }

    private func setupGestures() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
    }

    // MARK: - Data Management
    func refreshData() {
        var list = allSharedWatchlists

        if let searchText = searchBar.text, !searchText.isEmpty {
            list = list.filter { ($0.title ?? "").localizedCaseInsensitiveContains(searchText) }
        }

        switch currentSortOption {
        case .nameAZ:
            list.sort { ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending }
        case .nameZA:
            list.sort { ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedDescending }
        case .date:
            // Sorting by created_at or startDate as 'dateRange' is not direct property
            list.sort { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
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
            ("Date", .date)
        ]

        for (title, option) in options {
            alert.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                self.currentSortOption = option
                self.refreshData()
            }))
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
            popover.permittedArrowDirections = .any
        }

        present(alert, animated: true)
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: point) {
            let shared = filteredWatchlists[indexPath.row]
            showOptions(for: shared, at: indexPath)
        }
    }

    // MARK: - Navigation Helpers
    private func navigateToEdit(watchlist: Watchlist?) {
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else {
            return
        }

        vc.watchlistType = .shared
        if let watchlist = watchlist {
             vc.watchlistIdToEdit = watchlist.id
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showOptions(for shared: Watchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: shared.title, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { [weak self] _ in
            self?.navigateToEdit(watchlist: shared)
        }))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.confirmDelete(shared: shared)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let cell = collectionView.cellForItem(at: indexPath), let popover = alert.popoverPresentationController {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
            popover.permittedArrowDirections = .any
        }

        present(alert, animated: true)
    }

    private func confirmDelete(shared: Watchlist) {
        let alert = UIAlertController(title: "Delete Watchlist", message: "Are you sure you want to delete '\(shared.title ?? "")'?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            Task {
                try? await self.manager.deleteWatchlist(id: shared.id)
                await MainActor.run {
                    self.refreshData()
                }
            }
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

        // Map Shares to Avatars (Assuming 'shares' relationship exists or using placeholders)
        // Since we don't have User/Avatar data fully set up, we'll pass generic icons if empty
        let userImages: [UIImage] = [] // Placeholder

        // Map Stats (observed vs total entries)
        let stats = (try? manager.getStats(for: item.id)) ?? (0,0)

        // Get Image
        var image: UIImage? = nil
        if let path = item.images?.first?.imagePath {
            image = UIImage(named: path)
        }

        cell.configure(
            title: item.title ?? "Shared Watchlist",
            location: item.location ?? "Unknown",
            dateRange: "Oct - Nov", // Placeholder or derived from startDate/endDate
            mainImage: image,
            speciesCount: stats.total,
            observedCount: stats.observed,
            userImages: userImages
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
