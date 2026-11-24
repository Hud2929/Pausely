import Foundation

struct Subscription: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var category: String?
    var amount: Decimal
    var currency: String
    var billingFrequency: BillingFrequency
    /// The renewal anchor: a day, not a moment (`BillingDay`).
    @SavedDay var nextBillingDate: Date?
    /// Days before a renewal to remind. 0 means no reminder.
    var notifyBeforeDays: Int
    /// The last day of a free trial: a day, not a moment.
    @SavedDay var trialEndsAt: Date?
    var status: SubscriptionStatus
    var createdAt: Date
    /// Optional user note (e.g. "Shared with Sarah", "Promo ends Oct").
    var notes: String?
    /// Card, bank, or store that bills this subscription (e.g. "Apple", "Visa ···4242").
    var paymentMethod: String?
    /// Number of people splitting this subscription (1 = just me, 2...20 = shared plan).
    var splitCount: Int {
        didSet {
            let clamped = max(1, min(20, splitCount))
            if splitCount != clamped { splitCount = clamped }
        }
    }

    // Every field here is read by a screen, the renewal engine or the export
    // (`SubscriptionFieldTests`). A copy saved by an earlier version holds more; the rest is ignored.
    enum CodingKeys: String, CodingKey {
        case id, name, category, amount, currency, billingFrequency, nextBillingDate
        case notifyBeforeDays, trialEndsAt, status, createdAt
        case notes, paymentMethod, splitCount
    }

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        amount: Decimal,
        currency: String = CurrencyManager.shared.selectedCurrency,  // what the user pays in, unless told otherwise
        billingFrequency: BillingFrequency = .monthly,
        nextBillingDate: Date? = nil,
        notifyBeforeDays: Int = 3,
        trialEndsAt: Date? = nil,
        status: SubscriptionStatus = .active,
        createdAt: Date = Date(),
        notes: String? = nil,
        paymentMethod: String? = nil,
        splitCount: Int = 1
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.amount = amount
        self.currency = currency
        self.billingFrequency = billingFrequency
        self.nextBillingDate = nextBillingDate
        self.notifyBeforeDays = notifyBeforeDays
        self.trialEndsAt = trialEndsAt
        self.status = status
        self.createdAt = createdAt
        self.notes = notes
        self.paymentMethod = paymentMethod
        self.splitCount = max(1, min(20, splitCount))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        amount = try c.decode(Decimal.self, forKey: .amount)
        currency = try c.decode(String.self, forKey: .currency)
        billingFrequency = try c.decode(BillingFrequency.self, forKey: .billingFrequency)
        _nextBillingDate = try c.decodeIfPresent(SavedDay.self, forKey: .nextBillingDate) ?? SavedDay(wrappedValue: nil)
        notifyBeforeDays = try c.decodeIfPresent(Int.self, forKey: .notifyBeforeDays) ?? 3
        _trialEndsAt = try c.decodeIfPresent(SavedDay.self, forKey: .trialEndsAt) ?? SavedDay(wrappedValue: nil)
        status = try c.decode(SubscriptionStatus.self, forKey: .status)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        paymentMethod = try c.decodeIfPresent(String.self, forKey: .paymentMethod)
        splitCount = max(1, min(20, try c.decodeIfPresent(Int.self, forKey: .splitCount) ?? 1))
    }

    init(name: String, price: Double, category: String, billingFrequency: BillingFrequency = .monthly) {
        self.init(
            name: name,
            category: category,
            amount: Decimal(price),
            billingFrequency: billingFrequency
        )
    }
    
    // MARK: - Display Properties

    /// The person's own share of one charge (`amount` when not shared, or `amount / splitCount` rounded
    /// to the currency's precision so displayed share and totals always agree).
    var effectiveAmount: Decimal {
        let people = max(1, splitCount)
        return people > 1 ? AmountText.rounded(amount / Decimal(people), currency: currency) : amount
    }
    
    var displayAmount: String {
        return formatCurrency(effectiveAmount)
    }

    /// The person's exact share of one charge, unrounded: what totals are worked out from. Rounded first, a
    /// $17.99 plan split two ways came to $108.00 a year instead of $107.94 (the rating of 2026-11-23).
    var exactShare: Decimal {
        amount / Decimal(max(1, splitCount))
    }

    /// What it costs over a year: the person's share times the number of charges in a year (a monthly plan
    /// charges 12 times). One definition, so every screen shows the same yearly number.
    var annualCost: Decimal {
        exactShare * ProvenSubscription.periodsPerYear(billingFrequency)
    }

    var monthlyCost: Decimal {
        switch billingFrequency {
        case .weekly:
            return exactShare * Decimal(52) / 12
        case .biweekly:
            return exactShare * Decimal(26) / 12
        case .monthly:
            return exactShare
        case .quarterly:
            return exactShare / 3
        case .semiannual:
            return exactShare / 6
        case .yearly:
            return exactShare / 12
        }
    }

    /// Whether this subscription keeps charging on its own. Only these roll forward to the next cycle.
    var renewsAutomatically: Bool {
        status == .active || status == .trial
    }

    /// The next renewal. `nextBillingDate` is the anchor the user entered and is never overwritten;
    /// for a subscription that renews on its own, the next renewal is computed from that anchor, so a
    /// date that has passed rolls forward to the next cycle instead of sitting "overdue" forever.
    /// Paused, cancelled and expired subscriptions show the date exactly as entered.
    var calculatedNextBillingDate: Date? {
        nextRenewal(onOrAfter: Date())
    }

    func nextRenewal(onOrAfter day: Date, calendar: Calendar = .billing) -> Date? {
        guard let anchor = nextBillingDate else { return nil }
        guard renewsAutomatically else { return anchor }
        return RenewalSchedule.nextRenewal(anchor: anchor, frequency: billingFrequency, onOrAfter: day, calendar: calendar)
    }

    var daysUntilRenewal: Int? {
        guard let nextDate = calculatedNextBillingDate else { return nil }
        let calendar = Calendar.billing
        // Compare calendar days, not elapsed hours: 9 days away at 3pm must not read as "in 8 days".
        return calendar.calendarDays(from: Date(), to: nextDate)
    }
    
    
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ value: Decimal) -> String {
        MoneyFormat.string(value, currency)
    }

    // MARK: - StoreKit Integration

}

// MARK: - Billing Frequency
enum BillingFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case semiannual = "semiannual"
    case yearly = "yearly"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .weekly: return L10n.string("Weekly")
        case .biweekly: return L10n.string("Every 2 weeks")
        case .monthly: return L10n.string("Monthly")
        case .quarterly: return L10n.string("Every 3 months")
        case .semiannual: return L10n.string("Every 6 months")
        case .yearly: return L10n.string("Yearly")
        }
    }
    
    var shortDisplay: String {
        switch self {
        case .weekly: return L10n.string("/wk")
        case .biweekly: return L10n.string("/2wk")
        case .monthly: return L10n.string("/mo")
        case .quarterly: return L10n.string("/3mo")
        case .semiannual: return L10n.string("/6mo")
        case .yearly: return L10n.string("/yr")
        }
    }

    /// Grammatically correct billing period label, e.g. "per month", "per year"
    var billingPeriodLabel: String {
        switch self {
        case .weekly:     return L10n.string("per week")
        case .biweekly:   return L10n.string("every 2 weeks")
        case .monthly:    return L10n.string("per month")
        case .quarterly:  return L10n.string("every 3 months")
        case .semiannual: return L10n.string("every 6 months")
        case .yearly:     return L10n.string("per year")
        }
    }

    /// A price with its period as one phrase ("$4.99 a month", "月¥500"). The words and their order
    /// come from the reader's language; a price and a period are never joined by hand.
    func priced(_ amount: String) -> String {
        switch self {
        case .weekly:     return L10n.string("\(amount) a week")
        case .biweekly:   return L10n.string("\(amount) every 2 weeks")
        case .monthly:    return L10n.string("\(amount) a month")
        case .quarterly:  return L10n.string("\(amount) every 3 months")
        case .semiannual: return L10n.string("\(amount) every 6 months")
        case .yearly:     return L10n.string("\(amount) a year")
        }
    }

    /// The compact form for a receipt line ("$4.99/mo"): price, slash, period reads the same way
    /// round in all six languages, so this is the one place the two are put side by side.
    func pricedShort(_ amount: String) -> String {
        "\(amount)\(shortDisplay)"
    }
}

// MARK: - Subscription Status
/// Where a subscription stands: charging, in a free trial that will turn into a charge, or cancelled.
enum SubscriptionStatus: String, Codable, CaseIterable {
    case active = "active"
    case cancelled = "cancelled"
    case trial = "trial"

    /// A status as it was saved, by this version or an earlier one. Earlier versions had two more.
    /// "Paused" paused nothing at the service, so that subscription is still charging; "expired" had
    /// stopped. Anything unknown counts as charging: better a reminder too many than a charge unseen.
    init(saved raw: String) {
        switch raw {
        case "cancelled", "expired": self = .cancelled
        case "trial": self = .trial
        default: self = .active
        }
    }

    init(from decoder: Decoder) throws {
        self.init(saved: try decoder.singleValueContainer().decode(String.self))
    }

    var displayName: String {
        switch self {
        case .active: return L10n.string("Active")
        case .cancelled: return L10n.string("Cancelled")
        case .trial: return L10n.string("Free trial")
        }
    }
}


