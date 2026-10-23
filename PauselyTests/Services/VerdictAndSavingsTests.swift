import XCTest
@testable import Pausely

/// Renewal Verdicts and the Savings Receipt: which renewals wait for a decision, what "keep" stops,
/// and the charges a cancellation really avoids.
final class VerdictAndSavingsTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func ymd(_ date: Date) -> String { ReminderPlanner.dayStamp(date, cal) }

    private func sub(_ name: String = "Netflix", amount: Decimal = 20, anchor: Date?, frequency: BillingFrequency = .monthly,
                     status: SubscriptionStatus = .active, notify: Int = 3) -> Subscription {
        var s = TestFactories.makeSubscription(name: name, amount: amount, billingFrequency: frequency,
                                               status: status, nextBillingDate: anchor)
        s.notifyBeforeDays = notify
        return s
    }

    private func event(_ kind: LifecycleEvent.Kind, _ s: Subscription, on date: Date, renewal: Date? = nil) -> LifecycleEvent {
        LifecycleEvent(kind: kind, subscription: s, date: date, renewalDate: renewal)
    }

    // MARK: - Pending decisions

    func testRenewalInsideTheReminderWindowWaitsForADecision() {
        let netflix = sub(anchor: day(2026, 10, 31), notify: 3)
        XCTAssertNil(RenewalDecisions.pending(for: netflix, kept: [], now: day(2026, 10, 27), calendar: cal),
                     "4 days before is outside a 3-day window")
        let pending = RenewalDecisions.pending(for: netflix, kept: [], now: day(2026, 10, 28), calendar: cal)
        XCTAssertEqual(pending.map { ymd($0.date) }, "2026-10-31")
        XCTAssertEqual(pending?.isTrialEnd, false)
    }

    func testRemindMeOffNeverAsks() {
        let netflix = sub(anchor: day(2026, 10, 31), notify: 0)
        XCTAssertNil(RenewalDecisions.pending(for: netflix, kept: [], now: day(2026, 10, 30), calendar: cal))
    }

    func testCancelledAndPausedNeverAsk() {
        let cancelled = sub(anchor: day(2026, 10, 31), status: .cancelled)
        XCTAssertNil(RenewalDecisions.pending(for: cancelled, kept: [], now: day(2026, 10, 30), calendar: cal))
        var paused = sub(anchor: day(2026, 10, 31))
        paused.pausedUntil = day(2026, 12, 1)
        XCTAssertNil(RenewalDecisions.pending(for: paused, kept: [], now: day(2026, 10, 30), calendar: cal))
    }

    func testKeptRenewalStopsAskingUntilTheNextOne() {
        let netflix = sub(anchor: day(2026, 10, 31))
        let kept = RenewalDecisions.keptKeys(in: [event(.kept, netflix, on: day(2026, 10, 29), renewal: day(2026, 10, 31))], calendar: cal)
        XCTAssertNil(RenewalDecisions.pending(for: netflix, kept: kept, now: day(2026, 10, 30), calendar: cal))
        // A month later the next renewal asks again.
        let next = RenewalDecisions.pending(for: netflix, kept: kept, now: day(2026, 11, 28), calendar: cal)
        XCTAssertEqual(next.map { ymd($0.date) }, "2026-11-30")
    }

    func testTrialAsksAboutTheTrialEnd() {
        var trial = sub(anchor: day(2026, 11, 3), status: .trial)
        trial.trialEndsAt = day(2026, 11, 3, hour: 8)
        let pending = RenewalDecisions.pending(for: trial, kept: [], now: day(2026, 11, 1), calendar: cal)
        XCTAssertEqual(pending.map { ymd($0.date) }, "2026-11-03")
        XCTAssertEqual(pending?.isTrialEnd, true)
    }

    func testPendingListIsSoonestFirst() {
        let a = sub("A", anchor: day(2026, 10, 31))
        let b = sub("B", anchor: day(2026, 10, 29))
        let list = RenewalDecisions.pending(in: [a, b], events: [], now: day(2026, 10, 28), calendar: cal)
        XCTAssertEqual(list.map(\.subscriptionId), [b.id, a.id])
    }

    // MARK: - Reminders follow decisions and settings

    func testKeepingARenewalRemovesItsRemaining_reminders() {
        let netflix = sub(anchor: day(2026, 10, 31))
        let now = day(2026, 10, 28, hour: 10)
        let before = ReminderPlanner.plan(for: [netflix], now: now, calendar: cal, cyclesAhead: 2)
        XCTAssertTrue(before.contains { ymd($0.eventDate) == "2026-10-31" })

        let kept = RenewalDecisions.keptKeys(in: [event(.kept, netflix, on: now, renewal: day(2026, 10, 31))], calendar: cal)
        let after = ReminderPlanner.plan(for: [netflix], now: now, calendar: cal, cyclesAhead: 2, kept: kept)
        XCTAssertFalse(after.contains { ymd($0.eventDate) == "2026-10-31" }, "no more reminders about the kept charge")
        XCTAssertTrue(after.contains { ymd($0.eventDate) == "2026-11-30" }, "the next renewal still gets reminders")
    }

    func testSettingsSwitchesTurnReminderKindsOff() {
        let netflix = sub(anchor: day(2026, 10, 31))
        var trial = sub("Notion", anchor: day(2026, 11, 3), status: .trial)
        trial.trialEndsAt = day(2026, 11, 3)
        let now = day(2026, 10, 25)

        let noRenewals = ReminderPlanner.plan(for: [netflix, trial], now: now, calendar: cal,
                                              preferences: .init(renewals: false, trials: true))
        XCTAssertTrue(noRenewals.allSatisfy { $0.kind == .trialEnding })
        XCTAssertFalse(noRenewals.isEmpty)

        let noTrials = ReminderPlanner.plan(for: [netflix, trial], now: now, calendar: cal,
                                            preferences: .init(renewals: true, trials: false))
        XCTAssertFalse(noTrials.contains { $0.kind == .trialEnding })
        XCTAssertFalse(noTrials.isEmpty)
    }

    // MARK: - Savings ledger

    func testCancellationAvoidsTheNextTwelveMonthlyCharges() {
        let netflix = sub(amount: 20, anchor: day(2026, 10, 31))
        let events = [event(.cancelled, netflix, on: day(2026, 10, 29), renewal: day(2026, 10, 31))]

        let early = SavingsLedger.lines(from: events, now: day(2026, 10, 30), calendar: cal)
        XCTAssertEqual(early.count, 1)
        XCTAssertEqual(early[0].avoidedCharges.count, 12, "Oct 31 through Sep 30")
        XCTAssertEqual(ymd(early[0].avoidedCharges.first!), "2026-10-31")
        XCTAssertEqual(ymd(early[0].avoidedCharges.last!), "2027-09-30")
        XCTAssertEqual(early[0].savedSoFar, 0, "nothing saved until the charge day passes")
        XCTAssertEqual(early[0].onTrack, 240)

        let later = SavingsLedger.lines(from: events, now: day(2027, 1, 5), calendar: cal)
        XCTAssertEqual(later[0].avoidedSoFar.map(ymd), ["2026-10-31", "2026-11-30", "2026-12-31"], "month-end anchor doesn't drift")
        XCTAssertEqual(later[0].savedSoFar, 60)
    }

    func testCancellingOnTheRenewalDayDoesNotCountThatCharge() {
        let netflix = sub(amount: 20, anchor: day(2026, 10, 31))
        let lines = SavingsLedger.lines(from: [event(.cancelled, netflix, on: day(2026, 10, 31, hour: 15))],
                                        now: day(2026, 12, 15), calendar: cal)
        XCTAssertEqual(lines[0].avoidedSoFar.map(ymd), ["2026-11-30"])
    }

    func testReactivationStopsTheSavings() {
        let netflix = sub(amount: 20, anchor: day(2026, 10, 31))
        let events = [
            event(.cancelled, netflix, on: day(2026, 10, 29)),
            event(.reactivated, netflix, on: day(2026, 12, 31))
        ]
        let lines = SavingsLedger.lines(from: events, now: day(2027, 6, 1), calendar: cal)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].avoidedCharges.map(ymd), ["2026-10-31", "2026-11-30"],
                       "the Dec 31 charge happened because it started again that day")
        XCTAssertEqual(lines[0].savedSoFar, 40)
        XCTAssertFalse(lines[0].isOngoing)
    }

    func testCancelAgainAfterReactivatingStartsANewLine() {
        let netflix = sub(amount: 20, anchor: day(2026, 10, 31))
        let events = [
            event(.cancelled, netflix, on: day(2026, 10, 29)),
            event(.reactivated, netflix, on: day(2026, 11, 15)),
            event(.cancelled, netflix, on: day(2027, 1, 10)),
            event(.cancelled, netflix, on: day(2027, 1, 11))   // a duplicate while still cancelled
        ]
        let lines = SavingsLedger.lines(from: events, now: day(2027, 3, 1), calendar: cal)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[1].avoidedSoFar.map(ymd), ["2027-01-31", "2027-02-28"])
    }

    func testYearlyPlanCountsOneCharge() {
        let adobe = sub("Adobe", amount: 240, anchor: day(2026, 11, 11), frequency: .yearly)
        let lines = SavingsLedger.lines(from: [event(.cancelled, adobe, on: day(2026, 11, 1))], now: day(2026, 11, 12), calendar: cal)
        XCTAssertEqual(lines[0].avoidedCharges.count, 1)
        XCTAssertEqual(lines[0].savedSoFar, 240)
    }

    func testExcludedSubscriptionsAndPlainDeletesDontCount() {
        let pausely = sub("Pausely Pro", amount: 30, anchor: day(2026, 11, 1), frequency: .yearly)
        let netflix = sub(amount: 20, anchor: day(2026, 10, 31))
        let events = [
            event(.cancelled, pausely, on: day(2026, 10, 20)),
            event(.deleted, netflix, on: day(2026, 10, 20))
        ]
        XCTAssertTrue(SavingsLedger.lines(from: events, now: day(2027, 1, 1), calendar: cal, excluding: [pausely.id]).isEmpty)
    }

    func testTotalsArePerCurrency() {
        let a = sub("A", amount: 10, anchor: day(2026, 11, 1))
        var b = sub("B", amount: 5, anchor: day(2026, 11, 1))
        b.currency = "EUR"
        let events = [event(.cancelled, a, on: day(2026, 10, 20)), event(.cancelled, b, on: day(2026, 10, 20))]
        let totals = SavingsLedger.totals(SavingsLedger.lines(from: events, now: day(2026, 11, 2), calendar: cal))
        XCTAssertEqual(totals.savedSoFar["USD"], 10)
        XCTAssertEqual(totals.savedSoFar["EUR"], 5)
    }

    // MARK: - Verdict facts

    func testPriceChangeComparesWithTheFirstRecordedPrice() {
        let spotify = sub("Spotify", amount: 13, anchor: day(2026, 11, 1))
        let events = [
            LifecycleEvent(kind: .priceChanged, subscription: spotify, date: day(2026, 3, 1), previousAmount: 11),
            LifecycleEvent(kind: .priceChanged, subscription: spotify, date: day(2026, 6, 1), previousAmount: 12)
        ]
        let change = VerdictFacts.priceChange(for: spotify.id, currentAmount: 13, events: events)
        XCTAssertEqual(change?.from, 11)
        XCTAssertEqual(change.map { ymd($0.since) }, "2026-03-01")
        XCTAssertNil(VerdictFacts.priceChange(for: spotify.id, currentAmount: 11, events: events), "back to the original price")
    }

    func testRenewalAfterAChargeForAskAgainText() {
        let netflix = sub(anchor: day(2026, 1, 31))
        XCTAssertEqual(VerdictFacts.renewal(after: day(2026, 10, 31), for: netflix, calendar: cal).map(ymd), "2026-11-30")
    }

    /// The rating prompt waits until Pausely has saved money: the 1st, 3rd and 10th cancellation.
    func testRatingPromptMilestonesFollowTheReceipt() {
        XCTAssertEqual(ReviewPromptManager.milestone(forReceiptLines: 0), 0)
        XCTAssertEqual(ReviewPromptManager.milestone(forReceiptLines: 1), 1)
        XCTAssertEqual(ReviewPromptManager.milestone(forReceiptLines: 2), 1)
        XCTAssertEqual(ReviewPromptManager.milestone(forReceiptLines: 3), 3)
        XCTAssertEqual(ReviewPromptManager.milestone(forReceiptLines: 9), 3)
        XCTAssertEqual(ReviewPromptManager.milestone(forReceiptLines: 25), 10)
    }
}
