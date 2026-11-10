import XCTest
@testable import Pausely

/// Home's 30-day line: which charges are on it, on which day, and what leaves by a given day.
final class HorizonTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()
    private let rates = CurrencyRates(perUSD: ["USD": 1, "CAD": 2])

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func subscription(_ name: String, _ amount: String, anchor: Date?, frequency: BillingFrequency = .monthly,
                              currency: String = "USD", status: SubscriptionStatus = .active,
                              trialEnds: Date? = nil) -> Subscription {
        Subscription(name: name, amount: Decimal(string: amount)!, currency: currency, billingFrequency: frequency,
                     nextBillingDate: anchor, trialEndsAt: trialEnds, status: status)
    }

    func testChargesAreOrderedByDayAndCoverAFullMonth() {
        let now = day(2026, 11, 10, hour: 15)
        let charges = Horizon.charges(for: [
            subscription("Late", "5.00", anchor: day(2026, 12, 12)),      // day 32: outside
            subscription("Edge", "6.00", anchor: day(2026, 12, 11)),      // day 31: inside
            subscription("Today", "7.00", anchor: day(2026, 11, 10)),
            subscription("Soon", "8.00", anchor: day(2026, 11, 15)),
        ], now: now, calendar: calendar)
        // A monthly charge that falls today falls again 30 days later, inside the window.
        XCTAssertEqual(charges.map(\.name), ["Today", "Soon", "Today", "Edge"])
        XCTAssertEqual(charges.map(\.dayOffset), [0, 5, 30, 31])
    }

    func testASubscriptionAddedTodayForNextMonthIsOnTheLine() {
        // The add flow's default date is one month out: 30 days in November, 31 in December.
        for (now, next) in [(day(2026, 11, 10), day(2026, 12, 10)), (day(2026, 12, 10), day(2027, 1, 10))] {
            let charges = Horizon.charges(for: [subscription("New", "9.99", anchor: next)], now: now, calendar: calendar)
            XCTAssertEqual(charges.count, 1, "a charge one month from \(now) is shown")
        }
    }

    func testAPastAnchorRollsForwardAndWeeklyChargesRepeat() {
        let now = day(2026, 11, 10)
        let monthly = Horizon.charges(for: [subscription("Netflix", "17.99", anchor: day(2026, 3, 27))],
                                      now: now, calendar: calendar)
        XCTAssertEqual(monthly.map(\.dayOffset), [17], "the 27th of this month")

        let weekly = Horizon.charges(for: [subscription("Paper", "2.00", anchor: day(2026, 11, 12), frequency: .weekly)],
                                     now: now, calendar: calendar)
        XCTAssertEqual(weekly.map(\.dayOffset), [2, 9, 16, 23, 30])
    }

    func testTrialIsChargedWhenItEndsAndInactiveOnesAreLeftOut() {
        let now = day(2026, 11, 10)
        let charges = Horizon.charges(for: [
            subscription("Trial", "9.99", anchor: day(2026, 11, 12), status: .trial, trialEnds: day(2026, 11, 14)),
            subscription("Cancelled", "9.99", anchor: day(2026, 11, 12), status: .cancelled),
            subscription("Paused", "9.99", anchor: day(2026, 11, 12), status: .paused),
            subscription("No date", "9.99", anchor: nil),
        ], now: now, calendar: calendar)
        XCTAssertEqual(charges.count, 1)
        XCTAssertEqual(charges.first?.name, "Trial")
        XCTAssertEqual(charges.first?.dayOffset, 4)
        XCTAssertEqual(charges.first?.isTrialEnd, true)
    }

    func testTotalThroughADayConvertsAndSkipsWhatCannotBeConverted() {
        let now = day(2026, 11, 10)
        let charges = Horizon.charges(for: [
            subscription("A", "10.00", anchor: day(2026, 11, 11)),
            subscription("B", "20.00", anchor: day(2026, 11, 20), currency: "CAD"),   // 10 USD
            subscription("C", "99.00", anchor: day(2026, 11, 12), currency: "XXX"),   // unknown
        ], now: now, calendar: calendar)
        XCTAssertEqual(Horizon.total(of: charges, through: 5, in: "USD", rates: rates), 10)
        XCTAssertEqual(Horizon.total(of: charges, through: 29, in: "USD", rates: rates), 20)
        // A is charged again on day 31 (Dec 11).
        XCTAssertEqual(Horizon.total(of: charges, through: 31, in: "USD", rates: rates), 30)
        XCTAssertEqual(Horizon.total(of: charges, through: 0, in: "USD", rates: rates), 0)
    }

    func testUndatedListsOnlyActiveSubscriptionsWithoutARenewalDate() {
        let undated = Horizon.undated([
            subscription("Tallied", "5.00", anchor: nil),
            subscription("Dated", "5.00", anchor: day(2026, 11, 20)),
            subscription("Gone", "5.00", anchor: nil, status: .cancelled),
        ])
        XCTAssertEqual(undated.map(\.name), ["Tallied"])
    }
}
