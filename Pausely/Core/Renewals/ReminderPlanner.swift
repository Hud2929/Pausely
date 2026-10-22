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
        case trialEnding        // the day before a free trial ends
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
    }

    nonisolated static let identifierPrefix = "pausely.reminder."
    /// iOS keeps at most 64 pending local notifications per app; leave room for the others.
    static let defaultBudget = 60

    /// Which reminders the user wants (Settings → Notifications).
    struct Preferences: Equatable {
        var renewals = true
        var trials = true
    }

    /// - Parameters:
    ///   - cyclesAhead: how many upcoming renewals per subscription get reminders, so reminders keep
    ///     coming even if the app is not opened for a whole cycle.
    ///   - budget: the soonest reminders win when there are more than iOS allows.
    ///   - kept: renewals the user already decided to keep (`RenewalDecisions.keptKeys`); no more
    ///     reminders about those.
    static func plan(for subscriptions: [Subscription], now: Date, calendar: Calendar = .current,
                     cyclesAhead: Int = 2, budget: Int = defaultBudget,
                     preferences: Preferences = Preferences(), kept: Set<String> = []) -> [Reminder] {
        var all: [Reminder] = []
        for sub in subscriptions where sub.notifyBeforeDays > 0 {   // 0 means "Remind me: Off"
            let trialEnd = sub.status == .trial ? sub.trialEndsAt.map { calendar.startOfDay(for: $0) } : nil

            if preferences.renewals, sub.renewsAutomatically, let anchor = sub.nextBillingDate {
                let renewals = RenewalSchedule.upcomingRenewals(anchor: anchor, frequency: sub.billingFrequency,
                                                                onOrAfter: now, count: cyclesAhead, calendar: calendar)
                for renewal in renewals {
                    // The trial reminder already covers a first charge that falls when the trial ends.
                    if let trialEnd, calendar.calendarDays(from: trialEnd, to: renewal) <= 1 { continue }
                    if kept.contains(RenewalDecisions.key(sub.id, renewal, calendar)) { continue }
                    if sub.notifyBeforeDays > 1,
                       let r = make(.renewalHeadsUp, sub, renewal, daysBefore: sub.notifyBeforeDays, hour: 9, now, calendar) {
                        all.append(r)
                    }
                    if let r = make(.renewalTomorrow, sub, renewal, daysBefore: 1, hour: 11, now, calendar) { all.append(r) }
                    if let r = make(.renewalToday, sub, renewal, daysBefore: 0, hour: 9, now, calendar) { all.append(r) }
                }
            }

            if preferences.trials, let trialEnd, !kept.contains(RenewalDecisions.key(sub.id, trialEnd, calendar)),
               let r = make(.trialEnding, sub, calendar.noon(of: trialEnd), daysBefore: 1, hour: 10, now, calendar) {
                all.append(r)
            }
        }
        let ordered = all.sorted { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }
        return Array(ordered.prefix(budget))
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
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
