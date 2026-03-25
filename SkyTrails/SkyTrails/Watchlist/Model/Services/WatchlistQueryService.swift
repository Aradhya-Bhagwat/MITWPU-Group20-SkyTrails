import Foundation
import SwiftData
import CoreLocation

@MainActor
final class WatchlistQueryService {
    
    private struct EntryBucketKey: Hashable {
        let birdID: UUID
        let status: WatchlistEntryStatus
    }

    private struct EntryAggregation {
        let observed: [WatchlistEntry]
        let unobserved: [WatchlistEntry]

        var allEntries: [WatchlistEntry] {
            unobserved + observed
        }

        var stats: WatchlistStatsDTO {
            let observedCount = observed.count
            let unobservedCount = unobserved.count
            return WatchlistStatsDTO(
                observedCount: observedCount,
                unobservedCount: unobservedCount,
                totalCount: observedCount + unobservedCount
            )
        }
    }
    
    private let context: ModelContext
    private let persistence: WatchlistPersistenceService
    
    private var myWatchlistCache: (dto: WatchlistSummaryDTO, timestamp: Date)?
    private let cacheValidityDuration: TimeInterval = 2.0
    
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
        let watchlistIDs = allLists.map(\.watchlist_id)
        let allEntries = try persistence.fetchEntries(watchlistIDs: watchlistIDs)
        let entriesByWatchlist = allEntries.reduce(into: [UUID: [WatchlistEntry]]()) { partialResult, entry in
            guard let watchlistID = entry.watchlist?.watchlist_id else { return }
            partialResult[watchlistID, default: []].append(entry)
        }

        let customLists = allLists
            .filter { $0.type == .custom }
            .map { watchlist in
                buildSummaryDTO(for: watchlist, entries: entriesByWatchlist[watchlist.watchlist_id] ?? [])
            }

        let sharedLists = allLists
            .filter { $0.type == .shared }
            .map { watchlist in
                buildSummaryDTO(for: watchlist, entries: entriesByWatchlist[watchlist.watchlist_id] ?? [])
            }

        let myWatchlist = buildMyWatchlistDTO(from: allLists, entries: allEntries)
        let globalStats = aggregateEntries(allEntries).stats
        return (myWatchlist, customLists, sharedLists, globalStats)
    }
    
    func buildMyWatchlistDTO(from allLists: [Watchlist]) -> WatchlistSummaryDTO {
        let watchlistIDs = allLists.map(\.watchlist_id)
        let allEntries = (try? persistence.fetchEntries(watchlistIDs: watchlistIDs)) ?? []
        return buildMyWatchlistDTO(from: allLists, entries: allEntries)
    }

    func fetchEntries(
        identifier: WatchlistIdentifier,
        filter: WatchlistQueryFilter = WatchlistQueryFilter(),
        sort: WatchlistSortOption = .addedDateNewest
    ) throws -> [WatchlistEntryDTO] {
        let entries: [WatchlistEntry]

        if identifier.isVirtual {
            let allLists = try persistence.fetchWatchlists()
            let watchlistIDs = allLists.map(\.watchlist_id)
            entries = aggregateEntries(try persistence.fetchEntries(watchlistIDs: watchlistIDs), status: filter.status).allEntries
        } else if let uuid = identifier.uuid {
            entries = aggregateEntries(try persistence.fetchEntries(watchlistID: uuid, status: filter.status)).allEntries
        } else {
            return []
        }

        let filtered = apply(filter: filter, to: entries)
        return sortEntries(filtered, by: sort).compactMap { $0.toDomain() }
    }
    
    func getStats(for identifier: WatchlistIdentifier) throws -> WatchlistStatsDTO {
        if identifier.isVirtual {
            let allLists = try persistence.fetchWatchlists()
            let allEntries = try persistence.fetchEntries(watchlistIDs: allLists.map(\.watchlist_id))
            return aggregateEntries(allEntries).stats
        }

        if let uuid = identifier.uuid {
            return aggregateEntries(try persistence.fetchEntries(watchlistID: uuid)).stats
        }
        
        return .empty
    }
    
    func getGlobalObservedCount() throws -> Int {
        try aggregateEntries(try persistence.fetchAllEntries()).stats.observedCount
    }
    
    func getEntriesObservedNear(
        location: CLLocationCoordinate2D,
        radiusInKm: Double = 10.0,
        watchlistID: WatchlistIdentifier? = nil
    ) throws -> [WatchlistEntryDTO] {
        
        let allEntries: [WatchlistEntry]
        
        if let identifier = watchlistID, !identifier.isVirtual, let uuid = identifier.uuid {
            allEntries = aggregateEntries(try persistence.fetchEntries(watchlistID: uuid, status: .observed)).observed
        } else {
            allEntries = aggregateEntries(try persistence.fetchAllEntries(), status: .observed).observed
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
        
        let entries: [WatchlistEntry]
        
        if let identifier = watchlistID, !identifier.isVirtual, let uuid = identifier.uuid {
            entries = aggregateEntries(try persistence.fetchEntries(watchlistID: uuid, status: .to_observe)).unobserved
        } else {
            entries = aggregateEntries(try persistence.fetchAllEntries(), status: .to_observe).unobserved
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

    private func buildMyWatchlistDTO(from _: [Watchlist], entries: [WatchlistEntry]) -> WatchlistSummaryDTO {
        if let cached = myWatchlistCache,
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            return cached.dto
        }

        let dto = buildSummaryDTO(
            id: .virtual,
            title: "My Watchlist",
            subtitle: "All Birds",
            dateText: "",
            type: .my_watchlist,
            entries: entries
        )

        myWatchlistCache = (dto: dto, timestamp: Date())
        return dto
    }

    private func buildSummaryDTO(for watchlist: Watchlist, entries: [WatchlistEntry]) -> WatchlistSummaryDTO {
        let subtitle = watchlist.locationDisplayName ?? watchlist.location ?? "No location"

        let dateText: String
        if let start = watchlist.startDate, let end = watchlist.endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            dateText = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            dateText = "Season pending"
        }

        return buildSummaryDTO(
            id: WatchlistIdentifier.from(uuid: watchlist.watchlist_id, type: watchlist.type),
            title: watchlist.title ?? "Unnamed Watchlist",
            subtitle: subtitle,
            dateText: dateText,
            type: watchlist.type ?? .custom,
            entries: entries
        )
    }

    private func buildSummaryDTO(
        id: WatchlistIdentifier,
        title: String,
        subtitle: String,
        dateText: String,
        type: WatchlistType,
        entries: [WatchlistEntry]
    ) -> WatchlistSummaryDTO {
        let aggregation = aggregateEntries(entries)
        let unobservedPreviewImages = previewImages(from: aggregation.unobserved)
        let observedPreviewImages = previewImages(from: aggregation.observed)
        let previewImages = unobservedPreviewImages + observedPreviewImages

        return WatchlistSummaryDTO(
            id: id,
            title: title,
            subtitle: subtitle,
            dateText: dateText,
            image: previewImages.first,
            previewImages: previewImages,
            unobservedPreviewImages: unobservedPreviewImages,
            observedPreviewImages: observedPreviewImages,
            stats: aggregation.stats,
            type: type
        )
    }

    private func aggregateEntries(
        _ entries: [WatchlistEntry],
        status: WatchlistEntryStatus? = nil
    ) -> EntryAggregation {
        var buckets: [EntryBucketKey: WatchlistEntry] = [:]

        for entry in entries {
            guard let birdID = entry.bird?.bird_id else { continue }
            if let status, entry.status != status {
                continue
            }

            let key = EntryBucketKey(birdID: birdID, status: entry.status)
            if let existing = buckets[key] {
                if bucketDate(for: entry) > bucketDate(for: existing) {
                    buckets[key] = entry
                }
            } else {
                buckets[key] = entry
            }
        }

        let observed = buckets
            .filter { $0.key.status == .observed }
            .map(\.value)
            .sorted { bucketDate(for: $0) > bucketDate(for: $1) }

        let unobserved = buckets
            .filter { $0.key.status == .to_observe }
            .map(\.value)
            .sorted { bucketDate(for: $0) > bucketDate(for: $1) }

        return EntryAggregation(observed: observed, unobserved: unobserved)
    }

    private func previewImages(from entries: [WatchlistEntry]) -> [String] {
        Array(entries.compactMap(previewImageName(for:)).prefix(5))
    }

    private func previewImageName(for entry: WatchlistEntry) -> String? {
        if let photoPath = entry.photos?.first?.imagePath, !photoPath.isEmpty {
            return photoPath
        }

        guard let staticImageName = entry.bird?.staticImageName, !staticImageName.isEmpty else {
            return nil
        }

        return staticImageName
    }

    private func bucketDate(for entry: WatchlistEntry) -> Date {
        switch entry.status {
        case .observed:
            return entry.observationDate ?? entry.addedDate
        case .to_observe:
            return entry.addedDate
        }
    }

    private func apply(filter: WatchlistQueryFilter, to entries: [WatchlistEntry]) -> [WatchlistEntry] {
        var filtered = entries

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

        return filtered
    }

    private func sortEntries(_ entries: [WatchlistEntry], by option: WatchlistSortOption) -> [WatchlistEntry] {
        switch option {
        case .addedDateNewest:
            return entries.sorted { $0.addedDate > $1.addedDate }
        case .addedDateOldest:
            return entries.sorted { $0.addedDate < $1.addedDate }
        case .birdNameAZ:
            return entries.sorted { ($0.bird?.commonName ?? "") < ($1.bird?.commonName ?? "") }
        case .birdNameZA:
            return entries.sorted { ($0.bird?.commonName ?? "") > ($1.bird?.commonName ?? "") }
        case .observationDateNewest:
            return entries.sorted { ($0.observationDate ?? .distantPast) > ($1.observationDate ?? .distantPast) }
        case .observationDateOldest:
            return entries.sorted { ($0.observationDate ?? .distantFuture) < ($1.observationDate ?? .distantFuture) }
        case .priority:
            return entries.sorted { $0.priority > $1.priority }
        }
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
