//
//  BackgroundSyncAgent.swift
//  SkyTrails
//
//  Actor-based outbound sync service for dual-write to Supabase
//  Server is always authoritative for conflicts
//

import Foundation
import SwiftData
import BackgroundTasks

// MARK: - Sync Operation

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
    let payloadData: Data? // JSON-encoded payload (Sendable)
    let createdAt: Date
    let localUpdatedAt: Date? // For conflict detection
    var attempts: Int = 0
    var lastError: String?
    
    nonisolated init(type: SyncOperationType, table: String, recordId: UUID, payloadData: Data? = nil, localUpdatedAt: Date? = nil) {
        self.id = UUID()
        self.type = type
        self.table = table
        self.recordId = recordId
        self.payloadData = payloadData
        self.createdAt = Date()
        self.localUpdatedAt = localUpdatedAt
    }
}

// MARK: - Background Sync Agent

actor BackgroundSyncAgent {
    
    static let shared = BackgroundSyncAgent()
    static let taskIdentifier = "com.skytrails.sync.watchlist"
    
    // MARK: - Properties
    
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
    
    // MARK: - Init
    
    private init() {
        self.queue = Self.loadQueueFromDisk()
        self.deadLetterQueue = Self.loadDeadLetterFromDisk()
    }
    
    // MARK: - Disk Persistence
    
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
    
    // MARK: - Public API
    
    /// Queue a watchlist operation for sync using Sendable primitives
    func queueWatchlist(id: UUID, payloadData: Data?, updatedAt: Date?, operation: SyncOperationType) {
        print("🔍 [SyncAgent] queueWatchlist called:")
        print("   - id: \(id)")
        print("   - operation: \(operation)")
        print("   - payloadData: \(payloadData != nil ? "\(payloadData!.count) bytes" : "nil")")
        
        if let data = payloadData, let jsonStr = String(data: data, encoding: .utf8) {
            print("   - payload JSON: \(jsonStr)")
        }
        
        let syncOp = SyncOperation(
            type: operation,
            table: "watchlists",
            recordId: id,
            payloadData: payloadData,
            localUpdatedAt: updatedAt
        )
        queue.append(syncOp)
        Self.saveQueueToDisk(queue)
        print("📤 [SyncAgent] Queued watchlist \(operation): \(id)")
        print("🔍 [SyncAgent] Queue now has \(queue.count) items")
        
        Task {
            print("🔍 [SyncAgent] Starting processQueue from queueWatchlist")
            await processQueue()
        }
    }
    
    /// Queue an entry operation for sync using Sendable primitives
    func queueEntry(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(
            type: operation,
            table: "watchlist_entries",
            recordId: id,
            payloadData: payloadData,
            localUpdatedAt: localUpdatedAt
        )
        queue.append(syncOp)
        Self.saveQueueToDisk(queue)
        print("📤 [SyncAgent] Queued entry \(operation): \(id)")
        
        Task {
            await processQueue()
        }
    }
    
    /// Queue a rule operation for sync using Sendable primitives
    func queueRule(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(
            type: operation,
            table: "watchlist_rules",
            recordId: id,
            payloadData: payloadData,
            localUpdatedAt: localUpdatedAt
        )
        queue.append(syncOp)
        Self.saveQueueToDisk(queue)
        print("📤 [SyncAgent] Queued rule \(operation): \(id)")
        
        Task {
            await processQueue()
        }
    }
    
    /// Queue a photo operation for sync using Sendable primitives
    func queuePhoto(id: UUID, payloadData: Data?, localUpdatedAt: Date?, operation: SyncOperationType) {
        let syncOp = SyncOperation(
            type: operation,
            table: "observed_bird_photos",
            recordId: id,
            payloadData: payloadData,
            localUpdatedAt: localUpdatedAt
        )
        queue.append(syncOp)
        Self.saveQueueToDisk(queue)
        print("📤 [SyncAgent] Queued photo \(operation): \(id)")
        
        Task {
            await processQueue()
        }
    }
    
    /// Process all pending operations
    func syncAll() async {
        await processQueue()
    }
    
    /// Retry failed operations
    func retryFailed() async {
        let retryableItems = deadLetterQueue.filter { $0.attempts < maxRetries }
        deadLetterQueue.removeAll { $0.attempts < maxRetries }
        Self.saveDeadLetterToDisk(deadLetterQueue)
        queue.append(contentsOf: retryableItems)
        Self.saveQueueToDisk(queue)
        
        print("📤 [SyncAgent] Retrying \(retryableItems.count) failed operations")
        await processQueue()
    }
    
    /// Clear all pending operations (on logout)
    func clearAll() {
        queue.removeAll()
        deadLetterQueue.removeAll()
        Self.saveQueueToDisk(queue)
        Self.saveDeadLetterToDisk(deadLetterQueue)
        print("📤 [SyncAgent] Cleared all pending operations")
    }
    
    public func pendingOperationCount() -> Int {
        return queue.count
    }
    
    public func deadLetterCount() -> Int {
        return deadLetterQueue.count
    }

    // MARK: - Background Tasks

    func registerBackgroundTasks() {
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
            print("📤 [SyncAgent] Failed to schedule background sync: \(error)")
        }
        #endif
    }

    #if os(iOS)
    private func handleBackgroundTask(_ task: BGProcessingTask) async {
        task.expirationHandler = {
            print("📤 [SyncAgent] Background task expired")
        }

        await syncAll()
        task.setTaskCompleted(success: true)
    }
    #endif
    
    // MARK: - Queue Processing
    
    private func processQueue() async {
        print("🔍 [SyncAgent] processQueue called")
        print("🔍 [SyncAgent] isProcessing: \(isProcessing), queue.count: \(queue.count)")
        
        guard !isProcessing, !queue.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Load config if needed
        if config == nil {
            config = try? SupabaseConfig.load()
            print("🔍 [SyncAgent] Loaded config: \(config != nil ? "success" : "failed")")
        }
        
        guard let config else {
            print("📤 [SyncAgent] ❌ ERROR: Supabase config not available")
            return
        }
        
        // Check if authenticated
        let isAuthenticated = await MainActor.run(body: { UserSession.shared.isAuthenticatedWithSupabase() })
        print("🔍 [SyncAgent] isAuthenticated: \(isAuthenticated)")
        
        guard isAuthenticated else {
            print("📤 [SyncAgent] ❌ SKIPPING SYNC - not authenticated")
            return
        }
        
        print("📤 [SyncAgent] Processing \(queue.count) operations")
        
        var processedIndices: [Int] = []
        
        for (index, operation) in queue.enumerated() {
            do {
                // Check for conflicts before processing (server authoritative)
                let shouldProceed = try await checkServerConflict(operation, config: config)
                
                if shouldProceed {
                    try await processOperation(operation, config: config)
                    processedIndices.append(index)
                    print("📤 [SyncAgent] ✓ Synced: \(operation.table) \(operation.recordId)")
                    
                    // After successful delete sync, remove from local SwiftData
                    if operation.type == .delete {
                        await MainActor.run {
                            self.hardDeleteLocalRecord(table: operation.table, recordId: operation.recordId)
                        }
                    }
                } else {
                    // Server has newer data - skip this operation
                    processedIndices.append(index)
                    print("📤 [SyncAgent] ⚠ Skipped (server newer): \(operation.table) \(operation.recordId)")
                }
            } catch {
                var failedOp = operation
                failedOp.attempts += 1
                failedOp.lastError = error.localizedDescription
                
                if failedOp.attempts >= maxRetries {
                    deadLetterQueue.append(failedOp)
                    Self.saveDeadLetterToDisk(deadLetterQueue)
                    print("📤 [SyncAgent] ✗ Max retries reached: \(operation.table) \(operation.recordId)")
                } else {
                    queue[index] = failedOp
                    Self.saveQueueToDisk(queue)
                    print("📤 [SyncAgent] ⚠ Retry \(failedOp.attempts)/\(maxRetries): \(operation.table)")
                }
            }
        }
        
        for index in processedIndices.reversed() {
            queue.remove(at: index)
        }
        Self.saveQueueToDisk(queue)
    }
    
    // MARK: - Conflict Detection (Server Authoritative)
    
    private func checkServerConflict(_ operation: SyncOperation, config: SupabaseConfig) async throws -> Bool {
        // For CREATE operations, no conflict check needed
        if operation.type == .create {
            return true
        }
        
        // For DELETE operations, check if record still exists
        if operation.type == .delete {
            let serverRecord = try await fetchServerRecord(
                table: operation.table,
                recordId: operation.recordId,
                config: config
            )
            
            // If record doesn't exist on server, skip delete
            if serverRecord == nil {
                print("📤 [SyncAgent] Record already deleted on server: \(operation.recordId)")
                return false
            }
            
            // Check if server has already deleted it
            if let deletedAt = serverRecord?["deleted_at"] as? String, !deletedAt.isEmpty {
                print("📤 [SyncAgent] Record already soft-deleted on server: \(operation.recordId)")
                return false
            }
            
            return true
        }
        
        // For UPDATE operations, compare timestamps
        let serverRecord = try await fetchServerRecord(
            table: operation.table,
            recordId: operation.recordId,
            config: config
        )
        
        guard let serverRecord,
              let serverUpdatedAtStr = serverRecord["updated_at"] as? String,
              let serverUpdatedAt = ISO8601DateFormatter().date(from: serverUpdatedAtStr),
              let localUpdatedAt = operation.localUpdatedAt else {
            // Can't compare - proceed with update
            return true
        }
        
        // SERVER IS AUTHORITATIVE - if server is newer, skip update
        if serverUpdatedAt > localUpdatedAt {
            print("📤 [SyncAgent] Conflict: server is newer (\(serverUpdatedAt) > \(localUpdatedAt)), skipping")
            return false
        }
        
        return true
    }
    
    private func fetchServerRecord(
        table: String,
        recordId: UUID,
        config: SupabaseConfig
    ) async throws -> [String: Any]? {
        let token = await MainActor.run { UserSession.shared.getAccessToken() }
        
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        components.path = "/rest/v1/\(table)"
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(recordId.uuidString)"),
            URLQueryItem(name: "select", value: "updated_at,deleted_at")
        ]
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstRecord = jsonArray.first else {
            return nil
        }
        
        return firstRecord
    }
    
    private func processOperation(_ operation: SyncOperation, config: SupabaseConfig) async throws {
        let token = await MainActor.run { UserSession.shared.getAccessToken() }
        
        // Decode payload from Data to [String: Any]
        var payload: [String: Any] = [:]
        if let payloadData = operation.payloadData {
            payload = (try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]) ?? [:]
        }
        
        if operation.table == "observed_bird_photos" && (operation.type == .create || operation.type == .update) {
            try await uploadPhotoIfNeeded(payload: &payload, config: config, token: token)
        }
        
        if operation.table == "observed_bird_photos" && operation.type == .delete {
            try await deletePhotoFromStorage(payload: payload, config: config, token: token)
        }
        
        switch operation.type {
        case .create:
            try await createRecord(
                table: operation.table,
                payload: payload,
                config: config,
                token: token
            )
            
        case .update:
            try await updateRecord(
                table: operation.table,
                recordId: operation.recordId,
                payload: payload,
                config: config,
                token: token
            )
            
        case .delete:
            try await deleteRecord(
                table: operation.table,
                recordId: operation.recordId,
                config: config,
                token: token
            )
        }
    }
    
    // MARK: - HTTP Operations
    
    private func createRecord(
        table: String,
        payload: [String: Any],
        config: SupabaseConfig,
        token: String?
    ) async throws {
        print("🔍 [SyncAgent] createRecord called:")
        print("   - table: \(table)")
        print("   - payload: \(payload)")
        print("   - token: \(token != nil ? "present" : "nil")")
        
        var request = try buildRequest(
            path: "/rest/v1/\(table)",
            method: "POST",
            config: config,
            token: token
        )
        
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("🔍 [SyncAgent] Request URL: \(request.url?.absoluteString ?? "nil")")
        print("🔍 [SyncAgent] Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
        
        try await executeRequest(request)
    }
    
    private func updateRecord(
        table: String,
        recordId: UUID,
        payload: [String: Any],
        config: SupabaseConfig,
        token: String?
    ) async throws {
        var request = try buildRequest(
            path: "/rest/v1/\(table)?id=eq.\(recordId.uuidString)",
            method: "PATCH",
            config: config,
            token: token
        )
        
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        try await executeRequest(request)
    }
    
    private func deleteRecord(
        table: String,
        recordId: UUID,
        config: SupabaseConfig,
        token: String?
    ) async throws {
        // Use soft delete - send PATCH with deleted_at instead of actual DELETE
        let payload: [String: Any] = [
            "deleted_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = try buildRequest(
            path: "/rest/v1/\(table)?id=eq.\(recordId.uuidString)",
            method: "PATCH",
            config: config,
            token: token
        )
        
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        try await executeRequest(request)
    }
    
    private func buildRequest(
        path: String,
        method: String,
        config: SupabaseConfig,
        token: String?
    ) throws -> URLRequest {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Split path and query string properly
        // path might be "/rest/v1/table?query=value" - need to separate query
        let (pathOnly, queryString) = splitPathAndQuery(path)
        components.path = pathOnly
        components.percentEncodedQuery = queryString
        
        guard let url = components.url else {
            throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func splitPathAndQuery(_ raw: String) -> (path: String, query: String?) {
        let cleaned = raw.hasPrefix("/") ? raw : "/" + raw
        guard let index = cleaned.firstIndex(of: "?") else {
            return (cleaned, nil)
        }
        
        let path = String(cleaned[..<index])
        let queryStart = cleaned.index(after: index)
        let query = String(cleaned[queryStart...])
        return (path, query.isEmpty ? nil : query)
    }
    
    /// Hard delete a record from local SwiftData after successful server delete
    @MainActor
    private func hardDeleteLocalRecord(table: String, recordId: UUID) {
        let context = WatchlistManager.shared.context
        
        do {
            switch table {
            case "watchlists":
                let descriptor = FetchDescriptor<Watchlist>(predicate: #Predicate { $0.id == recordId })
                if let watchlist = try context.fetch(descriptor).first {
                    context.delete(watchlist)
                    try context.save()
                    print("🗑️ [SyncAgent] Hard deleted local watchlist: \(recordId)")
                }
                
            case "watchlist_entries":
                let descriptor = FetchDescriptor<WatchlistEntry>(predicate: #Predicate { $0.id == recordId })
                if let entry = try context.fetch(descriptor).first {
                    context.delete(entry)
                    try context.save()
                    print("🗑️ [SyncAgent] Hard deleted local entry: \(recordId)")
                    // Post notification for UI refresh
                    NotificationCenter.default.post(name: WatchlistManager.didLoadDataNotification, object: nil)
                }
                
            case "watchlist_rules":
                let descriptor = FetchDescriptor<WatchlistRule>(predicate: #Predicate { $0.id == recordId })
                if let rule = try context.fetch(descriptor).first {
                    context.delete(rule)
                    try context.save()
                    print("🗑️ [SyncAgent] Hard deleted local rule: \(recordId)")
                }
                
            case "observed_bird_photos":
                let descriptor = FetchDescriptor<ObservedBirdPhoto>(predicate: #Predicate { $0.id == recordId })
                if let photo = try context.fetch(descriptor).first {
                    context.delete(photo)
                    try context.save()
                    print("🗑️ [SyncAgent] Hard deleted local photo: \(recordId)")
                }
                
            default:
                print("⚠️ [SyncAgent] Unknown table for hard delete: \(table)")
            }
        } catch {
            print("❌ [SyncAgent] Failed to hard delete local \(table): \(error)")
        }
    }
    
    private func executeRequest(_ request: URLRequest) async throws {
        print("🔍 [SyncAgent] executeRequest called:")
        print("   - URL: \(request.url?.absoluteString ?? "nil")")
        print("   - Method: \(request.httpMethod ?? "nil")")
        print("   - Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔍 [SyncAgent] ❌ Invalid response (not HTTPURLResponse)")
            throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("🔍 [SyncAgent] Response status code: \(httpResponse.statusCode)")
        print("🔍 [SyncAgent] Response headers: \(httpResponse.allHeaderFields)")
        
        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        print("🔍 [SyncAgent] Response body: \(responseBody)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("🔍 [SyncAgent] ❌ HTTP ERROR \(httpResponse.statusCode): \(message)")
            throw NSError(
                domain: "SyncAgent",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        
        print("🔍 [SyncAgent] ✅ Request successful")
    }
}
//
//  BackgroundSyncAgent+Photo.swift
//  SkyTrails
//
//  Photo upload and deletion extension for BackgroundSyncAgent
//

import Foundation
import SwiftData

extension BackgroundSyncAgent {
    
    func uploadPhotoIfNeeded(payload: inout [String: Any], config: SupabaseConfig, token: String?) async throws {
        guard let isUploaded = payload["is_uploaded"] as? Bool, !isUploaded else {
            return // Already uploaded
        }
        
        guard let imagePath = payload["image_path"] as? String else {
            return
        }
        
        // Get local file URL
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "SyncAgent", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not access documents directory"])
        }
        
        let fileURL = documentsURL.appendingPathComponent("ObservedBirdPhotos", isDirectory: true).appendingPathComponent(imagePath)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "SyncAgent", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local photo file not found: \(imagePath)"])
        }
        
        let data = try Data(contentsOf: fileURL)
        
        // Use userId for path scoping if available, else just use the image filename
        let userIdStr = await MainActor.run { UserSession.shared.currentUserID?.uuidString ?? "guest" }
        let storagePath = "\(userIdStr)/\(imagePath)"
        
        // Upload to Supabase Storage
        let storageURLStr = try await uploadToStorage(path: storagePath, data: data, config: config, token: token)
        
        // Update payload
        payload["storage_url"] = storageURLStr
        payload["is_uploaded"] = true
        
        // Also update local DB entity on main thread
        if let idStr = payload["id"] as? String, let id = UUID(uuidString: idStr) {
            await MainActor.run {
                do {
                    // Assuming we have access to ModelContext or can post a notification
                    // We'll post a notification to update the local entity to avoid passing ModelContext to BackgroundSyncAgent
                    NotificationCenter.default.post(
                        name: NSNotification.Name("DidUploadPhoto"),
                        object: nil,
                        userInfo: ["id": id, "storageUrl": storageURLStr]
                    )
                }
            }
        }
    }
    
    func deletePhotoFromStorage(payload: [String: Any]?, config: SupabaseConfig, token: String?) async throws {
        guard let payload = payload,
              let isUploaded = payload["is_uploaded"] as? Bool, isUploaded,
              let storageUrlStr = payload["storage_url"] as? String else {
            return
        }
        
        // Extract path from storage URL. 
        // URL format is typically: https://[project_ref].supabase.co/storage/v1/object/public/photos/[userId]/[filename]
        // or we can just parse it
        guard let storageUrl = URL(string: storageUrlStr),
              storageUrl.pathComponents.contains("photos") else {
            return
        }
        
        // Find index of "photos" and get the rest
        if let index = storageUrl.pathComponents.firstIndex(of: "photos") {
            let relativePathComponents = storageUrl.pathComponents.suffix(from: index + 1)
            let storagePath = relativePathComponents.joined(separator: "/")
            
            try await deleteFromStorage(path: storagePath, config: config, token: token)
        }
    }
    
    private func uploadToStorage(path: String, data: Data, config: SupabaseConfig, token: String?) async throws -> String {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // /storage/v1/object/photos/{path}
        components.path = "/storage/v1/object/photos/\(path)"
        
        guard let url = components.url else {
            throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // Could be PUT to overwrite, but POST is fine if filenames are UUIDs
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (responseData, response) = try await URLSession.shared.upload(for: request, from: data)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode == 400 || httpResponse.statusCode == 409 {
            // Might already exist, try to get the URL anyway
            // Could also try PUT if we need to overwrite
            print("📤 [SyncAgent] Photo upload returned \(httpResponse.statusCode), proceeding as if successful")
        } else if !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "SyncAgent",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        
        // Return public URL or signed URL. Assuming public bucket "photos"
        let publicUrl = config.projectURL.appendingPathComponent("storage/v1/object/public/photos/\(path)").absoluteString
        return publicUrl
    }
    
    private func deleteFromStorage(path: String, config: SupabaseConfig, token: String?) async throws {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        components.path = "/storage/v1/object/photos/\(path)"
        
        guard let url = components.url else {
            throw NSError(domain: "SyncAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            print("📤 [SyncAgent] Failed to delete photo from storage: \(message)")
        }
    }
}
