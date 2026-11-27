import XCTest
import UserNotifications
@testable import Pausely

/// Pause Plan: who's eligible, what rotating saves, when each service is on, and which reminders keep
/// the rotation going.
final class PausePlanTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func ymd(_ date: Date) -> String { ReminderPlanner.dayStamp(date, cal) }

    private func sub(_ name: String, _ amount: Decimal = 15, anchor: Date?, category: String = "Entertainment",
                     frequency: BillingFrequency = .monthly, status: SubscriptionStatus = .active) -> Subscription {
        TestFactories.makeSubscription(name: name, amount: amount, billingFrequency: frequency, status: status,
                                       nextBillingDate: anchor, category: category)
    }

    // MARK: - Eligibility and savings

    func testOnlyMonthlyVideoServicesRotate() {
        XCTAssertTrue(PausePlanSchedule.isEligible(sub("Netflix", anchor: nil)))
        XCTAssertTrue(PausePlanSchedule.isEligible(sub("Max", anchor: nil, category: "Streaming")))
        XCTAssertTrue(PausePlanSchedule.isEligible(sub("Disney+", anchor: nil, category: "Other")), "known streaming name")
        XCTAssertFalse(PausePlanSchedule.isEligible(sub("Spotify", anchor: nil, category: "Music")))
        XCTAssertFalse(PausePlanSchedule.isEligible(sub("Netflix", anchor: nil, frequency: .yearly)))
        XCTAssertFalse(PausePlanSchedule.isEligible(sub("Notion", anchor: nil, category: "Productivity")))
        XCTAssertFalse(PausePlanSchedule.isEligible(sub("Pausely Pro", anchor: nil)))
        XCTAssertFalse(PausePlanSchedule.isEligible(sub("Constant Contact", anchor: nil, category: "Business")),
                       "\"stan\" inside a word isn't Stan")
        XCTAssertTrue(PausePlanSchedule.isEligible(sub("ESPN+", anchor: nil, category: "Sports")))
    }

    /// Eligibility used to include anything filed under "Entertainment", so Audible, PlayStation Plus
    /// and Kindle Unlimited were listed as streaming services and counted in the yearly saving.
    func testOnlyVideoStreamingByNameIsEligibleWhateverItsCategory() {
        for name in ["Audible", "PlayStation Plus", "Kindle Unlimited", "Twitch", "Patreon", "Scribd", "AMC Stubs A-List",
                     "Acorns", "Maximus Gym", "YouTube Music", "Apple Music", "Discovery Education"] {
            XCTAssertFalse(PausePlanSchedule.isEligible(sub(name, anchor: nil, category: "Entertainment")), name)
        }
        for name in ["Netflix", "HBO Max", "Max", "Disney+", "Hulu", "Amazon Prime Video", "Apple TV+", "Paramount+ with Showtime",
                     "Peacock Premium", "ESPN+", "FuboTV", "AMC+", "Acorn TV", "Discovery+", "MGM+", "Crave", "Shahid", "U-NEXT"] {
            XCTAssertTrue(PausePlanSchedule.isEligible(sub(name, anchor: nil, category: "Other")), name)
        }
    }

    func testRotatingThreeServicesSavesTwoThirds() {
        // 20 + 15 + 10 = 45 a month today; one at a time averages 15; 30 a month back = 360 a year.
        XCTAssertEqual(PausePlanSchedule.yearlySavings(monthlyCosts: [20, 15, 10]), 360)
        XCTAssertEqual(PausePlanSchedule.monthlyCostWhileRotating(monthlyCosts: [20, 15, 10]), 15)
        XCTAssertEqual(PausePlanSchedule.yearlySavings(monthlyCosts: [20]), 0, "one service isn't a rotation")
    }

    func testSuggestedOrderStartsWithTheLatestRenewal() {
        let now = day(2026, 10, 22)
        let a = sub("A", anchor: day(2026, 10, 25))
        let b = sub("B", anchor: day(2026, 11, 15))
        let c = sub("C", anchor: day(2026, 10, 30))
        XCTAssertEqual(PausePlanSchedule.suggestedOrder([a, b, c], now: now, calendar: cal), [b.id, a.id, c.id],
                       "B runs while A and C use up the time already paid for")
    }

    // MARK: - Turns

    private func threeServicePlan() -> (PausePlan, [Subscription]) {
        let netflix = sub("Netflix", anchor: day(2026, 10, 31))
        let max = sub("Max", anchor: day(2026, 11, 5))
        let disney = sub("Disney+", anchor: day(2026, 11, 12))
        let plan = PausePlan(subscriptionIds: [netflix.id, max.id, disney.id], startedOn: day(2026, 10, 22))
        return (plan, [netflix, max, disney])
    }

    private func byId(_ subs: [Subscription]) -> [UUID: Subscription] {
        Dictionary(uniqueKeysWithValues: subs.map { ($0.id, $0) })
    }

    func testTurnsHandOverMonthlyFromTheFirstServicesRenewal() {
        let (plan, subs) = threeServicePlan()
        let turns = PausePlanSchedule.turns(plan, subscriptions: byId(subs), count: 4, calendar: cal)
        XCTAssertEqual(turns.map(\.subscriptionId), [subs[0].id, subs[1].id, subs[2].id, subs[0].id])
        XCTAssertNil(turns[0].start, "Netflix was already on")
        XCTAssertEqual(turns.map { ymd($0.end) }, ["2026-10-31", "2026-11-30", "2026-12-31", "2027-01-31"],
                       "month-end handoffs don't drift")
        XCTAssertEqual(turns[1].start.map(ymd), "2026-10-31")
    }

    func testCurrentTurnFollowsTheCalendar() {
        let (plan, subs) = threeServicePlan()
        let ids = byId(subs)
        XCTAssertEqual(PausePlanSchedule.currentTurn(plan, subscriptions: ids, now: day(2026, 10, 30), calendar: cal)?.subscriptionId, subs[0].id)
        XCTAssertEqual(PausePlanSchedule.currentTurn(plan, subscriptions: ids, now: day(2026, 10, 31), calendar: cal)?.subscriptionId, subs[1].id)
        XCTAssertEqual(PausePlanSchedule.currentTurn(plan, subscriptions: ids, now: day(2026, 12, 15), calendar: cal)?.subscriptionId, subs[2].id)
        XCTAssertEqual(PausePlanSchedule.currentTurn(plan, subscriptions: ids, now: day(2027, 2, 1), calendar: cal)?.subscriptionId, subs[1].id)
    }

    // MARK: - Reminders

    func testRemindersCancelTheOthersAndHandOver() {
        let (plan, subs) = threeServicePlan()
        let reminders = PausePlanSchedule.reminders(plan, subscriptions: subs, now: day(2026, 10, 22, hour: 8), calendar: cal)
        func has(_ kind: ReminderPlanner.Kind, _ s: Subscription, _ date: String) -> Bool {
            reminders.contains { $0.kind == kind && $0.subscriptionId == s.id && ymd($0.eventDate) == date }
        }
        XCTAssertTrue(has(.planCancel, subs[2], "2026-11-12"), "Disney+ is paused: cancel before its renewal")
        XCTAssertFalse(reminders.contains { $0.kind == .planCancel && $0.subscriptionId == subs[1].id && ymd($0.eventDate) == "2026-11-05" },
                       "Max comes on next, so it isn't told to cancel")
        XCTAssertTrue(has(.planCancel, subs[0], "2026-10-31"), "Netflix hands over on Oct 31")
        XCTAssertTrue(has(.planStart, subs[2], "2026-11-30"), "Disney+ starts at the following handoff")
        XCTAssertTrue(reminders.allSatisfy { $0.identifier.hasPrefix(ReminderPlanner.identifierPrefix) })
    }

    func testNextServiceRenewingBeforeTheHandoffIsStillPaused() {
        // YouTube is on until Nov 15; Netflix comes next but renews Oct 27, so it should lapse until its turn.
        let youtube = sub("YouTube Premium", anchor: day(2026, 11, 15))
        let netflix = sub("Netflix", anchor: day(2026, 10, 27))
        let plan = PausePlan(subscriptionIds: [youtube.id, netflix.id], startedOn: day(2026, 10, 22))
        let reminders = PausePlanSchedule.reminders(plan, subscriptions: [youtube, netflix], now: day(2026, 10, 22, hour: 8), calendar: cal)
        XCTAssertTrue(reminders.contains { $0.kind == .planCancel && $0.subscriptionId == netflix.id && ymd($0.eventDate) == "2026-10-27" })
    }

    func testPausedServicesGetNoCancelReminder() {
        let (plan, subs) = threeServicePlan()
        var paused = subs
        paused[2].status = .cancelled
        let reminders = PausePlanSchedule.reminders(plan, subscriptions: paused, now: day(2026, 10, 22, hour: 8), calendar: cal)
        XCTAssertFalse(reminders.contains { $0.kind == .planCancel && $0.subscriptionId == subs[2].id })
    }

    func testPlannerUsesPlanRemindersInsteadOfRenewalOnes() {
        let (plan, subs) = threeServicePlan()
        let spotify = sub("Spotify", anchor: day(2026, 10, 28), category: "Music")
        let all = subs + [spotify]
        let reminders = ReminderPlanner.plan(for: all, now: day(2026, 10, 22, hour: 8), calendar: cal, pausePlan: plan)
        let rotating = Set(plan.subscriptionIds)
        XCTAssertFalse(reminders.contains { rotating.contains($0.subscriptionId) && [.renewalHeadsUp, .renewalTomorrow, .renewalToday].contains($0.kind) })
        XCTAssertTrue(reminders.contains { $0.subscriptionId == spotify.id && $0.kind == .renewalTomorrow }, "others are unaffected")
        XCTAssertTrue(reminders.contains { $0.kind == .planCancel })
    }

    // MARK: - Starting a service again

    private func renewals(from anchor: Date, after day: Date, count: Int = 4) -> [String] {
        RenewalSchedule.upcomingRenewals(anchor: anchor, frequency: .monthly, onOrAfter: day, count: count, calendar: cal).map(ymd)
    }

    /// Restarted on the 31st, it renews on the last day of short months and on the 31st again after
    /// them. Storing "a month after today" (28 February) made it renew on the 28th forever.
    func testAServiceStartedOnThe31stKeepsRenewingOnThe31st() {
        let restart = PausePlanSchedule.restartAnchor(startedOn: day(2027, 1, 31, hour: 20), frequency: .monthly, calendar: cal)
        XCTAssertTrue(restart.isStartDay)
        XCTAssertEqual(restart.anchor, day(2027, 1, 31))
        XCTAssertEqual(renewals(from: restart.anchor, after: day(2027, 2, 1)),
                       ["2027-02-28", "2027-03-31", "2027-04-30", "2027-05-31"])
    }

    /// On most days a month later is the same schedule, and it never shows the day just paid for as
    /// a charge still to come.
    func testOnMostDaysTheDateStoredIsTheFirstRenewal() {
        let started = day(2026, 11, 11, hour: 8)
        let restart = PausePlanSchedule.restartAnchor(startedOn: started, frequency: .monthly, calendar: cal)
        XCTAssertFalse(restart.isStartDay)
        XCTAssertEqual(restart.anchor, day(2026, 12, 11))
        XCTAssertEqual(renewals(from: restart.anchor, after: started, count: 24),
                       renewals(from: day(2026, 11, 11), after: day(2026, 11, 12), count: 24),
                       "the same renewals as counting from the start day itself")
    }

    func testOtherBillingPeriodsFollowTheSameRule() {
        let weekly = PausePlanSchedule.restartAnchor(startedOn: day(2026, 11, 11), frequency: .weekly, calendar: cal)
        XCTAssertEqual(weekly.anchor, day(2026, 11, 18))
        XCTAssertFalse(weekly.isStartDay)

        let leapDay = PausePlanSchedule.restartAnchor(startedOn: day(2028, 2, 29), frequency: .yearly, calendar: cal)
        XCTAssertEqual(leapDay.anchor, day(2028, 2, 29), "a year later would be 28 February every year, leap years too")
        XCTAssertTrue(leapDay.isStartDay)

        let yearly = PausePlanSchedule.restartAnchor(startedOn: day(2026, 11, 11), frequency: .yearly, calendar: cal)
        XCTAssertEqual(yearly.anchor, day(2027, 11, 11))
    }
}

/// "I started it" on the Pause Plan, through the real subscription list.
@MainActor
final class PausePlanStartTests: XCTestCase {

    private let store = SubscriptionStore.shared
    private var sandbox: StoreSandbox!
    private var plans: PausePlanStore!
    private var folder: URL!
    private let cal = Calendar.current

    override func setUp() async throws {
        sandbox = StoreSandbox()
        UserDefaults.standard.set(true, forKey: "debug_premium_override")
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("PausePlanStartTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        plans = PausePlanStore(fileURL: folder.appendingPathComponent("pause_plan.json"))
    }

    override func tearDown() async throws {
        await sandbox.restore()
        try? FileManager.default.removeItem(at: folder)
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func cancelled(_ name: String, anchor: Date) async throws -> Subscription {
        let sub = TestFactories.makeSubscription(name: name, status: .cancelled, nextBillingDate: anchor, category: "Entertainment")
        _ = try await store.addSubscription(sub)
        return sub
    }

    func testStartingACancelledServiceTurnsItOnWithItsFirstRenewalAMonthOn() async throws {
        let sub = try await cancelled("Netflix", anchor: day(2026, 9, 3))
        await plans.markStarted(sub, on: day(2026, 11, 11, hour: 9))
        let now = try XCTUnwrap(store.subscriptions.first)
        XCTAssertEqual(now.status, .active)
        XCTAssertEqual(now.nextBillingDate, day(2026, 12, 11))
        let kinds = LifecycleEventLog.shared.events.filter { $0.subscriptionId == sub.id }.map(\.kind)
        XCTAssertEqual(kinds, [.added, .reactivated])
    }

    /// Started on the 31st, the date stored is that day, and that day is already decided: no
    /// "keep it or cancel it?" and no reminder for a charge the person has just paid.
    func testStartedOnThe31stTodayIsNotAskedAbout() async throws {
        let sub = try await cancelled("Hulu", anchor: day(2026, 9, 3))
        let startedAt = day(2027, 1, 31, hour: 9)
        await plans.markStarted(sub, on: startedAt)
        let now = try XCTUnwrap(store.subscriptions.first)
        XCTAssertEqual(now.status, .active)
        XCTAssertEqual(now.nextBillingDate, day(2027, 1, 31))
        XCTAssertEqual(RenewalDecisions.pending(in: store.subscriptions, events: LifecycleEventLog.shared.events, now: startedAt), [])
        let next = try XCTUnwrap(RenewalDecisions.pending(in: store.subscriptions, events: LifecycleEventLog.shared.events,
                                                          now: day(2027, 2, 27)).first)
        XCTAssertEqual(next.date, day(2027, 2, 28), "the next one is asked about as usual")
    }

    func testAServiceThatIsAlreadyOnKeepsItsDate() async throws {
        let sub = TestFactories.makeSubscription(name: "Max", status: .active, nextBillingDate: day(2026, 11, 20), category: "Entertainment")
        _ = try await store.addSubscription(sub)
        await plans.markStarted(sub, on: day(2026, 11, 11))
        XCTAssertEqual(store.subscriptions.first?.nextBillingDate, day(2026, 11, 20))
        XCTAssertEqual(LifecycleEventLog.shared.events.filter { $0.subscriptionId == sub.id }.map(\.kind), [.added])
    }
}

/// Permanent anti-regression suite locking in every Gold Standard (>= 9.5) Pause Plan invariant so
/// none of the real-world rotation, undated-service, currency, lead-time, or Pro-feature quality
/// bugs can ever recur silently.
final class PausePlanGoldTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    private let rates = CurrencyRates(perUSD: ["USD": 1, "CAD": 2])

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func ymd(_ date: Date) -> String { ReminderPlanner.dayStamp(date, cal) }

    private func sub(_ name: String, _ amount: Decimal = 15, currency: String = "USD",
                     anchor: Date?, frequency: BillingFrequency = .monthly,
                     status: SubscriptionStatus = .active, notify: Int = 3) -> Subscription {
        var s = TestFactories.makeSubscription(name: name, amount: amount, currency: currency,
                                               billingFrequency: frequency, status: status,
                                               nextBillingDate: anchor, category: "Entertainment")
        s.notifyBeforeDays = notify
        return s
    }

    /// Day-1 undated active services MUST surface `.addDate` To-Dos instead of lying "You're all set".
    func testUndatedRotatingServicesAlwaysEmitAddDateTodos() {
        let now = day(2026, 11, 26)
        let netflix = sub("Netflix", anchor: nil)
        let hulu = sub("Hulu", anchor: nil)
        let disney = sub("Disney+", anchor: day(2026, 12, 10))
        let plan = PausePlan(subscriptionIds: [netflix.id, hulu.id, disney.id], startedOn: now)

        let items = PausePlanSchedule.actionItems(for: plan, subscriptions: [netflix, hulu, disney], now: now, calendar: cal)
        XCTAssertTrue(items.contains { $0.subscriptionId == netflix.id && $0.kind == .addDate },
                      "undated active current service must ask for a date")
        XCTAssertTrue(items.contains { $0.subscriptionId == hulu.id && $0.kind == .addDate },
                      "undated rotating service must NEVER silently vanish behind 'You're all set'")
        XCTAssertTrue(items.contains { $0.subscriptionId == disney.id && $0.kind == .cancel },
                      "dated rotating service still prompts to cancel")
    }

    /// Every Pause Plan cancel event schedules an advance heads-up >= 2 days before renewal (safely
    /// ahead of Apple's 24-hour cancellation deadline) respecting `notifyBeforeDays`, plus day-before.
    func testCancelRemindersAlwaysIncludeAdvanceHeadsUpAheadOf24HourCutoff() {
        let now = day(2026, 10, 20, hour: 8)
        let netflix = sub("Netflix", anchor: day(2026, 10, 31), notify: 3)
        let maxSub = sub("Max", anchor: day(2026, 11, 5), notify: 5)
        let disney = sub("Disney+", anchor: day(2026, 11, 12), notify: 7)
        let plan = PausePlan(subscriptionIds: [netflix.id, maxSub.id, disney.id], startedOn: now)

        let reminders = PausePlanSchedule.reminders(plan, subscriptions: [netflix, maxSub, disney], now: now, calendar: cal)
        let disneyCancels = reminders.filter { $0.kind == .planCancel && $0.subscriptionId == disney.id && ymd($0.eventDate) == "2026-11-12" }
        XCTAssertTrue(disneyCancels.contains { $0.daysBefore == 7 }, "honors 7-day lead time")
        XCTAssertTrue(disneyCancels.contains { $0.daysBefore == 1 }, "keeps day-before final reminder")

        // Even when notifyBeforeDays == 1, Pause Plan enforces at least a 2-day heads-up (> 24h cutoff).
        let tight = sub("Hulu", anchor: day(2026, 11, 12), notify: 1)
        let tightPlan = PausePlan(subscriptionIds: [netflix.id, maxSub.id, tight.id], startedOn: now)
        let tightReminders = PausePlanSchedule.reminders(tightPlan, subscriptions: [netflix, maxSub, tight], now: now, calendar: cal)
        let tightCancels = tightReminders.filter { $0.kind == .planCancel && $0.subscriptionId == tight.id && ymd($0.eventDate) == "2026-11-12" }
        XCTAssertTrue(tightCancels.contains { $0.daysBefore == 2 }, "minimum 2-day heads-up protects against 24h cutoff")
        XCTAssertTrue(tightCancels.contains { $0.daysBefore == 1 })
    }

    /// Estimate strictly flags FX conversion and counts unconvertible currencies without silent zero-drops.
    func testEstimateTracksFXConversionAndCountsUnconvertibleCurrencies() {
        let netflix = sub("Netflix", 20, currency: "USD", anchor: nil)
        let crave = sub("Crave", 20, currency: "CAD", anchor: nil)
        let foreign = sub("Local", 50, currency: "ZZZ", anchor: nil)

        let est = PausePlanSchedule.estimate(for: [netflix, crave, foreign], currency: "USD", rates: rates)
        XCTAssertEqual(est?.monthlyAll, Decimal(30))
        XCTAssertEqual(est?.monthlyRotating, Decimal(15))
        XCTAssertEqual(est?.yearlySavings, Decimal(180))
        XCTAssertEqual(est?.isConverted, true)
        XCTAssertEqual(est?.excludedUnconvertibleCount, 1)

        // Fewer than 2 convertible services -> returns nil instead of bogus $0.
        let impossible = PausePlanSchedule.estimate(for: [netflix, foreign], currency: "USD", rates: rates)
        XCTAssertNil(impossible)
    }

    /// Extend, switch, reorder, and bring-up-next preserve cumulative `savingsSince` and compute exact turns.
    func testLiveScheduleMutationsPreserveSavingsHistoryAndComputeExactTurns() throws {
        let start = day(2026, 10, 22)
        let netflix = sub("Netflix", 20, anchor: day(2026, 10, 31))
        let maxSub = sub("Max", 16, anchor: day(2026, 11, 5))
        let disney = sub("Disney+", 14, anchor: day(2026, 11, 12))
        let byId = [netflix.id: netflix, maxSub.id: maxSub, disney.id: disney]
        let plan = PausePlan(subscriptionIds: [netflix.id, maxSub.id, disney.id], startedOn: start, savingsSince: start)

        // 1. Extend Netflix on Oct 28 -> stays on until Nov 30 (one extra cycle!), keeps savingsSince == Oct 22.
        let extended = try XCTUnwrap(PausePlanSchedule.extendedCurrentTurn(plan, subscriptions: byId, now: day(2026, 10, 28), calendar: cal))
        XCTAssertEqual(extended.effectiveSavingsStart, start)
        let extTurn = try XCTUnwrap(PausePlanSchedule.currentTurn(extended, subscriptions: byId, now: day(2026, 10, 28), calendar: cal))
        XCTAssertEqual(extTurn.subscriptionId, netflix.id)
        XCTAssertEqual(ymd(extTurn.end), "2026-11-30")

        // 2. Reordering queue while extended preserves the extension AND puts Disney+ next.
        let promoted = try XCTUnwrap(PausePlanSchedule.bringingUpNext(disney.id, in: extended, subscriptions: byId, now: day(2026, 10, 28), calendar: cal))
        XCTAssertEqual(promoted.subscriptionIds, [netflix.id, disney.id, maxSub.id])
        XCTAssertEqual(promoted.effectiveSavingsStart, start)
        let promotedTurn = try XCTUnwrap(PausePlanSchedule.currentTurn(promoted, subscriptions: byId, now: day(2026, 10, 28), calendar: cal))
        XCTAssertEqual(ymd(promotedTurn.end), "2026-11-30", "queue reorder must not drop an active 1-month extension")

        // 3. Switch to next immediately moves Disney+ into index 0 today while preserving savingsSince.
        let switched = try XCTUnwrap(PausePlanSchedule.switchedToNext(promoted, subscriptions: byId, now: day(2026, 10, 29), calendar: cal))
        XCTAssertEqual(switched.subscriptionIds, [disney.id, maxSub.id, netflix.id])
        XCTAssertEqual(switched.effectiveSavingsStart, start)
        XCTAssertEqual(PausePlanSchedule.currentTurn(switched, subscriptions: byId, now: day(2026, 10, 29), calendar: cal)?.subscriptionId, disney.id)
    }

    /// Savings progress shows 12-month `onTrack` on Day 0 right after cancelling and never loses history after edits.
    func testSavingsProgressSurfacesDayZeroOnTrackAndSurvivesPlanExtension() {
        let start = day(2026, 10, 22)
        let netflix = sub("Netflix", 20, anchor: day(2026, 10, 31))
        let hulu = sub("Hulu", 18, anchor: day(2026, 11, 10))
        let cancelHulu = LifecycleEvent(kind: .cancelled, subscription: hulu, date: day(2026, 10, 23), renewalDate: day(2026, 11, 10))
        let lines = SavingsLedger.lines(from: [cancelHulu], now: day(2026, 10, 24), calendar: cal)

        // Extended plan has a later `startedOn` (Oct 31) than original `savingsSince` (Oct 22).
        let extendedPlan = PausePlan(subscriptionIds: [netflix.id, hulu.id], startedOn: day(2026, 10, 31), savingsSince: start)
        let progress = PausePlanSchedule.savingsProgress(for: extendedPlan, lines: lines, currency: "USD", rates: rates, calendar: cal)
        XCTAssertEqual(progress.savedSoFar, Decimal(0))
        XCTAssertEqual(progress.onTrack, Decimal(216), "Day-0 cancelled service shows $216 on track over 12 months even after extension")
        XCTAssertFalse(progress.savedIsConverted)
        XCTAssertFalse(progress.onTrackIsConverted)

        // Day-0 cancelled CAD service (display USD): savedSoFar is $0 (NEVER `≈$0.00`), onTrack IS converted (`≈$120`).
        let crave = sub("Crave", 20, currency: "CAD", anchor: day(2026, 11, 10))
        let cancelCrave = LifecycleEvent(kind: .cancelled, subscription: crave, date: day(2026, 10, 23), renewalDate: day(2026, 11, 10))
        let cadLines = SavingsLedger.lines(from: [cancelCrave], now: day(2026, 10, 24), calendar: cal)
        let cadPlan = PausePlan(subscriptionIds: [netflix.id, crave.id], startedOn: start, savingsSince: start)
        let cadProgress = PausePlanSchedule.savingsProgress(for: cadPlan, lines: cadLines, currency: "USD", rates: rates, calendar: cal)
        XCTAssertEqual(cadProgress.savedSoFar, Decimal(0))
        XCTAssertEqual(cadProgress.onTrack, Decimal(120))
        XCTAssertFalse(cadProgress.savedIsConverted, "Day-0 $0.00 must never print an ≈ prefix")
        XCTAssertTrue(cadProgress.onTrackIsConverted, "CAD-converted 12-month trajectory carries ≈")
    }

    /// Switching to a cancelled service with a stale pre-cancellation billing date MUST give a full
    /// 1-month turn (not a 1-day turn!) and MUST emit a `.start` To-Do instead of lying "You're all set".
    func testSwitchToCancelledServiceWithStaleBillingDateGivesFullMonthAndEmitsStartTodo() throws {
        let now = day(2026, 10, 28)
        let netflix = sub("Netflix", 20, anchor: day(2026, 10, 31), status: .cancelled)
        let maxCancelled = sub("Max", 16, anchor: day(2026, 10, 29), status: .cancelled)
        let disney = sub("Disney+", 14, anchor: day(2026, 11, 12), status: .cancelled)
        let subs = [netflix, maxCancelled, disney]
        let byId = Dictionary(uniqueKeysWithValues: subs.map { ($0.id, $0) })
        let plan = PausePlan(subscriptionIds: [netflix.id, maxCancelled.id, disney.id], startedOn: day(2026, 10, 22))

        let switched = try XCTUnwrap(PausePlanSchedule.switchedToNext(plan, subscriptions: byId, now: now, calendar: cal))
        XCTAssertEqual(switched.subscriptionIds.first, maxCancelled.id)

        let turn = try XCTUnwrap(PausePlanSchedule.currentTurn(switched, subscriptions: byId, now: now, calendar: cal))
        XCTAssertEqual(turn.subscriptionId, maxCancelled.id)
        XCTAssertEqual(ymd(turn.end), "2026-11-28", "cancelled service gets full 1-month turn, never 1-day stale anchor")

        let todos = PausePlanSchedule.actionItems(for: switched, subscriptions: subs, now: now, calendar: cal)
        XCTAssertTrue(todos.contains { $0.subscriptionId == maxCancelled.id && $0.kind == .start },
                      "Turn 0 cancelled service must prompt 'Start Max' instead of 'You're all set'")
    }

    /// Extending a service restarted 2 days after the prior handoff MUST advance a full cycle (~1 month),
    /// never just a 2-day bump to its drifted anchor.
    func testExtendCurrentTurnAddsFullCycleEvenWhenServiceRestartedLate() throws {
        let netflix = sub("Netflix", 20, anchor: day(2026, 10, 31))
        let maxLate = sub("Max", 16, anchor: day(2026, 12, 2))
        let subs = [netflix, maxLate]
        let byId = Dictionary(uniqueKeysWithValues: subs.map { ($0.id, $0) })
        // Plan started Oct 22: Turn 0 Netflix (end Oct 31), Turn 1 Max (Oct 31 -> Nov 30).
        // Max restarted 2 days late on Nov 2 (anchor Dec 2). Extending on Nov 5 must reach Jan 2, NOT Dec 2!
        let plan = PausePlan(subscriptionIds: [netflix.id, maxLate.id], startedOn: day(2026, 10, 22))
        let extended = try XCTUnwrap(PausePlanSchedule.extendedCurrentTurn(plan, subscriptions: byId, now: day(2026, 11, 5), calendar: cal))
        let turn = try XCTUnwrap(PausePlanSchedule.currentTurn(extended, subscriptions: byId, now: day(2026, 11, 5), calendar: cal))
        XCTAssertEqual(turn.subscriptionId, maxLate.id)
        XCTAssertEqual(ymd(turn.end), "2027-01-02", "extending a late-restarted service grants a full extra cycle")
    }

    /// Resubscribe links never open `/cancel*` pages for web services while preserving Apple Subscriptions.
    @MainActor
    func testResubscribeLinkNeverOpensCancelPathAndPreservesAppleSubscriptions() {
        let netflix = sub("Netflix", 20, anchor: nil)
        let netflixLink = CancelHelp.resubscribeLink(for: netflix)
        XCTAssertNotNil(netflixLink)
        XCTAssertEqual(netflixLink?.openInSystem, false)
        XCTAssertFalse(netflixLink?.url.absoluteString.lowercased().contains("cancel") ?? true,
                       "resubscribe link must never send user to /cancelplan")

        var appleSub = sub("Apple TV+", 10, anchor: nil)
        appleSub.paymentMethod = "Apple"
        let appleLink = CancelHelp.resubscribeLink(for: appleSub)
        XCTAssertEqual(appleLink?.openInSystem, true)
        XCTAssertEqual(appleLink?.url, CancelHelp.applesSubscriptions)
    }

    /// Lock Screen "I started it" requires device unlock and refuses execution while signed out.
    @MainActor
    func testMarkStartedNotificationRequiresAuthAndRefusesWhenSignedOut() async {
        XCTAssertTrue(ReminderActions.markStartedOptions.contains(.authenticationRequired),
                      "markStarted must require unlock so protected files are never silently dropped pre-unlock")
        let previousCheck = VerdictCenter.shared.isSignedIn
        defer { VerdictCenter.shared.isSignedIn = previousCheck }
        VerdictCenter.shared.isSignedIn = { false }
        let ok = await VerdictCenter.shared.markPausePlanStarted(subscriptionId: UUID())
        XCTAssertFalse(ok, "must refuse notification action when signed out")
    }

    /// Default eligibility includes YouTube Premium (excludes YouTube Music); opt-in covers monthly AI/other subs.
    func testEligibilityIncludesYouTubePremiumAndOptInCoversMonthlyAISubscriptions() {
        XCTAssertTrue(PausePlanSchedule.isEligible(sub("YouTube Premium", anchor: nil)))
        XCTAssertFalse(PausePlanSchedule.isEligible(sub("YouTube Music", anchor: nil)))
        let claude = sub("Claude Pro", 20, anchor: nil)
        XCTAssertFalse(PausePlanSchedule.isEligible(claude), "AI tools are never auto-counted in streaming savings")
        XCTAssertTrue(PausePlanSchedule.isOptInEligible(claude), "monthly AI tools can be opted into Pause Plan")
        XCTAssertFalse(PausePlanSchedule.isOptInEligible(sub("Pausely Pro", 4.99, anchor: nil)))
        XCTAssertFalse(PausePlanSchedule.isOptInEligible(sub("Claude Pro", 200, anchor: nil, frequency: .yearly)))
    }

    /// Legacy JSON without `savingsSince` decodes cleanly, and `WidgetFeed` decodes without `pauseTurnNextName`.
    func testLegacyPausePlanAndWidgetFeedDecodeCleanly() throws {
        let id1 = UUID(), id2 = UUID()
        let legacyPlanJSON = """
        {"subscriptionIds":["\(id1.uuidString)","\(id2.uuidString)"],"startedOn":800000000}
        """.data(using: .utf8)!
        let decodedPlan = try JSONDecoder().decode(PausePlan.self, from: legacyPlanJSON)
        XCTAssertEqual(decodedPlan.subscriptionIds, [id1, id2])
        XCTAssertNil(decodedPlan.savingsSince)
        XCTAssertEqual(decodedPlan.effectiveSavingsStart, decodedPlan.startedOn)

        let legacyFeedJSON = """
        {"charges":[],"monthlyText":"$20","yearlyText":"$240","hasSubscriptions":true,"pauseTurnName":"Netflix","pauseTurnEndText":"Nov 30","pauseTurnEndStamp":"2026-11-30"}
        """.data(using: .utf8)!
        let decodedFeed = try JSONDecoder().decode(WidgetFeed.self, from: legacyFeedJSON)
        XCTAssertEqual(decodedFeed.activePauseTurn(on: day(2026, 11, 25), calendar: cal)?.name, "Netflix")
        XCTAssertEqual(decodedFeed.activePauseTurn(on: day(2026, 11, 25), calendar: cal)?.nextName, "")
    }
}
