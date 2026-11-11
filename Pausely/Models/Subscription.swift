import Foundation
import SwiftUI

struct Subscription: Identifiable, Codable, Equatable {
    var id: UUID
    var userId: UUID?
    var name: String
    var bundleIdentifier: String?  // Bundle ID for Screen Time tracking
    var description: String?
    var logoUrl: String?
    var category: String?
    var amount: Decimal
    var currency: String
    var billingFrequency: BillingFrequency
    var nextBillingDate: Date?
    var monthlyUsageMinutes: Int
    var costPerHour: Decimal?
    var roiScore: Decimal?
    var wasteScore: Decimal?  // NEW: 0.0 = total waste, 1.0 = great value
    var notifyBeforeDays: Int  // NEW: Days before renewal to notify
    var trialEndsAt: Date?     // NEW: Trial expiration date
    var status: SubscriptionStatus
    var isDetected: Bool
    var canPause: Bool
    var pauseUrl: String?
    var pausedUntil: Date?
    var startDate: Date?       // Actual subscription start date (defaults to createdAt if nil)
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Tier & Price Override (Revolutionary Database)
    var selectedTier: PricingTier = .individual
    var userPriceUSD: Decimal?
    var isPriceOverridden: Bool = false


    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id, userId, name, bundleIdentifier, description, logoUrl, category, amount, currency
        case billingFrequency, nextBillingDate, monthlyUsageMinutes, costPerHour
        case roiScore, wasteScore, notifyBeforeDays, trialEndsAt, status, isDetected, canPause, pauseUrl, pausedUntil
        case createdAt, updatedAt
        case selectedTier, userPriceUSD, isPriceOverridden
    }
    
    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        bundleIdentifier: String? = nil,
        description: String? = nil,
        logoUrl: String? = nil,
        category: String? = nil,
        amount: Decimal,
        currency: String = CurrencyManager.shared.selectedCurrency,  // what the user pays in, unless told otherwise
        billingFrequency: BillingFrequency = .monthly,
        nextBillingDate: Date? = nil,
        monthlyUsageMinutes: Int = 0,
        costPerHour: Decimal? = nil,
        roiScore: Decimal? = nil,
        wasteScore: Decimal? = nil,
        notifyBeforeDays: Int = 3,
        trialEndsAt: Date? = nil,
        status: SubscriptionStatus = .active,
        isDetected: Bool = false,
        canPause: Bool = true,
        pauseUrl: String? = nil,
        pausedUntil: Date? = nil,
        startDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        selectedTier: PricingTier = .individual,
        userPriceUSD: Decimal? = nil,
        isPriceOverridden: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.description = description
        self.logoUrl = logoUrl
        self.category = category
        self.amount = amount
        self.currency = currency
        self.billingFrequency = billingFrequency
        self.nextBillingDate = nextBillingDate
        self.monthlyUsageMinutes = monthlyUsageMinutes
        self.costPerHour = costPerHour
        self.roiScore = roiScore
        self.wasteScore = wasteScore
        self.notifyBeforeDays = notifyBeforeDays
        self.trialEndsAt = trialEndsAt
        self.status = status
        self.isDetected = isDetected
        self.canPause = canPause
        self.pauseUrl = pauseUrl
        self.pausedUntil = pausedUntil
        self.startDate = startDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.selectedTier = selectedTier
        self.userPriceUSD = userPriceUSD
        self.isPriceOverridden = isPriceOverridden
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
    
    var lifetimeSpend: Decimal {
        let referenceDate = startDate ?? createdAt
        let monthsSinceStart = Date().timeIntervalSince(referenceDate) / (30.44 * 24 * 60 * 60)
        return monthlyCost * Decimal(monthsSinceStart)
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
    
    var isActive: Bool {
        status == .active
    }
    
    var isPaused: Bool {
        guard let pausedUntil = pausedUntil else { return false }
        return pausedUntil > Date()
    }

    /// Whether this subscription keeps charging on its own. Only these roll forward to the next cycle.
    var renewsAutomatically: Bool {
        (status == .active || status == .trial) && !isPaused
    }

    /// The next renewal. `nextBillingDate` is the anchor the user entered and is never overwritten;
    /// for a subscription that renews on its own, the next renewal is computed from that anchor, so a
    /// date that has passed rolls forward to the next cycle instead of sitting "overdue" forever.
    /// Paused, cancelled and expired subscriptions show the date exactly as entered.
    var calculatedNextBillingDate: Date? {
        nextRenewal(onOrAfter: Date())
    }

    func nextRenewal(onOrAfter day: Date, calendar: Calendar = .current) -> Date? {
        guard let anchor = nextBillingDate else { return nil }
        guard renewsAutomatically else { return anchor }
        return RenewalSchedule.nextRenewal(anchor: anchor, frequency: billingFrequency, onOrAfter: day, calendar: calendar)
    }

    var daysUntilRenewal: Int? {
        guard let nextDate = calculatedNextBillingDate else { return nil }
        let calendar = Calendar.current
        // Compare calendar days, not elapsed hours: 9 days away at 3pm must not read as "in 8 days".
        return calendar.calendarDays(from: Date(), to: nextDate)
    }
    
    
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ value: Decimal) -> String {
        MoneyFormat.string(value, currency)
    }

    // MARK: - StoreKit Integration

    // MARK: - Equatable
    
    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
        lhs.id == rhs.id
    }
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


