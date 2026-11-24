import XCTest
@testable import Pausely

/// The free plan tracks five subscriptions: five that are charging. A cancelled one is history and
/// takes no place, so cancelling, which is what the app is for, makes room for the next.
@MainActor
final class FreePlanTests: XCTestCase {

    private let store = SubscriptionStore.shared
    private var sandbox: StoreSandbox!

    override func setUp() async throws {
        sandbox = StoreSandbox()
        UserDefaults.standard.set(false, forKey: "debug_premium_override")
        UserDefaults.standard.set(false, forKey: "debug_free_pro")
        try XCTSkipIf(PaymentManager.shared.isPremium, "This simulator has Pro; the free plan can't be exercised on it")
    }

    override func tearDown() async throws {
        await sandbox.restore()
        sandbox = nil
    }

    private func sub(_ name: String, status: SubscriptionStatus = .active) -> Subscription {
        TestFactories.makeSubscription(name: name, status: status)
    }

    func testOnlyWhatIsChargingTakesAPlace() {
        let list = [sub("On"), sub("Trial", status: .trial), sub("Gone", status: .cancelled), sub("Also gone", status: .cancelled)]
        XCTAssertEqual(FreeTier.used(by: list), 2)
        XCTAssertEqual(FreeTier.room(in: list), FreeTier.subscriptionLimit - 2)
        XCTAssertEqual(FreeTier.room(in: (0..<9).map { sub("S\($0)") }), 0, "Never negative")
    }

    func testTheSixthIsRefusedAndCancellingOneMakesRoom() async throws {
        for index in 0..<FreeTier.subscriptionLimit { _ = try await store.addSubscription(sub("Charging \(index)")) }
        do {
            _ = try await store.addSubscription(sub("One too many"))
            XCTFail("The free plan took a sixth subscription")
        } catch SubscriptionStore.SubscriptionLimitError.freeTierLimitReached {}
        XCTAssertEqual(store.subscriptions.count, FreeTier.subscriptionLimit)

        // Before, a cancelled row kept its place, and the only way to make room was to delete it,
        // which also deletes it from the Savings Receipt.
        let first = try XCTUnwrap(store.subscriptions.last)
        await store.updateSubscriptionStatus(id: first.id, status: .cancelled)
        _ = try await store.addSubscription(sub("Fits now"))
        XCTAssertEqual(store.subscriptions.count, FreeTier.subscriptionLimit + 1)
        XCTAssertEqual(FreeTier.used(by: store.subscriptions), FreeTier.subscriptionLimit)
    }

    func testSomethingAlreadyCancelledCanAlwaysBeListed() async throws {
        for index in 0..<FreeTier.subscriptionLimit { _ = try await store.addSubscription(sub("Charging \(index)")) }
        _ = try await store.addSubscription(sub("Ended last year", status: .cancelled))
        XCTAssertEqual(store.subscriptions.first?.name, "Ended last year")
    }

    /// What an import may add is the same count: the places left for what charges.
    func testAnImportFillsOnlyThePlacesLeft() async throws {
        _ = try await store.addSubscription(sub("Charging"))
        _ = try await store.addSubscription(sub("Cancelled", status: .cancelled))
        let lines = (0..<6).map { TallyLine(name: "Found \($0)", category: "Other", amount: Decimal(10 + $0), currency: "USD",
                                            frequency: .monthly) }
        let outcome = await TallyImporter.add(lines, into: store, rates: .fallback, defaults: UserDefaults(suiteName: "FreePlanTests")!)
        UserDefaults(suiteName: "FreePlanTests")?.removePersistentDomain(forName: "FreePlanTests")
        XCTAssertEqual(outcome.added.count, FreeTier.subscriptionLimit - 1)
        XCTAssertEqual(outcome.waiting.count, 6 - (FreeTier.subscriptionLimit - 1))
    }

    /// One place decides whether the free plan is full. A screen that compares a count with the limit
    /// by itself (as four did, each counting cancelled rows) fails here.
    func testNothingElseComparesACountWithTheLimit() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let appFolder = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: appFolder.path), "Sources aren't readable from this test run")
        var offenders: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: appFolder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            if ["PaymentManager.swift", "ProFeature.swift"].contains(file.lastPathComponent) { continue }
            let text = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                // In a sentence ("Free tracks \(FreeTier.subscriptionLimit)") the number is only shown.
                let outsideSentences = line.replacingOccurrences(of: "\\(FreeTier.subscriptionLimit)", with: "")
                if outsideSentences.contains("FreeTier.subscriptionLimit") {
                    offenders.append("\(file.path.dropFirst(root.path.count + 1)):\(index + 1)")
                }
            }
        }
        XCTAssertEqual(offenders, [], "Ask FreeTier.used, FreeTier.room or PaymentManager.hasRoom")
    }
}

/// A cancelled subscription can be brought back, and what the verdict says about one comes from its
/// own history.
@MainActor
final class StartAgainAndVerdictFactsTests: XCTestCase {

    private let store = SubscriptionStore.shared
    private var sandbox: StoreSandbox!
    private let cal = Calendar.billing

    override func setUp() async throws {
        sandbox = StoreSandbox()
        UserDefaults.standard.set(false, forKey: "debug_premium_override")
        UserDefaults.standard.set(false, forKey: "debug_free_pro")
        try XCTSkipIf(PaymentManager.shared.isPremium, "This simulator has Pro; the free plan can't be exercised on it")
    }

    override func tearDown() async throws {
        await sandbox.restore()
        sandbox = nil
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Before, the only way back was to add it a second time, which left two rows.
    func testACancelledSubscriptionStartsAgainFromToday() async throws {
        var netflix = TestFactories.makeSubscription(name: "Netflix", nextBillingDate: day(2026, 3, 5))
        netflix.status = .cancelled
        _ = try await store.addSubscription(netflix)

        let started = await store.startAgain(id: netflix.id, on: day(2026, 11, 12))

        XCTAssertTrue(started)
        let now = try XCTUnwrap(store.subscriptions.first)
        XCTAssertEqual(now.status, .active)
        // Paid today; the next charge is a month from today, not from the old date.
        XCTAssertEqual(now.nextRenewal(onOrAfter: day(2026, 11, 13)), day(2026, 12, 12))
        XCTAssertEqual(store.subscriptions.count, 1)
        XCTAssertTrue(LifecycleEventLog.shared.events.contains { $0.subscriptionId == netflix.id && $0.kind == .reactivated })
    }

    func testOnAFullFreePlanStartingAgainIsRefusedAndNothingChanges() async throws {
        for index in 0..<FreeTier.subscriptionLimit {
            _ = try await store.addSubscription(TestFactories.makeSubscription(name: "Charging \(index)"))
        }
        var old = TestFactories.makeSubscription(name: "Old gym")
        old.status = .cancelled
        _ = try await store.addSubscription(old)

        let started = await store.startAgain(id: old.id)

        XCTAssertFalse(started)
        XCTAssertEqual(store.subscriptions.first { $0.id == old.id }?.status, .cancelled)
    }

    func testOneThatIsChargingKeepsItsDate() async throws {
        let netflix = TestFactories.makeSubscription(name: "Netflix", nextBillingDate: day(2026, 11, 20))
        _ = try await store.addSubscription(netflix)
        let started = await store.startAgain(id: netflix.id, on: day(2026, 11, 12))
        XCTAssertTrue(started)
        XCTAssertEqual(store.subscriptions.first?.nextBillingDate, day(2026, 11, 20))
    }

    // MARK: - What the renewals have come to

    private func event(_ kind: LifecycleEvent.Kind, _ sub: Subscription, on date: Date) -> LifecycleEvent {
        LifecycleEvent(kind: kind, subscription: sub, date: date)
    }

    func testRenewalsSoFarAreSummedAtThePriceOfTheirDay() {
        var netflix = TestFactories.makeSubscription(name: "Netflix", amount: 13.99)
        let march = event(.renewed, netflix, on: day(2026, 3, 5))
        let april = event(.renewed, netflix, on: day(2026, 4, 5))
        netflix.amount = 15.99   // the price went up in May
        let may = event(.renewed, netflix, on: day(2026, 5, 5))
        let other = event(.renewed, TestFactories.makeSubscription(name: "Spotify", amount: 10.99), on: day(2026, 5, 9))
        let edit = event(.priceChanged, netflix, on: day(2026, 5, 1))

        let renewed = VerdictFacts.renewedSoFar(for: netflix, events: [april, may, other, edit, march])
        XCTAssertEqual(renewed?.total, Decimal(string: "43.97"))
        XCTAssertEqual(renewed?.since, day(2026, 3, 5))
    }

    func testTheFirstChargeAfterAFreeTrialCounts() {
        let crave = TestFactories.makeSubscription(name: "Crave", amount: 9.99)
        let renewed = VerdictFacts.renewedSoFar(for: crave, events: [event(.trialEnded, crave, on: day(2026, 10, 1)),
                                                                    event(.renewed, crave, on: day(2026, 11, 1))])
        XCTAssertEqual(renewed?.total, Decimal(string: "19.98"))
    }

    func testNothingIsSaidBeforeARenewalHasPassedOrAcrossCurrencies() {
        var dazn = TestFactories.makeSubscription(name: "DAZN", amount: 20, currency: "EUR")
        XCTAssertNil(VerdictFacts.renewedSoFar(for: dazn, events: [event(.added, dazn, on: day(2026, 3, 1))]))

        let inEuros = event(.renewed, dazn, on: day(2026, 3, 5))
        dazn.currency = "USD"
        let inDollars = event(.renewed, dazn, on: day(2026, 4, 5))
        XCTAssertNil(VerdictFacts.renewedSoFar(for: dazn, events: [inEuros, inDollars]), "a sum across currencies would be a guess")
    }
}
