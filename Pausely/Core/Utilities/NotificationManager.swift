//
//  NotificationManager.swift
//  Pausely
//
//  Notification permission, categories and the delegate that turns a reminder tap into a decision.
//  Which reminders exist is decided by ReminderPlanner and applied by ReminderScheduler.
//

import Foundation
@preconcurrency import UserNotifications
import UIKit

/// The buttons on Pausely's notifications.
enum ReminderActions {
    /// Every renewal and trial reminder: decide right from the notification.
    static let decisionCategory = "RENEWAL_DECISION"
    static let keep = "KEEP"
    static let review = "REVIEW"

    /// Reminders created by the "Pause" Shortcut.
    static let pauseCategory = "PAUSE_REMINDER"
    static let openPausePage = "OPEN_PAUSE_PAGE"

    /// Registered on every launch; iOS forgets categories that aren't re-registered.
    static func registerCategories(on center: UNUserNotificationCenter = .current()) {
        let keepAction = UNNotificationAction(identifier: keep, title: String(localized: "Keep it"), options: [])
        let reviewAction = UNNotificationAction(identifier: review, title: String(localized: "Review"), options: [.foreground])
        let decision = UNNotificationCategory(identifier: decisionCategory, actions: [keepAction, reviewAction],
                                              intentIdentifiers: [], options: [])
        let openPause = UNNotificationAction(identifier: openPausePage, title: String(localized: "Open Pause Page"), options: [.foreground])
        let pause = UNNotificationCategory(identifier: pauseCategory, actions: [openPause], intentIdentifiers: [], options: [])
        center.setNotificationCategories([decision, pause])
    }
}

@Observable
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    /// What iOS currently allows. Refreshed on launch and whenever the app becomes active.
    private(set) var status: UNAuthorizationStatus = .notDetermined

    var isAuthorized: Bool { [.authorized, .provisional, .ephemeral].contains(status) }

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    /// Shows the system prompt (iOS only shows it once), then rebuilds reminders so they start now.
    @discardableResult
    func requestPermission() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshStatus()
        ReminderActions.registerCategories(on: center)
        await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions)
        return granted
    }

    /// For people who said no earlier: iOS Settings is the only place to turn reminders back on.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Pause reminders (Shortcuts)

    func schedulePauseReminder(for subscription: Subscription, reminderDate: Date, pauseURL: String?) {
        cancelPauseReminder(for: subscription.id)
        guard reminderDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Reminder: Pause \(subscription.name)"
        content.body = "Tap to open \(subscription.name)'s pause page."
        content.sound = .default
        content.categoryIdentifier = ReminderActions.pauseCategory
        content.userInfo = [
            "subscription_id": subscription.id.uuidString,
            "type": "pause_reminder",
            "pause_url": pauseURL ?? ""
        ]
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        dateComponents.hour = 9
        dateComponents.minute = 0
        let request = UNNotificationRequest(
            identifier: "pause-reminder-\(subscription.id.uuidString)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        )
        Task {
            await refreshStatus()
            guard isAuthorized else { return }
            try? await center.add(request)
        }
    }

    func cancelPauseReminder(for subscriptionId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            "pause-\(subscriptionId.uuidString)",
            "pause-reminder-\(subscriptionId.uuidString)"
        ])
    }

    func cancelReminder(for subscriptionId: UUID) {
        let id = subscriptionId.uuidString
        center.getPendingNotificationRequests { [center] requests in
            let matching = requests.map(\.identifier).filter {
                $0.contains(id) && (ReminderScheduler.isPauselyReminder($0) || $0.hasPrefix("pause-"))
            }
            center.removePendingNotificationRequests(withIdentifiers: matching)
        }
    }
}

// MARK: - Delegate

/// Set as the notification center's delegate at launch (see AppDelegate).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Reminders still show while Pausely is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let subscriptionId = (info["subscription_id"] as? String).flatMap(UUID.init(uuidString:))
        let pauseURL = (info["pause_url"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }

        switch response.actionIdentifier {
        case ReminderActions.keep:
            // Handled without opening the app: record the decision and drop the remaining reminders.
            if let subscriptionId { await VerdictCenter.shared.keep(subscriptionId: subscriptionId) }
        case ReminderActions.openPausePage:
            if let pauseURL {
                await MainActor.run { UIApplication.shared.open(pauseURL) }
            } else if let subscriptionId {
                await VerdictCenter.shared.showSubscription(subscriptionId)
            }
        case UNNotificationDismissActionIdentifier:
            break
        default:
            // A tap on the reminder, or "Review": open the decision for that subscription.
            if let subscriptionId { await VerdictCenter.shared.open(subscriptionId: subscriptionId) }
        }
    }
}
