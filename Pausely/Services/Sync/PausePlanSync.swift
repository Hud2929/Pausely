import Foundation
import Supabase
import os.log

/// Row representation of `public.pause_plans` in Supabase (one active plan per account).
struct PausePlanRecord: Codable, Equatable {
    var user_id: UUID
    var subscription_ids: [UUID]
    var started_on: String

    init(from plan: PausePlan, userId: UUID) {
        self.user_id = userId
        self.subscription_ids = plan.subscriptionIds
        self.started_on = plan.startedOn.iso8601String
    }

    func toPlan() -> PausePlan? {
        guard subscription_ids.count >= 2, let started = started_on.iso8601Date else { return nil }
        return PausePlan(subscriptionIds: subscription_ids, startedOn: started)
    }
}

/// Multi-device sync for the customer's Pause Plan (`public.pause_plans`).
@MainActor
final class PausePlanSync {
    static let shared = PausePlanSync()

    private init() {}

    enum Resolution: Equatable {
        case adoptRemote(PausePlan)
        case pushLocal(PausePlan)
        case inSync
    }

    /// Pure reconciliation rule between the local Pause Plan and the cloud copy.
    nonisolated static func resolve(local: PausePlan?, remote: PausePlan?) -> Resolution {
        switch (local, remote) {
        case (nil, nil):
            return .inSync
        case (nil, let remotePlan?):
            return .adoptRemote(remotePlan)
        case (let localPlan?, nil):
            return .pushLocal(localPlan)
        case (let localPlan?, let remotePlan?):
            if localPlan == remotePlan { return .inSync }
            return remotePlan.startedOn >= localPlan.startedOn ? .adoptRemote(remotePlan) : .pushLocal(localPlan)
        }
    }

    func sync() async {
        guard SubscriptionStore.cloudSyncEnabled, !AuthManager.shared.isGuest else { return }
        let client = SupabaseManager.shared.client
        guard let userId = client.auth.currentSession?.user.id,
              LocalUserData.belongs(to: userId.uuidString) else { return }

        PausePlanStore.shared.loadIfNeeded()
        do {
            let rows: [PausePlanRecord] = try await client
                .from("pause_plans")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            let remote = rows.first?.toPlan()
            switch Self.resolve(local: PausePlanStore.shared.plan, remote: remote) {
            case .adoptRemote(let plan):
                PausePlanStore.shared.applySynced(plan)
            case .pushLocal(let plan):
                await push(plan)
            case .inSync:
                break
            }
        } catch {
            os_log("PausePlanSync failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }
    }

    func push(_ plan: PausePlan?) async {
        guard SubscriptionStore.cloudSyncEnabled, !AuthManager.shared.isGuest else { return }
        let client = SupabaseManager.shared.client
        guard let userId = client.auth.currentSession?.user.id,
              LocalUserData.belongs(to: userId.uuidString) else { return }
        do {
            if let plan {
                let record = PausePlanRecord(from: plan, userId: userId)
                _ = try await client
                    .from("pause_plans")
                    .upsert(record, onConflict: "user_id")
                    .execute()
            } else {
                try await client
                    .from("pause_plans")
                    .delete()
                    .eq("user_id", value: userId)
                    .execute()
            }
        } catch {
            os_log("PausePlanSync push failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }
    }
}
