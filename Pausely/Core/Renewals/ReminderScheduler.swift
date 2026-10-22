import Foundation
import UserNotifications

/// Applies `ReminderPlanner`'s plan to the notification center: every pending Pausely reminder is
/// removed and the current plan is added. Call it after any change to subscriptions and on each launch.
@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    /// Identifiers used before the planner existed. Removed so old one-shot reminders cannot linger
    /// (they were never cancelled when a subscription was deleted).
    nonisolated static let legacyPrefixes = ["renewal-", "trial-"]

    private let center = UNUserNotificationCenter.current()
    private var isRunning = false
    private var needsAnotherPass = false

    func reschedule(_ subscriptions: [Subscription], now: Date = Date()) async {
        // Coalesce overlapping calls: the last state always wins.
        if isRunning { needsAnotherPass = true; return }
        isRunning = true
        defer { isRunning = false }

        var current = subscriptions
        repeat {
            needsAnotherPass = false
            await apply(current, now: now)
            current = SubscriptionStore.shared.subscriptions
        } while needsAnotherPass
    }

    private func apply(_ subscriptions: [Subscription], now: Date) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter(Self.isPauselyReminder)
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let settings = await center.notificationSettings()
        let allowed: Set<UNAuthorizationStatus> = [.authorized, .provisional, .ephemeral]
        guard allowed.contains(settings.authorizationStatus) else { return }

        let byId = Dictionary(subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let kept = RenewalDecisions.keptKeys(in: LifecycleEventLog.shared.events)
        for reminder in ReminderPlanner.plan(for: subscriptions, now: now, preferences: Self.preferences, kept: kept) {
            guard let sub = byId[reminder.subscriptionId] else { continue }
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: Self.content(for: reminder, subscription: sub),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// The two switches in Settings → Notifications. Both default to on.
    static let renewalRemindersKey = "renewalAlerts"
    static let trialRemindersKey = "trialEndingAlerts"

    static var preferences: ReminderPlanner.Preferences {
        let defaults = UserDefaults.standard
        return ReminderPlanner.Preferences(
            renewals: defaults.object(forKey: renewalRemindersKey) as? Bool ?? true,
            trials: defaults.object(forKey: trialRemindersKey) as? Bool ?? true
        )
    }

    nonisolated static func isPauselyReminder(_ identifier: String) -> Bool {
        identifier.hasPrefix(ReminderPlanner.identifierPrefix) || legacyPrefixes.contains { identifier.hasPrefix($0) }
    }

    static func content(for reminder: ReminderPlanner.Reminder, subscription sub: Subscription) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let amount = sub.displayAmount
        let day = reminder.eventDate.formatted(.dateTime.month(.abbreviated).day())
        switch reminder.kind {
        case .renewalHeadsUp:
            content.title = String(localized: "\(sub.name) renews in \(reminder.daysBefore) days")
            content.body = String(localized: "\(amount) on \(day). Keep it or cancel it?")
        case .renewalTomorrow:
            content.title = String(localized: "\(sub.name) charges tomorrow")
            content.body = String(localized: "\(amount) tomorrow. Cancel today if you don't want it to renew.")
        case .renewalToday:
            content.title = String(localized: "\(sub.name) renews today")
            content.body = String(localized: "\(amount) is due today.")
        case .trialEnding:
            content.title = String(localized: "\(sub.name) trial ends tomorrow")
            content.body = String(localized: "After that it costs \(amount) \(sub.billingFrequency.billingPeriodLabel). Keep it or cancel it?")
        }
        content.categoryIdentifier = ReminderActions.decisionCategory
        content.sound = .default
        content.userInfo = [
            "subscription_id": sub.id.uuidString,
            "type": reminder.kind.notificationType,
            "renewal_date": ReminderPlanner.dayStamp(reminder.eventDate, .current)
        ]
        return content
    }
}

extension ReminderPlanner.Kind {
    /// The `type` value the notification delegate already understands.
    var notificationType: String {
        switch self {
        case .renewalHeadsUp: return "renewal"
        case .renewalTomorrow: return "renewal_urgent"
        case .renewalToday: return "renewal_day_of"
        case .trialEnding: return "trial_ending"
        }
    }
}
