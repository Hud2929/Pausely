import XCTest
@testable import Pausely

/// The sentence on the paywall that compares a year of Pro with the person's own subscriptions.
final class PaywallCaseTests: XCTestCase {
    private let rates = CurrencyRates(perUSD: ["USD": 1, "CAD": 2])

    private func subscription(_ name: String, _ amount: String, currency: String = "USD",
                              frequency: BillingFrequency = .monthly, status: SubscriptionStatus = .active) -> Subscription {
        Subscription(name: name, amount: Decimal(string: amount)!, currency: currency,
                     billingFrequency: frequency, status: status)
    }

    func testComparesWithTheMostExpensiveSubscription() {
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("iCloud+", "2.99"), subscription("Netflix", "17.99")],
                                            rates: rates)
        // 29.99 is more than one month of Netflix (17.99) and less than two (35.98).
        XCTAssertEqual(result, .init(name: "Netflix", months: 2))
    }

    func testOneMonthWhenASingleChargeAlreadyCostsMore() {
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("Gym", "45.00")], rates: rates)
        XCTAssertEqual(result, .init(name: "Gym", months: 1))
    }

    func testExactMultipleIsNotCalledLess() {
        // Two months cost exactly 30.00: "less than 2 months" would be false, so it says 3.
        let result = PaywallCase.comparison(proYearly: 30, proCurrency: "USD",
                                            subscriptions: [subscription("Music", "15.00")], rates: rates)
        XCTAssertEqual(result, .init(name: "Music", months: 3))
    }

    func testConvertsBeforeComparingAndIgnoresWhatItCannotConvert() {
        // 20 CAD is 10 USD here, so the USD subscription at 12 is the most expensive.
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("Crave", "20.00", currency: "CAD"),
                                                            subscription("Spotify", "12.00"),
                                                            subscription("Mystery", "900.00", currency: "XXX")],
                                            rates: rates)
        XCTAssertEqual(result, .init(name: "Spotify", months: 3))
    }

    func testCancelledAndPausedSubscriptionsAreNotUsed() {
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("Old gym", "60.00", status: .cancelled),
                                                            subscription("Paused", "50.00", status: .paused)],
                                            rates: rates)
        XCTAssertNil(result)
    }

    func testNoComparisonWhenItWouldTakeMoreThanSixMonthsOrThereIsNoPrice() {
        XCTAssertNil(PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("iCloud+", "0.99")], rates: rates))
        XCTAssertNil(PaywallCase.comparison(proYearly: 0, proCurrency: "USD",
                                            subscriptions: [subscription("Netflix", "17.99")], rates: rates))
        XCTAssertNil(PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [], rates: rates))
    }

    func testYearlySubscriptionsAreComparedByTheirMonthlyCost() {
        // 120 a year is 10 a month: a year of Pro (29.99) is less than 3 months of it.
        let result = PaywallCase.comparison(proYearly: Decimal(string: "29.99")!, proCurrency: "USD",
                                            subscriptions: [subscription("Prime", "120.00", frequency: .yearly)], rates: rates)
        XCTAssertEqual(result, .init(name: "Prime", months: 3))
    }
}
