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
    /// The subscription the main screen should open: a tap on a widget, a Spotlight result, a link,
    /// or a reminder with nothing to decide. Held here until the main screen exists to show it, so a
    /// tap that starts the app is not lost.
    @Published var subscriptionToShow: Request?

    /// A reminder can still be on the Lock Screen after its owner signed out. It opens nothing and
    /// records nothing then: whoever signs in next must not be shown someone else's subscription.
    /// A demo launch (DEBUG only: captures, UI tests) has a list and no account, and counts as signed
    /// in, so the rows on Home and the Keep button can be followed there as a customer would.
    var isSignedIn: () -> Bool = { AuthManager.shared.isAuthenticated || LaunchFlag.demoMode.isSet }

    func openPausePlan() {
        guard isSignedIn() else { return }
        showingPausePlan = true
    }

    func open(subscriptionId: UUID) {
        guard isSignedIn() else { return }
        presented = Request(subscriptionId: subscriptionId)
    }

    /// Nothing waits to be shown: on sign-out, and when the iPhone's data is removed.
    func forget() {
        presented = nil
        showingPausePlan = false
        subscriptionToShow = nil
    }

    /// Opens the subscription itself.
    func showSubscription(_ subscriptionId: UUID) {
        guard isSignedIn() else { return }
        subscriptionToShow = Request(subscriptionId: subscriptionId)
    }

    /// Keep: records the decision for a charge, so no more reminders ask about it. The next renewal
    /// gets its own verdict.
    ///
    /// From the app it is the coming charge. From a reminder it is the charge that reminder was about
    /// (`renewalDay`, the day stamped on it): "Keep it" pressed on yesterday's reminder must not
    /// silence next month's.
    func keep(subscriptionId: UUID, renewalDay: String? = nil, now: Date = Date()) async {
        let store = SubscriptionStore.shared
        guard isSignedIn(), let sub = store.subscriptions.first(where: { $0.id == subscriptionId }) else { return }
        let decided = renewalDay.map { RenewalDecisions.charge(for: sub, onDay: $0, now: now) }
            ?? RenewalDecisions.upcomingCharge(for: sub, now: now)
        guard let charge = decided else { return }
        LifecycleEventLog.shared.record(.kept, for: sub, date: now, renewalDate: charge.date)
        await ReminderScheduler.shared.reschedule(store.subscriptions, now: now)
    }

    /// Decisions waiting right now, soonest first. Subscriptions in a Pause Plan follow the plan instead.
    /// The screen hands in the plan, from the plan store it watches: a screen that worked this out
    /// without watching the plan kept its old answer after a plan started or ended.
    func pendingDecisions(rotating plan: PausePlan?, now: Date = Date()) -> [RenewalDecisions.Pending] {
        let rotating = Set(plan?.subscriptionIds ?? [])
        return RenewalDecisions.pending(in: SubscriptionStore.shared.subscriptions.filter { !rotating.contains($0.id) },
                                        events: LifecycleEventLog.shared.events, now: now)
    }
}
