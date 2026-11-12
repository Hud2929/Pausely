import Foundation

/// Pausely's version of Lago's clock: the time-driven changes that happen even when nobody edits
/// anything. Runs when subscriptions load and whenever the app comes to the foreground.
///  1. A free trial whose end date has passed starts charging (status trial -> active).
///  2. Renewals that happened since the last run are recorded in the event log.
///  3. All reminders are rebuilt from the current subscriptions.
@MainActor
final class SubscriptionLifecycle {
    static let shared = SubscriptionLifecycle()

    struct Changes: Equatable {
        struct Renewal: Equatable { let subscriptionId: UUID; let date: Date }
        var endedTrials: [UUID: Date] = [:]
        var renewals: [Renewal] = []
    }

    private let lastRunKey = "lifecycle_last_run"
    private var isRunning = false

    /// Pure: what changed between `lastRun` and `now`. On the very first run nothing is back-filled.
    static func changes(for subscriptions: [Subscription], since lastRun: Date?, now: Date,
                        calendar: Calendar = .current) -> Changes {
        var changes = Changes()
        let today = calendar.startOfDay(for: now)
        for sub in subscriptions {
            if sub.status == .trial, let end = sub.trialEndsAt, calendar.startOfDay(for: end) < today {
                changes.endedTrials[sub.id] = end
            }
            guard let lastRun, sub.renewsAutomatically, let anchor = sub.nextBillingDate else { continue }
            for date in RenewalSchedule.renewals(anchor: anchor, frequency: sub.billingFrequency,
                                                 after: lastRun, through: now, calendar: calendar) {
                changes.renewals.append(.init(subscriptionId: sub.id, date: date))
            }
        }
        return changes
    }

    /// A trial that has ended is charging now. The day it ended was its first charge, so when no
    /// renewal date was ever set, that day (which the person entered) becomes it.
    static func afterTrial(_ trial: Subscription, endedOn end: Date, now: Date) -> Subscription {
        var active = trial
        active.status = .active
        active.updatedAt = now
        if active.nextBillingDate == nil { active.nextBillingDate = end }
        return active
    }

    func run(now: Date = Date()) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let store = SubscriptionStore.shared
        let lastRun = UserDefaults.standard.object(forKey: lastRunKey) as? Date
        let changes = Self.changes(for: store.subscriptions, since: lastRun, now: now)

        for (id, endDate) in changes.endedTrials {
            guard let trial = store.subscriptions.first(where: { $0.id == id }) else { continue }
            let sub = Self.afterTrial(trial, endedOn: endDate, now: now)
            await store.updateSubscription(sub)
            LifecycleEventLog.shared.record(.trialEnded, for: sub, date: endDate)
        }
        for renewal in changes.renewals {
            guard let sub = store.subscriptions.first(where: { $0.id == renewal.subscriptionId }) else { continue }
            LifecycleEventLog.shared.record(.renewed, for: sub, date: renewal.date)
        }

        UserDefaults.standard.set(now, forKey: lastRunKey)
        await ReminderScheduler.shared.reschedule(store.subscriptions, now: now)
    }
}
