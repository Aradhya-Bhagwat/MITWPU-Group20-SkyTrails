//
//  KeychainManager.swift
//  SkyTrails
//
//  Created by SDC-USER on 02/02/26.
//

import Foundation
import Security

class KeychainManager {

    static let shared = KeychainManager()

    func save(email: String, password: String) -> Bool {

        let data = password.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        return status == errSecSuccess
    }

    func getPassword(email: String) -> String? {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email,
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
}
extension String {

    var isValidEmail: Bool {

        let regex =
        #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#

        return NSPredicate(format: "SELF MATCHES %@", regex)
            .evaluate(with: self)
    }
}
