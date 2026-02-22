import Foundation
import SwiftData

enum SupabaseAuthError: Error, LocalizedError {
    case notConfigured
    case invalidRequest
    case invalidResponse
    case invalidUserID
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase config is missing. Add SUPABASE_URL and SUPABASE_ANON_KEY in Info.plist."
        case .invalidRequest:
            return "Unable to prepare auth request."
        case .invalidResponse:
            return "Unexpected response from auth server."
        case .invalidUserID:
            return "Supabase returned an invalid user ID."
        case .requestFailed(let message):
            return message
        }
    }
}

struct SupabaseAuthResult {
    let userID: UUID
    let email: String
    let accessToken: String?
    let refreshToken: String?
    let displayName: String?
    let profilePhoto: String?

    var hasSession: Bool {
        accessToken != nil && refreshToken != nil
    }
}

final class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private init() {}

    func signUp(name: String, email: String, password: String) async throws -> SupabaseAuthResult {
        let payload: [String: Any] = [
            "email": email,
            "password": password,
            "data": [
                "name": name
            ]
        ]

        let response: SupabaseSessionResponse = try await request(
            path: "/auth/v1/signup",
            method: "POST",
            body: payload
        )

        return try toAuthResult(from: response, fallbackEmail: email)
    }

    func signIn(email: String, password: String) async throws -> SupabaseAuthResult {
        let payload: [String: Any] = [
            "email": email,
            "password": password
        ]

        let response: SupabaseSessionResponse = try await request(
            path: "/auth/v1/token?grant_type=password",
            method: "POST",
            body: payload
        )

        return try toAuthResult(from: response, fallbackEmail: email)
    }

    func sendOTP(email: String) async throws {
        let payload: [String: Any] = [
            "email": email,
            "create_user": true
        ]

        do {
            let _: EmptyResponse = try await request(
                path: "/auth/v1/otp",
                method: "POST",
                body: payload
            )
        } catch {
            print("Supabase OTP send failed (Prototype mode): \(error.localizedDescription)")
            // In prototype mode, we allow the flow to continue
        }
    }

    func verifyOTP(email: String, token: String) async throws -> SupabaseAuthResult {
        // Prototype bypass
        if token == "123456" {
            return SupabaseAuthResult(
                userID: UUID(), 
                email: email,
                accessToken: "prototype_token_\(UUID().uuidString)",
                refreshToken: "prototype_refresh_\(UUID().uuidString)",
                displayName: nil,
                profilePhoto: nil
            )
        }

        let payload: [String: Any] = [
            "email": email,
            "token": token
        ]

        let response: SupabaseSessionResponse = try await request(
            path: "/auth/v1/token?grant_type=otp",
            method: "POST",
            body: payload
        )

        return try toAuthResult(from: response, fallbackEmail: email)
    }

    func signInWithGoogle(
        idToken: String,
        accessToken: String?,
        fallbackEmail: String?,
        fallbackName: String?,
        fallbackProfilePhoto: String?
    ) async throws -> SupabaseAuthResult {
        var payload: [String: Any] = [
            "provider": "google",
            "id_token": idToken
        ]

        if let accessToken, !accessToken.isEmpty {
            payload["access_token"] = accessToken
        }

        let response: SupabaseSessionResponse = try await request(
            path: "/auth/v1/token?grant_type=id_token",
            method: "POST",
            body: payload
        )

        var result = try toAuthResult(from: response, fallbackEmail: fallbackEmail)

        if result.displayName == nil || result.displayName?.isEmpty == true {
            result = SupabaseAuthResult(
                userID: result.userID,
                email: result.email,
                accessToken: result.accessToken,
                refreshToken: result.refreshToken,
                displayName: fallbackName,
                profilePhoto: result.profilePhoto ?? fallbackProfilePhoto
            )
        }

        return result
    }

    func restoreSession(accessToken: String, refreshToken: String) async throws -> SupabaseAuthResult {
        if let user = try? await getCurrentUser(accessToken: accessToken),
           let userID = UUID(uuidString: user.id) {
            return SupabaseAuthResult(
                userID: userID,
                email: user.email ?? "",
                accessToken: accessToken,
                refreshToken: refreshToken,
                displayName: user.displayName,
                profilePhoto: user.profilePhoto
            )
        }

        let refreshed = try await refreshSession(refreshToken: refreshToken)
        return try toAuthResult(from: refreshed)
    }

    func signOut(accessToken: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/auth/v1/logout",
            method: "POST",
            body: nil,
            bearerToken: accessToken
        )
    }

    private func getCurrentUser(accessToken: String) async throws -> SupabaseUserResponse {
        let response: SupabaseUserResponse = try await request(
            path: "/auth/v1/user",
            method: "GET",
            body: nil,
            bearerToken: accessToken
        )
        return response
    }

    private func refreshSession(refreshToken: String) async throws -> SupabaseSessionResponse {
        let payload: [String: Any] = [
            "refresh_token": refreshToken
        ]

        let response: SupabaseSessionResponse = try await request(
            path: "/auth/v1/token?grant_type=refresh_token",
            method: "POST",
            body: payload
        )
        return response
    }

    private func toAuthResult(
        from response: SupabaseSessionResponse,
        fallbackEmail: String? = nil
    ) throws -> SupabaseAuthResult {
        guard let userID = response.userID else {
            throw SupabaseAuthError.invalidUserID
        }

        return SupabaseAuthResult(
            userID: userID,
            email: response.user?.email ?? fallbackEmail ?? "",
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            displayName: response.user?.displayName,
            profilePhoto: response.user?.profilePhoto
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        body: [String: Any]?,
        bearerToken: String? = nil
    ) async throws -> Response {
        let config = try SupabaseConfig.load()
        let (pathOnly, queryString) = splitPathAndQuery(path)
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseAuthError.invalidRequest
        }
        components.path = "/" + pathOnly
        components.percentEncodedQuery = queryString
        guard let url = components.url else {
            throw SupabaseAuthError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "Auth failed with status \(httpResponse.statusCode)."
            throw SupabaseAuthError.requestFailed(message)
        }

        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            if Response.self == EmptyResponse.self {
                return EmptyResponse() as! Response
            }
            throw SupabaseAuthError.invalidResponse
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let decoded = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
            return decoded.localizedMessage
        }

        return String(data: data, encoding: .utf8)
    }

    private func splitPathAndQuery(_ raw: String) -> (path: String, query: String?) {
        let cleaned = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
        guard let index = cleaned.firstIndex(of: "?") else {
            return (cleaned, nil)
        }

        let path = String(cleaned[..<index])
        let queryStart = cleaned.index(after: index)
        let query = String(cleaned[queryStart...])
        return (path, query.isEmpty ? nil : query)
    }
}

private struct SupabaseSessionResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: SupabaseUserResponse?

    var userID: UUID? {
        guard let rawID = user?.id else { return nil }
        return UUID(uuidString: rawID)
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

private struct SupabaseUserResponse: Decodable {
    let id: String
    let email: String?
    let userMetadata: [String: SupabaseJSONValue]?

    var displayName: String? {
        userMetadata?["name"]?.stringValue
            ?? userMetadata?["full_name"]?.stringValue
            ?? userMetadata?["preferred_username"]?.stringValue
    }

    var profilePhoto: String? {
        userMetadata?["avatar_url"]?.stringValue
            ?? userMetadata?["picture"]?.stringValue
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }
}

private enum SupabaseJSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: SupabaseJSONValue])
    case array([SupabaseJSONValue])
    case null

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: SupabaseJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([SupabaseJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                SupabaseJSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
            )
        }
    }
}

private struct SupabaseErrorResponse: Decodable {
    let msg: String?
    let message: String?
    let errorDescription: String?

    var localizedMessage: String {
        if let message, !message.isEmpty { return message }
        if let msg, !msg.isEmpty { return msg }
        if let errorDescription, !errorDescription.isEmpty { return errorDescription }
        return "Authentication failed."
    }

    enum CodingKeys: String, CodingKey {
        case msg
        case message
        case errorDescription = "error_description"
    }
}

struct EmptyResponse: Decodable {}
