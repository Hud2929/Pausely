import Foundation

/// The time a person says they used each subscription this month. They type it (Pausely does not read
/// Screen Time), it stays on this device, and it counts only for the month it was entered in: last
/// month's hours are not this month's.
final class UsageLog: ObservableObject {
    static let shared = UsageLog()

    struct Usage: Equatable {
        var minutesUsed: Int
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    private func minutesKey(_ name: String) -> String { "usage_\(name)" }
    private func monthKey(_ name: String) -> String { "usage_month_\(name)" }

    private func month(of date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// What was entered for this month, or nil when nothing was. Zero is an answer ("I haven't used it").
    func getUsage(for subscriptionName: String, now: Date = Date()) -> Usage? {
        let minutes = defaults.integer(forKey: minutesKey(subscriptionName))
        guard let entered = defaults.string(forKey: monthKey(subscriptionName)) else {
            // Entered before months were recorded: it can only have been typed for the month it's read in.
            guard minutes > 0 else { return nil }
            defaults.set(month(of: now), forKey: monthKey(subscriptionName))
            return Usage(minutesUsed: minutes)
        }
        return entered == month(of: now) ? Usage(minutesUsed: minutes) : nil
    }

    func getCurrentMonthUsage(for subscriptionName: String, now: Date = Date()) -> Int {
        getUsage(for: subscriptionName, now: now)?.minutesUsed ?? 0
    }

    /// What an hour of use costs this month. Nil until some time has been entered.
    func calculateCostPerHour(monthlyCost: Decimal, subscriptionName: String, now: Date = Date()) -> Decimal? {
        let minutes = getCurrentMonthUsage(for: subscriptionName, now: now)
        guard minutes > 0 else { return nil }
        return monthlyCost / (Decimal(minutes) / 60)
    }

    func setMonthlyUsage(minutes: Int, for subscriptionName: String, now: Date = Date()) {
        objectWillChange.send()
        defaults.set(max(0, minutes), forKey: minutesKey(subscriptionName))
        defaults.set(month(of: now), forKey: monthKey(subscriptionName))
    }
}
