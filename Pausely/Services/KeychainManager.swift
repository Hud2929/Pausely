import Foundation
import Security

// MARK: - Keychain Manager
/// Securely stores sensitive credentials using iOS Keychain
@MainActor
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.pausely.app"

    private init() {}


    // MARK: - Save


    // MARK: - Retrieve


    // MARK: - Delete


    // MARK: - String-Based API (for compatibility with legacy KeychainService)

    /// Save a string value for a given key string
    func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            let newItem: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            if addStatus != errSecSuccess {
                PauselyLogger.error("Keychain save failed: \(addStatus)", category: "Keychain")
            }
        } else if status != errSecSuccess {
            PauselyLogger.error("Keychain update failed: \(status)", category: "Keychain")
        }
    }

    /// Retrieve a string value for a given key string
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// Delete a value for a given key string
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            PauselyLogger.error("Keychain delete failed: \(deleteStatus)", category: "Keychain")
        }
    }
}
