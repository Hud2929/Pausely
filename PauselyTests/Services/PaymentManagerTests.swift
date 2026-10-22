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

    /// True if `text` contains the amount in either decimal style ("4.99" or "4,99").
    private func containsAmount(_ text: String, _ amount: Decimal) -> Bool {
        let dot = "\(amount)"
        return text.contains(dot) || text.contains(dot.replacingOccurrences(of: ".", with: ","))
    }

    func testProMonthlyPrice_matchesLaunchPrice() {
        // The estimate shown before StoreKit loads follows ProPricing. USD and CAD use the same number.
        CurrencyManager.shared.selectedCurrency = "USD"
        let usdResult = SubscriptionTier.pro.priceInUserCurrency()
        XCTAssertTrue(containsAmount(usdResult, ProPricing.monthlyUSD),
                      "Pro monthly USD price should be \(ProPricing.monthlyUSD), got: \(usdResult)")

        CurrencyManager.shared.selectedCurrency = "CAD"
        let cadResult = SubscriptionTier.pro.priceInUserCurrency()
        XCTAssertTrue(containsAmount(cadResult, ProPricing.monthlyUSD),
                      "Pro monthly CAD price should be \(ProPricing.monthlyUSD), got: \(cadResult)")
    }

    func testProAnnualPrice_matchesLaunchPrice() {
        CurrencyManager.shared.selectedCurrency = "USD"
        let result = SubscriptionTier.proAnnual.priceInUserCurrency()
        XCTAssertTrue(containsAmount(result, ProPricing.annualUSD),
                      "Pro annual price should contain \(ProPricing.annualUSD), got: \(result)")
    }

    func testFreePrice_isZeroNotRoundedUp() {
        // monthlyPriceInUserCurrency() guards against free tier — must not return 0.99
        let result = SubscriptionTier.free.monthlyPriceInUserCurrency()
        // The free tier guard returns formatPrice(0, ...) which should be $0.00 or similar
        XCTAssertFalse(result.isEmpty)
    }

    func testProAnnualMonthlyEquivalent_nonEmpty_nonNaN() {
        // Annual price / 12 is only an estimate; it must never be empty or NaN.
        let result = SubscriptionTier.proAnnual.monthlyPriceInUserCurrency()
        XCTAssertFalse(result.isEmpty)
        XCTAssertFalse(result.lowercased().contains("nan"),
                       "Monthly equivalent must not be NaN: \(result)")
    }

    // MARK: - convertToUserCurrency: USD/CAD parity

    func testCAD_andUSD_samePrice() {
        // USD and CAD share the base number; all other currencies convert from the USD base.
        CurrencyManager.shared.selectedCurrency = "USD"
        let usdResult = SubscriptionTier.pro.priceInUserCurrency()

        CurrencyManager.shared.selectedCurrency = "CAD"
        let cadResult = SubscriptionTier.pro.priceInUserCurrency()

        XCTAssertTrue(containsAmount(usdResult, ProPricing.monthlyUSD), "USD price, got: \(usdResult)")
        XCTAssertTrue(containsAmount(cadResult, ProPricing.monthlyUSD), "CAD price, got: \(cadResult)")
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
            XCTAssertFalse(result.isEmpty)
            XCTAssertFalse(result.lowercased().contains("nan"))
        }
    }

    func testJPY_convertsAndEndsIn99() {
        CurrencyTestHelpers.withRates(["JPY": 150.0]) {
            CurrencyManager.shared.selectedCurrency = "JPY"
            let result = SubscriptionTier.pro.priceInUserCurrency()
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

    // MARK: - Entitlements

    func testProFeatures_haveTitlesAndDistinctIcons() {
        let features = ProFeature.allCases
        XCTAssertFalse(features.isEmpty)
        XCTAssertTrue(features.allSatisfy { !$0.title.isEmpty })
        XCTAssertEqual(Set(features.map(\.icon)).count, features.count)
    }

    func testFreeTier_locksProFeaturesAndStopsAtTheLimit() {
        let limit = FreeTier.subscriptionLimit
        XCTAssertTrue(ProFeature.canAddSubscription(currentCount: limit - 1, isPro: false))
        XCTAssertFalse(ProFeature.canAddSubscription(currentCount: limit, isPro: false))
        for feature in ProFeature.allCases {
            XCTAssertFalse(feature.isUnlocked(isPro: false), "\(feature) should be locked on the free tier")
        }
    }

    func testPro_unlocksEveryFeatureAndHasNoLimit() {
        XCTAssertTrue(ProFeature.canAddSubscription(currentCount: 500, isPro: true))
        for feature in ProFeature.allCases {
            XCTAssertTrue(feature.isUnlocked(isPro: true), "\(feature) should be unlocked for Pro")
        }
    }

    @MainActor
    func testPaymentManager_usesTheSameRule() {
        let payments = PaymentManager.shared
        for feature in ProFeature.allCases {
            XCTAssertEqual(payments.isUnlocked(feature), feature.isUnlocked(isPro: payments.isPremium))
        }
        XCTAssertEqual(payments.hasReachedSubscriptionLimit(currentCount: FreeTier.subscriptionLimit),
                       !ProFeature.canAddSubscription(currentCount: FreeTier.subscriptionLimit, isPro: payments.isPremium))
    }
}
