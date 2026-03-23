
import Foundation
import SwiftData

/// Defines available sorting options for watchlist entries in SmartWatchlistViewController
enum SmartWatchlistSortOption {
    case nameAZ
    case nameZA
    case newestFirst
    case month
    case startDate
    case endDate
    case rarity
}

/// Service responsible for sorting watchlist entries according to various strategies
@MainActor
final class WatchlistSortingService {
    
    /// Sorts watchlist entries according to the specified option
    /// - Parameters:
    ///   - entries: The array of entries to sort
    ///   - option: The sorting strategy to apply
    /// - Returns: A new array of sorted entries
    func sort(entries: [WatchlistEntry], by option: SmartWatchlistSortOption) -> [WatchlistEntry] {
        switch option {
        case .nameAZ:
            return sortByNameAscending(entries)
        case .nameZA:
            return sortByNameDescending(entries)
        case .newestFirst:
            return sortByNewestFirst(entries)
        case .month:
            return sortByMonth(entries)
        case .startDate:
            return sortByStartDate(entries)
        case .endDate:
            return sortByEndDate(entries)
        case .rarity:
            return sortByRarity(entries)
        }
    }
    
    // MARK: - Sorting Strategies
    
    private func sortByNameAscending(_ entries: [WatchlistEntry]) -> [WatchlistEntry] {
        return entries.sorted {
            ($0.bird?.name ?? "").localizedCaseInsensitiveCompare($1.bird?.name ?? "") == .orderedAscending
        }
    }
    
    private func sortByNameDescending(_ entries: [WatchlistEntry]) -> [WatchlistEntry] {
        return entries.sorted {
            ($0.bird?.name ?? "").localizedCaseInsensitiveCompare($1.bird?.name ?? "") == .orderedDescending
        }
    }
    
    private func sortByNewestFirst(_ entries: [WatchlistEntry]) -> [WatchlistEntry] {
        return entries.sorted { $0.addedDate > $1.addedDate }
    }
    
    private func sortByMonth(_ entries: [WatchlistEntry]) -> [WatchlistEntry] {
        return entries.sorted { monthValue(for: $0) < monthValue(for: $1) }
    }
    
    private func sortByStartDate(_ entries: [WatchlistEntry]) -> [WatchlistEntry] {
        return entries.sorted {
            ($0.toObserveStartDate ?? $0.observationDate ?? Date.distantFuture) <
            ($1.toObserveStartDate ?? $1.observationDate ?? Date.distantFuture)
        }
    }
    
    private func sortByEndDate(_ entries: [WatchlistEntry]) -> [WatchlistEntry] {
        return entries.sorted {
            ($0.toObserveEndDate ?? $0.observationDate ?? Date.distantFuture) <
            ($1.toObserveEndDate ?? $1.observationDate ?? Date.distantFuture)
        }
    }
    
    private func sortByRarity(_ entries: [WatchlistEntry]) -> [WatchlistEntry] {
        return entries.sorted { rarityRank(for: $0) < rarityRank(for: $1) }
    }
    
    // MARK: - Helper Methods
    
    /// Extracts the month value from an entry's date information
    /// - Parameter entry: The watchlist entry
    /// - Returns: The month number (1-12), or 13 if no valid date is found
    private func monthValue(for entry: WatchlistEntry) -> Int {
        if let observationDate = entry.observationDate {
            return Calendar.current.component(.month, from: observationDate)
        }
        if let startDate = entry.toObserveStartDate {
            return Calendar.current.component(.month, from: startDate)
        }
        return entry.bird?.validMonths?.min() ?? 13
    }
    
    /// Determines the rarity ranking for sorting purposes
    /// - Parameter entry: The watchlist entry
    /// - Returns: A numeric rank where lower numbers indicate higher rarity/conservation concern
    private func rarityRank(for entry: WatchlistEntry) -> Int {
        let rarity = entry.bird?.conservation_status?.lowercased() ?? ""
        let order: [String: Int] = [
            "critically endangered": 0,
            "endangered": 1,
            "vulnerable": 2,
            "near threatened": 3,
            "least concern": 4
        ]
        return order[rarity] ?? 5
    }
}
