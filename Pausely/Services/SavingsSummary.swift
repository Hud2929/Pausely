import Foundation

extension Subscription {
    /// Pausely's own subscription, which Pausely tracks like any other (see the Pausely Promise). It is
    /// known by its name, which is the same on every device the list reaches.
    var isPausely: Bool {
        name.caseInsensitiveCompare(PaymentManager.ownName) == .orderedSame
    }
}

/// The Savings Receipt in the customer's currency, plus how it compares with what Pausely costs.
struct SavingsSummary {
    let lines: [SavingsLedger.Line]
    let currency: String
    /// Charges avoided whose day has passed.
    let savedSoFar: Decimal
    /// Everything the cancellations avoid over their 12 months.
    let onTrack: Decimal
    /// What Pausely costs a year, when the customer pays for it.
    let pauselyYearlyCost: Decimal?
    /// The currency Pausely is paid for in, when that is known.
    var pauselyCurrency: String? = nil
    /// Lines whose currency could not be converted into `currency`, left out of the totals.
    var excludedUnconvertibleCount: Int = 0
    /// True when the customer is on paid Pro, but neither their list nor StoreKit has a price yet.
    var isPaidProWithoutKnownPrice: Bool = false
    /// Explicit conversion flags computed against the live rates table; nil falls back to line codes.
    var convertedSavedOverride: Bool? = nil
    var convertedOnTrackOverride: Bool? = nil

    var isEmpty: Bool { lines.isEmpty }

    /// True when a converted foreign-currency line contributed to "Saved so far".
    var savedIsConverted: Bool {
        if let override = convertedSavedOverride { return override }
        guard savedSoFar > 0 else { return false }
        let display = MoneyFormat.normalizedCode(currency)
        let hasPositiveLine = lines.contains { $0.savedSoFar > 0 }
        return lines.contains {
            MoneyFormat.normalizedCode($0.currency) != display && (!hasPositiveLine || $0.savedSoFar > 0)
        }
    }

    /// True when a converted foreign-currency line contributed to "On track this year".
    var onTrackIsConverted: Bool {
        if let override = convertedOnTrackOverride { return override }
        guard onTrack > 0 else { return false }
        let display = MoneyFormat.normalizedCode(currency)
        let hasPositiveLine = lines.contains { $0.onTrack > 0 }
        return lines.contains {
            MoneyFormat.normalizedCode($0.currency) != display && (!hasPositiveLine || $0.onTrack > 0)
        }
    }

    /// True when a cancellation in another currency was converted into either total.
    var totalsAreConverted: Bool {
        savedIsConverted || onTrackIsConverted
    }

    /// True when Pausely is paid for in another currency than the one the receipt is shown in.
    var pauselyCostIsConverted: Bool {
        guard let paidIn = pauselyCurrency else { return false }
        return MoneyFormat.normalizedCode(paidIn) != MoneyFormat.normalizedCode(currency)
    }

    /// One of the two totals as text ("$527.64", or "≈$527.64" when a line was converted).
    func total(_ amount: Decimal) -> String {
        MoneyFormat.total(amount, currency, converted: amount > 0 && totalsAreConverted)
    }

    /// "Saved so far" formatted with "≈" only when a converted line actually contributed to it.
    var savedSoFarText: String {
        MoneyFormat.total(savedSoFar, currency, converted: savedSoFar > 0 && savedIsConverted)
    }

    /// "On track this year" formatted with "≈" only when a converted line contributed to it.
    var onTrackText: String {
        MoneyFormat.total(onTrack, currency, converted: onTrack > 0 && onTrackIsConverted)
    }

    /// What Pausely costs a year as text, marked when it was converted.
    var pauselyCostText: String? {
        pauselyYearlyCost.map { MoneyFormat.total($0, currency, converted: pauselyCostIsConverted) }
    }

    /// How many times over Pausely pays for itself in a year, when it costs anything.
    var returnMultiple: Decimal? {
        guard let cost = pauselyYearlyCost, cost > 0 else { return nil }
        return onTrack / cost
    }

    /// The Pausely Promise: true once Pausely's savings cover what it costs (never falsely true
    /// when the customer is on paid Pro whose price isn't loaded yet).
    var paysForItself: Bool {
        if isPaidProWithoutKnownPrice { return false }
        guard let cost = pauselyYearlyCost else { return true }
        return onTrack >= cost
    }

    func formatted(_ amount: Decimal) -> String { MoneyFormat.string(amount, currency) }

    /// An amount from one receipt line, in the receipt's currency so the lines add up to the total.
    /// Marked "≈" when it was converted; left in its own currency only if it can't be converted.
    func formatted(_ amount: Decimal, from lineCurrency: String,
                   rates: CurrencyRates = CurrencyManager.shared.rates) -> String {
        if amount == 0 { return formatted(0) }
        if MoneyFormat.normalizedCode(lineCurrency) == MoneyFormat.normalizedCode(currency) { return formatted(amount) }
        guard let converted = rates.convert(amount, from: lineCurrency, to: currency) else {
            return MoneyFormat.string(amount, lineCurrency)
        }
        return "≈" + formatted(converted)
    }

    @MainActor
    static func current(now: Date = Date()) -> SavingsSummary {
        let store = SubscriptionStore.shared
        let currencies = CurrencyManager.shared
        let display = MoneyFormat.normalizedCode(currencies.selectedCurrency)
        let pausely = store.subscriptions.first { $0.isPausely && ($0.status == .active || $0.status == .trial) }
        let excluded = Set(store.subscriptions.filter(\.isPausely).map(\.id))
        let lines = SavingsLedger.lines(from: LifecycleEventLog.shared.events, now: now, excluding: excluded)
            .filter { $0.name.caseInsensitiveCompare(PaymentManager.ownName) != .orderedSame }
        let totals = SavingsLedger.totals(lines)
        func converted(_ byCurrency: [String: Decimal]) -> (total: Decimal, hasConverted: Bool) {
            var sum: Decimal = 0
            var hadForeign = false
            for (code, amount) in byCurrency {
                guard let value = currencies.convertToSelected(amount, from: code) else { continue }
                sum += value
                if amount > 0 && MoneyFormat.normalizedCode(code) != display { hadForeign = true }
            }
            return (sum, hadForeign)
        }
        let savedResult = converted(totals.savedSoFar)
        let onTrackResult = converted(totals.onTrack)
        let excludedUnconvertible = lines.filter { currencies.convertToSelected($0.onTrack, from: $0.currency) == nil }.count

        var yearlyCost: Decimal? = pausely.flatMap { currencies.convertToSelected($0.annualCost, from: $0.currency) }
        var paidCurrency: String? = pausely?.currency
        let isPaidSubscriber = PaymentManager.shared.isPremium && (pausely != nil || PaymentManager.shared.hasStoreKitEntitlement)
        if yearlyCost == nil, isPaidSubscriber {
            let storeKit = StoreKitManager.shared
            if let product = storeKit.product(for: PaymentManager.shared.currentTier) ?? storeKit.product(for: .proAnnual) {
                let code = product.priceFormatStyle.currencyCode
                let annual = product.id == StoreKitManager.ProductID.monthly.rawValue ? product.price * 12 : product.price
                yearlyCost = currencies.convertToSelected(annual, from: code)
                paidCurrency = code
            }
        }
        let unknownProPrice = isPaidSubscriber && yearlyCost == nil

        return SavingsSummary(
            lines: lines,
            currency: currencies.selectedCurrency,
            savedSoFar: savedResult.total,
            onTrack: onTrackResult.total,
            pauselyYearlyCost: yearlyCost,
            pauselyCurrency: paidCurrency,
            excludedUnconvertibleCount: excludedUnconvertible,
            isPaidProWithoutKnownPrice: unknownProPrice,
            convertedSavedOverride: savedResult.hasConverted,
            convertedOnTrackOverride: onTrackResult.hasConverted
        )
    }
}
