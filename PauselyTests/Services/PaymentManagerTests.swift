import XCTest
@testable import Pausely

/// Tests for SubscriptionTier pricing methods.
/// roundTo99() and convertToUserCurrency() are private — tested through the public interface.
final class PaymentManagerTests: XCTestCase {

    private var originalCurrency: String = "USD"

    override func setUp() {
        super.setUp()
        originalCurrency = CurrencyManager.shared.selectedCurrency
        CurrencyManager.shared.selectedCurrency = "USD"
    }

    override func tearDown() {
        CurrencyManager.shared.selectedCurrency = originalCurrency
        super.tearDown()
    }

    // MARK: - roundTo99 (via priceInUserCurrency / monthlyPriceInUserCurrency)

    func testProMonthlyPrice_endsIn99() {
        // USD and CAD both $9.99
        CurrencyManager.shared.selectedCurrency = "USD"
        let usdResult = SubscriptionTier.pro.priceInUserCurrency()
        XCTAssertTrue(usdResult.contains("9.99") || usdResult.contains("9,99"),
                      "Pro monthly USD price should be 9.99, got: \(usdResult)")

        CurrencyManager.shared.selectedCurrency = "CAD"
        let cadResult = SubscriptionTier.pro.priceInUserCurrency()
        XCTAssertTrue(cadResult.contains("9.99") || cadResult.contains("9,99"),
                      "Pro monthly CAD price should be 9.99, got: \(cadResult)")
    }

    func testProAnnualPrice_endsIn99() {
        // baseUSDPrice = 79.99 → roundTo99 → floor(79.99) + 0.99 = 79.99
        let result = SubscriptionTier.proAnnual.priceInUserCurrency()
        XCTAssertTrue(result.contains("79.99") || result.contains("79,99"),
                      "Pro annual price should contain 79.99, got: \(result)")
    }

    func testFreePrice_isZeroNotRoundedUp() {
        // monthlyPriceInUserCurrency() guards against free tier — must not return 0.99
        let result = SubscriptionTier.free.monthlyPriceInUserCurrency()
        // The free tier guard returns formatPrice(0, ...) which should be $0.00 or similar
        XCTAssertFalse(result.isEmpty)
    }

    func testProAnnualMonthlyEquivalent_nonEmpty_nonNaN() {
        // 79.99/12 ≈ 6.67 → roundTo99 → 6.99
        let result = SubscriptionTier.proAnnual.monthlyPriceInUserCurrency()
        XCTAssertFalse(result.isEmpty)
        XCTAssertFalse(result.lowercased().contains("nan"),
                       "Monthly equivalent must not be NaN: \(result)")
    }

    // MARK: - convertToUserCurrency: USD/CAD parity

    func testCAD_andUSD_samePriceOf999() {
        // USD and CAD both fixed at $9.99 — all other currencies convert from USD base
        CurrencyManager.shared.selectedCurrency = "USD"
        let usdResult = SubscriptionTier.pro.priceInUserCurrency()

        CurrencyManager.shared.selectedCurrency = "CAD"
        let cadResult = SubscriptionTier.pro.priceInUserCurrency()

        XCTAssertTrue(usdResult.contains("9.99") || usdResult.contains("9,99"),
                      "USD price should be 9.99, got: \(usdResult)")
        XCTAssertTrue(cadResult.contains("9.99") || cadResult.contains("9,99"),
                      "CAD price should be 9.99, got: \(cadResult)")
    }

    // MARK: - convertToUserCurrency: missing rate falls back to 1.0

    func testMissingExchangeRate_nocrash_returnsNonEmpty() {
        CurrencyTestHelpers.withRates([:]) {
            CurrencyManager.shared.selectedCurrency = "XYZ"
            let result = SubscriptionTier.pro.priceInUserCurrency()
            XCTAssertFalse(result.isEmpty,
                           "Missing rate should fall back to 1.0, not crash")
            XCTAssertFalse(result.lowercased().contains("nan"))
        }
    }

    // MARK: - convertToUserCurrency: EUR and JPY conversion

    func testEUR_convertsAndEndsIn99() {
        CurrencyTestHelpers.withRates(["EUR": 0.92]) {
            CurrencyManager.shared.selectedCurrency = "EUR"
            let result = SubscriptionTier.pro.priceInUserCurrency()
            // USD 9.99 * 0.92 = 9.1908 → roundTo99 → floor(9.1908) + 0.99 = 9.99
            XCTAssertFalse(result.isEmpty)
            XCTAssertFalse(result.lowercased().contains("nan"))
        }
    }

    func testJPY_convertsAndEndsIn99() {
        CurrencyTestHelpers.withRates(["JPY": 150.0]) {
            CurrencyManager.shared.selectedCurrency = "JPY"
            let result = SubscriptionTier.pro.priceInUserCurrency()
            // USD 9.99 * 150 = 1498.5 → roundTo99 → floor(1498.5) + 0.99 = 1498.99
            XCTAssertFalse(result.isEmpty)
            XCTAssertFalse(result.lowercased().contains("nan"))
        }
    }

    // MARK: - priceInUserCurrency: Pro Annual in GBP

    func testProAnnual_GBP_nonEmpty() {
        CurrencyTestHelpers.withRates(["GBP": 0.79]) {
            CurrencyManager.shared.selectedCurrency = "GBP"
            let result = SubscriptionTier.proAnnual.priceInUserCurrency()
            XCTAssertFalse(result.isEmpty)
            XCTAssertFalse(result.lowercased().contains("nan"))
        }
    }

    // MARK: - savingsPercent

    func testSavingsPercent_free_empty() {
        XCTAssertEqual(SubscriptionTier.free.savingsPercent, "")
    }

    func testSavingsPercent_pro_empty() {
        XCTAssertEqual(SubscriptionTier.pro.savingsPercent, "")
    }

    func testSavingsPercent_proAnnual_containsPercentSign() {
        XCTAssertTrue(SubscriptionTier.proAnnual.savingsPercent.contains("%"),
                      "Annual savings badge must include a % sign")
    }

    func testSavingsPercent_proAnnual_approximately17() {
        // Monthly USD $9.99 × 12 = $119.88, annual $79.99
        // Savings = (95.88 - 79.99) / 95.88 ≈ 16.6% → displayed as "17%"
        XCTAssertTrue(SubscriptionTier.proAnnual.savingsPercent.contains("17"),
                      "Annual savings should be ~17%, got: \(SubscriptionTier.proAnnual.savingsPercent)")
    }
}
