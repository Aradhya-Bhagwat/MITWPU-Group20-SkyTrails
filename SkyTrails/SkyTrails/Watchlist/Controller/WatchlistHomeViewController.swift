//
//  WatchlistHomeViewController.swift
//  SkyTrails
//
//

import UIKit
import SwiftData

@MainActor
class WatchlistHomeViewController: UIViewController {

    private let manager = WatchlistManager.shared
    
    // Local Cache for UI
    private var myWatchlist: Watchlist?
    private var customWatchlists: [Watchlist] = []
    private var sharedWatchlists: [Watchlist] = []
    
    // MARK: - Types
    enum WatchlistSection: Int, CaseIterable {
        case summary
        case myWatchlist
        case customWatchlist
        case sharedWatchlist
        
        var title: String {
            switch self {
            case .summary: return "Summary"
            case .myWatchlist: return "My Watchlist"
            case .customWatchlist: return "Custom Watchlist"
            case .sharedWatchlist: return "Shared Watchlist"
            }
        }
    }
    
    private struct LayoutConstants {
        static let summaryHeight: CGFloat = 110
        static let myWatchlistHeight: CGFloat = 320
        static let customWatchlistHeight: CGFloat = 184
        static let sharedWatchlistHeight: CGFloat = 140
        static let headerHeight: CGFloat = 40
    }
    
    // MARK: - Outlets
    @IBOutlet weak var summaryCardCollectionView: UICollectionView!
    @IBOutlet weak var addFloatingButton: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupFloatingButton()
        setupDataObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDataIfNeeded()
    }
    
    // MARK: - Setup
    private func setupUI() {
        self.title = "Watchlist"
        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.navigationItem.largeTitleDisplayMode = .always
    }
    
    private func setupFloatingButton() {
        addFloatingButton.layer.cornerRadius = addFloatingButton.frame.height / 2
        addFloatingButton.layer.shadowColor = UIColor.black.cgColor
        addFloatingButton.layer.shadowOpacity = 0.2
        addFloatingButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        addFloatingButton.layer.shadowRadius = 8
        
        // Use glass configuration if supported, otherwise standard tint
        addFloatingButton.tintColor = .systemBlue
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        let image = UIImage(systemName: "plus.circle.fill", withConfiguration: symbolConfig)
        addFloatingButton.setImage(image, for: .normal)
    }
    
    private func setupCollectionView() {
        summaryCardCollectionView.collectionViewLayout = createCompositionalLayout()
        summaryCardCollectionView.dataSource = self
        summaryCardCollectionView.delegate = self
        registerCells()
    }
    
    private func registerCells() {
        // Headers
        summaryCardCollectionView.register(
            UINib(nibName: "WatchlistSectionHeaderCollectionReusableView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "WatchlistSectionHeaderCollectionReusableView"
        )
        
        // Cells
        let cellIdentifiers = [
            "SummaryCardCollectionViewCell",
            "MyWatchlistCollectionViewCell",
            CustomWatchlistCollectionViewCell.identifier,
            SharedWatchlistCollectionViewCell.identifier
        ]
        
        cellIdentifiers.forEach { identifier in
            summaryCardCollectionView.register(UINib(nibName: identifier, bundle: nil), forCellWithReuseIdentifier: identifier)
        }
        
        summaryCardCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "PlaceholderCell")
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
        refreshDataIfNeeded()
    }

    private func refreshDataIfNeeded() {
        manager.onDataLoaded { [weak self] success in
            guard success, let self = self else { return }
            
            // Fetch updated data from SwiftData via Manager
            self.myWatchlist = self.manager.fetchWatchlists(type: .my_watchlist).first
            self.customWatchlists = self.manager.fetchWatchlists(type: .custom)
            self.sharedWatchlists = self.manager.fetchWatchlists(type: .shared)
            
            DispatchQueue.main.async {
                self.summaryCardCollectionView.reloadData()
            }
        }
    }
}

// MARK: - User Actions
extension WatchlistHomeViewController {
    
    @IBAction func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let point = gesture.location(in: summaryCardCollectionView)
        guard let indexPath = summaryCardCollectionView.indexPathForItem(at: point),
              let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }
        
        let watchlist: Watchlist?
        switch sectionType {
        case .myWatchlist: watchlist = myWatchlist
        case .customWatchlist:
            watchlist = customWatchlists.indices.contains(indexPath.item) ? customWatchlists[indexPath.item] : nil
        case .sharedWatchlist:
            watchlist = sharedWatchlists.indices.contains(indexPath.item) ? sharedWatchlists[indexPath.item] : nil
        default: watchlist = nil
        }
        
        if let wl = watchlist {
            showOptions(for: wl, at: indexPath)
        }
    }
    
    private func showOptions(for watchlist: Watchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: watchlist.title, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.navigateToEdit(watchlist: watchlist)
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.manager.deleteWatchlist(id: watchlist.id)
            self?.refreshDataIfNeeded()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentAlert(alert, at: indexPath)
    }
    
    private func presentAlert(_ alert: UIAlertController, at indexPath: IndexPath) {
        if let popover = alert.popoverPresentationController {
            if let cell = summaryCardCollectionView.cellForItem(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            } else {
                popover.sourceView = summaryCardCollectionView
                popover.sourceRect = CGRect(x: summaryCardCollectionView.bounds.midX, y: summaryCardCollectionView.bounds.midY, width: 0, height: 0)
            }
        }
        present(alert, animated: true)
    }
    
    @IBAction func addFloatingButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Add to Watchlist", message: "Choose how you want to add species.", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Add Observation (Observed)", style: .default) { [weak self] _ in
            self?.showObservedDetail()
        })
        
        alert.addAction(UIAlertAction(title: "Add Target (Unobserved)", style: .default) { [weak self] _ in
            self?.showSpeciesSelection()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showObservedDetail() {
        guard let watchlistId = myWatchlist?.id else {
            manager.addRoseRingedParakeetToMyWatchlist()
            refreshDataIfNeeded()
            return
        }
        
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "ObservedDetailViewController") as? ObservedDetailViewController else { return }
        vc.bird = nil
        vc.watchlistId = watchlistId
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showSpeciesSelection() {
        guard let watchlistId = myWatchlist?.id else { return }
        
        let storyboard = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "SpeciesSelectionViewController") as? SpeciesSelectionViewController else { return }
        vc.mode = .unobserved
        vc.targetWatchlistId = watchlistId
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Navigation
extension WatchlistHomeViewController {
    
    private func navigateToEdit(watchlist: Watchlist) {
        let sb = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
        vc.watchlistType = (watchlist.type == .shared) ? .shared : .custom
        vc.watchlistToEdit = watchlist
        navigationController?.pushViewController(vc, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowSmartWatchlist",
           let destVC = segue.destination as? SmartWatchlistViewController {
            
            if let mode = sender as? String, mode == "allSpecies" {
                destVC.watchlistType = .allSpecies
                destVC.watchlistTitle = "All Species"
            } else if let watchlist = sender as? Watchlist {
                switch watchlist.type {
                case .my_watchlist:
                    destVC.watchlistType = .myWatchlist
                    destVC.watchlistTitle = "My Watchlist"
                case .shared:
                    destVC.watchlistType = .shared
                    destVC.watchlistTitle = watchlist.title ?? "Shared Watchlist"
                default:
                    destVC.watchlistType = .custom
                    destVC.watchlistTitle = watchlist.title ?? "Custom Watchlist"
                }
                destVC.currentWatchlistId = watchlist.id
            }
        }
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension WatchlistHomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return WatchlistSection.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let sectionType = WatchlistSection(rawValue: section) else { return 0 }
        switch sectionType {
        case .summary: return 3
        case .myWatchlist: return myWatchlist != nil ? 1 : 0
        case .customWatchlist: return min(6, customWatchlists.count)
        case .sharedWatchlist: return sharedWatchlists.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let sectionType = WatchlistSection(rawValue: indexPath.section) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
        }
        
        switch sectionType {
        case .summary:
            return configureSummaryCell(in: collectionView, at: indexPath)
        case .myWatchlist:
            return configureMyWatchlistCell(in: collectionView, at: indexPath)
        case .customWatchlist:
            return configureCustomWatchlistCell(in: collectionView, at: indexPath)
        case .sharedWatchlist:
            return configureSharedWatchlistCell(in: collectionView, at: indexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }
        switch sectionType {
        case .summary:
            if indexPath.item == 0 { performSegue(withIdentifier: "ShowSmartWatchlist", sender: "allSpecies") }
        case .myWatchlist:
            if let wl = myWatchlist { performSegue(withIdentifier: "ShowSmartWatchlist", sender: wl) }
        case .customWatchlist:
            if customWatchlists.indices.contains(indexPath.item) {
                let wl = customWatchlists[indexPath.item]
                performSegue(withIdentifier: "ShowSmartWatchlist", sender: wl)
            }
        case .sharedWatchlist:
            if sharedWatchlists.indices.contains(indexPath.item) {
                let wl = sharedWatchlists[indexPath.item]
                performSegue(withIdentifier: "ShowSmartWatchlist", sender: wl)
            }
        }
    }
}

// MARK: - Cell Configuration Helpers
extension WatchlistHomeViewController {
    
    private func configureSummaryCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "SummaryCardCollectionViewCell", for: indexPath) as! SummaryCardCollectionViewCell
        
        let allWatchlists = manager.fetchWatchlists()
        let totalEntriesCount = allWatchlists.reduce(0) { $0 + ($1.entries?.count ?? 0) }
        let observedCount = manager.fetchGlobalObservedCount()
        
        var rareCount = 0
        allWatchlists.forEach { wl in
            wl.entries?.forEach { entry in
                if entry.status == .observed, let rarity = entry.bird?.rarityLevel, (rarity == .rare || rarity == .very_rare) {
                    rareCount += 1
                }
            }
        }
        
        let stats: [(String, String, UIColor)] = [
            ("\(totalEntriesCount)", "Watchlist", .systemGreen),
            ("\(observedCount)", "Observed", .systemBlue),
            ("\(rareCount)", "Rare", .systemOrange)
        ]
        
        let data = stats[indexPath.item]
        cell.configure(number: data.0, title: data.1, color: data.2)
        return cell
    }
    
    private func configureMyWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "MyWatchlistCollectionViewCell", for: indexPath) as! MyWatchlistCollectionViewCell
        if let watchlist = myWatchlist {
            let stats = manager.getStats(for: watchlist.id)
            let birds = (watchlist.entries ?? []).prefix(4).compactMap { $0.bird }
            let images = birds.compactMap { UIImage(named: $0.staticImageName) }
            cell.configure(observedCount: stats.observed, toObserveCount: stats.total - stats.observed, images: images)
        }
        return cell
    }
    
    private func configureCustomWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as! CustomWatchlistCollectionViewCell
        let watchlist = customWatchlists[indexPath.item]
        cell.configure(with: watchlist)
        return cell
    }
    
    private func configureSharedWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath) as! SharedWatchlistCollectionViewCell
        let shared = sharedWatchlists[indexPath.item]
        let stats = manager.getStats(for: shared.id)
        let image = UIImage(named: shared.images?.first?.imagePath ?? "")
        cell.configure(title: shared.title ?? "Shared", location: shared.location ?? "Global", dateRange: "Active", mainImage: image, speciesCount: stats.total, observedCount: stats.observed, userImages: [])
        return cell
    }
}

// MARK: - Compositional Layout
extension WatchlistHomeViewController {
    
    private func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self, let sectionType = WatchlistSection(rawValue: sectionIndex) else { return nil }
            switch sectionType {
            case .summary: return self.layoutSummarySection()
            case .myWatchlist: return self.layoutMyWatchlistSection()
            case .customWatchlist: return self.layoutCustomWatchlistSection(env: layoutEnvironment)
            case .sharedWatchlist: return self.layoutSharedWatchlistSection()
            }
        }
    }
    
    private func layoutSummarySection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0/3.0), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.summaryHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 20, trailing: 12)
        return section
    }
    
    private func layoutMyWatchlistSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.myWatchlistHeight)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
        section.boundarySupplementaryItems = [createHeader()]
        return section
    }
    
    private func layoutCustomWatchlistSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
        let fraction: CGFloat = env.container.effectiveContentSize.width > 700 ? 0.28 : 0.45
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction), heightDimension: .absolute(LayoutConstants.customWatchlistHeight)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
        section.boundarySupplementaryItems = [createHeader()]
        return section
    }
    
    private func layoutSharedWatchlistSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.sharedWatchlistHeight)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        section.boundarySupplementaryItems = [createHeader()]
        return section
    }
    
    private func createHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.headerHeight))
        return NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
    }
}

// MARK: - Header Delegate
extension WatchlistHomeViewController: SectionHeaderDelegate {
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "WatchlistSectionHeaderCollectionReusableView", for: indexPath) as! WatchlistSectionHeaderCollectionReusableView
        if let sectionType = WatchlistSection(rawValue: indexPath.section) {
            header.configure(title: sectionType.title, sectionIndex: indexPath.section, showSeeAll: (sectionType != .summary && sectionType != .myWatchlist), delegate: self)
        }
        return header
    }
    
    func didTapSeeAll(in section: Int) {
        guard let sectionType = WatchlistSection(rawValue: section) else { return }
        switch sectionType {
        case .customWatchlist: performSegue(withIdentifier: "ShowCustomWatchlistGrid", sender: self)
        case .sharedWatchlist: performSegue(withIdentifier: "ShowSharedWatchlistGrid", sender: self)
        default: break
        }
    }
}

