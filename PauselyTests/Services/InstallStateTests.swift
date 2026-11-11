import XCTest
@testable import Pausely

/// What is left on the phone when someone signs out, deletes their account, or deletes the app and
/// installs it again. The Keychain outlives the app, so each of these has to clear it deliberately.
@MainActor
final class InstallStateTests: XCTestCase {

    func testNothingSavedYetIsAFirstLaunch() {
        XCTAssertTrue(InstallState.isFirstLaunchSinceInstall(savedSettings: nil))
        XCTAssertTrue(InstallState.isFirstLaunchSinceInstall(savedSettings: [:]))
    }

    /// An update keeps the app's saved settings. It must never be taken for a new install,
    /// or updating would sign everyone out.
    func testAnythingSavedMeansTheAppWasAlreadyHere() {
        XCTAssertFalse(InstallState.isFirstLaunchSinceInstall(savedSettings: ["hasCompletedOnboarding": true]))
        XCTAssertFalse(InstallState.isFirstLaunchSinceInstall(savedSettings: [InstallState.markerKey: true]))
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

        RevolutionaryAuthManager.forgetProfile(userId: id)

        XCTAssertNil(KeychainManager.shared.get("profile_\(id)_firstName"))
        XCTAssertNil(KeychainManager.shared.get("profile_\(id)_lastName"))
    }
}
