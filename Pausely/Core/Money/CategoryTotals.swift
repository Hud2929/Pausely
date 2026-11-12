import Foundation

/// What one category costs a month, in the display currency.
struct CategoryTotal: Identifiable, Equatable {
    /// The category as stored on its subscriptions, in its display form ("Entertainment").
    let category: String
    let amount: Decimal
    let count: Int

    var id: String { category }
}

extension Array where Element == Subscription {
    /// What is being paid for, added up by category, each converted from its own currency, largest first.
    /// "entertainment" (from the catalog) and "Entertainment" (from the edit screen) are one category.
    func categoryTotals(in currency: String, rates: CurrencyRates = CurrencyManager.shared.rates) -> [CategoryTotal] {
        return Dictionary(grouping: charging) { SubscriptionCategory.label(for: $0.category) }
            .map { CategoryTotal(category: $0.key, amount: $0.value.monthlyTotal(in: currency, rates: rates), count: $0.value.count) }
            .sorted { ($0.amount, $1.category) > ($1.amount, $0.category) }
    }
}
