import Foundation
import UIKit

struct DeviceSessionRow: Codable {
    let id: UUID
    let userId: UUID
    let deviceId: String
    let platform: String
    let appVersion: String
    let createdAt: Date
    let lastSeenAt: Date
    let revokedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceId = "device_id"
        case platform
        case appVersion = "app_version"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case revokedAt = "revoked_at"
    }
}

final class DeviceSessionService {
    static let shared = DeviceSessionService()

    private let deviceIdKey = "skytrails_device_id"
    private let activeSessionIdKey = "skytrails_active_device_session_id"
    private let activeSessionUserIdKey = "skytrails_active_device_session_user_id"
    private let maxAllowedDevices = 2

    private init() {}

    func registerSession(userId: UUID, accessToken: String) async -> Bool {
        guard let config = try? SupabaseConfig.load() else { return true }

        let deviceId = stableDeviceId()
        let now = Date()
        let nowString = iso8601(now)
        let sessionId = UUID()
        let payload: [String: Any] = [
            "id": sessionId.uuidString,
            "user_id": userId.uuidString,
            "device_id": deviceId,
            "platform": "ios",
            "app_version": appVersion(),
            "created_at": nowString,
            "last_seen_at": nowString
        ]

        let insertStatus = await postJSON(
            path: "/rest/v1/user_device_sessions",
            query: "on_conflict=id",
            payload: payload,
            config: config,
            accessToken: accessToken
        )

        if insertStatus == 404 {
            return true
        }

        guard (200...299).contains(insertStatus) || insertStatus == 409 else {
            return true
        }

        storeActiveSession(sessionId: sessionId, userId: userId)
        _ = await enforceDeviceLimit(userId: userId, currentSessionId: sessionId, config: config, accessToken: accessToken)
        return await validateCurrentSession(userId: userId, accessToken: accessToken)
    }

    func validateCurrentSession(userId: UUID, accessToken: String) async -> Bool {
        guard let config = try? SupabaseConfig.load() else { return true }
        guard let active = activeSessionId(for: userId) else { return true }

        let filter = "id=eq.\(active.uuidString)&user_id=eq.\(userId.uuidString)&select=id,revoked_at"
        guard let data = await getData(path: "/rest/v1/user_device_sessions", query: filter, config: config, accessToken: accessToken) else {
            return true
        }

        guard let rows = try? JSONDecoder.iso8601.decode([SessionValidationRow].self, from: data) else {
            return true
        }

        guard let row = rows.first else {
            clearLocalSessionReference()
            return false
        }

        if row.revokedAt != nil {
            clearLocalSessionReference()
            return false
        }

        let status = await patchJSON(
            path: "/rest/v1/user_device_sessions",
            query: "id=eq.\(active.uuidString)&user_id=eq.\(userId.uuidString)",
            payload: ["last_seen_at": iso8601(Date())],
            config: config,
            accessToken: accessToken
        )

        return (200...299).contains(status) || status == 404
    }

    func revokeCurrentSession(userId: UUID, accessToken: String) async {
        guard let config = try? SupabaseConfig.load() else { return }
        guard let active = activeSessionId(for: userId) else {
            clearLocalSessionReference()
            return
        }

        _ = await patchJSON(
            path: "/rest/v1/user_device_sessions",
            query: "id=eq.\(active.uuidString)&user_id=eq.\(userId.uuidString)",
            payload: ["revoked_at": iso8601(Date())],
            config: config,
            accessToken: accessToken
        )
        clearLocalSessionReference()
    }

    func clearLocalSessionReference() {
        UserDefaults.standard.removeObject(forKey: activeSessionIdKey)
        UserDefaults.standard.removeObject(forKey: activeSessionUserIdKey)
    }

    private func enforceDeviceLimit(userId: UUID, currentSessionId: UUID, config: SupabaseConfig, accessToken: String) async -> Bool {
        let query = "user_id=eq.\(userId.uuidString)&revoked_at=is.null&select=id,last_seen_at,created_at&order=created_at.asc"
        guard let data = await getData(path: "/rest/v1/user_device_sessions", query: query, config: config, accessToken: accessToken) else {
            return true
        }

        guard let rows = try? JSONDecoder.iso8601.decode([DeviceLimitRow].self, from: data) else {
            return true
        }

        if rows.count <= maxAllowedDevices {
            return true
        }

        let overflow = rows.count - maxAllowedDevices
        let now = iso8601(Date())
        var revoked = 0

        for row in rows where row.id != currentSessionId {
            if revoked >= overflow { break }
            let status = await patchJSON(
                path: "/rest/v1/user_device_sessions",
                query: "id=eq.\(row.id.uuidString)&user_id=eq.\(userId.uuidString)&revoked_at=is.null",
                payload: ["revoked_at": now],
                config: config,
                accessToken: accessToken
            )
            if (200...299).contains(status) {
                revoked += 1
            }
        }

        return true
    }

    private func stableDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(generated, forKey: deviceIdKey)
        return generated
    }

    private func appVersion() -> String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }

    private func activeSessionId(for userId: UUID) -> UUID? {
        guard let rawId = UserDefaults.standard.string(forKey: activeSessionIdKey),
              let rawUser = UserDefaults.standard.string(forKey: activeSessionUserIdKey),
              rawUser == userId.uuidString
        else { return nil }
        return UUID(uuidString: rawId)
    }

    private func storeActiveSession(sessionId: UUID, userId: UUID) {
        UserDefaults.standard.set(sessionId.uuidString, forKey: activeSessionIdKey)
        UserDefaults.standard.set(userId.uuidString, forKey: activeSessionUserIdKey)
    }

    private func getData(path: String, query: String, config: SupabaseConfig, accessToken: String) async -> Data? {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = path
        components.percentEncodedQuery = query
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func postJSON(path: String, query: String? = nil, payload: [String: Any], config: SupabaseConfig, accessToken: String) async -> Int {
        return await sendJSON(method: "POST", path: path, query: query, payload: payload, config: config, accessToken: accessToken)
    }

    private func patchJSON(path: String, query: String, payload: [String: Any], config: SupabaseConfig, accessToken: String) async -> Int {
        return await sendJSON(method: "PATCH", path: path, query: query, payload: payload, config: config, accessToken: accessToken)
    }

    private func sendJSON(method: String, path: String, query: String?, payload: [String: Any], config: SupabaseConfig, accessToken: String) async -> Int {
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else { return -1 }
        components.path = path
        components.percentEncodedQuery = query
        guard let url = components.url else { return -1 }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if method == "POST" {
            request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return -1 }
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode ?? -1
        } catch {
            return -1
        }
    }

    private func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private struct DeviceLimitRow: Decodable {
    let id: UUID
    let lastSeenAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case lastSeenAt = "last_seen_at"
        case createdAt = "created_at"
    }
}

private struct SessionValidationRow: Decodable {
    let id: UUID
    let revokedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case revokedAt = "revoked_at"
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
