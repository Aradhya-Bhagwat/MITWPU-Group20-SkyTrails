//
//  WatchlistHomeViewController.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import UIKit

class WatchlistHomeViewController: UIViewController {

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
        static let myWatchlistHeight: CGFloat = 190
        static let customWatchlistHeight: CGFloat = 184
        static let sharedWatchlistHeight: CGFloat = 140
        static let headerHeight: CGFloat = 40
    }


    @IBOutlet weak var summaryCardCollectionView: UICollectionView!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        summaryCardCollectionView.reloadData()
    }

    // MARK: - Setup
    private func setupUI() {
        self.title = "Watchlist"
        self.navigationItem.largeTitleDisplayMode = .always
    }

    private func setupCollectionView() {
        // Layout must be set before data source assignments
        summaryCardCollectionView.collectionViewLayout = createCompositionalLayout()
        summaryCardCollectionView.dataSource = self
        summaryCardCollectionView.delegate = self
        
        registerCells()
    }

    private func registerCells() {
        // Headers
        summaryCardCollectionView.register(
            UINib(nibName: WatchlistSectionHeaderCollectionReusableView.reuseIdentifier, bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "WatchlistSectionHeaderCollectionReusableView"
        )

        // Cells
        let cells = [
            "SummaryCardCollectionViewCell",
            "MyWatchlistCollectionViewCell",
            CustomWatchlistCollectionViewCell.identifier,
            SharedWatchlistCollectionViewCell.identifier
        ]
        
        cells.forEach { identifier in
            summaryCardCollectionView.register(UINib(nibName: identifier, bundle: nil), forCellWithReuseIdentifier: identifier)
        }
        
        summaryCardCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "PlaceholderCell")
    }
}

// MARK: - User Actions 
extension WatchlistHomeViewController {
    
    @IBAction func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: summaryCardCollectionView)
        guard let indexPath = summaryCardCollectionView.indexPathForItem(at: point),
              let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }

        let manager = WatchlistManager.shared

        switch sectionType {
        case .myWatchlist:
            if let watchlist = manager.watchlists.first {
                showOptions(for: watchlist, at: indexPath)
            }

        case .customWatchlist:
            // Custom section logic: index + 1 (skipping 'My Watchlist')
            let actualIndex = indexPath.item + 1
            if actualIndex < manager.watchlists.count {
                let watchlist = manager.watchlists[actualIndex]
                showOptions(for: watchlist, at: indexPath)
            }

        case .sharedWatchlist:
            if let shared = manager.sharedWatchlists[safe: indexPath.item] {
                showOptions(for: shared, at: indexPath)
            }

        default: break
        }
    }

    private func showOptions(for watchlist: Watchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: watchlist.title, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.navigateToEdit(watchlist: watchlist)
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            WatchlistManager.shared.deleteWatchlist(id: watchlist.id)
            self?.summaryCardCollectionView.reloadData()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presentAlert(alert, at: indexPath)
    }

    private func showOptions(for shared: SharedWatchlist, at indexPath: IndexPath) {
        let alert = UIAlertController(title: shared.title, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.navigateToEdit(sharedWatchlist: shared)
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            WatchlistManager.shared.deleteSharedWatchlist(id: shared.id)
            self?.summaryCardCollectionView.reloadData()
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
}

// MARK: - Navigation
extension WatchlistHomeViewController {
    
    private func navigateToEdit(watchlist: Watchlist) {
        let sb = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
        vc.watchlistType = .custom
        vc.watchlistToEdit = watchlist
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func navigateToEdit(sharedWatchlist: SharedWatchlist) {
        let sb = UIStoryboard(name: "Watchlist", bundle: nil)
        guard let vc = sb.instantiateViewController(withIdentifier: "EditWatchlistDetailViewController") as? EditWatchlistDetailViewController else { return }
        vc.watchlistType = .shared
        vc.sharedWatchlistToEdit = sharedWatchlist
        navigationController?.pushViewController(vc, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Handle Grid Segues
        if segue.identifier == "ShowCustomWatchlistGrid" || segue.identifier == "ShowSharedWatchlistGrid" {
            return
        }

        // Handle Detail Segue
        if segue.identifier == "ShowSmartWatchlist",
           let destVC = segue.destination as? SmartWatchlistViewController {
            
            if let watchlists = sender as? [Watchlist] {
                // My Watchlist Case
                destVC.watchlistType = .myWatchlist
                destVC.watchlistTitle = "My Watchlist"
                destVC.allWatchlists = watchlists
                destVC.currentWatchlistId = watchlists.first?.id
                
            } else if let watchlist = sender as? Watchlist {
                // Custom Watchlist Case
                destVC.watchlistType = .custom
                destVC.watchlistTitle = watchlist.title
                destVC.observedBirds = watchlist.observedBirds
                destVC.toObserveBirds = watchlist.toObserveBirds
                destVC.currentWatchlistId = watchlist.id
                
            } else if let sharedWatchlist = sender as? SharedWatchlist {
                // Shared Watchlist Case
                destVC.watchlistType = .shared
                destVC.watchlistTitle = sharedWatchlist.title
                destVC.observedBirds = sharedWatchlist.observedBirds
                destVC.toObserveBirds = sharedWatchlist.toObserveBirds
                destVC.currentWatchlistId = sharedWatchlist.id
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
        let manager = WatchlistManager.shared
        guard let sectionType = WatchlistSection(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .summary: return 3
        case .myWatchlist: return 1
        case .customWatchlist: return min(6, max(0, manager.watchlists.count - 1))
        case .sharedWatchlist: return manager.sharedWatchlists.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let manager = WatchlistManager.shared
        guard let sectionType = WatchlistSection(rawValue: indexPath.section) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath)
        }
        
        switch sectionType {
        case .summary:
            return configureSummaryCell(in: collectionView, at: indexPath, manager: manager)
        case .myWatchlist:
            return configureMyWatchlistCell(in: collectionView, at: indexPath, manager: manager)
        case .customWatchlist:
            return configureCustomWatchlistCell(in: collectionView, at: indexPath, manager: manager)
        case .sharedWatchlist:
            return configureSharedWatchlistCell(in: collectionView, at: indexPath, manager: manager)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let manager = WatchlistManager.shared
        guard let sectionType = WatchlistSection(rawValue: indexPath.section) else { return }
        
        switch sectionType {
        case .myWatchlist:
            performSegue(withIdentifier: "ShowSmartWatchlist", sender: manager.watchlists)
            
        case .customWatchlist:
            let watchlistIndex = indexPath.item + 1
            if watchlistIndex < manager.watchlists.count {
                performSegue(withIdentifier: "ShowSmartWatchlist", sender: manager.watchlists[watchlistIndex])
            }
            
        case .sharedWatchlist:
            if let sharedWatchlist = manager.sharedWatchlists[safe: indexPath.item] {
                performSegue(withIdentifier: "ShowSmartWatchlist", sender: sharedWatchlist)
            }
            
        default: break
        }
    }
}

// MARK: - Cell Configuration Helpers
extension WatchlistHomeViewController {
    
    private func configureSummaryCell(in cv: UICollectionView, at indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "SummaryCardCollectionViewCell", for: indexPath) as! SummaryCardCollectionViewCell
        let data = [
            (manager.totalSpeciesCount, "Watchlist", UIColor.systemGreen),
            (manager.totalObservedCount, "Observed", UIColor.systemBlue),
            (manager.totalRareCount, "Rare", UIColor.systemOrange)
        ]
        
        let item = data[indexPath.item]
        cell.configure(number: "\(item.0)", title: item.1, color: item.2)
        return cell
    }
    
    private func configureMyWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "MyWatchlistCollectionViewCell", for: indexPath) as! MyWatchlistCollectionViewCell
        
        if let watchlist = manager.watchlists.first {
            let observedCount = watchlist.observedCount
            let totalCount = watchlist.birds.count
            let toObserveCount = totalCount - observedCount
            
            // Get up to 4 images for the collage
            let images = watchlist.birds.prefix(4).compactMap { bird -> UIImage? in
                guard let imageName = bird.images.first else { return nil }
                return UIImage(named: imageName)
            }
            
            cell.configure(
                observedCount: observedCount,
                toObserveCount: toObserveCount,
                images: images
            )
        } else {
            cell.configure(
                observedCount: 0,
                toObserveCount: 0,
                images: []
            )
        }
        return cell
    }
    
    private func configureCustomWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: CustomWatchlistCollectionViewCell.identifier, for: indexPath) as! CustomWatchlistCollectionViewCell
        
        // Offset by 1 to skip "My Watchlist"
        let listIndex = indexPath.item + 1
        if listIndex < manager.watchlists.count {
            cell.configure(with: manager.watchlists[listIndex])
        }
        return cell
    }
    
    private func configureSharedWatchlistCell(in cv: UICollectionView, at indexPath: IndexPath, manager: WatchlistManager) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: SharedWatchlistCollectionViewCell.identifier, for: indexPath) as! SharedWatchlistCollectionViewCell
        
        if let sharedItem = manager.sharedWatchlists[safe: indexPath.item] {
            let userImages = sharedItem.userImages.compactMap { imageName in
                UIImage(systemName: imageName)?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
            }
            
            cell.configure(
                title: sharedItem.title,
                location: sharedItem.location,
                dateRange: sharedItem.dateRange,
                mainImage: UIImage(named: sharedItem.mainImageName),
                stats: sharedItem.stats,
                userImages: userImages
            )
        }
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
        section.boundarySupplementaryItems = [createHeader()]
        return section
    }
    
    private func layoutMyWatchlistSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.myWatchlistHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
        section.boundarySupplementaryItems = [createHeader()]
        return section
    }
    
    private func layoutCustomWatchlistSection(env: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
        
        let containerWidth = env.container.effectiveContentSize.width
        let fraction: CGFloat = containerWidth > 700 ? 0.28 : 0.45
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction), heightDimension: .absolute(LayoutConstants.customWatchlistHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 20, trailing: 16)
        section.boundarySupplementaryItems = [createHeader()]
        return section
    }
    
    private func layoutSharedWatchlistSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(LayoutConstants.sharedWatchlistHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
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
        guard kind == UICollectionView.elementKindSectionHeader else { return UICollectionReusableView() }
        
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: WatchlistSectionHeaderCollectionReusableView.reuseIdentifier,
            for: indexPath
        ) as! WatchlistSectionHeaderCollectionReusableView
        
        if let sectionType = WatchlistSection(rawValue: indexPath.section) {
            let showChevron = (sectionType != .summary && sectionType != .myWatchlist)
            header.configure(title: sectionType.title, sectionIndex: indexPath.section, showSeeAll: showChevron, delegate: self)
        }
        
        return header
    }

    func didTapSeeAll(in section: Int) {
        guard let sectionType = WatchlistSection(rawValue: section) else { return }
        switch sectionType {
        case .customWatchlist:
            performSegue(withIdentifier: "ShowCustomWatchlistGrid", sender: self)
        case .sharedWatchlist:
            performSegue(withIdentifier: "ShowSharedWatchlistGrid", sender: self)
        default: break
        }
    }
}

// MARK: - Extensions

// Helper to avoid hardcoding reuse identifiers
extension UICollectionReusableView {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

// Safe Array Access
extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
