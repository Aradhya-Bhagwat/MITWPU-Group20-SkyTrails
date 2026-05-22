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
    let shapesSynced: Int
    let birdsSynced: Int
    let fieldMarksSynced: Int
    let variantsSynced: Int
    let birdLinksSynced: Int
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
        shapesSynced + birdsSynced + fieldMarksSynced + variantsSynced + birdLinksSynced +
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

        let shapeRows: [BirdShapeRow] = try await fetchFromSupabase(
            table: "bird_shapes",
            query: "select=*",
            config: config,
            accessToken: accessToken
        )

        let birdRows: [BirdRow] = try await fetchFromSupabase(
            table: "birds",
            query: "select=*",
            config: config,
            accessToken: accessToken
        )

        let fieldMarkRows: [BirdFieldMarkRow] = try await fetchFromSupabase(
            table: "bird_field_marks",
            query: "select=*",
            config: config,
            accessToken: accessToken
        )

        let variantRows: [FieldMarkVariantRow] = try await fetchFromSupabase(
            table: "field_mark_variants",
            query: "select=*",
            config: config,
            accessToken: accessToken
        )

        let birdLinkRows: [BirdFieldMarkVariantLinkRow] = try await fetchFromSupabase(
            table: "bird_field_mark_variant_links",
            query: "select=*",
            config: config,
            accessToken: accessToken
        )

        let ownedWatchlistRows: [WatchlistRow] = try await fetchFromSupabase(
            table: "watchlists",
            query: "select=*&user_id=eq.\(userId.uuidString)&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )

        let ownedWatchlistIDs = ownedWatchlistRows.map(\.watchlist_id)
        let ownedWatchlistIDSet = Set(ownedWatchlistIDs)

        let receivedShareRows: [WatchlistShareRow] = try await fetchFromSupabase(
            table: "watchlist_shares",
            query: "select=*&user_id=eq.\(userId.uuidString)&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )

        let sharedWatchlistIDs = receivedShareRows
            .map(\.watchlistId)
            .filter { !ownedWatchlistIDSet.contains($0) }

        let sharedWatchlistRows: [WatchlistRow] = try await fetchFromSupabaseByIDs(
            table: "watchlists",
            column: "watchlist_id",
            ids: sharedWatchlistIDs,
            baseQuery: "select=*&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )

        let watchlistRows = uniqueRows(ownedWatchlistRows + sharedWatchlistRows) { $0.watchlist_id }
        let allWatchlistIDs = watchlistRows.map(\.watchlist_id)
        
        let entryRows: [WatchlistEntryRow] = try await fetchFromSupabaseByIDs(
            table: "watchlist_entries",
            column: "watchlist_id",
            ids: allWatchlistIDs,
            baseQuery: "select=*&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )

        let entryIDs = entryRows.map(\.id)
        
        let ruleRows: [WatchlistRuleRow] = try await fetchFromSupabaseByIDs(
            table: "watchlist_rules",
            column: "watchlist_id",
            ids: allWatchlistIDs,
            baseQuery: "select=*&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )
        
        let ownerShareRows: [WatchlistShareRow] = try await fetchFromSupabaseByIDs(
            table: "watchlist_shares",
            column: "watchlist_id",
            ids: ownedWatchlistIDs,
            baseQuery: "select=*&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )

        let shareRows = uniqueRows(receivedShareRows + ownerShareRows) { $0.id }
        
        let photoRows: [ObservedBirdPhotoRow] = try await fetchFromSupabaseByIDs(
            table: "observed_bird_photos",
            column: "watchlist_entry_id",
            ids: entryIDs,
            baseQuery: "select=*",
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

        let sessionIDs = sessionRows.map(\.id)

        let resultRows: [IdentificationResultRow] = try await fetchFromSupabaseByIDs(
            table: "identification_results",
            column: "identification_session_id",
            ids: sessionIDs,
            baseQuery: "select=*&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )

        let resultIDs = resultRows.map(\.id)

        let candidateRows: [IdentificationCandidateRow] = try await fetchFromSupabaseByIDs(
            table: "identification_candidates",
            column: "identification_result_id",
            ids: resultIDs,
            baseQuery: "select=*&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )

        let markRows: [IdentificationSessionFieldMarkRow] = try await fetchFromSupabaseByIDs(
            table: "identification_session_marks",
            column: "identification_session_id",
            ids: sessionIDs,
            baseQuery: "select=*&deleted_at=is.null",
            config: config,
            accessToken: accessToken
        )

        let counts = try await MainActor.run {
            let context = WatchlistManager.shared.context
            
            // 1. Identify and Merge Parent Objects first
            let shapeCount = try mergeBirdShapes(shapeRows, context: context)
            try? context.save()

            let birdCount = try mergeBirds(birdRows, shapeRows: shapeRows, context: context)
            try? context.save()

            let fieldMarkCount = try mergeBirdFieldMarks(fieldMarkRows, context: context)
            try? context.save()

            let variantCount = try mergeFieldMarkVariants(variantRows, context: context)
            try? context.save()

            let linkCount = try mergeBirdFieldMarkVariantLinks(birdLinkRows, context: context)
            try? context.save()

            let wCount = try mergeWatchlists(watchlistRows, context: context)
            try? context.save()
            
            let sessCount = try mergeIdentificationSessions(sessionRows, context: context)
            try? context.save()
            
            // 2. Merge Child Objects that depend on parents
            let eCount = try mergeEntries(entryRows, context: context)
            try? context.save()
            
            let rCount = try mergeRules(ruleRows, context: context)
            try? context.save()
            
            let sCount = try mergeShares(shareRows, context: context)
            try? context.save()
            
            let pCount = try mergePhotos(photoRows, context: context)
            try? context.save()
            
            let resCount = try mergeIdentificationResults(resultRows, context: context)
            try? context.save()
            
            let candCount = try mergeIdentificationCandidates(candidateRows, context: context)
            try? context.save()
            
            let markCount = try mergeIdentificationSessionMarks(markRows, context: context)
            try? context.save()

            // Refresh derived watchlist fields after children are merged.
            // Custom watchlist cards read observed/species counts and cover image from Watchlist.
            try refreshDerivedWatchlistFields(context: context)
            try? context.save()
            
            return (shapeCount, birdCount, fieldMarkCount, variantCount, linkCount, wCount, eCount, rCount, sCount, pCount, sessCount, resCount, candCount, markCount)
        }
        
        let summary = InitialSyncSummary(
            shapesSynced: counts.0,
            birdsSynced: counts.1,
            fieldMarksSynced: counts.2,
            variantsSynced: counts.3,
            birdLinksSynced: counts.4,
            watchlistsSynced: counts.5,
            entriesSynced: counts.6,
            rulesSynced: counts.7,
            sharesSynced: counts.8,
            photosSynced: counts.9,
            sessionsSynced: counts.10,
            resultsSynced: counts.11,
            candidatesSynced: counts.12,
            marksSynced: counts.13,
            timestamp: Date()
        )
        await MainActor.run {
            WatchlistManager.shared.notifyDataDidChange()
        }
        return summary
    }

    private func fetchFromSupabaseByIDs<T: Decodable>(
        table: String,
        column: String,
        ids: [UUID],
        baseQuery: String = "select=*",
        config: SupabaseConfig,
        accessToken: String
    ) async throws -> [T] {
        let uniqueIDs = Array(Set(ids))
        guard !uniqueIDs.isEmpty else { return [] }

        let inList = uniqueIDs.map(\.uuidString).joined(separator: ",")
        let query = "\(baseQuery)&\(column)=in.(\(inList))"
        return try await fetchFromSupabase(
            table: table,
            query: query,
            config: config,
            accessToken: accessToken
        )
    }

    private func uniqueRows<T, K: Hashable>(_ rows: [T], key: (T) -> K) -> [T] {
        var seen = Set<K>()
        var result: [T] = []

        for row in rows {
            let rowKey = key(row)
            if seen.insert(rowKey).inserted {
                result.append(row)
            }
        }

        return result
    }

    @MainActor private func mergeBirdShapes(_ rows: [BirdShapeRow], context: ModelContext) throws -> Int {
        let existingShapes = try context.fetch(FetchDescriptor<BirdShape>())
        var shapeById = Dictionary(uniqueKeysWithValues: existingShapes.map { ($0.bird_shape_id, $0) })

        let birds = try context.fetch(FetchDescriptor<Bird>())
        let birdsByShapeId = Dictionary(grouping: birds.compactMap { bird -> (String, Bird)? in
            guard let shapeId = bird.shape_id else { return nil }
            return (shapeId, bird)
        }, by: \.0).mapValues { $0.map(\.1) }

        var syncedCount = 0
        for row in rows {
            let shape: BirdShape
            if let existing = shapeById[row.birdShapeId] {
                existing.name = row.name
                if let icon = row.icon, !icon.isEmpty {
                    existing.icon = icon
                }
                shape = existing
            } else {
                shape = BirdShape(
                    bird_shape_id: row.birdShapeId,
                    name: row.name,
                    icon: row.icon ?? ""
                )
                context.insert(shape)
                shapeById[row.birdShapeId] = shape
            }

            if let linkedBirds = birdsByShapeId[row.birdShapeId] {
                for bird in linkedBirds where bird.shape == nil || bird.shape?.bird_shape_id != row.birdShapeId {
                    bird.shape = shape
                }
            }
            syncedCount += 1
        }
        return syncedCount
    }

    @MainActor private func mergeBirds(_ rows: [BirdRow], shapeRows: [BirdShapeRow], context: ModelContext) throws -> Int {
        let existingBirds = try context.fetch(FetchDescriptor<Bird>())
        var birdById = Dictionary(uniqueKeysWithValues: existingBirds.map { ($0.bird_id, $0) })

        let shapes = try context.fetch(FetchDescriptor<BirdShape>())
        let shapeByCode = Dictionary(uniqueKeysWithValues: shapes.map { ($0.bird_shape_id, $0) })
        let shapeCodeByServerId = Dictionary(uniqueKeysWithValues: shapeRows.compactMap { row in
            row.serverId.map { ($0, row.birdShapeId) }
        })

        var syncedCount = 0
        for row in rows {
            let resolvedShapeCode = row.shapeCode ?? row.shapeServerId.flatMap { shapeCodeByServerId[$0] }
            let resolvedShape = resolvedShapeCode.flatMap { shapeByCode[$0] }
            let staticImageName = row.imageURL ?? row.commonName

            if let existing = birdById[row.id] {
                existing.commonName = row.commonName
                existing.scientificName = row.scientificName
                existing.staticImageName = staticImageName
                existing.family = row.family
                existing.order_name = row.orderName
                existing.descriptionText = row.description
                existing.conservation_status = row.conservationStatus
                existing.migration_strategy = row.migrationStrategy
                existing.shape_id = resolvedShapeCode
                existing.size_category = row.sizeCategory
                existing.shape = resolvedShape
            } else {
                let bird = Bird(
                    bird_id: row.id,
                    commonName: row.commonName,
                    scientificName: row.scientificName,
                    staticImageName: staticImageName,
                    family: row.family,
                    order_name: row.orderName,
                    descriptionText: row.description,
                    conservation_status: row.conservationStatus,
                    migration_strategy: row.migrationStrategy,
                    validMonths: nil,
                    likelySpot: nil,
                    shape_id: resolvedShapeCode,
                    size_category: row.sizeCategory,
                    shape: resolvedShape
                )
                context.insert(bird)
                birdById[row.id] = bird
            }
            syncedCount += 1
        }
        return syncedCount
    }

    @MainActor private func mergeBirdFieldMarks(_ rows: [BirdFieldMarkRow], context: ModelContext) throws -> Int {
        let existingMarks = try context.fetch(FetchDescriptor<BirdFieldMark>())
        var markById = Dictionary(uniqueKeysWithValues: existingMarks.map { ($0.bird_field_mark_id, $0) })

        let shapes = try context.fetch(FetchDescriptor<BirdShape>())
        let shapeById = Dictionary(uniqueKeysWithValues: shapes.map { ($0.bird_shape_id, $0) })

        var syncedCount = 0
        for row in rows {
            let mark: BirdFieldMark
            if let existing = markById[row.id] {
                existing.area = row.area
                existing.shape = shapeById[row.shapeId]
                mark = existing
            } else {
                mark = BirdFieldMark(area: row.area)
                mark.bird_field_mark_id = row.id
                mark.shape = shapeById[row.shapeId]
                context.insert(mark)
                markById[row.id] = mark
            }
            syncedCount += 1
        }
        return syncedCount
    }

    @MainActor private func mergeFieldMarkVariants(_ rows: [FieldMarkVariantRow], context: ModelContext) throws -> Int {
        let existingVariants = try context.fetch(FetchDescriptor<FieldMarkVariant>())
        var variantById = Dictionary(uniqueKeysWithValues: existingVariants.map { ($0.field_mark_variant_id, $0) })

        let fieldMarks = try context.fetch(FetchDescriptor<BirdFieldMark>())
        let fieldMarkById = Dictionary(uniqueKeysWithValues: fieldMarks.map { ($0.bird_field_mark_id, $0) })

        var syncedCount = 0
        for row in rows {
            let variant: FieldMarkVariant
            if let existing = variantById[row.id] {
                existing.name = row.name
                existing.fieldMark = row.fieldMarkId.flatMap { fieldMarkById[$0] }
                variant = existing
            } else {
                variant = FieldMarkVariant(name: row.name)
                variant.field_mark_variant_id = row.id
                variant.fieldMark = row.fieldMarkId.flatMap { fieldMarkById[$0] }
                context.insert(variant)
                variantById[row.id] = variant
            }
            syncedCount += 1
        }
        return syncedCount
    }

    @MainActor private func mergeBirdFieldMarkVariantLinks(_ rows: [BirdFieldMarkVariantLinkRow], context: ModelContext) throws -> Int {
        let existingLinks = try context.fetch(FetchDescriptor<BirdFieldMarkVariantLink>())
        var linkById = Dictionary(uniqueKeysWithValues: existingLinks.map { ($0.bird_field_mark_variant_link_id, $0) })
        var linkByLogicalKey: [String: BirdFieldMarkVariantLink] = [:]
        for link in existingLinks {
            let birdId = link.bird?.bird_id.uuidString.lowercased() ?? ""
            let variantId = link.variant?.field_mark_variant_id.uuidString.lowercased() ?? ""
            let key = "\(birdId)|\(link.area.lowercased())|\(variantId)"
            linkByLogicalKey[key] = link
        }

        let birds = try context.fetch(FetchDescriptor<Bird>())
        let birdById = Dictionary(uniqueKeysWithValues: birds.map { ($0.bird_id, $0) })
        let fieldMarks = try context.fetch(FetchDescriptor<BirdFieldMark>())
        let fieldMarkById = Dictionary(uniqueKeysWithValues: fieldMarks.map { ($0.bird_field_mark_id, $0) })
        let variants = try context.fetch(FetchDescriptor<FieldMarkVariant>())
        let variantById = Dictionary(uniqueKeysWithValues: variants.map { ($0.field_mark_variant_id, $0) })

        var syncedCount = 0
        for row in rows {
            guard let bird = birdById[row.birdId] else { continue }
            let logicalKey = "\(row.birdId.uuidString.lowercased())|\(row.area.lowercased())|\((row.variantId?.uuidString.lowercased()) ?? "")"

            let link: BirdFieldMarkVariantLink
            if let existing = linkById[row.id] ?? linkByLogicalKey[logicalKey] {
                existing.bird_field_mark_variant_link_id = row.id
                existing.bird = bird
                existing.fieldMark = row.fieldMarkId.flatMap { fieldMarkById[$0] }
                existing.variant = row.variantId.flatMap { variantById[$0] }
                existing.area = row.area
                link = existing
            } else {
                link = BirdFieldMarkVariantLink(
                    bird_field_mark_variant_link_id: row.id,
                    bird: bird,
                    fieldMark: row.fieldMarkId.flatMap { fieldMarkById[$0] },
                    variant: row.variantId.flatMap { variantById[$0] },
                    area: row.area
                )
                context.insert(link)
            }

            linkById[row.id] = link
            linkByLogicalKey[logicalKey] = link
            syncedCount += 1
        }
        return syncedCount
    }

    @MainActor private func mergeWatchlists(_ rows: [WatchlistRow], context: ModelContext) throws -> Int {
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
    
    @MainActor private func mergeEntries(_ rows: [WatchlistEntryRow], context: ModelContext) throws -> Int {
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
            if let birdId = row.birdId, birdById[birdId] == nil, let birdName = row.nickname, !birdName.isEmpty {
                let placeholder = Bird(bird_id: birdId, commonName: birdName, scientificName: "", staticImageName: "photo")
                context.insert(placeholder)
                birdById[birdId] = placeholder
            }
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
    
    @MainActor private func mergeRules(_ rows: [WatchlistRuleRow], context: ModelContext) throws -> Int {
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
    
    @MainActor private func mergeShares(_ rows: [WatchlistShareRow], context: ModelContext) throws -> Int {
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
    
    @MainActor private func mergePhotos(_ rows: [ObservedBirdPhotoRow], context: ModelContext) throws -> Int {
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

    @MainActor private func refreshDerivedWatchlistFields(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Watchlist>()
        let watchlists = try context.fetch(descriptor)

        for watchlist in watchlists {
            let activeEntries = (watchlist.entries ?? []).filter { $0.syncStatus != .pendingDelete }
            watchlist.observedCount = activeEntries.filter { $0.status == .observed }.count
            watchlist.speciesCount = Set(activeEntries.map { $0.bird?.bird_id ?? $0.id }).count
            watchlist.updateCoverImage()
        }
    }

    @MainActor private func mergeIdentificationSessions(_ rows: [IdentificationSessionRow], context: ModelContext) throws -> Int {
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

    @MainActor private func mergeIdentificationResults(_ rows: [IdentificationResultRow], context: ModelContext) throws -> Int {
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

    @MainActor private func mergeIdentificationCandidates(_ rows: [IdentificationCandidateRow], context: ModelContext) throws -> Int {
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
            // Merge candidates even if the related bird is temporarily missing locally.
            // That keeps synced result sets visible instead of dropping rows entirely.
            guard resultById[row.resultId] != nil else { continue }
            
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

    @MainActor private func mergeIdentificationSessionMarks(_ rows: [IdentificationSessionFieldMarkRow], context: ModelContext) throws -> Int {
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

        let fieldMarks = try context.fetch(FetchDescriptor<BirdFieldMark>())
        let fieldMarkById = Dictionary(uniqueKeysWithValues: fieldMarks.map { ($0.bird_field_mark_id, $0) })

        let variants = try context.fetch(FetchDescriptor<FieldMarkVariant>())
        let variantById = Dictionary(uniqueKeysWithValues: variants.map { ($0.field_mark_variant_id, $0) })

        var syncedCount = 0
        for row in rows {
            // Safer check: only merge if parent session exists locally
            guard sessionById[row.sessionId] != nil else { continue }
            
            let mark: IdentificationSessionFieldMark
            if let existing = existingById[row.id] {
                updateIdentificationSessionMark(existing, from: row, sessionById: sessionById, fieldMarkById: fieldMarkById, variantById: variantById)
                mark = existing
            } else {
                mark = createIdentificationSessionMark(from: row, sessionById: sessionById, fieldMarkById: fieldMarkById, variantById: variantById)
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
            print("DEBUG: InitialSyncService fetch failed - table: \(table), query: \(query), status: \(httpResponse.statusCode)")
            print("DEBUG: InitialSyncService fetch body: \(message)")
            throw InitialSyncError.networkError("HTTP \(httpResponse.statusCode): \(message)")
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let raw = try container.decode(String.self)

                if let parsed = Self.parseSupabaseDate(raw) {
                    return parsed
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date format: \(raw)"
                )
            }
            return try decoder.decode([T].self, from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "(non-utf8 body, \(data.count) bytes)"
            print("DEBUG: InitialSyncService decode failed - table: \(table), query: \(query)")
            print("DEBUG: InitialSyncService decode error: \(error)")
            print("DEBUG: InitialSyncService decode body: \(String(responseBody.prefix(4000)))")

            if let json = try? JSONSerialization.jsonObject(with: data),
               let rows = json as? [[String: Any]],
               let first = rows.first {
                let keys = first.keys.sorted().joined(separator: ", ")
                print("DEBUG: InitialSyncService decode first-row keys [\(table)]: \(keys)")

                let typedValues = first
                    .sorted { $0.key < $1.key }
                    .map { key, value in "\(key)=\(type(of: value))" }
                    .joined(separator: ", ")
                print("DEBUG: InitialSyncService decode first-row value types [\(table)]: \(typedValues)")
            }

            throw InitialSyncError.decodingError(error.localizedDescription)
        }
    }

    private nonisolated static func parseSupabaseDate(_ value: String) -> Date? {
        let fractionalSecondsFormatter = ISO8601DateFormatter()
        fractionalSecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalSecondsFormatter.date(from: value) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        if let date = standardFormatter.date(from: value) {
            return date
        }
        return nil
    }
    
    @MainActor private func createWatchlist(from row: WatchlistRow) -> Watchlist {
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
    
    @MainActor private func updateWatchlist(_ watchlist: Watchlist, from row: WatchlistRow) {
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
    
    @MainActor private func createEntry(
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
    
    @MainActor private func updateEntry(
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
    
    @MainActor private func createRule(
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
    
    @MainActor private func updateRule(
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
    
    @MainActor private func createShare(
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
    
    @MainActor private func updateShare(
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
    
    @MainActor private func createPhoto(
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
    
    @MainActor private func updatePhoto(
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

    @MainActor private func createIdentificationSession(from row: IdentificationSessionRow, shapeById: [String: BirdShape]) -> IdentificationSession {
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

    @MainActor private func updateIdentificationSession(_ session: IdentificationSession, from row: IdentificationSessionRow, shapeById: [String: BirdShape]) {
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

    @MainActor private func createIdentificationResult(from row: IdentificationResultRow, sessionById: [UUID: IdentificationSession], birdById: [UUID: Bird]) -> IdentificationResult {
        let result = IdentificationResult(
            identification_result_id: row.id,
            user_id: row.ownerId,
            createdAt: row.created_at
        )
        updateIdentificationResult(result, from: row, sessionById: sessionById, birdById: birdById)
        return result
    }

    @MainActor private func updateIdentificationResult(_ result: IdentificationResult, from row: IdentificationResultRow, sessionById: [UUID: IdentificationSession], birdById: [UUID: Bird]) {
        IdentificationRelationshipBinder.bind(result, to: sessionById[row.sessionId])
        if let birdId = row.birdId {
            result.bird = birdById[birdId]
        } else {
            result.bird = nil
        }
        result.user_id = row.ownerId
        result.serverRowVersion = Int64(row.rowVersion)
        result.deletedAt = row.deletedAt
        result.created_at = row.created_at
        result.created_at = row.created_at
        result.updated_at = row.updated_at
    }

    @MainActor private func createIdentificationCandidate(from row: IdentificationCandidateRow, resultById: [UUID: IdentificationResult], birdById: [UUID: Bird]) -> IdentificationCandidate {
        let candidate = IdentificationCandidate(
            identification_candidate_id: row.id,
            result: resultById[row.resultId],
            bird: birdById[row.birdId],
            confidence: row.confidence
        )
        updateIdentificationCandidate(candidate, from: row, resultById: resultById, birdById: birdById)
        return candidate
    }

    @MainActor private func updateIdentificationCandidate(_ candidate: IdentificationCandidate, from row: IdentificationCandidateRow, resultById: [UUID: IdentificationResult], birdById: [UUID: Bird]) {
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

    @MainActor private func createIdentificationSessionMark(
        from row: IdentificationSessionFieldMarkRow,
        sessionById: [UUID: IdentificationSession],
        fieldMarkById: [UUID: BirdFieldMark],
        variantById: [UUID: FieldMarkVariant]
    ) -> IdentificationSessionFieldMark {
        let mark = IdentificationSessionFieldMark(
            identification_session_mark_id: row.id,
            identification_session_id: row.sessionId,
            field_mark_id: row.fieldMarkId,
            variant_id: row.variantId,
            area: row.area
        )
        updateIdentificationSessionMark(mark, from: row, sessionById: sessionById, fieldMarkById: fieldMarkById, variantById: variantById)
        return mark
    }

    @MainActor private func updateIdentificationSessionMark(
        _ mark: IdentificationSessionFieldMark,
        from row: IdentificationSessionFieldMarkRow,
        sessionById: [UUID: IdentificationSession],
        fieldMarkById: [UUID: BirdFieldMark],
        variantById: [UUID: FieldMarkVariant]
    ) {
        mark.identification_session_id = row.sessionId
        if let session = sessionById[row.sessionId] {
            mark.session = session
        }
        mark.field_mark_id = row.fieldMarkId
        mark.fieldMark = fieldMarkById[row.fieldMarkId]
        mark.variant_id = row.variantId
        mark.variant = variantById[row.variantId]
        mark.area = row.area
        mark.serverRowVersion = Int64(row.rowVersion)
        mark.deletedAt = row.deletedAt
        mark.created_at = row.created_at
        mark.updated_at = row.updated_at
    }
}
