import XCTest
@testable import Pausely

/// Hardware-protected cache migration + multi-device merge/round-trip for Savings Receipt history
/// (`LifecycleSync`) and Pause Plan (`PausePlanSync`).
@MainActor
final class MultiDeviceSyncTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MultiDeviceSyncTests-\(UUID().uuidString)", isDirectory: true)
        suite = "MultiDeviceSyncTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.billing.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testProtectedBlobStoreMigratesLegacyUserDefaultsAndRemovesPlaintextCopy() throws {
        let payload = Data("{\"subscriptions\":[\"Netflix\"]}".utf8)
        let encodedLegacy = try JSONEncoder().encode(payload)
        defaults.set(encodedLegacy, forKey: "cached_subscriptions")

        let read = ProtectedBlobStore.read(filename: "subscriptions_cache.json",
                                           legacyKey: "cached_subscriptions",
                                           directory: tempDir,
                                           defaults: defaults)
        XCTAssertEqual(read, payload)
        XCTAssertNil(defaults.data(forKey: "cached_subscriptions"), "legacy plaintext UserDefaults entry is deleted after migration")

        let fileURL = tempDir.appendingPathComponent("subscriptions_cache.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        // Clearing removes the protected file cleanly.
        ProtectedBlobStore.write(Data(), filename: "subscriptions_cache.json",
                                 legacyKey: "cached_subscriptions", directory: tempDir, defaults: defaults)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testLifecycleSyncMergesLocalAndRemoteDeduplicatingByUUID() {
        let netflix = TestFactories.makeSubscription(name: "Netflix", amount: Decimal(string: "15.99")!)
        let sharedID = UUID()
        let shared = LifecycleEvent(id: sharedID, kind: .added, subscription: netflix, date: day(2026, 9, 1))
        let remoteOnly = LifecycleEvent(id: UUID(), kind: .renewed, subscription: netflix, date: day(2026, 10, 1))
        let localOnly = LifecycleEvent(id: UUID(), kind: .cancelled, subscription: netflix, date: day(2026, 11, 1), renewalDate: day(2026, 11, 5))

        let result = LifecycleSync.merge(local: [shared, localOnly], remote: [shared, remoteOnly])
        XCTAssertEqual(result.merged.map(\.kind), [.added, .renewed, .cancelled])
        XCTAssertEqual(result.toUpload.map(\.id), [localOnly.id])
    }

    func testLifecycleEventRecordRoundTripsAllFieldsAndSavedDays() throws {
        let userId = UUID()
        var sub = TestFactories.makeSubscription(name: "Spotify", amount: Decimal(string: "12.99")!, currency: "CAD", billingFrequency: .monthly)
        sub.nextBillingDate = day(2026, 12, 15)
        let event = LifecycleEvent(kind: .cancelled, subscription: sub, date: day(2026, 11, 20),
                                   previousAmount: Decimal(string: "10.99"), renewalDate: day(2026, 12, 15))

        let data = try JSONEncoder().encode(LifecycleEventRecord(from: event, userId: userId))
        let back = try JSONDecoder().decode(LifecycleEventRecord.self, from: data).toEvent()

        XCTAssertEqual(back?.id, event.id)
        XCTAssertEqual(back?.kind, .cancelled)
        XCTAssertEqual(back?.subscriptionId, sub.id)
        XCTAssertEqual(back?.subscriptionName, "Spotify")
        XCTAssertEqual(back?.amount, Decimal(string: "12.99"))
        XCTAssertEqual(back?.previousAmount, Decimal(string: "10.99"))
        XCTAssertEqual(back?.currency, "CAD")
        XCTAssertEqual(back?.frequency, .monthly)
        XCTAssertEqual(back?.renewalDate, day(2026, 12, 15))
        XCTAssertEqual(back?.anchorDate, day(2026, 12, 15))
    }

    func testPausePlanSyncRestoresOnFreshInstallAndPushesLocalWhenServerEmpty() throws {
        let a = UUID(), b = UUID(), c = UUID()
        let older = PausePlan(subscriptionIds: [a, b], startedOn: day(2026, 10, 1))
        let newer = PausePlan(subscriptionIds: [b, c, a], startedOn: day(2026, 11, 1))

        XCTAssertEqual(PausePlanSync.resolve(local: nil, remote: nil), .inSync)
        XCTAssertEqual(PausePlanSync.resolve(local: nil, remote: newer), .adoptRemote(newer), "reinstall restores plan")
        XCTAssertEqual(PausePlanSync.resolve(local: older, remote: nil), .pushLocal(older), "offline plan uploads")
        XCTAssertEqual(PausePlanSync.resolve(local: older, remote: newer), .adoptRemote(newer), "newer remote wins")
        XCTAssertEqual(PausePlanSync.resolve(local: newer, remote: older), .pushLocal(newer), "newer local wins")
        XCTAssertEqual(PausePlanSync.resolve(local: newer, remote: newer), .inSync)

        // Round-trip serialization check
        let recordData = try JSONEncoder().encode(PausePlanRecord(from: newer, userId: UUID()))
        let decoded = try JSONDecoder().decode(PausePlanRecord.self, from: recordData).toPlan()
        XCTAssertEqual(decoded?.subscriptionIds, [b, c, a])
    }
}
