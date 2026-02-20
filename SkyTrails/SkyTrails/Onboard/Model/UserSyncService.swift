import Foundation
import SwiftData

enum UserSyncError: Error, LocalizedError {
    case notAuthenticated
    case networkError(String)
    case decodingError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError:
            return "Failed to decode server response"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

final class UserSyncService {
    static let shared = UserSyncService()

    private init() {}

    func upsertUser(_ user: User) async throws {
        guard let accessToken = UserSession.shared.getAccessToken() else {
            throw UserSyncError.notAuthenticated
        }

        let config = try SupabaseConfig.load()
        let row = UserRow(from: user)

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw UserSyncError.networkError("Invalid URL")
        }
        components.path = "/rest/v1/users"
        components.percentEncodedQuery = "on_conflict=id"

        guard let url = components.url else {
            throw UserSyncError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(row)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UserSyncError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = data.isEmpty ? "Unknown error" : String(data: data, encoding: .utf8) ?? "Unknown error"
            throw UserSyncError.serverError("Status \(httpResponse.statusCode): \(message)")
        }
    }

    func fetchUser(id: UUID) async throws -> User? {
        guard let accessToken = UserSession.shared.getAccessToken() else {
            throw UserSyncError.notAuthenticated
        }

        let config = try SupabaseConfig.load()

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw UserSyncError.networkError("Invalid URL")
        }
        components.path = "/rest/v1/users"
        components.percentEncodedQuery = "id=eq.\(id.uuidString)"

        guard let url = components.url else {
            throw UserSyncError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UserSyncError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = data.isEmpty ? "Unknown error" : String(data: data, encoding: .utf8) ?? "Unknown error"
            throw UserSyncError.serverError("Status \(httpResponse.statusCode): \(message)")
        }

        guard !data.isEmpty else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let rows = try decoder.decode([UserRow].self, from: data)
            return rows.first?.toUser()
        } catch {
            throw UserSyncError.decodingError
        }
    }

    func deleteUser(id: UUID) async throws {
        guard let accessToken = UserSession.shared.getAccessToken() else {
            throw UserSyncError.notAuthenticated
        }

        let config = try SupabaseConfig.load()

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw UserSyncError.networkError("Invalid URL")
        }
        components.path = "/rest/v1/users"
        components.percentEncodedQuery = "id=eq.\(id.uuidString)"

        guard let url = components.url else {
            throw UserSyncError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UserSyncError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = data.isEmpty ? "Unknown error" : String(data: data, encoding: .utf8) ?? "Unknown error"
            throw UserSyncError.serverError("Status \(httpResponse.statusCode): \(message)")
        }
    }
}
