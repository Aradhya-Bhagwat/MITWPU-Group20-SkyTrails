
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
    
    private let tables: [String] = ["watchlists", "watchlist_entries", "watchlist_rules", "watchlist_shares", "observed_bird_photos"]
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
            if let error {
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
                    
                case .failure(let error):
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
            if let event = json["event"] as? String {
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
            if let error {
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
