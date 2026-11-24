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
/// signs anyone out, and neither does a launch while the phone's storage is still locked.
enum InstallState {
    static let markerKey = "install_marker"

    /// A first launch has nothing saved and no settings file on disk. The file matters: after a restart
    /// and before the phone's first unlock, saved settings read as empty although they are all there
    /// (see `SavedData`), and that must never pass for a new install.
    static func isFirstLaunchSinceInstall(savedSettings: [String: Any]?, settingsFileExists: Bool) -> Bool {
        (savedSettings ?? [:]).isEmpty && !settingsFileExists
    }

    /// Worked out once, and it has to be before anything is saved in this launch: `PauselyApp.init`
    /// reads it first thing.
    static let firstLaunch: Bool = {
        let defaults = UserDefaults.standard
        let saved = Bundle.main.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0) }
        let first = isFirstLaunchSinceInstall(savedSettings: saved, settingsFileExists: SavedData.settingsFileExists)
        defaults.set(true, forKey: markerKey)
        return first
    }()
}

/// Whether what the app has saved can be read right now.
///
/// After a restart, iOS keeps an app's saved settings and files encrypted until the phone has been
/// unlocked once. An app can still be started in that window: by a reminder's button pressed on the
/// Lock Screen, or by iOS warming the app up. Saved settings then read as if nothing had ever been
/// saved, with no error, and what the app saves in that state can replace the real thing
/// (christianselig.com/2024/10/beware-userdefaults; developer.apple.com/forums/thread/667959).
/// Pausely would take itself for a new install, clear the Keychain and lose the changes still waiting
/// to be sent.
///
/// So the app looks before it trusts an empty answer. If the settings file is on disk and its bytes
/// can't be read, storage is locked, and a launch in the background ends there: before anything is
/// read, decided or saved. The next launch, with the phone unlocked, starts normally.
enum SavedData {
    static func isLocked(settingsAreEmpty: Bool, settingsFileExists: Bool, settingsFileCanBeRead: Bool) -> Bool {
        settingsAreEmpty && settingsFileExists && !settingsFileCanBeRead
    }

    /// Where iOS keeps the app's saved settings.
    static var settingsFile: URL? {
        guard let id = Bundle.main.bundleIdentifier,
              let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        return library.appendingPathComponent("Preferences", isDirectory: true).appendingPathComponent("\(id).plist")
    }

    static var settingsFileExists: Bool {
        settingsFile.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    /// Worked out once, before anything else in the launch.
    static let lockedAtLaunch: Bool = {
        guard let file = settingsFile, let id = Bundle.main.bundleIdentifier else { return false }
        let saved = UserDefaults.standard.persistentDomain(forName: id) ?? [:]
        let canBeRead: Bool
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            canBeRead = try handle.read(upToCount: 1) != nil
        } catch {
            canBeRead = false
        }
        return isLocked(settingsAreEmpty: saved.isEmpty,
                        settingsFileExists: FileManager.default.fileExists(atPath: file.path),
                        settingsFileCanBeRead: canBeRead)
    }()
}
