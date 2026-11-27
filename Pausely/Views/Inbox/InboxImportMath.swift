import Foundation

/// The arithmetic of Find in Email: the slip's total, the free limit's split, and prices. Pure, and tested
/// in MailImportTests.
extension InboxImportView {
    /// What the slip adds up: the monthly cost of `found` in `currency`, each converted first, and whether
    /// any had to be, which marks the total "≈" (a mailbox of Canadian receipts read "¥16,027" to someone
    /// who sees yen, unmarked, on 2026-11-16).
    static func slipTotal(_ found: [FoundSubscription], in currency: String, rates: CurrencyRates) -> (monthly: Decimal, converted: Bool) {
        let display = MoneyFormat.normalizedCode(currency)
        let monthly = MoneyMath.total(found, in: currency, rates: rates, amount: { $0.proven.monthlyCost }, currencyOf: { $0.currency })
        return (monthly, found.contains { $0.proven.monthlyCost != 0 && MoneyFormat.normalizedCode($0.currency) != display })
    }

    /// The chosen ones the free list takes now and the ones that wait, ranked as `TallyImporter.add` ranks
    /// them: by yearly cost in the reader's currency.
    static func freeLimitSplit(_ chosen: [FoundSubscription], existing: [String], slots: Int,
                               in currency: String, rates: CurrencyRates) -> (add: [String], wait: [String]) {
        let plan = PendingTally.plan(lines: chosen.map(\.line), existingNames: existing, freeSlots: slots) { line in
            rates.convert(line.yearlyCost, from: line.currency, to: currency) ?? 0
        }
        return (plan.add.map(\.name), plan.wait.map(\.name))
    }

    static func names(_ list: [String]) -> String {
        list.formatted(.list(type: .and).locale(L10n.locale))
    }

    static func money(_ amount: Decimal, _ currency: String) -> String {
        MoneyFormat.string(amount, currency)
    }

    static func paywallContext(waiting: [TallyLine], existingChargingCount: Int, displayCurrency: String) -> PaywallContext {
        PaywallContext(
            trigger: .unlimitedSubscriptions,
            pendingWaitingLines: waiting,
            pendingTotalCount: existingChargingCount + waiting.count,
            pendingCurrency: displayCurrency
        )
    }
}
