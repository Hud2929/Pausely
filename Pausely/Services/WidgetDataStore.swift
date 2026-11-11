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
        // Totals in the display currency, every subscription converted from its own currency.
        let displayCurrency = CurrencyManager.shared.selectedCurrency
        let monthlyTotal = active.monthlyTotal(in: displayCurrency)
        let monthlySpend = NSDecimalNumber(decimal: monthlyTotal).doubleValue
        let upcoming = active.filter { sub in
            guard let next = sub.calculatedNextBillingDate else { return false }
            return next <= Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        }

        defaults.set(monthlySpend, forKey: "widget_monthlySpend")
        defaults.set(active.count, forKey: "widget_activeCount")
        defaults.set(upcoming.count, forKey: "widget_upcomingCount")
        defaults.set(displayCurrency, forKey: "widget_currencyCode")
        // The widget shows these exactly as written; it never formats money itself.
        defaults.set(MoneyFormat.string(monthlyTotal, displayCurrency), forKey: "widget_monthlySpendText")
        defaults.set(MoneyFormat.string(monthlyTotal, displayCurrency, wholeUnits: true), forKey: "widget_monthlySpendWholeText")
        defaults.set(MoneyFormat.string(monthlyTotal * 12, displayCurrency, wholeUnits: true), forKey: "widget_yearlySpendWholeText")

        let insight = generateInsight(for: active, monthlyTotal: monthlyTotal, currency: displayCurrency)
        defaults.set(insight, forKey: "widget_topInsight")

        // Publish upcoming renewal details for Live Activities
        if let firstUpcoming = upcoming.first {
            defaults.set(firstUpcoming.name, forKey: "liveActivity_subscriptionName")
            defaults.set(firstUpcoming.nextBillingDate?.timeIntervalSince1970 ?? 0, forKey: "liveActivity_renewalDate")
            defaults.set(NSDecimalNumber(decimal: firstUpcoming.amount).doubleValue, forKey: "liveActivity_amount")
            defaults.set(firstUpcoming.chargeText, forKey: "liveActivity_amountText")
            defaults.set(firstUpcoming.billingFrequency.displayName, forKey: "liveActivity_frequency")
        } else if let firstActive = active.first {
            defaults.set(firstActive.name, forKey: "liveActivity_subscriptionName")
            defaults.set(firstActive.nextBillingDate?.timeIntervalSince1970 ?? 0, forKey: "liveActivity_renewalDate")
            defaults.set(NSDecimalNumber(decimal: firstActive.amount).doubleValue, forKey: "liveActivity_amount")
            defaults.set(firstActive.chargeText, forKey: "liveActivity_amountText")
            defaults.set(firstActive.billingFrequency.displayName, forKey: "liveActivity_frequency")
        }

        // Publish trial subscriptions sorted by urgency
        let trialInfos = subscriptions
            .filter { $0.status == .trial }
            .compactMap { sub -> WidgetTrialInfo? in
                guard let trialEnd = sub.trialEndsAt else { return nil }
                return WidgetTrialInfo(
                    id: sub.id.uuidString,
                    name: sub.name,
                    trialEndsAt: trialEnd,
                    monthlyAmount: Double(truncating: sub.monthlyCost as NSNumber),
                    currencyCode: sub.currency,
                    billingFrequency: sub.billingFrequency.displayName,
                    amountText: sub.chargeText
                )
            }
            .sorted { $0.trialEndsAt < $1.trialEndsAt }
        if let data = try? JSONEncoder().encode(trialInfos) {
            defaults.set(data, forKey: "widget_trials")
        }

        defaults.synchronize()
    }

    // MARK: - Read (used by widget extension)

    func readSummary() -> WidgetSummary {
        guard let defaults else {
            return WidgetSummary()
        }
        return WidgetSummary(
            monthlySpend: defaults.double(forKey: "widget_monthlySpend"),
            activeCount: defaults.integer(forKey: "widget_activeCount"),
            upcomingCount: defaults.integer(forKey: "widget_upcomingCount"),
            currencyCode: defaults.string(forKey: "widget_currencyCode") ?? "USD",
            topInsight: defaults.string(forKey: "widget_topInsight") ?? "Track your subscriptions",
            monthlySpendText: defaults.string(forKey: "widget_monthlySpendText") ?? "",
            yearlySpendWholeText: defaults.string(forKey: "widget_yearlySpendWholeText") ?? ""
        )
    }


    // MARK: - Insights

    /// The one line the widget leads with: what charges next, how much, and when. A fact from the
    /// person's own list, in their language; never commentary on their spending.
    private func generateInsight(for subscriptions: [Subscription], monthlyTotal: Decimal, currency: String) -> String {
        guard !subscriptions.isEmpty else { return L10n.string("Add what you pay for in Pausely") }
        let dated = subscriptions.compactMap { sub in sub.calculatedNextBillingDate.map { (sub, $0) } }
        guard let (next, date) = dated.min(by: { $0.1 < $1.1 }) else { return L10n.string("Add renewal dates to see what's next") }
        let days = max(0, Calendar.current.calendarDays(from: Date(), to: date))
        let when: String
        switch days {
        case 0: when = L10n.string("today")
        case 1: when = L10n.string("tomorrow")
        default: when = L10n.string("in \(days) days")
        }
        return "\(next.name) · \(MoneyFormat.string(next.amount, next.currency)) · \(when)"
    }
}

// MARK: - Data Models

struct WidgetSummary {
    let monthlySpend: Double
    let activeCount: Int
    let upcomingCount: Int
    let currencyCode: String
    let topInsight: String
    /// Formatted by the app with MoneyFormat; the widget shows them as they are.
    let monthlySpendText: String
    let yearlySpendWholeText: String

    init(monthlySpend: Double = 0, activeCount: Int = 0, upcomingCount: Int = 0, currencyCode: String = "USD",
         topInsight: String = "Loading...", monthlySpendText: String = "", yearlySpendWholeText: String = "") {
        self.monthlySpend = monthlySpend
        self.activeCount = activeCount
        self.upcomingCount = upcomingCount
        self.currencyCode = currencyCode
        self.topInsight = topInsight
        self.monthlySpendText = monthlySpendText
        self.yearlySpendWholeText = yearlySpendWholeText
    }
}

// MARK: - Trial Info (shared with widget extension)

/// Must match `WidgetTrialInfo` in the widget extension field for field.
struct WidgetTrialInfo: Codable, Identifiable {
    let id: String
    let name: String
    let trialEndsAt: Date
    let monthlyAmount: Double
    let currencyCode: String
    let billingFrequency: String
    /// What the first charge will be, in the subscription's own currency ("$15.49").
    let amountText: String?

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: trialEndsAt).day ?? 0)
    }
}

