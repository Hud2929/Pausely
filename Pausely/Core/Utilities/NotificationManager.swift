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
    /// Whether an allowed reminder would actually be seen, and on time.
    private(set) var delivery: ReminderDelivery = .shown

    var isAuthorized: Bool { [.authorized, .provisional, .ephemeral].contains(status) }

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func refreshStatus() async {
        #if DEBUG
        // `--demo-reminders=ask|denied|on|hidden|late` shows a permission state the simulator is
        // not in, so each one's row on Home and its page in Settings can be looked at.
        if let shown = LaunchFlag.value(of: "--demo-reminders"), let demo = Self.demoState(shown) {
            status = demo.status
            delivery = demo.delivery
            return
        }
        #endif
        let settings = await center.notificationSettings()
        status = settings.authorizationStatus
        delivery = ReminderDelivery(banners: settings.alertSetting == .enabled,
                                    lockScreen: settings.lockScreenSetting == .enabled,
                                    notificationCenter: settings.notificationCenterSetting == .enabled,
                                    inScheduledSummary: settings.scheduledDeliverySetting == .enabled)
    }

    #if DEBUG
    nonisolated static func demoState(_ name: String) -> (status: UNAuthorizationStatus, delivery: ReminderDelivery)? {
        switch name {
        case "ask": return (.notDetermined, .shown)
        case "denied": return (.denied, .shown)
        case "on": return (.authorized, .shown)
        case "hidden": return (.authorized, .hidden)
        case "late": return (.authorized, .late)
        default: return nil
        }
    }
    #endif

    /// Shows the system prompt (iOS only shows it once), then rebuilds reminders so they start now.
    @discardableResult
    func requestPermission() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
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

/// "Allowed" is not "seen". iOS lets a person keep an app's notifications allowed while switching off
/// every place they could appear, or hold them for a summary twice a day; a reminder about tomorrow's
/// charge is then invisible or late, and the app must not say "Reminders are on".
enum ReminderDelivery: Equatable {
    /// Shown as it arrives, in at least one place.
    case shown
    /// Allowed, but banners, the Lock Screen and Notification Center are all off.
    case hidden
    /// Held for the Scheduled Summary, so it can arrive hours late.
    case late

    init(banners: Bool, lockScreen: Bool, notificationCenter: Bool, inScheduledSummary: Bool) {
        if !banners && !lockScreen && !notificationCenter {
            self = .hidden
        } else if inScheduledSummary {
            self = .late
        } else {
            self = .shown
        }
    }
}

// MARK: - Delegate

/// Set as the notification center's delegate at launch (see AppDelegate).
/// It keeps nothing of its own, so one instance can be used from anywhere.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
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
            if let subscriptionId {
                await VerdictCenter.shared.keep(subscriptionId: subscriptionId, renewalDay: info["renewal_date"] as? String)
            }
        case UNNotificationDismissActionIdentifier:
            break
        case _ where (info["type"] as? String)?.hasPrefix("pause_plan") == true:
            await VerdictCenter.shared.openPausePlan()
        case _ where (info["type"] as? String) == "savings_avoided":
            await VerdictCenter.shared.openSavingsReceipt()
        default:
            // A tap on the reminder, or "Review": open the decision for that subscription.
            if let subscriptionId { await VerdictCenter.shared.open(subscriptionId: subscriptionId) }
        }
    }
}
