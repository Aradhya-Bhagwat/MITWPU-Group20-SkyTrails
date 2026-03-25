
import Foundation
import SwiftData

/// Service responsible for filtering and deduplicating watchlist entries
@MainActor
final class WatchlistFilteringService {
    
    private weak var manager: WatchlistManager?
    
    init(manager: WatchlistManager? = nil) {
        self.manager = manager
    }
    
    func setManager(_ manager: WatchlistManager) {
        self.manager = manager
    }
    
    // MARK: - Enhanced Filtering API
    
    /// Fetches, filters, searches, and sorts entries for a given mode
    /// This is the primary API for ViewControllers - returns complete, ready-to-display data
    /// - Parameters:
    ///   - mode: The watchlist presentation mode
    ///   - watchlistId: The watchlist ID (for single watchlist modes)
    ///   - searchText: Optional search filter
    ///   - sortOption: How to sort the results
    /// - Returns: Complete result with observed, unobserved arrays and counts
    func fetchFilteredEntries(
        mode: WatchlistPresentationMode,
        watchlistId: UUID?,
        searchText: String?,
        sortOption: SmartWatchlistSortOption,
        status: WatchlistEntryStatus? = nil
    ) throws -> WatchlistEntriesResult {
        guard let manager = manager else {
            return WatchlistEntriesResult(
                observed: [],
                unobserved: [],
                observedCount: 0,
                unobservedCount: 0,
                totalCount: 0,
                title: "Watchlist",
                shouldShowRecommendations: false,
                recommendedBirds: []
            )
        }
        
        // Fetch base data
        let baseResult = try fetchEntriesForMode(mode: mode, watchlistId: watchlistId)
        
        // Apply search filter
        let observed = applySearchFilter(entries: baseResult.observed, searchText: searchText)
        let unobserved = applySearchFilter(entries: baseResult.toObserve, searchText: searchText)
        
        // Apply sorting
        let sortedObserved = manager.sortingService.sort(entries: observed, by: sortOption)
        let sortedUnobserved = manager.sortingService.sort(entries: unobserved, by: sortOption)
        
        return WatchlistEntriesResult(
            observed: sortedObserved,
            unobserved: sortedUnobserved,
            observedCount: sortedObserved.count,
            unobservedCount: sortedUnobserved.count,
            totalCount: sortedObserved.count + sortedUnobserved.count,
            title: baseResult.title,
            shouldShowRecommendations: baseResult.shouldShowRecommendations,
            recommendedBirds: baseResult.recommendedBirds
        )
    }
    
    /// Fetches entries for a watchlist grouped by status, with search and sort
    /// Used for myWatchlist mode with section-based display
    /// - Parameters:
    ///   - watchlists: Source watchlists to fetch from
    ///   - status: Filter by status
    ///   - searchText: Optional search filter
    ///   - sortOption: How to sort results
    /// - Returns: Dictionary of watchlist to filtered entries
    func fetchEntriesGroupedByWatchlist(
        watchlists: [Watchlist],
        status: WatchlistEntryStatus?,
        searchText: String?,
        sortOption: SmartWatchlistSortOption
    ) throws -> [(Watchlist, [WatchlistEntry])] {
        guard let manager = manager else { return [] }
        
        let filteredResults = watchlists.compactMap { watchlist -> (Watchlist, [WatchlistEntry])? in
            let entries = (try? manager.fetchEntries(watchlistID: watchlist.watchlist_id, status: status)) ?? []
            let filtered = applySearchFilter(entries: entries, searchText: searchText)
            let sorted = manager.sortingService.sort(entries: filtered, by: sortOption)
            return sorted.isEmpty ? nil : (watchlist, sorted)
        }
        
        return filteredResults
    }
    
    // MARK: - Private Helpers
    
    private func applySearchFilter(entries: [WatchlistEntry], searchText: String?) -> [WatchlistEntry] {
        guard let searchText = searchText, !searchText.isEmpty else {
            return entries
        }
        
        return entries.filter { entry in
            guard let bird = entry.bird else { return false }
            return bird.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Unique Entry Fetching (Legacy - kept for backward compatibility)
    
    /// Fetches unique entries from multiple watchlists, deduplicating by bird name
    /// - Parameters:
    ///   - watchlists: The watchlists to fetch from
    ///   - status: The entry status to filter by
    /// - Returns: An array of unique watchlist entries
    func fetchUniqueEntries(
        from watchlists: [Watchlist],
        status: WatchlistEntryStatus
    ) throws -> [WatchlistEntry] {
        guard let manager = manager else { return [] }
        
        var uniqueEntries: [WatchlistEntry] = []
        var seenBirdNames = Set<String>()
        
        for watchlist in watchlists {
            let entries = try manager.fetchEntries(watchlistID: watchlist.watchlist_id, status: status)
            
            for entry in entries {
                if let birdName = entry.bird?.name, !seenBirdNames.contains(birdName) {
                    seenBirdNames.insert(birdName)
                    uniqueEntries.append(entry)
                }
            }
        }
        
        return uniqueEntries
    }
    
    /// Result structure for mode-based fetching
    struct ModeBasedEntriesResult {
        let observed: [WatchlistEntry]
        let toObserve: [WatchlistEntry]
        let title: String
        let shouldShowRecommendations: Bool
        let recommendedBirds: [Bird]
    }
    
    // MARK: - Mode-Based Fetching
    
    /// Fetches entries based on the presentation mode
    /// - Parameters:
    ///   - mode: The watchlist presentation mode
    ///   - watchlistId: The current watchlist ID (for single watchlist modes)
    /// - Returns: A result containing observed, to-observe entries, and metadata
    func fetchEntriesForMode(
        mode: WatchlistPresentationMode,
        watchlistId: UUID?
    ) throws -> ModeBasedEntriesResult {
        guard let manager = manager else {
            return ModeBasedEntriesResult(
                observed: [],
                toObserve: [],
                title: "Watchlist",
                shouldShowRecommendations: false,
                recommendedBirds: []
            )
        }
        
        switch mode {
        case .myWatchlist:
            return try fetchForMyWatchlist(manager: manager)
            
        case .custom, .shared:
            return try fetchForSingleWatchlist(manager: manager, watchlistId: watchlistId)
            
        case .allSpecies:
            return try fetchForAllSpecies(manager: manager)
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchForMyWatchlist(manager: WatchlistManager) throws -> ModeBasedEntriesResult {
        let allWatchlists = try manager.fetchWatchlists()
        
        let uniqueObserved = try fetchUniqueEntries(from: allWatchlists, status: .observed)
        let uniqueToObserve = try fetchUniqueEntries(from: allWatchlists, status: .to_observe)
        
        // Show recommendations if both lists are empty
        let shouldShowRecommendations = uniqueObserved.isEmpty && uniqueToObserve.isEmpty
        let recommendedBirds = shouldShowRecommendations ? Array(manager.fetchAllBirds().prefix(10)) : []
        
        return ModeBasedEntriesResult(
            observed: uniqueObserved,
            toObserve: uniqueToObserve,
            title: "Summary",
            shouldShowRecommendations: shouldShowRecommendations,
            recommendedBirds: recommendedBirds
        )
    }
    
    private func fetchForSingleWatchlist(
        manager: WatchlistManager,
        watchlistId: UUID?
    ) throws -> ModeBasedEntriesResult {
        guard let id = watchlistId else {
            return ModeBasedEntriesResult(
                observed: [],
                toObserve: [],
                title: "Watchlist",
                shouldShowRecommendations: false,
                recommendedBirds: []
            )
        }
        
        let observed = try manager.fetchEntries(watchlistID: id, status: .observed)
        let toObserve = try manager.fetchEntries(watchlistID: id, status: .to_observe)
        let title = (try? manager.getWatchlist(by: id))??.title ?? "Watchlist"
        
        #if DEBUG
        print("[WatchlistFilteringService] fetchForSingleWatchlist - Watchlist ID: \(id)")
        print("[WatchlistFilteringService] fetchForSingleWatchlist - Observed count: \(observed.count)")
        print("[WatchlistFilteringService] fetchForSingleWatchlist - ToObserve count: \(toObserve.count)")
        for (index, entry) in observed.enumerated() {
            print("[WatchlistFilteringService] Observed[\(index)] - ID: \(entry.id), bird: \(String(describing: entry.bird?.name)), photos: \(entry.photos?.count ?? 0)")
        }
        for (index, entry) in toObserve.enumerated() {
            print("[WatchlistFilteringService] ToObserve[\(index)] - ID: \(entry.id), bird: \(String(describing: entry.bird?.name))")
        }
        #endif
        
        return ModeBasedEntriesResult(
            observed: observed,
            toObserve: toObserve,
            title: title,
            shouldShowRecommendations: false,
            recommendedBirds: []
        )
    }
    
    private func fetchForAllSpecies(manager: WatchlistManager) throws -> ModeBasedEntriesResult {
        let allWatchlists = try manager.fetchWatchlists()
        
        let uniqueObserved = try fetchUniqueEntries(from: allWatchlists, status: .observed)
        let uniqueToObserve = try fetchUniqueEntries(from: allWatchlists, status: .to_observe)
        
        return ModeBasedEntriesResult(
            observed: uniqueObserved,
            toObserve: uniqueToObserve,
            title: "Universal Index",
            shouldShowRecommendations: false,
            recommendedBirds: []
        )
    }
}
