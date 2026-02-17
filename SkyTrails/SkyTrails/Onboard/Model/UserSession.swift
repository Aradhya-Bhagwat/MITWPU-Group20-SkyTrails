//
//  UserSession.swift
//  SkyTrails
//
//  Created by SDC-USER on 17/02/26.
//

import Foundation

class UserSession {

    static let shared = UserSession()

    private let userKey = "loggedInUser"

    private init() {}

    func saveUser(_ user: User) {

        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
        }
    }

    func getUser() -> User? {

        guard let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: data)
        else { return nil }

        return user
    }

    func logout() {

        if let user = getUser() {
            KeychainManager.shared.delete(email: user.email)
        }

        UserDefaults.standard.removeObject(forKey: userKey)
    }

    func isLoggedIn() -> Bool {
        return getUser() != nil
    }
}
