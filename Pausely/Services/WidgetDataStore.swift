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
        defaults.set(CurrencyManager.shared.currentCurrency.code, forKey: "widget_currencyCode")

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
            currencyCode: defaults.string(forKey: "widget_currencyCode") ?? "USD",
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
    let currencyCode: String
    let topInsight: String

    var currencySymbol: String {
        switch currencyCode {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY", "CNY": return "¥"
        case "CAD": return "C$"
        case "AUD": return "A$"
        case "CHF": return "Fr"
        case "INR": return "₹"
        case "KRW": return "₩"
        case "BRL": return "R$"
        case "MXN", "ARS", "CLP", "COP", "UYU", "CUP", "DOP", "NIO", "NAD", "BZD", "BSD", "BBD", "TTD", "XCD", "LRD": return "$"
        case "SGD": return "S$"
        case "HKD": return "HK$"
        case "NOK", "SEK", "DKK", "ISK": return "kr"
        case "NZD": return "NZ$"
        case "ZAR": return "R"
        case "RUB": return "₽"
        case "TRY": return "₺"
        case "PLN": return "zł"
        case "THB": return "฿"
        case "IDR": return "Rp"
        case "MYR": return "RM"
        case "PHP": return "₱"
        case "CZK": return "Kč"
        case "ILS": return "₪"
        case "AED": return "د.إ"
        case "SAR", "QAR", "OMR", "YER": return "﷼"
        case "TWD": return "NT$"
        case "VND": return "₫"
        case "EGP": return "£"
        case "PKR", "MUR", "SCR", "NPR", "LKR": return "₨"
        case "NGN": return "₦"
        case "BDT": return "৳"
        case "RON": return "lei"
        case "HUF": return "Ft"
        case "UAH": return "₴"
        case "PEN": return "S/"
        case "MAD": return "د.م."
        case "KWD": return "د.ك"
        case "BHD": return ".د.ب"
        case "JOD": return "د.ا"
        case "KES": return "KSh"
        case "GHS": return "₵"
        case "TZS": return "TSh"
        case "UGX": return "USh"
        case "HRK": return "kn"
        case "BGN": return "лв"
        case "RSD": return "дин"
        case "GEL": return "₾"
        case "AMD": return "֏"
        case "AZN": return "₼"
        case "KZT": return "₸"
        case "UZS": return "so'm"
        case "TJS": return "SM"
        case "KGS": return "с"
        case "MNT": return "₮"
        case "MMK": return "K"
        case "KHR": return "៛"
        case "LAK": return "₭"
        case "BND": return "$"
        case "BWP": return "P"
        case "ZMW": return "ZK"
        case "MWK": return "MK"
        case "MZN": return "MT"
        case "SZL", "LSL": return "L"
        case "AOA": return "Kz"
        case "CDF": return "FC"
        case "RWF": return "FRw"
        case "BIF": return "FBu"
        case "DJF": return "Fdj"
        case "ETB": return "Br"
        case "SOS": return "Sh"
        case "GMD": return "D"
        case "GNF": return "FG"
        case "SLL": return "Le"
        case "MRU": return "UM"
        case "STN": return "Db"
        case "XOF": return "CFA"
        case "XAF": return "FCFA"
        case "AWG", "ANG": return "ƒ"
        case "HTG": return "G"
        case "GTQ": return "Q"
        case "HNL": return "L"
        case "CRC": return "₡"
        case "PAB": return "B/."
        case "PYG": return "₲"
        case "BOB", "VES": return "Bs"
        default: return "$"
        }
    }

    init(monthlySpend: Double = 0, activeCount: Int = 0, upcomingCount: Int = 0, currencyCode: String = "USD", topInsight: String = "Loading...") {
        self.monthlySpend = monthlySpend
        self.activeCount = activeCount
        self.upcomingCount = upcomingCount
        self.currencyCode = currencyCode
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
