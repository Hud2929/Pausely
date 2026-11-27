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

    func testProtectedBlobStoreMigratesRawLegacyDataAndPreservesLegacyKeyOnWriteFailure() throws {
        // Raw JSON bytes (not double-encoded by @AppSetting), matching legacy `first_run_tally_waiting`.
        let rawPayload = Data("[{\"name\":\"Hulu\"}]".utf8)
        defaults.set(rawPayload, forKey: "first_run_tally_waiting")
        let read = ProtectedBlobStore.read(filename: "waiting_lines.json",
                                           legacyKey: "first_run_tally_waiting",
                                           directory: tempDir,
                                           defaults: defaults)
        XCTAssertEqual(read, rawPayload)
        XCTAssertNil(defaults.data(forKey: "first_run_tally_waiting"))

        // If the destination directory cannot be created (path is a regular file), legacy key is preserved.
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let blockerFile = tempDir.appendingPathComponent("not_a_directory")
        try Data("x".utf8).write(to: blockerFile)
        defaults.set(rawPayload, forKey: "fallback_key")
        ProtectedBlobStore.write(rawPayload, filename: "blocked.json", legacyKey: "fallback_key",
                                 directory: blockerFile, defaults: defaults)
        XCTAssertEqual(defaults.data(forKey: "fallback_key"), rawPayload, "failed write must not erase legacy UserDefaults copy")
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

    func testLifecycleEventRecordUsesRealPostgresOccurredAtColumnAndRoundTrips() throws {
        let userId = UUID()
        var sub = TestFactories.makeSubscription(name: "Spotify", amount: Decimal(string: "12.99")!, currency: "CAD", billingFrequency: .monthly)
        sub.nextBillingDate = day(2026, 12, 15)
        let event = LifecycleEvent(kind: .cancelled, subscription: sub, date: day(2026, 11, 20),
                                   previousAmount: Decimal(string: "10.99"), renewalDate: day(2026, 12, 15))

        let data = try JSONEncoder().encode(LifecycleEventRecord(from: event, userId: userId))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["occurred_at"], "wire column must match Postgres public.lifecycle_events.occurred_at")
        XCTAssertNil(json["event_date"], "must not send non-existent event_date column")

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

    func testPausePlanSyncTombstonePreventsZombieResurrectionAndRoundTripsExplicitNull() throws {
        let a = UUID(), b = UUID(), c = UUID()
        let olderPlan = PausePlan(subscriptionIds: [a, b], startedOn: day(2026, 10, 1))
        let newerPlan = PausePlan(subscriptionIds: [b, c, a], startedOn: day(2026, 11, 1))

        let olderState = PausePlanStore.SyncState(plan: olderPlan, updatedAt: day(2026, 10, 1), endedAt: nil, pendingSync: false)
        let newerState = PausePlanStore.SyncState(plan: newerPlan, updatedAt: day(2026, 11, 1), endedAt: nil, pendingSync: false)
        let endedLater = PausePlanStore.SyncState(plan: nil, updatedAt: day(2026, 11, 10), endedAt: day(2026, 11, 10), pendingSync: true)
        let restartedAfterEnd = PausePlanStore.SyncState(plan: newerPlan, updatedAt: day(2026, 11, 15), endedAt: nil, pendingSync: true)

        XCTAssertEqual(PausePlanSync.resolve(local: nil, remote: nil), .inSync)
        XCTAssertEqual(PausePlanSync.resolve(local: nil, remote: newerState), .adoptRemote(newerState), "reinstall restores plan")
        XCTAssertEqual(PausePlanSync.resolve(local: olderState, remote: nil), .pushLocal(olderState), "offline plan uploads")
        XCTAssertEqual(PausePlanSync.resolve(local: olderState, remote: newerState), .adoptRemote(newerState), "newer remote wins")
        XCTAssertEqual(PausePlanSync.resolve(local: newerState, remote: olderState), .pushLocal(newerState), "newer local wins")
        XCTAssertEqual(PausePlanSync.resolve(local: newerState, remote: newerState), .inSync)

        // Tombstone beats stale active copy in both directions (no zombie resurrection!).
        XCTAssertEqual(PausePlanSync.resolve(local: endedLater, remote: newerState), .pushLocal(endedLater))
        XCTAssertEqual(PausePlanSync.resolve(local: newerState, remote: endedLater), .adoptRemote(endedLater))
        // Restarting after an end beats the older tombstone.
        XCTAssertEqual(PausePlanSync.resolve(local: restartedAfterEnd, remote: endedLater), .pushLocal(restartedAfterEnd))

        // Active record must explicitly encode `"ended_at": null` so server clears prior tombstone.
        let activeData = try JSONEncoder().encode(PausePlanRecord(from: restartedAfterEnd, userId: UUID()))
        let activeJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: activeData) as? [String: Any])
        XCTAssertTrue(activeJSON["ended_at"] is NSNull, "active PausePlanRecord must explicitly encode ended_at: null")
        let decodedActive = try JSONDecoder().decode(PausePlanRecord.self, from: activeData).toSyncState()
        XCTAssertEqual(decodedActive?.plan?.subscriptionIds, [b, c, a])
        XCTAssertNil(decodedActive?.endedAt)

        // Tombstone record encodes non-null `ended_at` and decodes as nil plan.
        let endedData = try JSONEncoder().encode(PausePlanRecord(from: endedLater, userId: UUID()))
        let decodedEnded = try JSONDecoder().decode(PausePlanRecord.self, from: endedData).toSyncState()
        XCTAssertNil(decodedEnded?.plan)
        XCTAssertNotNil(decodedEnded?.endedAt)

        // Legacy raw PausePlan JSON decodes seamlessly into SyncState.
        let legacyData = try JSONEncoder().encode(olderPlan)
        let migrated = try JSONDecoder().decode(PausePlanStore.SyncState.self, from: legacyData)
        XCTAssertEqual(migrated.plan, olderPlan)
        XCTAssertNil(migrated.endedAt)
    }

    func testPausePlanSyncConvergesWithFractionalSecondDates() throws {
        let a = UUID(), b = UUID()
        let fractional = Date(timeIntervalSince1970: 1_795_000_000.842)
        let localActive = PausePlanStore.SyncState(
            plan: PausePlan(subscriptionIds: [a, b], startedOn: fractional),
            updatedAt: fractional,
            endedAt: nil,
            pendingSync: false
        )
        let encoded = try JSONEncoder().encode(PausePlanRecord(from: localActive, userId: UUID()))
        let remoteActive = try XCTUnwrap(JSONDecoder().decode(PausePlanRecord.self, from: encoded).toSyncState())
        XCTAssertEqual(PausePlanSync.resolve(local: localActive, remote: remoteActive), .inSync,
                       "fractional-second local dates must converge cleanly with whole-second ISO-8601 server records")

        let localEnded = PausePlanStore.SyncState(plan: nil, updatedAt: fractional, endedAt: fractional, pendingSync: false)
        let encodedEnded = try JSONEncoder().encode(PausePlanRecord(from: localEnded, userId: UUID()))
        let remoteEnded = try XCTUnwrap(JSONDecoder().decode(PausePlanRecord.self, from: encodedEnded).toSyncState())
        XCTAssertEqual(PausePlanSync.resolve(local: localEnded, remote: remoteEnded), .inSync)
    }

    func testPausePlanRecordPreservesSavingsSinceAcrossDevicesAndReinstalls() throws {
        let a = UUID(), b = UUID()
        let origin = day(2026, 1, 1)
        let extendedStart = day(2026, 4, 1)
        let plan = PausePlan(subscriptionIds: [a, b], startedOn: extendedStart, savingsSince: origin)
        let state = PausePlanStore.SyncState(plan: plan, updatedAt: extendedStart, endedAt: nil, pendingSync: false)

        let encoded = try JSONEncoder().encode(PausePlanRecord(from: state, userId: UUID()))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNotNil(json["savings_since"], "PausePlanRecord must serialize savings_since for multi-device sync")

        let decoded = try XCTUnwrap(JSONDecoder().decode(PausePlanRecord.self, from: encoded).toSyncState())
        XCTAssertEqual(decoded.plan?.startedOn, extendedStart)
        XCTAssertEqual(decoded.plan?.savingsSince, origin)
        XCTAssertEqual(decoded.plan?.effectiveSavingsStart, origin)
        XCTAssertEqual(PausePlanSync.resolve(local: nil, remote: decoded), .adoptRemote(decoded))
    }
}
