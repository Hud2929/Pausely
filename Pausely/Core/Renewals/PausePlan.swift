import Foundation

/// Pause Plan: keep one streaming service on at a time and rotate monthly.
///
/// How it works in real life: the first service keeps running until its next renewal; every other
/// service in the plan is cancelled before it renews (people usually keep access until then). On the
/// first service's renewal day the next one starts, runs one month, and so on in order. The money
/// saved shows up on the Savings Receipt through the normal cancel and reactivate events.
struct PausePlan: Codable, Equatable {
    /// Rotation order; the first one is on when the plan starts.
    var subscriptionIds: [UUID]
    var startedOn: Date
}

enum PausePlanSchedule {

    /// One month with one service on.
    struct Turn: Equatable {
        let index: Int
        let subscriptionId: UUID
        /// Nil for the first turn, which was already running when the plan started.
        let start: Date?
        /// The handoff day to the next service (local noon).
        let end: Date
    }

    // MARK: - Eligibility and savings

    /// Video streaming services, by name. Short names ("hbo", "stan") must be a whole word; longer
    /// ones and phrases can be part of the name ("Paramount+ with Showtime"). Names that are also
    /// common words ("max") match only when they are the entire service name.
    private static let exactStreamingNames: Set<String> = ["max"]
    private static let streamingNames = [
        "netflix", "hbo", "hbo max", "hbomax", "disney", "hulu", "prime video", "apple tv", "paramount", "peacock",
        "crunchyroll", "espn", "discovery+", "discovery plus", "starz", "showtime", "mubi", "fubo", "fubotv",
        "sling", "youtube tv", "britbox", "acorn tv", "shudder", "curiositystream", "crave", "stan", "binge",
        "now tv", "dazn", "mgm", "amc+", "criterion", "philo", "hidive", "viki", "bet+", "hallmark",
        "directv", "frndly", "sundance now", "funimation", "dropout", "nebula", "fandor", "indieflix",
        "eros now", "vix", "zee5", "hotstar", "viaplay", "canal+", "videoland", "rtl+", "joyn", "u-next",
        "abema", "shahid", "osn+", "movistar plus", "filmin", "atresplayer", "molotov", "kayo", "foxtel",
        "tving", "wavve", "iqiyi", "globoplay", "claro video"
    ]

    /// Monthly video streaming services can rotate, and nothing else. Being filed under
    /// "Entertainment" is not enough: audiobooks, games and reading are there too, and telling someone
    /// to "watch one streaming service at a time" with Audible in the plan promised a saving that
    /// meant dropping something they use every day.
    static func isEligible(_ sub: Subscription) -> Bool {
        guard sub.billingFrequency == .monthly, !sub.isPausely else { return false }
        let name = sub.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if exactStreamingNames.contains(name) { return true }
        let words = name.split { !$0.isLetter && !$0.isNumber && $0 != "+" }.map(String.init)
        return streamingNames.contains { known in
            if known.contains(" ") || known.count >= 6 { return name.contains(known) }
            return words.contains { $0 == known || $0 == known + "+" }
        }
    }

    /// What rotating saves in a year: today every service charges monthly; with the plan, one does.
    static func yearlySavings(monthlyCosts: [Decimal]) -> Decimal {
        guard monthlyCosts.count >= 2 else { return 0 }
        let total = monthlyCosts.reduce(0, +)
        return (total - total / Decimal(monthlyCosts.count)) * 12
    }

    /// The average monthly cost while rotating.
    static func monthlyCostWhileRotating(monthlyCosts: [Decimal]) -> Decimal {
        guard !monthlyCosts.isEmpty else { return 0 }
        return monthlyCosts.reduce(0, +) / Decimal(monthlyCosts.count)
    }

    /// A sensible first service: the one whose next renewal is furthest away, so the others run out
    /// their paid time while it plays.
    static func suggestedOrder(_ subs: [Subscription], now: Date, calendar: Calendar = .billing) -> [UUID] {
        func next(_ s: Subscription) -> Date {
            s.renewsAutomatically ? (RenewalDecisions.upcomingCharge(for: s, now: now, calendar: calendar)?.date ?? .distantPast) : .distantPast
        }
        let sorted = subs.sorted { (next($0), $0.name) > (next($1), $1.name) }
        guard let first = sorted.first else { return [] }
        return [first.id] + sorted.dropFirst().sorted { (next($0), $0.name) < (next($1), $1.name) }.map(\.id)
    }

    // MARK: - Starting a service again

    /// The renewal date to store for a service started again on `day`.
    ///
    /// Every renewal has to fall on the day of the month it was started: a restart on the 31st renews
    /// on the last day of shorter months and on the 31st again after them. One period later says
    /// exactly the same for most start days, and is what's stored when it does, so the start day
    /// itself (already paid) never shows as a charge to come. When it would not (the 29th to 31st, a
    /// 29 February), the start day is stored, `isStartDay` is true, and the caller records that day
    /// as decided.
    static func restartAnchor(startedOn day: Date, frequency: BillingFrequency,
                              calendar: Calendar = .billing) -> (anchor: Date, isStartDay: Bool) {
        let start = calendar.startOfDay(for: day)
        let first = RenewalSchedule.occurrence(1, anchorDay: start, frequency: frequency, calendar: calendar)
        let sameSchedule = (1...48).allSatisfy { cycle in
            RenewalSchedule.occurrence(cycle + 1, anchorDay: start, frequency: frequency, calendar: calendar)
                == RenewalSchedule.occurrence(cycle, anchorDay: first, frequency: frequency, calendar: calendar)
        }
        return sameSchedule ? (calendar.noon(of: first), false) : (calendar.noon(of: start), true)
    }

    // MARK: - Turns

    /// When the first service hands over: its next charge strictly after the plan's start day
    /// (so starting a plan on the chosen first service's renewal day doesn't immediately skip Turn 0).
    static func firstHandoff(_ plan: PausePlan, subscriptions: [UUID: Subscription], calendar: Calendar = .billing) -> Date {
        let dayAfterStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: plan.startedOn)) ?? plan.startedOn
        if let firstId = plan.subscriptionIds.first, let first = subscriptions[firstId] {
            if let anchor = first.nextBillingDate {
                return RenewalSchedule.nextRenewal(anchor: anchor, frequency: .monthly, onOrAfter: dayAfterStart, calendar: calendar)
            }
            if first.status == .trial, let trialEnd = first.trialEndsAt {
                return RenewalSchedule.nextRenewal(anchor: trialEnd, frequency: .monthly, onOrAfter: dayAfterStart, calendar: calendar)
            }
        }
        let fallback = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: plan.startedOn)) ?? plan.startedOn
        return calendar.noon(of: fallback)
    }

    /// The first `count` turns. Handoffs are whole months after the first one (anchor-based, so the
    /// 31st stays the 31st where the month has one).
    static func turns(_ plan: PausePlan, subscriptions: [UUID: Subscription], count: Int,
                      calendar: Calendar = .billing) -> [Turn] {
        let ids = plan.subscriptionIds
        guard ids.count >= 2, count > 0 else { return [] }
        let first = firstHandoff(plan, subscriptions: subscriptions, calendar: calendar)
        func handoff(_ k: Int) -> Date {
            k == 0 ? first : calendar.noon(of: calendar.date(byAdding: .month, value: k, to: calendar.startOfDay(for: first)) ?? first)
        }
        return (0..<count).map { k in
            Turn(index: k, subscriptionId: ids[k % ids.count], start: k == 0 ? nil : handoff(k - 1), end: handoff(k))
        }
    }

    /// The turn running on `now`.
    static func currentTurn(_ plan: PausePlan, subscriptions: [UUID: Subscription], now: Date,
                            calendar: Calendar = .billing) -> Turn? {
        let today = calendar.startOfDay(for: now)
        let first = calendar.startOfDay(for: firstHandoff(plan, subscriptions: subscriptions, calendar: calendar))
        var months = 0
        if today >= first {
            months = (calendar.dateComponents([.month], from: first, to: today).month ?? 0) + 1
        }
        let all = turns(plan, subscriptions: subscriptions, count: months + 2, calendar: calendar)
        return all.last { turn in
            guard let start = turn.start else { return true }
            return calendar.startOfDay(for: start) <= today
        }
    }

    // MARK: - Reminders

    /// A service that isn't on should be cancelled before it renews, unless it's the next one on and
    /// that renewal falls in its own turn (then the charge pays for the month it's on anyway).
    static func shouldPause(_ subscriptionId: UUID, renewingOn renewal: Date, plan: PausePlan, current: Turn,
                            calendar: Calendar = .billing) -> Bool {
        guard subscriptionId != current.subscriptionId else { return false }
        let comingNext = plan.subscriptionIds[(current.index + 1) % plan.subscriptionIds.count]
        if subscriptionId == comingNext, calendar.startOfDay(for: renewal) >= calendar.startOfDay(for: current.end) {
            return false
        }
        return true
    }

    /// Reminders that keep the rotation going: cancel the services that should be paused before they
    /// renew, and start the next one on its day. Rebuilt with the rest whenever anything changes.
    static func reminders(_ plan: PausePlan, subscriptions: [Subscription], now: Date,
                          calendar: Calendar = .billing, handoffsAhead: Int = 2) -> [ReminderPlanner.Reminder] {
        let byId = Dictionary(subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        guard plan.subscriptionIds.count >= 2,
              let current = currentTurn(plan, subscriptions: byId, now: now, calendar: calendar) else { return [] }
        var result: [ReminderPlanner.Reminder] = []

        func add(_ kind: ReminderPlanner.Kind, _ subId: UUID, event: Date, daysBefore: Int, hour: Int) {
            guard let fireDay = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: event)),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: fireDay),
                  fire > now else { return }
            let id = "\(ReminderPlanner.identifierPrefix)\(kind.rawValue).\(subId.uuidString).\(ReminderPlanner.dayStamp(event, calendar))"
            guard !result.contains(where: { $0.identifier == id }) else { return }
            result.append(.init(identifier: id, kind: kind, subscriptionId: subId, fireDate: fire,
                                eventDate: calendar.noon(of: event), daysBefore: daysBefore))
        }

        // Services that should be paused but still renew (including free trials): cancel before the next charge.
        for id in plan.subscriptionIds where id != current.subscriptionId {
            guard let sub = byId[id], sub.renewsAutomatically,
                  let next = RenewalDecisions.upcomingCharge(for: sub, now: now, calendar: calendar)?.date,
                  shouldPause(id, renewingOn: next, plan: plan, current: current, calendar: calendar) else { continue }
            add(.planCancel, id, event: next, daysBefore: 1, hour: 10)
        }

        // The next handoffs: the outgoing service is cancelled the day before, the next one starts that morning.
        let upcoming = turns(plan, subscriptions: byId, count: current.index + 1 + handoffsAhead, calendar: calendar)
            .filter { $0.index > current.index }
        for (offset, turn) in upcoming.enumerated() {
            guard let handoff = turn.start else { continue }
            let outgoing = plan.subscriptionIds[(turn.index - 1) % plan.subscriptionIds.count]
            let isNext = offset == 0
            if !isNext || byId[outgoing]?.renewsAutomatically == true {
                add(.planCancel, outgoing, event: handoff, daysBefore: 1, hour: 10)
            }
            if !isNext || byId[turn.subscriptionId]?.renewsAutomatically != true {
                add(.planStart, turn.subscriptionId, event: handoff, daysBefore: 0, hour: 9)
            }
        }
        return result
    }
}
