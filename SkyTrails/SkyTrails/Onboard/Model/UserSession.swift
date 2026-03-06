
import Foundation

class UserSession {

    static let shared = UserSession()
    static let authStateDidChangeNotification = Notification.Name("UserSessionAuthStateDidChange")

    private let userKey = "loggedInUser"
    private let accessTokenKey = "supabase_access_token"
    private let refreshTokenKey = "supabase_refresh_token"

    private init() {}

    func saveUser(_ user: User) {

        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
        }
    }

    func saveAuthenticatedUser(
        _ user: User,
        accessToken: String?,
        refreshToken: String?
    ) {
        saveUser(user)

        if let accessToken {
            KeychainManager.shared.save(value: accessToken, for: accessTokenKey)
        } else {
            KeychainManager.shared.deleteValue(for: accessTokenKey)
        }

        if let refreshToken {
            KeychainManager.shared.save(value: refreshToken, for: refreshTokenKey)
        } else {
            KeychainManager.shared.deleteValue(for: refreshTokenKey)
        }

        notifyAuthStateChanged()
        Task {
            await createUserInSupabase(userId: user.user_id)
        }
        Task { @MainActor in
            if let token = getAccessToken() {
                let allowed = await DeviceSessionService.shared.registerSession(userId: user.user_id, accessToken: token)
                if !allowed {
                    logout()
                    return
                }
            }
            await connectRealtimeAndSync()
            do {
                try await IdentificationSyncService.shared.adoptGuestSessions(to: user.user_id)
            } catch {
            }
            do {
                let summary = try await InitialSyncService.shared.performInitialSync(userId: user.user_id)
            } catch {
            }
        }
    }

    func getUser() -> User? {

        guard let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: data)
        else { return nil }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["user_id"] == nil {
            saveUser(user)
        }

        return user
    }

    func getAccessToken() -> String? {
        KeychainManager.shared.getValue(for: accessTokenKey)
    }

    func getRefreshToken() -> String? {
        KeychainManager.shared.getValue(for: refreshTokenKey)
    }

    var currentUserID: UUID? {
        isAuthenticatedWithSupabase() ? getUser()?.user_id : nil
    }

    func logout() {
        let tokenBeforeLogout = getAccessToken()
        let userIdBeforeLogout = getUser()?.user_id
        KeychainManager.shared.deleteValue(for: accessTokenKey)
        KeychainManager.shared.deleteValue(for: refreshTokenKey)
        Task { @MainActor in
            if let userIdBeforeLogout, let tokenBeforeLogout {
                await DeviceSessionService.shared.revokeCurrentSession(userId: userIdBeforeLogout, accessToken: tokenBeforeLogout)
            } else {
                DeviceSessionService.shared.clearLocalSessionReference()
            }
            await disconnectRealtimeAndKeepSyncQueue()
        }
        
        notifyAuthStateChanged()
    }

    func isAuthenticatedWithSupabase() -> Bool {
        getAccessToken() != nil && getUser() != nil
    }

    var currentUser: User? {
        isAuthenticatedWithSupabase() ? getUser() : nil
    }

    @discardableResult
    func restoreSessionIfNeeded() async -> Bool {
        guard let accessToken = getAccessToken(),
              let refreshToken = getRefreshToken()
        else {
            if getUser() != nil {
                notifyAuthStateChanged()
            }
            return false
        }

        do {
            let authResult = try await SupabaseAuthService.shared.restoreSession(
                accessToken: accessToken,
                refreshToken: refreshToken
            )

            let cached = getUser()
            let resolvedName = authResult.displayName
                ?? cached?.name
                ?? fallbackName(from: authResult.email)

            let resolvedPhoto = authResult.profilePhoto
                ?? cached?.profilePhoto
                ?? "defaultProfile"

            let user = User(
                user_id: authResult.userID,
                name: resolvedName,
                gender: authResult.gender ?? cached?.gender ?? "Not Specified",
                email: authResult.email,
                profilePhoto: resolvedPhoto
            )

            saveAuthenticatedUser(
                user,
                accessToken: authResult.accessToken ?? accessToken,
                refreshToken: authResult.refreshToken ?? refreshToken
            )
            await connectRealtimeAndSync()
            do {
                let summary = try await InitialSyncService.shared.performInitialSync(userId: user.user_id)
            } catch {
            }
            
            return true
        } catch {
            logout()
            return false
        }
    }

    func isLoggedIn() -> Bool {
        return isAuthenticatedWithSupabase()
    }

    private func fallbackName(from email: String) -> String {
        let username = email.split(separator: "@").first.map(String.init) ?? "User"
        return username.isEmpty ? "User" : username
    }

    private func notifyAuthStateChanged() {
        NotificationCenter.default.post(name: Self.authStateDidChangeNotification, object: self)
    }
    
    private func connectRealtimeAndSync() async {
        do {
            try await RealtimeSyncService.shared.connect()
            try await RealtimeSyncService.shared.subscribeAll()
        } catch {
        }
        await BackgroundSyncAgent.shared.syncAll()
    }
    
    private func disconnectRealtimeAndKeepSyncQueue() async {
        RealtimeSyncService.shared.disconnect()
    }

    func validateCurrentDeviceSession() async -> Bool {
        guard let userId = currentUserID, let token = getAccessToken() else {
            return false
        }
        return await DeviceSessionService.shared.validateCurrentSession(userId: userId, accessToken: token)
    }
    
    private func createUserInSupabase(userId: UUID) async {
        guard let config = try? SupabaseConfig.load(),
              let accessToken = getAccessToken() else {
            return
        }
        
        let payload: [String: Any] = ["user_id": userId.uuidString]
        
        guard let url = URL(string: "\(config.projectURL.absoluteString)/rest/v1/users") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                } else if httpResponse.statusCode == 409 {
                } else {
                }
            }
        } catch {
        }
    }
}
