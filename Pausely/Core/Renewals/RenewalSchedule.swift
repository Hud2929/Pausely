import Foundation

/// Computes renewal dates the way billing systems do (see LAGO_TAKEAWAYS.md).
///
/// The date the user entered is an ANCHOR that is never overwritten; every renewal is computed from it.
/// Month-based cycles add N whole months to the anchor itself, never to the previous renewal, so a
/// subscription that started on Jan 31 renews Feb 28 (or 29), then Mar 31, and never drifts to the 28th.
/// A Feb 29 yearly plan renews Feb 28 in common years and Feb 29 again in leap years.
///
/// Renewals are calendar days. They are returned at local noon so a later time-zone change of up to
/// about ±11 hours cannot move them to a different day, and comparisons with "now" behave on the day itself.
enum RenewalSchedule {

    /// The renewal on or after the calendar day of `day`. When the anchor is today or later, that is the anchor.
    static func nextRenewal(anchor: Date, frequency: BillingFrequency, onOrAfter day: Date,
                            calendar: Calendar = .current) -> Date {
        let anchorDay = calendar.startOfDay(for: anchor)
        let target = calendar.startOfDay(for: day)
        guard target > anchorDay else { return noon(anchorDay, calendar) }

        var k = estimatedCycles(from: anchorDay, to: target, frequency: frequency, calendar: calendar)
        // The estimate never overshoots; step forward until the occurrence reaches the target day.
        while occurrence(k, anchorDay: anchorDay, frequency: frequency, calendar: calendar) < target {
            k += 1
        }
        return noon(occurrence(k, anchorDay: anchorDay, frequency: frequency, calendar: calendar), calendar)
    }

    /// The next `count` renewals on or after `day`, oldest first.
    static func upcomingRenewals(anchor: Date, frequency: BillingFrequency, onOrAfter day: Date, count: Int,
                                 calendar: Calendar = .current) -> [Date] {
        guard count > 0 else { return [] }
        let first = nextRenewal(anchor: anchor, frequency: frequency, onOrAfter: day, calendar: calendar)
        let anchorDay = calendar.startOfDay(for: anchor)
        let firstDay = calendar.startOfDay(for: first)
        var k = estimatedCycles(from: anchorDay, to: firstDay, frequency: frequency, calendar: calendar)
        while occurrence(k, anchorDay: anchorDay, frequency: frequency, calendar: calendar) < firstDay { k += 1 }
        return (0..<count).map { noon(occurrence(k + $0, anchorDay: anchorDay, frequency: frequency, calendar: calendar), calendar) }
    }

    /// Renewal days strictly after `start` and on or before `end` (both compared as calendar days).
    /// Used to notice renewals that happened while the app was closed.
    static func renewals(anchor: Date, frequency: BillingFrequency, after start: Date, through end: Date,
                         calendar: Calendar = .current, limit: Int = 60) -> [Date] {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard endDay > startDay else { return [] }
        guard let dayAfterStart = calendar.date(byAdding: .day, value: 1, to: startDay) else { return [] }
        var result: [Date] = []
        for date in upcomingRenewals(anchor: anchor, frequency: frequency, onOrAfter: dayAfterStart, count: limit, calendar: calendar) {
            guard calendar.startOfDay(for: date) <= endDay else { break }
            result.append(date)
        }
        return result
    }

    // MARK: - Internals

    /// The k-th renewal day (k = 0 is the anchor), always computed from the anchor itself.
    static func occurrence(_ k: Int, anchorDay: Date, frequency: BillingFrequency, calendar: Calendar) -> Date {
        let added: Date?
        switch frequency.step {
        case .days(let n): added = calendar.date(byAdding: .day, value: n * k, to: anchorDay)
        case .months(let n): added = calendar.date(byAdding: .month, value: n * k, to: anchorDay)
        }
        return calendar.startOfDay(for: added ?? anchorDay)
    }

    /// A lower bound for the number of whole cycles between two days, so long histories need no loop.
    private static func estimatedCycles(from anchorDay: Date, to target: Date, frequency: BillingFrequency,
                                        calendar: Calendar) -> Int {
        switch frequency.step {
        case .days(let n):
            let days = calendar.dateComponents([.day], from: anchorDay, to: target).day ?? 0
            return max(0, days / n)
        case .months(let n):
            let months = calendar.dateComponents([.month], from: anchorDay, to: target).month ?? 0
            return max(0, months / n - 1)
        }
    }

    private static func noon(_ day: Date, _ calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }
}

extension BillingFrequency {
    enum Step: Equatable { case days(Int), months(Int) }

    /// The length of one billing cycle.
    var step: Step {
        switch self {
        case .weekly: return .days(7)
        case .biweekly: return .days(14)
        case .monthly: return .months(1)
        case .quarterly: return .months(3)
        case .semiannual: return .months(6)
        case .yearly: return .months(12)
        }
    }
}

extension Calendar {
    /// The same calendar day at local noon: how Pausely stores a date that is a day, not a moment.
    func noon(of date: Date) -> Date {
        self.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay(for: date)) ?? date
    }
}
