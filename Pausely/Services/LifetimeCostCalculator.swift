import Foundation

/// Pure projection calculations for the Lifetime Cost card.
/// No SwiftUI dependencies — fully unit-testable.
struct LifetimeCostCalculator {

    /// Years used for the retirement projection throughout Pausely.
    static let retirementYears = 30

    /// Total cost if you keep a subscription for `years` years.
    /// Uses exact Decimal arithmetic: `monthly × 12 × years`.
    static func projectedCost(monthly: Decimal, years: Int) -> Decimal {
        monthly * 12 * Decimal(years)
    }

    /// Total cost if you keep a subscription until retirement (30 years).
    static func retirementCost(monthly: Decimal) -> Decimal {
        projectedCost(monthly: monthly, years: retirementYears)
    }

    /// Approximate daily cost using the ÷30 convention used throughout Pausely.
    /// Not calendar-accurate — intentionally consistent with `monthlyCost` display.
    static func dailyCost(monthly: Decimal) -> Decimal {
        monthly / 30
    }
}
