//
//  WatchlistQueryService.swift
//  SkyTrails
//
//  Complex queries, filtering, sorting, and aggregation logic
//  Strict MVC Refactoring
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
final class WatchlistQueryService {
    
    private let context: ModelContext
    private let persistence: WatchlistPersistenceService
    
    init(context: ModelContext, persistence: WatchlistPersistenceService) {
        self.context = context
        self.persistence = persistence
    }
    
    // MARK: - Dashboard Data
    
    func loadDashboardData() async throws -> (
        myWatchlist: WatchlistSummaryDTO?,
        custom: [WatchlistSummaryDTO],
        shared: [WatchlistSummaryDTO],
        globalStats: WatchlistStatsDTO
    ) {
        print("📊 [QueryService] Loading dashboard data...")
        
        let allLists = try persistence.fetchWatchlists()
        print("📊 [QueryService] Fetched \(allLists.count) total watchlists")
        
        // Filter & Map using entity extensions
        let customLists = allLists.filter { $0.type == .custom }.map { $0.toSummary() }
        let sharedLists = allLists.filter { $0.type == .shared }.map { $0.toSummary() }
        
        print("📊 [QueryService] Custom: \(customLists.count), Shared: \(sharedLists.count)")
        
        // Build My Watchlist (Real Watchlist)
        let myWatchlist = try buildMyWatchlistDTO()
        print("📊 [QueryService] My Watchlist: \(myWatchlist?.stats.observedCount ?? 0)/\(myWatchlist?.stats.totalCount ?? 0)")
        
        // Calculate Global Stats
        let allEntries = allLists.flatMap { $0.entries ?? [] }
        let globalStats = calculateStats(from: allEntries)
        print("📊 [QueryService] Global Stats: \(globalStats.observedCount)/\(globalStats.totalCount)")
        
        return (myWatchlist, customLists, sharedLists, globalStats)
    }
    
    func buildMyWatchlistDTO() throws -> WatchlistSummaryDTO? {
        guard let myWatchlist = try persistence.fetchMyWatchlist() else {
            return nil
        }
        
        return myWatchlist.toSummary()
    }
    
    // MARK: - Filtered & Sorted Queries
    
    func fetchEntries(
        identifier: WatchlistIdentifier,
        filter: WatchlistQueryFilter = WatchlistQueryFilter(),
        sort: WatchlistSortOption = .addedDateNewest
    ) throws -> [WatchlistEntryDTO] {
        let entries: [WatchlistEntry]
        
        if identifier.isVirtual {
            // My Watchlist - use real watchlist
            if let myWatchlist = try persistence.fetchMyWatchlist() {
                entries = myWatchlist.entries ?? []
            } else {
                return []
            }
        } else if let uuid = identifier.uuid {
            entries = try persistence.fetchEntries(watchlistID: uuid)
        } else {
            return []
        }
        
        // Apply filters
        var filtered = entries
        
        if let status = filter.status {
            filtered = filtered.filter { $0.status == status }
        }
        
        if let searchText = filter.searchText, !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            filtered = filtered.filter { entry in
                entry.bird?.commonName.lowercased().contains(lowercased) ?? false ||
                entry.bird?.scientificName.lowercased().contains(lowercased) ?? false
            }
        }
        
        if let families = filter.families, !families.isEmpty {
            filtered = filtered.filter { entry in
                guard let family = entry.bird?.family else { return false }
                return families.contains(family)
            }
        }
        
        if let hasPhotos = filter.hasPhotos {
            filtered = filtered.filter { entry in
                let photoCount = entry.photos?.count ?? 0
                return hasPhotos ? photoCount > 0 : photoCount == 0
            }
        }
        
        if let dateRange = filter.dateRange {
            filtered = filtered.filter { entry in
                guard let observationDate = entry.observationDate else { return false }
                return observationDate >= dateRange.start && observationDate <= dateRange.end
            }
        }
        
        // Convert to DTOs
        return filtered.compactMap { $0.toDomain() }
    }
    
    // MARK: - Stats
    
    func getStats(for identifier: WatchlistIdentifier) throws -> WatchlistStatsDTO {
        if identifier.isVirtual {
            // Use real My Watchlist stats
            if let myWatchlist = try persistence.fetchMyWatchlist() {
                return calculateStats(from: myWatchlist.entries ?? [])
            }
            return .empty
        } else if let uuid = identifier.uuid {
            let entries = try persistence.fetchEntries(watchlistID: uuid)
            return calculateStats(from: entries)
        }
        
        return .empty
    }
    
    func getGlobalObservedCount() throws -> Int {
        let allEntries = try persistence.fetchAllEntries()
        return allEntries.filter { $0.status == .observed }.count
    }
    
    private func calculateStats(from entries: [WatchlistEntry]) -> WatchlistStatsDTO {
        let observedCount = entries.filter { $0.status == .observed }.count
        let rareCount = 0
        
        return WatchlistStatsDTO(
            observedCount: observedCount,
            totalCount: entries.count,
            rareCount: rareCount
        )
    }
    
    // MARK: - Location-Based Queries
    
    func getEntriesObservedNear(
        location: CLLocationCoordinate2D,
        radiusInKm: Double = 10.0,
        watchlistID: WatchlistIdentifier? = nil
    ) throws -> [WatchlistEntryDTO] {
        
        var allEntries: [WatchlistEntry]
        
        if let identifier = watchlistID, !identifier.isVirtual, let uuid = identifier.uuid {
            allEntries = try persistence.fetchEntries(watchlistID: uuid, status: .observed)
        } else {
            allEntries = try persistence.fetchAllEntries().filter { $0.status == .observed }
        }
        
        // Filter entries with location data
        let withLocation = allEntries.filter { $0.lat != nil && $0.lon != nil }
        
        // Geospatial filter
        let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let nearby = withLocation.filter { entry in
            guard let lat = entry.lat, let lon = entry.lon else { return false }
            let entryLoc = CLLocation(latitude: lat, longitude: lon)
            return entryLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
        }
        
        return nearby.compactMap { $0.toDomain() }
    }
    
    // MARK: - Date Range Queries
    
    func getEntriesInDateRange(
        start: Date,
        end: Date,
        watchlistID: WatchlistIdentifier? = nil
    ) throws -> [WatchlistEntryDTO] {
        
        var entries: [WatchlistEntry]
        
        if let identifier = watchlistID, !identifier.isVirtual, let uuid = identifier.uuid {
            entries = try persistence.fetchEntries(watchlistID: uuid, status: .to_observe)
        } else {
            entries = try persistence.fetchAllEntries().filter { $0.status == .to_observe }
        }
        
        // Filter by date range overlap
        let filtered = entries.filter { entry in
            guard let rangeStart = entry.toObserveStartDate,
                  let rangeEnd = entry.toObserveEndDate else {
                return false
            }
            
            // Check if ranges overlap
            return rangeStart <= end && rangeEnd >= start
        }
        
        return filtered.compactMap { $0.toDomain() }
    }
    
    func getEntriesForThisWeek(watchlistID: WatchlistIdentifier? = nil) throws -> [WatchlistEntryDTO] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }
        
        return try getEntriesInDateRange(start: weekStart, end: weekEnd, watchlistID: watchlistID)
    }
    
    // MARK: - Integration Queries (Home Module)
    
    func getUpcomingBirds(
        userLocation: CLLocationCoordinate2D,
        currentWeek: Int,
        lookAheadWeeks: Int = 4,
        radiusInKm: Double = 50.0
    ) async throws -> [UpcomingBirdResult] {
        
        // Get all watchlist entries with notifications enabled
        let allEntries = try persistence.fetchAllEntries()
        let notifyEntries = allEntries.filter {
            $0.notify_upcoming && $0.status == .to_observe
        }
        
        // For each bird, check if it's present at user's location
        var results: [UpcomingBirdResult] = []
        let hotspotManager = HotspotManager(modelContext: context)
        
        for entry in notifyEntries {
            guard let bird = entry.bird else { continue }
            
            // Check weeks in the upcoming window
            for weekOffset in 0...lookAheadWeeks {
                let checkWeek = ((currentWeek + weekOffset - 1) % 52) + 1 // Wrap around year
                
                let presentBirds = await hotspotManager.getBirdsPresent(
                    at: userLocation,
                    duringWeek: checkWeek,
                    radiusInKm: radiusInKm
                )
                
                if presentBirds.contains(where: { $0.id == bird.id }) {
                    results.append(UpcomingBirdResult(
                        bird: bird,
                        entry: entry,
                        expectedWeek: checkWeek,
                        daysUntil: weekOffset * 7,
                        migrationDateRange: nil
                    ))
                    break // Only add each bird once
                }
            }
        }
        
        return results.sorted { $0.daysUntil < $1.daysUntil }
    }
}

// MARK: - Supporting Types

struct UpcomingBirdResult: Identifiable {
    let id = UUID()
    let bird: Bird
    let entry: WatchlistEntry
    let expectedWeek: Int
    let daysUntil: Int
    let migrationDateRange: String?
    
    var isArriving: Bool { daysUntil <= 7 }
    var isPresentNow: Bool { daysUntil == 0 }
    var statusText: String {
        if let range = migrationDateRange { return range }
        if isPresentNow { return "Here now!" }
        if isArriving { return "Arriving this week" }
        if daysUntil <= 14 { return "Arriving in \(daysUntil) days" }
        return "Expected in \(daysUntil / 7) weeks"
    }
}
