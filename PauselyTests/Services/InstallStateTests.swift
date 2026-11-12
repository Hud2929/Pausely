import XCTest
@testable import Pausely

/// What is left on the phone when someone signs out, deletes their account, or deletes the app and
/// installs it again. The Keychain outlives the app, so each of these has to clear it deliberately.
@MainActor
final class InstallStateTests: XCTestCase {

    func testNothingSavedYetIsAFirstLaunch() {
        XCTAssertTrue(InstallState.isFirstLaunchSinceInstall(savedSettings: nil, settingsFileExists: false))
        XCTAssertTrue(InstallState.isFirstLaunchSinceInstall(savedSettings: [:], settingsFileExists: false))
    }

    /// An update keeps the app's saved settings. It must never be taken for a new install,
    /// or updating would sign everyone out.
    func testAnythingSavedMeansTheAppWasAlreadyHere() {
        XCTAssertFalse(InstallState.isFirstLaunchSinceInstall(savedSettings: ["hasCompletedOnboarding": true], settingsFileExists: true))
        XCTAssertFalse(InstallState.isFirstLaunchSinceInstall(savedSettings: [InstallState.markerKey: true], settingsFileExists: true))
    }

    /// After a restart and before the first unlock, saved settings read as empty although the file is
    /// there. That is a locked phone, not a new install: nobody is signed out and nothing is cleared.
    func testSettingsThatCannotBeReadYetAreNotAFirstLaunch() {
        XCTAssertFalse(InstallState.isFirstLaunchSinceInstall(savedSettings: [:], settingsFileExists: true))
        XCTAssertFalse(InstallState.isFirstLaunchSinceInstall(savedSettings: nil, settingsFileExists: true))
    }

    func testStorageIsLockedOnlyWhenTheFileIsThereAndCannotBeRead() {
        XCTAssertTrue(SavedData.isLocked(settingsAreEmpty: true, settingsFileExists: true, settingsFileCanBeRead: false))
        // A new install: nothing saved and no file. Not locked.
        XCTAssertFalse(SavedData.isLocked(settingsAreEmpty: true, settingsFileExists: false, settingsFileCanBeRead: false))
        // An ordinary launch.
        XCTAssertFalse(SavedData.isLocked(settingsAreEmpty: false, settingsFileExists: true, settingsFileCanBeRead: true))
        // Empty but readable: odd, and not a reason to end a launch.
        XCTAssertFalse(SavedData.isLocked(settingsAreEmpty: true, settingsFileExists: true, settingsFileCanBeRead: true))
        // Something came back, so storage is open whatever else is true.
        XCTAssertFalse(SavedData.isLocked(settingsAreEmpty: false, settingsFileExists: true, settingsFileCanBeRead: false))
    }

    /// The test app runs with the phone unlocked: its storage is never taken for locked.
    func testThisLaunchIsNotLocked() {
        XCTAssertFalse(SavedData.lockedAtLaunch)
    }

    /// What the app keeps in the Keychain can be read while the phone is locked (after its first
    /// unlock), and an item saved by an earlier version becomes readable the next time it is saved.
    func testKeychainItemsAreReadableWhileThePhoneIsLocked() throws {
        let service = "com.pausely.app.tests.\(UUID().uuidString)"
        let keychain = KeychainManager(service: service)
        defer { keychain.deleteAll() }

        func accessibility(of key: String) -> String? {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                        kSecAttrAccount as String: key, kSecReturnAttributes as String: true,
                                        kSecMatchLimit as String: kSecMatchLimitOne]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
            return (result as? [String: Any])?[kSecAttrAccessible as String] as? String
        }

        keychain.save("user-1", forKey: "auth_cached_user_id")
        XCTAssertEqual(accessibility(of: "auth_cached_user_id"), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)

        // As an earlier version saved it: readable only while unlocked.
        let old: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                  kSecAttrAccount as String: "older", kSecValueData as String: Data("a".utf8),
                                  kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        XCTAssertEqual(SecItemAdd(old as CFDictionary, nil), errSecSuccess)
        keychain.save("b", forKey: "older")
        XCTAssertEqual(keychain.get("older"), "b")
        XCTAssertEqual(accessibility(of: "older"), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    func testClearingAKeychainServiceRemovesEveryItemInIt() {
        let keychain = KeychainManager(service: "com.pausely.app.tests.\(UUID().uuidString)")
        keychain.save("user-1", forKey: "auth_cached_user_id")
        keychain.save("Jane", forKey: "profile_user-1_firstName")
        XCTAssertEqual(keychain.get("auth_cached_user_id"), "user-1")

        keychain.deleteAll()

        XCTAssertNil(keychain.get("auth_cached_user_id"))
        XCTAssertNil(keychain.get("profile_user-1_firstName"))
    }

    func testClearingOneServiceLeavesAnotherAlone() {
        let first = KeychainManager(service: "com.pausely.app.tests.\(UUID().uuidString)")
        let second = KeychainManager(service: "com.pausely.app.tests.\(UUID().uuidString)")
        first.save("a", forKey: "key")
        second.save("b", forKey: "key")

        first.deleteAll()

        XCTAssertNil(first.get("key"))
        XCTAssertEqual(second.get("key"), "b")
        second.deleteAll()
    }

    /// The name is kept in the Keychain under the account's id, so that Apple, which gives a name only
    /// the first time, doesn't leave a returning person nameless. Deleting the account removes it.
    func testForgettingAProfileRemovesTheNameKeptForThatAccount() {
        let id = "test-\(UUID().uuidString)"
        KeychainManager.shared.save("Jane", forKey: "profile_\(id)_firstName")
        KeychainManager.shared.save("Doe", forKey: "profile_\(id)_lastName")

        AccountMemory.forgetName(userId: id)

        XCTAssertNil(KeychainManager.shared.get("profile_\(id)_firstName"))
        XCTAssertNil(KeychainManager.shared.get("profile_\(id)_lastName"))
    }
}
