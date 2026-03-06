
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
            await createUserInSupabase(userId: user.id)
        }
        Task { @MainActor in
            await connectRealtimeAndSync()
            do {
                try await IdentificationSyncService.shared.adoptGuestSessions(to: user.id)
            } catch {
            }
            do {
                let summary = try await InitialSyncService.shared.performInitialSync(userId: user.id)
            } catch {
            }
        }
    }

    func getUser() -> User? {

        guard let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: data)
        else { return nil }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["id"] == nil {
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
        isAuthenticatedWithSupabase() ? getUser()?.id : nil
    }

    func logout() {
        KeychainManager.shared.deleteValue(for: accessTokenKey)
        KeychainManager.shared.deleteValue(for: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        Task { @MainActor in
            await disconnectRealtimeAndClearSync()
            await WatchlistManager.shared.clearUserDataOnLogout()
            await IdentificationSyncService.shared.clearLocalData()
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
                logout()
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
                id: authResult.userID,
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
                let summary = try await InitialSyncService.shared.performInitialSync(userId: user.id)
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
    
    private func disconnectRealtimeAndClearSync() async {
        RealtimeSyncService.shared.disconnect()
        await BackgroundSyncAgent.shared.clearAll()
    }
    
    private func createUserInSupabase(userId: UUID) async {
        guard let config = try? SupabaseConfig.load(),
              let accessToken = getAccessToken() else {
            return
        }
        
        let payload: [String: Any] = ["id": userId.uuidString]
        
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
