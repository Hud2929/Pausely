import Foundation

/// The customer's Pause Plan, saved on the device next to the event log.
@MainActor
final class PausePlanStore: ObservableObject {
    static let shared = PausePlanStore()

    /// Sync metadata stored alongside the plan so ending a plan leaves a timestamped tombstone
    /// (`endedAt`) that beats stale active copies on other devices instead of resurrecting.
    struct SyncState: Codable, Equatable {
        var plan: PausePlan?
        var updatedAt: Date
        var endedAt: Date?
        var pendingSync: Bool

        init(plan: PausePlan?, updatedAt: Date = Date(), endedAt: Date? = nil, pendingSync: Bool = false) {
            self.plan = plan.map { PausePlan(subscriptionIds: $0.subscriptionIds, startedOn: PausePlanStore.wholeSecond($0.startedOn)) }
            self.updatedAt = PausePlanStore.wholeSecond(updatedAt)
            self.endedAt = endedAt.map(PausePlanStore.wholeSecond)
            self.pendingSync = pendingSync
        }

        private enum CodingKeys: String, CodingKey {
            case plan, updatedAt, endedAt, pendingSync
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if c.contains(.updatedAt) {
                plan = try c.decodeIfPresent(PausePlan.self, forKey: .plan)
                updatedAt = try c.decode(Date.self, forKey: .updatedAt)
                endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
                pendingSync = try c.decodeIfPresent(Bool.self, forKey: .pendingSync) ?? false
            } else {
                // Backwards compatibility with files written before SyncState existed.
                let legacy = try PausePlan(from: decoder)
                plan = legacy
                updatedAt = legacy.startedOn
                endedAt = nil
                pendingSync = false
            }
        }
    }

    /// Truncates timestamps to whole seconds so local files match ISO-8601 Supabase wire precision
    /// and never enter a fractional-second LWW re-push loop.
    nonisolated static func wholeSecond(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    @Published private(set) var plan: PausePlan?
    private(set) var syncState: SyncState?
    private let fileURL: URL
    /// False while a saved plan exists but can't be read (a background launch on a locked phone);
    /// nothing is written over it until it has been.
    private(set) var planIsLoaded = true

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        load()
    }

    /// Reads the plan if an earlier attempt couldn't. Called when the app comes to the foreground.
    func loadIfNeeded() {
        if !planIsLoaded { load() }
    }

    private func load() {
        switch DeviceFile.load(SyncState.self, from: fileURL) {
        case .value(let saved):
            syncState = saved
            plan = saved.plan
            planIsLoaded = true
            DeviceFile.relaxProtection(of: fileURL)
        case .missing:
            syncState = nil
            plan = nil
            planIsLoaded = true
        case .unreadable:
            planIsLoaded = false
        }
    }

    /// The plan with removed subscriptions dropped; nil once fewer than two are left.
    var activePlan: PausePlan? {
        guard var plan else { return nil }
        let existing = Set(SubscriptionStore.shared.subscriptions.map(\.id))
        plan.subscriptionIds = plan.subscriptionIds.filter(existing.contains)
        return plan.subscriptionIds.count >= 2 ? plan : nil
    }

    func contains(_ subscriptionId: UUID) -> Bool {
        activePlan?.subscriptionIds.contains(subscriptionId) == true
    }

    func start(order: [UUID], now: Date = Date()) async {
        guard order.count >= 2 else { return }
        let stamp = Self.wholeSecond(now)
        let created = PausePlan(subscriptionIds: order, startedOn: stamp)
        let state = SyncState(plan: created, updatedAt: stamp, endedAt: nil, pendingSync: true)
        plan = created
        syncState = state
        save()
        await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions)
        if self === Self.shared {
            await PausePlanSync.shared.push(state)
        }
    }

    func end(now: Date = Date()) async {
        let stamp = Self.wholeSecond(now)
        let state = SyncState(plan: nil, updatedAt: stamp, endedAt: stamp, pendingSync: true)
        plan = nil
        syncState = state
        save()
        await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions)
        if self === Self.shared {
            await PausePlanSync.shared.push(state)
        }
    }

    /// Applies a Pause Plan state (active or ended tombstone) pulled from the account without pushing back.
    func applySynced(_ synced: SyncState) {
        let normalized = SyncState(plan: synced.plan, updatedAt: synced.updatedAt, endedAt: synced.endedAt, pendingSync: false)
        let changed = plan != normalized.plan
        syncState = normalized
        plan = normalized.plan
        save()
        if changed {
            Task { await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions) }
        }
    }

    /// Clears the pending flag once a local change has been confirmed by the server.
    func markSynced(updatedAt: Date) {
        let stamp = Self.wholeSecond(updatedAt)
        guard var state = syncState, Self.wholeSecond(state.updatedAt) == stamp, state.pendingSync else { return }
        state.pendingSync = false
        syncState = state
        save()
    }

    /// "I started it": the subscription is on again from `date` (`SubscriptionStore.startAgain`).
    func markStarted(_ subscription: Subscription, on date: Date = Date(), calendar: Calendar = .billing) async {
        await SubscriptionStore.shared.startAgain(id: subscription.id, on: date, calendar: calendar)
    }

    /// Wipes the plan (account deletion).
    func removeAll() {
        plan = nil
        syncState = nil
        save()
    }

    // MARK: - Persistence

    private func save() {
        // A plan the person starts or ends by hand replaces whatever was saved, readable or not.
        planIsLoaded = true
        do {
            if let syncState {
                try DeviceFile.save(syncState, to: fileURL)
            } else if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            PauselyLogger.error("Pause Plan save failed: \(error.localizedDescription)", category: "lifecycle")
        }
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Pausely", isDirectory: true).appendingPathComponent("pause_plan.json")
    }
}
