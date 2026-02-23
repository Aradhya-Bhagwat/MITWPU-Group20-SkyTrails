import Foundation

enum SupabaseClientError: Error, LocalizedError {
    case notConfigured
    case invalidRequest
    case invalidResponse
    case unauthorized
    case requestFailed(Int, String?)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase client is not configured."
        case .invalidRequest:
            return "Unable to prepare Supabase request."
        case .invalidResponse:
            return "Unexpected response from Supabase."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .requestFailed(let status, let message):
            return message ?? "Supabase request failed with status \(status)."
        }
    }
}

enum SupabaseHTTPMethod: String {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
}

struct SupabaseRequestOptions: Sendable {
    let bearerTokenOverride: String?
    let queryItems: [URLQueryItem]?
    let additionalHeaders: [String: String]?

    nonisolated init(
        bearerTokenOverride: String? = nil,
        queryItems: [URLQueryItem]? = nil,
        additionalHeaders: [String: String]? = nil
    ) {
        self.bearerTokenOverride = bearerTokenOverride
        self.queryItems = queryItems
        self.additionalHeaders = additionalHeaders
    }
}

/// Centralized HTTP client for talking to Supabase REST, RPC and Storage endpoints.
/// Auth flows continue to use `SupabaseAuthService` directly; all other network
/// calls should go through this client.
final class SupabaseClient {

    static let shared = SupabaseClient()

    private init() {}

    // MARK: - Public API

    func get<T: Decodable>(
        path: String,
        options: SupabaseRequestOptions = SupabaseRequestOptions(),
        responseType: T.Type = T.self
    ) async throws -> T {
        try await request(
            path: path,
            method: .GET,
            body: Optional<Data>.none,
            options: options,
            responseType: responseType
        )
    }

    func post<T: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        options: SupabaseRequestOptions = SupabaseRequestOptions(),
        responseType: T.Type = T.self
    ) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(
            path: path,
            method: .POST,
            body: data,
            options: options,
            responseType: responseType
        )
    }

    func patch<T: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        options: SupabaseRequestOptions = SupabaseRequestOptions(),
        responseType: T.Type = T.self
    ) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(
            path: path,
            method: .PATCH,
            body: data,
            options: options,
            responseType: responseType
        )
    }

    func delete<T: Decodable>(
        path: String,
        options: SupabaseRequestOptions = SupabaseRequestOptions(),
        responseType: T.Type = T.self
    ) async throws -> T {
        try await request(
            path: path,
            method: .DELETE,
            body: Optional<Data>.none,
            options: options,
            responseType: responseType
        )
    }

    // MARK: - Core Request

    private func request<T: Decodable>(
        path: String,
        method: SupabaseHTTPMethod,
        body: Data?,
        options: SupabaseRequestOptions,
        responseType: T.Type
    ) async throws -> T {
        let config = try SupabaseConfig.load()

        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseClientError.invalidRequest
        }

        let cleanedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        components.path = "/" + cleanedPath

        if let queryItems = options.queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw SupabaseClientError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")

        if let accessToken = resolveAccessToken(override: options.bearerTokenOverride) {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let additional = options.additionalHeaders {
            for (key, value) in additional {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if let body {
            request.httpBody = body
        }

        #if DEBUG
        print("🔗 [SupabaseClient] \(method.rawValue) \(url.absoluteString)")
        #endif

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseClientError.invalidResponse
            }

            // 401 handling – attempt session restore once then surface error
            if httpResponse.statusCode == 401 {
                let restored = await UserSession.shared.restoreSessionIfNeeded()
                guard restored, let token = UserSession.shared.getAccessToken() else {
                    throw SupabaseClientError.unauthorized
                }

                var retryRequest = request
                retryRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
                return try decodeResponse(
                    data: retryData,
                    response: retryResponse,
                    responseType: responseType
                )
            }

            return try decodeResponse(
                data: data,
                response: response,
                responseType: responseType
            )
        } catch {
            throw error
        }
    }

    private func decodeResponse<T: Decodable>(
        data: Data,
        response: URLResponse,
        responseType: T.Type
    ) throws -> T {
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseClientError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw SupabaseClientError.requestFailed(http.statusCode, message)
        }

        if T.self == EmptyResponse.self, data.isEmpty {
            // Reuse auth service EmptyResponse to avoid duplication
            return EmptyResponse() as! T
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw SupabaseClientError.invalidResponse
        }
    }

    private func resolveAccessToken(override: String?) -> String? {
        if let override {
            return override
        }
        return UserSession.shared.getAccessToken()
    }
}

