import Foundation
import Supabase
import os.log

/// Row representation of `public.lifecycle_events` in Supabase.
struct LifecycleEventRecord: Codable, Equatable {
    var id: UUID
    var user_id: UUID?
    var subscription_id: UUID
    var subscription_name: String
    var kind: String
    var occurred_at: String
    var amount: Decimal
    var currency: String
    var frequency: String
    var previous_amount: Decimal?
    var renewal_date: String?
    var anchor_date: String?

    init(from event: LifecycleEvent, userId: UUID? = nil) {
        self.id = event.id
        self.user_id = userId
        self.subscription_id = event.subscriptionId
        let trimmed = event.subscriptionName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subscription_name = String((trimmed.isEmpty ? "Subscription" : trimmed).prefix(200))
        self.kind = event.kind.rawValue
        self.occurred_at = event.date.iso8601FractionalString
        self.amount = max(0, event.amount)
        self.currency = String(event.currency.prefix(10))
        self.frequency = event.frequency.rawValue
        self.previous_amount = event.previousAmount.map { max(0, $0) }
        self.renewal_date = event.renewalDate.map { BillingDay.stored($0).iso8601String }
        self.anchor_date = event.anchorDate.map { BillingDay.stored($0).iso8601String }
    }

    func toEvent() -> LifecycleEvent? {
        guard let eventKind = LifecycleEvent.Kind(rawValue: kind),
              let parsedDate = occurred_at.iso8601Date else { return nil }
        let freq = BillingFrequency(rawValue: frequency) ?? .monthly
        return LifecycleEvent(
            id: id,
            kind: eventKind,
            subscriptionId: subscription_id,
            subscriptionName: subscription_name,
            date: parsedDate,
            amount: amount,
            currency: currency,
            frequency: freq,
            previousAmount: previous_amount,
            renewalDate: renewal_date?.iso8601Date.map { BillingDay.local(fromStored: $0) },
            anchorDate: anchor_date?.iso8601Date.map { BillingDay.local(fromStored: $0) }
        )
    }
}

/// Multi-device sync for Savings Receipt and Price History (`public.lifecycle_events`).
/// Pure merge logic + idempotent upsert so reinstalling or signing in on an iPad restores the
/// entire Savings Receipt without ever duplicating an event.
@MainActor
final class LifecycleSync {
    static let shared = LifecycleSync()

    private init() {}

    /// Pure append-only union of local and remote lifecycle events, deduplicated by UUID, ordered
    /// chronologically, and capped at `maxEvents`.
    nonisolated static func merge(local: [LifecycleEvent], remote: [LifecycleEvent],
                                  maxEvents: Int = LifecycleEventLog.maxEvents) -> (merged: [LifecycleEvent], toUpload: [LifecycleEvent]) {
        let remoteIDs = Set(remote.map(\.id))
        var byID: [UUID: LifecycleEvent] = [:]
        for event in remote { byID[event.id] = event }
        for event in local where byID[event.id] == nil { byID[event.id] = event }

        var sorted = byID.values.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        if sorted.count > maxEvents {
            sorted = Array(sorted.suffix(maxEvents))
        }
        let keptIDs = Set(sorted.map(\.id))
        let toUpload = local.filter { keptIDs.contains($0.id) && !remoteIDs.contains($0.id) }
        return (sorted, toUpload)
    }

    /// Pulls remote history, merges with local, persists merged history, and uploads any local-only events.
    func sync() async {
        guard SubscriptionStore.cloudSyncEnabled, !AuthManager.shared.isGuest else { return }
        let client = SupabaseManager.shared.client
        guard client.auth.currentSession != nil else { return }

        LifecycleEventLog.shared.loadIfNeeded()
        guard LifecycleEventLog.shared.historyIsLoaded else { return }

        do {
            let session = try await client.auth.session
            guard !session.isExpired else { return }
            let userId = session.user.id
            guard LocalUserData.belongs(to: userId.uuidString) else { return }
            let remoteRows: [LifecycleEventRecord] = try await client
                .from("lifecycle_events")
                .select()
                .eq("user_id", value: userId)
                .order("occurred_at", ascending: false)
                .limit(LifecycleEventLog.maxEvents)
                .execute()
                .value

            let remoteEvents = remoteRows.compactMap { $0.toEvent() }
            let result = Self.merge(local: LifecycleEventLog.shared.events, remote: remoteEvents)

            if result.merged != LifecycleEventLog.shared.events {
                LifecycleEventLog.shared.restore(result.merged)
                WidgetDataStore.shared.publish(subscriptions: SubscriptionStore.shared.subscriptions)
                await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions)
            }
            if !result.toUpload.isEmpty {
                let records = result.toUpload.map { LifecycleEventRecord(from: $0, userId: userId) }
                _ = try await client
                    .from("lifecycle_events")
                    .upsert(records, onConflict: "id")
                    .execute()
            }
        } catch {
            os_log("LifecycleSync failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }
    }

    /// Uploads a single newly recorded event in the background when signed into a cloud account.
    func upload(_ event: LifecycleEvent) async {
        guard SubscriptionStore.cloudSyncEnabled, !AuthManager.shared.isGuest else { return }
        let client = SupabaseManager.shared.client
        guard client.auth.currentSession != nil else { return }
        do {
            let session = try await client.auth.session
            guard !session.isExpired else { return }
            let userId = session.user.id
            guard LocalUserData.belongs(to: userId.uuidString) else { return }
            let record = LifecycleEventRecord(from: event, userId: userId)
            _ = try await client
                .from("lifecycle_events")
                .upsert(record, onConflict: "id")
                .execute()
        } catch {
            os_log("LifecycleSync upload failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
        }
    }
}
