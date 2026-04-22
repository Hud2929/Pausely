import Foundation
import os.log

/// Shares subscription summary data to App Group UserDefaults for widget and Live Activity consumption.
@MainActor
final class WidgetDataStore {
    static let shared = WidgetDataStore()

    private let suiteName = "group.com.pausely.app.shared"
    private let injectedDefaults: UserDefaults?

    private var defaults: UserDefaults? {
        injectedDefaults ?? UserDefaults(suiteName: suiteName)
    }

    private init(defaults: UserDefaults? = nil) {
        self.injectedDefaults = defaults
    }

    /// Creates a testable instance with injected UserDefaults.
    static func forTesting(defaults: UserDefaults) -> WidgetDataStore {
        WidgetDataStore(defaults: defaults)
    }

    // MARK: - Publish

    func publish(subscriptions: [Subscription]) {
        guard let defaults else {
            os_log("WidgetDataStore: App Group UserDefaults not available", log: .default, type: .error)
            return
        }

        let active = subscriptions.filter { $0.status == .active }
        let monthlySpend = active.reduce(0.0) { $0 + (Double(truncating: $1.monthlyCost as NSNumber) ) }
        let upcoming = active.filter { sub in
            guard let next = sub.nextBillingDate else { return false }
            return next <= Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        }

        defaults.set(monthlySpend, forKey: "widget_monthlySpend")
        defaults.set(active.count, forKey: "widget_activeCount")
        defaults.set(upcoming.count, forKey: "widget_upcomingCount")

        let insight = generateInsight(for: active, monthlySpend: monthlySpend)
        defaults.set(insight, forKey: "widget_topInsight")

        // Publish upcoming renewal details for Live Activities
        if let firstUpcoming = upcoming.first {
            defaults.set(firstUpcoming.name, forKey: "liveActivity_subscriptionName")
            defaults.set(firstUpcoming.nextBillingDate?.timeIntervalSince1970 ?? 0, forKey: "liveActivity_renewalDate")
            defaults.set(Double(truncating: firstUpcoming.monthlyCost as NSNumber), forKey: "liveActivity_amount")
            defaults.set(firstUpcoming.billingFrequency.displayName, forKey: "liveActivity_frequency")
        } else if let firstActive = active.first {
            defaults.set(firstActive.name, forKey: "liveActivity_subscriptionName")
            defaults.set(firstActive.nextBillingDate?.timeIntervalSince1970 ?? 0, forKey: "liveActivity_renewalDate")
            defaults.set(Double(truncating: firstActive.monthlyCost as NSNumber), forKey: "liveActivity_amount")
            defaults.set(firstActive.billingFrequency.displayName, forKey: "liveActivity_frequency")
        }

        defaults.synchronize()
    }

    // MARK: - Read (used by widget extension)

    func readSummary() -> WidgetSummary {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return WidgetSummary()
        }
        return WidgetSummary(
            monthlySpend: defaults.double(forKey: "widget_monthlySpend"),
            activeCount: defaults.integer(forKey: "widget_activeCount"),
            upcomingCount: defaults.integer(forKey: "widget_upcomingCount"),
            topInsight: defaults.string(forKey: "widget_topInsight") ?? "Track your subscriptions"
        )
    }

    func readLiveActivityData() -> LiveActivityData {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return LiveActivityData()
        }
        return LiveActivityData(
            subscriptionName: defaults.string(forKey: "liveActivity_subscriptionName") ?? "Subscription",
            renewalDate: Date(timeIntervalSince1970: defaults.double(forKey: "liveActivity_renewalDate")),
            amount: defaults.double(forKey: "liveActivity_amount"),
            frequency: defaults.string(forKey: "liveActivity_frequency") ?? "Monthly"
        )
    }

    // MARK: - Insights

    private func generateInsight(for subscriptions: [Subscription], monthlySpend: Double) -> String {
        if subscriptions.isEmpty {
            return "Add your first subscription to start tracking"
        }
        if monthlySpend > 200 {
            return "You're spending \(String(format: "%.0f", monthlySpend))/month — review for savings"
        }
        let paused = subscriptions.filter { $0.status == .paused }.count
        if paused > 0 {
            return "\(paused) subscription\(paused == 1 ? "" : "s") paused — great job saving"
        }
        return "Tracking \(subscriptions.count) active subscription\(subscriptions.count == 1 ? "" : "s")"
    }
}

// MARK: - Data Models

struct WidgetSummary {
    let monthlySpend: Double
    let activeCount: Int
    let upcomingCount: Int
    let topInsight: String

    init(monthlySpend: Double = 0, activeCount: Int = 0, upcomingCount: Int = 0, topInsight: String = "Loading...") {
        self.monthlySpend = monthlySpend
        self.activeCount = activeCount
        self.upcomingCount = upcomingCount
        self.topInsight = topInsight
    }
}

struct LiveActivityData {
    let subscriptionName: String
    let renewalDate: Date
    let amount: Double
    let frequency: String

    init(subscriptionName: String = "", renewalDate: Date = Date(), amount: Double = 0, frequency: String = "Monthly") {
        self.subscriptionName = subscriptionName
        self.renewalDate = renewalDate
        self.amount = amount
        self.frequency = frequency
    }

    var daysUntilRenewal: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: renewalDate).day ?? 0
    }
}
