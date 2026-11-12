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

    // Every field here is read by a screen, the renewal engine or the export
    // (`SubscriptionFieldTests`). A copy saved by an earlier version holds more; the rest is ignored.
    enum CodingKeys: String, CodingKey {
        case id, name, category, amount, currency, billingFrequency, nextBillingDate
        case notifyBeforeDays, trialEndsAt, status, createdAt
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
        createdAt: Date = Date()
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
    
    var displayAmount: String {
        return formatCurrency(amount)
    }

    /// What it costs over a year: the price times the number of charges in a year (a monthly plan
    /// charges 12 times). One definition, so every screen shows the same yearly number.
    var annualCost: Decimal {
        amount * ProvenSubscription.periodsPerYear(billingFrequency)
    }
    
    var monthlyCost: Decimal {
        switch billingFrequency {
        case .weekly:
            return amount * Decimal(52) / 12
        case .biweekly:
            return amount * Decimal(26) / 12
        case .monthly:
            return amount
        case .quarterly:
            return amount / 3
        case .semiannual:
            return amount / 6
        case .yearly:
            return amount / 12
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
        case .biweekly: return L10n.string("Every 2 Weeks")
        case .monthly: return L10n.string("Monthly")
        case .quarterly: return L10n.string("Every 3 Months")
        case .semiannual: return L10n.string("Every 6 Months")
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
    
    
}

// MARK: - Subscription Status
enum SubscriptionStatus: String, Codable, CaseIterable {
    case active = "active"
    case paused = "paused"
    case cancelled = "cancelled"
    case trial = "trial"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .cancelled: return "Cancelled"
        case .trial: return "Trial"
        case .expired: return "Expired"
        }
    }
}

// MARK: - Subscription Extensions
extension Subscription {
    
    
    
    

    
    // MARK: - Waste Level
    
}


