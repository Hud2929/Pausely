import Foundation

/// What one category costs a month, in the display currency.
struct CategoryTotal: Identifiable, Equatable {
    /// The category as stored on its subscriptions, in its display form ("Entertainment").
    let category: String
    let amount: Decimal
    let count: Int
    /// Some of it is charged in another currency, so the amount is an estimate.
    var isConverted = false

    var id: String { category }
}

extension CategoryTotal {
    /// The name of the row that adds up what did not fit: shown as "Everything else".
    static let everythingElse = "\u{1F}everything else"
}

extension Array where Element == CategoryTotal {
    /// The list as a screen with room for `rows` shows it: the largest categories, and when there are
    /// more than fit, the rest added up in one last row, so the rows always add up to the whole.
    /// Insights showed the first five and dropped the others without a word.
    func fitted(to rows: Int) -> [CategoryTotal] {
        guard rows >= 2, count > rows else { return self }
        let rest = dropFirst(rows - 1)
        return prefix(rows - 1) + [CategoryTotal(category: CategoryTotal.everythingElse,
                                                amount: rest.reduce(0) { $0 + $1.amount },
                                                count: rest.reduce(0) { $0 + $1.count },
                                                isConverted: rest.contains(where: \.isConverted))]
    }
}

extension Array where Element == Subscription {
    /// What is being paid for, added up by category, each converted from its own currency, largest first.
    /// "entertainment" (from the catalog) and "Entertainment" (from the edit screen) are one category.
    func categoryTotals(in currency: String, rates: CurrencyRates = CurrencyManager.shared.rates) -> [CategoryTotal] {
        return Dictionary(grouping: charging) { SubscriptionCategory.label(for: $0.category) }
            .map { CategoryTotal(category: $0.key, amount: $0.value.monthlyTotal(in: currency, rates: rates), count: $0.value.count,
                                 isConverted: $0.value.isConverted(to: currency)) }
            .sorted { ($0.amount, $1.category) > ($1.amount, $0.category) }
    }
}
