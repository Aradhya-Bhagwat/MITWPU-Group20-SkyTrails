
import Foundation
import SwiftData

enum RealtimeSyncError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case subscriptionFailed(String)
    case invalidPayload
    case authRequired
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Realtime connection not established"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .subscriptionFailed(let message):
            return "Subscription failed: \(message)"
        case .invalidPayload:
            return "Invalid realtime payload received"
        case .authRequired:
            return "Authentication required for realtime sync"
        }
    }
}

enum RealtimeConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

@MainActor
final class RealtimeSyncService: NSObject {
    
    static let shared = RealtimeSyncService()
    
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var config: SupabaseConfig?
    
    private(set) var connectionState: RealtimeConnectionState = .disconnected
    private var isConnected: Bool { connectionState == .connected }
    
    private var heartbeatTimer: Timer?
    private var reconnectAttempts: Int = 0
    private var maxReconnectAttempts: Int = 5
    private var reconnectDelay: TimeInterval = 1.0
    
    private let tables: [String] = [
        "watchlists", "watchlist_entries", "watchlist_rules", "watchlist_shares", "observed_bird_photos", "users",
        "bird_shapes", "birds", "bird_field_marks", "field_mark_variants", "bird_field_mark_variant_links",
        "identification_sessions", "identification_results", "identification_candidates", "identification_session_marks"
    ]
    private var subscribedTables: Set<String> = []
    var onConnectionStateChanged: ((RealtimeConnectionState) -> Void)?
    var onSyncEvent: ((RealtimePayload) -> Void)?
    
    private override init() {
        super.init()
    }
    func connect() async throws {
        guard UserSession.shared.isAuthenticatedWithSupabase() else {
            throw RealtimeSyncError.authRequired
        }
        
        guard let config = try? SupabaseConfig.load() else {
            throw RealtimeSyncError.connectionFailed("Supabase config not available")
        }
        
        self.config = config
        
        try await establishConnection()
    }
    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        
        session?.invalidateAndCancel()
        session = nil
        
        subscribedTables.removeAll()
        updateConnectionState(.disconnected)
    }
    func subscribeAll() async throws {
        guard isConnected else {
            throw RealtimeSyncError.notConnected
        }
        
        for table in tables {
            try await subscribe(to: table)
        }
    }
    
    private func establishConnection() async throws {
        webSocket?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        
        guard let config = config else {
            throw RealtimeSyncError.connectionFailed("Config not set")
        }
        
        updateConnectionState(.connecting)
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw RealtimeSyncError.connectionFailed("Invalid URL")
        }
        
        components.scheme = "wss"
        components.path = "/realtime/v1/websocket"
        components.queryItems = [
            URLQueryItem(name: "apikey", value: config.anonKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]
        
        guard let wsURL = components.url else {
            throw RealtimeSyncError.connectionFailed("Invalid WebSocket URL")
        }
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        var request = URLRequest(url: wsURL)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token = UserSession.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        webSocket = session?.webSocketTask(with: request)
        webSocket?.resume()
        receiveMessage()
        startHeartbeat()
        reconnectAttempts = 0
        reconnectDelay = 1.0
        
        updateConnectionState(.connected)
    }
    
    private func reconnect() async {
        guard reconnectAttempts < maxReconnectAttempts else {
            return
        }
        
        updateConnectionState(.reconnecting)
        reconnectAttempts += 1
        let delay = reconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        let jitter = Double.random(in: 0...0.5)
        let totalDelay = delay + jitter
        try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
        
        do {
            try await connect()
            try await subscribeAll()
        } catch {
        }
    }
    
    private func subscribe(to table: String) async throws {
        guard isConnected, let webSocket else {
            throw RealtimeSyncError.notConnected
        }
        
        guard !subscribedTables.contains(table) else {
            return
        }
        
        let channelConfig = RealtimeChannelPayloadConfig(
            postgresChanges: [RealtimePostgresChange(table: table)]
        )
        let channelPayload = RealtimeChannelPayload(config: channelConfig)
        
        let channel = RealtimeChannel(
            topic: "realtime:public:\(table)",
            payload: channelPayload
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(channel)
        
        webSocket.send(.data(data)) { error in
            if error != nil {
            } else {
            }
        }
        
        subscribedTables.insert(table)
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveMessage()
                    
                case .failure(_):
                    if self.connectionState == .connected {
                        await self.reconnect()
                    }
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            parseMessage(data)
        case .string(let string):
            guard let data = string.data(using: .utf8) else { return }
            parseMessage(data)
        @unknown default:
            break
        }
    }
    
    private func parseMessage(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        guard let _ = json["type"] as? String,
              let payload = json["payload"] as? [String: Any] else {
            if json["event"] is String {
            }
            return
        }
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let realtimePayload = try? JSONDecoder().decode(RealtimePayload.self, from: payloadData) else {
            return
        }
        handleRealtimeEvent(realtimePayload)
    }
    
    private func handleRealtimeEvent(_ payload: RealtimePayload) {
        onSyncEvent?(payload)
        Task { @MainActor in
            do {
                switch payload.table {
                case "watchlists":
                    try await handleWatchlistEvent(payload)
                case "watchlist_entries":
                    try await handleEntryEvent(payload)
                case "watchlist_rules":
                    try await handleRuleEvent(payload)
                case "watchlist_shares":
                    try await handleShareEvent(payload)
                case "observed_bird_photos":
                    try await handlePhotoEvent(payload)
                case "users":
                    try await handleUserEvent(payload)
                case "bird_shapes":
                    try await handleBirdShapeEvent(payload)
                case "birds":
                    try await handleBirdEvent(payload)
                case "bird_field_marks":
                    try await handleBirdFieldMarkEvent(payload)
                case "field_mark_variants":
                    try await handleFieldMarkVariantEvent(payload)
                case "bird_field_mark_variant_links":
                    try await handleBirdFieldMarkVariantLinkEvent(payload)
                case "identification_sessions":
                    try await handleIdentificationSessionEvent(payload)
                case "identification_results":
                    try await handleIdentificationResultEvent(payload)
                case "identification_candidates":
                    try await handleIdentificationCandidateEvent(payload)
                case "identification_session_marks":
                    try await handleIdentificationSessionMarkEvent(payload)
                default:
                    break
                }
            } catch {
            }
        }
    }
    
    private func handleWatchlistEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "watchlist_id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertWatchlist(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "watchlist_id") else { return }
            try await deleteWatchlist(id: deleteId)
        }
    }
    
    private func handleEntryEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "watchlist_entry_id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertEntry(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "watchlist_entry_id") else { return }
            try await deleteEntry(id: deleteId)
        }
    }
    
    private func handleRuleEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "watchlist_rule_id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertRule(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "watchlist_rule_id") else { return }
            try await deleteRule(id: deleteId)
        }
    }
    
    private func handlePhotoEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "observed_bird_photo_id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertPhoto(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "observed_bird_photo_id") else { return }
            try await deletePhoto(id: deleteId)
        }
    }

    private func handleIdentificationSessionEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "identification_session_id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertIdentificationSession(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "identification_session_id") else { return }
            try await deleteIdentificationSession(id: deleteId)
        }
    }

    private func handleBirdShapeEvent(_ payload: RealtimePayload) async throws {
        let shapeId = payload.record?.string(for: "bird_shape_id")
            ?? payload.record?.string(for: "id")
            ?? payload.oldRecord?.string(for: "bird_shape_id")
            ?? payload.oldRecord?.string(for: "id")
        guard let shapeId else { return }

        switch payload.type {
        case .insert, .update:
            guard let record = payload.record else { return }
            try await upsertBirdShape(from: record, shapeId: shapeId)
        case .delete:
            try await deleteBirdShape(shapeId: shapeId)
        }
    }

    private func handleBirdFieldMarkEvent(_ payload: RealtimePayload) async throws {
        let id = payload.record?.uuid(for: "bird_field_mark_id") ?? payload.oldRecord?.uuid(for: "bird_field_mark_id")
        guard let id else { return }

        switch payload.type {
        case .insert, .update:
            guard let record = payload.record else { return }
            try await upsertBirdFieldMark(from: record, id: id)
        case .delete:
            try await deleteBirdFieldMark(id: id)
        }
    }

    private func handleBirdEvent(_ payload: RealtimePayload) async throws {
        let id = payload.record?.uuid(for: "bird_id")
            ?? payload.record?.uuid(for: "id")
            ?? payload.oldRecord?.uuid(for: "bird_id")
            ?? payload.oldRecord?.uuid(for: "id")
        guard let id else { return }

        switch payload.type {
        case .insert, .update:
            guard let record = payload.record else { return }
            try await upsertBird(from: record, id: id)
        case .delete:
            try await deleteBird(id: id)
        }
    }

    private func handleFieldMarkVariantEvent(_ payload: RealtimePayload) async throws {
        let id = payload.record?.uuid(for: "field_mark_variant_id") ?? payload.oldRecord?.uuid(for: "field_mark_variant_id")
        guard let id else { return }

        switch payload.type {
        case .insert, .update:
            guard let record = payload.record else { return }
            try await upsertFieldMarkVariant(from: record, id: id)
        case .delete:
            try await deleteFieldMarkVariant(id: id)
        }
    }

    private func handleBirdFieldMarkVariantLinkEvent(_ payload: RealtimePayload) async throws {
        let id = payload.record?.uuid(for: "bird_field_mark_variant_link_id") ?? payload.oldRecord?.uuid(for: "bird_field_mark_variant_link_id")
        guard let id else { return }

        switch payload.type {
        case .insert, .update:
            guard let record = payload.record else { return }
            try await upsertBirdFieldMarkVariantLink(from: record, id: id)
        case .delete:
            try await deleteBirdFieldMarkVariantLink(id: id)
        }
    }

    private func handleIdentificationResultEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "identification_result_id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertIdentificationResult(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "identification_result_id") else { return }
            try await deleteIdentificationResult(id: deleteId)
        }
    }

    private func handleIdentificationCandidateEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "identification_candidate_id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertIdentificationCandidate(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "identification_candidate_id") else { return }
            try await deleteIdentificationCandidate(id: deleteId)
        }
    }

    private func handleIdentificationSessionMarkEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "identification_session_mark_id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertIdentificationSessionMark(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "identification_session_mark_id") else { return }
            try await deleteIdentificationSessionMark(id: deleteId)
        }
    }
    
    private func handleUserEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "user_id") else { return }
        
        // Only care about updates to the current user
        guard let currentUser = UserSession.shared.getUser(), currentUser.user_id == id else {
            return
        }
        
        switch payload.type {
        case .insert, .update:
            let name = record.string(for: "name") ?? currentUser.name
            let gender = record.string(for: "gender") ?? currentUser.gender
            let email = record.string(for: "email") ?? currentUser.email
            let photo = record.string(for: "profile_photo") ?? currentUser.profilePhoto
            
            let updatedUser = User(
                user_id: id,
                name: name,
                gender: gender,
                email: email,
                profilePhoto: photo
            )
            
            UserSession.shared.saveUser(updatedUser)
        case .delete:
            // User deleted from another device? Logout.
            UserSession.shared.logout()
        }
    }
    
    private func handleShareEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "watchlist_share_id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertShare(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "watchlist_share_id") else { return }
            try await deleteShare(id: deleteId)
        }
    }
    
    private func upsertWatchlist(from record: [String: JSONValue], id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let existing = try WatchlistManager.shared.getWatchlist(by: id)
        
        if let watchlist = existing {
            watchlist.user_id = record.uuid(for: "user_id")
            watchlist.type = record.string(for: "type").flatMap { WatchlistType(rawValue: $0) } ?? .custom
            watchlist.title = record.string(for: "title")
            watchlist.location = record.string(for: "location")
            watchlist.locationDisplayName = record.string(for: "location_display_name")
            watchlist.observedCount = record.int(for: "observed_count") ?? 0
            watchlist.speciesCount = record.int(for: "species_count") ?? 0
            watchlist.coverImagePath = record.string(for: "cover_image_path")
            watchlist.startDate = record.date(for: "start_date")
            watchlist.endDate = record.date(for: "end_date")
            watchlist.deleted_at = record.date(for: "deleted_at")
            watchlist.syncStatus = .synced
            watchlist.lastSyncedAt = Date()
            watchlist.serverRowVersion = record.int(for: "row_version") ?? watchlist.serverRowVersion
            watchlist.updated_at = record.date(for: "updated_at")
            
            try? context.save()
        } else {
            let watchlist = Watchlist(
                watchlist_id: id,
                user_id: record.uuid(for: "user_id"),
                type: record.string(for: "type").flatMap { WatchlistType(rawValue: $0) } ?? .custom,
                title: record.string(for: "title"),
                location: record.string(for: "location"),
                locationDisplayName: record.string(for: "location_display_name"),
                startDate: record.date(for: "start_date"),
                endDate: record.date(for: "end_date")
            )
            watchlist.observedCount = record.int(for: "observed_count") ?? 0
            watchlist.speciesCount = record.int(for: "species_count") ?? 0
            watchlist.coverImagePath = record.string(for: "cover_image_path")
            watchlist.serverRowVersion = record.int(for: "row_version") ?? 0
            watchlist.deleted_at = record.date(for: "deleted_at")
            watchlist.syncStatus = .synced
            watchlist.lastSyncedAt = Date()
            watchlist.updated_at = record.date(for: "updated_at")
            
            context.insert(watchlist)
            try? context.save()
        }
    }
    
    private func deleteWatchlist(id: UUID) async throws {
        guard let watchlist = try WatchlistManager.shared.getWatchlist(by: id) else { return }
        watchlist.syncStatus = .synced
        watchlist.deleted_at = Date()
        try? WatchlistManager.shared.context.save()
    }
    
    private func upsertEntry(from record: [String: JSONValue], id: UUID) async throws {
        guard let watchlistId = record.uuid(for: "watchlist_id"),
              let watchlist = try WatchlistManager.shared.getWatchlist(by: watchlistId) else { return }
        var existingEntry: WatchlistEntry?
        if let entries = watchlist.entries {
            existingEntry = entries.first { $0.id == id }
        }
        
        if let entry = existingEntry {
            if let birdId = record.uuid(for: "bird_id") {
                entry.bird = try? WatchlistManager.shared.fetchBird(bird_id: birdId)
            }
            entry.status = record.string(for: "status") == "observed" ? .observed : .to_observe
            entry.nickname = record.string(for: "nickname")
            entry.notes = record.string(for: "notes")
            entry.addedDate = record.date(for: "added_date") ?? entry.addedDate
            entry.observationDate = record.date(for: "observation_date")
            entry.toObserveStartDate = record.date(for: "to_observe_start_date")
            entry.toObserveEndDate = record.date(for: "to_observe_end_date")
            entry.observedBy = record.string(for: "observed_by")
            entry.observedByUserId = record.uuid(for: "observed_by_user_id")
            entry.lat = record.double(for: "lat")
            entry.lon = record.double(for: "lon")
            entry.locationDisplayName = record.string(for: "location_display_name")
            entry.priority = record.int(for: "priority") ?? 0
            entry.notify_upcoming = record.bool(for: "notify_upcoming") ?? false
            entry.serverRowVersion = record.int(for: "row_version") ?? entry.serverRowVersion
            entry.syncStatus = .synced
            entry.lastSyncedAt = Date()
            
            try? WatchlistManager.shared.context.save()
        } else {
            let bird = record.uuid(for: "bird_id").flatMap { try? WatchlistManager.shared.fetchBird(bird_id: $0) }
            let entry = WatchlistEntry(
                id: id,
                watchlist: watchlist,
                bird: bird,
                status: record.string(for: "status") == "observed" ? .observed : .to_observe,
                notes: record.string(for: "notes"),
                observationDate: record.date(for: "observation_date"),
                observedBy: record.string(for: "observed_by"),
                observedByUserId: record.uuid(for: "observed_by_user_id")
            )
            entry.nickname = record.string(for: "nickname")
            entry.addedDate = record.date(for: "added_date") ?? entry.addedDate
            entry.toObserveStartDate = record.date(for: "to_observe_start_date")
            entry.toObserveEndDate = record.date(for: "to_observe_end_date")
            entry.lat = record.double(for: "lat")
            entry.lon = record.double(for: "lon")
            entry.locationDisplayName = record.string(for: "location_display_name")
            entry.priority = record.int(for: "priority") ?? 0
            entry.notify_upcoming = record.bool(for: "notify_upcoming") ?? false
            entry.serverRowVersion = record.int(for: "row_version") ?? 0
            entry.syncStatus = .synced
            entry.lastSyncedAt = Date()
            
            WatchlistManager.shared.context.insert(entry)
            try? WatchlistManager.shared.context.save()
        }
    }
    
    private func deleteEntry(id: UUID) async throws {
        let watchlists = try WatchlistManager.shared.fetchWatchlists()
        for watchlist in watchlists {
            if let entries = watchlist.entries {
                for entry in entries where entry.id == id {
                    WatchlistManager.shared.context.delete(entry)
                    try? WatchlistManager.shared.context.save()
                    return
                }
            }
        }
    }
    
    private func upsertRule(from record: [String: JSONValue], id: UUID) async throws {
        guard let watchlistId = record.uuid(for: "watchlist_id"),
              let watchlist = try WatchlistManager.shared.getWatchlist(by: watchlistId) else { return }
        var existingRule: WatchlistRule?
        if let rules = watchlist.rules {
            existingRule = rules.first { $0.id == id }
        }
        
        if let rule = existingRule {
            rule.lat = record.double(for: "lat")
            rule.lon = record.double(for: "lon")
            rule.radius_km = record.double(for: "radius_km")
            rule.start_date = record.date(for: "start_date")
            rule.end_date = record.date(for: "end_date")
            rule.shape_id = record.string(for: "shape_id")
            rule.pattern_key = record.string(for: "pattern_key")
            rule.is_active = record.bool(for: "is_active") ?? true
            rule.priority = record.int(for: "priority") ?? 0
            rule.deleted_at = record.date(for: "deleted_at")
            rule.serverRowVersion = record.int(for: "row_version") ?? rule.serverRowVersion
            rule.syncStatus = .synced
            rule.lastSyncedAt = Date()
            
            try? WatchlistManager.shared.context.save()
        } else {
            let ruleTypeString = record.string(for: "rule_type") ?? "location"
            let ruleType = WatchlistRuleType(rawValue: ruleTypeString) ?? .location
            
            let rule = WatchlistRule(
                id: id,
                watchlist: watchlist,
                rule_type: ruleType
            )
            rule.lat = record.double(for: "lat")
            rule.lon = record.double(for: "lon")
            rule.radius_km = record.double(for: "radius_km")
            rule.start_date = record.date(for: "start_date")
            rule.end_date = record.date(for: "end_date")
            rule.shape_id = record.string(for: "shape_id")
            rule.pattern_key = record.string(for: "pattern_key")
            rule.is_active = record.bool(for: "is_active") ?? true
            rule.priority = record.int(for: "priority") ?? 0
            rule.serverRowVersion = record.int(for: "row_version") ?? 0
            rule.deleted_at = record.date(for: "deleted_at")
            rule.syncStatus = .synced
            rule.lastSyncedAt = Date()
            
            WatchlistManager.shared.context.insert(rule)
            try? WatchlistManager.shared.context.save()
        }
    }
    
    private func deleteRule(id: UUID) async throws {
        let watchlists = try WatchlistManager.shared.fetchWatchlists()
        for watchlist in watchlists {
            if let rules = watchlist.rules {
                for rule in rules where rule.id == id {
                    WatchlistManager.shared.context.delete(rule)
                    try? WatchlistManager.shared.context.save()
                    return
                }
            }
        }
    }
    
    private func upsertShare(from record: [String: JSONValue], id: UUID) async throws {
        guard let watchlistId = record.uuid(for: "watchlist_id"),
              let watchlist = try WatchlistManager.shared.getWatchlist(by: watchlistId),
              let userId = record.uuid(for: "user_id")
        else { return }
        
        let existingShare = watchlist.shares?.first(where: { $0.id == id })
        if let share = existingShare {
            share.user_id = userId
            share.permission = record.string(for: "permission").flatMap { WatchlistSharePermission(rawValue: $0) } ?? .view
            share.shared_at = record.date(for: "shared_at") ?? share.shared_at
            share.shared_by_user_id = record.uuid(for: "shared_by_user_id")
            share.serverRowVersion = record.int(for: "server_row_version") ?? share.serverRowVersion
            share.deleted_at = record.date(for: "deleted_at")
            share.syncStatus = .synced
            share.lastSyncedAt = Date()
            try? WatchlistManager.shared.context.save()
        } else {
            let share = WatchlistShare(
                id: id,
                watchlist: watchlist,
                user_id: userId,
                permission: record.string(for: "permission").flatMap { WatchlistSharePermission(rawValue: $0) } ?? .view
            )
            share.shared_at = record.date(for: "shared_at") ?? share.shared_at
            share.shared_by_user_id = record.uuid(for: "shared_by_user_id")
            share.serverRowVersion = record.int(for: "server_row_version") ?? 0
            share.deleted_at = record.date(for: "deleted_at")
            share.syncStatus = .synced
            share.lastSyncedAt = Date()
            WatchlistManager.shared.context.insert(share)
            try? WatchlistManager.shared.context.save()
        }
    }
    
    private func deleteShare(id: UUID) async throws {
        let watchlists = try WatchlistManager.shared.fetchWatchlists()
        for watchlist in watchlists {
            if let shares = watchlist.shares {
                for share in shares where share.id == id {
                    WatchlistManager.shared.context.delete(share)
                    try? WatchlistManager.shared.context.save()
                    return
                }
            }
        }
    }
    
    private func upsertPhoto(from record: [String: JSONValue], id: UUID) async throws {
        guard let entryId = record.uuid(for: "watchlist_entry_id") else { return }
        let watchlists = try WatchlistManager.shared.fetchWatchlists()
        for watchlist in watchlists {
            if let entries = watchlist.entries {
                for entry in entries where entry.id == entryId {
                    var existingPhoto: ObservedBirdPhoto?
                    if let photos = entry.photos {
                        existingPhoto = photos.first { $0.id == id }
                    }
                    
                    if let photo = existingPhoto {
                        photo.imagePath = record.string(for: "image_path") ?? ""
                        photo.storageUrl = record.string(for: "storage_url")
                        photo.captured_at = record.date(for: "captured_at")
                        photo.serverRowVersion = record.int(for: "row_version") ?? photo.serverRowVersion
                        photo.syncStatus = .synced
                        photo.lastSyncedAt = Date()
                        
                        try? WatchlistManager.shared.context.save()
                    } else {
                        let photo = ObservedBirdPhoto(
                            id: id,
                            watchlistEntry: entry,
                            imagePath: record.string(for: "image_path") ?? ""
                        )
                        photo.storageUrl = record.string(for: "storage_url")
                        photo.captured_at = record.date(for: "captured_at")
                        photo.serverRowVersion = record.int(for: "row_version") ?? 0
                        photo.syncStatus = .synced
                        photo.lastSyncedAt = Date()
                        
                        WatchlistManager.shared.context.insert(photo)
                        try? WatchlistManager.shared.context.save()
                    }
                    return
                }
            }
        }
    }
    
    private func deletePhoto(id: UUID) async throws {
        let watchlists = try WatchlistManager.shared.fetchWatchlists()
        for watchlist in watchlists {
            if let entries = watchlist.entries {
                for entry in entries {
                    if let photos = entry.photos {
                        for photo in photos where photo.id == id {
                            WatchlistManager.shared.context.delete(photo)
                            try? WatchlistManager.shared.context.save()
                            return
                        }
                    }
                }
            }
        }
    }

    private func upsertIdentificationSession(from record: [String: JSONValue], id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<IdentificationSession>(predicate: #Predicate { $0.identification_session_id == id })
        let existing = try? context.fetch(descriptor).first

        if let session = existing {
            updateSessionFromRecord(session, record: record)
            try? context.save()
        } else {
            let session = IdentificationSession(
                identification_session_id: id,
                user_id: record.uuid(for: "user_id"),
                observationDate: record.date(for: "observation_date") ?? record.date(for: "created_at") ?? Date(),
                createdAt: record.date(for: "created_at") ?? Date(),
                status: record.string(for: "status").flatMap { SessionStatus(rawValue: $0) } ?? .completed
            )
            updateSessionFromRecord(session, record: record)
            context.insert(session)
            try? context.save()
        }
    }

    private func updateSessionFromRecord(_ session: IdentificationSession, record: [String: JSONValue]) {
        session.status = record.string(for: "status").flatMap { SessionStatus(rawValue: $0) } ?? .completed
        session.locationLat = record.double(for: "location_lat")
        session.locationLong = record.double(for: "location_long")
        session.deviceInfo = record.string(for: "device_info")
        session.notes = record.string(for: "notes")
        session.isPublic = record.bool(for: "is_public") ?? false
        session.weatherConditions = record.string(for: "weather_conditions")
        session.created_at = record.date(for: "created_at") ?? session.created_at
        session.updated_at = record.date(for: "updated_at")
        session.serverRowVersion = Int64(record.int(for: "row_version") ?? 0)
        session.deletedAt = record.date(for: "deleted_at")
        session.syncStatus = .synced
        session.lastSyncedAt = Date()

        // Handle Metadata
        if let metadataObj = record["metadata"], case .object(let dict) = metadataObj {
            var stringDict: [String: String] = [:]
            for (k, v) in dict {
                if let s = v.stringValue { stringDict[k] = s }
            }
            session.metadata = stringDict
            
            if let shapeId = stringDict["shapeId"] {
                let shapeDescriptor = FetchDescriptor<BirdShape>(predicate: #Predicate { $0.bird_shape_id == shapeId })
                session.shape = try? WatchlistManager.shared.context.fetch(shapeDescriptor).first
            }
            session.locationDisplayName = stringDict["locationDisplayName"]
            if let sizeStr = stringDict["sizeCategory"], let size = Int(sizeStr) {
                session.sizeCategory = size
            }
            if let filterStr = stringDict["filterCategories"] {
                session.selectedFilterCategories = filterStr.components(separatedBy: ",")
            }
        }
    }

    private func deleteIdentificationSession(id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<IdentificationSession>(predicate: #Predicate { $0.identification_session_id == id })
        if let session = try? context.fetch(descriptor).first {
            session.deletedAt = Date()
            session.syncStatus = .synced
            try? context.save()
        }
    }

    private func upsertIdentificationResult(from record: [String: JSONValue], id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<IdentificationResult>(predicate: #Predicate { $0.identification_result_id == id })
        let existing = try? context.fetch(descriptor).first

        guard let sessionId = record.uuid(for: "identification_session_id") else { return }
        let sessionDescriptor = FetchDescriptor<IdentificationSession>(predicate: #Predicate { $0.identification_session_id == sessionId })
        let session = try? context.fetch(sessionDescriptor).first

        if let result = existing {
            result.session = session
            result.user_id = record.uuid(for: "owner_id")
            if let birdId = record.uuid(for: "bird_id") {
                result.bird = try? WatchlistManager.shared.fetchBird(bird_id: birdId)
            } else {
                result.bird = nil
            }
            result.serverRowVersion = Int64(record.int(for: "row_version") ?? 0)
            result.updated_at = record.date(for: "updated_at")
            result.deletedAt = record.date(for: "deleted_at")
            result.syncStatus = .synced
            result.lastSyncedAt = Date()
            try? context.save()
        } else {
            let result = IdentificationResult(
                identification_result_id: id,
                session: session,
                user_id: record.uuid(for: "owner_id"),
                createdAt: record.date(for: "created_at") ?? Date()
            )
            if let birdId = record.uuid(for: "bird_id") {
                result.bird = try? WatchlistManager.shared.fetchBird(bird_id: birdId)
            } else {
                result.bird = nil
            }
            result.serverRowVersion = Int64(record.int(for: "row_version") ?? 0)
            result.updated_at = record.date(for: "updated_at")
            result.deletedAt = record.date(for: "deleted_at")
            result.syncStatus = .synced
            result.lastSyncedAt = Date()
            context.insert(result)
            try? context.save()
        }
    }

    private func deleteIdentificationResult(id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<IdentificationResult>(predicate: #Predicate { $0.identification_result_id == id })
        if let result = try? context.fetch(descriptor).first {
            result.deletedAt = Date()
            result.syncStatus = .synced
            try? context.save()
        }
    }

    private func upsertIdentificationCandidate(from record: [String: JSONValue], id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<IdentificationCandidate>(predicate: #Predicate { $0.identification_candidate_id == id })
        let existing = try? context.fetch(descriptor).first

        guard let resultId = record.uuid(for: "identification_result_id") else { return }
        let resultDescriptor = FetchDescriptor<IdentificationResult>(predicate: #Predicate { $0.identification_result_id == resultId })
        let result = try? context.fetch(resultDescriptor).first

        let birdId = record.uuid(for: "bird_id")
        let bird = birdId.flatMap { try? WatchlistManager.shared.fetchBird(bird_id: $0) }

        if let candidate = existing {
            candidate.result = result
            candidate.bird = bird
            candidate.confidence = record.double(for: "confidence") ?? 0.0
            candidate.rank = record.int(for: "confidence_rank")
            candidate.serverRowVersion = Int64(record.int(for: "row_version") ?? 0)
            candidate.updated_at = record.date(for: "updated_at")
            candidate.deletedAt = record.date(for: "deleted_at")
            candidate.syncStatus = .synced
            candidate.lastSyncedAt = Date()
            try? context.save()
        } else {
            let candidate = IdentificationCandidate(
                identification_candidate_id: id,
                result: result,
                bird: bird,
                confidence: record.double(for: "confidence") ?? 0.0,
                rank: record.int(for: "confidence_rank")
            )
            candidate.serverRowVersion = Int64(record.int(for: "row_version") ?? 0)
            candidate.updated_at = record.date(for: "updated_at")
            candidate.deletedAt = record.date(for: "deleted_at")
            candidate.syncStatus = .synced
            candidate.lastSyncedAt = Date()
            context.insert(candidate)
            try? context.save()
        }
    }

    private func deleteIdentificationCandidate(id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<IdentificationCandidate>(predicate: #Predicate { $0.identification_candidate_id == id })
        if let candidate = try? context.fetch(descriptor).first {
            candidate.deletedAt = Date()
            candidate.syncStatus = .synced
            try? context.save()
        }
    }

    private func upsertIdentificationSessionMark(from record: [String: JSONValue], id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<IdentificationSessionFieldMark>(predicate: #Predicate { $0.identification_session_mark_id == id })
        let existing = try? context.fetch(descriptor).first

        guard let sessionId = record.uuid(for: "identification_session_id") else { return }
        let sessionDescriptor = FetchDescriptor<IdentificationSession>(predicate: #Predicate { $0.identification_session_id == sessionId })
        let session = try? context.fetch(sessionDescriptor).first

        if let mark = existing {
            mark.session = session
            mark.area = record.string(for: "area") ?? ""
            if let markId = record.uuid(for: "field_mark_id") {
                mark.field_mark_id = markId
                let fieldMarkDescriptor = FetchDescriptor<BirdFieldMark>(predicate: #Predicate { $0.bird_field_mark_id == markId })
                mark.fieldMark = try? context.fetch(fieldMarkDescriptor).first
            } else {
                mark.fieldMark = nil
            }
            if let varId = record.uuid(for: "variant_id") {
                mark.variant_id = varId
                let variantDescriptor = FetchDescriptor<FieldMarkVariant>(predicate: #Predicate { $0.field_mark_variant_id == varId })
                mark.variant = try? context.fetch(variantDescriptor).first
            } else {
                mark.variant = nil
            }
            mark.serverRowVersion = Int64(record.int(for: "row_version") ?? 0)
            mark.updated_at = record.date(for: "updated_at")
            mark.deletedAt = record.date(for: "deleted_at")
            mark.syncStatus = .synced
            mark.lastSyncedAt = Date()
            try? context.save()
        } else {
            let mark = IdentificationSessionFieldMark(
                identification_session_mark_id: id,
                identification_session_id: sessionId,
                session: session,
                area: record.string(for: "area") ?? ""
            )
            if let markId = record.uuid(for: "field_mark_id") {
                mark.field_mark_id = markId
                let fieldMarkDescriptor = FetchDescriptor<BirdFieldMark>(predicate: #Predicate { $0.bird_field_mark_id == markId })
                mark.fieldMark = try? context.fetch(fieldMarkDescriptor).first
            }
            if let varId = record.uuid(for: "variant_id") {
                mark.variant_id = varId
                let variantDescriptor = FetchDescriptor<FieldMarkVariant>(predicate: #Predicate { $0.field_mark_variant_id == varId })
                mark.variant = try? context.fetch(variantDescriptor).first
            }
            
            mark.serverRowVersion = Int64(record.int(for: "row_version") ?? 0)
            mark.updated_at = record.date(for: "updated_at")
            mark.deletedAt = record.date(for: "deleted_at")
            mark.syncStatus = .synced
            mark.lastSyncedAt = Date()
            context.insert(mark)
            try? context.save()
        }
    }

    private func deleteIdentificationSessionMark(id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<IdentificationSessionFieldMark>(predicate: #Predicate { $0.identification_session_mark_id == id })
        if let mark = try? context.fetch(descriptor).first {
            mark.deletedAt = Date()
            mark.syncStatus = .synced
            try? context.save()
        }
    }

    private func upsertBirdShape(from record: [String: JSONValue], shapeId: String) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<BirdShape>(predicate: #Predicate { $0.bird_shape_id == shapeId })
        let existing = try? context.fetch(descriptor).first

        let name = record.string(for: "name") ?? shapeId
        let icon = record.string(for: "icon") ?? record.string(for: "icon_url") ?? ""

        if let shape = existing {
            shape.name = name
            if !icon.isEmpty {
                shape.icon = icon
            }
        } else {
            let shape = BirdShape(bird_shape_id: shapeId, name: name, icon: icon)
            context.insert(shape)
        }

        let birds = try? context.fetch(FetchDescriptor<Bird>(predicate: #Predicate { $0.shape_id == shapeId }))
        if let targetShape = try? context.fetch(descriptor).first {
            birds?.forEach { $0.shape = targetShape }
        }
        try? context.save()
    }

    private func deleteBirdShape(shapeId: String) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<BirdShape>(predicate: #Predicate { $0.bird_shape_id == shapeId })
        if let shape = try? context.fetch(descriptor).first {
            context.delete(shape)
            try? context.save()
        }
    }

    private func upsertBird(from record: [String: JSONValue], id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<Bird>(predicate: #Predicate { $0.bird_id == id })
        let existing = try? context.fetch(descriptor).first

        let shapeCode: String?
        if let explicitShapeCode = record.string(for: "bird_shape_id") {
            shapeCode = explicitShapeCode
        } else if let shapeServerId = record.uuid(for: "shape_id") {
            shapeCode = nil
            let shapeRows = try? context.fetch(FetchDescriptor<BirdShape>())
            let _ = shapeRows // keep compile-friendly local scope for future server-id mapping
            _ = shapeServerId
        } else {
            shapeCode = record.string(for: "shape_id")
        }

        let resolvedShape: BirdShape?
        if let shapeCode {
            let shapeDescriptor = FetchDescriptor<BirdShape>(predicate: #Predicate { $0.bird_shape_id == shapeCode })
            resolvedShape = try? context.fetch(shapeDescriptor).first
        } else {
            resolvedShape = nil
        }

        let staticImageName = record.string(for: "image_url") ?? record.string(for: "common_name") ?? "bird"

        if let bird = existing {
            bird.commonName = record.string(for: "common_name") ?? bird.commonName
            bird.scientificName = record.string(for: "scientific_name") ?? bird.scientificName
            bird.staticImageName = staticImageName
            bird.family = record.string(for: "family")
            bird.order_name = record.string(for: "order_name")
            bird.descriptionText = record.string(for: "description")
            bird.conservation_status = record.string(for: "conservation_status")
            bird.migration_strategy = record.string(for: "migration_strategy")
            bird.shape_id = shapeCode
            bird.size_category = record.int(for: "size_category")
            bird.shape = resolvedShape
        } else {
            let bird = Bird(
                bird_id: id,
                commonName: record.string(for: "common_name") ?? "Unknown Bird",
                scientificName: record.string(for: "scientific_name") ?? "",
                staticImageName: staticImageName,
                family: record.string(for: "family"),
                order_name: record.string(for: "order_name"),
                descriptionText: record.string(for: "description"),
                conservation_status: record.string(for: "conservation_status"),
                migration_strategy: record.string(for: "migration_strategy"),
                validMonths: nil,
                likelySpot: nil,
                shape_id: shapeCode,
                size_category: record.int(for: "size_category"),
                shape: resolvedShape
            )
            context.insert(bird)
        }
        try? context.save()
    }

    private func deleteBird(id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<Bird>(predicate: #Predicate { $0.bird_id == id })
        if let bird = try? context.fetch(descriptor).first {
            context.delete(bird)
            try? context.save()
        }
    }

    private func upsertBirdFieldMark(from record: [String: JSONValue], id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<BirdFieldMark>(predicate: #Predicate { $0.bird_field_mark_id == id })
        let existing = try? context.fetch(descriptor).first

        let shapeId = record.string(for: "shape_id")
        let shape = shapeId.flatMap { value in
            let shapeDescriptor = FetchDescriptor<BirdShape>(predicate: #Predicate { $0.bird_shape_id == value })
            return try? context.fetch(shapeDescriptor).first
        }

        if let mark = existing {
            mark.area = record.string(for: "area") ?? mark.area
            mark.shape = shape
        } else {
            let mark = BirdFieldMark(area: record.string(for: "area") ?? "")
            mark.bird_field_mark_id = id
            mark.shape = shape
            context.insert(mark)
        }
        try? context.save()
    }

    private func deleteBirdFieldMark(id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<BirdFieldMark>(predicate: #Predicate { $0.bird_field_mark_id == id })
        if let mark = try? context.fetch(descriptor).first {
            context.delete(mark)
            try? context.save()
        }
    }

    private func upsertFieldMarkVariant(from record: [String: JSONValue], id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<FieldMarkVariant>(predicate: #Predicate { $0.field_mark_variant_id == id })
        let existing = try? context.fetch(descriptor).first

        let fieldMark = record.uuid(for: "field_mark_id").flatMap { fieldMarkId in
            try? context.fetch(FetchDescriptor<BirdFieldMark>(predicate: #Predicate { $0.bird_field_mark_id == fieldMarkId })).first
        }

        if let variant = existing {
            variant.name = record.string(for: "name") ?? variant.name
            variant.fieldMark = fieldMark
        } else {
            let variant = FieldMarkVariant(name: record.string(for: "name") ?? "")
            variant.field_mark_variant_id = id
            variant.fieldMark = fieldMark
            context.insert(variant)
        }
        try? context.save()
    }

    private func deleteFieldMarkVariant(id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<FieldMarkVariant>(predicate: #Predicate { $0.field_mark_variant_id == id })
        if let variant = try? context.fetch(descriptor).first {
            context.delete(variant)
            try? context.save()
        }
    }

    private func upsertBirdFieldMarkVariantLink(from record: [String: JSONValue], id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<BirdFieldMarkVariantLink>(predicate: #Predicate { $0.bird_field_mark_variant_link_id == id })
        let existing = try? context.fetch(descriptor).first

        guard let birdId = record.uuid(for: "bird_id"),
              let bird = try? WatchlistManager.shared.fetchBird(bird_id: birdId) else { return }

        let area = record.string(for: "area") ?? ""
        let variantId = record.uuid(for: "variant_id")
        let fieldMarkId = record.uuid(for: "field_mark_id")
        let fieldMark = fieldMarkId.flatMap { markId in
            try? context.fetch(FetchDescriptor<BirdFieldMark>(predicate: #Predicate { $0.bird_field_mark_id == markId })).first
        }
        let variant = variantId.flatMap { value in
            try? context.fetch(FetchDescriptor<FieldMarkVariant>(predicate: #Predicate { $0.field_mark_variant_id == value })).first
        }

        let logicalMatches = try? context.fetch(FetchDescriptor<BirdFieldMarkVariantLink>())
        let logicalExisting = logicalMatches?.first {
            $0.bird?.bird_id == birdId &&
            $0.area.caseInsensitiveCompare(area) == .orderedSame &&
            $0.variant?.field_mark_variant_id == variantId
        }

        if let link = existing ?? logicalExisting {
            link.bird_field_mark_variant_link_id = id
            link.bird = bird
            link.fieldMark = fieldMark
            link.variant = variant
            link.area = area
        } else {
            let link = BirdFieldMarkVariantLink(
                bird_field_mark_variant_link_id: id,
                bird: bird,
                fieldMark: fieldMark,
                variant: variant,
                area: area
            )
            context.insert(link)
        }
        try? context.save()
    }

    private func deleteBirdFieldMarkVariantLink(id: UUID) async throws {
        let context = WatchlistManager.shared.context
        let descriptor = FetchDescriptor<BirdFieldMarkVariantLink>(predicate: #Predicate { $0.bird_field_mark_variant_link_id == id })
        if let link = try? context.fetch(descriptor).first {
            context.delete(link)
            try? context.save()
        }
    }
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendHeartbeat()
            }
        }
    }
    
    private func sendHeartbeat() {
        guard let webSocket else { return }
        
        let heartbeat = RealtimeHeartbeat()
        guard let data = try? JSONEncoder().encode(heartbeat) else { return }
        
        webSocket.send(.data(data)) { error in
            if error != nil {
            }
        }
    }
    
    private func updateConnectionState(_ state: RealtimeConnectionState) {
        connectionState = state
        onConnectionStateChanged?(state)
    }
}

extension RealtimeSyncService: URLSessionWebSocketDelegate {
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            updateConnectionState(.connected)
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor in
            if connectionState == .connected {
                Task {
                    await reconnect()
                }
            } else {
                updateConnectionState(.disconnected)
            }
        }
    }
}
