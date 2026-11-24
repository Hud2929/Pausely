import Foundation
import UIKit
import UserNotifications
import os.log

/// "Keep it" pressed on a reminder before the phone's first unlock after a restart.
///
/// Nothing the app saved can be read then, and anything saved could replace it (`SavedData`), so such
/// a launch ends before the app starts. The press itself is written down first, in a file of its own
/// that iOS lets the app read and write even then. It holds only which subscription, the day of the
/// charge the reminder was about and when the button was pressed: no name, no amount. The next launch
/// with the phone unlocked records each press as a Keep (`VerdictCenter.keepPressedWhileLocked`) and
/// removes the file.
enum LockedKeeps {
    struct Press: Codable, Equatable {
        let subscriptionId: UUID
        /// The charge's day as stamped on the reminder ("renewal_date").
        let renewalDay: String?
        let pressedAt: Date
    }

    /// In Library, which exists from the install on, outside the folders that hold the app's data.
    static var file: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeepPressedWhileLocked.json")
    }

    /// The press a reminder's button stands for, or nil for anything that is not "Keep it" on a reminder.
    static func press(action: String, userInfo: [AnyHashable: Any], at date: Date) -> Press? {
        guard action == ReminderActions.keep,
              let id = (userInfo["subscription_id"] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
        return Press(subscriptionId: id, renewalDay: userInfo["renewal_date"] as? String, pressedAt: date)
    }

    /// The other reminders about the charge that was kept ("charges tomorrow", "charges today"), which
    /// would otherwise still go off before the app is next opened. Read from their names
    /// (`ReminderPlanner`), so nothing saved has to be read.
    static func reminders(about press: Press, among identifiers: [String]) -> [String] {
        guard let day = press.renewalDay else { return [] }
        let charge = ".\(press.subscriptionId.uuidString).\(day)"
        return identifiers.filter { $0.hasPrefix(ReminderPlanner.identifierPrefix) && $0.hasSuffix(charge) }
    }

    /// Adds a press to the file. The file is written without data protection on purpose: before the
    /// first unlock no other kind can be written, and what it holds says nothing about the person.
    static func note(_ press: Press, at url: URL = file) {
        var presses = read(url)
        presses.append(press)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(presses).write(to: url, options: [.atomic, .noFileProtection])
        } catch {
            // Nothing about the press is logged; that it failed is what a device check needs to see.
            os_log("A Keep pressed while locked could not be written down", log: .default, type: .error)
        }
    }

    /// The presses waiting, oldest first, and the file gone.
    static func take(from url: URL = file) -> [Press] {
        let presses = read(url)
        try? FileManager.default.removeItem(at: url)
        return presses
    }

    private static func read(_ url: URL) -> [Press] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Press].self, from: data)) ?? []
    }
}

/// The notification delegate for a launch before the first unlock: it writes down "Keep it", takes
/// away that charge's other reminders, and touches nothing else; then the launch ends, as it always
/// has. Every other tap needs the phone unlocked and the app open, so it is left for then.
final class LockedLaunchDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = LockedLaunchDelegate()

    /// True for a launch that began in the background before the phone's first unlock. Shortcuts count
    /// as signed out meanwhile (`ShortcutProblem.isSignedIn`).
    @MainActor static var isActive = false

    /// Set as the delegate before launch finishes, so the press that started the app is delivered.
    /// The launch is held awake for that (iOS could otherwise suspend it and bring it back, blank, when
    /// the person later opens the app) and ends once the press is written down, after a few seconds if
    /// none comes, or the moment it would come to the front.
    @MainActor func start() {
        UNUserNotificationCenter.current().delegate = self
        _ = UIApplication.shared.beginBackgroundTask { exit(0) }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                               object: nil, queue: .main) { _ in exit(0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { exit(0) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let press = LockedKeeps.press(action: response.actionIdentifier,
                                            userInfo: response.notification.request.content.userInfo, at: Date()) else {
            exit(0)
        }
        LockedKeeps.note(press)
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: LockedKeeps.reminders(about: press, among: pending))
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: LockedKeeps.reminders(about: press, among: delivered))
        // The removals are handed to iOS; a moment for them to leave, then the launch ends.
        try? await Task.sleep(for: .milliseconds(300))
        exit(0)
    }
}
