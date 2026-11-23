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

    func testApplyChoicePreservesIdNotesPaymentMethodSplitAndAvoidsFakeLifecycleEvents() async throws {
        try XCTSkipIf(PaymentManager.shared.isPremium, "Free-tier slot swapping applies to the free plan")
        let store = SubscriptionStore.shared
        let originalID = UUID()
        let rich = Subscription(
            id: originalID,
            name: "Netflix",
            category: "Entertainment",
            amount: Decimal(string: "22.99")!,
            currency: "USD",
            billingFrequency: .monthly,
            notifyBeforeDays: 7,
            notes: "Shared with roommate",
            paymentMethod: "Apple",
            splitCount: 2
        )
        _ = try await store.addSubscription(rich)
        let others = (1...5).map { i in
            TallyLine(name: "Extra \(i)", category: "Other", amount: Decimal(i * 4), currency: "USD", frequency: .monthly)
        }
        _ = await TallyImporter.add(others, into: store, rates: .fallback, defaults: defaults)
        let eventsBefore = LifecycleEventLog.shared.events.count

        // Demote Netflix to waiting (promoting Extra 5 for the first time), then swap Netflix back in.
        await TallyImporter.applyChoice(
            selectedNames: ["Extra 1", "Extra 2", "Extra 3", "Extra 4", "Extra 5"],
            into: store,
            defaults: defaults
        )
        let eventsAfterFirstSwap = LifecycleEventLog.shared.events.count
        XCTAssertEqual(eventsAfterFirstSwap, eventsBefore + 1, "only the first-time promotion of Extra 5 should emit .added")

        await TallyImporter.applyChoice(
            selectedNames: ["Netflix", "Extra 2", "Extra 3", "Extra 4", "Extra 5"],
            into: store,
            defaults: defaults
        )

        let restored = store.subscriptions.first { $0.name == "Netflix" }
        XCTAssertEqual(restored?.id, originalID, "UUID must survive slot swap so UsageLog and PriceHistory stay linked")
        XCTAssertEqual(restored?.notes, "Shared with roommate")
        XCTAssertEqual(restored?.paymentMethod, "Apple")
        XCTAssertEqual(restored?.splitCount, 2)
        XCTAssertEqual(restored?.notifyBeforeDays, 7)
        let netflixEvents = LifecycleEventLog.shared.events.filter { $0.subscriptionId == originalID }
        XCTAssertEqual(netflixEvents.map(\.kind), [.added], "swapping Netflix out and back must not emit fake deleted/added events")
        XCTAssertEqual(LifecycleEventLog.shared.events.count, eventsAfterFirstSwap, "restoring a swapped-out item must emit zero events")
    }

    func testGuestMergeDeduplicatesExistingServerSubscriptionAndBackfillsDetails() {
        let serverSub = Subscription(name: "Netflix", category: "Entertainment", amount: 15.99, currency: "USD")
        let guestSub = Subscription(name: "Netflix Standard", category: "Entertainment", amount: 15.99, currency: "USD",
                                    notes: "Roommate split", paymentMethod: "Apple", splitCount: 2)
        let guestOnly = Subscription(name: "Spotify", category: "Music", amount: 11.99, currency: "USD")

        let merged = SubscriptionSyncMerge.merge(
            server: [serverSub],
            local: [guestSub, guestOnly],
            pending: [guestSub.id: .create, guestOnly.id: .create],
            firstSyncForUser: true
        )

        XCTAssertEqual(merged.subscriptions.count, 2, "must not duplicate Netflix when guest signs into existing account")
        XCTAssertEqual(merged.supersededLocalIDs, [guestSub.id])
        XCTAssertEqual(merged.upload.map(\.id), [guestOnly.id])
        let mergedNetflix = merged.subscriptions.first { $0.id == serverSub.id }
        XCTAssertEqual(mergedNetflix?.notes, "Roommate split")
        XCTAssertEqual(mergedNetflix?.paymentMethod, "Apple")
        XCTAssertEqual(mergedNetflix?.splitCount, 2)
        XCTAssertEqual(merged.backfill.map(\.id), [serverSub.id])
    }

    func testCaseInsensitiveOwnerClaimDoesNotWipeSameAccount() async throws {
        let store = SubscriptionStore.shared
        _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Netflix", amount: 15.99))
        defaults.set("5F0C3A0E-1111-4000-8000-000000000001", forKey: "local_data_owner")
        await LocalUserData.claim(for: "5f0c3a0e-1111-4000-8000-000000000001", defaults: defaults)
        XCTAssertEqual(store.subscriptions.count, 1, "UUID casing difference must not trigger a wipe")
    }

    func testFirstSyncReconcileDeduplicatesGuestRowBeforeDrainingToServer() async throws {
        let store = SubscriptionStore.shared
        let serverNetflix = Subscription(name: "Netflix", category: "Entertainment", amount: 15.99, currency: "USD")
        let guestNetflix = Subscription(name: "Netflix Standard", category: "Entertainment", amount: 15.99, currency: "USD",
                                        notes: "Shared with Sarah", paymentMethod: "Apple", splitCount: 2)
        let guestSpotify = Subscription(name: "Spotify", category: "Music", amount: 11.99, currency: "USD")

        // Guest adds both offline while local; both sit in sync.pending as .create.
        sandbox.transport.canSend = false
        _ = try await store.addSubscription(guestNetflix)
        _ = try await store.addSubscription(guestSpotify)
        XCTAssertEqual(store.sync.pending.count, 2)

        // Now guest signs into an existing cloud account that ALREADY has Netflix on the server.
        // Even with transport online, reconcileWithServer MUST fetch & merge BEFORE draining.
        sandbox.transport.canSend = true
        sandbox.transport.hold(serverNetflix)
        var callsAtFetchTime: [String] = []
        try await store.reconcileWithServer(userId: "existing-user-123", defaults: defaults) {
            callsAtFetchTime = self.sandbox.transport.calls
            return ([serverNetflix], [])
        }

        XCTAssertTrue(callsAtFetchTime.isEmpty, "firstSync must NOT drain guest .create intents before fetching remote rows")
        XCTAssertEqual(store.subscriptions.count, 2, "duplicate Netflix must be merged, not duplicated")
        XCTAssertNil(sandbox.transport.rows[guestNetflix.id], "superseded guest Netflix must never be created on server")
        XCTAssertEqual(sandbox.transport.rows[guestSpotify.id]?.name, "Spotify", "guest-only Spotify uploads after merge")
        XCTAssertEqual(sandbox.transport.rows[serverNetflix.id]?.notes, "Shared with Sarah", "guest details backfill onto server Netflix")
        XCTAssertEqual(sandbox.transport.rows[serverNetflix.id]?.paymentMethod, "Apple")
        XCTAssertEqual(sandbox.transport.rows[serverNetflix.id]?.splitCount, 2)
        XCTAssertTrue(store.sync.pending.isEmpty)
        XCTAssertFalse(SubscriptionStore.isFirstSync(for: "EXISTING-USER-123", defaults: defaults), "UUID casing matches")
    }

    func testGuestModeNeverLoadsCancelDifficultyScores() async {
        let auth = AuthManager.shared
        let savedUser = auth.currentUser
        let savedAuth = auth.isAuthenticated
        let savedState = auth.state
        defer {
            auth.currentUser = savedUser
            auth.isAuthenticated = savedAuth
            auth.state = savedState
            CancelDifficultyService.shared.reset()
        }

        CancelDifficultyService.shared.reset()
        auth.enterGuestMode(persist: false)
        await CancelDifficultyService.shared.loadIfNeeded()
        XCTAssertTrue(CancelDifficultyService.shared.scores.isEmpty, "guest mode must never contact server for difficulty scores")
    }

    func testFailedInitialFetchRecoversOnNetworkRestoreWithoutDuplicating() async throws {
        let store = SubscriptionStore.shared
        let serverNetflix = Subscription(name: "Netflix", category: "Entertainment", amount: 15.99, currency: "USD")
        let guestNetflix = Subscription(name: "Netflix Standard", category: "Entertainment", amount: 15.99, currency: "USD",
                                        notes: "Roommate split", splitCount: 2)
        let guestSpotify = Subscription(name: "Spotify", category: "Music", amount: 11.99, currency: "USD")

        sandbox.transport.canSend = false
        _ = try await store.addSubscription(guestNetflix)
        _ = try await store.addSubscription(guestSpotify)
        sandbox.transport.hold(serverNetflix)

        // First attempt fails (transient offline/timeout): syncedUserKey MUST stay unset.
        do {
            try await store.reconcileWithServer(userId: "recover-user-1", defaults: defaults) {
                throw URLError(.notConnectedToInternet)
            }
            XCTFail("Expected initial offline fetch to throw")
        } catch is URLError {}

        XCTAssertTrue(SubscriptionStore.isFirstSync(for: "recover-user-1", defaults: defaults),
                      "failed initial fetch must leave isFirstSync true so guest rows cannot drain raw")
        XCTAssertTrue(sandbox.transport.calls.isEmpty)

        // Network returns: SyncQueue invokes onNetworkRestored BEFORE draining.
        var recovered = false
        store.sync.onNetworkRestored = { [weak self] in
            guard let self else { return }
            self.sandbox.transport.canSend = true
            try? await store.reconcileWithServer(userId: "recover-user-1", defaults: self.defaults) {
                ([serverNetflix], [])
            }
            recovered = true
        }
        await store.sync.networkChanged(isOnline: false)
        await store.sync.networkChanged(isOnline: true)

        XCTAssertTrue(recovered)
        XCTAssertFalse(SubscriptionStore.isFirstSync(for: "recover-user-1", defaults: defaults))
        XCTAssertEqual(store.subscriptions.count, 2)
        XCTAssertNil(sandbox.transport.rows[guestNetflix.id], "superseded guest Netflix must not upload after recovery")
        XCTAssertEqual(sandbox.transport.rows[guestSpotify.id]?.name, "Spotify")
        XCTAssertEqual(sandbox.transport.rows[serverNetflix.id]?.notes, "Roommate split")
        XCTAssertEqual(sandbox.transport.rows[serverNetflix.id]?.splitCount, 2)
        XCTAssertTrue(store.sync.pending.isEmpty)
    }
}
