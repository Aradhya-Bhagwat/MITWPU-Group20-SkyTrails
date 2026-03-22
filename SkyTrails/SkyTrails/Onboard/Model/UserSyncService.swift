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
        components.percentEncodedQuery = "on_conflict=user_id"

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

        let responseBody = String(data: data, encoding: .utf8) ?? "(empty)"
        print("DEBUG: UserSyncService upsertUser response - Status: \(httpResponse.statusCode)")
        print("DEBUG: Response Body: \(responseBody)")

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let message = errorJson["message"] as? String ?? "No message"
                let details = errorJson["details"] as? String ?? "No details"
                print("DEBUG: Supabase Error - Message: \(message), Details: \(details)")
            }
            throw UserSyncError.serverError("Status \(httpResponse.statusCode): \(responseBody)")
        }
    }

    func fetchUser(user_id: UUID) async throws -> User? {
        guard let accessToken = UserSession.shared.getAccessToken() else {
            throw UserSyncError.notAuthenticated
        }

        let config = try SupabaseConfig.load()

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw UserSyncError.networkError("Invalid URL")
        }
        components.path = "/rest/v1/users"
        components.percentEncodedQuery = "user_id=eq.\(user_id.uuidString)"

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

    func deleteUser(user_id: UUID) async throws {
        guard let accessToken = UserSession.shared.getAccessToken() else {
            throw UserSyncError.notAuthenticated
        }

        let config = try SupabaseConfig.load()

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw UserSyncError.networkError("Invalid URL")
        }
        components.path = "/rest/v1/users"
        components.percentEncodedQuery = "user_id=eq.\(user_id.uuidString)"

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

    func uploadProfilePhoto(data: Data, user_id: UUID) async throws -> String {
        guard let accessToken = UserSession.shared.getAccessToken() else {
            throw UserSyncError.notAuthenticated
        }

        let config = try SupabaseConfig.load()
        let fileName = "profile_\(user_id.uuidString)_\(Int(Date().timeIntervalSince1970)).jpg"
        let storagePath = "\(user_id.uuidString)/\(fileName)"

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw UserSyncError.networkError("Invalid URL")
        }
        
        // We'll use the 'photos' bucket for now as it's already used in BackgroundSyncAgent
        // and we can prefix it with 'profiles/' to keep it organized.
        components.path = "/storage/v1/object/photos/profiles/\(storagePath)"

        guard let url = components.url else {
            throw UserSyncError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let (responseData, response) = try await URLSession.shared.upload(for: request, from: data)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UserSyncError.networkError("Invalid response")
        }

        let responseBody = String(data: responseData, encoding: .utf8) ?? "(empty)"
        print("DEBUG: UserSyncService uploadProfilePhoto response - Status: \(httpResponse.statusCode)")
        print("DEBUG: Response Body: \(responseBody)")

        guard (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 409 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                let message = errorJson["message"] as? String ?? "No message"
                let details = errorJson["details"] as? String ?? "No details"
                print("DEBUG: Storage Error - Message: \(message), Details: \(details)")
            }
            throw UserSyncError.serverError("Storage Status \(httpResponse.statusCode): \(responseBody)")
        }

        let publicUrl = config.projectURL.appendingPathComponent("storage/v1/object/public/photos/profiles/\(storagePath)").absoluteString
        return publicUrl
    }
}
