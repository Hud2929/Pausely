import Foundation

extension Subscription {
    /// Pausely's own subscription, which Pausely tracks like any other (see the Pausely Promise).
    var isPausely: Bool {
        bundleIdentifier == "com.pausely.app.Pausely" || name.caseInsensitiveCompare("Pausely Pro") == .orderedSame
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

    var isEmpty: Bool { lines.isEmpty }

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
            byCurrency.reduce(Decimal(0)) { $0 + currencies.convertToSelected($1.value, from: $1.key) }
        }
        return SavingsSummary(
            lines: lines,
            currency: currencies.selectedCurrency,
            savedSoFar: converted(totals.savedSoFar),
            onTrack: converted(totals.onTrack),
            pauselyYearlyCost: pausely.map { currencies.convertToSelected($0.annualCost, from: $0.currency) }
        )
    }
}
