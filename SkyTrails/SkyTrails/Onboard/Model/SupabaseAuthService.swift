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
    let gender: String?
    let profilePhoto: String?

    var hasSession: Bool {
        accessToken != nil && refreshToken != nil
    }
}

enum SupabaseOAuthProvider: String {
    case google
    case apple
}

final class SupabaseAuthService {
    static let shared = SupabaseAuthService()
    private let oauthStateKey = "supabase_oauth_state"
    var otpLength: Int {
        let value = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_OTP_LENGTH") as? NSNumber)?.intValue ?? 8
        return max(4, min(10, value))
    }
    var otpResendCooldownSeconds: Int {
        let value = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_OTP_RESEND_SECONDS") as? NSNumber)?.intValue ?? 60
        return max(15, min(300, value))
    }

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
        print("🔍 [AuthService] signIn called for email: \(email) with password length: \(password.count)")
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

    func sendOTP(email: String, createUser: Bool, metadata: [String: String]? = nil) async throws {
        var payload: [String: Any] = [
            "email": email,
            "create_user": createUser
        ]

        if let metadata, !metadata.isEmpty {
            payload["data"] = metadata
        }

        let _: EmptyResponse = try await request(
            path: "/auth/v1/otp",
            method: "POST",
            body: payload
        )
    }

    func verifyOTP(email: String, token: String) async throws -> SupabaseAuthResult {
        let verifyPayload: [String: Any] = [
            "email": email,
            "token": token,
            "type": "email"
        ]

        let response: SupabaseSessionResponse = try await request(
            path: "/auth/v1/verify",
            method: "POST",
            body: verifyPayload
        )
        return try toAuthResult(from: response, fallbackEmail: email)
    }

    func userExists(email: String) async throws -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rpcPayload: [String: Any] = ["input_email": normalizedEmail]

        // Prefer RPC for production-safe checks; fallback to direct query if RPC is not deployed yet.
        if let exists: Bool = try? await request(
            path: "/rest/v1/rpc/check_user_email_exists",
            method: "POST",
            body: rpcPayload
        ) {
            return exists
        }

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?")
        let encodedEmail = normalizedEmail.addingPercentEncoding(withAllowedCharacters: allowed)
            ?? normalizedEmail

        let rows: [SupabaseUserExistsRow] = try await request(
            path: "/rest/v1/users?select=id&email=eq.\(encodedEmail)&limit=1",
            method: "GET",
            body: nil
        )

        return !rows.isEmpty
    }

    func oauthSignInURL(provider: SupabaseOAuthProvider) throws -> URL {
        let config = try SupabaseConfig.load()
        let redirectURL = try oauthRedirectURL()
        let state = UUID().uuidString
        UserDefaults.standard.set(state, forKey: oauthStateKey)

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseAuthError.invalidRequest
        }

        components.path = "/auth/v1/authorize"
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "redirect_to", value: redirectURL.absoluteString),
            URLQueryItem(name: "state", value: state)
        ]

        guard let url = components.url else {
            throw SupabaseAuthError.invalidRequest
        }

        return url
    }

    func isOAuthRedirectURL(_ url: URL) -> Bool {
        guard let expected = try? oauthRedirectURL() else { return false }

        return url.scheme == expected.scheme
            && url.host == expected.host
            && normalized(path: url.path) == normalized(path: expected.path)
    }

    func completeOAuthSignIn(from callbackURL: URL) async throws -> SupabaseAuthResult {
        let parameters = callbackParameters(from: callbackURL)

        if let description = parameters["error_description"], !description.isEmpty {
            clearOAuthState()
            throw SupabaseAuthError.requestFailed(description)
        }

        if let error = parameters["error"], !error.isEmpty {
            clearOAuthState()
            throw SupabaseAuthError.requestFailed(error)
        }

        if let callbackState = parameters["state"], !callbackState.isEmpty {
            if let expectedState = UserDefaults.standard.string(forKey: oauthStateKey),
               !expectedState.isEmpty,
               expectedState != callbackState {
                clearOAuthState()
                throw SupabaseAuthError.requestFailed("OAuth state mismatch. Please try signing in again.")
            }
        }

        guard let accessToken = parameters["access_token"], !accessToken.isEmpty else {
            clearOAuthState()
            throw SupabaseAuthError.requestFailed("Supabase OAuth callback did not return an access token.")
        }

        guard let refreshToken = parameters["refresh_token"], !refreshToken.isEmpty else {
            clearOAuthState()
            throw SupabaseAuthError.requestFailed("Supabase OAuth callback did not return a refresh token.")
        }

        let user = try await getCurrentUser(accessToken: accessToken)
        guard let userID = UUID(uuidString: user.id) else {
            clearOAuthState()
            throw SupabaseAuthError.invalidUserID
        }

        clearOAuthState()

        return SupabaseAuthResult(
            userID: userID,
            email: user.email ?? "",
            accessToken: accessToken,
            refreshToken: refreshToken,
            displayName: user.displayName,
            gender: user.gender,
            profilePhoto: user.profilePhoto
        )
    }

    func restoreSession(accessToken: String, refreshToken: String) async throws -> SupabaseAuthResult {
        print("🔍 [AuthService] restoreSession called")

        do {
            let user = try await getCurrentUser(accessToken: accessToken)
            if let userID = UUID(uuidString: user.id) {
                print("🔍 [AuthService] ✅ getCurrentUser succeeded with existing token")
                return SupabaseAuthResult(
                    userID: userID,
                    email: user.email ?? "",
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    displayName: user.displayName,
                    gender: user.gender,
                    profilePhoto: user.profilePhoto
                )
            }
        } catch {
            print("🔍 [AuthService] ⚠️ getCurrentUser failed: \(error.localizedDescription)")
            print("🔍 [AuthService] Attempting token refresh...")
        }

        let refreshed = try await refreshSession(refreshToken: refreshToken)
        print("🔍 [AuthService] ✅ Token refresh succeeded")
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
            gender: response.user?.gender,
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
            if let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) {
                // Redact password for security in logs, but log the rest
                let logBody = bodyString.replacingOccurrences(of: "\"password\":\"[^\"]*\"", with: "\"password\":\"***\"", options: String.CompareOptions.regularExpression)
                print("🚀 [AuthService] Request Body: \(logBody)")
            }
        }

        print("🚀 [AuthService] Request: \(method) \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [AuthService] Invalid response type")
            throw SupabaseAuthError.invalidResponse
        }

        print("⬇️ [AuthService] Response Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
            print("⬇️ [AuthService] Response Body: \(responseString)")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "Auth failed with status \(httpResponse.statusCode)."
            print("❌ [AuthService] Request failed: \(message)")
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

    private func oauthRedirectURL() throws -> URL {
        let scheme = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_REDIRECT_SCHEME") as? String) ?? "skytrails"
        let host = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_REDIRECT_HOST") as? String) ?? "auth"
        let rawPath = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_REDIRECT_PATH") as? String) ?? "/callback"
        let path = rawPath.hasPrefix("/") ? rawPath : "/" + rawPath

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path

        guard let url = components.url else {
            throw SupabaseAuthError.invalidRequest
        }

        return url
    }

    private func callbackParameters(from callbackURL: URL) -> [String: String] {
        var parameters: [String: String] = [:]

        if let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems {
            for item in queryItems {
                parameters[item.name] = item.value
            }
        }

        if let fragment = callbackURL.fragment, !fragment.isEmpty {
            var fragmentComponents = URLComponents()
            fragmentComponents.query = fragment

            if let fragmentItems = fragmentComponents.queryItems {
                for item in fragmentItems {
                    parameters[item.name] = item.value
                }
            }
        }

        return parameters
    }

    private func clearOAuthState() {
        UserDefaults.standard.removeObject(forKey: oauthStateKey)
    }

    private func normalized(path: String) -> String {
        if path.hasSuffix("/") {
            return String(path.dropLast())
        }
        return path
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
            ?? composedName
            ?? userMetadata?["given_name"]?.stringValue
            ?? userMetadata?["family_name"]?.stringValue
            ?? userMetadata?["preferred_username"]?.stringValue
    }

    var profilePhoto: String? {
        userMetadata?["avatar_url"]?.stringValue
            ?? userMetadata?["picture"]?.stringValue
            ?? userMetadata?["profile_image"]?.stringValue
            ?? userMetadata?["photo_url"]?.stringValue
    }

    var gender: String? {
        userMetadata?["gender"]?.stringValue
    }

    private var composedName: String? {
        let given = userMetadata?["given_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let family = userMetadata?["family_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let joined = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        return joined.isEmpty ? nil : joined
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

private struct SupabaseUserExistsRow: Decodable {
    let id: UUID
}
