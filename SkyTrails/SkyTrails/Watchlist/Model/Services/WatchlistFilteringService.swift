
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
    
    // MARK: - Unique Entry Fetching
    
    /// Fetches unique entries from multiple watchlists, deduplicating by bird id
    /// - Parameters:
    ///   - watchlists: The watchlists to fetch from
    ///   - status: The entry status to filter by
    /// - Returns: An array of unique watchlist entries
    func fetchUniqueEntries(
        from watchlists: [Watchlist],
        status: WatchlistEntryStatus
    ) throws -> [WatchlistEntry] {
        guard let manager = manager else { return [] }
        
        var uniqueEntriesByBirdID: [UUID: WatchlistEntry] = [:]
        
        for watchlist in watchlists {
            let entries = try manager.fetchEntries(watchlistID: watchlist.watchlist_id, status: status)
            
            for entry in entries {
                guard let birdID = entry.bird?.bird_id else { continue }
                if let existing = uniqueEntriesByBirdID[birdID] {
                    let entryDate = entry.observationDate ?? entry.addedDate
                    let existingDate = existing.observationDate ?? existing.addedDate
                    if entryDate > existingDate {
                        uniqueEntriesByBirdID[birdID] = entry
                    }
                } else {
                    uniqueEntriesByBirdID[birdID] = entry
                }
            }
        }
        
        return uniqueEntriesByBirdID.values.sorted { ($0.observationDate ?? $0.addedDate) > ($1.observationDate ?? $1.addedDate) }
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
        let uniqueObserved = try manager.fetchEntries(watchlistID: WatchlistConstants.myWatchlistID, status: .observed)
        let uniqueToObserve = try manager.fetchEntries(watchlistID: WatchlistConstants.myWatchlistID, status: .to_observe)
        
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
