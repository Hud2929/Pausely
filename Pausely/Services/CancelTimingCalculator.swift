import Foundation

/// Pure calculation logic for the Cancel Timing card.
/// No SwiftUI dependencies — fully unit-testable.
struct CancelTimingCalculator {

    // MARK: - Cycle Length

    /// Number of days in a billing cycle for the given frequency.
    static func cycleDays(for frequency: BillingFrequency) -> Int {
        switch frequency {
        case .weekly:     return 7
        case .biweekly:   return 14
        case .monthly:    return 30
        case .quarterly:  return 91
        case .semiannual: return 182
        case .yearly:     return 365
        }
    }

    // MARK: - Progress

    /// Days elapsed since `lastBillingDate`, clamped to ≥0.
    /// Pass `today` for testing; defaults to `Date()`.
    static func daysUsed(from lastBillingDate: Date, today: Date = Date()) -> Int {
        let raw = Calendar.current.dateComponents([.day], from: lastBillingDate, to: today).day ?? 0
        return max(0, raw)
    }

    /// Fraction of the current billing cycle consumed, clamped to 0…1.
    /// Returns 0 when `lastBillingDate` is nil or `cycleDays` is 0.
    static func progress(lastBillingDate: Date?, cycleDays: Int, today: Date = Date()) -> Double {
        guard let last = lastBillingDate, cycleDays > 0 else { return 0 }
        let used = daysUsed(from: last, today: today)
        return min(1, Double(used) / Double(cycleDays))
    }
}
