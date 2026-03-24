
import Foundation
import SwiftData
import CoreLocation

@MainActor
final class WatchlistQueryService {
    
    private let context: ModelContext
    private let persistence: WatchlistPersistenceService
    
    // Caching for My Watchlist
    private var myWatchlistCache: (dto: WatchlistSummaryDTO, timestamp: Date)?
    private let cacheValidityDuration: TimeInterval = 2.0 // 2 seconds
    
    init(context: ModelContext, persistence: WatchlistPersistenceService) {
        self.context = context
        self.persistence = persistence
    }
    
    func invalidateMyWatchlistCache() {
        myWatchlistCache = nil
    }
    
    func loadDashboardData() async throws -> (
        myWatchlist: WatchlistSummaryDTO?,
        custom: [WatchlistSummaryDTO],
        shared: [WatchlistSummaryDTO],
        globalStats: WatchlistStatsDTO
    ) {
        let allLists = try persistence.fetchWatchlists()
        let customLists = allLists.filter { $0.type == .custom }.map { $0.toSummary() }
        let sharedLists = allLists.filter { $0.type == .shared }.map { $0.toSummary() }
        let myWatchlist = buildMyWatchlistDTO(from: allLists)
        let allEntries = allLists.flatMap { $0.entries ?? [] }
        let globalStats = calculateStats(from: allEntries)
        return (myWatchlist, customLists, sharedLists, globalStats)
    }
    
    func buildMyWatchlistDTO(from allLists: [Watchlist]) -> WatchlistSummaryDTO {
        // Check cache validity
        if let cached = myWatchlistCache,
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            return cached.dto
        }
        
        let allEntries = allLists.flatMap { $0.entries ?? [] }
        var uniqueEntries: [UUID: WatchlistEntry] = [:]
        for entry in allEntries {
            if let birdId = entry.bird?.bird_id {
                if let existing = uniqueEntries[birdId] {
                    // Priority rules:
                    // 1. Observed status beats unobserved
                    // 2. If same status, newer date wins
                    let entryDate = entry.observationDate ?? entry.addedDate
                    let existingDate = existing.observationDate ?? existing.addedDate
                    
                    let shouldReplace = 
                        (entry.status == .observed && existing.status != .observed) ||
                        (entry.status == existing.status && entryDate > existingDate)
                    
                    if shouldReplace {
                        uniqueEntries[birdId] = entry
                    }
                } else {
                    uniqueEntries[birdId] = entry
                }
            }
        }
        
        let uniqueEntriesArray = Array(uniqueEntries.values)
        let stats = calculateStats(from: uniqueEntriesArray)
        
        let toObserveImages = uniqueEntriesArray
            .filter { $0.status == .to_observe }
            .compactMap { entry -> String? in
                if let photoPath = entry.photos?.first?.imagePath {
                    return photoPath
                }
                return entry.bird?.staticImageName
            }
            .prefix(5)
            .map { String($0) }
            
        let observedImages = uniqueEntriesArray
            .filter { $0.status == .observed }
            .compactMap { entry -> String? in
                if let photoPath = entry.photos?.first?.imagePath {
                    return photoPath
                }
                return entry.bird?.staticImageName
            }
            .prefix(5)
            .map { String($0) }
            
        let previewImages = Array(toObserveImages) + Array(observedImages)
        
        let dto = WatchlistSummaryDTO(
            id: .virtual,
            title: "My Watchlist",
            subtitle: "All Birds",
            dateText: "",
            image: previewImages.first,
            previewImages: Array(previewImages),
            unobservedPreviewImages: Array(toObserveImages),
            observedPreviewImages: Array(observedImages),
            stats: stats,
            type: .my_watchlist
        )
        
        // Update cache
        myWatchlistCache = (dto: dto, timestamp: Date())
        
        return dto
    }
    
    func fetchEntries(
        identifier: WatchlistIdentifier,
        filter: WatchlistQueryFilter = WatchlistQueryFilter(),
        sort: WatchlistSortOption = .addedDateNewest
    ) throws -> [WatchlistEntryDTO] {
        let entries: [WatchlistEntry]
        
        if identifier.isVirtual {
            let allLists = try persistence.fetchWatchlists()
            entries = allLists.flatMap { $0.entries ?? [] }
        } else if let uuid = identifier.uuid {
            entries = try persistence.fetchEntries(watchlistID: uuid)
        } else {
            return []
        }
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
        return filtered.compactMap { $0.toDomain() }
    }
    
    func getStats(for identifier: WatchlistIdentifier) throws -> WatchlistStatsDTO {
        if identifier.isVirtual {
            let allLists = try persistence.fetchWatchlists()
            let allEntries = allLists.flatMap { $0.entries ?? [] }
            return calculateStats(from: allEntries)
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
        let withLocation = allEntries.filter { $0.lat != nil && $0.lon != nil }
        let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let nearby = withLocation.filter { entry in
            guard let lat = entry.lat, let lon = entry.lon else { return false }
            let entryLoc = CLLocation(latitude: lat, longitude: lon)
            return entryLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
        }
        
        return nearby.compactMap { $0.toDomain() }
    }
    
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
        let filtered = entries.filter { entry in
            guard let rangeStart = entry.toObserveStartDate,
                  let rangeEnd = entry.toObserveEndDate else {
                return false
            }
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
    
    func getUpcomingBirds(
        userLocation: CLLocationCoordinate2D,
        currentWeek: Int,
        lookAheadWeeks: Int = 4,
        radiusInKm: Double = 50.0
    ) async throws -> [UpcomingBirdResult] {
        let allEntries = try persistence.fetchAllEntries()
        let notifyEntries = allEntries.filter {
            $0.notify_upcoming && $0.status == .to_observe
        }
        var results: [UpcomingBirdResult] = []
        let hotspotManager = HotspotManager(modelContext: context)
        
        for entry in notifyEntries {
            guard let bird = entry.bird else { continue }
            for weekOffset in 0...lookAheadWeeks {
                let checkWeek = ((currentWeek + weekOffset - 1) % 52) + 1
                
                let presentBirds = await hotspotManager.getBirdsPresent(
                    at: userLocation,
                    duringWeek: checkWeek,
                    radiusInKm: radiusInKm
                )
                
                if presentBirds.contains(where: { $0.bird_id == bird.bird_id }) {
                    results.append(UpcomingBirdResult(
                        bird: bird,
                        entry: entry,
                        expectedWeek: checkWeek,
                        daysUntil: weekOffset * 7,
                        migrationDateRange: nil
                    ))
                    break
                }
            }
        }
        
        return results.sorted { $0.daysUntil < $1.daysUntil }
    }
}

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
