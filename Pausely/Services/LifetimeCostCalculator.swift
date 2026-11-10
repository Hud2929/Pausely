import Foundation

/// Pure projection calculations for the Lifetime Cost card.
/// No SwiftUI dependencies — fully unit-testable.
struct LifetimeCostCalculator {

    /// Total cost if you keep a subscription for `years` years.
    /// Uses exact Decimal arithmetic: `monthly × 12 × years`.
    static func projectedCost(monthly: Decimal, years: Int) -> Decimal {
        monthly * 12 * Decimal(years)
    }
}
