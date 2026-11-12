import XCTest
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
