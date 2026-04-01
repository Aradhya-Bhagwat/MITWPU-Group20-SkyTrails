import Foundation
import SwiftData

/// Service responsible for filtering and deduplicating watchlist entries
@MainActor
final class WatchlistFilteringService {
    
    private let query: WatchlistQuerying
    private let sorting: WatchlistSortingService
    
    init(query: WatchlistQuerying, sorting: WatchlistSortingService) {
        self.query = query
        self.sorting = sorting
    }
    
    // MARK: - Enhanced Filtering API
    
    /// Fetches, filters, searches, and sorts entries for a given mode
    func fetchFilteredEntries(
        mode: WatchlistPresentationMode,
        watchlistId: UUID?,
        searchText: String?,
        sortOption: SmartWatchlistSortOption,
        status: WatchlistEntryStatus? = nil
    ) throws -> WatchlistEntriesResult {
        // Fetch base data
        let baseResult = try fetchEntriesForMode(mode: mode, watchlistId: watchlistId)
        
        // Apply search filter
        let observed = applySearchFilter(entries: baseResult.observed, searchText: searchText)
        let unobserved = applySearchFilter(entries: baseResult.toObserve, searchText: searchText)
        
        // Apply sorting
        let sortedObserved = sorting.sort(entries: observed, by: sortOption)
        let sortedUnobserved = sorting.sort(entries: unobserved, by: sortOption)
        
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
    func fetchEntriesGroupedByWatchlist(
        watchlists: [Watchlist],
        status: WatchlistEntryStatus?,
        searchText: String?,
        sortOption: SmartWatchlistSortOption
    ) throws -> [(Watchlist, [WatchlistEntry])] {
        let filteredResults = watchlists.compactMap { watchlist -> (Watchlist, [WatchlistEntry])? in
            let entries = (try? query.fetchEntries(watchlistID: watchlist.watchlist_id, status: status)) ?? []
            let filtered = applySearchFilter(entries: entries, searchText: searchText)
            let sorted = sorting.sort(entries: filtered, by: sortOption)
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
    
    // MARK: - Unique Entry Fetching
    
    /// Fetches unique entries from multiple watchlists, deduplicating by bird name
    func fetchUniqueEntries(
        from watchlists: [Watchlist],
        status: WatchlistEntryStatus
    ) throws -> [WatchlistEntry] {
        var uniqueEntries: [WatchlistEntry] = []
        var seenBirdNames = Set<String>()
        
        for watchlist in watchlists {
            let entries = try query.fetchEntries(watchlistID: watchlist.watchlist_id, status: status)
            
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
    func fetchEntriesForMode(
        mode: WatchlistPresentationMode,
        watchlistId: UUID?
    ) throws -> ModeBasedEntriesResult {
        switch mode {
        case .myWatchlist:
            return try fetchForMyWatchlist()
            
        case .custom, .shared:
            return try fetchForSingleWatchlist(watchlistId: watchlistId)
            
        case .allSpecies:
            return try fetchForAllSpecies()
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchForMyWatchlist() throws -> ModeBasedEntriesResult {
        let allWatchlists = try query.fetchWatchlists(type: nil)
        
        let uniqueObserved = try fetchUniqueEntries(from: allWatchlists, status: .observed)
        let uniqueToObserve = try fetchUniqueEntries(from: allWatchlists, status: .to_observe)
        
        let shouldShowRecommendations = uniqueObserved.isEmpty && uniqueToObserve.isEmpty
        let recommendedBirds = shouldShowRecommendations ? Array(query.fetchAllBirds().prefix(10)) : []
        
        return ModeBasedEntriesResult(
            observed: uniqueObserved,
            toObserve: uniqueToObserve,
            title: "Summary",
            shouldShowRecommendations: shouldShowRecommendations,
            recommendedBirds: recommendedBirds
        )
    }
    
    private func fetchForSingleWatchlist(watchlistId: UUID?) throws -> ModeBasedEntriesResult {
        guard let id = watchlistId else {
            return ModeBasedEntriesResult(
                observed: [],
                toObserve: [],
                title: "Watchlist",
                shouldShowRecommendations: false,
                recommendedBirds: []
            )
        }
        
        let observed = try query.fetchEntries(watchlistID: id, status: .observed)
        let toObserve = try query.fetchEntries(watchlistID: id, status: .to_observe)
        let title = (try? query.getWatchlist(by: id))?.title ?? "Watchlist"
        
        return ModeBasedEntriesResult(
            observed: observed,
            toObserve: toObserve,
            title: title,
            shouldShowRecommendations: false,
            recommendedBirds: []
        )
    }
    
    private func fetchForAllSpecies() throws -> ModeBasedEntriesResult {
        let allWatchlists = try query.fetchWatchlists(type: nil)
        
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
