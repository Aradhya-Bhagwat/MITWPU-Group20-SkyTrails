
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
        guard let userID = activeUserID else {
            return watchlist.user_id == nil
        }
        
        return watchlist.user_id == userID || watchlist.type == .shared
    }

    private func scoped(_ watchlists: [Watchlist]) -> [Watchlist] {
        watchlists.filter {
            isWatchlistAccessible($0)
                && $0.deleted_at == nil
                && $0.syncStatus != .pendingDelete
        }
    }
    private func queueSync(_ operation: @escaping @Sendable () async -> Void) {
        guard activeUserID != nil else {
            return
        }
        Task.detached(priority: .utility) {
            await operation()
        }
    }

    private func iso8601String(from date: Date?) -> String? {
        guard let date else { return nil }
        return ISO8601DateFormatter().string(from: date)
    }

    private func serializePayload(_ payload: [String: Any], context: String) -> Data? {
        do {
            return try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("WatchlistPersistenceService failed to serialize \(context): \(error.localizedDescription)")
            return nil
        }
    }
    
    func createWatchlist(
        title: String,
        location: String?,
        locationDisplayName: String?,
        startDate: Date?,
        endDate: Date?,
        type: WatchlistType = .custom
    ) throws -> Watchlist {
        let userID = activeUserID ?? UserSession.shared.currentUser?.user_id
        let watchlist = Watchlist(
            user_id: userID,
            title: title,
            location: location,
            locationDisplayName: locationDisplayName,
            startDate: startDate,
            endDate: endDate
        )
        watchlist.type = type
        context.insert(watchlist)
        try saveContext()
        let watchlistId = watchlist.watchlist_id
        let payloadData = buildWatchlistPayloadData(watchlist, for: .create)
        let updatedAt = watchlist.updated_at
        queueSync {
            await BackgroundSyncAgent.shared.queueWatchlist(
                id: watchlistId,
                payloadData: payloadData,
                updated_at: updatedAt,
                operation: .create
            )
        }
        
        return watchlist
    }
    
    func fetchWatchlist(id: UUID) throws -> Watchlist? {
        let descriptor = FetchDescriptor<Watchlist>(
            predicate: #Predicate { $0.watchlist_id == id }
        )
        guard let watchlist = try context.fetch(descriptor).first else { return nil }
        return scoped([watchlist]).first
    }
    
    func fetchWatchlists(type: WatchlistType? = nil) throws -> [Watchlist] {
        let descriptor = FetchDescriptor<Watchlist>(
            sortBy: [SortDescriptor(\.created_at, order: .reverse)]
        )
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
        let watchlistId = watchlist.watchlist_id
        let payloadData = buildWatchlistPayloadData(watchlist, for: .update)
        let updatedAt = watchlist.updated_at
        
        queueSync {
            await BackgroundSyncAgent.shared.queueWatchlist(
                id: watchlistId,
                payloadData: payloadData,
                updated_at: updatedAt,
                operation: .update
            )
        }
    }
    
    func deleteWatchlist(id: UUID) throws {
        let descriptor = FetchDescriptor<Watchlist>(
            predicate: #Predicate { $0.watchlist_id == id }
        )
        guard let watchlist = try context.fetch(descriptor).first, isWatchlistAccessible(watchlist) else {
            throw WatchlistError.watchlistNotFound(.custom(id))
        }
        watchlist.deleted_at = Date()
        watchlist.syncStatus = .pendingDelete
        try saveContext()
        let watchlistId = watchlist.watchlist_id
        let payloadData = buildWatchlistPayloadData(watchlist, for: .delete)
        let updatedAt = watchlist.updated_at
        
        queueSync {
            await BackgroundSyncAgent.shared.queueWatchlist(
                id: watchlistId,
                payloadData: payloadData,
                updated_at: updatedAt,
                operation: .delete
            )
        }
    }
    
    func clearWatchlist(id: UUID) throws {
        guard let watchlist = try fetchWatchlist(id: id) else {
            throw WatchlistError.watchlistNotFound(.custom(id))
        }
        
        let entries = watchlist.entries ?? []
        for entry in entries {
            entry.syncStatus = .pendingDelete
        }
        
        try saveContext()
        try recalculateWatchlistStats(watchlistID: id)

        let syncItems = entries.map { entry in
            (id: entry.id, payload: self.buildEntryPayloadData(entry, for: .delete))
        }

        // Sync each entry deletion
        queueSync {
            for item in syncItems {
                let localUpdatedAt = Date()
                await BackgroundSyncAgent.shared.queueEntry(
                    id: item.id,
                    payloadData: item.payload,
                    localUpdatedAt: localUpdatedAt,
                    operation: .delete
                )
            }
        }
    }
    
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
        
        let userID = activeUserID ?? UserSession.shared.currentUser?.user_id
        let entry = WatchlistEntry(
            watchlist: watchlist,
            bird: bird,
            status: status,
            notes: notes,
            observationDate: observationDate,
            observedByUserId: (status == .observed) ? userID : nil
        )
        entry.toObserveStartDate = toObserveStartDate
        entry.toObserveEndDate = toObserveEndDate
        
        if status == .observed && observationDate == nil {
            entry.observationDate = Date()
        }
        
        context.insert(entry)
        try saveContext()
        try recalculateWatchlistStats(watchlistID: watchlistID)
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
        var entries = (watchlist.entries ?? []).filter { $0.syncStatus != .pendingDelete }
        
        if let status = status {
            entries = entries.filter { $0.status == status }
        }
        
        return entries.sorted { $0.addedDate < $1.addedDate }
    }
    
    func fetchAllEntries() throws -> [WatchlistEntry] {
        return try fetchWatchlists()
            .flatMap { ($0.entries ?? []).filter { $0.syncStatus != .pendingDelete } }
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
        if entry.status == .observed {
            entry.observedByUserId = activeUserID
        }
        entry.syncStatus = .pendingUpdate
        
        try saveContext()
        if let watchlistID = entry.watchlist?.watchlist_id {
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
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
        entry.syncStatus = .pendingDelete
        try saveContext()
        if let watchlistID = entry.watchlist?.watchlist_id {
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
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
        
        let wasToObserve = entry.status == .to_observe
        let hadRemindersEnabled = entry.notify_upcoming
        if wasToObserve && hadRemindersEnabled {
            Task {
                await NotificationService.shared.cancelReminders(for: entry.id)
            }
            entry.notify_upcoming = false
        }
        
        entry.status = (entry.status == .observed) ? .to_observe : .observed
        entry.observationDate = (entry.status == .observed) ? Date() : nil
        entry.observedByUserId = (entry.status == .observed) ? activeUserID : nil
        entry.syncStatus = .pendingUpdate
        
        try saveContext()
        if let watchlistID = entry.watchlist?.watchlist_id {
            try recalculateWatchlistStats(watchlistID: watchlistID)
        }
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
    
    func updateEntryNotifyUpcoming(id: UUID, notify: Bool) throws {
        guard let entry = try fetchEntry(id: id) else {
            throw WatchlistError.entryNotFound(id)
        }
        
        entry.notify_upcoming = notify
        entry.syncStatus = .pendingUpdate
        
        try saveContext()
        if notify {
            Task {
                await NotificationService.shared.scheduleReminders(for: entry)
            }
        } else {
            Task {
                await NotificationService.shared.cancelReminders(for: entry.id)
            }
        }
        let entryId = entry.id
        let payloadData = buildEntryPayloadData(entry, for: .update)
        let localUpdatedAt = entry.addedDate
        
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
        
        let userID = activeUserID ?? UserSession.shared.currentUser?.user_id
        let existingBirdIDs = Set((watchlist.entries ?? []).compactMap { $0.bird?.bird_id })
        var createdEntries: [WatchlistEntry] = []
        
        for bird in birds {
            guard !existingBirdIDs.contains(bird.bird_id) else {
                continue
            }
            
            let entry = WatchlistEntry(
                watchlist: watchlist,
                bird: bird,
                status: status,
                observedByUserId: (status == .observed) ? userID : nil
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
            rule_type: type
        )
        parameters.apply(to: rule)
        rule.priority = priority
        rule.is_active = isActive
        
        context.insert(rule)
        try saveContext()
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
    
    func upsertRule(
        watchlistID: UUID,
        type: WatchlistRuleType,
        parameters: RuleParameters,
        isActive: Bool = true,
        priority: Int = 0
    ) throws {
        let existingRule = try fetchRules(watchlistID: watchlistID).first {
            $0.rule_type == type && $0.deleted_at == nil
        }
        
        if let existingRule {
            parameters.apply(to: existingRule)
            existingRule.priority = priority
            existingRule.is_active = isActive
            existingRule.syncStatus = .pendingUpdate
            existingRule.deleted_at = nil
            try saveContext()
            
            let ruleId = existingRule.id
            let payloadData = buildRulePayloadData(existingRule, for: .update)
            let localUpdatedAt = existingRule.created_at
            queueSync {
                await BackgroundSyncAgent.shared.queueRule(
                    id: ruleId,
                    payloadData: payloadData,
                    localUpdatedAt: localUpdatedAt,
                    operation: .update
                )
            }
        } else {
            _ = try createRule(
                watchlistID: watchlistID,
                type: type,
                parameters: parameters,
                priority: priority,
                isActive: isActive
            )
        }
    }
    
    func fetchRules(watchlistID: UUID, activeOnly: Bool = false) throws -> [WatchlistRule] {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else {
            throw WatchlistError.watchlistNotFound(.custom(watchlistID))
        }
        
        var rules = watchlist.rules ?? []
        rules = rules.filter { $0.deleted_at == nil }
        
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
        rule.syncStatus = .pendingDelete
        rule.deleted_at = Date()
        try saveContext()
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
    
    func deleteRule(watchlistID: UUID, type: WatchlistRuleType) throws {
        let rules = try fetchRules(watchlistID: watchlistID)
        guard let rule = rules.first(where: { $0.rule_type == type && $0.deleted_at == nil }) else {
            return
        }
        try deleteRule(id: rule.id)
    }
    
    func fetchBird(bird_id: UUID) throws -> Bird? {
        let descriptor = FetchDescriptor<Bird>(
            predicate: #Predicate { $0.bird_id == bird_id }
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
            if watchlist.user_id == nil || watchlist.user_id == WatchlistConstants.legacyDefaultOwnerID {
                watchlist.user_id = userID
                // Keep pendingCreate if it was never synced, otherwise set to pendingUpdate
                if watchlist.syncStatus != .synced {
                    watchlist.syncStatus = .pendingCreate
                } else {
                    watchlist.syncStatus = .pendingUpdate
                }
                changed = true
                adoptedCount += 1
            }
        }
        for watchlist in allWatchlists where watchlist.user_id == userID {
            for entry in watchlist.entries ?? [] {
                if entry.syncStatus == .pendingOwner || entry.syncStatus == .pendingCreate {
                    entry.syncStatus = .pendingCreate
                }
            }
            for rule in watchlist.rules ?? [] {
                if rule.syncStatus == .pendingOwner || rule.syncStatus == .pendingCreate {
                    rule.syncStatus = .pendingCreate
                }
            }
            for entry in watchlist.entries ?? [] {
                for photo in entry.photos ?? [] {
                    if photo.syncStatus == .pendingOwner || photo.syncStatus == .pendingCreate {
                        photo.syncStatus = .pendingCreate
                    }
                }
            }
        }

        let adoptedIdentification = try bindIdentificationToCurrentUser()
        adoptedCount += adoptedIdentification

        if changed || adoptedIdentification > 0 {
            try saveContext()
            queueSync {
                await BackgroundSyncAgent.shared.syncAll()
            }
        }

        return adoptedCount
    }

    func repairInconsistentSyncState() throws -> Int {
        var repairedCount = 0

        let watchlists = try context.fetch(FetchDescriptor<Watchlist>())
        for watchlist in watchlists {
            if repairSyncStatus(&watchlist.syncStatus, lastSyncedAt: watchlist.lastSyncedAt) {
                repairedCount += 1
            }
        }

        let entries = try context.fetch(FetchDescriptor<WatchlistEntry>())
        for entry in entries {
            if repairSyncStatus(&entry.syncStatus, lastSyncedAt: entry.lastSyncedAt) {
                repairedCount += 1
            }
        }

        let rules = try context.fetch(FetchDescriptor<WatchlistRule>())
        for rule in rules {
            if repairSyncStatus(&rule.syncStatus, lastSyncedAt: rule.lastSyncedAt) {
                repairedCount += 1
            }
        }

        let shares = try context.fetch(FetchDescriptor<WatchlistShare>())
        for share in shares {
            if repairSyncStatus(&share.syncStatus, lastSyncedAt: share.lastSyncedAt) {
                repairedCount += 1
            }
        }

        let photos = try context.fetch(FetchDescriptor<ObservedBirdPhoto>())
        for photo in photos {
            if repairSyncStatus(&photo.syncStatus, lastSyncedAt: photo.lastSyncedAt) {
                repairedCount += 1
            }
        }

        let sessions = try context.fetch(FetchDescriptor<IdentificationSession>())
        for session in sessions {
            if repairSyncStatus(&session.syncStatus, lastSyncedAt: session.lastSyncedAt) {
                repairedCount += 1
            }
        }

        let results = try context.fetch(FetchDescriptor<IdentificationResult>())
        for result in results {
            if repairSyncStatus(&result.syncStatus, lastSyncedAt: result.lastSyncedAt) {
                repairedCount += 1
            }
        }

        let candidates = try context.fetch(FetchDescriptor<IdentificationCandidate>())
        for candidate in candidates {
            if repairSyncStatus(&candidate.syncStatus, lastSyncedAt: candidate.lastSyncedAt) {
                repairedCount += 1
            }
        }

        let marks = try context.fetch(FetchDescriptor<IdentificationSessionFieldMark>())
        for mark in marks {
            if repairSyncStatus(&mark.syncStatus, lastSyncedAt: mark.lastSyncedAt) {
                repairedCount += 1
            }
        }

        if repairedCount > 0 {
            try saveContext()
        }

        return repairedCount
    }

    func bindIdentificationToCurrentUser() throws -> Int {
        let userID = activeUserID ?? UserSession.shared.currentUser?.user_id
        guard let userID else { return 0 }
        
        var adoptedCount = 0
        
        let sessionDescriptor = FetchDescriptor<IdentificationSession>()
        let sessions = try context.fetch(sessionDescriptor)
        
        for session in sessions {
            if session.user_id == nil {
                session.user_id = userID
                session.syncStatus = .pendingCreate
                adoptedCount += 1
            }
        }
        
        let resultDescriptor = FetchDescriptor<IdentificationResult>()
        let results = try context.fetch(resultDescriptor)
        for result in results {
            if result.user_id == nil {
                result.user_id = userID
                result.syncStatus = .pendingCreate
            }
        }
        
        return adoptedCount
    }
    
    func createBird(
        commonName: String,
        scientificName: String = "Unknown",
        staticImageName: String = "photo",
    ) throws -> Bird {
        if try fetchBird(byCommonName: commonName) != nil {
            throw WatchlistError.duplicateEntry(birdName: commonName)
        }
        
        let bird = Bird(bird_id: UUID(),
            commonName: commonName,
            scientificName: scientificName,
            staticImageName: staticImageName
        )
        
        context.insert(bird)
        try saveContext()
        
        return bird
    }
    
    private func saveContext() throws {
        do {
            try context.save()
        } catch {
            throw WatchlistError.persistenceFailed(underlying: error)
        }
    }

    private func repairSyncStatus(_ syncStatus: inout SyncStatus, lastSyncedAt: Date?) -> Bool {
        guard syncStatus == .failed else { return false }
        syncStatus = lastSyncedAt == nil ? .pendingCreate : .pendingUpdate
        return true
    }
    
    private func recalculateWatchlistStats(watchlistID: UUID) throws {
        guard let watchlist = try fetchWatchlist(id: watchlistID) else { return }
        
        let activeEntries = (watchlist.entries ?? []).filter { $0.syncStatus != .pendingDelete }
        let observedCount = activeEntries.filter { $0.status == .observed }.count
        let speciesCount = Set(activeEntries.map { $0.bird?.bird_id ?? $0.id }).count
        
        watchlist.observedCount = observedCount
        watchlist.speciesCount = speciesCount
        watchlist.updated_at = Date()
        
        try saveContext()
    }
    
    private func buildWatchlistPayloadData(_ watchlist: Watchlist, for operation: SyncOperationType) -> Data? {
        var payload: [String: Any] = [
            "watchlist_id": watchlist.watchlist_id.uuidString,
            "user_id": watchlist.user_id?.uuidString as Any,
            "type": watchlist.type?.rawValue ?? "custom",
            "title": watchlist.title as Any,
            "location": watchlist.location as Any,
            "location_display_name": watchlist.locationDisplayName as Any,
            "start_date": iso8601String(from: watchlist.startDate) as Any,
            "end_date": iso8601String(from: watchlist.endDate) as Any,
            "cover_image_path": watchlist.coverImagePath as Any,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if operation == .delete {
            payload["deleted_at"] = ISO8601DateFormatter().string(from: Date())
        }
        
        return serializePayload(payload, context: "watchlist payload")
    }
    
    private func buildEntryPayloadData(_ entry: WatchlistEntry, for operation: SyncOperationType) -> Data? {
        var payload: [String: Any] = [
            "watchlist_entry_id": entry.id.uuidString,
            "watchlist_id": entry.watchlist?.watchlist_id.uuidString as Any,
            "bird_id": entry.bird?.bird_id.uuidString as Any,  // CRITICAL FIX: Include bird_id in sync payload
            "nickname": entry.nickname as Any,
            "status": entry.status.rawValue,
            "notes": entry.notes as Any,
            "observation_date": iso8601String(from: entry.observationDate) as Any,
            "to_observe_start_date": iso8601String(from: entry.toObserveStartDate) as Any,
            "to_observe_end_date": iso8601String(from: entry.toObserveEndDate) as Any,
            "observed_by": entry.observedBy as Any,
            "observed_by_user_id": entry.observedByUserId?.uuidString as Any,
            "lat": entry.lat as Any,
            "lon": entry.lon as Any,
            "location_display_name": entry.locationDisplayName as Any,
            "priority": entry.priority,
            "notify_upcoming": entry.notify_upcoming,
            "added_date": ISO8601DateFormatter().string(from: entry.addedDate),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        #if DEBUG
        print("[WatchlistPersistenceService] buildEntryPayloadData - entry.id: \(entry.id)")
        print("[WatchlistPersistenceService] buildEntryPayloadData - entry.bird: \(String(describing: entry.bird))")
        print("[WatchlistPersistenceService] buildEntryPayloadData - entry.bird?.bird_id: \(String(describing: entry.bird?.bird_id))")
        print("[WatchlistPersistenceService] buildEntryPayloadData - bird_id in payload: \(payload["bird_id"] ?? "nil")")
        #endif
        
        if operation == .delete {
            payload["deleted_at"] = ISO8601DateFormatter().string(from: Date())
        }
        
        return serializePayload(payload, context: "entry payload")
    }
    
    private func buildRulePayloadData(_ rule: WatchlistRule, for operation: SyncOperationType) -> Data? {
        var payload: [String: Any] = [
            "watchlist_rule_id": rule.id.uuidString,
            "watchlist_id": rule.watchlist?.watchlist_id.uuidString as Any,
            "rule_type": rule.rule_type.rawValue,
            "lat": rule.lat as Any,
            "lon": rule.lon as Any,
            "radius_km": rule.radius_km as Any,
            "start_date": iso8601String(from: rule.start_date) as Any,
            "end_date": iso8601String(from: rule.end_date) as Any,
            "shape_id": rule.shape_id as Any,
            "pattern_key": rule.pattern_key as Any,
            "is_active": rule.is_active,
            "priority": rule.priority,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if operation == .delete {
            payload["deleted_at"] = ISO8601DateFormatter().string(from: Date())
        }
        
        return serializePayload(payload, context: "rule payload")
    }
}
