import Foundation

/// Pause Plan: keep one streaming (or opted-in monthly) service on at a time and rotate monthly.
///
/// How it works in real life: the first service keeps running until its next renewal; every other
/// service in the plan is cancelled before it renews (people usually keep access until then). On the
/// first service's renewal day the next one starts, runs one month, and so on in order. The money
/// saved shows up on the Savings Receipt through the normal cancel and reactivate events.
struct PausePlan: Codable, Equatable {
    /// Rotation order; the first one is on when the plan starts.
    var subscriptionIds: [UUID]
    var startedOn: Date
    /// Earliest start date of this rotation series, preserved across edits, reorders, and 1-month
    /// extensions so cumulative rotation savings never reset to $0. Nil for legacy JSON or freshly
    /// pulled remote rows (`effectiveSavingsStart` falls back cleanly to `startedOn`).
    var savingsSince: Date? = nil

    /// Earliest day from which cancellations count toward this rotation's savings.
    var effectiveSavingsStart: Date {
        guard let savingsSince else { return startedOn }
        return min(savingsSince, startedOn)
    }
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

    /// Strict monetary preview for the Pause Plan setup / editor slip. Unknown currencies are never
    /// silently added as zero; they are excluded and counted in `excludedUnconvertibleCount`.
    struct Estimate: Equatable {
        let monthlyAll: Decimal
        let monthlyRotating: Decimal
        let yearlySavings: Decimal
        let isConverted: Bool
        let excludedUnconvertibleCount: Int
    }

    /// One concrete next step inside an active Pause Plan. Kept pure so tests lock down every
    /// edge case (including undated active subscriptions, which must NEVER produce "You're all set").
    struct ActionItem: Identifiable, Equatable {
        enum Kind: Equatable {
            case addDate
            case cancel
            case start
        }

        let id: String
        let subscriptionId: UUID
        let kind: Kind
        let dueDate: Date?
        let nextSubscriptionId: UUID?
        let isTrialEnd: Bool
    }

    /// Cumulative avoided charges and 12-month trajectory for the services in a Pause Plan.
    /// Tracks FX conversion independently for `savedSoFar` vs `onTrack` so Day-0 never shows `≈$0.00`.
    struct SavingsProgress: Equatable {
        let savedSoFar: Decimal
        let onTrack: Decimal
        let savedIsConverted: Bool
        let onTrackIsConverted: Bool
        let excludedUnconvertibleCount: Int
    }

    // MARK: - Eligibility and savings

    /// Video streaming services, by name. Short names ("hbo", "stan") must be a whole word; longer
    /// ones and phrases can be part of the name ("Paramount+ with Showtime"). Names that are also
    /// common words ("max") match only when they are the entire service name.
    private static let exactStreamingNames: Set<String> = ["max"]
    private static let streamingNames = [
        "netflix", "hbo", "hbo max", "hbomax", "disney", "hulu", "prime video", "apple tv", "paramount", "peacock",
        "crunchyroll", "espn", "discovery+", "discovery plus", "starz", "showtime", "mubi", "fubo", "fubotv",
        "sling", "youtube tv", "youtube premium", "britbox", "acorn tv", "shudder", "curiositystream", "crave",
        "stan", "binge", "now tv", "dazn", "mgm", "amc+", "criterion", "philo", "hidive", "viki", "bet+", "hallmark",
        "directv", "frndly", "sundance now", "funimation", "dropout", "nebula", "fandor", "indieflix",
        "eros now", "vix", "zee5", "hotstar", "viaplay", "canal+", "videoland", "rtl+", "joyn", "u-next",
        "abema", "shahid", "osn+", "movistar plus", "filmin", "atresplayer", "molotov", "kayo", "foxtel",
        "tving", "wavve", "iqiyi", "globoplay", "claro video"
    ]

    /// Frequency-agnostic check for known video streaming services (shared with `OverlapDetector`).
    static func isStreamingService(named rawName: String) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if exactStreamingNames.contains(name) { return true }
        let words = name.split { !$0.isLetter && !$0.isNumber && $0 != "+" }.map(String.init)
        return streamingNames.contains { known in
            if known.contains(" ") || known.count >= 6 { return name.contains(known) }
            return words.contains { $0 == known || $0 == known + "+" }
        }
    }

    /// Monthly video streaming services recommended automatically for rotation. Being filed under
    /// "Entertainment" is not enough: audiobooks, games and reading stay out of automatic savings
    /// claims (`GOLD_STANDARD.md` T96) unless the person manually opts them in via `isOptInEligible`.
    static func isEligible(_ sub: Subscription) -> Bool {
        guard sub.billingFrequency == .monthly, !sub.isPausely else { return false }
        return isStreamingService(named: sub.name)
    }

    /// Any other monthly non-Pausely subscription (such as AI tools, creative suites, or gaming passes)
    /// that a person may explicitly opt into their rotation queue. Never auto-selected or counted
    /// in unsolicited savings headlines.
    static func isOptInEligible(_ sub: Subscription) -> Bool {
        sub.billingFrequency == .monthly && !sub.isPausely && !isEligible(sub)
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

    /// Strict estimate for a chosen set of monthly subscriptions in `currency`. Returns nil if fewer
    /// than two subscriptions can be converted into `currency`.
    static func estimate(for subscriptions: [Subscription],
                         currency: String,
                         rates: CurrencyRates) -> Estimate? {
        var convertible: [Subscription] = []
        var costs: [Decimal] = []
        var unconvertible = 0
        for sub in subscriptions {
            if let converted = rates.convert(sub.monthlyCost, from: sub.currency, to: currency) {
                convertible.append(sub)
                costs.append(converted)
            } else {
                unconvertible += 1
            }
        }
        guard costs.count >= 2 else { return nil }
        let all = costs.reduce(0, +)
        return Estimate(
            monthlyAll: all,
            monthlyRotating: monthlyCostWhileRotating(monthlyCosts: costs),
            yearlySavings: yearlySavings(monthlyCosts: costs),
            isConverted: convertible.isConverted(to: currency),
            excludedUnconvertibleCount: unconvertible
        )
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

    // MARK: - Live schedule mutations (cloud-sync compatible, zero history loss)

    /// Reorders or edits the members of a running plan while keeping the active service in place (if
    /// still included), preserving its handoff/extension, and keeping cumulative `savingsSince`.
    static func updatedPlan(_ plan: PausePlan,
                            newOrder: [UUID],
                            subscriptions: [UUID: Subscription],
                            now: Date,
                            calendar: Calendar = .billing) -> PausePlan? {
        let deduped = newOrder.reduce(into: [UUID]()) { acc, id in
            if !acc.contains(id) { acc.append(id) }
        }
        guard deduped.count >= 2 else { return nil }
        let today = calendar.startOfDay(for: now)
        let current = currentTurn(plan, subscriptions: subscriptions, now: now, calendar: calendar)
        let activeId = deduped[0]
        let activeSub = subscriptions[activeId]
        let hasDate = activeSub.map { $0.nextBillingDate != nil || ($0.status == .trial && $0.trialEndsAt != nil) } ?? false

        let newStartedOn: Date
        if let current, current.subscriptionId == activeId {
            if hasDate {
                // Keep any future extension (`plan.startedOn > today`) while never anchoring in the past.
                newStartedOn = max(calendar.noon(of: today), plan.startedOn)
            } else {
                // Preserve the undated turn's existing handoff date (`fallback = startedOn + 1 month`).
                let backOneMonth = calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: current.end)) ?? today
                newStartedOn = calendar.noon(of: backOneMonth)
            }
        } else {
            newStartedOn = calendar.noon(of: today)
        }

        return PausePlan(
            subscriptionIds: deduped,
            startedOn: PausePlanStore.wholeSecond(newStartedOn),
            savingsSince: PausePlanStore.wholeSecond(plan.effectiveSavingsStart)
        )
    }

    /// Extends the currently active service by one full billing cycle (preserving queue order after
    /// it and cumulative `savingsSince`). Syncs cleanly via standard `(subscriptionIds, startedOn)`.
    /// If the active service was restarted a few days after the previous handoff (so its next anchor
    /// sits < 20 days past `current.end`), advances past that drifted date so the extension always
    /// grants a true additional month rather than a 2-day bump.
    static func extendedCurrentTurn(_ plan: PausePlan,
                                    subscriptions: [UUID: Subscription],
                                    now: Date,
                                    calendar: Calendar = .billing) -> PausePlan? {
        guard plan.subscriptionIds.count >= 2,
              let current = currentTurn(plan, subscriptions: subscriptions, now: now, calendar: calendar) else { return nil }
        let ordered = rotatedOrderStartingAt(current.subscriptionId, in: plan.subscriptionIds)
        let savingsOrigin = PausePlanStore.wholeSecond(plan.effectiveSavingsStart)
        let candidate = PausePlan(
            subscriptionIds: ordered,
            startedOn: PausePlanStore.wholeSecond(calendar.noon(of: current.end)),
            savingsSince: savingsOrigin
        )
        let candidateEnd = firstHandoff(candidate, subscriptions: subscriptions, calendar: calendar)
        if calendar.calendarDays(from: current.end, to: candidateEnd) < 20 {
            return PausePlan(
                subscriptionIds: ordered,
                startedOn: PausePlanStore.wholeSecond(calendar.noon(of: candidateEnd)),
                savingsSince: savingsOrigin
            )
        }
        return candidate
    }

    /// Switches immediately to the next service in line today (moving the outgoing service to the
    /// back of the queue and preserving cumulative `savingsSince`).
    static func switchedToNext(_ plan: PausePlan,
                               subscriptions: [UUID: Subscription],
                               now: Date,
                               calendar: Calendar = .billing) -> PausePlan? {
        guard plan.subscriptionIds.count >= 2,
              let current = currentTurn(plan, subscriptions: subscriptions, now: now, calendar: calendar) else { return nil }
        let nextIndex = (current.index + 1) % plan.subscriptionIds.count
        let nextId = plan.subscriptionIds[nextIndex]
        let ordered = rotatedOrderStartingAt(nextId, in: plan.subscriptionIds)
        return PausePlan(
            subscriptionIds: ordered,
            startedOn: PausePlanStore.wholeSecond(calendar.noon(of: now)),
            savingsSince: PausePlanStore.wholeSecond(plan.effectiveSavingsStart)
        )
    }

    /// Pulls a later service in the queue straight into the "up next" slot right behind the active one.
    static func bringingUpNext(_ subscriptionId: UUID,
                               in plan: PausePlan,
                               subscriptions: [UUID: Subscription],
                               now: Date,
                               calendar: Calendar = .billing) -> PausePlan? {
        guard plan.subscriptionIds.count >= 3,
              let current = currentTurn(plan, subscriptions: subscriptions, now: now, calendar: calendar),
              subscriptionId != current.subscriptionId,
              plan.subscriptionIds.contains(subscriptionId) else { return nil }
        var ordered = rotatedOrderStartingAt(current.subscriptionId, in: plan.subscriptionIds)
        if let idx = ordered.firstIndex(of: subscriptionId), idx > 1 {
            ordered.remove(at: idx)
            ordered.insert(subscriptionId, at: 1)
        }
        return updatedPlan(plan, newOrder: ordered, subscriptions: subscriptions, now: now, calendar: calendar)
    }

    /// Rotates `ids` cyclically so `firstId` is at index 0 while preserving relative queue order.
    static func rotatedOrderStartingAt(_ firstId: UUID, in ids: [UUID]) -> [UUID] {
        guard let idx = ids.firstIndex(of: firstId), idx > 0 else { return ids }
        return Array(ids[idx...]) + Array(ids[..<idx])
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
    /// Cancelled services do NOT trust stale pre-cancellation billing dates — they receive a full
    /// 1-month turn from `plan.startedOn` until restarted via "I started it".
    static func firstHandoff(_ plan: PausePlan, subscriptions: [UUID: Subscription], calendar: Calendar = .billing) -> Date {
        let dayAfterStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: plan.startedOn)) ?? plan.startedOn
        if let firstId = plan.subscriptionIds.first, let first = subscriptions[firstId], first.renewsAutomatically {
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

    // MARK: - Action items & savings progress

    /// Pure deterministic To-Do list for an active Pause Plan.
    /// Guarantees undated active subscriptions NEVER vanish behind a false "You're all set".
    static func actionItems(for plan: PausePlan,
                            subscriptions: [Subscription],
                            now: Date,
                            calendar: Calendar = .billing) -> [ActionItem] {
        let subs = Dictionary(subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        guard let current = currentTurn(plan, subscriptions: subs, now: now, calendar: calendar),
              let currentSub = subs[current.subscriptionId] else { return [] }
        let upcoming = turns(plan, subscriptions: subs, count: current.index + 2, calendar: calendar)
            .filter { $0.index > current.index }
        let next = upcoming.first

        var items: [ActionItem] = []

        // 1. Current service must be on (even on Turn 0 after "Switch now" or starting with a cancelled sub).
        if !currentSub.renewsAutomatically {
            items.append(ActionItem(id: "start-\(currentSub.id)", subscriptionId: currentSub.id,
                                    kind: .start, dueDate: current.start ?? plan.startedOn,
                                    nextSubscriptionId: nil, isTrialEnd: false))
        } else if RenewalDecisions.upcomingCharge(for: currentSub, now: now, calendar: calendar) == nil {
            items.append(ActionItem(id: "date-\(currentSub.id)", subscriptionId: currentSub.id,
                                    kind: .addDate, dueDate: nil, nextSubscriptionId: nil, isTrialEnd: false))
        }

        // 2. Other rotating services that are still renewing must either be cancelled before renewal
        //    or given a renewal date so Pausely can actually remind before they charge.
        for id in plan.subscriptionIds where id != current.subscriptionId {
            guard let sub = subs[id], sub.renewsAutomatically else { continue }
            guard let renewal = RenewalDecisions.upcomingCharge(for: sub, now: now, calendar: calendar)?.date else {
                items.append(ActionItem(id: "date-\(id)", subscriptionId: id,
                                        kind: .addDate, dueDate: nil, nextSubscriptionId: nil, isTrialEnd: false))
                continue
            }
            guard shouldPause(id, renewingOn: renewal, plan: plan, current: current, calendar: calendar) else { continue }
            items.append(ActionItem(id: "cancel-\(id)", subscriptionId: id,
                                    kind: .cancel, dueDate: renewal, nextSubscriptionId: nil,
                                    isTrialEnd: sub.status == .trial))
        }

        // 3. Handoff approaching: prompt to cancel outgoing service inside its lead window (>= 3 days).
        let handoffLead = max(3, currentSub.notifyBeforeDays)
        if let next, currentSub.renewsAutomatically,
           RenewalDecisions.upcomingCharge(for: currentSub, now: now, calendar: calendar) != nil,
           calendar.calendarDays(from: now, to: current.end) <= handoffLead,
           subs[next.subscriptionId] != nil {
            items.append(ActionItem(id: "handoff-\(currentSub.id)", subscriptionId: currentSub.id,
                                    kind: .cancel, dueDate: current.end,
                                    nextSubscriptionId: next.subscriptionId, isTrialEnd: false))
        }

        return items
    }

    /// Cumulative saved-so-far and 12-month on-track savings for the services in `plan`.
    static func savingsProgress(for plan: PausePlan,
                                lines: [SavingsLedger.Line],
                                currency: String,
                                rates: CurrencyRates,
                                calendar: Calendar = .billing) -> SavingsProgress {
        let members = Set(plan.subscriptionIds)
        let since = calendar.startOfDay(for: plan.effectiveSavingsStart)
        let matching = lines.filter { members.contains($0.subscriptionId) && $0.cancelledOn >= since }
        let display = MoneyFormat.normalizedCode(currency)

        var saved: Decimal = 0
        var onTrack: Decimal = 0
        var savedConverted = false
        var onTrackConverted = false
        var excluded = 0

        for line in matching {
            guard let cSaved = rates.convert(line.savedSoFar, from: line.currency, to: currency),
                  let cTrack = rates.convert(line.onTrack, from: line.currency, to: currency) else {
                excluded += 1
                continue
            }
            saved += cSaved
            onTrack += cTrack
            if MoneyFormat.normalizedCode(line.currency) != display {
                if cSaved > 0 { savedConverted = true }
                if cTrack > 0 { onTrackConverted = true }
            }
        }
        return SavingsProgress(savedSoFar: saved, onTrack: onTrack,
                               savedIsConverted: savedConverted, onTrackIsConverted: onTrackConverted,
                               excludedUnconvertibleCount: excluded)
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

    /// Reminders that keep the rotation going:
    /// - Advance cancel heads-up (`max(2, notifyBeforeDays)` days ahead at 10 AM — safely ahead of
    ///   Apple's 24-hour cutoff) PLUS a day-before final call at 10 AM.
    /// - Start morning reminder at 9 AM on handoff day.
    /// Rebuilt cleanly with the rest whenever anything changes.
    static func reminders(_ plan: PausePlan, subscriptions: [Subscription], now: Date,
                          calendar: Calendar = .billing, handoffsAhead: Int = 2) -> [ReminderPlanner.Reminder] {
        let byId = Dictionary(subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        guard plan.subscriptionIds.count >= 2,
              let current = currentTurn(plan, subscriptions: byId, now: now, calendar: calendar) else { return [] }
        var result: [ReminderPlanner.Reminder] = []

        func add(_ kind: ReminderPlanner.Kind, _ subId: UUID, event: Date, daysBefore: Int, hour: Int, suffix: String = "") {
            guard let fireDay = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: event)),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: fireDay),
                  fire > now else { return }
            let id = "\(ReminderPlanner.identifierPrefix)\(kind.rawValue).\(subId.uuidString).\(ReminderPlanner.dayStamp(event, calendar))\(suffix)"
            guard !result.contains(where: { $0.identifier == id }) else { return }
            result.append(.init(identifier: id, kind: kind, subscriptionId: subId, fireDate: fire,
                                eventDate: calendar.noon(of: event), daysBefore: daysBefore))
        }

        func addCancelPair(_ subId: UUID, event: Date) {
            guard let sub = byId[subId], sub.notifyBeforeDays > 0 else { return }
            let lead = max(2, sub.notifyBeforeDays)
            add(.planCancel, subId, event: event, daysBefore: lead, hour: 10, suffix: ".d\(lead)")
            add(.planCancel, subId, event: event, daysBefore: 1, hour: 10)
        }

        // Services that should be paused but still renew (including free trials): cancel before the next charge.
        for id in plan.subscriptionIds where id != current.subscriptionId {
            guard let sub = byId[id], sub.renewsAutomatically,
                  let next = RenewalDecisions.upcomingCharge(for: sub, now: now, calendar: calendar)?.date,
                  shouldPause(id, renewingOn: next, plan: plan, current: current, calendar: calendar) else { continue }
            addCancelPair(id, event: next)
        }

        // The next handoffs: the outgoing service gets advance + day-before cancel calls; the next starts that morning.
        let upcoming = turns(plan, subscriptions: byId, count: current.index + 1 + handoffsAhead, calendar: calendar)
            .filter { $0.index > current.index }
        for (offset, turn) in upcoming.enumerated() {
            guard let handoff = turn.start else { continue }
            let outgoing = plan.subscriptionIds[(turn.index - 1) % plan.subscriptionIds.count]
            let isNext = offset == 0
            if byId[outgoing] != nil, (!isNext || byId[outgoing]?.renewsAutomatically == true) {
                addCancelPair(outgoing, event: handoff)
            }
            if byId[turn.subscriptionId] != nil, (!isNext || byId[turn.subscriptionId]?.renewsAutomatically != true) {
                add(.planStart, turn.subscriptionId, event: handoff, daysBefore: 0, hour: 9)
            }
        }
        return result
    }
}
