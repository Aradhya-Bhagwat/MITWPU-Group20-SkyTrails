import Foundation
import SwiftData
import BackgroundTasks

enum SyncOperationType: String, Sendable, Equatable, Codable {
    case create
    case update
    case delete
}

struct SyncOperation: Sendable, Codable {
    let id: UUID
    let type: SyncOperationType
    let table: String
    let recordId: UUID
    let payloadData: Data?
    let created_at: Date
    let localUpdatedAt: Date?
    var attempts: Int = 0
    var lastError: String?
    
    nonisolated init(type: SyncOperationType, table: String, recordId: UUID, payloadData: Data? = nil, localUpdatedAt: Date? = nil) {
        self.id = UUID()
        self.type = type
        self.table = table
        self.recordId = recordId
        self.payloadData = payloadData
        self.created_at = Date()
        self.localUpdatedAt = localUpdatedAt
    }
}

actor BackgroundSyncAgent {
    
    static let shared = BackgroundSyncAgent()
    static let taskIdentifier = "com.skytrails.sync.watchlist"
    
    private var queue: [SyncOperation] = []
    private var deadLetterQueue: [SyncOperation] = []
    private var isProcessing: Bool = false
    
    private let maxRetries: Int = 5
    private let baseDelay: TimeInterval = 2.0
    
    private var config: SupabaseConfig?
    
    private static let queueFileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("sync_queue.json")
    
    private static let deadLetterFileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("dead_letter_queue.json")
    
    private init() {
        self.queue = Self.loadQueueFromDisk()
        self.deadLetterQueue = Self.loadDeadLetterFromDisk()
    }
    
    private static func loadQueueFromDisk() -> [SyncOperation] {
        guard let data = try? Data(contentsOf: queueFileURL),
              let ops = try? JSONDecoder().decode([SyncOperation].self, from: data)
        else { return [] }
        return ops
    }
    
    private static func loadDeadLetterFromDisk() -> [SyncOperation] {
        guard let data = try? Data(contentsOf: deadLetterFileURL),
              let ops = try? JSONDecoder().decode([SyncOperation].self, from: data)
        else { return [] }
        return ops
    }
    
    private static func saveQueueToDisk(_ ops: [SyncOperation]) {
        guard let data = try? JSONEncoder().encode(ops) else { return }
        try? data.write(to: queueFileURL)
    }
    
    private static func saveDeadLetterToDisk(_ ops: [SyncOperation]) {
        guard let data = try? JSONEncoder().encode(ops) else { return }
        try? data.write(to: deadLetterFileURL)
    }

    // --- Queue Methods ---

    func queueWatchlist(id: UUID, payloadData: Data?, updated_at: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(type: operation, table: "watchlists", recordId: id, payloadData: payloadData, localUpdatedAt: updated_at)
        addToQueue(syncOp)
    }

    func queueEntry(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(type: operation, table: "watchlist_entries", recordId: id, payloadData: payloadData, localUpdatedAt: localUpdatedAt)
        addToQueue(syncOp)
    }

    func queueRule(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(type: operation, table: "watchlist_rules", recordId: id, payloadData: payloadData, localUpdatedAt: localUpdatedAt)
        addToQueue(syncOp)
    }

    func queueShare(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(type: operation, table: "watchlist_shares", recordId: id, payloadData: payloadData, localUpdatedAt: localUpdatedAt)
        addToQueue(syncOp)
    }

    func queuePhoto(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(type: operation, table: "observed_bird_photos", recordId: id, payloadData: payloadData, localUpdatedAt: localUpdatedAt)
        addToQueue(syncOp)
    }

    func queueIdentificationSession(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(type: operation, table: "identification_sessions", recordId: id, payloadData: payloadData, localUpdatedAt: localUpdatedAt)
        addToQueue(syncOp)
    }

    func queueIdentificationResult(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(type: operation, table: "identification_results", recordId: id, payloadData: payloadData, localUpdatedAt: localUpdatedAt)
        addToQueue(syncOp)
    }

    func queueIdentificationCandidate(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(type: operation, table: "identification_candidates", recordId: id, payloadData: payloadData, localUpdatedAt: localUpdatedAt)
        addToQueue(syncOp)
    }

    func queueIdentificationSessionMark(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(type: operation, table: "identification_session_marks", recordId: id, payloadData: payloadData, localUpdatedAt: localUpdatedAt)
        addToQueue(syncOp)
    }

    func purgeIdentificationOperations() {
        let identificationTables: Set<String> = [
            "identification_sessions",
            "identification_results",
            "identification_candidates",
            "identification_session_marks"
        ]
        queue.removeAll { identificationTables.contains($0.table) }
        deadLetterQueue.removeAll { identificationTables.contains($0.table) }
        Self.saveQueueToDisk(queue)
        Self.saveDeadLetterToDisk(deadLetterQueue)
    }

    private func addToQueue(_ op: SyncOperation) {
        queue.append(op)
        Self.saveQueueToDisk(queue)
        Task {
            await processQueue()
        }
    }

    // --- Sync All & Scanning ---

    func syncAll() async {
        await scanForPendingChanges()
        await processQueue()
    }

    private func scanForPendingChanges() async {
        await MainActor.run {
            let context = WatchlistManager.shared.context
            
            scanWatchlists(context: context)
            scanEntries(context: context)
            scanRules(context: context)
            scanShares(context: context)
            scanPhotos(context: context)
            scanIdentificationSessions(context: context)
            scanIdentificationResults(context: context)
            scanIdentificationCandidates(context: context)
            scanIdentificationSessionMarks(context: context)
        }
    }

    @MainActor
    private func scanWatchlists(context: ModelContext) {
        let descriptor = FetchDescriptor<Watchlist>()
        if let items = try? context.fetch(descriptor) {
            for item in items where item.syncStatus != .synced && item.user_id != nil {
                let opType: SyncOperationType = (item.syncStatus == .pendingDelete) ? .delete : (item.syncStatus == .pendingCreate ? .create : .update)
                let payload = buildWatchlistPayload(item)
                let id = item.watchlist_id
                let updated_at = item.updated_at
                Task {
                    await self.queueWatchlist(id: id, payloadData: payload, updated_at: updated_at, operation: opType)
                }
            }
        }
    }

    @MainActor
    private func scanEntries(context: ModelContext) {
        let descriptor = FetchDescriptor<WatchlistEntry>()
        if let items = try? context.fetch(descriptor) {
            for item in items where item.syncStatus != .synced {
                // Entries depend on their watchlist which now has a user check
                let opType: SyncOperationType = (item.syncStatus == .pendingDelete) ? .delete : (item.syncStatus == .pendingCreate ? .create : .update)
                let payload = buildEntryPayload(item)
                let id = item.id
                let localUpdatedAt = item.observationDate ?? item.addedDate
                Task {
                    await self.queueEntry(id: id, payloadData: payload, localUpdatedAt: localUpdatedAt, operation: opType)
                }
            }
        }
    }

    @MainActor
    private func scanRules(context: ModelContext) {
        let descriptor = FetchDescriptor<WatchlistRule>()
        if let items = try? context.fetch(descriptor) {
            for item in items where item.syncStatus != .synced {
                let opType: SyncOperationType = (item.syncStatus == .pendingDelete) ? .delete : (item.syncStatus == .pendingCreate ? .create : .update)
                let payload = buildRulePayload(item)
                let id = item.id
                let localUpdatedAt = item.created_at
                Task {
                    await self.queueRule(id: id, payloadData: payload, localUpdatedAt: localUpdatedAt, operation: opType)
                }
            }
        }
    }

    @MainActor
    private func scanShares(context: ModelContext) {
        let descriptor = FetchDescriptor<WatchlistShare>()
        if let items = try? context.fetch(descriptor) {
            for item in items where item.syncStatus != .synced {
                let opType: SyncOperationType = (item.syncStatus == .pendingDelete) ? .delete : (item.syncStatus == .pendingCreate ? .create : .update)
                let payload = buildSharePayload(item)
                let id = item.id
                let localUpdatedAt = item.shared_at
                Task {
                    await self.queueShare(id: id, payloadData: payload, localUpdatedAt: localUpdatedAt, operation: opType)
                }
            }
        }
    }

    @MainActor
    private func scanPhotos(context: ModelContext) {
        let descriptor = FetchDescriptor<ObservedBirdPhoto>()
        if let items = try? context.fetch(descriptor) {
            for item in items where item.syncStatus != .synced {
                let opType: SyncOperationType = (item.syncStatus == .pendingDelete) ? .delete : (item.syncStatus == .pendingCreate ? .create : .update)
                let payload = buildPhotoPayload(item)
                let id = item.id
                let localUpdatedAt = item.captured_at ?? item.created_at
                Task {
                    await self.queuePhoto(id: id, payloadData: payload, localUpdatedAt: localUpdatedAt, operation: opType)
                }
            }
        }
    }

    @MainActor
    private func scanIdentificationSessions(context: ModelContext) {
        let descriptor = FetchDescriptor<IdentificationSession>()
        if let items = try? context.fetch(descriptor) {
            for item in items where item.syncStatus != .synced && item.user_id != nil {
                let opType: SyncOperationType = (item.syncStatus == .pendingDelete) ? .delete : (item.syncStatus == .pendingCreate ? .create : .update)
                let payload = buildIdentificationSessionPayload(item)
                let id = item.identification_session_id
                let localUpdatedAt = item.created_at
                Task {
                    await self.queueIdentificationSession(id: id, payloadData: payload, localUpdatedAt: localUpdatedAt, operation: opType)
                }
            }
        }
    }

    @MainActor
    private func scanIdentificationResults(context: ModelContext) {
        let descriptor = FetchDescriptor<IdentificationResult>()
        if let items = try? context.fetch(descriptor) {
            for item in items where item.syncStatus != .synced && item.user_id != nil {
                let opType: SyncOperationType = (item.syncStatus == .pendingDelete) ? .delete : (item.syncStatus == .pendingCreate ? .create : .update)
                let payload = buildIdentificationResultPayload(item)
                let id = item.identification_result_id
                let localUpdatedAt = item.created_at
                Task {
                    await self.queueIdentificationResult(id: id, payloadData: payload, localUpdatedAt: localUpdatedAt, operation: opType)
                }
            }
        }
    }

    @MainActor
    private func scanIdentificationCandidates(context: ModelContext) {
        let descriptor = FetchDescriptor<IdentificationCandidate>()
        if let items = try? context.fetch(descriptor) {
            for item in items where item.syncStatus != .synced {
                let opType: SyncOperationType = (item.syncStatus == .pendingDelete) ? .delete : (item.syncStatus == .pendingCreate ? .create : .update)
                let payload = buildIdentificationCandidatePayload(item)
                let id = item.identification_candidate_id
                let localUpdatedAt = item.created_at
                Task {
                    await self.queueIdentificationCandidate(id: id, payloadData: payload, localUpdatedAt: localUpdatedAt, operation: opType)
                }
            }
        }
    }

    @MainActor
    private func scanIdentificationSessionMarks(context: ModelContext) {
        let descriptor = FetchDescriptor<IdentificationSessionFieldMark>()
        if let items = try? context.fetch(descriptor) {
            for item in items where item.syncStatus != .synced {
                let opType: SyncOperationType = (item.syncStatus == .pendingDelete) ? .delete : (item.syncStatus == .pendingCreate ? .create : .update)
                let payload = buildIdentificationSessionMarkPayload(item)
                let id = item.identification_session_mark_id
                let localUpdatedAt = item.created_at
                Task {
                    await self.queueIdentificationSessionMark(id: id, payloadData: payload, localUpdatedAt: localUpdatedAt, operation: opType)
                }
            }
        }
    }

    // --- Payload Builders ---

    @MainActor
    private func buildWatchlistPayload(_ item: Watchlist) -> Data? {
        let userId = item.user_id?.uuidString ?? UserSession.shared.currentUser?.user_id.uuidString
        let payload: [String: Any] = [
            "watchlist_id": item.watchlist_id.uuidString,
            "user_id": userId as Any,
            "type": item.type?.rawValue ?? "custom",
            "title": item.title as Any,
            "location": item.location as Any,
            "location_display_name": item.locationDisplayName as Any,
            "start_date": item.startDate != nil ? ISO8601DateFormatter().string(from: item.startDate!) : NSNull(),
            "end_date": item.endDate != nil ? ISO8601DateFormatter().string(from: item.endDate!) : NSNull(),
            "cover_image_path": item.coverImagePath as Any,
            "updated_at": ISO8601DateFormatter().string(from: Date()),
            "deleted_at": item.deleted_at != nil ? ISO8601DateFormatter().string(from: item.deleted_at!) : NSNull()
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    @MainActor
    private func buildEntryPayload(_ item: WatchlistEntry) -> Data? {
        let observedByUserId = item.observedByUserId?.uuidString ?? (item.status == .observed ? UserSession.shared.currentUser?.user_id.uuidString : nil)
        let payload: [String: Any] = [
            "watchlist_entry_id": item.id.uuidString,
            "watchlist_id": item.watchlist?.watchlist_id.uuidString as Any,
            "nickname": item.nickname as Any,
            "status": item.status.rawValue,
            "notes": item.notes as Any,
            "observation_date": item.observationDate != nil ? ISO8601DateFormatter().string(from: item.observationDate!) : NSNull(),
            "to_observe_start_date": item.toObserveStartDate != nil ? ISO8601DateFormatter().string(from: item.toObserveStartDate!) : NSNull(),
            "to_observe_end_date": item.toObserveEndDate != nil ? ISO8601DateFormatter().string(from: item.toObserveEndDate!) : NSNull(),
            "observed_by": item.observedBy as Any,
            "observed_by_user_id": observedByUserId as Any,
            "lat": item.lat as Any,
            "lon": item.lon as Any,
            "location_display_name": item.locationDisplayName as Any,
            "priority": item.priority,
            "notify_upcoming": item.notify_upcoming,
            "added_date": ISO8601DateFormatter().string(from: item.addedDate),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    @MainActor
    private func buildRulePayload(_ item: WatchlistRule) -> Data? {
        let payload: [String: Any] = [
            "watchlist_rule_id": item.id.uuidString,
            "watchlist_id": item.watchlist?.watchlist_id.uuidString as Any,
            "rule_type": item.rule_type.rawValue,
            "lat": item.lat as Any,
            "lon": item.lon as Any,
            "radius_km": item.radius_km as Any,
            "start_date": item.start_date != nil ? ISO8601DateFormatter().string(from: item.start_date!) : NSNull(),
            "end_date": item.end_date != nil ? ISO8601DateFormatter().string(from: item.end_date!) : NSNull(),
            "shape_id": item.shape_id as Any,
            "pattern_key": item.pattern_key as Any,
            "is_active": item.is_active,
            "priority": item.priority,
            "updated_at": ISO8601DateFormatter().string(from: Date()),
            "deleted_at": item.deleted_at != nil ? ISO8601DateFormatter().string(from: item.deleted_at!) : NSNull()
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    @MainActor
    private func buildSharePayload(_ item: WatchlistShare) -> Data? {
        let payload: [String: Any] = [
            "watchlist_share_id": item.id.uuidString,
            "watchlist_id": item.watchlist?.watchlist_id.uuidString as Any,
            "user_id": item.user_id.uuidString,
            "permission": item.permission.rawValue,
            "shared_at": ISO8601DateFormatter().string(from: item.shared_at),
            "shared_by_user_id": item.shared_by_user_id?.uuidString as Any,
            "deleted_at": item.deleted_at != nil ? ISO8601DateFormatter().string(from: item.deleted_at!) : NSNull()
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    @MainActor
    private func buildPhotoPayload(_ item: ObservedBirdPhoto) -> Data? {
        let payload: [String: Any] = [
            "observed_bird_photo_id": item.id.uuidString,
            "watchlist_entry_id": item.watchlistEntry?.id.uuidString as Any,
            "image_path": item.imagePath,
            "storage_url": item.storageUrl as Any,
            "captured_at": item.captured_at != nil ? ISO8601DateFormatter().string(from: item.captured_at!) : NSNull(),
            "uploaded_at": ISO8601DateFormatter().string(from: item.uploaded_at),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    @MainActor
    private func buildIdentificationSessionPayload(_ item: IdentificationSession) -> Data? {
        var metadata: [String: String] = item.metadata ?? [:]
        if let shapeId = item.shape?.bird_shape_id { metadata["shapeId"] = shapeId }
        if let locationDisplayName = item.locationDisplayName { metadata["locationDisplayName"] = locationDisplayName }
        if let sizeCategory = item.sizeCategory { metadata["sizeCategory"] = String(sizeCategory) }
        if let filterCategories = item.selectedFilterCategories { metadata["filterCategories"] = filterCategories.joined(separator: ",") }
        metadata["observationDate"] = ISO8601DateFormatter().string(from: item.observationDate)

        let payload: [String: Any] = [
            "identification_session_id": item.identification_session_id.uuidString,
            "user_id": item.user_id?.uuidString as Any,
            "status": item.status.rawValue,
            "location_lat": item.locationLat as Any,
            "location_long": item.locationLong as Any,
            "device_info": item.deviceInfo as Any,
            "notes": item.notes as Any,
            "is_public": item.isPublic,
            "weather_conditions": item.weatherConditions as Any,
            "metadata": metadata,
            "created_at": ISO8601DateFormatter().string(from: item.created_at),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    @MainActor
    private func buildIdentificationResultPayload(_ item: IdentificationResult) -> Data? {
        let ownerId = item.user_id?.uuidString ?? UserSession.shared.currentUser?.user_id.uuidString
        let payload: [String: Any] = [
            "identification_result_id": item.identification_result_id.uuidString,
            "identification_session_id": item.session?.identification_session_id.uuidString as Any,
            "owner_id": ownerId as Any,
            "bird_id": item.bird?.bird_id.uuidString as Any,
            "created_at": ISO8601DateFormatter().string(from: item.created_at),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    @MainActor
    private func buildIdentificationCandidatePayload(_ item: IdentificationCandidate) -> Data? {
        let payload: [String: Any] = [
            "identification_candidate_id": item.identification_candidate_id.uuidString,
            "identification_result_id": item.result?.identification_result_id.uuidString as Any,
            "bird_id": item.bird?.bird_id.uuidString as Any,
            "confidence": item.confidence,
            "confidence_rank": item.rank as Any,
            "matched_features": item.matchScore?.matchedFeatures ?? [],
            "mismatched_features": item.matchScore?.mismatchedFeatures ?? [],
            "created_at": ISO8601DateFormatter().string(from: item.created_at),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    @MainActor
    private func buildIdentificationSessionMarkPayload(_ item: IdentificationSessionFieldMark) -> Data? {
        let payload: [String: Any] = [
            "identification_session_mark_id": item.identification_session_mark_id.uuidString,
            "identification_session_id": item.identification_session_id.uuidString,
            "field_mark_id": item.field_mark_id.uuidString,
            "variant_id": item.variant_id.uuidString,
            "area": item.area,
            "created_at": ISO8601DateFormatter().string(from: item.created_at),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    // --- Processing ---

    func retryFailed() async {
        let retryableItems = deadLetterQueue.filter { $0.attempts < maxRetries }
        deadLetterQueue.removeAll { $0.attempts < maxRetries }
        Self.saveDeadLetterToDisk(deadLetterQueue)
        queue.append(contentsOf: retryableItems)
        Self.saveQueueToDisk(queue)
        await processQueue()
    }

    func clearAll() {
        queue.removeAll()
        deadLetterQueue.removeAll()
        Self.saveQueueToDisk(queue)
        Self.saveDeadLetterToDisk(deadLetterQueue)
    }
    
    public func pendingOperationCount() -> Int {
        return queue.count
    }
    
    public func deadLetterCount() -> Int {
        return deadLetterQueue.count
    }

    nonisolated func registerBackgroundTasks() {
        #if os(iOS)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            Task {
                await self.handleBackgroundTask(processingTask)
            }
        }
        #endif
    }

    func scheduleBackgroundSync() {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
        }
        #endif
    }

    #if os(iOS)
    private func handleBackgroundTask(_ task: BGProcessingTask) async {
        task.expirationHandler = { }
        await syncAll()
        task.setTaskCompleted(success: true)
    }
    #endif
    
    private func processQueue() async {
        guard !isProcessing, !queue.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        if config == nil { config = try? SupabaseConfig.load() }
        guard let config else { return }
        
        let isAuthenticated = await MainActor.run { UserSession.shared.isAuthenticatedWithSupabase() }
        guard isAuthenticated else { return }
        
        // --- Prioritize Operations ---
        let priorityMap: [String: Int] = [
            "users": 1,
            "watchlists": 2,
            "watchlist_entries": 3,
            "identification_sessions": 4,
            "identification_results": 5,
            "identification_candidates": 6,
            "identification_session_marks": 6,
            "watchlist_rules": 7,
            "watchlist_shares": 8,
            "observed_bird_photos": 9
        ]
        
        queue.sort { op1, op2 in
            let p1 = priorityMap[op1.table] ?? 100
            let p2 = priorityMap[op2.table] ?? 100
            if p1 != p2 {
                return p1 < p2
            }
            return op1.localUpdatedAt ?? Date.distantPast < op2.localUpdatedAt ?? Date.distantPast
        }
        
        // Use a while loop to handle items added during processing
        while !queue.isEmpty {
            let operation = queue[0]
            do {
                let shouldProceed = try await checkServerConflict(operation, config: config)
                if shouldProceed {
                    try await processOperation(operation, config: config)
                    
                    // MARK: - Update Local Sync Status
                    await MainActor.run {
                        let context = WatchlistManager.shared.context
                        let recordId = operation.recordId

                        switch operation.table {
                        case "watchlists":
                            if let item = try? context.fetch(FetchDescriptor<Watchlist>(predicate: #Predicate { $0.watchlist_id == recordId })).first {
                                item.syncStatus = .synced
                                item.lastSyncedAt = Date()
                            }
                        case "watchlist_entries":
                            if let item = try? context.fetch(FetchDescriptor<WatchlistEntry>(predicate: #Predicate { $0.id == recordId })).first {
                                item.syncStatus = .synced
                                item.lastSyncedAt = Date()
                            }
                        case "watchlist_rules":
                            if let item = try? context.fetch(FetchDescriptor<WatchlistRule>(predicate: #Predicate { $0.id == recordId })).first {
                                item.syncStatus = .synced
                                item.lastSyncedAt = Date()
                            }
                        case "watchlist_shares":
                            if let item = try? context.fetch(FetchDescriptor<WatchlistShare>(predicate: #Predicate { $0.id == recordId })).first {
                                item.syncStatus = .synced
                                item.lastSyncedAt = Date()
                            }
                        case "observed_bird_photos":
                            if let item = try? context.fetch(FetchDescriptor<ObservedBirdPhoto>(predicate: #Predicate { $0.id == recordId })).first {
                                item.syncStatus = .synced
                                item.lastSyncedAt = Date()
                            }
                        case "identification_sessions":
                            if let item = try? context.fetch(FetchDescriptor<IdentificationSession>(predicate: #Predicate { $0.identification_session_id == recordId })).first {
                                item.syncStatus = .synced
                                item.lastSyncedAt = Date()
                            }
                        case "identification_results":
                            if let item = try? context.fetch(FetchDescriptor<IdentificationResult>(predicate: #Predicate { $0.identification_result_id == recordId })).first {
                                item.syncStatus = .synced
                                item.lastSyncedAt = Date()
                            }
                        case "identification_candidates":
                            if let item = try? context.fetch(FetchDescriptor<IdentificationCandidate>(predicate: #Predicate { $0.identification_candidate_id == recordId })).first {
                                item.syncStatus = .synced
                                item.lastSyncedAt = Date()
                            }
                        case "identification_session_marks":
                            if let item = try? context.fetch(FetchDescriptor<IdentificationSessionFieldMark>(predicate: #Predicate { $0.identification_session_mark_id == recordId })).first {
                                item.syncStatus = .synced
                                item.lastSyncedAt = Date()
                            }
                        default: break
                        }
                        
                        if operation.type == .delete {
                            self.hardDeleteLocalRecord(table: operation.table, recordId: operation.recordId)
                        }
                        
                        try? context.save()
                    }
                }
                
                // Remove from queue ONLY after success or confirmed skip
                queue.remove(at: 0)
                Self.saveQueueToDisk(queue)
                
            } catch {
                var failedOp = operation
                print("DEBUG: BackgroundSyncAgent operation failed - table: \(operation.table), op: \(operation.type.rawValue), recordId: \(operation.recordId), error: \(error.localizedDescription)")
                
                // Special handling for 409 (Conflict/Foreign Key violation)
                if let nsError = error as NSError?, nsError.code == 409 {
                    print("DEBUG: BackgroundSyncAgent - 409 Conflict for \(operation.table). Moving to back of queue.")
                    queue.remove(at: 0)
                    queue.append(failedOp)
                    Self.saveQueueToDisk(queue)
                    // Continue to next item without incrementing attempts immediately
                    // This allows other creates (like parents) to finish first.
                    continue
                }
                
                failedOp.attempts += 1
                failedOp.lastError = error.localizedDescription
                
                if failedOp.attempts >= maxRetries {
                    let lastError = failedOp.lastError ?? "none"
                    print("DEBUG: BackgroundSyncAgent moving to dead-letter - table: \(failedOp.table), op: \(failedOp.type.rawValue), recordId: \(failedOp.recordId), attempts: \(failedOp.attempts), lastError: \(lastError)")
                    deadLetterQueue.append(failedOp)
                    queue.remove(at: 0)
                    Self.saveDeadLetterToDisk(deadLetterQueue)
                    Self.saveQueueToDisk(queue)
                } else {
                    // Update the operation in the queue and try again next loop or next run
                    queue[0] = failedOp
                    Self.saveQueueToDisk(queue)
                    // Wait a bit before retrying the same item
                    try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                }
            }
        }
    }

    private func replaceQueuedOperation(with operation: SyncOperation) -> Bool {
        guard let index = queue.firstIndex(where: { $0.id == operation.id }) else { return false }
        queue[index] = operation
        return true
    }
    
    private func checkServerConflict(_ operation: SyncOperation, config: SupabaseConfig) async throws -> Bool {
        if operation.type == .create { return true }
        
        let serverRecord = try await fetchServerRecord(table: operation.table, recordId: operation.recordId, config: config)
        print("DEBUG: ConflictCheck - table: \(operation.table), op: \(operation.type.rawValue), recordId: \(operation.recordId), hasServerRecord: \(serverRecord != nil)")
        
        if operation.type == .delete {
            if serverRecord == nil {
                print("DEBUG: ConflictCheck - delete skipped (server row missing): \(operation.table) \(operation.recordId)")
                return false
            }
            if let deletedAt = serverRecord?["deleted_at"] as? String, !deletedAt.isEmpty {
                print("DEBUG: ConflictCheck - delete skipped (already deleted on server): \(operation.table) \(operation.recordId), deleted_at: \(deletedAt)")
                return false
            }
            return true
        }
        
        guard let serverRecord,
              let serverUpdatedAtStr = serverRecord["updated_at"] as? String,
              let serverUpdatedAt = ISO8601DateFormatter().date(from: serverUpdatedAtStr),
              let localUpdatedAt = operation.localUpdatedAt else {
            return true
        }
        
        let shouldProceed = localUpdatedAt >= serverUpdatedAt
        print("DEBUG: ConflictCheck - update decision table: \(operation.table), recordId: \(operation.recordId), localUpdatedAt: \(String(describing: operation.localUpdatedAt)), serverUpdatedAt: \(String(describing: serverRecord["updated_at"])), shouldProceed: \(shouldProceed)")
        return shouldProceed
    }
    
    private func fetchServerRecord(table: String, recordId: UUID, config: SupabaseConfig) async throws -> [String: Any]? {
        let token = await MainActor.run { UserSession.shared.getAccessToken() }
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else { return nil }
        
        components.path = "/rest/v1/\(table)"
        let primaryKey = primaryKeyColumn(for: table)
        components.queryItems = [
            URLQueryItem(name: primaryKey, value: "eq.\(recordId.uuidString)"),
            URLQueryItem(name: "select", value: "updated_at,deleted_at")
        ]
        
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            let body = String(data: data, encoding: .utf8) ?? "(non-utf8 body, \(data.count) bytes)"
            print("DEBUG: ConflictCheck fetch - table: \(table), recordId: \(recordId), status: \(httpResponse.statusCode), body: \(String(body.prefix(500)))")
        }
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstRecord = jsonArray.first else { return nil }
        
        return firstRecord
    }
    
    private func processOperation(_ operation: SyncOperation, config: SupabaseConfig) async throws {
        let token = await MainActor.run { UserSession.shared.getAccessToken() }
        var payload: [String: Any] = [:]
        if let payloadData = operation.payloadData {
            payload = (try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]) ?? [:]
        }
        
        // Log the payload for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("DEBUG: BackgroundSyncAgent - Sending payload to table '\(operation.table)':\n\(jsonString)")
        }

        if operation.table == "observed_bird_photos" {
            if operation.type == .create || operation.type == .update {
                try await uploadPhotoIfNeeded(payload: &payload, config: config, token: token)
            } else if operation.type == .delete {
                try await deletePhotoFromStorage(payload: payload, config: config, token: token)
            }
        }
        
        switch operation.type {
        case .create: try await createRecord(table: operation.table, payload: payload, config: config, token: token)
        case .update: try await updateRecord(table: operation.table, recordId: operation.recordId, payload: payload, config: config, token: token)
        case .delete: try await deleteRecord(table: operation.table, recordId: operation.recordId, config: config, token: token)
        }
        print("DEBUG: BackgroundSyncAgent operation success - table: \(operation.table), op: \(operation.type.rawValue), recordId: \(operation.recordId)")
    }
    
    private func createRecord(table: String, payload: [String: Any], config: SupabaseConfig, token: String?) async throws {
        let pk = primaryKeyColumn(for: table)
        // Always use upsert logic (POST with on_conflict) for better resilience
        let path = "/rest/v1/\(table)?on_conflict=\(pk)"
        
        var request = try buildRequest(path: path, method: "POST", config: config, token: token)
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        try await executeRequest(request)
    }
    
    private func updateRecord(table: String, recordId: UUID, payload: [String: Any], config: SupabaseConfig, token: String?) async throws {
        let pk = primaryKeyColumn(for: table)
        var request = try buildRequest(path: "/rest/v1/\(table)?\(pk)=eq.\(recordId.uuidString)", method: "PATCH", config: config, token: token)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        try await executeRequest(request)
    }
    
    private func deleteRecord(table: String, recordId: UUID, config: SupabaseConfig, token: String?) async throws {
        let pk = primaryKeyColumn(for: table)
        let method = (table == "observed_bird_photos") ? "DELETE" : "PATCH"
        var path = "/rest/v1/\(table)?\(pk)=eq.\(recordId.uuidString)"
        
        var request = try buildRequest(path: path, method: method, config: config, token: token)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        print("DEBUG: BackgroundSyncAgent delete request - table: \(table), recordId: \(recordId), method: \(method), path: \(path)")
        
        if method == "PATCH" {
            let payload: [String: Any] = ["deleted_at": ISO8601DateFormatter().string(from: Date())]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            print("DEBUG: BackgroundSyncAgent delete payload - table: \(table), recordId: \(recordId), payload: \(payload)")
        }
        
        try await executeRequest(request)
    }
    
    private func buildRequest(path: String, method: String, config: SupabaseConfig, token: String?) throws -> URLRequest {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        let parts = path.split(separator: "?", maxSplits: 1)
        components.path = String(parts[0])
        if parts.count > 1 { components.percentEncodedQuery = String(parts[1]) }
        
        guard let url = components.url else { throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func primaryKeyColumn(for table: String) -> String {
        switch table {
        case "watchlists": return "watchlist_id"
        case "watchlist_entries": return "watchlist_entry_id"
        case "watchlist_rules": return "watchlist_rule_id"
        case "watchlist_shares": return "watchlist_share_id"
        case "observed_bird_photos": return "observed_bird_photo_id"
        case "identification_sessions": return "identification_session_id"
        case "identification_results": return "identification_result_id"
        case "identification_candidates": return "identification_candidate_id"
        case "identification_session_marks": return "identification_session_mark_id"
        default: return "id"
        }
    }

    @MainActor
    private func hardDeleteLocalRecord(table: String, recordId: UUID) {
        let context = WatchlistManager.shared.context
        do {
            switch table {
            case "watchlists":
                if let item = try context.fetch(FetchDescriptor<Watchlist>(predicate: #Predicate { $0.watchlist_id == recordId })).first { context.delete(item) }
            case "watchlist_entries":
                if let item = try context.fetch(FetchDescriptor<WatchlistEntry>(predicate: #Predicate { $0.id == recordId })).first {
                    context.delete(item)
                    NotificationCenter.default.post(name: WatchlistManager.didLoadDataNotification, object: nil)
                }
            case "watchlist_rules":
                if let item = try context.fetch(FetchDescriptor<WatchlistRule>(predicate: #Predicate { $0.id == recordId })).first { context.delete(item) }
            case "watchlist_shares":
                if let item = try context.fetch(FetchDescriptor<WatchlistShare>(predicate: #Predicate { $0.id == recordId })).first { context.delete(item) }
            case "observed_bird_photos":
                if let item = try context.fetch(FetchDescriptor<ObservedBirdPhoto>(predicate: #Predicate { $0.id == recordId })).first { context.delete(item) }
            case "identification_sessions":
                if let item = try context.fetch(FetchDescriptor<IdentificationSession>(predicate: #Predicate { $0.identification_session_id == recordId })).first { context.delete(item) }
            case "identification_results":
                if let item = try context.fetch(FetchDescriptor<IdentificationResult>(predicate: #Predicate { $0.identification_result_id == recordId })).first { context.delete(item) }
            case "identification_candidates":
                if let item = try context.fetch(FetchDescriptor<IdentificationCandidate>(predicate: #Predicate { $0.identification_candidate_id == recordId })).first { context.delete(item) }
            case "identification_session_marks":
                if let item = try context.fetch(FetchDescriptor<IdentificationSessionFieldMark>(predicate: #Predicate { $0.identification_session_mark_id == recordId })).first { context.delete(item) }
            default: break
            }
        } catch { }
    }

    private func executeRequest(_ request: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]) }
        
        let responseBody = String(data: data, encoding: .utf8) ?? "(empty)"
        print("DEBUG: BackgroundSyncAgent response - Status: \(httpResponse.statusCode)")
        print("DEBUG: Response Body: \(responseBody)")
        
        if !(200...299).contains(httpResponse.statusCode) {
            var errorInfo: [String: Any] = [NSLocalizedDescriptionKey: responseBody]
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let message = errorJson["message"] as? String ?? "No message"
                let details = errorJson["details"] as? String ?? "No details"
                print("DEBUG: Supabase Sync Error - Message: \(message), Details: \(details)")
                errorInfo["supabase_message"] = message
                errorInfo["supabase_details"] = details
            }
            throw NSError(domain: "SyncAgent", code: httpResponse.statusCode, userInfo: errorInfo)
        }
    }
}

import Foundation
import SwiftData

extension BackgroundSyncAgent {
    func uploadPhotoIfNeeded(payload: inout [String: Any], config: SupabaseConfig, token: String?) async throws {
        if let storageUrl = payload["storage_url"] as? String, !storageUrl.isEmpty { return }
        guard let imagePath = payload["image_path"] as? String,
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let fileURL = documentsURL.appendingPathComponent("ObservedBirdPhotos", isDirectory: true).appendingPathComponent(imagePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw NSError(domain: "SyncAgent", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local photo file not found: \(imagePath)"]) }
        
        let data = try Data(contentsOf: fileURL)
        let userIdStr = await MainActor.run { UserSession.shared.currentUserID?.uuidString ?? "guest" }
        let storagePath = "\(userIdStr)/\(imagePath)"
        let storageURLStr = try await uploadToStorage(path: storagePath, data: data, config: config, token: token)
        payload["storage_url"] = storageURLStr
        if let idStr = payload["observed_bird_photo_id"] as? String, let id = UUID(uuidString: idStr) {
            await MainActor.run { NotificationCenter.default.post(name: NSNotification.Name("DidUploadPhoto"), object: nil, userInfo: ["id": id, "storageUrl": storageURLStr]) }
        }
    }
    
    func deletePhotoFromStorage(payload: [String: Any]?, config: SupabaseConfig, token: String?) async throws {
        guard let payload = payload, let storageUrlStr = payload["storage_url"] as? String,
              let storageUrl = URL(string: storageUrlStr), storageUrl.pathComponents.contains("photos"),
              let index = storageUrl.pathComponents.firstIndex(of: "photos") else { return }
        
        let storagePath = storageUrl.pathComponents.suffix(from: index + 1).joined(separator: "/")
        try await deleteFromStorage(path: storagePath, config: config, token: token)
    }
    
    private func uploadToStorage(path: String, data: Data, config: SupabaseConfig, token: String?) async throws -> String {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else { throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]) }
        components.path = "/storage/v1/object/photos/\(path)"
        guard let url = components.url else { throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        
        let (responseData, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse else { throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]) }
        
        if httpResponse.statusCode != 400 && httpResponse.statusCode != 409 && !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SyncAgent", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return config.projectURL.appendingPathComponent("storage/v1/object/public/photos/\(path)").absoluteString
    }
    
    private func deleteFromStorage(path: String, config: SupabaseConfig, token: String?) async throws {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else { throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]) }
        components.path = "/storage/v1/object/photos/\(path)"
        guard let url = components.url else { throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) { }
    }
}
