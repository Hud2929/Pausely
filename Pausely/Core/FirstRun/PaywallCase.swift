import Foundation
import StoreKit

/// Why the paywall was opened and the exact user facts that brought them here, so the headline,
/// value line, and feature order speak directly to what the person just tried to do.
struct PaywallContext: Equatable, Sendable {
    var trigger: ProFeature? = nil
    /// The specific subscription that triggered the upgrade moment (e.g. catalog add, custom add, refund email).
    var serviceName: String? = nil
    /// That subscription's own-currency charge amount and currency code.
    var serviceChargeAmount: Decimal? = nil
    var serviceChargeCurrency: String? = nil
    /// Pause Plan rotation estimate calculated before opening the paywall.
    var pausePlanYearlySavings: Decimal? = nil
    var pausePlanCurrency: String? = nil
    var pausePlanIsConverted: Bool = false
    var pausePlanServices: [String] = []
    /// Pre-commit overflow lines (e.g. from RevealStep or ScreenshotImportView picker before saving).
    var pendingWaitingLines: [TallyLine] = []
    /// Total subscription count when opening from a pre-commit overflow flow.
    var pendingTotalCount: Int? = nil
    /// Currency to format pre-commit waiting lines in when different from `CurrencyManager.selectedCurrency`.
    var pendingCurrency: String? = nil
    /// True when shown once right after FirstRun completes with a real personalized case.
    var fromFirstRunReveal: Bool = false
    /// True when opened directly from SavingsReceiptView so proven savings keep headline priority.
    var fromSavingsReceipt: Bool = false
    /// Peak month and yearly savings context when triggered from the Insights 12-month forecast or cut simulator.
    var forecastPeakMonth: String? = nil
    var forecastPeakAmount: Decimal? = nil
    var forecastCurrency: String? = nil
    var forecastIsConverted: Bool = false
    var simulatorYearlySavings: Decimal? = nil

    init(trigger: ProFeature? = nil,
         serviceName: String? = nil,
         serviceChargeAmount: Decimal? = nil,
         serviceChargeCurrency: String? = nil,
         pausePlanYearlySavings: Decimal? = nil,
         pausePlanCurrency: String? = nil,
         pausePlanIsConverted: Bool = false,
         pausePlanServices: [String] = [],
         pendingWaitingLines: [TallyLine] = [],
         pendingTotalCount: Int? = nil,
         pendingCurrency: String? = nil,
         fromFirstRunReveal: Bool = false,
         fromSavingsReceipt: Bool = false,
         forecastPeakMonth: String? = nil,
         forecastPeakAmount: Decimal? = nil,
         forecastCurrency: String? = nil,
         forecastIsConverted: Bool = false,
         simulatorYearlySavings: Decimal? = nil) {
        self.trigger = trigger
        self.serviceName = serviceName
        self.serviceChargeAmount = serviceChargeAmount
        self.serviceChargeCurrency = serviceChargeCurrency
        self.pausePlanYearlySavings = pausePlanYearlySavings
        self.pausePlanCurrency = pausePlanCurrency
        self.pausePlanIsConverted = pausePlanIsConverted
        self.pausePlanServices = pausePlanServices
        self.pendingWaitingLines = pendingWaitingLines
        self.pendingTotalCount = pendingTotalCount
        self.pendingCurrency = pendingCurrency
        self.fromFirstRunReveal = fromFirstRunReveal
        self.fromSavingsReceipt = fromSavingsReceipt
        self.forecastPeakMonth = forecastPeakMonth
        self.forecastPeakAmount = forecastPeakAmount
        self.forecastCurrency = forecastCurrency
        self.forecastIsConverted = forecastIsConverted
        self.simulatorYearlySavings = simulatorYearlySavings
    }
}

/// The paywall's argument, made strictly from the person's own list and real StoreKit prices.
/// Pure, so every number and conversion on the paywall is unit tested.
enum PaywallCase {
    /// What the paywall can say about prices. They are the App Store's: until it has answered there
    /// are none, and the page prints no sentence with a hole in it ("Pausely Pro is … a year.").
    enum Prices: Equatable {
        case known
        /// Asked for and not yet answered.
        case loading
        /// The App Store did not answer: no prices, no plans to pick, and a way to ask again.
        case unavailable
    }

    static func prices(loaded: Bool, isLoading: Bool) -> Prices {
        if loaded { return .known }
        return isLoading ? .loading : .unavailable
    }

    struct Comparison: Equatable {
        /// The person's most expensive subscription.
        let name: String
        /// A year of Pro costs less than this many months of it.
        let months: Int
    }

    /// Compares a year of Pro with the person's most expensive active subscription. Nil when there
    /// is nothing to compare with, when a currency can't be converted (no guessing), or when Pro
    /// would cost more than six months of it (not an argument worth making).
    static func comparison(proYearly: Decimal, proCurrency: String,
                           subscriptions: [Subscription], rates: CurrencyRates) -> Comparison? {
        guard proYearly > 0 else { return nil }
        let candidates: [(name: String, monthly: Decimal)] = subscriptions.compactMap { subscription in
            guard subscription.renewsAutomatically,
                  let monthly = rates.convert(subscription.monthlyCost, from: subscription.currency, to: proCurrency),
                  monthly > 0 else { return nil }
            return (subscription.name, monthly)
        }
        guard let top = candidates.max(by: { $0.monthly < $1.monthly }) else { return nil }
        // The smallest whole number of months that costs more than a year of Pro.
        var ratio = proYearly / top.monthly, floor = Decimal()
        NSDecimalRound(&floor, &ratio, 0, .down)
        let months = NSDecimalNumber(decimal: floor).intValue + 1
        return months <= 6 ? Comparison(name: top.name, months: months) : nil
    }

    /// Pause Plan rotation ROI against a year of Pro, computed strictly with `rates.convert`.
    struct PausePlanROI: Equatable {
        let yearlySavings: Decimal
        let currency: String
        let serviceNames: [String]
        /// Whole-number floor multiple (e.g. 11 for 11.6×) when savings are at least 2× Pro's yearly price.
        let wholeMultiple: Int?
        let coversPro: Bool
    }

    static func pausePlanROI(yearlySavings: Decimal, savingsCurrency: String, serviceNames: [String],
                             proYearly: Decimal, proCurrency: String, rates: CurrencyRates) -> PausePlanROI? {
        guard yearlySavings > 0, proYearly > 0,
              let converted = rates.convert(yearlySavings, from: savingsCurrency, to: proCurrency),
              converted > 0 else { return nil }
        let covers = converted > proYearly
        var ratio = converted / proYearly, floor = Decimal()
        NSDecimalRound(&floor, &ratio, 0, .down)
        let multiple = NSDecimalNumber(decimal: floor).intValue
        return PausePlanROI(yearlySavings: yearlySavings, currency: savingsCurrency, serviceNames: serviceNames,
                            wholeMultiple: multiple >= 2 ? multiple : nil, coversPro: covers)
    }

    /// Yearly cost of subscriptions sitting unwatched in the waiting queue.
    struct WaitingRisk: Equatable {
        let count: Int
        let yearlyAmount: Decimal
        let currency: String
        let isConverted: Bool
        let names: [String]
        /// True when the unwatched yearly total exceeds a year of Pro.
        let exceedsPro: Bool
    }

    static func waitingRisk(lines: [TallyLine], displayCurrency: String,
                            proYearly: Decimal?, proCurrency: String?,
                            rates: CurrencyRates) -> WaitingRisk? {
        guard !lines.isEmpty else { return nil }
        let display = MoneyFormat.normalizedCode(displayCurrency)
        var sum: Decimal = 0
        var convertedAny = false
        for line in lines {
            guard let yearly = rates.convert(line.yearlyCost, from: line.currency, to: display) else { return nil }
            sum += yearly
            if MoneyFormat.normalizedCode(line.currency) != display { convertedAny = true }
        }
        guard sum > 0 else { return nil }
        let exceedsPro: Bool = {
            guard let proYearly, proYearly > 0, let proCurrency,
                  let inPro = rates.convert(sum, from: display, to: proCurrency) else { return false }
            return inPro > proYearly
        }()
        return WaitingRisk(count: lines.count, yearlyAmount: sum, currency: display,
                           isConverted: convertedAny, names: lines.map(\.name), exceedsPro: exceedsPro)
    }

    /// Proven 12-month Savings Receipt proof for a Free user whose cancellations already cover Pro.
    struct SavingsProof: Equatable {
        let onTrack: Decimal
        let currency: String
        let isConverted: Bool
        /// Floor-rounded multiple (1 decimal place, e.g. 6.4) when `onTrack >= proYearly`.
        let multiple: Decimal
    }

    static func savingsProof(onTrack: Decimal, summaryCurrency: String, isConverted: Bool,
                             proYearly: Decimal, proCurrency: String,
                             rates: CurrencyRates) -> SavingsProof? {
        guard onTrack > 0, proYearly > 0,
              let converted = rates.convert(onTrack, from: summaryCurrency, to: proCurrency),
              converted >= proYearly else { return nil }
        var ratio = converted / proYearly, rounded = Decimal()
        NSDecimalRound(&rounded, &ratio, 1, .down)
        guard rounded >= 1 else { return nil }
        return SavingsProof(onTrack: onTrack, currency: summaryCurrency, isConverted: isConverted, multiple: rounded)
    }

    /// True when one charge of the triggering subscription (e.g. a refund draft) is at least a full year of Pro.
    static func singleChargeCoversPro(amount: Decimal, currency: String,
                                      proYearly: Decimal, proCurrency: String,
                                      rates: CurrencyRates) -> Bool {
        guard amount > 0, proYearly > 0,
              let converted = rates.convert(amount, from: currency, to: proCurrency) else { return false }
        return converted >= proYearly
    }

    /// Always renders all `ProFeature.allCases`, moving the triggering feature to the top.
    static func orderedFeatures(prioritizing trigger: ProFeature?) -> [ProFeature] {
        let all = ProFeature.allCases
        guard let trigger, let index = all.firstIndex(of: trigger), index > 0 else { return all }
        var reordered = all
        reordered.remove(at: index)
        reordered.insert(trigger, at: 0)
        return reordered
    }

    /// Converts a StoreKit introductory free-trial period into whole calendar days.
    static func trialDays(value: Int, unit: Product.SubscriptionPeriod.Unit) -> Int? {
        guard value > 0 else { return nil }
        switch unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return nil
        }
    }

    /// Total subscriptions represented by a waiting-risk headline, never undercounting when both
    /// saved waiting lines and newly scanned pre-commit overflow exist simultaneously.
    static func totalSubscriptions(pendingTotalCount: Int?, activeCount: Int, waitingCount: Int) -> Int {
        max(pendingTotalCount ?? 0, activeCount + waitingCount)
    }
}
