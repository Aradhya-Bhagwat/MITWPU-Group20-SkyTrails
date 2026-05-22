
import UIKit
import SwiftData

@MainActor
class IdentificationHistoryListViewController: UIViewController {

    private var allHistories: [IdentificationSession] = []
    private var sections: [HistorySection] = []
    
    struct HistorySection {
        let dateString: String
        var items: [IdentificationSession]
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    var viewModel: IdentificationManager?

    enum SortOption {
        case recent, nameAZ, nameZA
    }
    private var currentSortOption: SortOption = .recent

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadData()
    }

    private func setupNavigationBar() {
        updateFilterMenu()
    }

    private func updateFilterMenu() {
        let recentAction = UIAction(title: "Most Recent", image: nil, state: currentSortOption == .recent ? .on : .off) { [weak self] _ in
            self?.currentSortOption = .recent
            self?.updateData()
            self?.updateFilterMenu()
        }
        
        let azAction = UIAction(title: "Name (A-Z)", image: nil, state: currentSortOption == .nameAZ ? .on : .off) { [weak self] _ in
            self?.currentSortOption = .nameAZ
            self?.updateData()
            self?.updateFilterMenu()
        }
        
        let zaAction = UIAction(title: "Name (Z-A)", image: nil, state: currentSortOption == .nameZA ? .on : .off) { [weak self] _ in
            self?.currentSortOption = .nameZA
            self?.updateData()
            self?.updateFilterMenu()
        }
        
        let menu = UIMenu(title: "Sort History", children: [recentAction, azAction, zaAction])
        
        if let existingItem = navigationItem.rightBarButtonItem {
            existingItem.menu = menu
        } else {
            let filterButton = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease.circle"), menu: menu)
            navigationItem.rightBarButtonItem = filterButton
        }
    }

    private func setupUI() {
        title = "History"
        view.backgroundColor = .systemBackground
        
        searchBar.isHidden = false
        searchBar.delegate = self
        searchBar.placeholder = "Search species..."
        
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumInteritemSpacing = 12
        flowLayout.minimumLineSpacing = 12
        flowLayout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        flowLayout.headerReferenceSize = CGSize(width: view.bounds.width, height: 60)
        flowLayout.sectionHeadersPinToVisibleBounds = true
        
        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        
        let nib = UINib(nibName: "HistoryCollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "history_cell")
        
        let headerNib = UINib(nibName: "HistorySectionHeaderView", bundle: nil)
        collectionView.register(headerNib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "HistorySectionHeaderView")
    }

    private func loadData() {
        let context = WatchlistManager.shared.context
        let currentUserId = UserSession.shared.currentUserID
        
        do {
            let descriptor = FetchDescriptor<IdentificationSession>(
                sortBy: [SortDescriptor(\.observationDate, order: .reverse)]
            )
            let sessions = try context.fetch(descriptor)
            print("Fetched \(sessions.count) sessions total")
            
            self.allHistories = sessions.filter {
                let hasBird = $0.result?.bird != nil
                let matchesUser = (currentUserId == nil ? $0.user_id == nil : $0.user_id == currentUserId)
                return $0.status == .completed && hasBird && matchesUser
            }
            print("Filtered to \(allHistories.count) completed history items")
            self.updateData()
        } catch {
            print("Failed to fetch history: \(error)")
        }
    }

    private func updateData() {
        var list = allHistories
        if let text = searchBar.text, !text.isEmpty {
            list = list.filter { session in
                let birdName = session.result?.bird?.commonName ?? ""
                return birdName.localizedCaseInsensitiveContains(text)
            }
        }
        
        switch currentSortOption {
        case .recent:
            list.sort { $0.observationDate > $1.observationDate }
        case .nameAZ:
            list.sort { ($0.result?.bird?.commonName ?? "").localizedCaseInsensitiveCompare($1.result?.bird?.commonName ?? "") == .orderedAscending }
        case .nameZA:
            list.sort { ($0.result?.bird?.commonName ?? "").localizedCaseInsensitiveCompare($1.result?.bird?.commonName ?? "") == .orderedDescending }
        }
        
        // Grouping
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        
        var tempSections: [HistorySection] = []
        let grouped = Dictionary(grouping: list) { session in
            formatter.string(from: session.observationDate)
        }
        
        let sortedDates = grouped.keys.sorted { date1, date2 in
            guard let d1 = formatter.date(from: date1), let d2 = formatter.date(from: date2) else { return false }
            return d1 > d2
        }
        
        for dateString in sortedDates {
            if let items = grouped[dateString] {
                tempSections.append(HistorySection(dateString: dateString, items: items))
            }
        }
        
        self.sections = tempSections
        collectionView.reloadData()
    }
}

extension IdentificationHistoryListViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "history_cell", for: indexPath) as? HistoryCollectionViewCell else {
            return UICollectionViewCell()
        }
        let session = sections[indexPath.section].items[indexPath.item]
        cell.configureCell(historyItem: session)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HistorySectionHeaderView", for: indexPath) as? HistorySectionHeaderView else {
                return UICollectionReusableView()
            }
            header.configure(date: sections[indexPath.section].dateString)
            return header
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedSession = sections[indexPath.section].items[indexPath.item]
        
        if let vm = viewModel {
            vm.loadSessionAndFilter(session: selectedSession)
        }
        
        let storyboard = UIStoryboard(name: "Identification", bundle: nil)
        if let resultVC = storyboard.instantiateViewController(withIdentifier: "ResultViewController") as? ResultViewController {
            resultVC.viewModel = self.viewModel
            resultVC.historyItem = selectedSession.result
            self.navigationController?.pushViewController(resultVC, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 60)
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

extension IdentificationHistoryListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// UISearchResultsUpdating removed since storyboard searchBar is restored
