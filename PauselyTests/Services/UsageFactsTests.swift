import XCTest
@testable import Pausely

/// What the hours a person typed say about their subscriptions: their figures and plain arithmetic.
final class UsageFactsTests: XCTestCase {

    private func sub(_ name: String, _ amount: String, currency: String = "USD", frequency: BillingFrequency = .monthly,
                     status: SubscriptionStatus = .active) -> Subscription {
        Subscription(name: name, amount: Decimal(string: amount)!, currency: currency, billingFrequency: frequency, status: status)
    }

    private func facts(_ subscriptions: [Subscription], minutes: [String: Int],
                       currency: String = "USD") -> (used: [UsageFacts.Line], unused: [UsageFacts.Line]) {
        UsageFacts.lines(for: subscriptions, minutesThisMonth: { minutes[$0.name] }, currency: currency, rates: .fallback)
    }

    func testAnHourCostsTheMonthDividedByTheHoursTyped() {
        let result = facts([sub("Netflix", "15.00")], minutes: ["Netflix": 300])
        XCTAssertEqual(result.used.map(\.subscription.name), ["Netflix"])
        XCTAssertEqual(result.used.first?.costPerHour, 3)
        XCTAssertEqual(result.unused, [])
    }

    func testAYearlyPriceIsCountedByTheMonth() {
        let result = facts([sub("Notion", "120.00", frequency: .yearly)], minutes: ["Notion": 60])
        XCTAssertEqual(result.used.first?.monthly, 10)
        XCTAssertEqual(result.used.first?.costPerHour, 10)
    }

    func testTheDearestHourComesFirst() {
        let result = facts([sub("Cheap hour", "10.00"), sub("Dear hour", "10.00"), sub("Middle", "30.00")],
                           minutes: ["Cheap hour": 600, "Dear hour": 30, "Middle": 300])
        XCTAssertEqual(result.used.map(\.subscription.name), ["Dear hour", "Middle", "Cheap hour"])
        XCTAssertEqual(result.used.map(\.costPerHour), [20, 6, 1])
    }

    /// Zero is an answer ("I haven't used it"); nothing typed is not, and says nothing.
    func testNotUsedIsOnlyWhatWasEnteredAsZero() {
        let result = facts([sub("Gym", "40.00"), sub("Hulu", "8.00"), sub("Never asked", "99.00")],
                           minutes: ["Gym": 0, "Hulu": 0])
        XCTAssertEqual(result.used, [])
        XCTAssertEqual(result.unused.map(\.subscription.name), ["Gym", "Hulu"], "the dearest month first")
        XCTAssertNil(result.unused.first?.costPerHour)
    }

    func testOnlyWhatIsChargingIsCounted() {
        let result = facts([sub("Cancelled", "10.00", status: .cancelled), sub("Trial", "10.00", status: .trial)],
                           minutes: ["Cancelled": 0, "Trial": 120])
        XCTAssertEqual(result.unused, [])
        XCTAssertEqual(result.used.map(\.subscription.name), ["Trial"])
    }

    func testAPriceInAnotherCurrencyIsConvertedAndSaysSo() throws {
        let result = facts([sub("DAZN", "20.00", currency: "EUR")], minutes: ["DAZN": 60])
        let line = try XCTUnwrap(result.used.first)
        XCTAssertTrue(line.isConverted)
        XCTAssertEqual(line.monthly, CurrencyRates.fallback.convert(20, from: "EUR", to: "USD"))
    }

    func testAPriceThatCannotBeConvertedIsLeftOut() {
        let result = facts([sub("Mystery", "20.00", currency: "ZZZ")], minutes: ["Mystery": 60])
        XCTAssertEqual(result.used, [])
    }

    /// Hours typed on an Arabic or a Japanese keyboard are hours too.
    func testHoursAreReadInAnyDigits() {
        XCTAssertEqual(UsageInputSheet.totalMinutes(hours: "٣", minutes: "٢٠"), 200)
        XCTAssertEqual(UsageInputSheet.totalMinutes(hours: "１２", minutes: ""), 720)
        XCTAssertEqual(UsageInputSheet.totalMinutes(hours: "2", minutes: "5"), 125)
        XCTAssertNil(UsageInputSheet.totalMinutes(hours: "abc", minutes: ""))
        XCTAssertNil(UsageInputSheet.totalMinutes(hours: "", minutes: "75"))
        XCTAssertNil(UsageInputSheet.totalMinutes(hours: "900", minutes: ""))
    }
}
