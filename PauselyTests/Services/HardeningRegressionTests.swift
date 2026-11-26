import StoreKit
import UserNotifications
import XCTest
@testable import Pausely

/// Regression tests for the deep-audit bugs fixed across sync, lifecycle, trials, Pause Plan,
/// TallyImporter, Horizon, CancelConcierge, and CSV export.
@MainActor
final class HardeningRegressionTests: XCTestCase {

    private var sandbox: StoreSandbox!
    private var defaults: UserDefaults!
    private var suiteName = ""

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    override func setUp() async throws {
        sandbox = StoreSandbox()
        suiteName = "HardeningRegressionTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        UserDefaults.standard.set(false, forKey: "debug_premium_override")
        UserDefaults.standard.set(false, forKey: "debug_free_pro")
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        await sandbox.restore()
        sandbox = nil
    }

    // Bug #3: Concurrent server fetch + add (drained) + edit (pending) must never drop the new subscription.
    func testConcurrentFetchWithAddThenEditKeepsSubscriptionAndEdit() async throws {
        let store = SubscriptionStore.shared
        defaults.set("user-concurrent", forKey: SubscriptionStore.syncedUserKey)

        let existing = TestFactories.makeSubscription(name: "Existing", amount: 10)
        sandbox.transport.canSend = true
        sandbox.transport.hold(existing)
        _ = try await store.addSubscription(existing)
        store.sync.removeAll()

        let added = TestFactories.makeSubscription(name: "AddedMidFetch", amount: 15)
        try await store.reconcileWithServer(userId: "user-concurrent", defaults: defaults) {
            self.sandbox.transport.canSend = true
            _ = try? await store.addSubscription(added)
            self.sandbox.transport.canSend = false
            var edited = added
            edited.amount = 25
            await store.updateSubscription(edited)
            return ([existing], [])
        }

        let surviving = store.subscriptions.first { $0.id == added.id }
        XCTAssertNotNil(surviving, "newly added subscription must survive in-flight server fetch")
        XCTAssertEqual(surviving?.amount, 25, "edit made during fetch must be preserved")
    }

    // Bug #4: Trial with both trialEndsAt == D and nextBillingDate == D must never double-count day D.
    func testTrialEndingDoesNotDoubleCountFirstChargeAsRenewal() {
        let end = day(2026, 11, 20)
        let trial = Subscription(name: "Pausely Pro", category: "Productivity", amount: 5, currency: "USD",
                                 billingFrequency: .monthly, nextBillingDate: end, trialEndsAt: end, status: .trial)

        let oneDayLater = SubscriptionLifecycle.changes(for: [trial], since: day(2026, 11, 15), now: day(2026, 11, 21), calendar: cal)
        XCTAssertEqual(oneDayLater.endedTrials[trial.id], end)
        XCTAssertTrue(oneDayLater.renewals.isEmpty, "day D must not also emit a .renewed event")

        let onEndDay = SubscriptionLifecycle.changes(for: [trial], since: day(2026, 11, 15), now: day(2026, 11, 20, hour: 15), calendar: cal)
        XCTAssertTrue(onEndDay.endedTrials.isEmpty)
        XCTAssertTrue(onEndDay.renewals.isEmpty)

        let weeksLater = SubscriptionLifecycle.changes(for: [trial], since: day(2026, 11, 15), now: day(2026, 12, 22), calendar: cal)
        XCTAssertEqual(weeksLater.endedTrials[trial.id], end)
        XCTAssertEqual(weeksLater.renewals.count, 1)
        XCTAssertEqual(ReminderPlanner.dayStamp(weeksLater.renewals[0].date, cal), "2026-12-20")
    }

    // Bug #5 + #8: App-created trials (nextBillingDate == nil, trialEndsAt != nil) work in Pause Plan,
    // CancelConcierge, CSV export, and undo-cancel; starting a plan on Turn 0's renewal day doesn't skip Turn 0.
    func testPausePlanTrialRemindersSameDayStartAndTrialExports() async throws {
        let now = day(2026, 11, 24, hour: 8)
        let netflix = Subscription(name: "Netflix", category: "Entertainment", amount: 20, currency: "USD",
                                   billingFrequency: .monthly, nextBillingDate: day(2026, 11, 24), status: .active)
        let huluTrial = Subscription(name: "Hulu", category: "Entertainment", amount: 18, currency: "USD",
                                     billingFrequency: .monthly, nextBillingDate: nil, trialEndsAt: day(2026, 12, 1), status: .trial)
        let plan = PausePlan(subscriptionIds: [netflix.id, huluTrial.id], startedOn: now)
        let byId = [netflix.id: netflix, huluTrial.id: huluTrial]

        let current = PausePlanSchedule.currentTurn(plan, subscriptions: byId, now: now, calendar: cal)
        XCTAssertEqual(current?.subscriptionId, netflix.id, "starting Pause Plan on Turn 0's renewal day must keep Turn 0 active")
        XCTAssertEqual(ReminderPlanner.dayStamp(try XCTUnwrap(current?.end), cal), "2026-12-24")

        let reminders = PausePlanSchedule.reminders(plan, subscriptions: [netflix, huluTrial], now: now, calendar: cal)
        let hasTrialCancel = reminders.contains {
            $0.kind == .planCancel && $0.subscriptionId == huluTrial.id && ReminderPlanner.dayStamp($0.eventDate, cal) == "2026-12-01"
        }
        XCTAssertTrue(hasTrialCancel, "Pause Plan must remind before an app-created trial ends")

        let draft = CancelConcierge.cancellationDraft(for: huluTrial, now: now, calendar: cal, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(draft.body.contains("Dec 1"), "cancellation draft should mention trial end date: \(draft.body)")
        let csv = SubscriptionExporter.csv(for: [huluTrial], now: now, calendar: cal)
        XCTAssertTrue(csv.contains("2026-12-01"), "CSV export should include trial end date")

        let store = SubscriptionStore.shared
        _ = try await store.addSubscription(huluTrial)
        await store.updateSubscriptionStatus(id: huluTrial.id, status: .cancelled)
        let restored = await store.startAgain(id: huluTrial.id, on: now, calendar: cal)
        XCTAssertTrue(restored)
        XCTAssertEqual(store.subscriptions.first { $0.id == huluTrial.id }?.status, .trial)
    }

    // Bug #12 + #14: Trial ending today after noon stays `.trial`; cancelled sub doesn't block re-import;
    // Horizon.undated includes undated trials.
    func testTallyAfternoonTrialCancelledReimportAndUndatedTrial() async throws {
        let endNoon = day(2026, 11, 24, hour: 12)
        let afternoon = day(2026, 11, 24, hour: 18)
        let line = TallyLine(name: "Duolingo", category: "Education", amount: Decimal(string: "83.99")!,
                             currency: "USD", frequency: .yearly, trialEndsAt: endNoon)
        let sub = line.subscription(now: afternoon, calendar: cal)
        XCTAssertEqual(sub.status, .trial, "trial ending today after noon must remain .trial")
        XCTAssertEqual(sub.trialEndsAt, endNoon)

        let store = SubscriptionStore.shared
        let oldCancelled = TestFactories.makeSubscription(name: "Netflix", amount: 15, status: .cancelled, nextBillingDate: nil)
        _ = try await store.addSubscription(oldCancelled)
        let outcome = await TallyImporter.add([
            TallyLine(name: "Netflix", category: "Entertainment", amount: Decimal(string: "19.99")!, currency: "USD")
        ], into: store, defaults: defaults)
        XCTAssertEqual(outcome.added, ["Netflix"], "cancelled history entry must not block re-importing active service")
        XCTAssertTrue(outcome.alreadyListed.isEmpty)

        let undatedTrial = Subscription(name: "TrialNoDate", category: "Other", amount: 9, currency: "USD",
                                        billingFrequency: .monthly, nextBillingDate: nil, trialEndsAt: nil, status: .trial)
        XCTAssertEqual(Horizon.undated([undatedTrial]).map(\.id), [undatedTrial.id])
    }

    // Bug #16 + #18: LifecycleEventRecord truncates >200-char names; SyncQueue.fail ignores stale revisions.
    func testLifecycleNameTruncationAndStaleRevisionFail() async {
        let longName = String(repeating: "A", count: 250)
        let event = LifecycleEvent(id: UUID(), kind: .added, subscriptionId: UUID(), subscriptionName: longName,
                                   date: Date(), amount: 10, currency: "USD", frequency: .monthly)
        let record = LifecycleEventRecord(from: event, userId: UUID())
        XCTAssertEqual(record.subscription_name.count, 200)

        let sub = TestFactories.makeSubscription(name: "Netflix", amount: 15)
        let transport = SlowFailTransport()
        let queue = SyncQueue(transport: transport, load: { Data() }, store: { _ in })
        var current = sub
        queue.currentCopy = { id in id == current.id ? current : nil }
        queue.noteAdded(sub.id)

        let drainTask = Task { await queue.drain(force: true) }
        await transport.waitUntilStarted()
        current.amount = 20
        queue.noteChanged(sub.id)
        transport.finishWithFailure()
        await drainTask.value

        XCTAssertTrue(queue.pending.isEmpty, "revision 2 must retry immediately without backoff from revision 1")
        XCTAssertEqual(transport.attempts, 2)
    }

    // Physical-device & hardware readiness: Taptic Engine haptics, lock-screen "Keep it" category options,
    // and live App Store StoreKit product fetch on real iOS hardware.
    func testHardwareHapticsLockScreenKeepActionAndLiveStoreKit() async throws {
        // 1. All six ink-and-paper haptics run cleanly on Taptic Engine (and Simulator).
        Feel.selection()
        Feel.tick()
        Feel.keep()
        Feel.tearStart()
        Feel.tearEnd()
        Feel.landed()

        // 2. Notification category registers "Keep it" WITHOUT .authenticationRequired so it works from Lock Screen.
        ReminderActions.registerCategories()
        let categories = await UNUserNotificationCenter.current().notificationCategories()
        let decision = try XCTUnwrap(categories.first { $0.identifier == ReminderActions.decisionCategory })
        let keepAction = try XCTUnwrap(decision.actions.first { $0.identifier == ReminderActions.keep })
        XCTAssertFalse(keepAction.options.contains(.authenticationRequired), "Keep it must run from lock screen without unlock")
        XCTAssertFalse(keepAction.options.contains(.foreground), "Keep it must run silently in background")

        // 3. On real iPhone hardware, verify Apple's live/sandbox StoreKit returns both Pausely Pro products.
        #if !targetEnvironment(simulator)
        let ids = StoreKitManager.ProductID.allCases.map(\.rawValue)
        let products = try await StoreKit.Product.products(for: ids)
        XCTAssertEqual(Set(products.map(\.id)), Set(ids), "App Store must return monthly and annual Pro products on device")
        for product in products {
            XCTAssertGreaterThan(product.price, 0, "\(product.id) must have a positive storefront price")
        }
        #endif
    }
}

@MainActor
private final class SlowFailTransport: SyncTransport {
    var canSend = true
    var attempts = 0
    private var startedCont: CheckedContinuation<Void, Never>?
    private var releaseCont: CheckedContinuation<Void, Never>?
    private var didStart = false

    func waitUntilStarted() async {
        if didStart { return }
        await withCheckedContinuation { startedCont = $0 }
    }

    func finishWithFailure() {
        releaseCont?.resume()
        releaseCont = nil
    }

    func create(_ subscription: Subscription) async throws {
        attempts += 1
        if attempts == 1 {
            didStart = true
            startedCont?.resume()
            startedCont = nil
            await withCheckedContinuation { releaseCont = $0 }
            throw NSError(domain: "TestHTTP", code: 400)
        }
    }

    func update(_ subscription: Subscription) async throws { attempts += 1 }
    func delete(id: UUID) async throws { attempts += 1 }
}
