import Foundation

/// The time a person says they used each subscription this month. They type it (Pausely does not read
/// Screen Time), it stays on this device, and it counts only for the month it was entered in: last
/// month's hours are not this month's.
///
/// Keyed by the subscription's UUID so renaming a subscription never loses its hours and two
/// subscriptions with the same name never collide. Legacy name-keyed entries migrate on first read.
@MainActor
final class UsageLog: ObservableObject {
    static let shared = UsageLog()

    struct Usage: Equatable {
        var minutesUsed: Int
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .billing) {
        self.defaults = defaults
        self.calendar = calendar
    }

    private func minutesKey(_ name: String) -> String { "usage_\(name)" }
    private func monthKey(_ name: String) -> String { "usage_month_\(name)" }
    private func idMinutesKey(_ id: UUID) -> String { "usage_id_\(id.uuidString)" }
    private func idMonthKey(_ id: UUID) -> String { "usage_month_id_\(id.uuidString)" }

    private func month(of date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    // MARK: - Subscription (UUID-keyed, with transparent migration from legacy name keys)

    func getUsage(for subscription: Subscription, now: Date = Date()) -> Usage? {
        let mKey = idMonthKey(subscription.id)
        let minKey = idMinutesKey(subscription.id)
        if let entered = defaults.string(forKey: mKey) {
            return entered == month(of: now) ? Usage(minutesUsed: defaults.integer(forKey: minKey)) : nil
        }
        // Migrate a legacy entry saved under the subscription's name before UUID keying.
        if let legacy = getUsage(for: subscription.name, now: now) {
            defaults.set(legacy.minutesUsed, forKey: minKey)
            defaults.set(month(of: now), forKey: mKey)
            defaults.removeObject(forKey: minutesKey(subscription.name))
            defaults.removeObject(forKey: monthKey(subscription.name))
            return legacy
        }
        return nil
    }

    func getCurrentMonthUsage(for subscription: Subscription, now: Date = Date()) -> Int {
        getUsage(for: subscription, now: now)?.minutesUsed ?? 0
    }

    func calculateCostPerHour(for subscription: Subscription, now: Date = Date()) -> Decimal? {
        let minutes = getCurrentMonthUsage(for: subscription, now: now)
        guard minutes > 0 else { return nil }
        return subscription.monthlyCost / (Decimal(minutes) / 60)
    }

    func setMonthlyUsage(minutes: Int, for subscription: Subscription, now: Date = Date()) {
        objectWillChange.send()
        defaults.set(max(0, minutes), forKey: idMinutesKey(subscription.id))
        defaults.set(month(of: now), forKey: idMonthKey(subscription.id))
        // Clean up any legacy name-keyed entry so a rename cannot resurrect stale values.
        defaults.removeObject(forKey: minutesKey(subscription.name))
        defaults.removeObject(forKey: monthKey(subscription.name))
    }

    // MARK: - Legacy name-keyed read (kept solely for transparent UUID migration)

    /// What was entered for this month under a legacy name key, or nil when nothing was.
    private func getUsage(for subscriptionName: String, now: Date = Date()) -> Usage? {
        let minutes = defaults.integer(forKey: minutesKey(subscriptionName))
        guard let entered = defaults.string(forKey: monthKey(subscriptionName)) else {
            // Entered before months were recorded: it can only have been typed for the month it's read in.
            guard minutes > 0 else { return nil }
            defaults.set(month(of: now), forKey: monthKey(subscriptionName))
            return Usage(minutesUsed: minutes)
        }
        return entered == month(of: now) ? Usage(minutesUsed: minutes) : nil
    }

    #if DEBUG
    /// A demo list starts with no hours typed in. Without this the two hours of Netflix that one
    /// list seeded showed on the lists opened after it.
    func forgetAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("usage_") {
            defaults.removeObject(forKey: key)
        }
        objectWillChange.send()
    }
    #endif
}
