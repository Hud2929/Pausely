import XCTest
@testable import Pausely

/// Local-first guest mode and user-chosen free-tier slot selection.
@MainActor
final class GuestModeTests: XCTestCase {

    private var sandbox: StoreSandbox!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() async throws {
        sandbox = StoreSandbox()
        suite = "GuestModeTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        UserDefaults.standard.set(false, forKey: "debug_premium_override")
        UserDefaults.standard.set(false, forKey: "debug_free_pro")
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        await sandbox.restore()
        sandbox = nil
    }

    func testGuestModeDoesNotReportLoadFailureWhenEmpty() {
        XCTAssertFalse(SubscriptionStore.fetchReallyFailed(SyncFailure.signedOut, userID: AuthManager.guestUserID))
        XCTAssertTrue(SubscriptionStore.fetchReallyFailed(URLError(.notConnectedToInternet), userID: AuthManager.guestUserID))
    }

    func testUpgradingFromGuestToRealAccountKeepsLocalDataAndQueuesUpload() async throws {
        let store = SubscriptionStore.shared
        _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Netflix", amount: 15.99))
        _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Spotify", amount: 10.99))
        store.sync.removeAll()

        defaults.set(AuthManager.guestUserID, forKey: "local_data_owner")
        XCTAssertTrue(LocalUserData.belongs(to: "real-user-123", defaults: defaults))

        await LocalUserData.claim(for: "real-user-123", defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: "local_data_owner"), "real-user-123")
        XCTAssertEqual(store.subscriptions.count, 2, "guest subscriptions stay intact when creating an account")
        XCTAssertEqual(store.sync.pending.count, 2, "local guest subscriptions are queued to upload")
    }

    func testSwitchingBetweenTwoRealAccountsStillWipesLocalData() async throws {
        let store = SubscriptionStore.shared
        _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Netflix", amount: 15.99))
        defaults.set("account-A", forKey: "local_data_owner")

        XCTAssertFalse(LocalUserData.belongs(to: "account-B", defaults: defaults))
        await LocalUserData.claim(for: "account-B", defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: "local_data_owner"), "account-B")
        XCTAssertTrue(store.subscriptions.isEmpty, "switching between real accounts wipes the previous account's data")
    }

    func testPreferredNamesFillFreeSlotsAheadOfMoreExpensiveServices() {
        func line(_ name: String, _ amount: String) -> TallyLine {
            TallyLine(name: name, category: "Entertainment", amount: Decimal(string: amount)!, currency: "USD")
        }
        let lines = [
            line("iCloud+", "2.99"),
            line("Peloton", "44.00"),
            line("Netflix", "19.99"),
            line("Spotify", "12.99"),
        ]
        let plan = PendingTally.plan(lines: lines, existingNames: [], freeSlots: 2, preferredNames: ["iCloud+", "Spotify"])
        XCTAssertEqual(Set(plan.add.map(\.name)), ["iCloud+", "Spotify"])
        XCTAssertEqual(Set(plan.wait.map(\.name)), ["Peloton", "Netflix"])
    }

    func testApplyChoiceSwapsTrackedAndWaitingWithoutLosingData() async throws {
        try XCTSkipIf(PaymentManager.shared.isPremium, "Free-tier slot swapping applies to the free plan")
        let store = SubscriptionStore.shared
        let lines = (1...7).map { i in
            TallyLine(name: "Service \(i)", category: "Entertainment", amount: Decimal(i * 5), currency: "USD", frequency: .monthly)
        }
        _ = await TallyImporter.add(lines, into: store, rates: .fallback, defaults: defaults)
        XCTAssertEqual(store.subscriptions.charging.count, FreeTier.subscriptionLimit)
        XCTAssertEqual(TallyImporter.waitingLines(defaults: defaults).count, 2)

        // Swap out the two most expensive (Service 7, Service 6) in favor of Service 1 and Service 2.
        await TallyImporter.applyChoice(
            selectedNames: ["Service 1", "Service 2", "Service 3", "Service 4", "Service 5"],
            into: store,
            defaults: defaults
        )

        XCTAssertEqual(Set(store.subscriptions.charging.map(\.name)),
                       ["Service 1", "Service 2", "Service 3", "Service 4", "Service 5"])
        let nowWaiting = TallyImporter.waitingLines(defaults: defaults)
        XCTAssertEqual(Set(nowWaiting.map(\.name)), ["Service 6", "Service 7"])
    }
}
