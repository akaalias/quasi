import Foundation
import Security

/// Secrets the user enters in the app, kept in the system keychain.
enum Keychain {
    enum Secret: String {
        case anthropicKey = "anthropic-api-key"
        case todoistToken = "todoist-api-token"
    }

    private static let service = "com.alexisrondeau.Quasi"

    static func read(_ secret: Secret) -> String? {
        var query = base(secret)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Stores the value, or removes the secret when the value is nil or empty.
    static func write(_ value: String?, for secret: Secret) {
        SecItemDelete(base(secret) as CFDictionary)
        guard let value, !value.isEmpty else { return }
        var item = base(secret)
        item[kSecValueData as String] = Data(value.utf8)
        // Readable while the iPhone is locked, since recordings are processed in the background.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func base(_ secret: Secret) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: secret.rawValue]
    }
}
