import Foundation

/// The Savings Receipt: money Pausely helped keep, derived from the lifecycle event log.
///
/// Conservative on purpose. A cancellation avoids only the renewals the same renewal engine would
/// have charged (computed from the billing anchor), counted for the 12 months after the decision and
/// only while the subscription stays cancelled. "Saved so far" counts only charges whose day has
/// passed. Nothing is estimated from categories or averages, so every line can be checked.
enum SavingsLedger {

    /// How far ahead a cancellation counts.
    static let horizonMonths = 12

    struct Line: Identifiable, Equatable {
        /// The cancellation event this line comes from.
        let id: UUID
        let subscriptionId: UUID
        let name: String
        let currency: String
        let amountPerCharge: Decimal
        let frequency: BillingFrequency
        let cancelledOn: Date
        /// Set when the subscription became active again; no savings after that day.
        let endedOn: Date?
        /// Every charge this cancellation avoids inside the horizon, oldest first.
        let avoidedCharges: [Date]
        /// Avoided charges whose day has passed.
        let avoidedSoFar: [Date]

        var savedSoFar: Decimal { amountPerCharge * Decimal(avoidedSoFar.count) }
        var onTrack: Decimal { amountPerCharge * Decimal(avoidedCharges.count) }
        var isOngoing: Bool { endedOn == nil }
    }

    /// Lines in the order the cancellations happened.
    /// - Parameter excluding: subscriptions that never count, such as Pausely's own subscription.
    static func lines(from events: [LifecycleEvent], now: Date, calendar: Calendar = .current,
                      excluding: Set<UUID> = []) -> [Line] {
        let bySubscription = Dictionary(grouping: events.filter { !excluding.contains($0.subscriptionId) },
                                        by: \.subscriptionId)
        var lines: [Line] = []
        for (_, history) in bySubscription {
            var open: LifecycleEvent?
            for event in history.sorted(by: { $0.date < $1.date }) {
                switch event.kind {
                case .cancelled where open == nil:
                    open = event
                case .reactivated:
                    if let cancel = open {
                        lines.append(line(for: cancel, endedOn: event.date, now: now, calendar: calendar))
                        open = nil
                    }
                default:
                    break
                }
            }
            if let cancel = open {
                lines.append(line(for: cancel, endedOn: nil, now: now, calendar: calendar))
            }
        }
        return lines.sorted { ($0.cancelledOn, $0.id.uuidString) < ($1.cancelledOn, $1.id.uuidString) }
    }

    private static func line(for cancel: LifecycleEvent, endedOn: Date?, now: Date, calendar: Calendar) -> Line {
        var charges: [Date] = []
        if let anchor = cancel.anchorDate ?? cancel.renewalDate,
           let horizon = calendar.date(byAdding: .month, value: horizonMonths, to: cancel.date) {
            // A reactivation on a renewal day means that charge happened, so it is not counted.
            let end = endedOn.flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }.map { min($0, horizon) } ?? horizon
            charges = RenewalSchedule.renewals(anchor: anchor, frequency: cancel.frequency,
                                               after: cancel.date, through: end, calendar: calendar)
        }
        let today = calendar.startOfDay(for: now)
        return Line(
            id: cancel.id,
            subscriptionId: cancel.subscriptionId,
            name: cancel.subscriptionName,
            currency: cancel.currency,
            amountPerCharge: cancel.amount,
            frequency: cancel.frequency,
            cancelledOn: cancel.date,
            endedOn: endedOn,
            avoidedCharges: charges,
            avoidedSoFar: charges.filter { calendar.startOfDay(for: $0) <= today }
        )
    }

    /// Totals per currency; the caller converts them for display.
    static func totals(_ lines: [Line]) -> (savedSoFar: [String: Decimal], onTrack: [String: Decimal]) {
        var saved: [String: Decimal] = [:]
        var track: [String: Decimal] = [:]
        for line in lines {
            saved[line.currency, default: 0] += line.savedSoFar
            track[line.currency, default: 0] += line.onTrack
        }
        return (saved, track)
    }
}
