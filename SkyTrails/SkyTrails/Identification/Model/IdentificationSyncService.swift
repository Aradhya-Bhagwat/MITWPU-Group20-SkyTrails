import Foundation
import SwiftData

enum IdentificationSyncError: Error, LocalizedError {
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

actor IdentificationSyncService {
    
    static let shared = IdentificationSyncService()
    
    private var config: SupabaseConfig?
    
    private init() {}
    
    func performSync(userId: UUID) async throws {
        if config == nil {
            config = try SupabaseConfig.load()
        }
        
        guard let config else {
            throw IdentificationSyncError.configNotLoaded
        }
        
        guard let accessToken = await MainActor.run(body: { UserSession.shared.getAccessToken() }) else {
            throw IdentificationSyncError.notAuthenticated
        }
        try await pushPendingSessions(userId: userId, config: config, accessToken: accessToken)

        let sessionRows: [IdentificationSessionRow] = try await fetchFromSupabase(
            table: "identification_sessions",
            query: "select=*&user_id=eq.\(userId.uuidString)",
            config: config,
            accessToken: accessToken
        )

        let sessionIDs = sessionRows.map(\.id)
        let resultRows: [PulledIdentificationResultRow]
        let candidateRows: [PulledIdentificationCandidateRow]
        let markRows: [PulledIdentificationSessionMarkRow]

        if sessionIDs.isEmpty {
            resultRows = []
            candidateRows = []
            markRows = []
        } else {
            resultRows = try await fetchFromSupabaseByIDs(
                table: "identification_results",
                column: "identification_session_id",
                ids: sessionIDs,
                config: config,
                accessToken: accessToken
            )

            let resultIDs = resultRows.map(\.id)
            if resultIDs.isEmpty {
                candidateRows = []
            } else {
                candidateRows = try await fetchFromSupabaseByIDs(
                    table: "identification_candidates",
                    column: "identification_result_id",
                    ids: resultIDs,
                    config: config,
                    accessToken: accessToken
                )
            }

            markRows = try await fetchFromSupabaseByIDs(
                table: "identification_session_marks",
                column: "identification_session_id",
                ids: sessionIDs,
                config: config,
                accessToken: accessToken
            )
        }

        try await MainActor.run {
            let context = WatchlistManager.shared.context
            try mergeIdentificationGraph(
                userId: userId,
                sessionRows: sessionRows,
                resultRows: resultRows,
                candidateRows: candidateRows,
                markRows: markRows,
                context: context
            )
            try context.save()
        }
    }

    private nonisolated func mergeIdentificationGraph(
        userId: UUID,
        sessionRows: [IdentificationSessionRow],
        resultRows: [PulledIdentificationResultRow],
        candidateRows: [PulledIdentificationCandidateRow],
        markRows: [PulledIdentificationSessionMarkRow],
        context: ModelContext
    ) throws {
        _ = try mergeIdentificationSessions(sessionRows, context: context)
        _ = try mergeIdentificationResults(resultRows, context: context)
        _ = try mergeIdentificationCandidates(candidateRows, context: context)
        _ = try mergeIdentificationSessionMarks(markRows, context: context)
        try reconcileIdentificationOrphans(
            userId: userId,
            sessionIDs: Set(sessionRows.map(\.id)),
            resultIDs: Set(resultRows.map(\.id)),
            candidateIDs: Set(candidateRows.map(\.id)),
            markIDs: Set(markRows.map(\.id)),
            context: context
        )
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
                updateSession(existing, from: row, shapeById: shapeById)
                session = existing
            } else {
                session = createSession(from: row, shapeById: shapeById)
                context.insert(session)
            }
            session.syncStatus = .synced
            session.lastSyncedAt = Date()
            syncedCount += 1
        }
        
        return syncedCount
    }
    
    private nonisolated func createSession(from row: IdentificationSessionRow, shapeById: [String: BirdShape]) -> IdentificationSession {
        let shapeId = row.metadata?["shapeId"]
        let shape = shapeId.flatMap { shapeById[$0] }
        let locationDisplayName = row.metadata?["locationDisplayName"]
        let sizeCategory = row.metadata?["sizeCategory"].flatMap { Int($0) }
        let filterCategories = row.metadata?["filterCategories"]?.components(separatedBy: ",")
        
        let observationDate: Date
        if let obsDateStr = row.metadata?["observationDate"],
           let parsedDate = ISO8601DateFormatter().date(from: obsDateStr) {
            observationDate = parsedDate
        } else {
            observationDate = row.created_at
        }
        
        let session = IdentificationSession(
            identification_session_id: row.id,
            user_id: row.userId,
            shape: shape,
            locationId: nil,
            locationDisplayName: locationDisplayName,
            observationDate: observationDate,
            createdAt: row.created_at,
            status: SessionStatus(rawValue: row.status) ?? .completed,
            sizeCategory: sizeCategory,
            selectedFilterCategories: filterCategories
        )
        updateSession(session, from: row, shapeById: shapeById)
        return session
    }
    
    private nonisolated func updateSession(_ session: IdentificationSession, from row: IdentificationSessionRow, shapeById: [String: BirdShape]) {
        session.user_id = row.userId
        
        if let shapeId = row.metadata?["shapeId"] {
            session.shape = shapeById[shapeId]
        }
        session.locationDisplayName = row.metadata?["locationDisplayName"]
        
        if let obsDateStr = row.metadata?["observationDate"],
           let parsedDate = ISO8601DateFormatter().date(from: obsDateStr) {
            session.observationDate = parsedDate
        } else {
            session.observationDate = row.created_at
        }
        
        session.status = SessionStatus(rawValue: row.status) ?? .completed
        
        if let sizeStr = row.metadata?["sizeCategory"], let size = Int(sizeStr) {
            session.sizeCategory = size
        }
        if let filterStr = row.metadata?["filterCategories"] {
            session.selectedFilterCategories = filterStr.components(separatedBy: ",")
        }
        
        session.locationLat = row.locationLat
        session.locationLong = row.locationLong
        session.deviceInfo = row.deviceInfo
        session.notes = row.notes
        session.isPublic = row.isPublic ?? false
        session.weatherConditions = row.weatherConditions
        session.metadata = row.metadata
        
        session.created_at = row.created_at
        session.updated_at = row.updated_at
    }

    private nonisolated func mergeIdentificationResults(_ rows: [PulledIdentificationResultRow], context: ModelContext) throws -> Int {
        let existingResults = try context.fetch(FetchDescriptor<IdentificationResult>())
        var existingById = Dictionary(uniqueKeysWithValues: existingResults.map { ($0.identification_result_id, $0) })

        let sessions = try context.fetch(FetchDescriptor<IdentificationSession>())
        let sessionById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.identification_session_id, $0) })

        let birds = try context.fetch(FetchDescriptor<Bird>())
        let birdById = Dictionary(uniqueKeysWithValues: birds.map { ($0.bird_id, $0) })

        var syncedCount = 0
        for row in rows {
            guard sessionById[row.sessionId] != nil else { continue }

            let result: IdentificationResult
            if let existing = existingById[row.id] {
                updateIdentificationResult(existing, from: row, sessionById: sessionById, birdById: birdById)
                result = existing
            } else {
                result = createIdentificationResult(from: row, sessionById: sessionById, birdById: birdById)
                context.insert(result)
                existingById[row.id] = result
            }
            result.syncStatus = .synced
            result.lastSyncedAt = Date()
            syncedCount += 1
        }
        return syncedCount
    }

    private nonisolated func mergeIdentificationCandidates(_ rows: [PulledIdentificationCandidateRow], context: ModelContext) throws -> Int {
        let existingCandidates = try context.fetch(FetchDescriptor<IdentificationCandidate>())
        var existingById = Dictionary(uniqueKeysWithValues: existingCandidates.map { ($0.identification_candidate_id, $0) })

        let results = try context.fetch(FetchDescriptor<IdentificationResult>())
        let resultById = Dictionary(uniqueKeysWithValues: results.map { ($0.identification_result_id, $0) })

        let birds = try context.fetch(FetchDescriptor<Bird>())
        let birdById = Dictionary(uniqueKeysWithValues: birds.map { ($0.bird_id, $0) })

        var syncedCount = 0
        for row in rows {
            guard resultById[row.resultId] != nil else { continue }

            let candidate: IdentificationCandidate
            if let existing = existingById[row.id] {
                updateIdentificationCandidate(existing, from: row, resultById: resultById, birdById: birdById)
                candidate = existing
            } else {
                candidate = createIdentificationCandidate(from: row, resultById: resultById, birdById: birdById)
                context.insert(candidate)
                existingById[row.id] = candidate
            }
            candidate.syncStatus = .synced
            candidate.lastSyncedAt = Date()
            syncedCount += 1
        }
        return syncedCount
    }

    private nonisolated func mergeIdentificationSessionMarks(_ rows: [PulledIdentificationSessionMarkRow], context: ModelContext) throws -> Int {
        let existingMarks = try context.fetch(FetchDescriptor<IdentificationSessionFieldMark>())
        var existingById = Dictionary(uniqueKeysWithValues: existingMarks.map { ($0.identification_session_mark_id, $0) })

        let sessions = try context.fetch(FetchDescriptor<IdentificationSession>())
        let sessionById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.identification_session_id, $0) })

        let fieldMarks = try context.fetch(FetchDescriptor<BirdFieldMark>())
        let fieldMarkById = Dictionary(uniqueKeysWithValues: fieldMarks.map { ($0.bird_field_mark_id, $0) })

        let variants = try context.fetch(FetchDescriptor<FieldMarkVariant>())
        let variantById = Dictionary(uniqueKeysWithValues: variants.map { ($0.field_mark_variant_id, $0) })

        var syncedCount = 0
        for row in rows {
            guard sessionById[row.sessionId] != nil else { continue }

            let mark: IdentificationSessionFieldMark
            if let existing = existingById[row.id] {
                updateIdentificationSessionMark(existing, from: row, sessionById: sessionById, fieldMarkById: fieldMarkById, variantById: variantById)
                mark = existing
            } else {
                mark = createIdentificationSessionMark(from: row, sessionById: sessionById, fieldMarkById: fieldMarkById, variantById: variantById)
                context.insert(mark)
                existingById[row.id] = mark
            }
            mark.syncStatus = .synced
            mark.lastSyncedAt = Date()
            syncedCount += 1
        }
        return syncedCount
    }

    private nonisolated func reconcileIdentificationOrphans(
        userId: UUID,
        sessionIDs: Set<UUID>,
        resultIDs: Set<UUID>,
        candidateIDs: Set<UUID>,
        markIDs: Set<UUID>,
        context: ModelContext
    ) throws {
        let existingSessions = try context.fetch(FetchDescriptor<IdentificationSession>())
        for session in existingSessions {
            guard session.syncStatus == .synced,
                  session.user_id == userId,
                  !sessionIDs.contains(session.identification_session_id) else { continue }
            context.delete(session)
        }

        let existingResults = try context.fetch(FetchDescriptor<IdentificationResult>())
        for result in existingResults {
            guard result.syncStatus == .synced,
                  let sessionId = result.session?.identification_session_id,
                  sessionIDs.contains(sessionId),
                  !resultIDs.contains(result.identification_result_id) else { continue }
            context.delete(result)
        }

        let existingCandidates = try context.fetch(FetchDescriptor<IdentificationCandidate>())
        for candidate in existingCandidates {
            guard candidate.syncStatus == .synced,
                  let resultId = candidate.result?.identification_result_id,
                  resultIDs.contains(resultId),
                  !candidateIDs.contains(candidate.identification_candidate_id) else { continue }
            context.delete(candidate)
        }

        let existingMarks = try context.fetch(FetchDescriptor<IdentificationSessionFieldMark>())
        for mark in existingMarks {
            guard mark.syncStatus == .synced,
                  sessionIDs.contains(mark.identification_session_id),
                  !markIDs.contains(mark.identification_session_mark_id) else { continue }
            context.delete(mark)
        }
    }
    
    func pushPendingSessions(userId: UUID, config: SupabaseConfig, accessToken: String) async throws {
        let pendingSessionIDs = await MainActor.run { () -> [UUID] in
            do {
                let descriptor = FetchDescriptor<IdentificationSession>(
                    sortBy: [SortDescriptor(\.created_at, order: .reverse)]
                )
                let sessions = try WatchlistManager.shared.context.fetch(descriptor)
                return sessions.filter { $0.user_id == nil || $0.user_id == userId }.map { $0.identification_session_id }
            } catch {
                return []
            }
        }
        for sessionID in pendingSessionIDs {
            try await pushSession(sessionID: sessionID, userId: userId, config: config, accessToken: accessToken)
        }
    }
    
    func pushSession(sessionID: UUID, userId: UUID, config: SupabaseConfig, accessToken: String) async throws {
        
        let (_, data) = try await MainActor.run { () -> (IdentificationSessionRow, Data) in
            let descriptor = FetchDescriptor<IdentificationSession>(
                predicate: #Predicate { $0.identification_session_id == sessionID }
            )
            guard let session = try WatchlistManager.shared.context.fetch(descriptor).first else {
                throw IdentificationSyncError.contextError("Session not found")
            }
            
            var metadata: [String: String] = session.metadata ?? [:]
            if let shapeId = session.shape?.bird_shape_id {
                metadata["shapeId"] = shapeId
            }
            if let locationDisplayName = session.locationDisplayName {
                metadata["locationDisplayName"] = locationDisplayName
            }
            if let sizeCategory = session.sizeCategory {
                metadata["sizeCategory"] = String(sizeCategory)
            }
            if let filterCategories = session.selectedFilterCategories {
                metadata["filterCategories"] = filterCategories.joined(separator: ",")
            }
            metadata["observationDate"] = ISO8601DateFormatter().string(from: session.observationDate)
            
            let row = IdentificationSessionRow(
                id: session.identification_session_id,
                userId: session.user_id ?? userId,
                status: session.status.rawValue,
                locationLat: session.locationLat,
                locationLong: session.locationLong,
                deviceInfo: session.deviceInfo,
                notes: session.notes,
                isPublic: session.isPublic,
                weatherConditions: session.weatherConditions,
                metadata: metadata.isEmpty ? nil : metadata,
                created_at: session.created_at,
                updated_at: session.updated_at
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return (row, try encoder.encode(row))
        }
        
        let urlString = "\(config.projectURL.absoluteString)/rest/v1/identification_sessions"
        guard let url = URL(string: urlString) else {
            throw IdentificationSyncError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IdentificationSyncError.networkError("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw IdentificationSyncError.networkError("HTTP \(httpResponse.statusCode): \(message)")
        }
        
        await MainActor.run {
            let descriptor = FetchDescriptor<IdentificationSession>(
                predicate: #Predicate { $0.identification_session_id == sessionID }
            )
            if let session = try? WatchlistManager.shared.context.fetch(descriptor).first {
                session.syncStatus = .synced
                session.lastSyncedAt = Date()
            }
        }
    }
    
    private nonisolated func fetchFromSupabase<T: Decodable>(
        table: String,
        query: String,
        config: SupabaseConfig,
        accessToken: String
    ) async throws -> [T] {
        let urlString = "\(config.projectURL.absoluteString)/rest/v1/\(table)?\(query)"
        
        guard let url = URL(string: urlString) else {
            throw IdentificationSyncError.networkError("Invalid URL: \(urlString)")
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
            throw IdentificationSyncError.networkError(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IdentificationSyncError.networkError("Invalid response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw IdentificationSyncError.networkError("HTTP \(httpResponse.statusCode): \(message)")
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
            throw IdentificationSyncError.decodingError(error.localizedDescription)
        }
    }

    private func fetchFromSupabaseByIDs<T: Decodable>(
        table: String,
        column: String,
        ids: [UUID],
        config: SupabaseConfig,
        accessToken: String
    ) async throws -> [T] {
        let uniqueIDs = Array(Set(ids))
        guard !uniqueIDs.isEmpty else { return [] }

        let inList = uniqueIDs.map(\.uuidString).joined(separator: ",")
        return try await fetchFromSupabase(
            table: table,
            query: "select=*&\(column)=in.(\(inList))",
            config: config,
            accessToken: accessToken
        )
    }

    private nonisolated static func parseSupabaseDate(_ value: String) -> Date? {
        let fractionalSecondsFormatter = ISO8601DateFormatter()
        fractionalSecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalSecondsFormatter.date(from: value) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        return standardFormatter.date(from: value)
    }
    
    func adoptGuestSessions(to userId: UUID) async throws {
        await MainActor.run {
            do {
                let descriptor = FetchDescriptor<IdentificationSession>(
                    predicate: #Predicate { $0.syncStatusRaw == "pendingOwner" }
                )
                let pendingSessions = try WatchlistManager.shared.context.fetch(descriptor)
                
                for session in pendingSessions {
                    session.user_id = userId
                    session.syncStatus = .pendingCreate
                    if let result = session.result {
                        result.user_id = userId
                        result.syncStatus = (result.syncStatus == .synced) ? .pendingUpdate : .pendingCreate
                    }
                }
                
                try WatchlistManager.shared.context.save()
            } catch {
            }
        }
        try await performSync(userId: userId)
    }

    func deleteAllHistory() async throws {
        await BackgroundSyncAgent.shared.purgeIdentificationOperations()

        let userId = await MainActor.run { UserSession.shared.getUser()?.user_id }
        let accessToken = await MainActor.run { UserSession.shared.getAccessToken() }

        if let userId, let accessToken {
            if config == nil {
                config = try SupabaseConfig.load()
            }

            guard let config else {
                throw IdentificationSyncError.configNotLoaded
            }

            try await deleteHistoryFromSupabase(userId: userId, config: config, accessToken: accessToken)
        }

        await clearLocalData()
    }

    private func deleteHistoryFromSupabase(userId: UUID, config: SupabaseConfig, accessToken: String) async throws {
        let sessionRows: [IdentificationSessionDeleteRow] = try await fetchFromSupabase(
            table: "identification_sessions",
            query: "select=identification_session_id&user_id=eq.\(userId.uuidString)&limit=10000",
            config: config,
            accessToken: accessToken
        )

        let sessionIDs = sessionRows.map(\.id)
        guard !sessionIDs.isEmpty else { return }

        let resultRows: [IdentificationResultDeleteRow] = try await fetchFromSupabase(
            table: "identification_results",
            query: "select=identification_result_id&identification_session_id=in.\(supabaseInList(sessionIDs))&limit=10000",
            config: config,
            accessToken: accessToken
        )

        let resultIDs = resultRows.map(\.id)

        if !resultIDs.isEmpty {
            try await deleteFromSupabase(
                table: "identification_candidates",
                filter: "identification_result_id=in.\(supabaseInList(resultIDs))",
                config: config,
                accessToken: accessToken
            )
        }

        try await deleteFromSupabase(
            table: "identification_session_marks",
            filter: "identification_session_id=in.\(supabaseInList(sessionIDs))",
            config: config,
            accessToken: accessToken
        )

        if !resultIDs.isEmpty {
            try await deleteFromSupabase(
                table: "identification_results",
                filter: "identification_result_id=in.\(supabaseInList(resultIDs))",
                config: config,
                accessToken: accessToken
            )
        }

        try await deleteFromSupabase(
            table: "identification_sessions",
            filter: "identification_session_id=in.\(supabaseInList(sessionIDs))",
            config: config,
            accessToken: accessToken
        )
    }

    private func deleteFromSupabase(
        table: String,
        filter: String,
        config: SupabaseConfig,
        accessToken: String
    ) async throws {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw IdentificationSyncError.networkError("Invalid URL")
        }

        components.path = "/rest/v1/\(table)"
        components.percentEncodedQuery = filter

        guard let url = components.url else {
            throw IdentificationSyncError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw IdentificationSyncError.networkError("HTTP \(statusCode) while deleting \(table)")
            }
        } catch let error as IdentificationSyncError {
            throw error
        } catch {
            throw IdentificationSyncError.networkError(error.localizedDescription)
        }
    }

    private func supabaseInList(_ ids: [UUID]) -> String {
        let joined = ids.map(\.uuidString).joined(separator: ",")
        return "(\(joined))"
    }
    
    func clearLocalData() async {
        await MainActor.run {
            do {
                let sessionDescriptor = FetchDescriptor<IdentificationSession>()
                let sessions = try WatchlistManager.shared.context.fetch(sessionDescriptor)
                
                for session in sessions {
                    WatchlistManager.shared.context.delete(session)
                }

                let markDescriptor = FetchDescriptor<IdentificationSessionFieldMark>()
                let marks = try WatchlistManager.shared.context.fetch(markDescriptor)

                for mark in marks {
                    WatchlistManager.shared.context.delete(mark)
                }
                
                let resultDescriptor = FetchDescriptor<IdentificationResult>()
                let results = try WatchlistManager.shared.context.fetch(resultDescriptor)
                
                for result in results {
                    WatchlistManager.shared.context.delete(result)
                }
                
                let candidateDescriptor = FetchDescriptor<IdentificationCandidate>()
                let candidates = try WatchlistManager.shared.context.fetch(candidateDescriptor)
                
                for candidate in candidates {
                    WatchlistManager.shared.context.delete(candidate)
                }
                
                try WatchlistManager.shared.context.save()
            } catch {
            }
        }
    }

    private nonisolated func createIdentificationResult(
        from row: PulledIdentificationResultRow,
        sessionById: [UUID: IdentificationSession],
        birdById: [UUID: Bird]
    ) -> IdentificationResult {
        let result = IdentificationResult(
            identification_result_id: row.id,
            user_id: row.ownerId,
            createdAt: row.created_at
        )
        updateIdentificationResult(result, from: row, sessionById: sessionById, birdById: birdById)
        return result
    }

    private nonisolated func updateIdentificationResult(
        _ result: IdentificationResult,
        from row: PulledIdentificationResultRow,
        sessionById: [UUID: IdentificationSession],
        birdById: [UUID: Bird]
    ) {
        IdentificationRelationshipBinder.bind(result, to: sessionById[row.sessionId])
        result.user_id = row.ownerId
        result.bird = row.birdId.flatMap { birdById[$0] }
        result.serverRowVersion = Int64(row.rowVersion)
        result.deletedAt = row.deletedAt
        result.created_at = row.created_at
        result.updated_at = row.updated_at
    }

    private nonisolated func createIdentificationCandidate(
        from row: PulledIdentificationCandidateRow,
        resultById: [UUID: IdentificationResult],
        birdById: [UUID: Bird]
    ) -> IdentificationCandidate {
        let candidate = IdentificationCandidate(
            identification_candidate_id: row.id,
            result: resultById[row.resultId],
            bird: row.birdId.flatMap { birdById[$0] },
            confidence: row.confidence,
            rank: row.rank,
            matchScore: MatchScore(
                matchedFeatures: row.matchedFeatures,
                mismatchedFeatures: row.mismatchedFeatures,
                score: 0
            )
        )
        updateIdentificationCandidate(candidate, from: row, resultById: resultById, birdById: birdById)
        return candidate
    }

    private nonisolated func updateIdentificationCandidate(
        _ candidate: IdentificationCandidate,
        from row: PulledIdentificationCandidateRow,
        resultById: [UUID: IdentificationResult],
        birdById: [UUID: Bird]
    ) {
        candidate.result = resultById[row.resultId]
        candidate.bird = row.birdId.flatMap { birdById[$0] }
        candidate.confidence = row.confidence
        candidate.rank = row.rank
        candidate.matchScore = MatchScore(
            matchedFeatures: row.matchedFeatures,
            mismatchedFeatures: row.mismatchedFeatures,
            score: 0
        )
        candidate.serverRowVersion = Int64(row.rowVersion)
        candidate.deletedAt = row.deletedAt
        candidate.created_at = row.created_at
        candidate.updated_at = row.updated_at
    }

    private nonisolated func createIdentificationSessionMark(
        from row: PulledIdentificationSessionMarkRow,
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

    private nonisolated func updateIdentificationSessionMark(
        _ mark: IdentificationSessionFieldMark,
        from row: PulledIdentificationSessionMarkRow,
        sessionById: [UUID: IdentificationSession],
        fieldMarkById: [UUID: BirdFieldMark],
        variantById: [UUID: FieldMarkVariant]
    ) {
        mark.identification_session_id = row.sessionId
        mark.session = sessionById[row.sessionId]
        if let fieldMarkId = row.fieldMarkId {
            mark.field_mark_id = fieldMarkId
            mark.fieldMark = fieldMarkById[fieldMarkId]
        } else {
            mark.fieldMark = nil
        }
        if let variantId = row.variantId {
            mark.variant_id = variantId
            mark.variant = variantById[variantId]
        } else {
            mark.variant = nil
        }
        mark.area = row.area
        mark.serverRowVersion = Int64(row.rowVersion)
        mark.deletedAt = row.deletedAt
        mark.created_at = row.created_at
        mark.updated_at = row.updated_at
    }
}

private struct IdentificationResultDeleteRow: Decodable, Sendable {
    let id: UUID

    enum CodingKeys: String, CodingKey {
        case id = "identification_result_id"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
    }
}

private struct IdentificationSessionDeleteRow: Decodable, Sendable {
    let id: UUID

    enum CodingKeys: String, CodingKey {
        case id = "identification_session_id"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
    }
}

private struct PulledIdentificationResultRow: Decodable, Sendable {
    let id: UUID
    let sessionId: UUID
    let ownerId: UUID?
    let birdId: UUID?
    let rowVersion: Int
    let deletedAt: Date?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id = "identification_result_id"
        case sessionId = "identification_session_id"
        case ownerId = "owner_id"
        case legacyOwnerId = "user_id"
        case birdId = "bird_id"
        case rowVersion = "row_version"
        case deletedAt = "deleted_at"
        case created_at = "created_at"
        case updated_at = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId)
            ?? container.decodeIfPresent(UUID.self, forKey: .legacyOwnerId)
        birdId = try container.decodeIfPresent(UUID.self, forKey: .birdId)
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
    }
}

private struct PulledIdentificationCandidateRow: Decodable, Sendable {
    let id: UUID
    let resultId: UUID
    let birdId: UUID?
    let confidence: Double
    let rank: Int?
    let matchedFeatures: [String]
    let mismatchedFeatures: [String]
    let rowVersion: Int
    let deletedAt: Date?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id = "identification_candidate_id"
        case resultId = "identification_result_id"
        case birdId = "bird_id"
        case confidence
        case rank = "confidence_rank"
        case legacyRank = "rank"
        case matchedFeatures = "matched_features"
        case mismatchedFeatures = "mismatched_features"
        case rowVersion = "row_version"
        case deletedAt = "deleted_at"
        case created_at = "created_at"
        case updated_at = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        resultId = try container.decode(UUID.self, forKey: .resultId)
        birdId = try container.decodeIfPresent(UUID.self, forKey: .birdId)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        rank = try container.decodeIfPresent(Int.self, forKey: .rank)
            ?? container.decodeIfPresent(Int.self, forKey: .legacyRank)
        matchedFeatures = try container.decodeIfPresent([String].self, forKey: .matchedFeatures) ?? []
        mismatchedFeatures = try container.decodeIfPresent([String].self, forKey: .mismatchedFeatures) ?? []
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
    }
}

private struct PulledIdentificationSessionMarkRow: Decodable, Sendable {
    let id: UUID
    let sessionId: UUID
    let fieldMarkId: UUID?
    let variantId: UUID?
    let area: String
    let rowVersion: Int
    let deletedAt: Date?
    let created_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id = "identification_session_mark_id"
        case sessionId = "identification_session_id"
        case fieldMarkId = "field_mark_id"
        case variantId = "variant_id"
        case area
        case rowVersion = "row_version"
        case deletedAt = "deleted_at"
        case created_at = "created_at"
        case updated_at = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        fieldMarkId = try container.decodeIfPresent(UUID.self, forKey: .fieldMarkId)
        variantId = try container.decodeIfPresent(UUID.self, forKey: .variantId)
        area = try container.decodeIfPresent(String.self, forKey: .area) ?? ""
        rowVersion = try container.decodeIfPresent(Int.self, forKey: .rowVersion) ?? 0
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
        updated_at = try container.decodeIfPresent(Date.self, forKey: .updated_at)
    }
}
