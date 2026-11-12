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

    /// What Pro unlocks, and so what the paywall lists and the store page may promise: tracking more
    /// than the free plan does, and Pause Plan. A third thing listed here has to exist.
    func testProUnlocksExactlyWhatExists() {
        XCTAssertEqual(ProFeature.allCases, [.unlimitedSubscriptions, .pausePlan])
        XCTAssertEqual(ProFeature.allCases.map(\.title), ["Unlimited subscriptions", "Pause Plan: rotate your streaming"])
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
        let full = (0..<FreeTier.subscriptionLimit).map { TestFactories.makeSubscription(name: "Charging \($0)") }
        XCTAssertEqual(payments.hasRoom(in: full),
                       ProFeature.canAddSubscription(currentCount: FreeTier.subscriptionLimit, isPro: payments.isPremium))
    }

    // MARK: - Pausely's own line in the list

    private func own(_ tier: SubscriptionTier, price: String, currency: String, trial: Bool = false) -> StoreKitManager.OwnSubscription {
        StoreKitManager.OwnSubscription(tier: tier, price: Decimal(string: price)!, currency: currency,
                                        renews: Date(timeIntervalSince1970: 1_800_000_000), isTrial: trial)
    }

    /// The line is what the App Store states for this customer. It used to be able to go in at US
    /// launch prices, as "USD", with a next charge that was only a guess.
    @MainActor
    func testPauselysOwnLineIsExactlyWhatTheAppStoreStates() {
        let line = PaymentManager.pauselyLine(own(.proAnnual, price: "39.99", currency: "CAD"))
        XCTAssertEqual(line.name, "Pausely Pro")
        XCTAssertEqual(line.amount, Decimal(string: "39.99"))
        XCTAssertEqual(line.currency, "CAD")
        XCTAssertEqual(line.billingFrequency, .yearly)
        XCTAssertEqual(line.nextBillingDate, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(line.status, .active)
        XCTAssertNil(line.trialEndsAt)
        XCTAssertTrue(line.isPausely)
    }

    @MainActor
    func testDuringTheFreeTrialTheLineIsATrialEndingOnTheFirstCharge() {
        let line = PaymentManager.pauselyLine(own(.pro, price: "4.99", currency: "USD", trial: true))
        XCTAssertEqual(line.status, .trial)
        XCTAssertEqual(line.trialEndsAt, line.nextBillingDate)
        XCTAssertEqual(line.billingFrequency, .monthly)
    }

    /// A line an earlier version added at US prices is brought to the App Store's; a right one is left alone.
    @MainActor
    func testAWronglyPricedLineIsCorrectedAndARightOneIsNotTouched() throws {
        let stated = own(.proAnnual, price: "39.99", currency: "CAD")
        var wrong = PaymentManager.pauselyLine(own(.proAnnual, price: "29.99", currency: "USD"))
        wrong.notifyBeforeDays = 7
        let fixed = try XCTUnwrap(PaymentManager.corrected(wrong, to: stated))
        XCTAssertEqual(fixed.amount, Decimal(string: "39.99"))
        XCTAssertEqual(fixed.currency, "CAD")
        XCTAssertEqual(fixed.id, wrong.id)
        XCTAssertEqual(fixed.notifyBeforeDays, 7, "what the person set stays")
        XCTAssertEqual(fixed.nextBillingDate, wrong.nextBillingDate)
        XCTAssertNil(PaymentManager.corrected(fixed, to: stated))
    }

    // MARK: - What the paywall says afterwards

    func testNothingIsSaidWhenItWorkedOrThePersonClosedApplesSheet() {
        XCTAssertNil(PaywallNotice.after(StoreKitManager.PurchaseOutcome.purchased))
        XCTAssertNil(PaywallNotice.after(StoreKitManager.PurchaseOutcome.cancelled), "this used to raise \"Purchase Error\"")
        XCTAssertNil(PaywallNotice.after(StoreKitManager.RestoreOutcome.restored))
        XCTAssertNil(PaywallNotice.after(StoreKitManager.RestoreOutcome.cancelled))
    }

    /// Each of these used to read "Purchase failed. Please try again." under "Purchase Error".
    func testEveryOtherOutcomeHasItsOwnWords() {
        let pending = PaywallNotice.after(StoreKitManager.PurchaseOutcome.pending)
        XCTAssertEqual(pending?.title, L10n.string("Waiting for Approval"))
        XCTAssertEqual(pending?.offersRetry, false, "buying again would not help")

        let failed = PaywallNotice.after(StoreKitManager.PurchaseOutcome.failed)
        XCTAssertEqual(failed?.title, L10n.string("The Purchase Didn't Go Through"))
        XCTAssertEqual(failed?.offersRetry, true)

        let unverified = PaywallNotice.after(StoreKitManager.PurchaseOutcome.unverified)
        XCTAssertEqual(unverified?.message, L10n.string("The App Store couldn't confirm this purchase. If you were charged, tap Restore Purchases."))

        let nothing = PaywallNotice.after(StoreKitManager.RestoreOutcome.nothingToRestore)
        XCTAssertEqual(nothing?.title, L10n.string("Nothing to Restore"))
        XCTAssertEqual(nothing?.message, L10n.string("There's no Pausely Pro subscription on this Apple Account."))
        XCTAssertEqual(nothing?.offersRetry, false)

        let unreachable = PaywallNotice.after(StoreKitManager.RestoreOutcome.failed)
        XCTAssertEqual(unreachable?.title, L10n.string("Couldn't Restore"))
        XCTAssertEqual(unreachable?.offersRetry, true)

        let titles = [pending, failed, unverified, nothing, unreachable].compactMap { $0?.title }
        XCTAssertEqual(Set(titles).count, 5, "five outcomes, five different titles")
    }
}
