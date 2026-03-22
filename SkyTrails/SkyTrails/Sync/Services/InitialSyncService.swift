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
    let sessionsSynced: Int
    let resultsSynced: Int
    let candidatesSynced: Int
    let marksSynced: Int
    let timestamp: Date
    
    nonisolated var totalSynced: Int {
        watchlistsSynced + entriesSynced + rulesSynced + sharesSynced + photosSynced +
        sessionsSynced + resultsSynced + candidatesSynced + marksSynced
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

        // --- STEP: Restore User Profile ---
        do {
            if let serverUser = try await UserSyncService.shared.fetchUser(user_id: userId) {
                await MainActor.run {
                    if let currentUser = UserSession.shared.getUser() {
                        var updated = currentUser
                        updated.name = serverUser.name
                        updated.gender = serverUser.gender
                        updated.profilePhoto = serverUser.profilePhoto
                        UserSession.shared.saveUser(updated)
                    } else {
                        UserSession.shared.saveUser(serverUser)
                    }
                }
            }
        } catch {
            print("DEBUG: InitialSyncService - Failed to restore user profile: \(error)")
        }
        // ---------------------------------

        let watchlistRows: [WatchlistRow] = try await fetchFromSupabase(
            table: "watchlists",
            query: "select=*&user_id=eq.\(userId.uuidString)&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )
        
        let entryRows: [WatchlistEntryRow] = try await fetchFromSupabase(
            table: "watchlist_entries",
            query: "select=*&watchlist_id=in.(select watchlist_id from watchlists where user_id=eq.\(userId.uuidString))",
            config: config,
            accessToken: accessToken
        )
        
        let ruleRows: [WatchlistRuleRow] = try await fetchFromSupabase(
            table: "watchlist_rules",
            query: "select=*&watchlist_id=in.(select watchlist_id from watchlists where user_id=eq.\(userId.uuidString))",
            config: config,
            accessToken: accessToken
        )
        
        let shareRows: [WatchlistShareRow] = try await fetchFromSupabase(
            table: "watchlist_shares",
            query: "select=*&or=(watchlist_id.in.(select watchlist_id from watchlists where user_id=eq.\(userId.uuidString)),user_id.eq.\(userId.uuidString))",
            config: config,
            accessToken: accessToken
        )
        
        let photoRows: [ObservedBirdPhotoRow] = try await fetchFromSupabase(
            table: "observed_bird_photos",
            query: "select=*&watchlist_entry_id=in.(select watchlist_entry_id from watchlist_entries where watchlist_id in (select watchlist_id from watchlists where user_id=eq.\(userId.uuidString)))",
            config: config,
            accessToken: accessToken
        )

        // Identification Sync
        let sessionRows: [IdentificationSessionRow] = try await fetchFromSupabase(
            table: "identification_sessions",
            query: "select=*&user_id=eq.\(userId.uuidString)",
            config: config,
            accessToken: accessToken
        )

        let resultRows: [IdentificationResultRow] = try await fetchFromSupabase(
            table: "identification_results",
            query: "select=*&identification_session_id=in.(select identification_session_id from identification_sessions where user_id=eq.\(userId.uuidString))",
            config: config,
            accessToken: accessToken
        )

        let candidateRows: [IdentificationCandidateRow] = try await fetchFromSupabase(
            table: "identification_candidates",
            query: "select=*&identification_result_id=in.(select identification_result_id from identification_results where identification_session_id in (select identification_session_id from identification_sessions where user_id=eq.\(userId.uuidString)))",
            config: config,
            accessToken: accessToken
        )

        let markRows: [IdentificationSessionFieldMarkRow] = try await fetchFromSupabase(
            table: "identification_session_marks",
            query: "select=*&identification_session_id=in.(select identification_session_id from identification_sessions where user_id=eq.\(userId.uuidString))",
            config: config,
            accessToken: accessToken
        )

        let counts = try await MainActor.run {
            let context = WatchlistManager.shared.context
            
            let wCount = try mergeWatchlists(watchlistRows, context: context)
            let eCount = try mergeEntries(entryRows, context: context)
            let rCount = try mergeRules(ruleRows, context: context)
            let sCount = try mergeShares(shareRows, context: context)
            let pCount = try mergePhotos(photoRows, context: context)
            
            let sessCount = try mergeIdentificationSessions(sessionRows, context: context)
            let resCount = try mergeIdentificationResults(resultRows, context: context)
            let candCount = try mergeIdentificationCandidates(candidateRows, context: context)
            let markCount = try mergeIdentificationSessionMarks(markRows, context: context)

            try context.save()
            
            return (wCount, eCount, rCount, sCount, pCount, sessCount, resCount, candCount, markCount)
        }
        
        let summary = InitialSyncSummary(
            watchlistsSynced: counts.0,
            entriesSynced: counts.1,
            rulesSynced: counts.2,
            sharesSynced: counts.3,
            photosSynced: counts.4,
            sessionsSynced: counts.5,
            resultsSynced: counts.6,
            candidatesSynced: counts.7,
            marksSynced: counts.8,
            timestamp: Date()
        )
        return summary
    }
    
    private nonisolated func mergeWatchlists(_ rows: [WatchlistRow], context: ModelContext) throws -> Int {
        let existingWatchlists = try context.fetch(FetchDescriptor<Watchlist>())
        var existingById: [UUID: Watchlist] = [:]
        for watchlist in existingWatchlists {
            if existingById[watchlist.watchlist_id] == nil {
                existingById[watchlist.watchlist_id] = watchlist
            }
        }
        
        var syncedCount = 0
        
        for row in rows {
            let watchlist: Watchlist
            if let existing = existingById[row.watchlist_id] {
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
            watchlistById[watchlist.watchlist_id] = watchlist
        }
        
        let birdsDescriptor = FetchDescriptor<Bird>()
        let birds = try context.fetch(birdsDescriptor)
        var birdById: [UUID: Bird] = [:]
        for bird in birds {
            birdById[bird.bird_id] = bird
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
            watchlistById[watchlist.watchlist_id] = watchlist
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
            watchlistById[watchlist.watchlist_id] = watchlist
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

    private nonisolated func mergeIdentificationSessions(_ rows: [IdentificationSessionRow], context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<IdentificationSession>()
        let existingSessions = try context.fetch(descriptor)
        var existingById: [UUID: IdentificationSession] = [:]
        for session in existingSessions {
            existingById[session.identification_session_id] = session
        }

        let shapesDescriptor = FetchDescriptor<BirdShape>()
        let shapes = try context.fetch(shapesDescriptor)
        var shapeById: [String: BirdShape] = [:]
        for shape in shapes {
            shapeById[shape.bird_shape_id] = shape
        }

        var syncedCount = 0
        for row in rows {
            let session: IdentificationSession
            if let existing = existingById[row.id] {
                updateIdentificationSession(existing, from: row, shapeById: shapeById)
                session = existing
            } else {
                session = createIdentificationSession(from: row, shapeById: shapeById)
                context.insert(session)
            }
            session.syncStatus = .synced
            session.lastSyncedAt = Date()
            syncedCount += 1
        }
        return syncedCount
    }

    private nonisolated func mergeIdentificationResults(_ rows: [IdentificationResultRow], context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<IdentificationResult>()
        let existingResults = try context.fetch(descriptor)
        var existingById: [UUID: IdentificationResult] = [:]
        for result in existingResults {
            existingById[result.identification_result_id] = result
        }

        let sessionsDescriptor = FetchDescriptor<IdentificationSession>()
        let sessions = try context.fetch(sessionsDescriptor)
        var sessionById: [UUID: IdentificationSession] = [:]
        for session in sessions {
            sessionById[session.identification_session_id] = session
        }

        let birdsDescriptor = FetchDescriptor<Bird>()
        let birds = try context.fetch(birdsDescriptor)
        var birdById: [UUID: Bird] = [:]
        for bird in birds {
            birdById[bird.bird_id] = bird
        }

        var syncedCount = 0
        for row in rows {
            // Safer check: only merge if the parent session exists locally
            guard sessionById[row.sessionId] != nil else { continue }
            
            let result: IdentificationResult
            if let existing = existingById[row.id] {
                updateIdentificationResult(existing, from: row, sessionById: sessionById, birdById: birdById)
                result = existing
            } else {
                result = createIdentificationResult(from: row, sessionById: sessionById, birdById: birdById)
                context.insert(result)
            }
            result.syncStatus = .synced
            result.lastSyncedAt = Date()
            syncedCount += 1
        }
        return syncedCount
    }

    private nonisolated func mergeIdentificationCandidates(_ rows: [IdentificationCandidateRow], context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<IdentificationCandidate>()
        let existingCandidates = try context.fetch(descriptor)
        var existingById: [UUID: IdentificationCandidate] = [:]
        for candidate in existingCandidates {
            existingById[candidate.identification_candidate_id] = candidate
        }

        let resultsDescriptor = FetchDescriptor<IdentificationResult>()
        let results = try context.fetch(resultsDescriptor)
        var resultById: [UUID: IdentificationResult] = [:]
        for result in results {
            resultById[result.identification_result_id] = result
        }

        let birdsDescriptor = FetchDescriptor<Bird>()
        let birds = try context.fetch(birdsDescriptor)
        var birdById: [UUID: Bird] = [:]
        for bird in birds {
            birdById[bird.bird_id] = bird
        }

        var syncedCount = 0
        for row in rows {
            // Safer check: only merge if parent result and target bird exist locally
            guard resultById[row.resultId] != nil, birdById[row.birdId] != nil else { continue }
            
            let candidate: IdentificationCandidate
            if let existing = existingById[row.id] {
                updateIdentificationCandidate(existing, from: row, resultById: resultById, birdById: birdById)
                candidate = existing
            } else {
                candidate = createIdentificationCandidate(from: row, resultById: resultById, birdById: birdById)
                context.insert(candidate)
            }
            candidate.syncStatus = .synced
            candidate.lastSyncedAt = Date()
            syncedCount += 1
        }
        return syncedCount
    }

    private nonisolated func mergeIdentificationSessionMarks(_ rows: [IdentificationSessionFieldMarkRow], context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<IdentificationSessionFieldMark>()
        let existingMarks = try context.fetch(descriptor)
        var existingById: [UUID: IdentificationSessionFieldMark] = [:]
        for mark in existingMarks {
            existingById[mark.identification_session_mark_id] = mark
        }

        let sessionsDescriptor = FetchDescriptor<IdentificationSession>()
        let sessions = try context.fetch(sessionsDescriptor)
        var sessionById: [UUID: IdentificationSession] = [:]
        for session in sessions {
            sessionById[session.identification_session_id] = session
        }

        var syncedCount = 0
        for row in rows {
            // Safer check: only merge if parent session exists locally
            guard sessionById[row.sessionId] != nil else { continue }
            
            let mark: IdentificationSessionFieldMark
            if let existing = existingById[row.id] {
                updateIdentificationSessionMark(existing, from: row, sessionById: sessionById)
                mark = existing
            } else {
                mark = createIdentificationSessionMark(from: row, sessionById: sessionById)
                context.insert(mark)
            }
            mark.syncStatus = .synced
            mark.lastSyncedAt = Date()
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
            watchlist_id: row.watchlist_id,
            user_id: row.user_id,
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
        watchlist.user_id = row.user_id
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
        watchlist.created_at = row.created_at
        watchlist.updated_at = row.updated_at
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
        rule.created_at = row.created_at
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

    private nonisolated func createIdentificationSession(from row: IdentificationSessionRow, shapeById: [String: BirdShape]) -> IdentificationSession {
        let obsDate: Date
        if let obsDateStr = row.metadata?["observationDate"],
           let parsedDate = ISO8601DateFormatter().date(from: obsDateStr) {
            obsDate = parsedDate
        } else {
            obsDate = row.created_at
        }
        
        let session = IdentificationSession(
            identification_session_id: row.id,
            user_id: row.userId,
            observationDate: obsDate,
            createdAt: row.created_at,
            status: SessionStatus(rawValue: row.status) ?? .completed
        )
        updateIdentificationSession(session, from: row, shapeById: shapeById)
        return session
    }

    private nonisolated func updateIdentificationSession(_ session: IdentificationSession, from row: IdentificationSessionRow, shapeById: [String: BirdShape]) {
        session.user_id = row.userId
        session.status = SessionStatus(rawValue: row.status) ?? .completed
        session.locationLat = row.locationLat
        session.locationLong = row.locationLong
        session.deviceInfo = row.deviceInfo
        session.notes = row.notes
        session.isPublic = row.isPublic ?? false
        session.weatherConditions = row.weatherConditions
        session.metadata = row.metadata
        
        if let shapeId = row.metadata?["shapeId"] {
            session.shape = shapeById[shapeId]
        }
        session.locationDisplayName = row.metadata?["locationDisplayName"]
        if let sizeStr = row.metadata?["sizeCategory"], let size = Int(sizeStr) {
            session.sizeCategory = size
        }
        if let filterStr = row.metadata?["filterCategories"] {
            session.selectedFilterCategories = filterStr.components(separatedBy: ",")
        }
        if let obsDateStr = row.metadata?["observationDate"],
           let parsedDate = ISO8601DateFormatter().date(from: obsDateStr) {
            session.observationDate = parsedDate
        } else {
            session.observationDate = row.created_at
        }

        session.created_at = row.created_at
        session.updated_at = row.updated_at
    }
private nonisolated func createIdentificationResult(from row: IdentificationResultRow, sessionById: [UUID: IdentificationSession], birdById: [UUID: Bird]) -> IdentificationResult {
    let result = IdentificationResult(
        identification_result_id: row.id,
        session: sessionById[row.sessionId],
        user_id: row.ownerId,
        createdAt: row.created_at
    )
        updateIdentificationResult(result, from: row, sessionById: sessionById, birdById: birdById)
        return result
    }

    private nonisolated func updateIdentificationResult(_ result: IdentificationResult, from row: IdentificationResultRow, sessionById: [UUID: IdentificationSession], birdById: [UUID: Bird]) {
        if let session = sessionById[row.sessionId] {
            result.session = session
        }
        if let birdId = row.birdId {
            result.bird = birdById[birdId]
        }
        result.user_id = row.ownerId
        result.serverRowVersion = Int64(row.rowVersion)
        result.deletedAt = row.deletedAt
        result.created_at = row.created_at
        result.created_at = row.created_at
        result.updated_at = row.updated_at
    }

    private nonisolated func createIdentificationCandidate(from row: IdentificationCandidateRow, resultById: [UUID: IdentificationResult], birdById: [UUID: Bird]) -> IdentificationCandidate {
        let candidate = IdentificationCandidate(
            identification_candidate_id: row.id,
            result: resultById[row.resultId],
            bird: birdById[row.birdId],
            confidence: row.confidence
        )
        updateIdentificationCandidate(candidate, from: row, resultById: resultById, birdById: birdById)
        return candidate
    }

    private nonisolated func updateIdentificationCandidate(_ candidate: IdentificationCandidate, from row: IdentificationCandidateRow, resultById: [UUID: IdentificationResult], birdById: [UUID: Bird]) {
        if let result = resultById[row.resultId] {
            candidate.result = result
        }
        if let bird = birdById[row.birdId] {
            candidate.bird = bird
        }
        candidate.confidence = row.confidence
        candidate.rank = row.rank
        candidate.serverRowVersion = Int64(row.rowVersion)
        candidate.deletedAt = row.deletedAt
        candidate.created_at = row.created_at
        candidate.updated_at = row.updated_at
    }

    private nonisolated func createIdentificationSessionMark(from row: IdentificationSessionFieldMarkRow, sessionById: [UUID: IdentificationSession]) -> IdentificationSessionFieldMark {
        let mark = IdentificationSessionFieldMark(
            identification_session_mark_id: row.id,
            identification_session_id: row.sessionId,
            field_mark_id: row.fieldMarkId,
            variant_id: row.variantId,
            area: row.area
        )
        updateIdentificationSessionMark(mark, from: row, sessionById: sessionById)
        return mark
    }

    private nonisolated func updateIdentificationSessionMark(_ mark: IdentificationSessionFieldMark, from row: IdentificationSessionFieldMarkRow, sessionById: [UUID: IdentificationSession]) {
        mark.identification_session_id = row.sessionId
        if let session = sessionById[row.sessionId] {
            mark.session = session
        }
        mark.field_mark_id = row.fieldMarkId
        mark.variant_id = row.variantId
        mark.area = row.area
        mark.serverRowVersion = Int64(row.rowVersion)
        mark.deletedAt = row.deletedAt
        mark.created_at = row.created_at
        mark.updated_at = row.updated_at
    }
}
