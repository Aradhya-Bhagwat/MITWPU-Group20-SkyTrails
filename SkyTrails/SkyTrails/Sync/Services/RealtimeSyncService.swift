//
//  RealtimeSyncService.swift
//  SkyTrails
//
//  WebSocket-based real-time sync with Supabase
//

import Foundation
import SwiftData

// MARK: - Realtime Sync Error

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

// MARK: - Connection State

enum RealtimeConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

// MARK: - Realtime Sync Service

@MainActor
final class RealtimeSyncService: NSObject {
    
    static let shared = RealtimeSyncService()
    
    // MARK: - Properties
    
    private var webSocket: URLSessionWebSocketTask?
    private var config: SupabaseConfig?
    
    private(set) var connectionState: RealtimeConnectionState = .disconnected
    private var isConnected: Bool { connectionState == .connected }
    
    private var heartbeatTimer: Timer?
    private var reconnectAttempts: Int = 0
    private var maxReconnectAttempts: Int = 5
    private var reconnectDelay: TimeInterval = 1.0
    
    private let tables: [String] = ["watchlists", "watchlist_entries", "watchlist_rules", "observed_bird_photos"]
    private var subscribedTables: Set<String> = []
    
    // Callbacks
    var onConnectionStateChanged: ((RealtimeConnectionState) -> Void)?
    var onSyncEvent: ((RealtimePayload) -> Void)?
    
    // MARK: - Init
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    /// Connect to Supabase Realtime with current user's token
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
    
    /// Disconnect from Realtime
    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        
        subscribedTables.removeAll()
        updateConnectionState(.disconnected)
        
        print("📡 [Realtime] Disconnected")
    }
    
    /// Subscribe to all watchlist-related tables
    func subscribeAll() async throws {
        guard isConnected else {
            throw RealtimeSyncError.notConnected
        }
        
        for table in tables {
            try await subscribe(to: table)
        }
        
        print("📡 [Realtime] Subscribed to all tables: \(tables.joined(separator: ", "))")
    }
    
    // MARK: - Connection Management
    
    private func establishConnection() async throws {
        guard let config = config else {
            throw RealtimeSyncError.connectionFailed("Config not set")
        }
        
        updateConnectionState(.connecting)
        
        // Build WebSocket URL
        // Supabase Realtime format: wss://<project-ref>.supabase.co/realtime/v1/websocket
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
        
        // Create WebSocket task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        var request = URLRequest(url: wsURL)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        // Add authorization if available
        if let token = UserSession.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()
        
        // Start listening
        receiveMessage()
        
        // Start heartbeat
        startHeartbeat()
        
        // Reset reconnect attempts on successful connection
        reconnectAttempts = 0
        reconnectDelay = 1.0
        
        updateConnectionState(.connected)
        print("📡 [Realtime] Connected to \(wsURL.host ?? "unknown")")
    }
    
    private func reconnect() async {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("📡 [Realtime] Max reconnect attempts reached")
            return
        }
        
        updateConnectionState(.reconnecting)
        reconnectAttempts += 1
        
        // Exponential backoff
        let delay = reconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        let jitter = Double.random(in: 0...0.5)
        let totalDelay = delay + jitter
        
        print("📡 [Realtime] Reconnecting in \(String(format: "%.1f", totalDelay))s (attempt \(reconnectAttempts))")
        
        try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
        
        do {
            try await connect()
            try await subscribeAll()
        } catch {
            print("📡 [Realtime] Reconnect failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Subscription
    
    private func subscribe(to table: String) async throws {
        guard isConnected, let webSocket else {
            throw RealtimeSyncError.notConnected
        }
        
        // Build the channel config
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
                print("📡 [Realtime] Subscribe error for \(table): \(error.localizedDescription)")
            } else {
                print("📡 [Realtime] Subscribed to: \(table)")
            }
        }
        
        subscribedTables.insert(table)
    }
    
    // MARK: - Message Handling
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveMessage() // Continue listening
                    
                case .failure(let error):
                    print("📡 [Realtime] Receive error: \(error.localizedDescription)")
                    
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
        // Try to decode as realtime message
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Check for event type (indicates a data message)
        guard let eventType = json["type"] as? String,
              let payload = json["payload"] as? [String: Any] else {
            // Could be a system message (phx_reply, etc.)
            if let event = json["event"] as? String {
                print("📡 [Realtime] System event: \(event)")
            }
            return
        }
        
        // Decode payload
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let realtimePayload = try? JSONDecoder().decode(RealtimePayload.self, from: payloadData) else {
            print("📡 [Realtime] Failed to decode payload")
            return
        }
        
        // Process the event
        handleRealtimeEvent(realtimePayload)
    }
    
    private func handleRealtimeEvent(_ payload: RealtimePayload) {
        print("📡 [Realtime] Event: \(payload.type.rawValue) on \(payload.table)")
        
        // Notify callback
        onSyncEvent?(payload)
        
        // Apply to local data - SERVER IS AUTHORITATIVE
        Task { @MainActor in
            do {
                switch payload.table {
                case "watchlists":
                    try await handleWatchlistEvent(payload)
                case "watchlist_entries":
                    try await handleEntryEvent(payload)
                case "watchlist_rules":
                    try await handleRuleEvent(payload)
                case "observed_bird_photos":
                    try await handlePhotoEvent(payload)
                default:
                    print("📡 [Realtime] Unknown table: \(payload.table)")
                }
            } catch {
                print("📡 [Realtime] Error handling event: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Event Handlers (Server is Authoritative)
    
    private func handleWatchlistEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertWatchlist(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "id") else { return }
            try await deleteWatchlist(id: deleteId)
        }
    }
    
    private func handleEntryEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertEntry(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "id") else { return }
            try await deleteEntry(id: deleteId)
        }
    }
    
    private func handleRuleEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertRule(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "id") else { return }
            try await deleteRule(id: deleteId)
        }
    }
    
    private func handlePhotoEvent(_ payload: RealtimePayload) async throws {
        guard let record = payload.record,
              let id = record.uuid(for: "id") else { return }
        
        switch payload.type {
        case .insert, .update:
            try await upsertPhoto(from: record, id: id)
        case .delete:
            guard let oldRecord = payload.oldRecord,
                  let deleteId = oldRecord.uuid(for: "id") else { return }
            try await deletePhoto(id: deleteId)
        }
    }
    
    // MARK: - Data Operations (Server Authoritative)
    
    private func upsertWatchlist(from record: [String: JSONValue], id: UUID) async throws {
        // Check if exists
        let existing = try WatchlistManager.shared.getWatchlist(by: id)
        
        if let watchlist = existing {
            // UPDATE - Server wins, overwrite all fields
            watchlist.owner_id = record.uuid(for: "owner_id")
            watchlist.title = record.string(for: "title")
            watchlist.location = record.string(for: "location")
            watchlist.locationDisplayName = record.string(for: "location_display_name")
            watchlist.observedCount = record.int(for: "observed_count") ?? 0
            watchlist.speciesCount = record.int(for: "species_count") ?? 0
            watchlist.coverImagePath = record.string(for: "cover_image_path")
            watchlist.speciesRuleEnabled = record.bool(for: "species_rule_enabled") ?? false
            watchlist.speciesRuleShapeId = record.string(for: "species_rule_shape_id")
            watchlist.locationRuleEnabled = record.bool(for: "location_rule_enabled") ?? false
            watchlist.locationRuleLat = record.double(for: "location_rule_lat")
            watchlist.locationRuleLon = record.double(for: "location_rule_lon")
            watchlist.locationRuleRadiusKm = record.double(for: "location_rule_radius_km") ?? 50.0
            watchlist.locationRuleDisplayName = record.string(for: "location_rule_display_name")
            watchlist.dateRuleEnabled = record.bool(for: "date_rule_enabled") ?? false
            watchlist.dateRuleStartDate = record.date(for: "date_rule_start_date")
            watchlist.dateRuleEndDate = record.date(for: "date_rule_end_date")
            watchlist.deleted_at = record.date(for: "deleted_at")
            watchlist.syncStatus = .synced
            watchlist.lastSyncedAt = Date()
            watchlist.updated_at = record.date(for: "updated_at")
            
            print("📡 [Realtime] Updated watchlist from server: \(watchlist.title ?? "unnamed")")
        } else {
            // INSERT - Create new
            let watchlist = Watchlist(
                id: id,
                owner_id: record.uuid(for: "owner_id"),
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
            watchlist.speciesRuleEnabled = record.bool(for: "species_rule_enabled") ?? false
            watchlist.speciesRuleShapeId = record.string(for: "species_rule_shape_id")
            watchlist.locationRuleEnabled = record.bool(for: "location_rule_enabled") ?? false
            watchlist.locationRuleLat = record.double(for: "location_rule_lat")
            watchlist.locationRuleLon = record.double(for: "location_rule_lon")
            watchlist.locationRuleRadiusKm = record.double(for: "location_rule_radius_km") ?? 50.0
            watchlist.locationRuleDisplayName = record.string(for: "location_rule_display_name")
            watchlist.dateRuleEnabled = record.bool(for: "date_rule_enabled") ?? false
            watchlist.dateRuleStartDate = record.date(for: "date_rule_start_date")
            watchlist.dateRuleEndDate = record.date(for: "date_rule_end_date")
            watchlist.deleted_at = record.date(for: "deleted_at")
            watchlist.syncStatus = .synced
            watchlist.lastSyncedAt = Date()
            watchlist.updated_at = record.date(for: "updated_at")
            
            // Note: Would need to insert into context
            print("📡 [Realtime] Created watchlist from server: \(watchlist.title ?? "unnamed")")
        }
    }
    
    private func deleteWatchlist(id: UUID) async throws {
        guard let watchlist = try WatchlistManager.shared.getWatchlist(by: id) else { return }
        
        // Server says delete - apply immediately
        watchlist.syncStatus = .synced
        watchlist.deleted_at = Date()
        
        print("📡 [Realtime] Deleted watchlist (server authoritative): \(id)")
    }
    
    private func upsertEntry(from record: [String: JSONValue], id: UUID) async throws {
        guard let watchlistId = record.uuid(for: "watchlist_id"),
              let watchlist = try WatchlistManager.shared.getWatchlist(by: watchlistId) else { return }
        
        // Find existing entry
        var existingEntry: WatchlistEntry?
        if let entries = watchlist.entries {
            existingEntry = entries.first { $0.id == id }
        }
        
        if let entry = existingEntry {
            // UPDATE - Server wins
            entry.status = record.string(for: "status") == "observed" ? .observed : .to_observe
            entry.nickname = record.string(for: "nickname")
            entry.notes = record.string(for: "notes")
            entry.observationDate = record.date(for: "observation_date")
            entry.toObserveStartDate = record.date(for: "to_observe_start_date")
            entry.toObserveEndDate = record.date(for: "to_observe_end_date")
            entry.observedBy = record.string(for: "observed_by")
            entry.lat = record.double(for: "lat")
            entry.lon = record.double(for: "lon")
            entry.locationDisplayName = record.string(for: "location_display_name")
            entry.priority = record.int(for: "priority") ?? 0
            entry.notify_upcoming = record.bool(for: "notify_upcoming") ?? false
            entry.target_date_range = record.string(for: "target_date_range")
            entry.syncStatus = .synced
            entry.lastSyncedAt = Date()
            
            print("📡 [Realtime] Updated entry from server: \(id)")
        } else {
            // INSERT - Create new entry
            let entry = WatchlistEntry(
                id: id,
                watchlist: watchlist,
                bird: nil, // Bird reference would need to be resolved
                status: record.string(for: "status") == "observed" ? .observed : .to_observe,
                notes: record.string(for: "notes"),
                observationDate: record.date(for: "observation_date"),
                observedBy: record.string(for: "observed_by")
            )
            entry.nickname = record.string(for: "nickname")
            entry.toObserveStartDate = record.date(for: "to_observe_start_date")
            entry.toObserveEndDate = record.date(for: "to_observe_end_date")
            entry.lat = record.double(for: "lat")
            entry.lon = record.double(for: "lon")
            entry.locationDisplayName = record.string(for: "location_display_name")
            entry.priority = record.int(for: "priority") ?? 0
            entry.notify_upcoming = record.bool(for: "notify_upcoming") ?? false
            entry.target_date_range = record.string(for: "target_date_range")
            entry.syncStatus = .synced
            entry.lastSyncedAt = Date()
            
            print("📡 [Realtime] Created entry from server: \(id)")
        }
    }
    
    private func deleteEntry(id: UUID) async throws {
        // Find and delete entry
        let watchlists = try WatchlistManager.shared.fetchWatchlists()
        for watchlist in watchlists {
            if let entries = watchlist.entries {
                for entry in entries where entry.id == id {
                    entry.syncStatus = .synced
                    // Mark deleted - actual removal happens on save
                    print("📡 [Realtime] Deleted entry (server authoritative): \(id)")
                    return
                }
            }
        }
    }
    
    private func upsertRule(from record: [String: JSONValue], id: UUID) async throws {
        guard let watchlistId = record.uuid(for: "watchlist_id"),
              let watchlist = try WatchlistManager.shared.getWatchlist(by: watchlistId) else { return }
        
        // Find existing rule
        var existingRule: WatchlistRule?
        if let rules = watchlist.rules {
            existingRule = rules.first { $0.id == id }
        }
        
        if let rule = existingRule {
            // UPDATE - Server wins
            rule.parameters_json = record.string(for: "parameters_json") ?? "{}"
            rule.is_active = record.bool(for: "is_active") ?? true
            rule.priority = record.int(for: "priority") ?? 0
            rule.deleted_at = record.date(for: "deleted_at")
            rule.syncStatus = .synced
            rule.lastSyncedAt = Date()
            
            print("📡 [Realtime] Updated rule from server: \(id)")
        } else {
            // INSERT - Create new
            let ruleTypeString = record.string(for: "rule_type") ?? "location"
            let ruleType = WatchlistRuleType(rawValue: ruleTypeString) ?? .location
            
            let rule = WatchlistRule(
                id: id,
                watchlist: watchlist,
                rule_type: ruleType,
                parameters: record.string(for: "parameters_json") ?? "{}"
            )
            rule.is_active = record.bool(for: "is_active") ?? true
            rule.priority = record.int(for: "priority") ?? 0
            rule.syncStatus = .synced
            rule.lastSyncedAt = Date()
            
            print("📡 [Realtime] Created rule from server: \(id)")
        }
    }
    
    private func deleteRule(id: UUID) async throws {
        let watchlists = try WatchlistManager.shared.fetchWatchlists()
        for watchlist in watchlists {
            if let rules = watchlist.rules {
                for rule in rules where rule.id == id {
                    rule.syncStatus = .synced
                    rule.deleted_at = Date()
                    print("📡 [Realtime] Deleted rule (server authoritative): \(id)")
                    return
                }
            }
        }
    }
    
    private func upsertPhoto(from record: [String: JSONValue], id: UUID) async throws {
        guard let entryId = record.uuid(for: "watchlist_entry_id") else { return }
        
        // Find entry
        let watchlists = try WatchlistManager.shared.fetchWatchlists()
        for watchlist in watchlists {
            if let entries = watchlist.entries {
                for entry in entries where entry.id == entryId {
                    // Find or create photo
                    var existingPhoto: ObservedBirdPhoto?
                    if let photos = entry.photos {
                        existingPhoto = photos.first { $0.id == id }
                    }
                    
                    if let photo = existingPhoto {
                        // UPDATE - Server wins
                        photo.imagePath = record.string(for: "image_path") ?? ""
                        photo.storageUrl = record.string(for: "storage_url")
                        photo.isUploaded = record.bool(for: "is_uploaded") ?? false
                        photo.captured_at = record.date(for: "captured_at")
                        photo.syncStatus = .synced
                        photo.lastSyncedAt = Date()
                        
                        print("📡 [Realtime] Updated photo from server: \(id)")
                    } else {
                        // INSERT - Create new
                        let photo = ObservedBirdPhoto(
                            id: id,
                            watchlistEntry: entry,
                            imagePath: record.string(for: "image_path") ?? ""
                        )
                        photo.storageUrl = record.string(for: "storage_url")
                        photo.isUploaded = record.bool(for: "is_uploaded") ?? false
                        photo.captured_at = record.date(for: "captured_at")
                        photo.syncStatus = .synced
                        photo.lastSyncedAt = Date()
                        
                        print("📡 [Realtime] Created photo from server: \(id)")
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
                            photo.syncStatus = .synced
                            // Mark for removal
                            print("📡 [Realtime] Deleted photo (server authoritative): \(id)")
                            return
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Heartbeat
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
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
                print("📡 [Realtime] Heartbeat error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - State Management
    
    private func updateConnectionState(_ state: RealtimeConnectionState) {
        connectionState = state
        onConnectionStateChanged?(state)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension RealtimeSyncService: URLSessionWebSocketDelegate {
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            print("📡 [Realtime] WebSocket opened")
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
            print("📡 [Realtime] WebSocket closed: \(closeCode.rawValue)")
            
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
