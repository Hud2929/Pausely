import XCTest
@testable import Pausely

/// The paywall must show what Apple charges. The savings and per-month figures are derived from real
/// App Store prices by pure functions, tested here with exact decimals.
final class StoreKitPricingTests: XCTestCase {

    private func d(_ s: String) -> Decimal { Decimal(string: s)! }

    func testLaunchPricesSaveFiftyPercent() {
        // 12 x 4.99 = 59.88; 29.99 is about 49.9% less.
        XCTAssertEqual(StoreKitManager.annualSavingsPercent(monthly: d("4.99"), annual: d("29.99")), 50)
    }

    func testOtherPriceCombinations() {
        XCTAssertEqual(StoreKitManager.annualSavingsPercent(monthly: d("9.99"), annual: d("39.99")), 67)
        XCTAssertEqual(StoreKitManager.annualSavingsPercent(monthly: d("9.99"), annual: d("79.99")), 33)
    }

    func testNoSavingMeansNoBadge() {
        XCTAssertNil(StoreKitManager.annualSavingsPercent(monthly: d("4.99"), annual: d("59.88")))
        XCTAssertNil(StoreKitManager.annualSavingsPercent(monthly: d("4.99"), annual: d("80")))
        XCTAssertNil(StoreKitManager.annualSavingsPercent(monthly: 0, annual: d("29.99")))
    }

    func testPerMonthIsRoundedToCents() {
        XCTAssertEqual(StoreKitManager.perMonth(annual: d("29.99")), d("2.50"))
        XCTAssertEqual(StoreKitManager.perMonth(annual: d("39.99")), d("3.33"))
        XCTAssertEqual(StoreKitManager.perMonth(annual: d("79.99")), d("6.67"))
    }

    func testLaunchConstantsAreExactDecimals() {
        XCTAssertEqual(ProPricing.monthlyUSD, d("4.99"))
        XCTAssertEqual(ProPricing.annualUSD, d("29.99"))
        XCTAssertEqual(FreeTier.subscriptionLimit, 5)
        XCTAssertEqual(SubscriptionTier.free.subscriptionLimit, FreeTier.subscriptionLimit)
    }
}
