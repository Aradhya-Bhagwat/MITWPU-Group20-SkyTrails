import Foundation
import SwiftData

enum InitialSyncError: Error, LocalizedError {
    case notAuthenticated
    case configNotLoaded
    case networkError(String)
    case decodingError(String)
    case contextError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated with Supabase"
        case .configNotLoaded:
            return "Failed to load Supabase configuration"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .contextError(let message):
            return "SwiftData context error: \(message)"
        }
    }
}

struct InitialSyncSummary: Sendable {
    let watchlistsSynced: Int
    let entriesSynced: Int
    let rulesSynced: Int
    let photosSynced: Int
    let timestamp: Date
    
    var totalSynced: Int {
        watchlistsSynced + entriesSynced + rulesSynced + photosSynced
    }
}

actor InitialSyncService {
    
    static let shared = InitialSyncService()
    
    private var config: SupabaseConfig?
    
    private init() {}
    
    func performInitialSync(userId: UUID) async throws -> InitialSyncSummary {
        print("🔄 [InitialSync] Starting initial sync for user: \(userId)")
        
        if config == nil {
            config = try SupabaseConfig.load()
        }
        
        guard let config else {
            throw InitialSyncError.configNotLoaded
        }
        
        guard let accessToken = await MainActor.run(body: { UserSession.shared.getAccessToken() }) else {
            throw InitialSyncError.notAuthenticated
        }
        
        // Fetch all data from server FIRST (outside MainActor)
        let watchlistRows: [WatchlistRow] = try await fetchFromSupabase(
            table: "watchlists",
            query: "select=*&owner_id=eq.\(userId.uuidString)&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )
        
        let entryRows: [WatchlistEntryRow] = try await fetchFromSupabase(
            table: "watchlist_entries",
            query: "select=*&watchlist_id=in.(select id from watchlists where owner_id=eq.\(userId.uuidString))",
            config: config,
            accessToken: accessToken
        )
        
        let ruleRows: [WatchlistRuleRow] = try await fetchFromSupabase(
            table: "watchlist_rules",
            query: "select=*&watchlist_id=in.(select id from watchlists where owner_id=eq.\(userId.uuidString))",
            config: config,
            accessToken: accessToken
        )
        
        let photoRows: [ObservedBirdPhotoRow] = try await fetchFromSupabase(
            table: "observed_bird_photos",
            query: "select=*&watchlist_entry_id=in.(select id from watchlist_entries where watchlist_id in (select id from watchlists where owner_id=eq.\(userId.uuidString)))",
            config: config,
            accessToken: accessToken
        )
        
        
        // Now merge into SwiftData on MainActor
        let (watchlistsCount, entriesCount, rulesCount, photosCount) = try await MainActor.run {
            let context = WatchlistManager.shared.context
            
            let wCount = try mergeWatchlists(watchlistRows, context: context)
            let eCount = try mergeEntries(entryRows, context: context)
            let rCount = try mergeRules(ruleRows, context: context)
            let pCount = try mergePhotos(photoRows, context: context)
            
            try context.save()
            
            return (wCount, eCount, rCount, pCount)
        }
        
        let summary = InitialSyncSummary(
            watchlistsSynced: watchlistsCount,
            entriesSynced: entriesCount,
            rulesSynced: rulesCount,
            photosSynced: photosCount,
            timestamp: Date()
        )
        
        print("🔄 [InitialSync] Completed: \(summary.totalSynced) items synced")
        return summary
    }
    
    private nonisolated func mergeWatchlists(_ rows: [WatchlistRow], context: ModelContext) throws -> Int {
        let existingWatchlists = try context.fetch(FetchDescriptor<Watchlist>())
        var existingById: [UUID: Watchlist] = [:]
        for watchlist in existingWatchlists {
            if watchlist.owner_id != nil && existingById[watchlist.id] == nil {
                existingById[watchlist.id] = watchlist
            }
        }
        
        var syncedCount = 0
        
        for row in rows {
            let watchlist: Watchlist
            if let existing = existingById[row.id] {
                updateWatchlist(existing, from: row)
                watchlist = existing
            } else {
                watchlist = createWatchlist(from: row)
                context.insert(watchlist)
            }
            watchlist.syncStatus = .synced
            watchlist.lastSyncedAt = Date()
            syncedCount += 1
        }
        
        print("🔄 [InitialSync] Synced \(syncedCount) watchlists")
        return syncedCount
    }
    
    private nonisolated func mergeEntries(_ rows: [WatchlistEntryRow], context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<WatchlistEntry>()
        let existingEntries = try context.fetch(descriptor)
        var existingById: [UUID: WatchlistEntry] = [:]
        for entry in existingEntries {
            existingById[entry.id] = entry
        }
        
        let watchlistsDescriptor = FetchDescriptor<Watchlist>()
        let watchlists = try context.fetch(watchlistsDescriptor)
        var watchlistById: [UUID: Watchlist] = [:]
        for watchlist in watchlists {
            watchlistById[watchlist.id] = watchlist
        }
        
        let birdsDescriptor = FetchDescriptor<Bird>()
        let birds = try context.fetch(birdsDescriptor)
        var birdById: [UUID: Bird] = [:]
        for bird in birds {
            birdById[bird.id] = bird
        }
        
        var syncedCount = 0
        
        for row in rows {
            let entry: WatchlistEntry
            if let existing = existingById[row.id] {
                updateEntry(existing, from: row, watchlistById: watchlistById, birdById: birdById)
                entry = existing
            } else {
                entry = createEntry(from: row, watchlistById: watchlistById, birdById: birdById)
                context.insert(entry)
            }
            entry.syncStatus = .synced
            entry.lastSyncedAt = Date()
            syncedCount += 1
        }
        
        print("🔄 [InitialSync] Synced \(syncedCount) entries")
        return syncedCount
    }
    
    private nonisolated func mergeRules(_ rows: [WatchlistRuleRow], context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<WatchlistRule>()
        let existingRules = try context.fetch(descriptor)
        var existingById: [UUID: WatchlistRule] = [:]
        for rule in existingRules {
            existingById[rule.id] = rule
        }
        
        let watchlistsDescriptor = FetchDescriptor<Watchlist>()
        let watchlists = try context.fetch(watchlistsDescriptor)
        var watchlistById: [UUID: Watchlist] = [:]
        for watchlist in watchlists {
            watchlistById[watchlist.id] = watchlist
        }
        
        var syncedCount = 0
        
        for row in rows {
            let rule: WatchlistRule
            if let existing = existingById[row.id] {
                updateRule(existing, from: row, watchlistById: watchlistById)
                rule = existing
            } else {
                rule = createRule(from: row, watchlistById: watchlistById)
                context.insert(rule)
            }
            rule.syncStatus = .synced
            rule.lastSyncedAt = Date()
            syncedCount += 1
        }
        
        print("🔄 [InitialSync] Synced \(syncedCount) rules")
        return syncedCount
    }
    
    private nonisolated func mergePhotos(_ rows: [ObservedBirdPhotoRow], context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<ObservedBirdPhoto>()
        let existingPhotos = try context.fetch(descriptor)
        var existingById: [UUID: ObservedBirdPhoto] = [:]
        for photo in existingPhotos {
            existingById[photo.id] = photo
        }
        
        let entriesDescriptor = FetchDescriptor<WatchlistEntry>()
        let entries = try context.fetch(entriesDescriptor)
        var entryById: [UUID: WatchlistEntry] = [:]
        for entry in entries {
            entryById[entry.id] = entry
        }
        
        var syncedCount = 0
        
        for row in rows {
            let photo: ObservedBirdPhoto
            if let existing = existingById[row.id] {
                updatePhoto(existing, from: row, entryById: entryById)
                photo = existing
            } else {
                photo = createPhoto(from: row, entryById: entryById)
                context.insert(photo)
            }
            photo.syncStatus = .synced
            photo.lastSyncedAt = Date()
            syncedCount += 1
        }
        
        print("🔄 [InitialSync] Synced \(syncedCount) photos")
        return syncedCount
    }
    
    private nonisolated func fetchFromSupabase<T: Decodable>(
        table: String,
        query: String,
        config: SupabaseConfig,
        accessToken: String
    ) async throws -> [T] {
        let urlString = "\(config.projectURL.absoluteString)/rest/v1/\(table)?\(query)"
        
        guard let url = URL(string: urlString) else {
            throw InitialSyncError.networkError("Invalid URL: \(urlString)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw InitialSyncError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InitialSyncError.networkError("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InitialSyncError.networkError("HTTP \(httpResponse.statusCode): \(message)")
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([T].self, from: data)
        } catch {
            throw InitialSyncError.decodingError(error.localizedDescription)
        }
    }
    
    private nonisolated func createWatchlist(from row: WatchlistRow) -> Watchlist {
        let watchlist = Watchlist(
            id: row.id,
            owner_id: row.ownerId,
            type: WatchlistType(rawValue: row.type) ?? .custom,
            title: row.title,
            location: row.location,
            locationDisplayName: row.locationDisplayName,
            startDate: row.startDate,
            endDate: row.endDate
        )
        updateWatchlist(watchlist, from: row)
        return watchlist
    }
    
    private nonisolated func updateWatchlist(_ watchlist: Watchlist, from row: WatchlistRow) {
        watchlist.owner_id = row.ownerId
        watchlist.type = WatchlistType(rawValue: row.type) ?? .custom
        watchlist.title = row.title
        watchlist.location = row.location
        watchlist.locationDisplayName = row.locationDisplayName
        watchlist.startDate = row.startDate
        watchlist.endDate = row.endDate
        watchlist.observedCount = row.observedCount
        watchlist.speciesCount = row.speciesCount
        watchlist.coverImagePath = row.coverImagePath
        watchlist.speciesRuleEnabled = row.speciesRuleEnabled
        watchlist.speciesRuleShapeId = row.speciesRuleShapeId
        watchlist.locationRuleEnabled = row.locationRuleEnabled
        watchlist.locationRuleLat = row.locationRuleLat
        watchlist.locationRuleLon = row.locationRuleLon
        watchlist.locationRuleRadiusKm = row.locationRuleRadiusKm ?? 50.0
        watchlist.locationRuleDisplayName = row.locationRuleDisplayName
        watchlist.dateRuleEnabled = row.dateRuleEnabled
        watchlist.dateRuleStartDate = row.dateRuleStartDate
        watchlist.dateRuleEndDate = row.dateRuleEndDate
        watchlist.serverRowVersion = row.rowVersion
        watchlist.deleted_at = row.deletedAt
        watchlist.created_at = row.createdAt
        watchlist.updated_at = row.updatedAt
    }
    
    private nonisolated func createEntry(
        from row: WatchlistEntryRow,
        watchlistById: [UUID: Watchlist],
        birdById: [UUID: Bird]
    ) -> WatchlistEntry {
        let entry = WatchlistEntry(
            id: row.id,
            status: WatchlistEntryStatus(rawValue: row.status) ?? .to_observe,
            notes: row.notes,
            observationDate: row.observationDate,
            observedBy: row.observedBy
        )
        updateEntry(entry, from: row, watchlistById: watchlistById, birdById: birdById)
        return entry
    }
    
    private nonisolated func updateEntry(
        _ entry: WatchlistEntry,
        from row: WatchlistEntryRow,
        watchlistById: [UUID: Watchlist],
        birdById: [UUID: Bird]
    ) {
        entry.watchlist = watchlistById[row.watchlistId]
        entry.bird = birdById[row.birdId]
        entry.nickname = row.nickname
        entry.status = WatchlistEntryStatus(rawValue: row.status) ?? .to_observe
        entry.notes = row.notes
        entry.addedDate = row.addedDate
        entry.observationDate = row.observationDate
        entry.toObserveStartDate = row.toObserveStartDate
        entry.toObserveEndDate = row.toObserveEndDate
        entry.observedBy = row.observedBy
        entry.lat = row.lat
        entry.lon = row.lon
        entry.locationDisplayName = row.locationDisplayName
        entry.priority = row.priority
        entry.notify_upcoming = row.notifyUpcoming
        entry.target_date_range = row.targetDateRange
        entry.serverRowVersion = row.rowVersion
        entry.addedDate = row.createdAt
    }
    
    private nonisolated func createRule(
        from row: WatchlistRuleRow,
        watchlistById: [UUID: Watchlist]
    ) -> WatchlistRule {
        let rule = WatchlistRule(
            id: row.id,
            rule_type: WatchlistRuleType(rawValue: row.ruleType) ?? .location,
            parameters: row.parametersJson
        )
        updateRule(rule, from: row, watchlistById: watchlistById)
        return rule
    }
    
    private nonisolated func updateRule(
        _ rule: WatchlistRule,
        from row: WatchlistRuleRow,
        watchlistById: [UUID: Watchlist]
    ) {
        rule.watchlist = watchlistById[row.watchlistId]
        rule.rule_type = WatchlistRuleType(rawValue: row.ruleType) ?? .location
        rule.parameters_json = row.parametersJson
        rule.is_active = row.isActive
        rule.priority = row.priority
        rule.serverRowVersion = row.rowVersion
        rule.deleted_at = row.deletedAt
        rule.created_at = row.createdAt
    }
    
    private nonisolated func createPhoto(
        from row: ObservedBirdPhotoRow,
        entryById: [UUID: WatchlistEntry]
    ) -> ObservedBirdPhoto {
        let photo = ObservedBirdPhoto(
            id: row.id,
            imagePath: row.imagePath
        )
        updatePhoto(photo, from: row, entryById: entryById)
        return photo
    }
    
    private nonisolated func updatePhoto(
        _ photo: ObservedBirdPhoto,
        from row: ObservedBirdPhotoRow,
        entryById: [UUID: WatchlistEntry]
    ) {
        photo.watchlistEntry = entryById[row.watchlistEntryId]
        photo.imagePath = row.imagePath
        photo.storageUrl = row.storageUrl
        photo.isUploaded = row.isUploaded
        photo.captured_at = row.capturedAt
        photo.uploaded_at = row.uploadedAt ?? Date()
    }
}
