import Foundation
import Supabase
import os.log

/// Row representation of `public.pause_plans` in Supabase (one active or tombstoned plan per account).
struct PausePlanRecord: Codable, Equatable {
    var user_id: UUID
    var subscription_ids: [UUID]
    var started_on: String
    var ended_at: String?
    var updated_at: String?

    init(from state: PausePlanStore.SyncState, userId: UUID) {
        self.user_id = userId
        if let plan = state.plan {
            self.subscription_ids = plan.subscriptionIds
            self.started_on = plan.startedOn.iso8601String
            self.ended_at = nil
        } else {
            let ended = state.endedAt ?? state.updatedAt
            self.subscription_ids = []
            self.started_on = ended.iso8601String
            self.ended_at = ended.iso8601String
        }
        self.updated_at = state.updatedAt.iso8601String
    }

    /// Always sends `ended_at` (including explicit `null`) so restarting a plan clears an earlier tombstone.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user_id, forKey: .user_id)
        try c.encode(subscription_ids, forKey: .subscription_ids)
        try c.encode(started_on, forKey: .started_on)
        try c.encode(ended_at, forKey: .ended_at)
        try c.encodeIfPresent(updated_at, forKey: .updated_at)
    }

    func toSyncState() -> PausePlanStore.SyncState? {
        let ended = ended_at?.iso8601Date
        let updated = updated_at?.iso8601Date ?? ended ?? started_on.iso8601Date
        guard let updated else { return nil }
        if let ended {
            return PausePlanStore.SyncState(plan: nil, updatedAt: updated, endedAt: ended, pendingSync: false)
        }
        guard subscription_ids.count >= 2, let started = started_on.iso8601Date else { return nil }
        return PausePlanStore.SyncState(
            plan: PausePlan(subscriptionIds: subscription_ids, startedOn: started),
            updatedAt: updated,
            endedAt: nil,
            pendingSync: false
        )
    }
}

/// Multi-device sync for the customer's Pause Plan (`public.pause_plans`).
@MainActor
final class PausePlanSync {
    static let shared = PausePlanSync()

    private init() {}

    enum Resolution: Equatable {
        case adoptRemote(PausePlanStore.SyncState)
        case pushLocal(PausePlanStore.SyncState)
        case inSync
    }

    /// Pure LWW reconciliation between local and cloud Pause Plan states, preserving tombstones
    /// (`endedAt != nil`) so ending a plan on one device never gets resurrected by another.
    nonisolated static func resolve(local: PausePlanStore.SyncState?, remote: PausePlanStore.SyncState?) -> Resolution {
        switch (local, remote) {
        case (nil, nil):
            return .inSync
        case (nil, let remoteState?):
            return .adoptRemote(remoteState)
        case (let localState?, nil):
            return (localState.plan != nil || localState.pendingSync) ? .pushLocal(localState) : .inSync
        case (let localState?, let remoteState?):
            let localUpdated = PausePlanStore.wholeSecond(localState.updatedAt)
            let remoteUpdated = PausePlanStore.wholeSecond(remoteState.updatedAt)
            let localPlan = localState.plan.map { PausePlan(subscriptionIds: $0.subscriptionIds, startedOn: PausePlanStore.wholeSecond($0.startedOn)) }
            let remotePlan = remoteState.plan.map { PausePlan(subscriptionIds: $0.subscriptionIds, startedOn: PausePlanStore.wholeSecond($0.startedOn)) }
            let localEnded = localState.endedAt.map(PausePlanStore.wholeSecond)
            let remoteEnded = remoteState.endedAt.map(PausePlanStore.wholeSecond)

            if localPlan == remotePlan && localEnded == remoteEnded {
                return (localState.pendingSync && localUpdated >= remoteUpdated) ? .pushLocal(localState) : .inSync
            }
            if remoteUpdated > localUpdated {
                return .adoptRemote(remoteState)
            }
            if localUpdated > remoteUpdated {
                return .pushLocal(localState)
            }
            // Same second: ending wins over active so a cancelled rotation never bounces back.
            if remoteEnded != nil && localEnded == nil { return .adoptRemote(remoteState) }
            if localEnded != nil && remoteEnded == nil { return .pushLocal(localState) }
            return .adoptRemote(remoteState)
        }
    }

    func sync() async {
        guard SubscriptionStore.cloudSyncEnabled, !AuthManager.shared.isGuest else { return }
        let client = SupabaseManager.shared.client
        guard let userId = client.auth.currentSession?.user.id,
              LocalUserData.belongs(to: userId.uuidString) else { return }

        PausePlanStore.shared.loadIfNeeded()
        guard PausePlanStore.shared.planIsLoaded else { return }
        do {
            let rows: [PausePlanRecord] = try await client
                .from("pause_plans")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            let remote = rows.first?.toSyncState()
            switch Self.resolve(local: PausePlanStore.shared.syncState, remote: remote) {
            case .adoptRemote(let state):
                PausePlanStore.shared.applySynced(state)
            case .pushLocal(let state):
                await push(state)
            case .inSync:
                break
            }
        } catch {
            os_log("PausePlanSync failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }
    }

    func push(_ state: PausePlanStore.SyncState) async {
        guard SubscriptionStore.cloudSyncEnabled, !AuthManager.shared.isGuest else { return }
        let client = SupabaseManager.shared.client
        guard let userId = client.auth.currentSession?.user.id,
              LocalUserData.belongs(to: userId.uuidString) else { return }
        do {
            let record = PausePlanRecord(from: state, userId: userId)
            _ = try await client
                .from("pause_plans")
                .upsert(record, onConflict: "user_id")
                .execute()
            PausePlanStore.shared.markSynced(updatedAt: state.updatedAt)
        } catch {
            os_log("PausePlanSync push failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }
    }
}
