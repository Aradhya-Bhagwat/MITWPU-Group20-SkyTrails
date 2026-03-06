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
    let sharesSynced: Int
    let photosSynced: Int
    let timestamp: Date
    
    nonisolated var totalSynced: Int {
        watchlistsSynced + entriesSynced + rulesSynced + sharesSynced + photosSynced
    }
}

actor InitialSyncService {
    
    static let shared = InitialSyncService()
    
    private var config: SupabaseConfig?
    
    private init() {}
    
    func performInitialSync(userId: UUID) async throws -> InitialSyncSummary {
        if config == nil {
            config = try SupabaseConfig.load()
        }
        
        guard let config else {
            throw InitialSyncError.configNotLoaded
        }
        
        guard let accessToken = await MainActor.run(body: { UserSession.shared.getAccessToken() }) else {
            throw InitialSyncError.notAuthenticated
        }
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
        
        let shareRows: [WatchlistShareRow] = try await fetchFromSupabase(
            table: "watchlist_shares",
            query: "select=*&or=(watchlist_id.in.(select id from watchlists where owner_id=eq.\(userId.uuidString)),user_id.eq.\(userId.uuidString))",
            config: config,
            accessToken: accessToken
        )
        
        let photoRows: [ObservedBirdPhotoRow] = try await fetchFromSupabase(
            table: "observed_bird_photos",
            query: "select=*&watchlist_entry_id=in.(select id from watchlist_entries where watchlist_id in (select id from watchlists where owner_id=eq.\(userId.uuidString)))",
            config: config,
            accessToken: accessToken
        )
        let (watchlistsCount, entriesCount, rulesCount, sharesCount, photosCount) = try await MainActor.run {
            let context = WatchlistManager.shared.context
            
            let wCount = try mergeWatchlists(watchlistRows, context: context)
            let eCount = try mergeEntries(entryRows, context: context)
            let rCount = try mergeRules(ruleRows, context: context)
            let sCount = try mergeShares(shareRows, context: context)
            let pCount = try mergePhotos(photoRows, context: context)
            
            try context.save()
            
            return (wCount, eCount, rCount, sCount, pCount)
        }
        
        let summary = InitialSyncSummary(
            watchlistsSynced: watchlistsCount,
            entriesSynced: entriesCount,
            rulesSynced: rulesCount,
            sharesSynced: sharesCount,
            photosSynced: photosCount,
            timestamp: Date()
        )
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
        return syncedCount
    }
    
    private nonisolated func mergeShares(_ rows: [WatchlistShareRow], context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<WatchlistShare>()
        let existingShares = try context.fetch(descriptor)
        var existingById: [UUID: WatchlistShare] = [:]
        for share in existingShares {
            existingById[share.id] = share
        }
        
        let watchlistsDescriptor = FetchDescriptor<Watchlist>()
        let watchlists = try context.fetch(watchlistsDescriptor)
        var watchlistById: [UUID: Watchlist] = [:]
        for watchlist in watchlists {
            watchlistById[watchlist.id] = watchlist
        }
        
        var syncedCount = 0
        for row in rows {
            let share: WatchlistShare
            if let existing = existingById[row.id] {
                updateShare(existing, from: row, watchlistById: watchlistById)
                share = existing
            } else {
                share = createShare(from: row, watchlistById: watchlistById)
                context.insert(share)
            }
            share.syncStatus = .synced
            share.lastSyncedAt = Date()
            syncedCount += 1
        }
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
            observedBy: row.observedBy,
            observedByUserId: row.observedByUserId
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
        if let birdId = row.birdId {
            entry.bird = birdById[birdId]
        } else {
            entry.bird = nil
        }
        entry.nickname = row.nickname
        entry.status = WatchlistEntryStatus(rawValue: row.status) ?? .to_observe
        entry.notes = row.notes
        entry.addedDate = row.addedDate
        entry.observationDate = row.observationDate
        entry.toObserveStartDate = row.toObserveStartDate
        entry.toObserveEndDate = row.toObserveEndDate
        entry.observedBy = row.observedBy
        entry.observedByUserId = row.observedByUserId
        entry.lat = row.lat
        entry.lon = row.lon
        entry.locationDisplayName = row.locationDisplayName
        entry.priority = row.priority
        entry.notify_upcoming = row.notifyUpcoming
        entry.serverRowVersion = row.rowVersion
    }
    
    private nonisolated func createRule(
        from row: WatchlistRuleRow,
        watchlistById: [UUID: Watchlist]
    ) -> WatchlistRule {
        let rule = WatchlistRule(
            id: row.id,
            rule_type: WatchlistRuleType(rawValue: row.ruleType) ?? .location
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
        rule.lat = row.lat
        rule.lon = row.lon
        rule.radius_km = row.radiusKm
        rule.start_date = row.startDate
        rule.end_date = row.endDate
        rule.shape_id = row.shapeId
        rule.pattern_key = row.patternKey
        rule.is_active = row.isActive
        rule.priority = row.priority
        rule.serverRowVersion = row.rowVersion
        rule.deleted_at = row.deletedAt
        rule.created_at = row.createdAt
    }
    
    private nonisolated func createShare(
        from row: WatchlistShareRow,
        watchlistById: [UUID: Watchlist]
    ) -> WatchlistShare {
        let share = WatchlistShare(
            id: row.id,
            watchlist: watchlistById[row.watchlistId],
            user_id: row.userId,
            permission: WatchlistSharePermission(rawValue: row.permission) ?? .view
        )
        updateShare(share, from: row, watchlistById: watchlistById)
        return share
    }
    
    private nonisolated func updateShare(
        _ share: WatchlistShare,
        from row: WatchlistShareRow,
        watchlistById: [UUID: Watchlist]
    ) {
        share.watchlist = watchlistById[row.watchlistId]
        share.user_id = row.userId
        share.permission = WatchlistSharePermission(rawValue: row.permission) ?? .view
        share.shared_at = row.sharedAt
        share.shared_by_user_id = row.sharedByUserId
        share.serverRowVersion = row.serverRowVersion
        share.deleted_at = row.deletedAt
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
        photo.serverRowVersion = row.rowVersion
        photo.captured_at = row.capturedAt
        photo.uploaded_at = row.uploadedAt ?? Date()
    }
}
