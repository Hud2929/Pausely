import XCTest
@testable import Pausely

/// Renewal math, reminder planning and the lifecycle run. Edge cases follow the list Lago tests for its
/// billing periods (see LAGO_TAKEAWAYS.md): month-end anchors, leap days, the first period, time zones.
@MainActor
final class RenewalEngineTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
    }

    private func ymd(_ date: Date) -> String { ReminderPlanner.dayStamp(date, cal) }

    private func next(_ anchor: Date, _ f: BillingFrequency, _ onOrAfter: Date) -> String {
        ymd(RenewalSchedule.nextRenewal(anchor: anchor, frequency: f, onOrAfter: onOrAfter, calendar: cal))
    }

    // MARK: - RenewalSchedule

    func testAnchorTodayOrLaterIsTheNextRenewal() {
        XCTAssertEqual(next(day(2026, 10, 30), .monthly, day(2026, 10, 22)), "2026-10-30")
        XCTAssertEqual(next(day(2026, 10, 22, hour: 23), .monthly, day(2026, 10, 22, hour: 6)), "2026-10-22")
    }

    func testRenewalOnTheTargetDayIsReturned() {
        XCTAssertEqual(next(day(2026, 9, 22), .monthly, day(2026, 10, 22, hour: 20)), "2026-10-22")
    }

    func testMonthEndAnchorClampsWithoutDrifting() {
        let jan31 = day(2026, 1, 31)
        XCTAssertEqual(next(jan31, .monthly, day(2026, 2, 1)), "2026-02-28")
        XCTAssertEqual(next(jan31, .monthly, day(2026, 3, 1)), "2026-03-31", "must not drift to the 28th")
        XCTAssertEqual(next(jan31, .monthly, day(2026, 4, 1)), "2026-04-30")
        XCTAssertEqual(next(jan31, .monthly, day(2028, 2, 1)), "2028-02-29", "leap year")
    }

    func testLeapDayYearlyAnchor() {
        let feb29 = day(2024, 2, 29)
        XCTAssertEqual(next(feb29, .yearly, day(2025, 1, 1)), "2025-02-28")
        XCTAssertEqual(next(feb29, .yearly, day(2027, 3, 1)), "2028-02-29")
    }

    func testWeeklyAndBiweekly() {
        let mon = day(2026, 10, 5)
        XCTAssertEqual(next(mon, .weekly, day(2026, 10, 22)), "2026-10-26")
        XCTAssertEqual(next(mon, .biweekly, day(2026, 10, 22)), "2026-11-02")
    }

    func testQuarterlyAndSemiannualFromMonthEnd() {
        XCTAssertEqual(next(day(2025, 11, 30), .quarterly, day(2026, 3, 1)), "2026-05-30")
        XCTAssertEqual(next(day(2025, 8, 31), .semiannual, day(2026, 1, 1)), "2026-02-28")
        XCTAssertEqual(next(day(2025, 8, 31), .semiannual, day(2026, 3, 1)), "2026-08-31")
    }

    func testFarPastAnchor() {
        XCTAssertEqual(next(day(2001, 1, 15), .monthly, day(2026, 10, 22)), "2026-11-15")
        XCTAssertEqual(next(day(2001, 1, 15), .weekly, day(2026, 10, 22)), ymd(RenewalSchedule.nextRenewal(
            anchor: day(2001, 1, 15), frequency: .weekly, onOrAfter: day(2026, 10, 22), calendar: cal)))
    }

    func testDaylightSavingChangeKeepsTheDayAndNoon() {
        // Daylight saving time starts in Toronto on 2026-03-08.
        let renewal = RenewalSchedule.nextRenewal(anchor: day(2026, 3, 2), frequency: .weekly,
                                                  onOrAfter: day(2026, 3, 9, hour: 1), calendar: cal)
        XCTAssertEqual(ymd(renewal), "2026-03-09")
        XCTAssertEqual(cal.component(.hour, from: renewal), 12)
    }

    func testUpcomingRenewalsList() {
        let list = RenewalSchedule.upcomingRenewals(anchor: day(2026, 1, 31), frequency: .monthly,
                                                   onOrAfter: day(2026, 2, 1), count: 3, calendar: cal)
        XCTAssertEqual(list.map(ymd), ["2026-02-28", "2026-03-31", "2026-04-30"])
    }

    func testRenewalsBetweenTwoRuns() {
        let anchor = day(2026, 9, 15)
        XCTAssertEqual(RenewalSchedule.renewals(anchor: anchor, frequency: .monthly, after: day(2026, 10, 1),
                                                through: day(2026, 10, 22), calendar: cal).map(ymd), ["2026-10-15"])
        XCTAssertEqual(RenewalSchedule.renewals(anchor: anchor, frequency: .monthly, after: day(2026, 10, 15),
                                                through: day(2026, 10, 15, hour: 23), calendar: cal), [])
        XCTAssertEqual(RenewalSchedule.renewals(anchor: anchor, frequency: .monthly, after: day(2026, 10, 14),
                                                through: day(2026, 10, 15, hour: 8), calendar: cal).map(ymd), ["2026-10-15"])
    }

    // MARK: - Subscription

    func testActiveSubscriptionRollsForwardInsteadOfOverdue() {
        let anchor = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let sub = TestFactories.makeSubscription(billingFrequency: .monthly, status: .active, nextBillingDate: anchor)
        let days = sub.daysUntilRenewal ?? -1
        XCTAssertTrue((0...31).contains(days), "got \(days)")
        if case .overdue = sub.renewalStatus { XCTFail("an active subscription is never overdue") }
        XCTAssertEqual(sub.nextBillingDate, anchor, "the stored anchor is never overwritten")
    }

    func testCancelledSubscriptionKeepsItsDate() {
        let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let sub = TestFactories.makeSubscription(status: .cancelled, nextBillingDate: past)
        XCTAssertEqual(sub.calculatedNextBillingDate, past)
        if case .overdue = sub.renewalStatus {} else { XCTFail("expected overdue") }
    }

    func testPausedSubscriptionDoesNotRoll() {
        let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let until = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        let sub = TestFactories.makeSubscription(status: .active, nextBillingDate: past, pausedUntil: until)
        XCTAssertFalse(sub.renewsAutomatically)
        XCTAssertEqual(sub.calculatedNextBillingDate, past)
    }

    // MARK: - ReminderPlanner

    private func sub(_ anchor: Date, notify: Int = 3, status: SubscriptionStatus = .active,
                     trialEnds: Date? = nil, frequency: BillingFrequency = .monthly) -> Subscription {
        var s = TestFactories.makeSubscription(billingFrequency: frequency, status: status, nextBillingDate: anchor)
        s.notifyBeforeDays = notify
        s.trialEndsAt = trialEnds
        return s
    }

    func testReminderOffMeansNone() {
        XCTAssertTrue(ReminderPlanner.plan(for: [sub(day(2026, 10, 30), notify: 0)], now: day(2026, 10, 22, hour: 8), calendar: cal).isEmpty)
    }

    func testRemindersForTwoCycles() {
        let plan = ReminderPlanner.plan(for: [sub(day(2026, 10, 30))], now: day(2026, 10, 22, hour: 8), calendar: cal)
        let got = plan.map { "\($0.kind.rawValue) \(ymd($0.fireDate)) \(cal.component(.hour, from: $0.fireDate))" }
        XCTAssertEqual(got, [
            "renewalHeadsUp 2026-10-27 9", "renewalTomorrow 2026-10-29 11", "renewalToday 2026-10-30 9",
            "renewalHeadsUp 2026-11-27 9", "renewalTomorrow 2026-11-29 11", "renewalToday 2026-11-30 9",
        ])
    }

    func testOneDayReminderHasNoSeparateHeadsUp() {
        let plan = ReminderPlanner.plan(for: [sub(day(2026, 10, 30), notify: 1)], now: day(2026, 10, 22, hour: 8), calendar: cal)
        XCTAssertFalse(plan.contains { $0.kind == .renewalHeadsUp })
        XCTAssertEqual(plan.count, 4)
    }

    func testPastFireTimesAreSkipped() {
        // Renews today; it is 10:00, so the 09:00 "today" and yesterday's reminders are gone.
        let plan = ReminderPlanner.plan(for: [sub(day(2026, 10, 22))], now: day(2026, 10, 22, hour: 10), calendar: cal)
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > day(2026, 10, 22, hour: 10) })
        XCTAssertTrue(plan.contains { $0.kind == .renewalToday && ymd($0.eventDate) == "2026-11-22" })
    }

    func testBudgetKeepsTheSoonest() {
        let subs = (0..<30).map { sub(day(2026, 11, 1 + $0 % 28)) }
        let plan = ReminderPlanner.plan(for: subs, now: day(2026, 10, 22, hour: 8), calendar: cal)
        XCTAssertEqual(plan.count, ReminderPlanner.defaultBudget)
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
        XCTAssertEqual(Set(plan.map(\.identifier)).count, plan.count, "identifiers are unique")
    }

    func testCancelledSubscriptionGetsNoReminders() {
        XCTAssertTrue(ReminderPlanner.plan(for: [sub(day(2026, 10, 30), status: .cancelled)], now: day(2026, 10, 22, hour: 8), calendar: cal).isEmpty)
    }

    func testTrialGetsOneTrialReminderInsteadOfDuplicates() {
        let plan = ReminderPlanner.plan(for: [sub(day(2026, 10, 25), status: .trial, trialEnds: day(2026, 10, 25))],
                                        now: day(2026, 10, 22, hour: 8), calendar: cal)
        XCTAssertEqual(plan.filter { $0.kind == .trialEnding }.map { ymd($0.fireDate) }, ["2026-10-24"])
        XCTAssertFalse(plan.contains { $0.kind != .trialEnding && ymd($0.eventDate) == "2026-10-25" })
        XCTAssertTrue(plan.contains { $0.kind == .renewalToday && ymd($0.eventDate) == "2026-11-25" })
    }

    func testPlanIsDeterministic() {
        let subs = [sub(day(2026, 10, 30)), sub(day(2026, 11, 3), notify: 7)]
        XCTAssertEqual(ReminderPlanner.plan(for: subs, now: day(2026, 10, 22, hour: 8), calendar: cal),
                       ReminderPlanner.plan(for: subs, now: day(2026, 10, 22, hour: 8), calendar: cal))
    }

    // MARK: - Lifecycle

    func testEndedTrialsAndRenewalsSinceLastRun() {
        let trial = sub(day(2026, 11, 21), status: .trial, trialEnds: day(2026, 10, 21))
        let trialToday = sub(day(2026, 11, 22), status: .trial, trialEnds: day(2026, 10, 22))
        let monthly = sub(day(2026, 9, 15))
        let cancelled = sub(day(2026, 9, 15), status: .cancelled)
        let changes = SubscriptionLifecycle.changes(for: [trial, trialToday, monthly, cancelled],
                                                    since: day(2026, 10, 1), now: day(2026, 10, 22, hour: 9), calendar: cal)
        XCTAssertEqual(Set(changes.endedTrials.keys), [trial.id])
        XCTAssertEqual(changes.renewals.map(\.subscriptionId), [monthly.id])
        XCTAssertEqual(changes.renewals.map { ymd($0.date) }, ["2026-10-15"])
    }

    func testFirstRunDoesNotBackfill() {
        let changes = SubscriptionLifecycle.changes(for: [sub(day(2020, 1, 15))], since: nil, now: day(2026, 10, 22), calendar: cal)
        XCTAssertTrue(changes.renewals.isEmpty)
    }

    // MARK: - Event log

    func testEventLogPersistsAndCaps() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("events-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let s = sub(day(2026, 10, 30))
        let log = LifecycleEventLog(fileURL: url)
        log.record(.added, for: s, date: day(2026, 10, 1))
        log.record(.priceChanged, for: s, date: day(2026, 10, 2), previousAmount: 9.99)
        let reloaded = LifecycleEventLog(fileURL: url)
        XCTAssertEqual(reloaded.events.map(\.kind), [.added, .priceChanged])
        XCTAssertEqual(reloaded.events.last?.previousAmount, 9.99)

        for i in 0..<(LifecycleEventLog.maxEvents + 5) { log.record(.renewed, for: s, date: day(2026, 1, 1).addingTimeInterval(Double(i))) }
        XCTAssertEqual(log.events.count, LifecycleEventLog.maxEvents)
    }

    // MARK: - Editing keeps the anchor

    func testEditingWithoutChangingTheDateKeepsTheAnchor() {
        let anchor = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let original = TestFactories.makeSubscription(billingFrequency: .monthly, status: .active, nextBillingDate: anchor)
        var draft = SubscriptionEditDraft(from: original)
        XCTAssertEqual(draft.nextBillingDate, original.calculatedNextBillingDate, "the form shows the upcoming renewal")
        draft.name = "Netflix Premium"
        XCTAssertEqual(draft.applied(to: original)?.nextBillingDate, anchor)
    }

    func testPickingANewDayMovesTheAnchorToNoon() {
        let original = TestFactories.makeSubscription(billingFrequency: .monthly, status: .active,
                                                      nextBillingDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!)
        var draft = SubscriptionEditDraft(from: original)
        let picked = Calendar.current.date(byAdding: .day, value: 12, to: Date())!
        draft.nextBillingDate = picked
        let saved = draft.applied(to: original)?.nextBillingDate
        XCTAssertNotNil(saved)
        XCTAssertTrue(Calendar.current.isDate(saved!, inSameDayAs: picked))
        XCTAssertEqual(Calendar.current.component(.hour, from: saved!), 12)
    }
}
