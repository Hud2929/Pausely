import Foundation

/// Which renewals are waiting for a keep-or-cancel decision, and which were already decided.
/// Pure: works on the subscriptions and the event log, so the dashboard, the reminders and the tests
/// all agree.
enum RenewalDecisions {

    /// What is up for a decision: the next charge, or the end of a free trial.
    struct Pending: Equatable, Identifiable {
        let subscriptionId: UUID
        /// The renewal or trial end, at local noon.
        let date: Date
        let isTrialEnd: Bool
        var id: UUID { subscriptionId }
    }

    static func key(_ subscriptionId: UUID, _ date: Date, _ calendar: Calendar = .current) -> String {
        "\(subscriptionId.uuidString)|\(ReminderPlanner.dayStamp(date, calendar))"
    }

    /// Keys of every renewal the user chose to keep.
    static func keptKeys(in events: [LifecycleEvent], calendar: Calendar = .current) -> Set<String> {
        Set(events.compactMap { event in
            guard event.kind == .kept, let renewal = event.renewalDate else { return nil }
            return key(event.subscriptionId, renewal, calendar)
        })
    }

    /// The charge a decision is about right now: the trial end for a trial that hasn't ended,
    /// otherwise the next renewal. Nil when nothing will be charged.
    static func upcomingCharge(for sub: Subscription, now: Date, calendar: Calendar = .current) -> (date: Date, isTrialEnd: Bool)? {
        guard sub.renewsAutomatically else { return nil }
        let today = calendar.startOfDay(for: now)
        if sub.status == .trial, let end = sub.trialEndsAt, calendar.startOfDay(for: end) >= today {
            return (calendar.noon(of: end), true)
        }
        guard let next = sub.nextRenewal(onOrAfter: now, calendar: calendar) else { return nil }
        return (next, false)
    }

    /// The decision waiting for this subscription: its next charge falls inside its reminder window
    /// (at least the day before) and the user hasn't kept it yet. "Remind me: Off" means never ask.
    static func pending(for sub: Subscription, kept: Set<String>, now: Date,
                        calendar: Calendar = .current) -> Pending? {
        guard sub.notifyBeforeDays > 0, let charge = upcomingCharge(for: sub, now: now, calendar: calendar) else { return nil }
        let days = calendar.calendarDays(from: calendar.startOfDay(for: now), to: charge.date)
        guard days >= 0, days <= max(sub.notifyBeforeDays, 1) else { return nil }
        guard !kept.contains(key(sub.id, charge.date, calendar)) else { return nil }
        return Pending(subscriptionId: sub.id, date: charge.date, isTrialEnd: charge.isTrialEnd)
    }

    /// Every decision waiting right now, soonest first.
    static func pending(in subscriptions: [Subscription], events: [LifecycleEvent], now: Date,
                        calendar: Calendar = .current) -> [Pending] {
        let kept = keptKeys(in: events, calendar: calendar)
        return subscriptions
            .compactMap { pending(for: $0, kept: kept, now: now, calendar: calendar) }
            .sorted { ($0.date, $0.subscriptionId.uuidString) < ($1.date, $1.subscriptionId.uuidString) }
    }
}
