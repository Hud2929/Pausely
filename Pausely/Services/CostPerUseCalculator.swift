import Foundation
import SwiftUI

// MARK: - Cost Per Use Calculator
/// Pure, unit-testable calculation engine for cost-per-use analytics.
/// All methods are static and stateless — they take inputs and return outputs.
struct CostPerUseCalculator {

    // MARK: - Value Score Thresholds
    static let greatValueThreshold: Double = 1.0 / 50.0   // > 50 hrs per $1
    static let fairValueThreshold: Double = 1.0 / 10.0    // 10-50 hrs per $1
    // < 10 hrs per $1 = poor value

    // MARK: - Core Calculations

    /// Calculate cost per hour for a subscription
    /// - Parameters:
    ///   - monthlyCost: The monthly cost of the subscription
    ///   - monthlyHoursUsed: Hours used in the current month
    /// - Returns: Cost per hour, or nil if hours is zero
    static func costPerHour(monthlyCost: Decimal, monthlyHoursUsed: Double) -> Decimal? {
        guard monthlyHoursUsed > 0 else { return nil }
        return monthlyCost / Decimal(monthlyHoursUsed)
    }

    /// Calculate cost per session for a subscription
    /// - Parameters:
    ///   - monthlyCost: The monthly cost of the subscription
    ///   - monthlySessions: Number of sessions in the current month
    /// - Returns: Cost per session, or nil if sessions is zero
    static func costPerSession(monthlyCost: Decimal, monthlySessions: Int) -> Decimal? {
        guard monthlySessions > 0 else { return nil }
        return monthlyCost / Decimal(monthlySessions)
    }

    /// Calculate a value score (0-100) based on cost-per-hour efficiency
    /// Higher score = better value (lower cost per hour of use)
    /// - Parameters:
    ///   - monthlyCost: The monthly cost
    ///   - monthlyHoursUsed: Hours used this month
    /// - Returns: Value score 0-100, or nil if data is missing
    static func valueScore(monthlyCost: Decimal, monthlyHoursUsed: Double) -> Double? {
        guard monthlyHoursUsed > 0 else { return nil }
        let costPerHourDouble = Double(truncating: (monthlyCost / Decimal(monthlyHoursUsed)) as NSNumber)
        // Score: 100 at $0/hr, decreasing as cost per hour increases
        // Formula: max(0, 100 - costPerHour * 5) gives reasonable spread
        let score = max(0, 100 - (costPerHourDouble * 5))
        return min(100, score)
    }

    /// Determine value tier based on cost-per-hour
    /// - Parameter costPerHour: The calculated cost per hour
    /// - Returns: Value tier classification
    static func valueTier(costPerHour: Decimal) -> ValueTier {
        let cph = Double(truncating: costPerHour as NSNumber)
        if cph <= greatValueThreshold {
            return .great
        } else if cph <= fairValueThreshold {
            return .fair
        } else {
            return .poor
        }
    }


    // MARK: - Subscription Efficiency Score


    // MARK: - Rankings

    /// Rank subscriptions by value (best to worst)
    /// - Parameters:
    ///   - subscriptions: All subscriptions
    ///   - usageProvider: Closure that returns monthly hours for a subscription name
    /// - Returns: Array of ranked results with scores
    static func rankedByValue(
        subscriptions: [Subscription],
        usageProvider: (String) -> Double?
    ) -> [CostPerUseResult] {
        subscriptions
            .filter { $0.status == .active }
            .compactMap { sub in
                guard let hours = usageProvider(sub.name), hours > 0 else {
                    return CostPerUseResult(
                        subscription: sub,
                        monthlyHoursUsed: 0,
                        costPerHour: nil,
                        costPerSession: nil,
                        valueScore: nil,
                        valueTier: .unknown,
                        sessions: 0,
                        hasUsageData: false
                    )
                }
                let cph = costPerHour(monthlyCost: sub.monthlyCost, monthlyHoursUsed: hours)
                let score = valueScore(monthlyCost: sub.monthlyCost, monthlyHoursUsed: hours)
                let tier: ValueTier
                if let cph = cph {
                    tier = valueTier(costPerHour: cph)
                } else {
                    tier = .unknown
                }
                return CostPerUseResult(
                    subscription: sub,
                    monthlyHoursUsed: hours,
                    costPerHour: cph,
                    costPerSession: nil,
                    valueScore: score,
                    valueTier: tier,
                    sessions: 0,
                    hasUsageData: true
                )
            }
            .sorted { lhs, rhs in
                // Sort by value score descending; unknown at bottom
                guard let lScore = lhs.valueScore else { return false }
                guard let rScore = rhs.valueScore else { return true }
                return lScore > rScore
            }
    }

    /// Get top N best value subscriptions
    static func bestValue(
        subscriptions: [Subscription],
        usageProvider: (String) -> Double?,
        limit: Int = 3
    ) -> [CostPerUseResult] {
        Array(rankedByValue(subscriptions: subscriptions, usageProvider: usageProvider).prefix(limit))
    }


    // MARK: - Comparison


    // MARK: - Trend Analysis


    // MARK: - Smart Alert Triggers


    // MARK: - Formatting Helpers

    /// Format a cost-per-hour value for display
    static func formatCostPerHour(_ value: Decimal, currencyCode: String) -> String {
        MoneyFormat.string(value, currencyCode)
    }

    /// Format hours for display
    static func formatHours(_ hours: Double) -> String {
        if hours == 0 { return "0h" }
        if hours < 1 {
            return "\(Int(hours * 60))m"
        } else if hours == floor(hours) {
            return "\(Int(hours))h"
        } else {
            return String(format: "%.1fh", hours)
        }
    }

    /// Format a value score for display
    static func formatValueScore(_ score: Double) -> String {
        return String(format: "%.0f", score)
    }
}

// MARK: - Supporting Types

enum ValueTier: String, CaseIterable {
    case great
    case fair
    case poor
    case unknown


    var swiftUIColor: SwiftUI.Color {
        switch self {
        case .great:   return .kept
        case .fair:    return .decide
        case .poor:    return .due
        case .unknown: return .inkTextFaint
        }
    }

    var label: String {
        switch self {
        case .great:   return "Great Value"
        case .fair:    return "Fair Value"
        case .poor:    return "Poor Value"
        case .unknown: return "No Data"
        }
    }

    var icon: String {
        switch self {
        case .great:   return "checkmark.seal.fill"
        case .fair:    return "exclamationmark.triangle.fill"
        case .poor:    return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

struct CostPerUseResult: Identifiable {
    let id = UUID()
    let subscription: Subscription
    let monthlyHoursUsed: Double
    let costPerHour: Decimal?
    let costPerSession: Decimal?
    let valueScore: Double?
    let valueTier: ValueTier
    let sessions: Int
    let hasUsageData: Bool


    var displayHoursUsed: String {
        CostPerUseCalculator.formatHours(monthlyHoursUsed)
    }

    var isWasted: Bool {
        monthlyHoursUsed == 0 && subscription.monthlyCost > 0 && hasUsageData
    }

}


