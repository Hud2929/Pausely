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

    /// Pause Plan handoffs: a tap opens the plan.
    static let pausePlanCategory = "PAUSE_PLAN"

    /// Registered on every launch; iOS forgets categories that aren't re-registered.
    static func registerCategories(on center: UNUserNotificationCenter = .current()) {
        let keepAction = UNNotificationAction(identifier: keep, title: L10n.string("Keep it"), options: [])
        let reviewAction = UNNotificationAction(identifier: review, title: L10n.string("Review"), options: [.foreground])
        let decision = UNNotificationCategory(identifier: decisionCategory, actions: [keepAction, reviewAction],
                                              intentIdentifiers: [], options: [])
        let plan = UNNotificationCategory(identifier: pausePlanCategory, actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([decision, plan])
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

        switch response.actionIdentifier {
        case ReminderActions.keep:
            // Handled without opening the app: record the decision and drop the remaining reminders.
            if let subscriptionId { await VerdictCenter.shared.keep(subscriptionId: subscriptionId) }
        case UNNotificationDismissActionIdentifier:
            break
        case _ where (info["type"] as? String)?.hasPrefix("pause_plan") == true:
            await VerdictCenter.shared.openPausePlan()
        default:
            // A tap on the reminder, or "Review": open the decision for that subscription.
            if let subscriptionId { await VerdictCenter.shared.open(subscriptionId: subscriptionId) }
        }
    }
}
