import XCTest
@testable import Pausely

/// The event history is the only source of the Savings Receipt, and a notification's "Keep it" button
/// runs while the phone is locked, when the file may not be readable. These tests hold the rule that a
/// history that couldn't be read is never written over.
@MainActor
final class DeviceFileTests: XCTestCase {

    private var folder: URL!
    private var file: URL { folder.appendingPathComponent("lifecycle_events.json") }

    override func setUp() {
        super.setUp()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("device-file-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        setReadable(true)
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    /// What a locked phone does to a protected file: it is there, and reading it fails.
    private func setReadable(_ readable: Bool) {
        try? FileManager.default.setAttributes([.posixPermissions: readable ? 0o644 : 0o000], ofItemAtPath: file.path)
    }

    private func savedKinds() throws -> [LifecycleEvent.Kind] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([LifecycleEvent].self, from: Data(contentsOf: file)).map(\.kind)
    }

    private func historyOfThree() -> Subscription {
        let netflix = TestFactories.makeSubscription(name: "Netflix", amount: 15.49)
        let log = LifecycleEventLog(fileURL: file)
        log.record(.added, for: netflix)
        log.record(.renewed, for: netflix)
        log.record(.cancelled, for: netflix)
        return netflix
    }

    func testAnUnreadableHistoryIsNeverWrittenOver() throws {
        let netflix = historyOfThree()
        setReadable(false)

        let locked = LifecycleEventLog(fileURL: file)
        XCTAssertFalse(locked.historyIsLoaded)
        locked.record(.kept, for: netflix)
        XCTAssertEqual(locked.events.map(\.kind), [.kept], "what just happened is known in memory")

        setReadable(true)
        XCTAssertEqual(try savedKinds(), [.added, .renewed, .cancelled], "the saved history was not replaced by one event")
    }

    func testWhatHappenedWhileLockedJoinsTheHistoryOnceItCanBeRead() throws {
        let netflix = historyOfThree()
        setReadable(false)
        let locked = LifecycleEventLog(fileURL: file)
        locked.record(.kept, for: netflix)

        setReadable(true)
        locked.loadIfNeeded()

        XCTAssertTrue(locked.historyIsLoaded)
        XCTAssertEqual(locked.events.map(\.kind), [.added, .renewed, .cancelled, .kept])
        XCTAssertEqual(try savedKinds(), [.added, .renewed, .cancelled, .kept])
    }

    func testTheNextEventAfterUnlockAlsoRecoversTheHistory() throws {
        let netflix = historyOfThree()
        setReadable(false)
        let locked = LifecycleEventLog(fileURL: file)
        locked.record(.kept, for: netflix)

        setReadable(true)
        locked.record(.reactivated, for: netflix)

        XCTAssertEqual(try savedKinds(), [.added, .renewed, .cancelled, .kept, .reactivated])
    }

    func testNoFileYetStartsEmptyAndSaves() throws {
        let log = LifecycleEventLog(fileURL: file)
        XCTAssertTrue(log.historyIsLoaded)
        XCTAssertEqual(log.events.count, 0)
        log.record(.added, for: TestFactories.makeSubscription(name: "Spotify"))
        XCTAssertEqual(try savedKinds(), [.added])
    }

    func testAFileThisVersionCannotDecodeIsSetAsideNotDestroyed() throws {
        try Data("not a history".utf8).write(to: file)

        let log = LifecycleEventLog(fileURL: file)
        XCTAssertTrue(log.historyIsLoaded)
        XCTAssertEqual(log.events.count, 0)
        log.record(.added, for: TestFactories.makeSubscription(name: "Spotify"))

        XCTAssertEqual(try savedKinds(), [.added])
        let kept = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.contains("set-aside") }
        XCTAssertEqual(kept.count, 1, "the old file is still on the device")
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent(kept[0]), encoding: .utf8), "not a history")
    }

    func testAnUnreadablePausePlanIsNotReportedAsNoPlan() throws {
        let planFile = folder.appendingPathComponent("pause_plan.json")
        try DeviceFile.save(PausePlan(subscriptionIds: [UUID(), UUID()], startedOn: Date()), to: planFile)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: planFile.path)

        let locked = PausePlanStore(fileURL: planFile)
        XCTAssertNil(locked.plan)

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: planFile.path)
        locked.loadIfNeeded()
        XCTAssertEqual(locked.plan?.subscriptionIds.count, 2, "the plan is back once the file can be read")
    }
}
