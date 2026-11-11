import XCTest
@testable import Pausely

/// "Where it goes" on Insights: what each category costs a month.
final class CategoryTotalsTests: XCTestCase {

    private let rates = CurrencyRates(perUSD: ["USD": 1, "EUR": 0.5])

    private func sub(_ name: String, _ amount: Decimal, _ category: String?, currency: String = "USD",
                     frequency: BillingFrequency = .monthly, status: SubscriptionStatus = .active) -> Subscription {
        Subscription(name: name, category: category, amount: amount, currency: currency, billingFrequency: frequency, status: status)
    }

    func testCategoriesAddUpLargestFirst_withCatalogAndTypedNamesMerged() {
        let totals = [
            sub("Netflix", 15, "entertainment"),          // the catalog's raw value
            sub("Disney+", 10, "Entertainment"),          // the edit screen's display name
            sub("Spotify", 12, "Music"),
            sub("Gym", 240, "Health & Fitness", frequency: .yearly)   // 20 a month
        ].categoryTotals(in: "USD", rates: rates)

        XCTAssertEqual(totals.map(\.category), ["Entertainment", "Health & Fitness", "Music"])
        XCTAssertEqual(totals.map(\.amount), [25, 20, 12])
        XCTAssertEqual(totals.map(\.count), [2, 1, 1])
    }

    func testEachSubscriptionIsConvertedFromItsOwnCurrency() {
        // 10 euros is 20 dollars at these rates; adding the raw numbers would give 20, not 30.
        let totals = [sub("Deezer", 10, "Music", currency: "EUR"), sub("Spotify", 10, "Music")].categoryTotals(in: "USD", rates: rates)
        XCTAssertEqual(totals, [CategoryTotal(category: "Music", amount: 30, count: 2)])
    }

    func testOnlyActiveSubscriptionsCount_andNoCategoryIsOther() {
        let totals = [
            sub("Paused", 50, "Music", status: .paused),
            sub("Cancelled", 50, "Music", status: .cancelled),
            sub("Mystery", 5, nil)
        ].categoryTotals(in: "USD", rates: rates)
        XCTAssertEqual(totals, [CategoryTotal(category: "Other", amount: 5, count: 1)])
    }
}

/// The hours someone types for a subscription: accepted only when they make sense.
final class UsageInputTests: XCTestCase {
    func testHoursAndMinutesBecomeMinutes() {
        XCTAssertEqual(UsageInputSheet.totalMinutes(hours: "2", minutes: "30"), 150)
        XCTAssertEqual(UsageInputSheet.totalMinutes(hours: "", minutes: "45"), 45)
        XCTAssertEqual(UsageInputSheet.totalMinutes(hours: "3", minutes: ""), 180)
        XCTAssertEqual(UsageInputSheet.totalMinutes(hours: "0", minutes: "0"), 0, "none at all is an answer")
    }

    func testNonsenseIsNotSaved() {
        XCTAssertNil(UsageInputSheet.totalMinutes(hours: "", minutes: ""), "nothing typed is not zero")
        XCTAssertNil(UsageInputSheet.totalMinutes(hours: "2", minutes: "75"), "minutes run to 59")
        XCTAssertNil(UsageInputSheet.totalMinutes(hours: "900", minutes: "0"), "a month has 744 hours at most")
        XCTAssertNil(UsageInputSheet.totalMinutes(hours: "two", minutes: ""))
        XCTAssertNil(UsageInputSheet.totalMinutes(hours: "-1", minutes: "10"))
    }
}
