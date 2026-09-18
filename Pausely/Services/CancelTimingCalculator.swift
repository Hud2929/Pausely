import Foundation

/// Level of timing advice for cancelling a subscription.
enum CancelTimingLevel: Equatable {
    case good   // ≥85% of cycle consumed — great time to cancel
    case fair   // 50%–84% consumed
    case poor   // <50% consumed — just got billed
}

/// Advice returned by `CancelTimingCalculator.cancelAdvice(...)`.
struct CancelAdvice: Equatable {
    let text: String
    let level: CancelTimingLevel
}

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

    // MARK: - Value

    /// Portion of `monthlyCost` already consumed in this cycle.
    static func valueUsed(monthlyCost: Decimal, progress: Double) -> Decimal {
        monthlyCost * Decimal(progress)
    }

    /// Portion of `monthlyCost` remaining in this cycle.
    /// `valueUsed + valueRemaining` always equals `monthlyCost`.
    static func valueRemaining(monthlyCost: Decimal, progress: Double) -> Decimal {
        monthlyCost * Decimal(1 - progress)
    }

    // MARK: - Advice

    /// Human-readable cancellation advice and a timing level.
    static func cancelAdvice(daysUsed: Int, daysRemaining: Int, cycleDays: Int) -> CancelAdvice {
        let progress: Double = cycleDays > 0 ? Double(daysUsed) / Double(cycleDays) : 0
        let daysToWait = max(0, cycleDays / 2 - daysUsed)

        switch progress {
        case 0.85...:
            return CancelAdvice(
                text: "Great time to cancel — you've used most of this cycle.",
                level: .good
            )
        case 0.50..<0.85:
            let dayWord = daysRemaining == 1 ? "day" : "days"
            return CancelAdvice(
                text: "Decent timing — \(daysRemaining) \(dayWord) left in this cycle.",
                level: .fair
            )
        default:
            let dayWord = daysToWait == 1 ? "day" : "days"
            return CancelAdvice(
                text: "You just got billed — wait \(daysToWait) more \(dayWord) for better timing.",
                level: .poor
            )
        }
    }
}
