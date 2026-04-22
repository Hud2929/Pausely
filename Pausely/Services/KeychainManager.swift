import Foundation
import Security

// MARK: - Keychain Manager
/// Securely stores sensitive credentials using iOS Keychain
@MainActor
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.pausely.app"

    private init() {}

    enum KeychainError: Error, LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidStatus(OSStatus)
        case conversionFailed
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Credential not found in Keychain"
            case .duplicateItem:
                return "Credential already exists"
            case .invalidStatus(let status):
                return "Keychain error: \(SecCopyErrorMessageString(status, nil) as? String ?? "Unknown") (\(status))"
            case .conversionFailed:
                return "Failed to convert credential data"
            case .accessDenied:
                return "Access denied to Keychain"
            }
        }
    }

    enum KeychainKey: String, CaseIterable {
        case customerPortalToken = "customer_portal_token"
        case licenseKey = "license_key"

        var account: String { self.rawValue }
    }

    // MARK: - Save

    func save(_ data: String, for key: KeychainKey) throws {
        guard let dataToSave = data.data(using: .utf8) else {
            throw KeychainError.conversionFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: dataToSave,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            let newItem: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key.account,
                kSecValueData as String: dataToSave,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.invalidStatus(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.invalidStatus(status)
        }
    }

    // MARK: - Retrieve

    func retrieve(for key: KeychainKey) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainError.itemNotFound }
            throw KeychainError.invalidStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.conversionFailed
        }

        return string
    }

    // MARK: - Delete

    func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.invalidStatus(status)
        }
    }

    func clearAllCredentials() {
        for key in KeychainKey.allCases {
            try? delete(for: key)
        }
    }

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
                #if DEBUG
                print("Keychain save failed: \(addStatus)")
                #endif
            }
        } else if status != errSecSuccess {
            #if DEBUG
            print("Keychain update failed: \(status)")
            #endif
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
            #if DEBUG
            print("Keychain delete failed: \(deleteStatus)")
            #endif
        }
    }
}
