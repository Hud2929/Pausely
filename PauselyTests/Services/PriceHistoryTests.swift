import XCTest
@testable import Pausely

/// The price history, read from the event log, and what counts as a price going up or down.
final class PriceHistoryTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private let id = UUID()

    private func sub(_ amount: Decimal, _ currency: String = "USD", _ frequency: BillingFrequency = .monthly) -> Subscription {
        TestFactories.makeSubscription(id: id, name: "Netflix", amount: amount, currency: currency, billingFrequency: frequency)
    }

    private func added(_ amount: Decimal, on date: Date, _ currency: String = "USD", _ frequency: BillingFrequency = .monthly) -> LifecycleEvent {
        LifecycleEvent(kind: .added, subscription: sub(amount, currency, frequency), date: date)
    }

    /// The person changed it to `amount`; it was `previous` before.
    private func changed(to amount: Decimal, from previous: Decimal, on date: Date, _ currency: String = "USD",
                         _ frequency: BillingFrequency = .monthly) -> LifecycleEvent {
        LifecycleEvent(kind: .priceChanged, subscription: sub(amount, currency, frequency), date: date, previousAmount: previous)
    }

    private func change(_ now: Subscription, _ events: [LifecycleEvent]) -> PriceHistory.Change? {
        PriceHistory.latestChange(for: now, events: events, calendar: cal)
    }

    // MARK: The record

    func testEveryPriceOnRecordOldestFirst() {
        let events = [changed(to: 17, from: 15, on: day(2026, 6, 1)), added(15, on: day(2026, 1, 10)),
                      LifecycleEvent(kind: .kept, subscription: sub(17), date: day(2026, 7, 1))]
        let points = PriceHistory.points(for: id, events: events)
        XCTAssertEqual(points.map(\.amount), [15, 17])
        XCTAssertEqual(points.map(\.date), [day(2026, 1, 10), day(2026, 6, 1)])
    }

    /// Added before events were kept: the earlier price is known from the first change, its day is not.
    func testAHistoryThatStartsWithAChangeStillKnowsThePriceBefore() {
        let points = PriceHistory.points(for: id, events: [changed(to: 17, from: 15, on: day(2026, 6, 1))])
        XCTAssertEqual(points.map(\.amount), [15, 17])
        XCTAssertNil(points[0].date)
        XCTAssertEqual(points[1].date, day(2026, 6, 1))
        XCTAssertEqual(Set(points.map(\.id)).count, 2)
    }

    // MARK: What counts as a change

    func testAPricePaidForAndThenRaisedWentUp() {
        let events = [added(15, on: day(2026, 1, 10)), changed(to: 17, from: 15, on: day(2026, 6, 1))]
        let up = change(sub(17), events)
        XCTAssertEqual(up, PriceHistory.Change(from: 15, to: 17, currency: "USD", since: day(2026, 6, 1)))
        XCTAssertEqual(up?.isIncrease, true)

        let down = change(sub(12), [added(15, on: day(2026, 1, 10)), changed(to: 12, from: 15, on: day(2026, 6, 1))])
        XCTAssertEqual(down?.isIncrease, false)
    }

    /// It was added at the catalog's typical price and corrected when the first real charge came, or
    /// a slip of the finger was fixed. The service never charged the earlier price, so nothing went up.
    func testCorrectingAPriceThatWasNeverChargedIsNotAPriceChange() {
        let typo = [added(Decimal(string: "5.49")!, on: day(2026, 11, 1)), changed(to: Decimal(string: "15.49")!, from: Decimal(string: "5.49")!, on: day(2026, 11, 1))]
        XCTAssertNil(change(sub(Decimal(string: "15.49")!), typo))

        let firstCharge = [added(15, on: day(2026, 11, 1)), changed(to: 17, from: 15, on: day(2026, 11, 28))]
        XCTAssertNil(change(sub(17), firstCharge), "27 days in: the monthly price had not been charged once")

        let afterOnePeriod = [added(15, on: day(2026, 11, 1)), changed(to: 17, from: 15, on: day(2026, 12, 1))]
        XCTAssertEqual(change(sub(17), afterOnePeriod)?.from, 15)
    }

    /// 10 US dollars edited to 14 Canadian dollars used to read "went up", with the difference shown
    /// in the new currency.
    func testACurrencyOrBillingPeriodChangeIsNotAPriceChange() {
        let currency = [added(10, on: day(2026, 1, 10)), changed(to: 14, from: 10, on: day(2026, 6, 1), "CAD")]
        XCTAssertNil(change(sub(14, "CAD"), currency))

        let period = [added(10, on: day(2026, 1, 10)), changed(to: 100, from: 10, on: day(2026, 6, 1), "USD", .yearly)]
        XCTAssertNil(change(sub(100, "USD", .yearly), period))
    }

    func testOnlyTheLatestChangeCountsAndOnlyWhileItStands() {
        let events = [added(11, on: day(2026, 1, 1)), changed(to: 12, from: 11, on: day(2026, 3, 1)),
                      changed(to: 13, from: 12, on: day(2026, 6, 1))]
        XCTAssertEqual(change(sub(13), events), PriceHistory.Change(from: 12, to: 13, currency: "USD", since: day(2026, 6, 1)))
        XCTAssertNil(change(sub(20), events), "today's price isn't the one on record")
        XCTAssertNil(change(sub(13, "EUR"), events), "nor is its currency")
        XCTAssertNil(change(sub(11), [added(11, on: day(2026, 1, 1))]), "a single price is not a change")
    }

    func testAnEarlierPriceWithNoDateIsTakenAsPaid() {
        let events = [changed(to: 17, from: 15, on: day(2026, 6, 1))]
        XCTAssertEqual(change(sub(17), events)?.from, 15)
    }
}

/// The year slip on Profile: what it counts, and from where.
final class YearSlipTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func event(_ kind: LifecycleEvent.Kind, _ sub: Subscription, on date: Date) -> LifecycleEvent {
        LifecycleEvent(kind: kind, subscription: sub, date: date)
    }

    /// It used to count every cancelled subscription whose record had been touched this year, so an
    /// edit or a sync of an old cancellation counted as cancelling it this year.
    func testCancelledThisYearIsCountedFromTheHistory() {
        let lastYear = TestFactories.makeSubscription(name: "Cancelled last year")
        let thisYear = TestFactories.makeSubscription(name: "Cancelled this year")
        let backOn = TestFactories.makeSubscription(name: "Cancelled then restarted")
        let twice = TestFactories.makeSubscription(name: "Cancelled twice")
        let events = [
            event(.cancelled, lastYear, on: day(2025, 12, 30)),
            event(.priceChanged, lastYear, on: day(2026, 5, 1)),
            event(.cancelled, thisYear, on: day(2026, 2, 1)),
            event(.cancelled, backOn, on: day(2026, 3, 1)), event(.reactivated, backOn, on: day(2026, 4, 1)),
            event(.cancelled, twice, on: day(2026, 1, 5)), event(.reactivated, twice, on: day(2026, 2, 5)),
            event(.cancelled, twice, on: day(2026, 6, 5))
        ]
        XCTAssertEqual(WrappedStats.cancelledThisYear(events, year: 2026, calendar: cal), 2)
        XCTAssertEqual(WrappedStats.cancelledThisYear(events, year: 2025, calendar: cal), 1)

        // Everything cancelled is still a year worth printing: nothing is paid now, and something was kept.
        let allCancelled = WrappedStats(subscriptions: [], events: events, now: day(2026, 11, 12), calendar: cal,
                                        currency: "USD", rates: .fallback)
        XCTAssertFalse(allCancelled.hasNothingToShow)
        XCTAssertEqual(allCancelled.totalCount, 0)
    }

    func testTheSlipGroupsCategoriesAndComparesInOneCurrency() {
        let rates = CurrencyRates(perUSD: ["JPY": 150])
        let list = [
            TestFactories.makeSubscription(name: "Netflix", amount: 15, currency: "USD", category: "entertainment"),
            TestFactories.makeSubscription(name: "Crave", amount: 12, currency: "USD", category: "Entertainment"),
            TestFactories.makeSubscription(name: "Gym", amount: 20, currency: "USD", category: "Health & Fitness"),
            TestFactories.makeSubscription(name: "Yen", amount: 1_500, currency: "JPY", category: "Music")   // 10 dollars
        ]
        let slip = WrappedStats(subscriptions: list, events: [], now: day(2026, 11, 11), calendar: cal, currency: "USD", rates: rates)
        XCTAssertEqual(slip.year, 2026)
        XCTAssertEqual(slip.totalCount, 4)
        XCTAssertEqual(slip.monthlyCost, 57)
        XCTAssertEqual(slip.yearlyCost, 684)
        XCTAssertTrue(slip.isConverted, "the yen were converted, so the totals are estimates")
        XCTAssertEqual(slip.topService, "Gym", "20 dollars, not 1,500 yen")
        XCTAssertEqual(slip.topCategory, "Entertainment", "27 dollars across both spellings")

        let dollarsOnly = WrappedStats(subscriptions: Array(list.prefix(3)), events: [], now: day(2026, 11, 11), calendar: cal,
                                       currency: "USD", rates: rates)
        XCTAssertFalse(dollarsOnly.isConverted)
    }
}

