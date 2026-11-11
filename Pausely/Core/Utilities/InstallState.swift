import Foundation

/// Whether this is the first launch since the app was installed.
///
/// The Keychain outlives the app. Delete Pausely, install it again, and the last person's sign-in and
/// mail passwords are still there while everything else they had is gone: the app would open signed in
/// as them, on the age check, with an empty list. So on the first launch after an install whatever the
/// Keychain holds is cleared and the app starts signed out.
///
/// The test is whether anything at all has been saved for the app yet. An update keeps the saved
/// settings and a fresh install has none. It leans towards "not a first launch": an update never
/// signs anyone out.
enum InstallState {
    static let markerKey = "install_marker"

    static func isFirstLaunchSinceInstall(savedSettings: [String: Any]?) -> Bool {
        (savedSettings ?? [:]).isEmpty
    }

    /// Worked out once, and it has to be before anything is saved in this launch: `PauselyApp.init`
    /// reads it first thing.
    static let firstLaunch: Bool = {
        let defaults = UserDefaults.standard
        let saved = Bundle.main.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0) }
        let first = isFirstLaunchSinceInstall(savedSettings: saved)
        defaults.set(true, forKey: markerKey)
        return first
    }()
}
