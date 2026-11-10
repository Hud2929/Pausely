import XCTest
@testable import Pausely

/// The Subscriptions list: which group each subscription lands in, and the order inside a group.
final class SubscriptionGroupsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()
    private lazy var now = day(2026, 11, 10, hour: 15)

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func sub(_ name: String, _ amount: String = "10.00", anchor: Date? = nil,
                     status: SubscriptionStatus = .active, pausedUntil: Date? = nil) -> Subscription {
        Subscription(name: name, amount: Decimal(string: amount)!, currency: "USD", nextBillingDate: anchor,
                     status: status, pausedUntil: pausedUntil)
    }

    func testEachSubscriptionLandsInTheRightGroup() {
        let decide = sub("Decide", anchor: day(2026, 11, 12))
        let cases: [(Subscription, SubscriptionGroups.Group)] = [
            (decide, .decide),
            (sub("Week", anchor: day(2026, 11, 17)), .thisWeek),          // 7 days
            (sub("Month", anchor: day(2026, 11, 18)), .thisMonth),        // 8 days
            (sub("MonthEdge", anchor: day(2026, 12, 10)), .thisMonth),    // 30 days
            (sub("Tallied"), .undated),
            (sub("Gone", anchor: day(2026, 11, 12), status: .cancelled), .cancelled),
            (sub("Expired", status: .expired), .cancelled),
            (sub("Resting", anchor: day(2026, 11, 12), pausedUntil: day(2027, 1, 1)), .paused),
        ]
        for (subscription, expected) in cases {
            XCTAssertEqual(SubscriptionGroups.group(for: subscription, pending: [decide.id], now: now, calendar: calendar),
                           expected, subscription.name)
        }
        let yearly = Subscription(name: "Yearly", amount: 99, currency: "USD", billingFrequency: .yearly,
                                  nextBillingDate: day(2027, 3, 1))
        XCTAssertEqual(SubscriptionGroups.group(for: yearly, pending: [], now: now, calendar: calendar), .later)
    }

    func testSectionsAreInDisplayOrderSoonestFirstAndEmptyOnesAreLeftOut() {
        let sections = SubscriptionGroups.sections([
            sub("Cheap no date", "3.00"),
            sub("B later this week", anchor: day(2026, 11, 16)),
            sub("Costly no date", "30.00"),
            sub("A sooner this week", anchor: day(2026, 11, 11)),
            sub("Cancelled", status: .cancelled),
        ], pending: [], now: now, calendar: calendar)

        XCTAssertEqual(sections.map(\.group), [.thisWeek, .undated, .cancelled])
        XCTAssertEqual(sections[0].subscriptions.map(\.name), ["A sooner this week", "B later this week"])
        XCTAssertEqual(sections[1].subscriptions.map(\.name), ["Costly no date", "Cheap no date"])
    }

    func testAPendingDecisionOutranksThisWeek() {
        let netflix = sub("Netflix", anchor: day(2026, 11, 11))
        let without = SubscriptionGroups.sections([netflix], pending: [], now: now, calendar: calendar)
        let with = SubscriptionGroups.sections([netflix], pending: [netflix.id], now: now, calendar: calendar)
        XCTAssertEqual(without.map(\.group), [.thisWeek])
        XCTAssertEqual(with.map(\.group), [.decide])
    }
}
