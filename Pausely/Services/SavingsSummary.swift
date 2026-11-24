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

    var isEmpty: Bool { lines.isEmpty }

    /// True when a cancellation in another currency was converted into the two totals. That makes
    /// them estimates, and they are marked "≈" wherever they are shown, like every other total in
    /// the app (`MoneyFormat.total`). Each such line is already marked on the receipt.
    var totalsAreConverted: Bool {
        let display = MoneyFormat.normalizedCode(currency)
        return lines.contains { MoneyFormat.normalizedCode($0.currency) != display }
    }

    /// True when Pausely is paid for in another currency than the one the receipt is shown in.
    var pauselyCostIsConverted: Bool {
        guard let paidIn = pauselyCurrency else { return false }
        return MoneyFormat.normalizedCode(paidIn) != MoneyFormat.normalizedCode(currency)
    }

    /// One of the two totals as text ("$527.64", or "≈$527.64" when a line was converted).
    func total(_ amount: Decimal) -> String {
        MoneyFormat.total(amount, currency, converted: totalsAreConverted)
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

    /// The Pausely Promise: true once Pausely's savings cover what it costs.
    var paysForItself: Bool {
        guard let cost = pauselyYearlyCost else { return true }
        return onTrack >= cost
    }

    func formatted(_ amount: Decimal) -> String { MoneyFormat.string(amount, currency) }

    /// An amount from one receipt line, in the receipt's currency so the lines add up to the total.
    /// Marked "≈" when it was converted; left in its own currency only if it can't be converted.
    func formatted(_ amount: Decimal, from lineCurrency: String,
                   rates: CurrencyRates = CurrencyManager.shared.rates) -> String {
        if lineCurrency == currency { return formatted(amount) }
        guard let converted = rates.convert(amount, from: lineCurrency, to: currency) else {
            return MoneyFormat.string(amount, lineCurrency)
        }
        return "≈" + formatted(converted)
    }

    @MainActor
    static func current(now: Date = Date()) -> SavingsSummary {
        let store = SubscriptionStore.shared
        let currencies = CurrencyManager.shared
        let pausely = store.subscriptions.first { $0.isPausely && ($0.status == .active || $0.status == .trial) }
        let excluded = Set(store.subscriptions.filter(\.isPausely).map(\.id))
        let lines = SavingsLedger.lines(from: LifecycleEventLog.shared.events, now: now, excluding: excluded)
            .filter { $0.name.caseInsensitiveCompare("Pausely Pro") != .orderedSame }
        let totals = SavingsLedger.totals(lines)
        func converted(_ byCurrency: [String: Decimal]) -> Decimal {
            // An amount with no rate is left out of the total; its own line still shows it in its currency.
            byCurrency.compactMap { currencies.convertToSelected($0.value, from: $0.key) }.reduce(0, +)
        }
        return SavingsSummary(
            lines: lines,
            currency: currencies.selectedCurrency,
            savedSoFar: converted(totals.savedSoFar),
            onTrack: converted(totals.onTrack),
            pauselyYearlyCost: pausely.flatMap { currencies.convertToSelected($0.annualCost, from: $0.currency) },
            pauselyCurrency: pausely?.currency
        )
    }
}
