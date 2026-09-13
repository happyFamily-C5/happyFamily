import Foundation
import Security

/// Keychain storage for opaque donor QR tokens. The backend contract forbids
/// logging or persisting QR tokens outside secure local storage, so every
/// token that reaches the app (create booking / booking detail) lands here
/// keyed by booking id.
enum QRTokenKeychain {
    static let service = "happyFamily.donor.qrToken"

    static func save(_ token: String, bookingId: UUID) throws {
        let account = bookingId.uuidString
        var query = baseQuery(account: account)
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        // Upsert semantics: a replayed booking replaces the stored token.
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BackendError.configuration("keychain add failed: \(status)")
        }
    }

    static func token(for bookingId: UUID) -> String? {
        var query = baseQuery(account: bookingId.uuidString)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(bookingId: UUID) throws {
        let status = SecItemDelete(baseQuery(account: bookingId.uuidString) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BackendError.configuration("keychain delete failed: \(status)")
        }
    }

    /// Removes every stored donor QR token. Logout must leave no token in
    /// secure storage: the next session starts from a clean tenant scope.
    static func deleteAll() {
        var query = baseQuery(account: "")
        query.removeValue(forKey: kSecAttrAccount as String)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            // Best-effort by design: a logout must not fail because a token
            // row could not be removed.
            return
        }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
