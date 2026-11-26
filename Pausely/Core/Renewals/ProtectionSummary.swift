import Foundation

/// Factual summary of what Pausely is actively guarding right now, used on Pausely's own trial
/// verdict slip so the Pausely Promise weighs real ongoing protection during the 7-day trial
/// before renewals have had a chance to land on the Savings Receipt.
struct ProtectionSummary: Equatable {
    let watchedCount: Int
    /// Total yearly spend across watched subscriptions in `displayCurrency`, or `nil` if any
    /// subscription cannot be converted (never silently drops unknown currencies).
    let yearlySpend: Decimal?
    let displayCurrency: String
    let isConverted: Bool
    /// Soonest non-Pausely upcoming renewal or trial end within the next month, if dated.
    let nextCharge: Horizon.Charge?
    /// How many watched subscriptions exceed the free plan's limit.
    let overFreeLimitCount: Int

    static func current(subscriptions: [Subscription],
                        displayCurrency: String,
                        rates: CurrencyRates,
                        now: Date = Date(),
                        calendar: Calendar = .billing) -> ProtectionSummary {
        let watched = subscriptions.charging.filter { !$0.isPausely }
        let display = MoneyFormat.normalizedCode(displayCurrency)
        var yearly: Decimal? = watched.isEmpty ? nil : 0
        var converted = false

        for sub in watched {
            let subCode = MoneyFormat.normalizedCode(sub.currency)
            if subCode != display { converted = true }
            if let amount = rates.convert(sub.annualCost, from: sub.currency, to: display) {
                yearly = (yearly ?? 0) + amount
            } else {
                yearly = nil
                break
            }
        }

        let nextCharge = Horizon.charges(for: watched, now: now, calendar: calendar).first
        let freeCap = FreeTier.room(in: [])
        return ProtectionSummary(
            watchedCount: watched.count,
            yearlySpend: yearly,
            displayCurrency: displayCurrency,
            isConverted: converted,
            nextCharge: nextCharge,
            overFreeLimitCount: max(0, watched.count - freeCap)
        )
    }
}
