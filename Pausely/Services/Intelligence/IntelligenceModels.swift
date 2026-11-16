import Foundation

// MARK: - Receipt Signal
/// Compact, privacy-preserving facts extracted from ONE email on-device.
/// It deliberately contains no subject line and no body text — only what the engine needs.
struct ReceiptSignal: Codable, Equatable, Identifiable {
    var id: String                       // Message-ID header when known (same receipt in two inboxes = one), else provider id
    var date: Date
    var senderDomain: String
    var senderName: String
    var merchantHint: String?            // from a platform parser or product detection
    var platform: String                 // direct | apple | googleplay | stripe | paypal | paddle
    var kind: EmailKind
    var amount: Decimal?
    var currency: String?
    var cadenceHint: BillingFrequency?
    var trialDays: Int?
    var renewalLanguage: Bool
    var oneTimeLanguage: Bool
    var promotional: Bool
    /// Structured (schema.org) receipt data found in the email, when present.
    var markup: StructuredReceiptParser.Kind? = nil
    var hasUnsubscribe: Bool? = nil
    var bulkMail: Bool? = nil
    /// Inboxes (account ids) this receipt was found in. Empty for receipts saved before multiple inboxes.
    var sources: [String]? = nil
    /// The sender claims to be a known merchant, but the receiving server's checks say the message isn't
    /// signed by it: never trusted as proof of a subscription.
    var spoofSuspected: Bool? = nil
    /// What the plan costs once an introductory price ends ("$134.99 for 1 year, then $269.99/year").
    var nextAmount: Decimal? = nil
    /// The introductory price as stated, before tax, so the rise is measured like with like.
    var introAmount: Decimal? = nil
}

// MARK: - Output Models

struct ChargeEvidence: Codable, Equatable, Identifiable {
    var id: String
    var date: Date
    var amount: Decimal
    var currency: String
}

struct ProvenSubscription: Identifiable, Equatable {
    enum Status: Equatable {
        case active
        case trial
        case priceIncreased
        case likelyEnded
        case cancelled
    }

    enum Tier: Int, Comparable {
        case hidden = 0
        case review = 1      // shown under "Worth a look", never pre-selected
        case likely = 2      // shown, not pre-selected
        case confirmed = 3   // pre-selected
        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: String
    var name: String
    var merchantKey: String
    var category: String?
    var cancelURL: String?
    var amount: Decimal
    var currency: String
    var frequency: BillingFrequency
    var lastChargeDate: Date?
    var nextBillingDate: Date?
    var status: Status
    var score: Int
    var tier: Tier
    var evidence: [ChargeEvidence]
    var reasons: [String]
    var previousAmount: Decimal?
    var trialEndsOn: Date?
    var chargedAfterCancel: Bool = false

    var annualCost: Decimal { amount * ProvenSubscription.periodsPerYear(frequency) }
    var monthlyCost: Decimal { annualCost / 12 }

    static func periodsPerYear(_ f: BillingFrequency) -> Decimal {
        switch f {
        case .weekly: return 52
        case .biweekly: return 26
        case .monthly: return 12
        case .quarterly: return 4
        case .semiannual: return 2
        case .yearly: return 1
        }
    }
}

struct IntelligenceInsight: Identifiable, Equatable {
    enum Kind: Equatable { case priceIncrease, trialEnding, renewalSoon, likelyEnded, chargedAfterCancel, priceChangeNotice, paymentFailed }
    let id: String
    var kind: Kind
    var title: String
    var detail: String
    var subscriptionId: String?
    /// Positive = money the user could lose (or save) per year.
    var annualImpact: Decimal?
}

struct IntelligenceReport: Equatable {
    var subscriptions: [ProvenSubscription]
    var ignoredPurchaseGroups: Int
    var insights: [IntelligenceInsight]

    var active: [ProvenSubscription] {
        subscriptions.filter { $0.status != .likelyEnded && $0.status != .cancelled }
    }
    /// What the likely-or-better subscriptions cost a month in `currency`. A mailbox can hold
    /// receipts in several currencies, so each one is converted before adding.
    func monthlyTotal(in currency: String, rates: CurrencyRates = CurrencyManager.shared.rates) -> Decimal {
        MoneyMath.total(counted, in: currency, rates: rates,
                        amount: \.monthlyCost, currencyOf: \.currency)
    }

    /// True when that total holds a receipt in another currency than `currency`, so that part of
    /// it was worked out at an exchange rate. Such a total is an estimate and is marked "≈"
    /// wherever it is shown (`MoneyFormat.total`), like every other total in the app.
    func monthlyTotalIsConverted(to currency: String) -> Bool {
        let display = MoneyFormat.normalizedCode(currency)
        return counted.contains { $0.monthlyCost != 0 && MoneyFormat.normalizedCode($0.currency) != display }
    }

    /// The subscriptions a total counts: still running, and likely or better.
    private var counted: [ProvenSubscription] { active.filter { $0.tier >= .likely } }
}
