//
//  Keychain.swift
//  HotMess
//

import Foundation
import Security

/// A minimal wrapper over the Security framework, replacing the
/// `KeychainAccess` dependency.
///
/// Items are stored with `kSecAttrAccessibleAfterFirstUnlock` so the app can
/// still authenticate when it wakes in the background for a location update or
/// a push — the library default (`WhenUnlocked`) silently failed there.
struct Keychain: Sendable {
    enum Key: String, Sendable {
        case sessionToken = "token"
    }

    let service: String

    static let shared = Keychain(service: "social.hotmess.account")

    func string(for key: Key) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func set(_ value: String?, for key: Key) -> Bool {
        guard let value, let data = value.data(using: .utf8) else {
            return removeValue(for: key)
        }

        let query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        guard updateStatus == errSecItemNotFound else { return false }

        var insert = query
        insert.merge(attributes) { current, _ in current }

        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func removeValue(for key: Key) -> Bool {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}
