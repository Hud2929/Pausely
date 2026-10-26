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

    /// What this costs a year, in `currency`. Nil when its currency can't be converted.
    func annualCost(in currency: String, rates: CurrencyRates = CurrencyManager.shared.rates) -> Decimal? {
        rates.convert(annualCost, from: self.currency, to: currency)
    }

    /// The price of one charge in this subscription's own currency: "$15.49", "US$20.00".
    var chargeText: String { MoneyFormat.string(amount, currency) }
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
