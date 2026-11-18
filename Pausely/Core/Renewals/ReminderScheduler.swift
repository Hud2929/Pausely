import Foundation
import UserNotifications
import os.log

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
    /// Callers that arrived during a pass. Each returns once a pass that started after it has finished,
    /// so "Keep it" from a notification does not report done (and let iOS suspend the app) while the
    /// kept charge's reminders are still waiting to go off.
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func reschedule(_ subscriptions: [Subscription], now: Date = Date()) async {
        // Coalesce overlapping calls: the last state always wins.
        if isRunning {
            needsAnotherPass = true
            await withCheckedContinuation { waiting.append($0) }
            return
        }
        isRunning = true

        var current = subscriptions
        repeat {
            needsAnotherPass = false
            let covered = waiting
            waiting = []
            await apply(current, now: now)
            covered.forEach { $0.resume() }
            current = SubscriptionStore.shared.subscriptions
        } while needsAnotherPass
        isRunning = false
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
        let pausePlan = PausePlanStore.shared.activePlan
        for reminder in ReminderPlanner.plan(for: subscriptions, now: now, preferences: Self.preferences, kept: kept,
                                             pausePlan: pausePlan) {
            guard let sub = byId[reminder.subscriptionId] else { continue }
            await add(UNNotificationRequest(
                identifier: reminder.identifier,
                content: Self.content(for: reminder, subscription: sub),
                trigger: UNCalendarNotificationTrigger(dateMatching: Self.triggerDate(for: reminder.fireDate), repeats: false)
            ))
        }
        // Reminders are planned a couple of renewals ahead. If the app isn't opened in all that time,
        // the last thing it sends says so, instead of going quiet.
        if let refill = ReminderPlanner.refillDate(for: subscriptions, now: now, preferences: Self.preferences, kept: kept,
                                                   pausePlan: pausePlan) {
            await add(UNNotificationRequest(
                identifier: ReminderPlanner.refillIdentifier,
                content: Self.refillContent(),
                trigger: UNCalendarNotificationTrigger(dateMatching: Self.triggerDate(for: refill), repeats: false)
            ))
        }
    }

    /// A reminder iOS refuses is one the person won't get: it leaves a trace in the log.
    private func add(_ request: UNNotificationRequest) async {
        do {
            try await center.add(request)
        } catch {
            os_log("A reminder could not be scheduled: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }
    }

    static func refillContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = L10n.string("Your renewal reminders need a refresh")
        content.body = L10n.string("Open Pausely once and it plans the next ones.")
        content.sound = .default
        content.userInfo = ["type": "refill"]
        return content
    }

    /// The moment a reminder fires, as the notification center wants it: year, month, day, hour and
    /// minute in the Gregorian calendar, and saying so. Without the calendar, a phone that shows the
    /// Buddhist calendar would look for the year 2026 of its own era.
    nonisolated static func triggerDate(for fireDate: Date) -> DateComponents {
        var components = Calendar.billing.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        components.calendar = .billing
        return components
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
        let day = reminder.eventDate.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
        switch reminder.kind {
        case .renewalHeadsUp:
            content.title = L10n.string("\(sub.name) renews \(L10n.relativeDay(reminder.daysBefore))")
            content.body = L10n.string("\(amount) on \(day). Keep it or cancel it?")
        case .renewalTomorrow:
            content.title = L10n.string("\(sub.name) charges tomorrow")
            content.body = L10n.string("\(amount) tomorrow. Cancel today if you don't want it to renew.")
        case .renewalToday:
            content.title = L10n.string("\(sub.name) renews today")
            content.body = L10n.string("\(amount) is due today.")
        case .trialEnding:
            content.title = L10n.string("\(sub.name) trial ends tomorrow")
            content.body = L10n.string("After that it costs \(amount) \(sub.billingFrequency.billingPeriodLabel). Keep it or cancel it?")
        case .planCancel:
            content.title = L10n.string("Pause Plan: cancel \(sub.name) today")
            content.body = L10n.string("It renews tomorrow for \(amount). Cancel today and it comes back on its turn.")
        case .planStart:
            content.title = L10n.string("Pause Plan: \(sub.name) is on")
            content.body = L10n.string("Its month starts today. Start it again whenever you're ready to watch.")
        }
        switch reminder.kind {
        case .planCancel, .planStart: content.categoryIdentifier = ReminderActions.pausePlanCategory
        default: content.categoryIdentifier = ReminderActions.decisionCategory
        }
        content.sound = .default
        content.userInfo = [
            "subscription_id": sub.id.uuidString,
            "type": reminder.kind.notificationType,
            "renewal_date": ReminderPlanner.dayStamp(reminder.eventDate, .billing)
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
        case .planCancel: return "pause_plan_cancel"
        case .planStart: return "pause_plan_start"
        }
    }
}
