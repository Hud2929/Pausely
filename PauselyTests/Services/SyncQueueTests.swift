import XCTest
@testable import Pausely

/// The queue every change to a subscription goes through on its way to the account. Each test names a
/// way a change used to be lost, or could be: it drives the real queue against a stand-in for the
/// account that can be offline, refuse, and have something happen on the phone mid-send.
@MainActor
final class SyncQueueTests: XCTestCase {

    private var account: FakeSyncTransport!
    /// This iPhone's list: what the queue reads when it sends.
    private var list: [Subscription] = []
    /// What the queue has written to disk.
    private var saved = Data()
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var queue: SyncQueue!

    override func setUp() async throws {
        account = FakeSyncTransport()
        account.canSend = true
        list = []
        saved = Data()
        queue = makeQueue()
    }

    private func makeQueue() -> SyncQueue {
        let queue = SyncQueue(transport: account, load: { self.saved }, store: { self.saved = $0 }, now: { self.clock })
        queue.currentCopy = { id in self.list.first { $0.id == id } }
        return queue
    }

    private func add(_ name: String, amount: Decimal = 10) -> Subscription {
        let sub = TestFactories.makeSubscription(name: name, amount: amount)
        list.append(sub)
        queue.noteAdded(sub.id)
        return sub
    }

    private func change(_ id: UUID, _ edit: (inout Subscription) -> Void) {
        let index = list.firstIndex { $0.id == id }!
        edit(&list[index])
        queue.noteChanged(id)
    }

    // MARK: One thing to send per subscription

    func testAnAddThenEditsIsStillOneAddCarryingTheLatestCopy() async {
        account.canSend = false
        let sub = add("Netflix")
        change(sub.id) { $0.amount = 12 }
        change(sub.id) { $0.status = .cancelled }
        XCTAssertEqual(queue.pending.map(\.kind), [.create])

        account.canSend = true
        await queue.drain()
        XCTAssertEqual(account.calls, ["create Netflix"])
        XCTAssertEqual(account.rows[sub.id]?.amount, 12)
        XCTAssertEqual(account.rows[sub.id]?.status, .cancelled)
        XCTAssertTrue(queue.pending.isEmpty)
    }

    func testAnAddThenADeleteIsOneDelete() async {
        account.canSend = false
        let sub = add("Gone")
        list.removeAll()
        queue.noteDeleted(sub.id)
        XCTAssertEqual(queue.pending.map(\.kind), [.delete])

        account.canSend = true
        await queue.drain()
        XCTAssertEqual(account.calls, ["delete"])
        XCTAssertTrue(account.rows.isEmpty)
    }

    func testAnEditToWhatTheAccountAlreadyHasIsAnEdit() async {
        let sub = add("Netflix")
        await queue.drain()
        change(sub.id) { $0.amount = 12 }
        XCTAssertEqual(queue.pending.map(\.kind), [.update])
        await queue.drain()
        XCTAssertEqual(account.calls, ["create Netflix", "update Netflix"])
        XCTAssertEqual(account.rows[sub.id]?.amount, 12)
    }

    /// An edit never brings back a row another device deleted; the next fetch takes it off this one.
    func testAnEditDoesNotPutBackWhatAnotherDeviceDeleted() async {
        let sub = TestFactories.makeSubscription(name: "Deleted on iPad")
        list = [sub]
        queue.noteChanged(sub.id)
        await queue.drain()
        XCTAssertEqual(account.calls, ["update Deleted on iPad"])
        XCTAssertTrue(account.rows.isEmpty)
        XCTAssertTrue(queue.pending.isEmpty)
    }

    // MARK: Changes made while sending

    /// The old queue replaced itself with "what failed" when a pass ended, so anything noted during
    /// the pass was gone.
    func testAnAddMadeWhileAnotherIsBeingSentIsSentToo() async {
        let first = add("First")
        var second: Subscription?
        account.whileSending = { second = self.add("Second") }
        await queue.drain()
        XCTAssertEqual(Set(account.rows.keys), [first.id, second!.id])
        XCTAssertTrue(queue.pending.isEmpty)
    }

    func testAnEditMadeWhileItsAddIsBeingSentIsSentAfterIt() async {
        let sub = add("Netflix", amount: 10)
        account.whileSending = { self.change(sub.id) { $0.amount = 12 } }
        await queue.drain()
        XCTAssertEqual(account.calls, ["create Netflix", "update Netflix"])
        XCTAssertEqual(account.rows[sub.id]?.amount, 12)
        XCTAssertTrue(queue.pending.isEmpty)
    }

    func testADeleteMadeWhileItsAddIsBeingSentRemovesIt() async {
        let sub = add("Netflix")
        account.whileSending = {
            self.list.removeAll()
            self.queue.noteDeleted(sub.id)
        }
        await queue.drain()
        XCTAssertEqual(account.calls, ["create Netflix", "delete"])
        XCTAssertTrue(account.rows.isEmpty)
        XCTAssertTrue(queue.pending.isEmpty)
    }

    /// Someone else signs in while a pass is running: the last person's remaining changes are
    /// forgotten on the spot and none of them is sent after that.
    func testWhatIsForgottenMidPassIsNotSent() async {
        _ = add("First")
        _ = add("Second")
        _ = add("Third")
        account.whileSending = { self.queue.removeAll() }
        await queue.drain()
        XCTAssertEqual(account.calls, ["create First"])
        XCTAssertTrue(queue.pending.isEmpty)
    }

    /// An edit made while an earlier subscription is being sent goes up once, not twice.
    func testAnEditToOneStillWaitingItsTurnIsSentOnce() async {
        _ = add("First")
        let second = add("Second", amount: 10)
        account.whileSending = { self.change(second.id) { $0.amount = 12 } }
        await queue.drain()
        XCTAssertEqual(account.calls, ["create First", "create Second"])
        XCTAssertEqual(account.rows[second.id]?.amount, 12)
    }

    /// Whoever asks while a pass is running gets their answer when everything has been tried, and
    /// nothing is sent twice.
    func testAskingAgainWhileSendingWaitsForTheSamePass() async {
        let first = add("First")
        var second: Subscription?
        var secondCaller: Task<[String], Never>?
        account.whileSending = {
            second = self.add("Second")
            secondCaller = Task { @MainActor in
                await self.queue.drain()
                return self.account.calls
            }
        }
        await queue.drain()
        let seenBySecondCaller = await secondCaller!.value
        XCTAssertEqual(seenBySecondCaller, ["create First", "create Second"])
        XCTAssertEqual(account.calls, ["create First", "create Second"])
        XCTAssertEqual(Set(account.rows.keys), [first.id, second!.id])
    }

    // MARK: Failures

    func testAFailedChangeIsKeptAndWaitsLongerEachTime() async {
        let sub = add("Netflix")
        account.failure = URLError(.notConnectedToInternet)

        await queue.drain()
        XCTAssertEqual(queue.pending.map(\.subscriptionId), [sub.id])
        XCTAssertEqual(queue.pending.first?.attempts, 1)
        XCTAssertEqual(queue.pending.first?.notBefore, clock.addingTimeInterval(2))

        await queue.drain()
        XCTAssertEqual(account.calls.count, 1, "not tried again before its wait is over")

        clock.addTimeInterval(3)
        await queue.drain()
        XCTAssertEqual(queue.pending.first?.attempts, 2)
        XCTAssertEqual(queue.pending.first?.notBefore, clock.addingTimeInterval(4))

        await queue.drain(force: true)
        XCTAssertEqual(queue.pending.first?.attempts, 3, "coming to the front or pulling to refresh tries now")

        account.failure = nil
        await queue.drain(force: true)
        XCTAssertEqual(account.rows[sub.id]?.name, "Netflix")
        XCTAssertTrue(queue.pending.isEmpty)
    }

    /// "It will sync when you're back online" has to be true without the person doing anything.
    func testComingBackOnlineSendsWhatFailedWithoutWaiting() async {
        let sub = add("Netflix")
        account.failure = URLError(.notConnectedToInternet)
        await queue.drain()
        await queue.networkChanged(isOnline: false)
        account.failure = nil

        await queue.networkChanged(isOnline: true)
        XCTAssertEqual(account.rows[sub.id]?.name, "Netflix")
        XCTAssertTrue(queue.pending.isEmpty)

        _ = add("Later")
        account.failure = URLError(.timedOut)
        await queue.drain()
        let callsSoFar = account.calls.count
        await queue.networkChanged(isOnline: true)
        XCTAssertEqual(account.calls.count, callsSoFar, "still online is not coming back online")
    }

    func testANewChangeIsTriedAtOnceEvenAfterFailures() async {
        let sub = add("Netflix")
        account.failure = URLError(.timedOut)
        await queue.drain()
        account.failure = nil
        change(sub.id) { $0.amount = 12 }
        await queue.drain()
        XCTAssertEqual(account.rows[sub.id]?.amount, 12)
    }

    func testOneFailureDoesNotHoldUpTheOthers() async {
        let stuck = add("Stuck")
        account.failure = URLError(.timedOut)
        await queue.drain()
        account.failure = nil
        let fine = add("Fine")
        await queue.drain()
        XCTAssertEqual(Set(account.rows.keys), [fine.id])
        XCTAssertEqual(queue.pending.map(\.subscriptionId), [stuck.id])
    }

    func testARefusalIsToldApartFromBeingOffline() async {
        struct Refused: Error {}
        _ = add("Netflix")
        account.failure = URLError(.networkConnectionLost)
        await queue.drain()
        XCTAssertEqual(queue.pending.first?.refused, false)
        account.failure = Refused()
        await queue.drain(force: true)
        XCTAssertEqual(queue.pending.first?.refused, true)
    }

    func testWaitsDoubleUpToFiveMinutes() {
        XCTAssertEqual([1, 2, 3, 4, 8, 9, 50].map(SyncQueue.wait(afterAttempt:)), [2, 4, 8, 16, 256, 300, 300])
    }

    // MARK: Nothing is sent that shouldn't be, and nothing is lost meanwhile

    func testSignedOutNothingIsSentAndEverythingIsStillThereAfterARelaunch() async {
        account.canSend = false
        let added = add("Netflix")
        let removed = UUID()
        queue.noteDeleted(removed)
        await queue.drain(force: true)
        XCTAssertTrue(account.calls.isEmpty)

        let relaunched = makeQueue()
        XCTAssertEqual(relaunched.pendingKinds, [added.id: .create, removed: .delete])
        account.canSend = true
        await relaunched.drain()
        XCTAssertEqual(account.calls, ["create Netflix", "delete"])
    }

    /// Before the list is loaded an empty list means nothing: treating it as "deleted here" would
    /// throw away every waiting add.
    func testNothingIsSentUntilTheListIsLoaded() async {
        let sub = add("Netflix")
        queue.currentCopy = nil
        await queue.drain(force: true)
        XCTAssertTrue(account.calls.isEmpty)
        XCTAssertEqual(queue.pending.map(\.subscriptionId), [sub.id])
    }

    // MARK: A queue saved by an earlier version

    func testAQueueSavedByAnEarlierVersionIsKeptAsOneIntentEach() throws {
        let added = UUID(), edited = UUID(), deleted = UUID(), addedThenPaused = UUID()
        func entry(_ type: String, _ id: UUID) -> [String: Any] {
            ["id": UUID().uuidString, "type": type, "subscriptionId": id.uuidString, "payload": "e30=",
             "retryCount": 3, "createdAt": 784_000_000.0]
        }
        saved = try JSONSerialization.data(withJSONObject: [
            entry("create", added), entry("update", edited), entry("updateStatus", edited),
            entry("update", deleted), entry("delete", deleted),
            entry("create", addedThenPaused), entry("pause", addedThenPaused), entry("resume", addedThenPaused)
        ])
        let upgraded = makeQueue()
        XCTAssertEqual(upgraded.pending.map(\.subscriptionId), [added, edited, deleted, addedThenPaused])
        XCTAssertEqual(upgraded.pending.map(\.kind), [.create, .update, .delete, .create])
        XCTAssertEqual(upgraded.pending.map(\.attempts), [0, 0, 0, 0])
    }

    func testUnreadableSavedDataIsAnEmptyQueueNotACrash() {
        saved = Data("not a queue".utf8)
        XCTAssertTrue(makeQueue().pending.isEmpty)
    }

    // MARK: What changed since a fetch began

    /// A list fetched while changes were being made may be older than they are, even when they have
    /// already been sent: the merge is told about them.
    func testChangesSinceAMarkAreReportedEvenOnceSent() async {
        let before = add("Before")
        await queue.drain()
        let mark = queue.sequence

        let during = add("During")
        change(during.id) { $0.amount = 12 }
        change(before.id) { $0.amount = 12 }
        let removed = add("Removed")
        list.removeAll { $0.id == removed.id }
        queue.noteDeleted(removed.id)
        await queue.drain()

        XCTAssertTrue(queue.pending.isEmpty)
        XCTAssertEqual(queue.changes(since: mark), [during.id: .create, before.id: .update, removed.id: .delete])
        XCTAssertEqual(queue.changes(since: queue.sequence), [:])
    }
}
