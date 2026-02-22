//
//  UserSession.swift
//  SkyTrails
//
//  Created by SDC-USER on 17/02/26.
//

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
        
        // Connect to realtime sync on successful auth
        Task { @MainActor in
            await connectRealtimeAndSync()
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
        
        // Disconnect realtime and clear sync queue
        Task { @MainActor in
            await disconnectRealtimeAndClearSync()
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
                gender: cached?.gender ?? "Not Specified",
                email: authResult.email,
                profilePhoto: resolvedPhoto
            )

            saveAuthenticatedUser(
                user,
                accessToken: authResult.accessToken ?? accessToken,
                refreshToken: authResult.refreshToken ?? refreshToken
            )
            
            // Connect realtime after session restore
            await connectRealtimeAndSync()
            
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
    
    // MARK: - Realtime & Sync Integration
    
    private func connectRealtimeAndSync() async {
        do {
            try await RealtimeSyncService.shared.connect()
            try await RealtimeSyncService.shared.subscribeAll()
            print("✅ [UserSession] Realtime connected and subscribed")
        } catch {
            print("⚠️ [UserSession] Failed to connect realtime: \(error.localizedDescription)")
        }
        
        // Process any pending sync operations
        await BackgroundSyncAgent.shared.syncAll()
    }
    
    private func disconnectRealtimeAndClearSync() async {
        RealtimeSyncService.shared.disconnect()
        await BackgroundSyncAgent.shared.clearAll()
        print("✅ [UserSession] Realtime disconnected and sync cleared")
    }
}
