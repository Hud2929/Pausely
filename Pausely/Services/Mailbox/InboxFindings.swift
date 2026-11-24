import Foundation

/// A subscription a search of the person's email found, as the results screen lists it.
struct FoundSubscription: Identifiable, Equatable {
    let proven: ProvenSubscription

    /// Stable across a re-analysis (merchant, period, currency), so what was ticked stays ticked. A currency
    /// that was only assumed is left out: choosing another dollar for "$" unticked every row it relabelled
    /// (the rating of 2026-11-23).
    var id: String {
        guard proven.currencyAssumed else { return proven.id }
        return proven.id.split(separator: "|").dropLast().joined(separator: "|") + "|$"
    }
    var name: String { proven.name }
    var amount: Decimal { proven.amount }
    var currency: String { proven.currency }
    var billingFrequency: BillingFrequency { proven.frequency }

    /// A cancellation email came after the last charge: shown, never offered for import.
    var isCancelled: Bool { proven.status == .cancelled }
    /// Still charging as far as the receipts show.
    var isLive: Bool { proven.status != .likelyEnded && proven.status != .cancelled }
    /// A trial whose email didn't say what it costs afterwards.
    var priceUnknown: Bool { proven.status == .trial && proven.amount == 0 }

    /// The line this becomes on the person's list. The anchor is the day of the last charge the receipts
    /// show (a real date the renewal schedule rolls forward), never a date worked out from it.
    var line: TallyLine {
        TallyLine(name: name, category: SubscriptionCategory.matching(proven.category).displayName,
                  // What the next renewal charges, when an email said so: the reminder is about that charge.
                  amount: proven.comingAmount ?? amount, currency: currency, isConfirmed: true, frequency: billingFrequency,
                  // No date for one that may have ended: its old charge would make Home promise a next one.
                  anchor: proven.status == .trial || proven.status == .likelyEnded ? nil : (proven.lastChargeDate ?? proven.nextBillingDate),
                  trialEndsAt: proven.status == .trial ? proven.trialEndsOn : nil,
                  paymentMethod: proven.billedThrough)
    }
}

/// One receipt read during a search, shown while the search runs: who charged, how much, when.
struct ReceiptSeen: Identifiable, Equatable {
    var name: String
    var amount: Decimal
    var currency: String
    var date: Date
    var id: String { name.lowercased() }
}
