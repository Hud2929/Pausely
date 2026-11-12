import Foundation

/// The customer's Pause Plan, saved on the device next to the event log.
@MainActor
final class PausePlanStore: ObservableObject {
    static let shared = PausePlanStore()

    @Published private(set) var plan: PausePlan?
    private let fileURL: URL
    /// False while a saved plan exists but can't be read (a background launch on a locked phone);
    /// nothing is written over it until it has been.
    private var planIsLoaded = true

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        load()
    }

    /// Reads the plan if an earlier attempt couldn't. Called when the app comes to the foreground.
    func loadIfNeeded() {
        if !planIsLoaded { load() }
    }

    private func load() {
        switch DeviceFile.load(PausePlan.self, from: fileURL) {
        case .value(let saved):
            plan = saved
            planIsLoaded = true
            DeviceFile.relaxProtection(of: fileURL)
        case .missing:
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
        plan = PausePlan(subscriptionIds: order, startedOn: now)
        save()
        await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions)
    }

    func end() async {
        plan = nil
        save()
        await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions)
    }

    /// "I started it": the subscription is active again and its next charge is a month after `date`.
    /// The status change records a reactivation, which closes its Savings Receipt line.
    func markStarted(_ subscription: Subscription, on date: Date = Date(), calendar: Calendar = .current) async {
        let store = SubscriptionStore.shared
        var updated = subscription
        updated.nextBillingDate = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: date)).map { calendar.noon(of: $0) }
        updated.updatedAt = date
        await store.updateSubscription(updated)
        await store.updateSubscriptionStatus(id: subscription.id, status: .active)
    }

    /// Wipes the plan (account deletion).
    func removeAll() {
        plan = nil
        save()
    }

    // MARK: - Persistence

    private func save() {
        // A plan the person starts or ends by hand replaces whatever was saved, readable or not.
        planIsLoaded = true
        do {
            if let plan {
                try DeviceFile.save(plan, to: fileURL)
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
