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
                // In a sentence ("Free watches \(FreeTier.subscriptionLimit)") the number is only shown.
                let outsideSentences = line.replacingOccurrences(of: "\\(FreeTier.subscriptionLimit)", with: "")
                if outsideSentences.contains("FreeTier.subscriptionLimit") {
                    offenders.append("\(file.path.dropFirst(root.path.count + 1)):\(index + 1)")
                }
            }
        }
        XCTAssertEqual(offenders, [], "Ask FreeTier.used, FreeTier.room or PaymentManager.hasRoom")
    }
}
