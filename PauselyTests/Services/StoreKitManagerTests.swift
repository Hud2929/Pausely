import StoreKit
import XCTest
@testable import Pausely

/// The one class that talks to StoreKit, with its three questions to the App Store answered by the
/// test: which plans exist, what is paid for right now, and "sync with the App Store".
@MainActor
final class StoreKitManagerTests: XCTestCase {

    private let monthly = StoreKitManager.ProductID.monthly.rawValue
    private let annual = StoreKitManager.ProductID.annual.rawValue

    private var realEntitlements: (() async -> [StoreKitManager.Entitlement])!

    /// The real StoreKit never answers inside a unit-test host, so nothing here may reach it: the
    /// app's own manager is given an answer for the length of each test as well.
    override func setUp() async throws {
        realEntitlements = StoreKitManager.shared.currentEntitlements
        StoreKitManager.shared.currentEntitlements = { [] }
    }

    override func tearDown() async throws {
        StoreKitManager.shared.currentEntitlements = realEntitlements
    }

    private func paidFor(_ ids: String...) -> () async -> [StoreKitManager.Entitlement] {
        { ids.map { StoreKitManager.Entitlement(productID: $0) } }
    }

    // MARK: Prices

    /// A failed load used to count as loaded: the paywall then showed "…" for prices until the app
    /// was restarted. Now every call asks again until the plans are there.
    func testPricesThatFailedToLoadAreAskedForAgain() async {
        let store = StoreKitManager()
        var asked: [[String]] = []
        store.fetchProducts = { ids in
            asked.append(ids)
            throw URLError(.notConnectedToInternet)
        }
        await store.loadProducts()
        await store.loadProducts()
        XCTAssertEqual(asked.count, 2)
        XCTAssertEqual(Set(asked[0]), [monthly, annual])
        XCTAssertTrue(store.products.isEmpty)
        XCTAssertFalse(store.isLoading)

        store.fetchProducts = { ids in
            asked.append(ids)
            return []
        }
        await store.loadProducts()
        await store.loadProducts()
        XCTAssertEqual(asked.count, 4, "an empty answer is not prices either")
        XCTAssertNil(store.product(for: .pro))
    }

    // MARK: What is paid for

    func testThePlanPaidForIsTheHighestOneTheAppStoreReports() async {
        let store = StoreKitManager()
        store.currentEntitlements = paidFor()
        var tier = await store.entitledTier()
        XCTAssertNil(tier)

        store.currentEntitlements = paidFor(monthly)
        tier = await store.entitledTier()
        XCTAssertEqual(tier, .pro)

        store.currentEntitlements = paidFor(monthly, annual)
        tier = await store.entitledTier()
        XCTAssertEqual(tier, .proAnnual)

        store.currentEntitlements = paidFor("com.someone.else.product")
        tier = await store.entitledTier()
        XCTAssertNil(tier, "only Pausely's own plans count")
    }

    func testARefundedPurchaseIsNotPaidFor() async {
        let store = StoreKitManager()
        store.currentEntitlements = { [StoreKitManager.Entitlement(productID: self.annual, isRevoked: true)] }
        let tier = await store.entitledTier()
        XCTAssertNil(tier)
    }

    // MARK: Restoring

    func testRestoringSaysWhetherThereWasAnythingToRestore() async {
        let store = StoreKitManager()
        store.syncWithAppStore = {}
        store.currentEntitlements = paidFor()
        var outcome = await store.restorePurchases()
        XCTAssertEqual(outcome, .nothingToRestore)

        store.currentEntitlements = paidFor(annual)
        outcome = await store.restorePurchases()
        XCTAssertEqual(outcome, .restored)
        XCTAssertFalse(store.isLoading)
    }

    func testRestoringTellsClosingTheSignInApartFromAFailure() async {
        let store = StoreKitManager()
        store.currentEntitlements = paidFor()
        store.syncWithAppStore = { throw StoreKit.StoreKitError.userCancelled }
        var outcome = await store.restorePurchases()
        XCTAssertEqual(outcome, .cancelled)

        store.syncWithAppStore = { throw URLError(.notConnectedToInternet) }
        outcome = await store.restorePurchases()
        XCTAssertEqual(outcome, .failed)
    }
}

/// The tier the app reads, as the App Store's answer changes while the app runs.
@MainActor
final class ProTierTests: XCTestCase {

    private let store = StoreKitManager.shared
    private let payments = PaymentManager.shared
    private var realEntitlements: (() async -> [StoreKitManager.Entitlement])!
    private var savedGrant: Any?

    override func setUp() async throws {
        realEntitlements = store.currentEntitlements
        savedGrant = UserDefaults.standard.object(forKey: "pausely_pro_grant")
        UserDefaults.standard.removeObject(forKey: "pausely_pro_grant")
    }

    /// Ends on the free tier with the real source back in place. The real StoreKit is not asked here
    /// (it never answers inside a unit-test host); the app asks it at its next launch.
    override func tearDown() async throws {
        store.currentEntitlements = { [] }
        await payments.updateCurrentEntitlements()
        UserDefaults.standard.set(savedGrant, forKey: "pausely_pro_grant")
        store.currentEntitlements = realEntitlements
    }

    private func appStoreSays(_ entitlements: [StoreKitManager.Entitlement]) async {
        store.currentEntitlements = { entitlements }
        // What a transaction update, a purchase, a restore and coming to the front all call.
        await payments.updateCurrentEntitlements()
    }

    /// The transaction listener used to be able only to turn Pro on. A refund, a revocation or an
    /// expiry while the app was running left Pro unlocked until the next cold launch.
    func testProIsTakenAwayWhenTheAppStoreStopsReportingIt() async {
        await appStoreSays([.init(productID: StoreKitManager.ProductID.annual.rawValue)])
        XCTAssertEqual(payments.currentTier, .proAnnual)

        await appStoreSays([.init(productID: StoreKitManager.ProductID.annual.rawValue, isRevoked: true)])
        XCTAssertEqual(payments.currentTier, .free, "refunded")

        await appStoreSays([.init(productID: StoreKitManager.ProductID.monthly.rawValue)])
        XCTAssertEqual(payments.currentTier, .pro)

        await appStoreSays([])
        XCTAssertEqual(payments.currentTier, .free, "ended")
        XCTAssertEqual(AppSettings.shared.currentTier, .free, "and the saved tier follows, so the next launch starts free too")
    }

    func testAGrantOnTheAccountKeepsProWhenThereIsNoPurchase() async {
        await appStoreSays([])
        await payments.setProGrant(true)
        XCTAssertEqual(payments.currentTier, .pro)
        await payments.setProGrant(false)
        XCTAssertEqual(payments.currentTier, .free)
    }
}
