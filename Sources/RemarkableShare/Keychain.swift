import Foundation
import RemarkableShareCore
import Security

/// Stores the stream password (not the tablet root password — that is never persisted).
enum Keychain {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: TabletConfig.keychainService,
            kSecAttrAccount as String: TabletConfig.keychainAccount,
        ]
    }

    static func streamPassword() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Returns the stored password, creating one if none exists (or the stored one is unusable).
    static func ensureStreamPassword() -> String {
        if let existing = streamPassword(), PasswordPolicy.isSafe(existing) { return existing }
        let fresh = PasswordPolicy.generate()
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(fresh.utf8)
        add[kSecAttrLabel as String] = "reMarkable Share stream password"
        SecItemAdd(add as CFDictionary, nil)
        return fresh
    }
}
