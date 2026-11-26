import Foundation
import Network
import Supabase
import os.log

/// What one subscription still owes the server.
///
/// There is at most one of these per subscription. An edit after an add that hasn't been sent is still
/// one add; a delete after it is one delete. Nothing is stored here but the id: what is sent is always
/// the copy on this iPhone at the moment of sending, so a stale one can never go up.
struct SyncIntent: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        /// Made on this iPhone; the server may never have seen it.
        case create
        /// Changed on this iPhone. If another device deleted it meanwhile, the delete stands.
        case update
        case delete
    }

    let subscriptionId: UUID
    var kind: Kind
    /// Goes up by one with every change. A send clears the intent only if this is still the number
    /// it started with, so a change made while the send was in flight is sent too.
    var revision = 1
    var attempts = 0
    /// The server answered and said no (as opposed to not being reachable).
    var refused = false
    /// After a failure: when the next try is due, unless the person or the system asks sooner.
    var notBefore: Date?

    var id: UUID { subscriptionId }
}

enum SyncFailure: Error {
    /// Nobody is signed in, so there is no account to send to or fetch from.
    case signedOut
}

/// Where queued changes are sent. The app uses Supabase; tests use a stand-in that can fail and stall.
@MainActor
protocol SyncTransport {
    /// False when nobody is signed in or cloud writes are switched off: nothing is sent, everything is kept.
    var canSend: Bool { get }
    /// Adds the row, or brings it up to date if an earlier try got through without its answer arriving.
    func create(_ subscription: Subscription) async throws
    /// Changes the row. A row that is no longer there was deleted on another device; that is not an error.
    func update(_ subscription: Subscription) async throws
    func delete(id: UUID) async throws
}

/// Every change to a subscription goes through here on its way to the server.
///
/// The list on this iPhone is changed first, then the change is noted here and the queue is drained.
/// It is also drained when the app comes to the front and when the network comes back, which is what
/// makes "It will sync when you're back online" true.
@MainActor
final class SyncQueue: ObservableObject {
    static let shared = SyncQueue(transport: SupabaseSyncTransport(),
                                  load: { AppSettings.shared.syncQueueOperations },
                                  store: { AppSettings.shared.syncQueueOperations = $0 },
                                  unattended: true)

    @Published private(set) var pending: [SyncIntent] = []

    /// The subscription as it is on this iPhone now. Set by `SubscriptionStore` once its list is
    /// loaded; until then nothing is sent, so an unloaded list can't be mistaken for an empty one.
    var currentCopy: ((UUID) -> Subscription?)?

    /// Invoked when the device regains connectivity before draining the queue, allowing first-sync
    /// reconciliation to recover automatically if the initial post-sign-in fetch failed offline.
    var onNetworkRestored: (() async -> Void)?

    private let transport: SyncTransport
    private let store: (Data) -> Void
    private let now: () -> Date
    private var inFlight: Task<Void, Never>?
    private var drainAgain = false
    private var retryFailuresAgain = false
    private let unattended: Bool
    private var monitor: NWPathMonitor?
    private var wasOnline = true
    private var retry: Task<Void, Never>?

    /// Counts every change noted since launch (see `changes(since:)`).
    private(set) var sequence = 0
    private var noted: [UUID: (kind: SyncIntent.Kind, at: Int, addedAt: Int?)] = [:]

    /// - Parameter unattended: also send without being asked, when the network comes back and when a
    ///   failed change is due for another try. The app's queue does; a test's queue is driven by the test.
    init(transport: SyncTransport, load: () -> Data, store: @escaping (Data) -> Void,
         now: @escaping () -> Date = Date.init, unattended: Bool = false) {
        self.transport = transport
        self.store = store
        self.now = now
        self.unattended = unattended
        pending = Self.intents(from: load())
        if unattended { watchNetwork() }
    }

    /// What is waiting, by subscription.
    var pendingKinds: [UUID: SyncIntent.Kind] {
        Dictionary(pending.map { ($0.subscriptionId, $0.kind) }, uniquingKeysWith: { _, last in last })
    }

    func intent(for id: UUID) -> SyncIntent? { pending.first { $0.subscriptionId == id } }

    /// Changes noted after `mark` (a value of `sequence`), sent or not. A list fetched from the server
    /// while they were being made may be older than they are, so the merge treats them as still waiting.
    func changes(since mark: Int) -> [UUID: SyncIntent.Kind] {
        noted.filter { $0.value.at > mark }.mapValues { change in
            // Added after the mark and changed since: the fetched list may not have it at all.
            if change.kind == .update, let addedAt = change.addedAt, addedAt > mark { return .create }
            return change.kind
        }
    }

    // MARK: - Noting a change

    /// A subscription was made on this iPhone.
    func noteAdded(_ id: UUID) { note(id, .create) }

    /// A subscription was changed on this iPhone.
    func noteChanged(_ id: UUID) { note(id, .update) }

    /// A subscription was removed on this iPhone.
    func noteDeleted(_ id: UUID) { note(id, .delete) }

    private func note(_ id: UUID, _ kind: SyncIntent.Kind) {
        sequence += 1
        let addedAt = kind == .create ? sequence : (kind == .update ? noted[id]?.addedAt : nil)
        noted[id] = (kind, sequence, addedAt)
        if let index = pending.firstIndex(where: { $0.subscriptionId == id }) {
            // A change to something the server has never seen is still "add it", with the change in it.
            let stillNew = pending[index].kind == .create && kind == .update
            pending[index].kind = stillNew ? .create : kind
            pending[index].revision += 1
            pending[index].attempts = 0
            pending[index].refused = false
            pending[index].notBefore = nil
        } else {
            pending.append(SyncIntent(subscriptionId: id, kind: kind))
        }
        // A pass that is already sending works from the list it started with: have it go round again.
        if inFlight != nil { drainAgain = true }
        persist()
    }

    // MARK: - Sending

    /// Sends what is waiting, oldest first, and returns when every change noted before the call has
    /// been tried.
    /// - Parameter force: also retry what failed recently. True when the person pulls to refresh, the
    ///   app comes to the front or the network comes back; false after an ordinary change.
    func drain(force: Bool = false) async {
        guard transport.canSend, currentCopy != nil else { return }
        if let inFlight {
            // Already sending. Whatever was noted meanwhile goes in the pass that follows.
            drainAgain = true
            retryFailuresAgain = retryFailuresAgain || force
            await inFlight.value
            return
        }
        let task = Task { @MainActor in
            await self.sendAll(retryingFailures: force)
            self.inFlight = nil
        }
        inFlight = task
        await task.value
    }

    private func sendAll(retryingFailures force: Bool) async {
        var retryFailures = force
        repeat {
            drainAgain = false
            retryFailures = retryFailures || retryFailuresAgain
            retryFailuresAgain = false
            for id in pending.map(\.subscriptionId) {
                // As it is now, not as it was when the pass began: it may have changed, been sent,
                // or been forgotten (another account took over the phone) in the meantime.
                guard let intent = intent(for: id) else { continue }
                if !retryFailures, let due = intent.notBefore, due > now() { continue }
                do {
                    switch intent.kind {
                    case .delete:
                        try await transport.delete(id: intent.subscriptionId)
                    case .create:
                        // No longer on this iPhone, and no delete was noted: a fetch found that another
                        // device had deleted it. Nothing is left to send.
                        if let copy = currentCopy?(intent.subscriptionId) { try await transport.create(copy) }
                    case .update:
                        if let copy = currentCopy?(intent.subscriptionId) { try await transport.update(copy) }
                    }
                    finish(intent)
                } catch {
                    fail(intent, error)
                }
            }
            retryFailures = false
        } while drainAgain
        persist()
        retryWhenDue()
    }

    /// While the app is open, what failed is tried again when its wait is over.
    private func retryWhenDue() {
        retry?.cancel()
        guard unattended, let due = pending.compactMap(\.notBefore).min() else { return }
        let wait = max(1, due.timeIntervalSince(now()))
        retry = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.drain()
        }
    }

    private func finish(_ sent: SyncIntent) {
        guard let index = pending.firstIndex(where: { $0.subscriptionId == sent.subscriptionId }) else { return }
        if pending[index].revision == sent.revision {
            pending.remove(at: index)
            return
        }
        // Changed while it was being sent. The server has the row now, so what's left is a change to it.
        if sent.kind == .create, pending[index].kind == .create { pending[index].kind = .update }
        drainAgain = true
    }

    private func fail(_ sent: SyncIntent, _ error: Error) {
        guard let index = pending.firstIndex(where: { $0.subscriptionId == sent.subscriptionId }) else { return }
        if pending[index].revision != sent.revision {
            // The user edited or deleted this subscription while the older request was in flight.
            // Retry the newer revision immediately instead of stamping backoff/refused onto it.
            drainAgain = true
            return
        }
        pending[index].attempts += 1
        pending[index].refused = !Self.isUnreachable(error)
        pending[index].notBefore = now().addingTimeInterval(Self.wait(afterAttempt: pending[index].attempts))
        os_log("A queued change failed (attempt %{public}d): %{public}@", log: .default, type: .error,
               pending[index].attempts, String(describing: type(of: error)))
    }

    /// 2, 4, 8 ... seconds after each failure in a row, never more than five minutes.
    static func wait(afterAttempt attempt: Int) -> TimeInterval {
        min(300, pow(2, Double(max(1, min(attempt, 9)))))
    }

    /// True when the request never got an answer (no network, timed out), as opposed to being refused.
    static func isUnreachable(_ error: Error) -> Bool {
        error is URLError || (error as NSError).domain == NSURLErrorDomain
    }

    /// Forgets every queued change (account deletion, or someone else signing in on this iPhone).
    func removeAll() {
        pending = []
        noted = [:]
        persist()
    }

    /// Drops a queued `.create` intent when a local guest item merged into an existing server row.
    func dropPendingCreate(_ id: UUID) {
        let before = pending.count
        pending.removeAll { $0.subscriptionId == id && $0.kind == .create }
        if noted[id]?.kind == .create { noted.removeValue(forKey: id) }
        if pending.count != before { persist() }
    }

    // MARK: - When the network comes back

    private func watchNetwork() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in await self?.networkChanged(isOnline: isOnline) }
        }
        monitor.start(queue: DispatchQueue(label: "pausely.sync.network"))
        self.monitor = monitor
    }

    /// Coming back online reconciles pending first-sync if needed, then sends what is waiting.
    func networkChanged(isOnline: Bool) async {
        let cameBack = isOnline && !wasOnline
        wasOnline = isOnline
        if cameBack {
            await onNetworkRestored?()
            await drain(force: true)
        }
    }

    // MARK: - Keeping the queue between launches

    private struct Saved: Codable {
        var version = 2
        var intents: [SyncIntent]
    }

    /// What versions before 2026-11 kept: one entry per attempted write, with its payload.
    private struct EarlierOperation: Decodable {
        let type: String
        let subscriptionId: UUID
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Saved(intents: pending)) else { return }
        store(data)
    }

    /// Reads the saved queue, including one written by an earlier version: its entries for one
    /// subscription become a single "add it", "send it as it is now" or "remove it".
    static func intents(from data: Data) -> [SyncIntent] {
        guard !data.isEmpty else { return [] }
        if let saved = try? JSONDecoder().decode(Saved.self, from: data) { return saved.intents }
        guard let earlier = try? JSONDecoder().decode([EarlierOperation].self, from: data) else { return [] }
        var intents: [SyncIntent] = []
        for operation in earlier {
            let kind: SyncIntent.Kind = switch operation.type {
            case "delete": .delete
            case "create": .create
            default: .update
            }
            if let index = intents.firstIndex(where: { $0.subscriptionId == operation.subscriptionId }) {
                let stillNew = intents[index].kind == .create && kind == .update
                intents[index].kind = stillNew ? .create : kind
            } else {
                intents.append(SyncIntent(subscriptionId: operation.subscriptionId, kind: kind))
            }
        }
        return intents
    }
}

/// The real thing: the signed-in person's rows in the `subscriptions` table.
@MainActor
struct SupabaseSyncTransport: SyncTransport {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Not while signed out, and not while what's on this iPhone was left by a different account:
    /// one person's unsent changes must never be sent into another person's account.
    var canSend: Bool {
        guard SubscriptionStore.cloudSyncEnabled, let user = client.auth.currentSession?.user.id else { return false }
        return LocalUserData.belongs(to: user.uuidString) && !SubscriptionStore.isFirstSync(for: user.uuidString)
    }

    private func validSession() async throws -> Session {
        guard client.auth.currentSession != nil else { throw SyncFailure.signedOut }
        let session = try await client.auth.session
        guard !session.isExpired else { throw SyncFailure.signedOut }
        return session
    }

    func create(_ subscription: Subscription) async throws {
        let session = try await validSession()
        var record = SubscriptionRecord(from: subscription)
        record.user_id = session.user.id
        _ = try await client.from("subscriptions").upsert(record).execute()
    }

    /// The whole row, without its owner (an update never changes who it belongs to). Dates that were
    /// cleared go up as null, so a resume or a removed renewal date clears on the server too.
    func update(_ subscription: Subscription) async throws {
        _ = try await validSession()
        _ = try await client.from("subscriptions")
            .update(SubscriptionRecord(from: subscription))
            .eq("id", value: subscription.id)
            .execute()
    }

    func delete(id: UUID) async throws {
        _ = try await validSession()
        try await client.from("subscriptions").delete().eq("id", value: id).execute()
    }
}
