import Foundation
import Security

// MARK: - Keychain Manager
/// Securely stores sensitive credentials using iOS Keychain
@MainActor
final class KeychainManager {
    static let shared = KeychainManager()

    private let service: String

    /// Readable once the phone has been unlocked after a restart, like the session the sign-in library
    /// keeps. A reminder's "Keep it" runs while the phone is locked: with "only while unlocked" the app
    /// could not tell who was signed in, and the button did nothing.
    private static let readable = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    /// The app uses `shared`. Tests make their own with a service of their own, so they never touch
    /// what the app keeps.
    init(service: String = "com.pausely.app") {
        self.service = service
    }

    /// Removes every item kept under this service. Used on the first launch after an install, when
    /// anything found here was left by a copy of the app that has since been deleted.
    func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            PauselyLogger.error("Keychain clear failed: \(status)", category: "Keychain")
        }
    }


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
            kSecAttrAccessible as String: Self.readable
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            let newItem: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: Self.readable
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
