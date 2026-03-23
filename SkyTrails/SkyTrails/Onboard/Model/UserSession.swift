
import Foundation

class UserSession {

    static let shared = UserSession()
    static let authStateDidChangeNotification = Notification.Name("UserSessionAuthStateDidChange")
    static let userProfileDidChangeNotification = Notification.Name("UserProfileDidChange")

    private let userKey = "loggedInUser"
    private let accessTokenKey = "supabase_access_token"
    private let refreshTokenKey = "supabase_refresh_token"

    private init() {}

    func saveUser(_ user: User) {

        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
            NotificationCenter.default.post(name: Self.userProfileDidChangeNotification, object: nil)
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
            await createUserInSupabase(user: user)
        }
        Task { @MainActor in
            if let token = getAccessToken() {
                let allowed = await DeviceSessionService.shared.registerSession(userId: user.user_id, accessToken: token)
                if !allowed {
                    logout()
                    return
                }
            }
            
            // 1. Establish Realtime Connection
            await connectRealtimeAndSync()
            
            // 2. Adopt any guest data created before login (Watchlists, Identification, etc.)
            await WatchlistManager.shared.bindCurrentUserOwnership()
            
            // 3. Pull all data from Supabase that might have been created on other devices
            do {
                _ = try await InitialSyncService.shared.performInitialSync(userId: user.user_id)
            } catch {
                print("DEBUG: UserSession - Initial sync failed: \(error)")
            }
            
            // 4. Trigger Background Agent to push any newly adopted pending changes
            await BackgroundSyncAgent.shared.syncAll()
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

    func syncProfileWithServer() async {
        guard let user = getUser() else { return }
        do {
            if let serverUser = try await UserSyncService.shared.fetchUser(user_id: user.user_id) {
                var updated = user
                updated.name = serverUser.name
                updated.gender = serverUser.gender
                updated.profilePhoto = serverUser.profilePhoto
                saveUser(updated)
            }
        } catch {
            print("DEBUG: UserSession - Failed to sync profile with server: \(error)")
        }
    }
    
    private func createUserInSupabase(user: User) async {
        guard let config = try? SupabaseConfig.load(),
              let accessToken = getAccessToken() else {
            return
        }
        
        var payload: [String: Any] = [
            "user_id": user.user_id.uuidString,
            "name": user.name,
            "email": user.email,
            "gender": user.gender
        ]
        
        if user.profilePhoto != "defaultProfile" {
            payload["profile_photo"] = user.profilePhoto
        }
        
        guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
            return
        }
        components.path = "/rest/v1/users"
        components.percentEncodedQuery = "on_conflict=user_id"
        
        guard let url = components.url else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    print("DEBUG: User created successfully in database")
                } else if httpResponse.statusCode == 409 {
                    print("DEBUG: User already exists in database")
                } else {
                    let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown"
                    print("DEBUG: User creation failed with status: \(httpResponse.statusCode), error: \(errorMsg)")
                }
            }
        } catch {
            print("DEBUG: User creation error: \(error)")
        }
    }
}
