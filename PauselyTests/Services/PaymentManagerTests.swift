import XCTest
@testable import Pausely

/// What Pro unlocks, and the free tier's limit.
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

    // Pro prices on screen come only from StoreKit (`Product.displayPrice`); see
    // `CurrencyGuardTests` for the rule that Pausely never shows a price it worked out itself.

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
