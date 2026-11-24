import Foundation
import os.log

/// Adding up money that may be in different currencies. Every amount is converted to the target
/// currency first; nothing is ever added in its own currency next to another one.
enum MoneyMath {
    /// The sum of `items` in `currency`. An item whose currency can't be converted is left out and
    /// logged, because adding it unconverted would put a wrong number on screen.
    static func total<S: Sequence>(_ items: S, in currency: String, rates: CurrencyRates,
                                   amount: (S.Element) -> Decimal,
                                   currencyOf: (S.Element) -> String) -> Decimal {
        items.reduce(Decimal(0)) { sum, item in
            let value = amount(item)
            if value == 0 { return sum }
            guard let converted = rates.convert(value, from: currencyOf(item), to: currency) else {
                os_log("MoneyMath: no rate for %{public}@ → %{public}@; left out of a total",
                       log: .default, type: .error, currencyOf(item), currency)
                return sum
            }
            return sum + converted
        }
    }

    /// The exact sum of amounts that are all in `currency`, or nil when one of them is not. For a
    /// history of what one subscription charged: nothing is converted, because a rate from today
    /// applied to a charge from last spring would be a guess.
    static func exactTotal<S: Sequence>(_ items: S, allIn currency: String,
                                        amount: (S.Element) -> Decimal,
                                        currencyOf: (S.Element) -> String) -> Decimal? {
        var sum = Decimal(0)
        for item in items {
            guard currencyOf(item).caseInsensitiveCompare(currency) == .orderedSame else { return nil }
            sum += amount(item)
        }
        return sum
    }
}

extension Collection where Element == Subscription {
    /// The subscriptions that are charging: on, or in a trial that turns into a charge.
    /// Every total, count and "what you pay" on a screen, a widget, a Shortcut or an export starts
    /// from this list, so two of them can never disagree about the same subscriptions.
    var charging: [Subscription] { filter(\.renewsAutomatically) }

    /// True when adding these up in `currency` means converting at least one of them at an exchange
    /// rate. A total like that is an estimate, and every place that shows one marks it "≈"
    /// (`MoneyFormat.total`).
    func isConverted(to currency: String = CurrencyManager.shared.selectedCurrency) -> Bool {
        let display = MoneyFormat.normalizedCode(currency)
        return contains { MoneyFormat.normalizedCode($0.currency) != display }
    }
}

extension CurrencyManager {
    /// The rates every conversion uses: live rates where loaded, the built-in table elsewhere.
    var rates: CurrencyRates { ratesTable }
}

extension Subscription {
    /// What this costs a month, in `currency`. Nil when its currency can't be converted.
    func monthlyCost(in currency: String, rates: CurrencyRates = CurrencyManager.shared.rates) -> Decimal? {
        rates.convert(monthlyCost, from: self.currency, to: currency)
    }

    /// The person's share of one charge in this subscription's own currency: "$15.49", "US$20.00".
    var chargeText: String { MoneyFormat.string(effectiveAmount, currency) }

    /// The full plan price before splitting across multiple people.
    var fullChargeText: String { MoneyFormat.string(amount, currency) }
}

extension Sequence where Element == Subscription {
    /// Monthly cost of all of these, in `currency` (the user's display currency by default).
    func monthlyTotal(in currency: String = CurrencyManager.shared.selectedCurrency,
                      rates: CurrencyRates = CurrencyManager.shared.rates) -> Decimal {
        MoneyMath.total(self, in: currency, rates: rates, amount: \.monthlyCost, currencyOf: \.currency)
    }

    /// Yearly cost of all of these, in `currency` (the user's display currency by default).
    func annualTotal(in currency: String = CurrencyManager.shared.selectedCurrency,
                     rates: CurrencyRates = CurrencyManager.shared.rates) -> Decimal {
        MoneyMath.total(self, in: currency, rates: rates, amount: \.annualCost, currencyOf: \.currency)
    }
}
