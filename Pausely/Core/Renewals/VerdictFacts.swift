import Foundation

/// Facts from the event log that a Renewal Verdict shows. Pure, so they can be tested.
enum VerdictFacts {

    /// When the user last chose to keep it.
    static func lastKept(for subscriptionId: UUID, events: [LifecycleEvent]) -> Date? {
        events.filter { $0.subscriptionId == subscriptionId && $0.kind == .kept }.map(\.date).max()
    }

    /// The renewal after `charge`, for "we'll ask again before …".
    static func renewal(after charge: Date, for sub: Subscription, calendar: Calendar = .current) -> Date? {
        guard let anchor = sub.nextBillingDate,
              let dayAfter = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: charge)) else { return nil }
        return RenewalSchedule.nextRenewal(anchor: anchor, frequency: sub.billingFrequency, onOrAfter: dayAfter, calendar: calendar)
    }
}
