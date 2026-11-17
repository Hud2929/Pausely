import XCTest
@testable import Pausely

/// The two parts the engine hands its work to: finding the schedule in one merchant's charges, and
/// saying what follows from the subscriptions that were proven. Each is tested here on its own; the
/// engine's tests hold what they come to together.
final class ChargeScheduleTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func charge(_ id: String, on date: Date, _ amount: Decimal) -> ReceiptSignal {
        ReceiptSignal(id: id, date: date, senderDomain: "example.com", senderName: "Example", merchantHint: nil,
                      platform: "direct", kind: .charge, amount: amount, currency: "USD", cadenceHint: nil,
                      trialDays: nil, renewalLanguage: false, oneTimeLanguage: false, promotional: false)
    }

    // MARK: - The schedule

    /// A receipt and the payment notice that follows it a day later are one charge, not two.
    func testAReceiptAndItsPaymentNoticeAreOneCharge() {
        let charges = [charge("receipt", on: day(2026, 3, 5), 9.99),
                       charge("notice", on: day(2026, 3, 6), 9.99),
                       charge("next", on: day(2026, 4, 5), 9.99)]

        XCTAssertEqual(ChargeSchedule.collapsing(charges).map(\.id), ["receipt", "next"])
    }

    func testSixMonthlyChargesAreAMonthlySchedule() throws {
        let charges = (1...6).map { charge("m\($0)", on: day(2026, $0, 5), 9.99) }

        let schedule = try XCTUnwrap(ChargeSchedule.best(in: charges))

        XCTAssertEqual(schedule.cadence.frequency, .monthly)
        XCTAssertEqual(schedule.charges.map(\.id), ["m1", "m2", "m3", "m4", "m5", "m6"])
        XCTAssertEqual(schedule.regularity, 1.0, accuracy: 0.001)
    }

    /// One charge is no pattern, and neither are two that are no billing period apart.
    func testChargesThatFollowNoPeriodAreNoSchedule() {
        XCTAssertNil(ChargeSchedule.best(in: [charge("only", on: day(2026, 1, 5), 9.99)]))
        XCTAssertNil(ChargeSchedule.best(in: [charge("a", on: day(2026, 1, 5), 9.99),
                                              charge("b", on: day(2026, 6, 4), 9.99)]))
    }

    /// Paid monthly for half a year, then by the year: what is billed today is the yearly plan,
    /// though the monthly run is the longer one.
    func testAPlanThatChangedItsPeriodIsTheOneThatReachesTheNewestCharge() throws {
        let monthly = (1...6).map { charge("m\($0)", on: day(2025, $0, 5), 9.99) }
        let yearly = [charge("y1", on: day(2025, 8, 1), 99), charge("y2", on: day(2026, 8, 1), 99)]

        let schedule = try XCTUnwrap(ChargeSchedule.best(in: monthly + yearly))

        XCTAssertEqual(schedule.cadence.frequency, .yearly)
        XCTAssertEqual(schedule.charges.map(\.id), ["y1", "y2"])
    }

    /// A plan billed on the 5th of each month, and one other charge from the same company on the
    /// 20th of February. Read as a fortnightly plan, every charge fits if two receipts are taken to
    /// be missing; read as a monthly plan, four fit exactly and one is left over. The plan is monthly.
    func testAChargeInTheMiddleOfAMonthDoesNotMakeAMonthlyPlanFortnightly() throws {
        var charges = (1...4).map { charge("m\($0)", on: day(2026, $0, 5), 9.99) }
        charges.append(charge("stray", on: day(2026, 2, 20), 24))

        let schedule = try XCTUnwrap(ChargeSchedule.best(in: charges))

        XCTAssertEqual(schedule.cadence.frequency, .monthly)
        XCTAssertEqual(schedule.charges.map(\.id), ["m1", "m2", "m3", "m4"])
    }

    /// The same for a plan billed every three months, with a smaller purchase a month after the first.
    func testAStrayChargeDoesNotMakeAQuarterlyPlanMonthly() throws {
        var charges = [charge("q1", on: day(2026, 1, 5), 30), charge("q2", on: day(2026, 4, 5), 30),
                       charge("q3", on: day(2026, 7, 5), 30)]
        charges.append(charge("stray", on: day(2026, 2, 5), 12))

        let schedule = try XCTUnwrap(ChargeSchedule.best(in: charges))

        XCTAssertEqual(schedule.cadence.frequency, .quarterly)
        XCTAssertEqual(schedule.charges.map(\.id), ["q1", "q2", "q3"])
    }

    /// A monthly plan with one receipt missing is still monthly, with nothing left over.
    func testAMissingReceiptDoesNotBreakAMonthlyPlan() throws {
        let charges = [1, 2, 4, 5, 6].map { charge("m\($0)", on: day(2026, $0, 5), 9.99) }

        let schedule = try XCTUnwrap(ChargeSchedule.best(in: charges))

        XCTAssertEqual(schedule.cadence.frequency, .monthly)
        XCTAssertEqual(schedule.charges.map(\.id), ["m1", "m2", "m4", "m5", "m6"])
    }

    /// Receipts at one price in October, then March, June, August, September and October: a monthly
    /// plan with mail deleted. Read as quarterly, March, June and September fit with nothing missing,
    /// but August and October, at the plan's own price, would have to be something else.
    func testChargesAtThePlansPriceAreNotLeftOutToMakeARarerPeriodFit() throws {
        let months = [(2025, 10), (2026, 3), (2026, 6), (2026, 8), (2026, 9), (2026, 10)]
        let charges = months.map { charge("\($0.0)-\($0.1)", on: day($0.0, $0.1, 20), 22.60) }

        let schedule = try XCTUnwrap(ChargeSchedule.best(in: charges))

        XCTAssertEqual(schedule.cadence.frequency, .monthly)
        XCTAssertEqual(schedule.charges.map(\.id), ["2026-3", "2026-6", "2026-8", "2026-9", "2026-10"])
        XCTAssertEqual(schedule.missed, 3)
    }

    func testTwoAmountsAreTheSameWithinTheShareGiven() {
        XCTAssertTrue(ChargeSchedule.sameAmount(10, 10.2, tolerance: 0.02))
        XCTAssertFalse(ChargeSchedule.sameAmount(10, 10.3, tolerance: 0.02))
        XCTAssertTrue(ChargeSchedule.sameAmount(0, 0, tolerance: 0.02))
    }

    // MARK: - What follows

    private func proven(_ id: String, amount: Decimal, status: ProvenSubscription.Status, tier: ProvenSubscription.Tier,
                        previous: Decimal? = nil) -> ProvenSubscription {
        ProvenSubscription(id: id, name: "Example", merchantKey: "example", category: nil, cancelURL: nil,
                           amount: amount, currency: "USD", frequency: .monthly, lastChargeDate: day(2026, 10, 5),
                           nextBillingDate: day(2026, 11, 5), status: status, score: 80, tier: tier, evidence: [],
                           reasons: [], previousAmount: previous, trialEndsOn: nil)
    }

    /// A price that rose is said once, with what the rise comes to over a year.
    func testARiseInPriceIsSaidWithWhatItCostsOverAYear() throws {
        let sub = proven("example|monthly|USD", amount: 9.99, status: .priceIncreased, tier: .confirmed, previous: 7.99)

        let insights = SubscriptionInsights.all(for: [sub], groups: [:], now: day(2026, 10, 7), calendar: calendar)

        XCTAssertEqual(insights.map(\.id), ["price|example|monthly|USD"])
        XCTAssertEqual(insights.first?.kind, .priceIncrease)
        XCTAssertEqual(insights.first?.annualImpact, Decimal(string: "24.00"))
    }

    /// Nothing is said about a subscription that is only worth a look.
    func testNothingIsSaidAboutWhatIsNotYetLikely() {
        let sub = proven("example|monthly|USD", amount: 9.99, status: .priceIncreased, tier: .review, previous: 7.99)

        XCTAssertEqual(SubscriptionInsights.all(for: [sub], groups: [:], now: day(2026, 10, 7), calendar: calendar).map(\.id), [])
    }

    /// A declined card is said only while no charge has gone through since.
    func testAFailedPaymentIsSaidUntilAChargeGoesThrough() {
        let sub = proven("example|monthly|USD", amount: 9.99, status: .active, tier: .confirmed)
        var failure = charge("declined", on: day(2026, 10, 6), 9.99)
        failure.kind = .paymentFailed
        let merchant = MerchantCatalog.builtin.resolve(hint: "Netflix", senderName: "Netflix", senderDomain: "netflix.com")!
        let groups: SubscriptionInsights.Groups = ["example": (merchant, [failure])]

        let after = SubscriptionInsights.all(for: [sub], groups: groups, now: day(2026, 10, 7), calendar: calendar)
        XCTAssertEqual(after.map(\.id), ["failed|example|monthly|USD"])

        var paid = sub
        paid.lastChargeDate = day(2026, 10, 7)
        XCTAssertEqual(SubscriptionInsights.all(for: [paid], groups: groups, now: day(2026, 10, 8), calendar: calendar).map(\.id), [])
    }
}
