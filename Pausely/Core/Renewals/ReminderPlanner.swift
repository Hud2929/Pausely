import Foundation

/// Plans every renewal and trial reminder Pausely should have pending, from the current subscriptions.
///
/// Pure: the same subscriptions and time always give the same plan. `ReminderScheduler` replaces all
/// pending Pausely reminders with this plan, so editing a date, deleting or cancelling a subscription,
/// or a renewal passing can never leave a stale reminder behind (Lago's "announced state" rule).
enum ReminderPlanner {

    enum Kind: String, Codable, CaseIterable {
        case renewalHeadsUp     // N days before (the subscription's "Remind me" setting)
        case renewalTomorrow    // the day before
        case renewalToday       // the morning of the renewal
        case trialHeadsUp       // two days before a free trial ends (safely ahead of Apple's 24-hour cutoff)
        case trialEnding        // the day before a free trial ends
        case planCancel         // Pause Plan: cancel this one before it renews
        case planStart          // Pause Plan: this one's month starts today
        case savingsAvoided     // Cancelled subscription charge day passed: celebrates money kept
    }

    struct Reminder: Equatable {
        let identifier: String
        let kind: Kind
        let subscriptionId: UUID
        /// When the notification fires (local time).
        let fireDate: Date
        /// The renewal or trial end it is about.
        let eventDate: Date
        let daysBefore: Int
        /// Formatted avoided-charge amount for `.savingsAvoided` milestones (from `SavingsLedger`).
        var amountText: String? = nil
    }

    nonisolated static let identifierPrefix = "pausely.reminder."
    /// The one notification that asks the person to open the app (`refillDate`).
    nonisolated static let refillIdentifier = identifierPrefix + "refill"
    /// iOS keeps at most 64 pending local notifications per app; leave room for the others.
    static let defaultBudget = 60

    /// Which reminders the user wants (Settings → Notifications).
    struct Preferences: Equatable {
        var renewals = true
        var trials = true
        /// Avoided-charge milestones (rank 3, never displaces renewals). Pure planner defaults to
        /// `false`; `ReminderScheduler.preferences` reads the live user switch (which defaults to `true`).
        var savingsMilestones = false
    }

    /// One future charge day that a cancelled subscription will no longer bill.
    struct AvoidedCharge: Equatable {
        let subscriptionId: UUID
        let date: Date
        var amountText: String? = nil
    }

    /// - Parameters:
    ///   - cyclesAhead: how many upcoming renewals per subscription get reminders, so reminders keep
    ///     coming even if the app is not opened for a whole cycle.
    ///   - budget: how many reminders iOS will hold. When there are more, every subscription keeps the
    ///     one that matters most (the day before its next charge) before any keeps the others.
    ///   - kept: renewals the user already decided to keep (`RenewalDecisions.keptKeys`); no more
    ///     reminders about those.
    static func plan(for subscriptions: [Subscription], now: Date, calendar: Calendar = .billing,
                     cyclesAhead: Int = 2, budget: Int = defaultBudget,
                     preferences: Preferences = Preferences(), kept: Set<String> = [],
                     pausePlan: PausePlan? = nil,
                     avoidedCharges: [AvoidedCharge] = []) -> [Reminder] {
        chosen(from: ranked(for: subscriptions, now: now, calendar: calendar, cyclesAhead: cyclesAhead,
                            preferences: preferences, kept: kept, pausePlan: pausePlan,
                            avoidedCharges: avoidedCharges), budget: budget)
    }

    /// When to ask the person to open Pausely, so that reminders don't quietly stop. Reminders are
    /// planned a couple of renewals ahead and renewed every time the app is opened or a reminder is
    /// answered. Someone who does neither for that long would get nothing more, without knowing. So the
    /// plan ends with one notification saying so: at nine on the morning after its last reminder, or on
    /// the morning of the first one that didn't fit, whichever comes first. Nil when nothing is planned.
    static func refillDate(for subscriptions: [Subscription], now: Date, calendar: Calendar = .billing,
                           cyclesAhead: Int = 2, budget: Int = defaultBudget,
                           preferences: Preferences = Preferences(), kept: Set<String> = [],
                           pausePlan: PausePlan? = nil,
                           avoidedCharges: [AvoidedCharge] = []) -> Date? {
        // Rank-3 savings milestones must never distort `refillDate` (neither starving active renewal
        // refreshes nor triggering false refill warnings when a milestone is dropped).
        let activeAll = ranked(for: subscriptions, now: now, calendar: calendar, cyclesAhead: cyclesAhead,
                               preferences: preferences, kept: kept, pausePlan: pausePlan,
                               avoidedCharges: avoidedCharges)
            .filter { $0.reminder.kind != .savingsAvoided }
        let planned = chosen(from: activeAll, budget: budget)
        guard let last = planned.last else { return nil }
        let plannedIds = Set(planned.map(\.identifier))
        let firstLeftOut = activeAll.map(\.reminder).filter { !plannedIds.contains($0.identifier) }.map(\.fireDate).min()

        func nine(onTheDayOf date: Date, plus days: Int) -> Date? {
            calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date))
                .flatMap { calendar.date(bySettingHour: 9, minute: 0, second: 0, of: $0) }
        }
        let candidates = [nine(onTheDayOf: last.fireDate, plus: 1), firstLeftOut.flatMap { nine(onTheDayOf: $0, plus: 0) }]
        return candidates.compactMap { $0 }.filter { $0 > now }.min()
    }

    /// Every reminder there could be, each with how much it matters: 0 for the day before a
    /// subscription's next charge, the end of a trial and Pause Plan handoffs; 1 for the other
    /// reminders about that next charge; 2 for the charges after it.
    private static func ranked(for subscriptions: [Subscription], now: Date, calendar: Calendar, cyclesAhead: Int,
                               preferences: Preferences, kept: Set<String>,
                               pausePlan: PausePlan?,
                               avoidedCharges: [AvoidedCharge]) -> [(reminder: Reminder, rank: Int)] {
        var all: [(reminder: Reminder, rank: Int)] = []
        // Subscriptions in a Pause Plan get the plan's reminders instead of the usual renewal ones.
        let rotating = pausePlan.map { Set($0.subscriptionIds) } ?? []
        if let pausePlan, preferences.renewals {
            all += PausePlanSchedule.reminders(pausePlan, subscriptions: subscriptions, now: now, calendar: calendar)
                .map { ($0, 0) }
        }
        for sub in subscriptions where sub.notifyBeforeDays > 0 {   // 0 means "Remind me: Off"
            if rotating.contains(sub.id) { continue }
            let trialEnd = sub.status == .trial ? sub.trialEndsAt.map { calendar.startOfDay(for: $0) } : nil

            if preferences.renewals, sub.renewsAutomatically, let anchor = sub.nextBillingDate {
                let renewals = RenewalSchedule.upcomingRenewals(anchor: anchor, frequency: sub.billingFrequency,
                                                                onOrAfter: now, count: cyclesAhead, calendar: calendar)
                for (cycle, renewal) in renewals.enumerated() {
                    // The trial reminder already covers a first charge that falls when the trial ends.
                    if let trialEnd, calendar.calendarDays(from: trialEnd, to: renewal) <= 1 { continue }
                    if kept.contains(RenewalDecisions.key(sub.id, renewal, calendar)) { continue }
                    let later = cycle > 0
                    if sub.notifyBeforeDays > 1,
                       let r = make(.renewalHeadsUp, sub, renewal, daysBefore: sub.notifyBeforeDays, hour: 9, now, calendar) {
                        all.append((r, later ? 2 : 1))
                    }
                    if let r = make(.renewalTomorrow, sub, renewal, daysBefore: 1, hour: 11, now, calendar) {
                        all.append((r, later ? 2 : 0))
                    }
                    if let r = make(.renewalToday, sub, renewal, daysBefore: 0, hour: 9, now, calendar) {
                        all.append((r, later ? 2 : 1))
                    }
                }
            }

            if preferences.trials, let trialEnd, !kept.contains(RenewalDecisions.key(sub.id, trialEnd, calendar)) {
                // Two days before gives advance notice safely ahead of Apple's 24-hour cancellation deadline.
                if let headsUp = make(.trialHeadsUp, sub, calendar.noon(of: trialEnd), daysBefore: 2, hour: 10, now, calendar) {
                    all.append((headsUp, 0))
                }
                if let ending = make(.trialEnding, sub, calendar.noon(of: trialEnd), daysBefore: 1, hour: 10, now, calendar) {
                    all.append((ending, 0))
                }
            }
        }
        if preferences.savingsMilestones {
            let subsById = Dictionary(subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for charge in avoidedCharges {
                guard let sub = subsById[charge.subscriptionId], !sub.isPausely,
                      var r = make(.savingsAvoided, sub, calendar.noon(of: charge.date), daysBefore: 0, hour: 10, now, calendar) else {
                    continue
                }
                r.amountText = charge.amountText
                // Rank 3: strictly below all active renewal/trial/Pause Plan alerts so milestones never crowd them out.
                all.append((r, 3))
            }
        }
        return all
    }

    /// The reminders that fit, in the order they fire. What matters most is kept first; within the
    /// same rank, the soonest.
    private static func chosen(from all: [(reminder: Reminder, rank: Int)], budget: Int) -> [Reminder] {
        all.sorted { ($0.rank, $0.reminder.fireDate, $0.reminder.identifier) < ($1.rank, $1.reminder.fireDate, $1.reminder.identifier) }
            .prefix(max(budget, 0))
            .map(\.reminder)
            .sorted { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }
    }

    private static func make(_ kind: Kind, _ sub: Subscription, _ eventDay: Date, daysBefore: Int, hour: Int,
                             _ now: Date, _ calendar: Calendar) -> Reminder? {
        guard let fireDay = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: eventDay)),
              let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: fireDay),
              fire > now else { return nil }
        return Reminder(identifier: "\(identifierPrefix)\(kind.rawValue).\(sub.id.uuidString).\(dayStamp(eventDay, calendar))",
                        kind: kind, subscriptionId: sub.id, fireDate: fire, eventDate: eventDay, daysBefore: daysBefore)
    }

    static func dayStamp(_ date: Date, _ calendar: Calendar) -> String {
        calendar.dayStamp(date)
    }
}
