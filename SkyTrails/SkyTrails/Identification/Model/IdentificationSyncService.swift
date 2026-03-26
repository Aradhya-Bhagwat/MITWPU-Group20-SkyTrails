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
        try await MainActor.run {
            let context = WatchlistManager.shared.context
            _ = try mergeSessions(sessionRows, context: context)
            try context.save()
        }
    }
    
    private nonisolated func mergeSessions(_ rows: [IdentificationSessionRow], context: ModelContext) throws -> Int {
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
        
        session.serverRowVersion = nil
        session.deletedAt = nil
        session.created_at = row.created_at
        session.updated_at = row.updated_at
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
        
        let (row, data) = try await MainActor.run { () -> (IdentificationSessionRow, Data) in
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
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([T].self, from: data)
        } catch {
            throw IdentificationSyncError.decodingError(error.localizedDescription)
        }
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
}

private struct IdentificationResultDeleteRow: Decodable {
    let id: UUID

    enum CodingKeys: String, CodingKey {
        case id = "identification_result_id"
    }
}

private struct IdentificationSessionDeleteRow: Decodable {
    let id: UUID

    enum CodingKeys: String, CodingKey {
        case id = "identification_session_id"
    }
}
