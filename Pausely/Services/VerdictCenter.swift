import Foundation

/// Opens Renewal Verdicts and records decisions. Notification taps, the dashboard's "Decide" card
/// and the subscription screen all go through here, so a decision is recorded the same way
/// wherever it is made.
@MainActor
final class VerdictCenter: ObservableObject {
    static let shared = VerdictCenter()

    struct Request: Identifiable, Equatable {
        let subscriptionId: UUID
        var id: UUID { subscriptionId }
    }

    /// The verdict the main screen should show. Set by a notification tap; cleared on dismiss.
    @Published var presented: Request?
    /// Set by a Pause Plan reminder tap.
    @Published var showingPausePlan = false

    func openPausePlan() {
        showingPausePlan = true
    }

    func open(subscriptionId: UUID) {
        presented = Request(subscriptionId: subscriptionId)
    }

    /// Opens the subscription itself (used when a reminder has no decision to make).
    func showSubscription(_ subscriptionId: UUID) {
        NotificationCenter.default.post(name: .showSubscriptionManagement, object: nil,
                                        userInfo: ["subscription_id": subscriptionId.uuidString])
    }

    /// Keep: records the decision for the coming charge, so no more reminders ask about it.
    /// The next renewal gets its own verdict.
    func keep(subscriptionId: UUID, now: Date = Date()) async {
        let store = SubscriptionStore.shared
        guard let sub = store.subscriptions.first(where: { $0.id == subscriptionId }),
              let charge = RenewalDecisions.upcomingCharge(for: sub, now: now) else { return }
        LifecycleEventLog.shared.record(.kept, for: sub, date: now, renewalDate: charge.date)
        await ReminderScheduler.shared.reschedule(store.subscriptions, now: now)
    }

    /// Decisions waiting right now, soonest first. Subscriptions in a Pause Plan follow the plan instead.
    func pendingDecisions(now: Date = Date()) -> [RenewalDecisions.Pending] {
        let rotating = Set(PausePlanStore.shared.activePlan?.subscriptionIds ?? [])
        return RenewalDecisions.pending(in: SubscriptionStore.shared.subscriptions.filter { !rotating.contains($0.id) },
                                        events: LifecycleEventLog.shared.events, now: now)
    }
}
