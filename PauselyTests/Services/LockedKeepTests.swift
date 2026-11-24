import XCTest
import UserNotifications
@testable import Pausely

/// "Keep it" pressed on a reminder before the phone's first unlock after a restart used to be lost:
/// that launch ended before the button reached the app, so the charge was asked about again and its
/// remaining reminders still went off. The press is written down now, and kept at the next launch
/// with the phone unlocked. (The simulator has no data protection, so the locked launch itself is a
/// device check; what it writes and what is done with it are tested here.)
@MainActor
final class LockedKeepTests: XCTestCase {

    private var sandbox: StoreSandbox!
    private var file: URL!
    private var realSignedIn: (() -> Bool)!
    /// In whole seconds, as the file keeps it.
    private let now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))

    override func setUp() async throws {
        sandbox = StoreSandbox()
        file = FileManager.default.temporaryDirectory.appendingPathComponent("locked-keeps-\(UUID().uuidString).json")
        realSignedIn = VerdictCenter.shared.isSignedIn
        VerdictCenter.shared.isSignedIn = { true }
    }

    override func tearDown() async throws {
        VerdictCenter.shared.isSignedIn = realSignedIn
        try? FileManager.default.removeItem(at: file)
        await sandbox.restore()
    }

    /// A monthly subscription that charges in two days, in the list, and the day stamped on its reminder.
    private func chargingSoon() -> (Subscription, String) {
        let sub = TestFactories.makeSubscription(nextBillingDate: Calendar.billing.date(byAdding: .day, value: 2, to: now))
        SubscriptionStore.shared.subscriptions = [sub]
        let charge = RenewalDecisions.upcomingCharge(for: sub, now: now)!
        return (sub, ReminderPlanner.dayStamp(charge.date, .billing))
    }

    private func kept(_ id: UUID) -> [LifecycleEvent] {
        LifecycleEventLog.shared.events.filter { $0.kind == .kept && $0.subscriptionId == id }
    }

    func testOnlyKeepItOnAReminderIsWrittenDown() {
        let id = UUID()
        let info: [AnyHashable: Any] = ["subscription_id": id.uuidString, "renewal_date": "2026-12-01"]
        XCTAssertEqual(LockedKeeps.press(action: ReminderActions.keep, userInfo: info, at: now),
                       LockedKeeps.Press(subscriptionId: id, renewalDay: "2026-12-01", pressedAt: now))
        XCTAssertNil(LockedKeeps.press(action: ReminderActions.review, userInfo: info, at: now), "Review opens the app")
        XCTAssertNil(LockedKeeps.press(action: UNNotificationDefaultActionIdentifier, userInfo: info, at: now), "a tap opens the app")
        XCTAssertNil(LockedKeeps.press(action: ReminderActions.keep, userInfo: ["renewal_date": "2026-12-01"], at: now),
                     "a reminder without a subscription")
    }

    /// "Keep it" on one reminder takes away the others about the same charge, read from their names,
    /// and leaves every other reminder (another charge, another subscription, the refill notice).
    func testTheChargesOtherRemindersAreFoundByName() {
        let id = UUID()
        let other = UUID()
        let press = LockedKeeps.Press(subscriptionId: id, renewalDay: "2026-12-01", pressedAt: now)
        let prefix = ReminderPlanner.identifierPrefix
        let names = ["\(prefix)renewal.\(id.uuidString).2026-12-01", "\(prefix)dayOf.\(id.uuidString).2026-12-01",
                     "\(prefix)renewal.\(id.uuidString).2027-01-01", "\(prefix)renewal.\(other.uuidString).2026-12-01",
                     ReminderPlanner.refillIdentifier, "someone-else.\(id.uuidString).2026-12-01"]
        XCTAssertEqual(LockedKeeps.reminders(about: press, among: names), Array(names.prefix(2)))
        XCTAssertEqual(LockedKeeps.reminders(about: LockedKeeps.Press(subscriptionId: id, renewalDay: nil, pressedAt: now),
                                             among: names), [], "without the charge's day, nothing is guessed")
    }

    /// The names the scheduler gives reminders are the ones the locked launch looks for.
    func testReminderNamesEndWithTheSubscriptionAndTheChargesDay() {
        let (sub, stamp) = chargingSoon()
        let planned = ReminderPlanner.plan(for: [sub], now: now, preferences: ReminderScheduler.preferences, kept: [],
                                           pausePlan: nil)
        XCTAssertFalse(planned.isEmpty)
        let press = LockedKeeps.Press(subscriptionId: sub.id, renewalDay: stamp, pressedAt: now)
        let aboutThisCharge = planned.filter { ReminderPlanner.dayStamp($0.eventDate, .billing) == stamp }.map(\.identifier)
        XCTAssertFalse(aboutThisCharge.isEmpty)
        XCTAssertEqual(LockedKeeps.reminders(about: press, among: planned.map(\.identifier)), aboutThisCharge)
    }

    func testTwoKeepsOfOneChargeAreOneDecision() async {
        let (sub, stamp) = chargingSoon()
        LockedKeeps.note(LockedKeeps.Press(subscriptionId: sub.id, renewalDay: stamp, pressedAt: now.addingTimeInterval(-120)), at: file)
        LockedKeeps.note(LockedKeeps.Press(subscriptionId: sub.id, renewalDay: stamp, pressedAt: now.addingTimeInterval(-60)), at: file)
        await VerdictCenter.shared.keepPressedWhileLocked(from: file, now: now)
        XCTAssertEqual(kept(sub.id).count, 1)
    }

    func testPressesAreTakenInOrderAndOnlyOnce() {
        let first = LockedKeeps.Press(subscriptionId: UUID(), renewalDay: "2026-12-01", pressedAt: now.addingTimeInterval(-60))
        let second = LockedKeeps.Press(subscriptionId: UUID(), renewalDay: nil, pressedAt: now)
        LockedKeeps.note(first, at: file)
        LockedKeeps.note(second, at: file)
        XCTAssertEqual(LockedKeeps.take(from: file), [first, second])
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "the file goes once read")
        XCTAssertEqual(LockedKeeps.take(from: file), [], "and nothing is kept twice")
    }

    func testAKeepPressedWhileLockedIsRecordedForTheChargeItWasAbout() async {
        let (sub, stamp) = chargingSoon()
        let pressedAt = now.addingTimeInterval(-3600)
        LockedKeeps.note(LockedKeeps.Press(subscriptionId: sub.id, renewalDay: stamp, pressedAt: pressedAt), at: file)

        await VerdictCenter.shared.keepPressedWhileLocked(from: file, now: now)

        let events = kept(sub.id)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.date, pressedAt, "kept when the button was pressed")
        XCTAssertEqual(events.first?.renewalDate.map { ReminderPlanner.dayStamp($0, .billing) }, stamp,
                       "for the charge the reminder was about")
        XCTAssertTrue(RenewalDecisions.pending(in: [sub], events: LifecycleEventLog.shared.events, now: now).isEmpty,
                      "so it is no longer waiting for a decision")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testNothingIsTakenWhileNobodyIsSignedIn() async {
        let (sub, stamp) = chargingSoon()
        VerdictCenter.shared.isSignedIn = { false }
        LockedKeeps.note(LockedKeeps.Press(subscriptionId: sub.id, renewalDay: stamp, pressedAt: now), at: file)

        await VerdictCenter.shared.keepPressedWhileLocked(from: file, now: now)

        XCTAssertTrue(kept(sub.id).isEmpty)
        XCTAssertEqual(LockedKeeps.take(from: file).count, 1, "left for when the person is signed in")
    }

    func testAPressForASubscriptionNoLongerInTheListIsDropped() async {
        _ = chargingSoon()
        let gone = UUID()
        LockedKeeps.note(LockedKeeps.Press(subscriptionId: gone, renewalDay: nil, pressedAt: now), at: file)

        await VerdictCenter.shared.keepPressedWhileLocked(from: file, now: now)

        XCTAssertTrue(kept(gone).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    /// The press from an unlocked phone goes the same way: it had no test at all.
    func testKeepFromAReminderRecordsThatCharge() async {
        let (sub, stamp) = chargingSoon()
        await VerdictCenter.shared.keep(subscriptionId: sub.id, renewalDay: stamp, now: now)
        XCTAssertEqual(kept(sub.id).first?.renewalDate.map { ReminderPlanner.dayStamp($0, .billing) }, stamp)
    }
}
