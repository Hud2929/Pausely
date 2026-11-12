import XCTest
@testable import Pausely

/// The subscription list the whole app reads from. Changes land on the device first (offline-first);
/// totals, filters and history follow; whatever the account didn't get waits in the sync queue. Runs in a
/// `StoreSandbox` against a stand-in for the account (offline unless a test puts it online), so the live
/// database is never touched and nothing is left behind.
@MainActor
final class SubscriptionStoreTests: XCTestCase {

    private let store = SubscriptionStore.shared
    private var sandbox: StoreSandbox!

    override func setUp() async throws {
        sandbox = StoreSandbox()
        CurrencyManager.shared.selectedCurrency = "USD"
        UserDefaults.standard.set(true, forKey: "debug_premium_override")   // the free limit has its own test
    }

    override func tearDown() async throws {
        await sandbox.restore()
        sandbox = nil
    }

    private func days(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: Date())! }
    private func add(_ sub: Subscription) async { _ = try? await store.addSubscription(sub) }
    private var waiting: [SyncIntent.Kind] { store.sync.pending.map(\.kind) }
    private var account: FakeSyncTransport { sandbox.transport }
    private var offlineNotice: String { L10n.string("Saved on this iPhone. It will sync when you're back online.") }

    /// A subscription the account already has: added while online, nothing waiting.
    private func addOnline(_ sub: Subscription) async {
        account.canSend = true
        await add(sub)
        XCTAssertTrue(store.sync.pending.isEmpty)
    }

    // MARK: The demo list (debug builds)

    /// A debug build with an empty list used to fill it with twelve made-up subscriptions on any
    /// launch, and a build signed in to a real account then uploaded them to it. The test app is an
    /// ordinary launch: an empty saved list stays empty.
    func testAnEmptyListIsNotFilledWithTheDemoSetInAnOrdinaryLaunch() {
        XCTAssertFalse(LaunchFlag.isDemoLaunch, "the tests run in an ordinary launch")
        AppSettings.shared.cachedSubscriptions = Data()
        store.subscriptions = []
        store.showList()   // reads the saved list again
        XCTAssertEqual(store.subscriptions, [])
        XCTAssertTrue(AppSettings.shared.cachedSubscriptions.isEmpty, "and nothing made up is saved")
    }

    /// `--varied-demo-data` is how the screen tour opens every row and state that depends on what is
    /// in a list. If the list loses one of these, the tour stops seeing that state and nobody notices.
    func testTheVariedDemoListHoldsOneOfEverything() {
        let now = Date()
        let list = DemoSubscriptions.varied(now: now, currency: "USD")
        XCTAssertEqual(Set(list.map(\.name)).count, list.count, "each name once")

        XCTAssertEqual(list.filter { $0.status == .trial && $0.trialEndsAt != nil }.map(\.name), ["Disney+"])
        XCTAssertEqual(list.filter { $0.status == .cancelled }.map(\.name), ["Hulu"])
        XCTAssertEqual(Horizon.undated(list).map(\.name), ["Adobe Creative Cloud"])
        XCTAssertEqual(list.filter { $0.currency != "USD" }.map(\.name), ["Duolingo"], "one in another currency")
        XCTAssertTrue(list.charging.isConverted(to: "USD"), "so the totals are marked as converted")
        XCTAssertEqual(Set(list.map(\.billingFrequency)), [.monthly, .quarterly, .yearly])

        XCTAssertGreaterThan(list.charging.count, 8, "the Subscriptions tab shows its search field")
        XCTAssertGreaterThan(Horizon.charges(for: list, now: now).count, 6, "Home says how many more are in Subscriptions")
        XCTAssertGreaterThanOrEqual(list.filter(PausePlanSchedule.isEligible).count, 2, "Pause Plan has something to rotate")
        XCTAssertFalse(RenewalDecisions.pending(in: list, events: [], now: now).isEmpty, "something waits for a decision")
        XCTAssertEqual(DemoSubscriptions.varied(now: now, currency: "EUR").first { $0.name == "Duolingo" }?.currency, "GBP")
    }

    func testTheDemoSetIsOnlyForDemoLaunchesAndNeverOutlivesThem() {
        XCTAssertTrue(SubscriptionStore.fillsWithDemoList(listIsEmpty: true, isDemoLaunch: true))
        XCTAssertFalse(SubscriptionStore.fillsWithDemoList(listIsEmpty: true, isDemoLaunch: false))
        XCTAssertFalse(SubscriptionStore.fillsWithDemoList(listIsEmpty: false, isDemoLaunch: true), "a real list is never replaced")

        XCTAssertEqual(SubscriptionStore.savedDemoList(isDemo: true, isDemoLaunch: false), .discarded,
                       "an ordinary launch throws a saved demo list away before it can be synced as the person's own")
        XCTAssertEqual(SubscriptionStore.savedDemoList(isDemo: true, isDemoLaunch: true), .shownOffline)
        XCTAssertEqual(SubscriptionStore.savedDemoList(isDemo: false, isDemoLaunch: false), .none)
        XCTAssertEqual(SubscriptionStore.savedDemoList(isDemo: false, isDemoLaunch: true), .none)
    }

    // MARK: Adding

    func testAddingPutsItFirstAndUpdatesTheTotals() async {
        await add(TestFactories.makeSubscription(name: "Monthly", amount: 10, billingFrequency: .monthly))
        await add(TestFactories.makeSubscription(name: "Yearly", amount: 120, billingFrequency: .yearly))
        XCTAssertEqual(store.subscriptions.map(\.name), ["Yearly", "Monthly"])
        XCTAssertEqual(store.totalMonthlySpend, 20)
        XCTAssertEqual(store.totalAnnualSpend, 240)
    }

    /// Offline isn't a failure: the change is kept, queued for sync, and a notice says so. Callers that
    /// treated the old error as "not saved" showed false errors and invited duplicate adds.
    func testAddingOfflineKeepsItQueuesItAndSaysSo() async throws {
        let sub = TestFactories.makeSubscription(name: "Offline")
        store.lastErrorMessage = nil
        let synced = try await store.addSubscription(sub)
        XCTAssertFalse(synced)
        XCTAssertEqual(store.lastErrorMessage, offlineNotice)
        XCTAssertEqual(store.subscriptions.map(\.id), [sub.id], "the subscription stays on the device")
        XCTAssertEqual(store.sync.pending.map(\.subscriptionId), [sub.id])
        XCTAssertEqual(waiting, [.create])
        XCTAssertTrue(account.calls.isEmpty)
        XCTAssertEqual(LifecycleEventLog.shared.events.filter { $0.subscriptionId == sub.id }.map(\.kind), [.added])
    }

    /// Dates are days. Only an add used to be put at noon, and only its renewal date: an edit at
    /// 11 pm, or any trial end, was stored as that moment and could land on another day elsewhere.
    func testRenewalAndTrialDaysAreKeptAtNoonOnAddAndOnEdit() async throws {
        let calendar = Calendar.current
        func at(_ hour: Int, _ minute: Int, daysFromNow: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: days(daysFromNow))!
        }
        var sub = TestFactories.makeSubscription(name: "Crave", status: .trial, nextBillingDate: at(23, 40, daysFromNow: 9))
        sub.trialEndsAt = at(0, 5, daysFromNow: 9)
        await add(sub)
        var saved = try XCTUnwrap(store.subscriptions.first)
        XCTAssertEqual(saved.nextBillingDate, calendar.noon(of: days(9)))
        XCTAssertEqual(saved.trialEndsAt, calendar.noon(of: days(9)))

        saved.nextBillingDate = at(23, 59, daysFromNow: 20)
        saved.trialEndsAt = at(6, 0, daysFromNow: 20)
        await store.updateSubscription(saved)
        let edited = try XCTUnwrap(store.subscriptions.first)
        XCTAssertEqual(edited.nextBillingDate, calendar.noon(of: days(20)))
        XCTAssertEqual(edited.trialEndsAt, calendar.noon(of: days(20)))
    }

    // MARK: Changing

    func testEditingTheAmountUpdatesTotalsAndRecordsThePriceChange() async throws {
        let sub = TestFactories.makeSubscription(name: "Netflix", amount: 10)
        await add(sub)
        var edited = try XCTUnwrap(store.subscriptions.first)
        edited.amount = 12
        await store.updateSubscription(edited)
        XCTAssertEqual(store.totalMonthlySpend, 12)
        let change = try XCTUnwrap(LifecycleEventLog.shared.events.filter { $0.subscriptionId == sub.id }.last)
        XCTAssertEqual(change.kind, .priceChanged)
        XCTAssertEqual(change.previousAmount, 10)
        XCTAssertEqual(change.amount, 12)
    }

    /// The history holds every change to what it costs: the amount, its currency, how often it charges.
    func testAChangeOfCurrencyOrBillingPeriodGoesInTheHistoryToo() async throws {
        let sub = TestFactories.makeSubscription(name: "Crave", amount: 10, currency: "USD")
        await add(sub)
        var inDollarsCanadian = sub
        inDollarsCanadian.currency = "CAD"
        await store.updateSubscription(inDollarsCanadian)
        var yearly = inDollarsCanadian
        yearly.billingFrequency = .yearly
        await store.updateSubscription(yearly)
        var renamed = yearly
        renamed.name = "Crave Premium"
        await store.updateSubscription(renamed)

        let recorded = LifecycleEventLog.shared.events.filter { $0.subscriptionId == sub.id }
        XCTAssertEqual(recorded.map(\.kind), [.added, .priceChanged, .priceChanged], "a new name is not a new price")
        let points = PriceHistory.points(for: sub.id, events: LifecycleEventLog.shared.events)
        XCTAssertEqual(points.map(\.currency), ["USD", "CAD", "CAD"])
        XCTAssertEqual(points.map(\.frequency), [.monthly, .monthly, .yearly])
    }

    // MARK: Reaching the account

    /// What came back from the server used to replace the subscription, and the server doesn't store
    /// everything: the app it belongs to was gone the moment it synced.
    func testAnAddThatReachesTheAccountKeepsWhatOnlyThisIPhoneKnows() async throws {
        let sub = TestFactories.makeSubscription(name: "Pausely Pro")
        account.canSend = true
        store.lastErrorMessage = nil
        let reached = try await store.addSubscription(sub)
        XCTAssertTrue(reached)
        XCTAssertEqual(store.subscriptions, [sub], "exactly what was added, nothing dropped")
        XCTAssertEqual(account.rows[sub.id]?.name, "Pausely Pro")
        XCTAssertTrue(store.sync.pending.isEmpty)
        XCTAssertNil(store.lastErrorMessage, "nothing is said when nothing is waiting")
    }

    /// The old queue sent an edit as a change to a row the server had never been given, which changed
    /// nothing, and then counted it as sent: the next fetch put the old price back.
    func testAnEditMadeBeforeTheAddWasSentGoesUpWithIt() async throws {
        let sub = TestFactories.makeSubscription(name: "Netflix", amount: 10)
        await add(sub)
        var edited = sub
        edited.amount = 12
        await store.updateSubscription(edited)
        XCTAssertEqual(waiting, [.create], "still one thing to send: the add, as it is now")

        account.canSend = true
        await store.sync.drain(force: true)
        XCTAssertEqual(account.calls, ["create Netflix"])
        XCTAssertEqual(account.rows[sub.id]?.amount, 12)
        XCTAssertTrue(store.sync.pending.isEmpty)
    }

    func testACancelMadeBeforeTheAddWasSentGoesUpWithIt() async throws {
        let sub = TestFactories.makeSubscription(name: "Hulu", amount: 10)
        await add(sub)
        await store.updateSubscriptionStatus(id: sub.id, status: .cancelled)
        account.canSend = true
        await store.sync.drain(force: true)
        XCTAssertEqual(account.rows[sub.id]?.status, .cancelled)
    }

    func testADeleteMadeBeforeTheAddWasSentLeavesNothingOnTheAccount() async throws {
        let sub = TestFactories.makeSubscription(name: "Gone")
        await add(sub)
        await store.deleteSubscription(id: sub.id)
        XCTAssertEqual(waiting, [.delete])
        account.canSend = true
        await store.sync.drain(force: true)
        XCTAssertEqual(account.calls, ["delete"])
        XCTAssertTrue(account.rows.isEmpty)
    }

    func testOnceTheAccountHasItAnEditIsSentAsAnEditStraightAway() async throws {
        let sub = TestFactories.makeSubscription(name: "Netflix", amount: 10)
        await addOnline(sub)
        var edited = sub
        edited.amount = 12
        await store.updateSubscription(edited)
        XCTAssertEqual(account.calls, ["create Netflix", "update Netflix"])
        XCTAssertEqual(account.rows[sub.id]?.amount, 12)
        XCTAssertTrue(store.sync.pending.isEmpty)
    }

    /// "When you're back online" is only said when being offline is the reason.
    func testTheNoticeSaysWhyAChangeIsStillWaiting() async throws {
        let sub = TestFactories.makeSubscription(name: "Netflix")
        await addOnline(sub)

        account.failure = URLError(.notConnectedToInternet)
        await store.updateSubscriptionStatus(id: sub.id, status: .cancelled)
        XCTAssertEqual(store.lastErrorMessage, offlineNotice)

        struct Refused: Error {}
        account.failure = Refused()
        await store.updateSubscriptionStatus(id: sub.id, status: .active)
        XCTAssertEqual(store.lastErrorMessage,
                       L10n.string("Saved on this iPhone. It hasn't reached your account yet. Pausely will keep trying."))

        await store.deleteSubscription(id: sub.id)
        XCTAssertEqual(store.lastErrorMessage,
                       L10n.string("Removed from this iPhone. Your account still has it. Pausely will keep trying."))
        XCTAssertNotNil(account.rows[sub.id], "and it does")

        account.failure = URLError(.timedOut)
        let other = TestFactories.makeSubscription(name: "Other")
        await add(other)
        await store.deleteSubscription(id: other.id)
        XCTAssertEqual(store.lastErrorMessage, L10n.string("Removed from this iPhone. It will sync when you're back online."))
    }

    func testCancellingStopsCountingItAndReactivatingCountsItAgain() async throws {
        let sub = TestFactories.makeSubscription(name: "Hulu", amount: 10)
        await addOnline(sub)
        await store.updateSubscriptionStatus(id: sub.id, status: .cancelled)
        XCTAssertEqual(store.totalMonthlySpend, 0)
        XCTAssertEqual(account.rows[sub.id]?.status, .cancelled)
        await store.updateSubscriptionStatus(id: sub.id, status: .active)
        XCTAssertEqual(store.totalMonthlySpend, 10)
        XCTAssertEqual(account.rows[sub.id]?.status, .active)
        XCTAssertEqual(LifecycleEventLog.shared.events.filter { $0.subscriptionId == sub.id }.map(\.kind), [.added, .cancelled, .reactivated])
    }

    func testDeletingRemovesItItsTotalAndRecordsIt() async throws {
        let keep = TestFactories.makeSubscription(name: "Keep", amount: 5)
        let gone = TestFactories.makeSubscription(name: "Gone", amount: 7)
        await add(keep)
        await add(gone)
        XCTAssertEqual(store.totalMonthlySpend, 12)
        await store.deleteSubscription(id: gone.id)
        XCTAssertEqual(store.subscriptions.map(\.id), [keep.id])
        XCTAssertEqual(store.totalMonthlySpend, 5)
        XCTAssertEqual(LifecycleEventLog.shared.events.filter { $0.subscriptionId == gone.id }.last?.kind, .deleted)
        XCTAssertEqual(waiting, [.create, .delete])
    }

    // MARK: Lists and totals

    func testTotalsCountOnlyActiveSubscriptions() async {
        await add(TestFactories.makeSubscription(name: "Active", amount: 10, status: .active))
        await add(TestFactories.makeSubscription(name: "Cancelled", amount: 20, status: .cancelled))
        XCTAssertEqual(store.totalMonthlySpend, 10)
        XCTAssertEqual(store.totalAnnualSpend, 120)
    }

    /// A total that had to convert something is an estimate and says so; one that didn't is exact.
    func testATotalIsMarkedAsAnEstimateOnlyWhenSomethingWasConverted() async throws {
        await add(TestFactories.makeSubscription(name: "Netflix", amount: 10, currency: "USD"))
        XCTAssertFalse(store.totalIsConverted)
        XCTAssertEqual(MoneyFormat.total(store.totalMonthlySpend, "USD", converted: store.totalIsConverted), MoneyFormat.string(Decimal(10), "USD"))

        let crave = TestFactories.makeSubscription(name: "Crave", amount: 14, currency: "CAD")
        await add(crave)
        XCTAssertTrue(store.totalIsConverted)
        XCTAssertTrue(MoneyFormat.total(store.totalMonthlySpend, "USD", converted: store.totalIsConverted).hasPrefix("≈"))

        // Cancelled, it is no longer in the total, so the total is exact again.
        await store.updateSubscriptionStatus(id: crave.id, status: .cancelled)
        XCTAssertFalse(store.totalIsConverted)
    }

    /// One list, one answer. Home left trials out and Insights did too, while the paywall and the
    /// year slip counted them: someone with a trial saw different yearly figures for the same list.
    func testEveryTotalAndCountIsAboutTheSameSubscriptions() async throws {
        await add(TestFactories.makeSubscription(name: "On", amount: 10, status: .active, category: "Music"))
        await add(TestFactories.makeSubscription(name: "Trial", amount: 5, status: .trial, category: "Music"))
        await add(TestFactories.makeSubscription(name: "Cancelled", amount: 1000, status: .cancelled, category: "Music"))

        // Home and the Subscriptions tab
        XCTAssertEqual(store.totalMonthlySpend, 15)
        XCTAssertEqual(store.totalAnnualSpend, 180)
        XCTAssertEqual(store.activeSubscriptions.map(\.name).sorted(), ["On", "Trial"])
        // Insights, by category
        XCTAssertEqual(store.subscriptions.categoryTotals(in: "USD"), [CategoryTotal(category: "Music", amount: 15, count: 2)])
        // The paywall's "about … a year" and the year slip
        XCTAssertEqual(store.activeSubscriptions.annualTotal(in: "USD"), 180)
        let slip = WrappedStats(subscriptions: store.subscriptions, events: LifecycleEventLog.shared.events)
        XCTAssertEqual(slip.yearlyCost, 180)
        XCTAssertEqual(slip.totalCount, 2)
        // The paywall's comparison never names something that isn't charging
        let comparison = PaywallCase.comparison(proYearly: 30, proCurrency: "USD", subscriptions: store.subscriptions,
                                                rates: CurrencyManager.shared.rates)
        XCTAssertEqual(comparison?.name, "On")
        // The widget
        let widget = WidgetDataStore.feed(for: store.subscriptions, now: Date())
        XCTAssertEqual(widget.monthlyText, MoneyFormat.string(Decimal(15), "USD"))
    }
}
