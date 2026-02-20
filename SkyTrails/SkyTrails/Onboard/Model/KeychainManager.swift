//
//  KeychainManager.swift
//  SkyTrails
//
//  Created by SDC-USER on 02/02/26.
//

import Foundation
import Security

final class KeychainManager {

    static let shared = KeychainManager()

    private init() {}

    @discardableResult
    func save(value: String, for key: String) -> Bool {

        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "SkyTrails",
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func getValue(for key: String) -> String? {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "SkyTrails",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?

        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data {
            return String(decoding: data, as: UTF8.self)
        }

        return nil
    }

    func deleteValue(for key: String) {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "SkyTrails",
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
extension String {

    var isValidEmail: Bool {

        let regex =
        #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#

        return NSPredicate(format: "SELF MATCHES %@", regex)
            .evaluate(with: self)
    }
}
