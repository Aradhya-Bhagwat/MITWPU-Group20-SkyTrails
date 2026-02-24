//
//  WatchlistPersistenceService.swift
//  SkyTrails
//
//  Pure CRUD operations on SwiftData - NO business logic
//  Strict MVC Refactoring
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
final class WatchlistPersistenceService {
    
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }

    private var activeUserID: UUID? {
        UserSession.shared.currentUserID
    }

    private func isWatchlistAccessible(_ watchlist: Watchlist) -> Bool {
        // Guest (not logged in): only see nil owner_id (own guest-created watchlists)
        // Logged in: only see own watchlists OR shared watchlists
        guard let userID = activeUserID else {
            return watchlist.owner_id == nil
        }
        
        return watchlist.owner_id == userID || watchlist.type == .shared
    }

    private func scoped(_ watchlists: [Watchlist]) -> [Watchlist] {
        watchlists.filter { isWatchlistAccessible($0) }
    }
    
    // MARK: - Sync Helper
    
    /// Fire-and-forget sync to Supabase (only if authenticated)
    private func queueSync(_ operation: @escaping @Sendable () async -> Void) {
        print("🔍 [Persistence] queueSync called, activeUserID: \(activeUserID?.uuidString ?? "nil")")
        
        guard activeUserID != nil else {
            print("🔍 [Persistence] ❌ SKIPPING SYNC - no activeUserID (user not authenticated)")
            return
        }
        
        print("🔍 [Persistence] ✅ Proceeding with sync, launching Task.detached")
        Task.detached(priority: .utility) {
            print("🔍 [Persistence] Inside Task.detached, executing operation")
            await operation()
        }
    }
    
    // MARK: - Watchlist CRUD
    
    func createWatchlist(
        title: String,
        location: String?,
        locationDisplayName: String?,
        startDate: Date?,
        endDate: Date?,
        type: WatchlistType = .custom
    ) throws -> Watchlist {
        print("🔍 [Persistence] createWatchlist called:")
        print("   - title: \(title)")
        print("   - activeUserID: \(activeUserID?.uuidString ?? "nil")")
        print("   - isAuthenticated: \(UserSession.shared.isAuthenticatedWithSupabase())")
        
        let watchlist = Watchlist(
            owner_id: activeUserID,
            title: title,
            location: location,
            locationDisplayName: locationDisplayName,
            startDate: startDate,
            endDate: endDate
        )
        watchlist.type = type
        
        print("🔍 [Persistence] Created watchlist with id: \(watchlist.id)")
        print("   - owner_id: \(watchlist.owner_id?.uuidString ?? "nil")")
        
        context.insert(watchlist)
        try saveContext()
        print("🔍 [Persistence] SwiftData context saved successfully")
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let watchlistId = watchlist.id
        let payloadData = buildWatchlistPayloadData(watchlist, for: .create)
        let updatedAt = watchlist.updated_at
        
        print("🔍 [Persistence] Payload data: \(payloadData != nil ? "present (\(payloadData!.count) bytes)" : "nil")")
        
        queueSync {
            print("🔍 [Persistence] Inside queueSync closure, calling BackgroundSyncAgent.queueWatchlist")
            await BackgroundSyncAgent.shared.queueWatchlist(
                id: watchlistId,
                payloadData: payloadData,
                updatedAt: updatedAt,
                operation: .create
            )
        }
        
        return watchlist
    }
    
    func fetchWatchlist(id: UUID) throws -> Watchlist? {
        let descriptor = FetchDescriptor<Watchlist>(
            predicate: #Predicate { $0.id == id }
        )
        guard let watchlist = try context.fetch(descriptor).first else { return nil }
        return isWatchlistAccessible(watchlist) ? watchlist : nil
    }
    
    func fetchWatchlists(type: WatchlistType? = nil) throws -> [Watchlist] {
        let descriptor = FetchDescriptor<Watchlist>(
            sortBy: [SortDescriptor(\.created_at, order: .reverse)]
        )
        
        // Note: SwiftData enum predicates are limited, filter post-fetch if type is specified
        let all = scoped(try context.fetch(descriptor))
        
        if let type = type {
            return all.filter { $0.type == type }
        }
        return all
    }
    
    func updateWatchlist(
        id: UUID,
        title: String?,
        location: String?,
        locationDisplayName: String?,
        startDate: Date?,
        endDate: Date?
    ) throws {
        guard let watchlist = try fetchWatchlist(id: id) else {
            throw WatchlistError.watchlistNotFound(.custom(id))
        }
        
        if let title = title { watchlist.title = title }
        if let location = location { watchlist.location = location }
        if let locationDisplayName = locationDisplayName { watchlist.locationDisplayName = locationDisplayName }
        if let startDate = startDate { watchlist.startDate = startDate }
        if let endDate = endDate { watchlist.endDate = endDate }
        
        watchlist.updated_at = Date()
        watchlist.syncStatus = .pendingUpdate
        try saveContext()
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let watchlistId = watchlist.id
        let payloadData = buildWatchlistPayloadData(watchlist, for: .update)
        let updatedAt = watchlist.updated_at
        
        queueSync {
            await BackgroundSyncAgent.shared.queueWatchlist(
                id: watchlistId,
                payloadData: payloadData,
                updatedAt: updatedAt,
                operation: .update
            )
        }
    }
    
    func deleteWatchlist(id: UUID) throws {
        let descriptor = FetchDescriptor<Watchlist>(
            predicate: #Predicate { $0.id == id }
        )
        guard let watchlist = try context.fetch(descriptor).first, isWatchlistAccessible(watchlist) else {
            throw WatchlistError.watchlistNotFound(.custom(id))
        }
        
        // Soft delete - mark for sync deletion
        watchlist.deleted_at = Date()
        watchlist.syncStatus = .pendingDelete
        try saveContext()
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let watchlistId = watchlist.id
        let payloadData = buildWatchlistPayloadData(watchlist, for: .delete)
        let updatedAt = watchlist.updated_at
        
        queueSync {
            await BackgroundSyncAgent.shared.queueWatchlist(
                id: watchlistId,
                payloadData: payloadData,
                updatedAt: updatedAt,
                operation: .delete
            )
        }
    }
    
    func updateWatchlistStats(id: UUID, observedCount: Int, speciesCount: Int) throws {
        guard let watchlist = try fetchWatchlist(id: id) else {
            throw WatchlistError.watchlistNotFound(.custom(id))
        }
        
        watchlist.observedCount = observedCount
        watchlist.speciesCount = speciesCount
        watchlist.updated_at = Date()
        try saveContext()
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let watchlistId = watchlist.id
        let payloadData = buildWatchlistPayloadData(watchlist, for: .update)
        let updatedAt = watchlist.updated_at
        
        queueSync {
            await BackgroundSyncAgent.shared.queueWatchlist(
                id: watchlistId,
                payloadData: payloadData,
                updatedAt: updatedAt,
                operation: .update
            )
        }
    }
    
    // MARK: - Entry CRUD
    
    func createEntry(
        watchlistID: UUID,
        bird: Bird,
        status: WatchlistEntryStatus,
        notes: String? = nil,
        observationDate: Date? = nil,
        toObserveStartDate: Date? = nil,
        toObserveEndDate: Date? = nil
    ) throws -> WatchlistEntry {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        let entry = WatchlistEntry(
            watchlist: watchlist,
            bird: bird,
            status: status,
            notes: notes,
            observationDate: observationDate
        )
        entry.toObserveStartDate = toObserveStartDate
        entry.toObserveEndDate = toObserveEndDate
        
        if status == .observed && observationDate == nil {
            entry.observationDate = Date()
        }
        
        context.insert(entry)
        try saveContext()
        
        // Update watchlist stats
        try recalculateWatchlistStats(watchlistID: watchlistID)
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let entryId = entry.id
        let payloadData = buildEntryPayloadData(entry, for: .create)
        let localUpdatedAt = entry.observationDate ?? entry.addedDate
        
        queueSync {
            await BackgroundSyncAgent.shared.queueEntry(
                id: entryId,
                payloadData: payloadData,
                localUpdatedAt: localUpdatedAt,
                operation: .create
            )
        }
        
        return entry
    }
    
    func fetchEntry(id: UUID) throws -> WatchlistEntry? {
        let descriptor = FetchDescriptor<WatchlistEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchEntries(watchlistID: UUID, status: WatchlistEntryStatus? = nil) throws -> [WatchlistEntry] {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        var entries = watchlist.entries ?? []
        
        if let status = status {
            entries = entries.filter { $0.status == status }
        }
        
        return entries.sorted { $0.addedDate < $1.addedDate }
    }
    
    func fetchAllEntries() throws -> [WatchlistEntry] {
        return try fetchWatchlists()
            .flatMap { $0.entries ?? [] }
            .sorted { $0.addedDate < $1.addedDate }
    }
    
    func updateEntry(
        id: UUID,
        notes: String?,
        observationDate: Date?,
        lat: Double?,
        lon: Double?,
        locationDisplayName: String?,
        toObserveStartDate: Date?,
        toObserveEndDate: Date?
    ) throws {
        guard let entry = try fetchEntry(id: id) else {
            throw WatchlistError.entryNotFound(id)
        }
        
        entry.notes = notes
        entry.observationDate = observationDate
        entry.lat = lat
        entry.lon = lon
        entry.locationDisplayName = locationDisplayName
        entry.toObserveStartDate = toObserveStartDate
        entry.toObserveEndDate = toObserveEndDate
        entry.syncStatus = .pendingUpdate
        
        try saveContext()
        
        // Update parent watchlist stats
        if let watchlistID = entry.watchlist?.id {
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let entryId = entry.id
        let payloadData = buildEntryPayloadData(entry, for: .update)
        let localUpdatedAt = entry.observationDate ?? entry.addedDate
        
        queueSync {
            await BackgroundSyncAgent.shared.queueEntry(
                id: entryId,
                payloadData: payloadData,
                localUpdatedAt: localUpdatedAt,
                operation: .update
            )
        }
    }
    
    func deleteEntry(id: UUID) throws {
        let descriptor = FetchDescriptor<WatchlistEntry>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entry = try context.fetch(descriptor).first else {
            throw WatchlistError.entryNotFound(id)
        }
        
        // Soft delete - mark for sync deletion
        entry.syncStatus = .pendingDelete
        try saveContext()
        
        // Update parent watchlist stats
        if let watchlistID = entry.watchlist?.id {
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let entryId = entry.id
        let payloadData = buildEntryPayloadData(entry, for: .delete)
        let localUpdatedAt = entry.observationDate ?? entry.addedDate
        
        queueSync {
            await BackgroundSyncAgent.shared.queueEntry(
                id: entryId,
                payloadData: payloadData,
                localUpdatedAt: localUpdatedAt,
                operation: .delete
            )
        }
    }
    
    func toggleEntryStatus(id: UUID) throws {
        guard let entry = try fetchEntry(id: id) else {
            throw WatchlistError.entryNotFound(id)
        }
        
        entry.status = (entry.status == .observed) ? .to_observe : .observed
        entry.observationDate = (entry.status == .observed) ? Date() : nil
        entry.syncStatus = .pendingUpdate
        
        try saveContext()
        
        // Update parent watchlist stats
        if let watchlistID = entry.watchlist?.id {
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let entryId = entry.id
        let payloadData = buildEntryPayloadData(entry, for: .update)
        let localUpdatedAt = entry.observationDate ?? entry.addedDate
        
        queueSync {
            await BackgroundSyncAgent.shared.queueEntry(
                id: entryId,
                payloadData: payloadData,
                localUpdatedAt: localUpdatedAt,
                operation: .update
            )
        }
    }
    
    func addBirdsToWatchlist(
        watchlistID: UUID,
        birds: [Bird],
        status: WatchlistEntryStatus
    ) throws -> [WatchlistEntry] {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        let existingBirdIDs = Set((watchlist.entries ?? []).compactMap { $0.bird?.id })
        var createdEntries: [WatchlistEntry] = []
        
        for bird in birds {
            // Skip if already exists
            guard !existingBirdIDs.contains(bird.id) else {
                continue
            }
            
            let entry = WatchlistEntry(
                watchlist: watchlist,
                bird: bird,
                status: status
            )
            
            if status == .observed {
                entry.observationDate = Date()
            }
            
            context.insert(entry)
            createdEntries.append(entry)
        }
        
        if !createdEntries.isEmpty {
            try saveContext()
            try recalculateWatchlistStats(watchlistID: watchlistID)
            
            // Queue sync for all created entries - extract Sendable primitives before crossing actor boundary
            let entrySyncItems = createdEntries.map { entry -> (id: UUID, payloadData: Data?, localUpdatedAt: Date?) in
                (entry.id, buildEntryPayloadData(entry, for: .create), entry.observationDate ?? entry.addedDate)
            }
            queueSync {
                for item in entrySyncItems {
                    await BackgroundSyncAgent.shared.queueEntry(
                        id: item.id,
                        payloadData: item.payloadData,
                        localUpdatedAt: item.localUpdatedAt,
                        operation: .create
                    )
                }
            }
        }
        
        return createdEntries
    }
    
    // MARK: - Rule CRUD
    
    func createRule(
        watchlistID: UUID,
        type: WatchlistRuleType,
        parameters: RuleParameters,
        priority: Int = 0,
        isActive: Bool = true
    ) throws -> WatchlistRule {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        let rule = WatchlistRule(
            watchlist: watchlist,
            rule_type: type,
            parameters: parameters.jsonString
        )
        rule.priority = priority
        rule.is_active = isActive
        
        context.insert(rule)
        try saveContext()
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let ruleId = rule.id
        let payloadData = buildRulePayloadData(rule, for: .create)
        let localUpdatedAt = rule.created_at
        
        queueSync {
            await BackgroundSyncAgent.shared.queueRule(
                id: ruleId,
                payloadData: payloadData,
                localUpdatedAt: localUpdatedAt,
                operation: .create
            )
        }
        
        return rule
    }
    
    func fetchRules(watchlistID: UUID, activeOnly: Bool = false) throws -> [WatchlistRule] {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        var rules = watchlist.rules ?? []
        
        if activeOnly {
            rules = rules.filter { $0.is_active }
        }
        
        return rules.sorted { $0.priority > $1.priority }
    }
    
    func toggleRule(id: UUID) throws {
        let descriptor = FetchDescriptor<WatchlistRule>(
            predicate: #Predicate { $0.id == id }
        )
        guard let rule = try context.fetch(descriptor).first else {
            throw WatchlistError.ruleValidationFailed("Rule not found")
        }
        
        rule.is_active = !rule.is_active
        rule.syncStatus = .pendingUpdate
        try saveContext()
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let ruleId = rule.id
        let payloadData = buildRulePayloadData(rule, for: .update)
        let localUpdatedAt = rule.created_at
        
        queueSync {
            await BackgroundSyncAgent.shared.queueRule(
                id: ruleId,
                payloadData: payloadData,
                localUpdatedAt: localUpdatedAt,
                operation: .update
            )
        }
    }
    
    func deleteRule(id: UUID) throws {
        let descriptor = FetchDescriptor<WatchlistRule>(
            predicate: #Predicate { $0.id == id }
        )
        guard let rule = try context.fetch(descriptor).first else {
            throw WatchlistError.ruleValidationFailed("Rule not found")
        }
        
        // Soft delete
        rule.syncStatus = .pendingDelete
        rule.deleted_at = Date()
        try saveContext()
        
        // Queue sync - extract Sendable primitives before crossing actor boundary
        let ruleId = rule.id
        let payloadData = buildRulePayloadData(rule, for: .delete)
        let localUpdatedAt = rule.created_at
        
        queueSync {
            await BackgroundSyncAgent.shared.queueRule(
                id: ruleId,
                payloadData: payloadData,
                localUpdatedAt: localUpdatedAt,
                operation: .delete
            )
        }
    }
    
    // MARK: - Bird CRUD
    
    func fetchBird(id: UUID) throws -> Bird? {
        let descriptor = FetchDescriptor<Bird>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchBird(byCommonName name: String) throws -> Bird? {
        let descriptor = FetchDescriptor<Bird>(
            predicate: #Predicate { $0.commonName == name }
        )
        return try context.fetch(descriptor).first
    }
    
    func fetchAllBirds() throws -> [Bird] {
        let descriptor = FetchDescriptor<Bird>()
        return try context.fetch(descriptor)
    }

    func bindWatchlistsToCurrentUser() throws -> Int {
        guard let userID = activeUserID else { return 0 }

        let descriptor = FetchDescriptor<Watchlist>()
        let allWatchlists = try context.fetch(descriptor)

        var changed = false
        var adoptedCount = 0
        for watchlist in allWatchlists where watchlist.type != .shared {
            if watchlist.owner_id == nil || watchlist.owner_id == WatchlistConstants.legacyDefaultOwnerID {
                watchlist.owner_id = userID
                watchlist.syncStatus = .pendingUpdate
                changed = true
                adoptedCount += 1
            }
        }

        // Adopt entries, rules, and photos
        for watchlist in allWatchlists where watchlist.owner_id == userID {
            // Adopt entries
            for entry in watchlist.entries ?? [] {
                if entry.syncStatus == .pendingOwner || entry.syncStatus == .pendingCreate {
                    entry.syncStatus = .pendingUpdate
                }
            }
            
            // Adopt rules
            for rule in watchlist.rules ?? [] {
                if rule.syncStatus == .pendingOwner || rule.syncStatus == .pendingCreate {
                    rule.syncStatus = .pendingUpdate
                }
            }
            
            // Adopt photos
            for entry in watchlist.entries ?? [] {
                for photo in entry.photos ?? [] {
                    if photo.syncStatus == .pendingOwner || photo.syncStatus == .pendingCreate {
                        photo.syncStatus = .pendingUpdate
                    }
                }
            }
        }

        if changed {
            try saveContext()
            
            // Sync all adopted items
            queueSync {
                await BackgroundSyncAgent.shared.syncAll()
            }
        }

        return adoptedCount
    }
    
    func createBird(
        commonName: String,
        scientificName: String = "Unknown",
        staticImageName: String = "photo",
    ) throws -> Bird {
        // Check for duplicate
        if try fetchBird(byCommonName: commonName) != nil {
            throw WatchlistError.duplicateEntry(birdName: commonName)
        }
        
        let bird = Bird(
            id: UUID(),
            commonName: commonName,
            scientificName: scientificName,
            staticImageName: staticImageName,
            validLocations: []
        )
        
        context.insert(bird)
        try saveContext()
        
        return bird
    }
    
    // MARK: - Private Helpers
    
    private func saveContext() throws {
        do {
            try context.save()
        } catch {
            throw WatchlistError.persistenceFailed(underlying: error)
        }
    }
    
    private func recalculateWatchlistStats(watchlistID: UUID) throws {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else { return }
        
        let entries = watchlist.entries ?? []
        let observedCount = entries.filter { $0.status == .observed }.count
        let totalCount = entries.count
        
        watchlist.observedCount = observedCount
        watchlist.speciesCount = totalCount
        watchlist.updated_at = Date()
        
        try saveContext()
    }
    
    // MARK: - Payload Builders (for Sendable extraction)
    
    private func buildWatchlistPayloadData(_ watchlist: Watchlist, for operation: SyncOperationType) -> Data? {
        var payload: [String: Any] = [
            "id": watchlist.id.uuidString,
            "owner_id": watchlist.owner_id?.uuidString as Any,
            "type": watchlist.type?.rawValue ?? "custom",
            "title": watchlist.title as Any,
            "location": watchlist.location as Any,
            "location_display_name": watchlist.locationDisplayName as Any,
            "observed_count": watchlist.observedCount,
            "species_count": watchlist.speciesCount,
            "cover_image_path": watchlist.coverImagePath as Any,
            "species_rule_enabled": watchlist.speciesRuleEnabled,
            "species_rule_shape_id": watchlist.speciesRuleShapeId as Any,
            "location_rule_enabled": watchlist.locationRuleEnabled,
            "location_rule_lat": watchlist.locationRuleLat as Any,
            "location_rule_lon": watchlist.locationRuleLon as Any,
            "location_rule_radius_km": watchlist.locationRuleRadiusKm,
            "location_rule_display_name": watchlist.locationRuleDisplayName as Any,
            "date_rule_enabled": watchlist.dateRuleEnabled,
            "date_rule_start_date": watchlist.dateRuleStartDate.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "date_rule_end_date": watchlist.dateRuleEndDate.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "sync_status": watchlist.syncStatusRaw,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if operation == .delete {
            payload["deleted_at"] = ISO8601DateFormatter().string(from: Date())
        }
        
        return try? JSONSerialization.data(withJSONObject: payload)
    }
    
    private func buildEntryPayloadData(_ entry: WatchlistEntry, for operation: SyncOperationType) -> Data? {
        var payload: [String: Any] = [
            "id": entry.id.uuidString,
            "watchlist_id": entry.watchlist?.id.uuidString as Any,
            "bird_id": entry.bird?.id.uuidString as Any,
            "nickname": entry.nickname as Any,
            "status": entry.status.rawValue,
            "notes": entry.notes as Any,
            "observation_date": entry.observationDate.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "to_observe_start_date": entry.toObserveStartDate.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "to_observe_end_date": entry.toObserveEndDate.map { ISO8601DateFormatter().string(from: $0) } as Any,
            "observed_by": entry.observedBy as Any,
            "lat": entry.lat as Any,
            "lon": entry.lon as Any,
            "location_display_name": entry.locationDisplayName as Any,
            "priority": entry.priority,
            "notify_upcoming": entry.notify_upcoming,
            "target_date_range": entry.target_date_range as Any,
            "sync_status": entry.syncStatusRaw,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if operation == .delete {
            payload["deleted_at"] = ISO8601DateFormatter().string(from: Date())
        }
        
        return try? JSONSerialization.data(withJSONObject: payload)
    }
    
    private func buildRulePayloadData(_ rule: WatchlistRule, for operation: SyncOperationType) -> Data? {
        var payload: [String: Any] = [
            "id": rule.id.uuidString,
            "watchlist_id": rule.watchlist?.id.uuidString as Any,
            "rule_type": rule.rule_type.rawValue,
            "parameters_json": rule.parameters_json,
            "is_active": rule.is_active,
            "priority": rule.priority,
            "sync_status": rule.syncStatusRaw,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if operation == .delete {
            payload["deleted_at"] = ISO8601DateFormatter().string(from: Date())
        }
        
        return try? JSONSerialization.data(withJSONObject: payload)
    }
}
