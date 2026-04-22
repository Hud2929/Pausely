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
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Tier & Price Override (Revolutionary Database)
    var selectedTier: PricingTier = .individual
    var userPriceUSD: Decimal?
    var isPriceOverridden: Bool = false

    var effectivePriceUSD: Decimal {
        isPriceOverridden ? (userPriceUSD ?? amount) : amount
    }

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
        currency: String = "USD",
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
    
    var displayCostPerHour: String {
        guard let cost = costPerHour else { return "N/A" }
        return formatCurrency(cost)
    }
    
    var displayAmount: String {
        return formatCurrency(amount)
    }
    
    var displayAnnualCost: String {
        return formatCurrency(annualCost)
    }
    
    var annualCost: Decimal {
        switch billingFrequency {
        case .weekly:
            // Use precise multiplier: 52.14 weeks per year (365.25/7)
            return amount * Decimal(52.14)
        case .biweekly:
            // 26.07 biweekly periods per year
            return amount * Decimal(26.07)
        case .monthly:
            // 12.03 months per year
            return amount * Decimal(12.03)
        case .quarterly:
            return amount * 4
        case .semiannual:
            return amount * 2
        case .yearly:
            return amount
        }
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
        status == .paused
    }
    
    var daysUntilRenewal: Int? {
        guard let nextDate = nextBillingDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: nextDate)
        return components.day
    }
    
    var renewalStatus: RenewalStatus {
        guard let days = daysUntilRenewal else { return .unknown }
        
        if days < 0 {
            return .overdue
        } else if days == 0 {
            return .today
        } else if days <= 3 {
            return .soon(days: days)
        } else if days <= 7 {
            return .thisWeek(days: days)
        } else {
            return .upcoming(days: days)
        }
    }
    
    enum RenewalStatus {
        case unknown
        case overdue
        case today
        case soon(days: Int)
        case thisWeek(days: Int)
        case upcoming(days: Int)
        
        var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .overdue: return "Overdue"
            case .today: return "Today"
            case .soon(let days): return "\(days) day\(days == 1 ? "" : "s")"
            case .thisWeek(let days): return "\(days) days"
            case .upcoming(let days): return "\(days) days"
            }
        }
        
        var color: String {
            switch self {
            case .unknown: return "gray"
            case .overdue: return "red"
            case .today: return "orange"
            case .soon: return "yellow"
            case .thisWeek: return "blue"
            case .upcoming: return "green"
            }
        }
        
        var isUrgent: Bool {
            switch self {
            case .overdue, .today, .soon:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(currency) \(value)"
    }

    // MARK: - StoreKit Integration

    /// Known StoreKit product IDs for this app's premium subscriptions
    private static let storeKitProductIds: Set<String> = [
        "com.pausely.premium.monthly",
        "com.pausely.premium.annual",
        "com.pausely.premium.lifetime"
    ]

    /// Whether this subscription is managed by StoreKit (in-app purchase)
    /// Falls back to checking if we have a product ID match
    var isStoreKitManaged: Bool {
        // Check if this subscription's name matches our StoreKit products
        // In a full implementation, you'd store the product ID on the subscription
        if let description = description {
            return Self.storeKitProductIds.contains(description)
        }
        return false
    }

    /// Checks if this subscription can be managed through StoreKit APIs
    var canManageViaStoreKit: Bool {
        return isStoreKitManaged
    }

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
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        case .quarterly: return "Every 3 Months"
        case .semiannual: return "Every 6 Months"
        case .yearly: return "Yearly"
        }
    }
    
    var shortDisplay: String {
        switch self {
        case .weekly: return "/wk"
        case .biweekly: return "/2wk"
        case .monthly: return "/mo"
        case .quarterly: return "/3mo"
        case .semiannual: return "/6mo"
        case .yearly: return "/yr"
        }
    }
    
    var multiplierToMonthly: Decimal {
        switch self {
        case .weekly: return Decimal(52) / 12
        case .biweekly: return Decimal(26) / 12
        case .monthly: return 1
        case .quarterly: return Decimal(1) / 3
        case .semiannual: return Decimal(1) / 6
        case .yearly: return Decimal(1) / 12
        }
    }
    
    var multiplierToYearly: Decimal {
        switch self {
        case .weekly: return 52
        case .biweekly: return 26
        case .monthly: return 12
        case .quarterly: return 4
        case .semiannual: return 2
        case .yearly: return 1
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
    
    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .trial: return "clock.fill"
        case .expired: return "exclamationmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .paused: return "orange"
        case .cancelled: return "red"
        case .trial: return "blue"
        case .expired: return "gray"
        }
    }
}

// MARK: - Subscription Extensions
extension Subscription {
    func convertedTo(currency: String, rate: Decimal) -> Subscription {
        var converted = self
        converted.amount = amount * rate
        converted.currency = currency
        return converted
    }
    
    mutating func updateLastUsed() {
        // This would track usage for ROI calculations
        // For now, just update the timestamp
        updatedAt = Date()
    }
    
    mutating func calculateROI(usageMinutes: Int) {
        monthlyUsageMinutes = usageMinutes
        
        let monthlyHours = Decimal(usageMinutes) / 60
        if monthlyHours > 0 {
            costPerHour = monthlyCost / monthlyHours
            
            // Value Score: a normalized 0-100 score where lower cost-per-hour yields higher scores.
            // Formula: max(0, 100 - costPerHour * 10)
            // This is NOT a real financial ROI calculation. It is an approximation designed to
            // surface cost-per-use insights. True ROI = (value_received - cost) / cost requires
            // subjective value quantification not possible from screen time alone.
            let costPerHourDouble = Double(truncating: (costPerHour ?? 0) as NSDecimalNumber)
            let baseScore = max(0, 100 - (costPerHourDouble * 10))
            roiScore = Decimal(baseScore)
        }
        
        // Calculate waste score: usage relative to expected usage based on cost
        // Baseline: $1/month = 10 minutes expected usage.
        // NOTE: This 10 min/$ baseline is an industry approximation for casual app engagement.
        // It is not a universal truth — actual "reasonable" usage varies significantly by app
        // category (e.g., streaming vs. utility) and individual user behavior.
        let monthlyCostDouble = Double(truncating: monthlyCost as NSNumber)
        guard monthlyCostDouble > 0 else {
            // Free subscription has no waste
            wasteScore = 0
            return
        }
        let expectedMinutes = monthlyCostDouble * 10
        let score = min(Double(usageMinutes) / expectedMinutes, 1.0)
        wasteScore = Decimal(score)
    }
    
    /// Mark as cancelled (one-tap)
    mutating func markAsCancelled() {
        status = .cancelled
        updatedAt = Date()
    }
    
    /// Mark as paused (one-tap)
    mutating func markAsPaused(until date: Date) {
        status = .paused
        pausedUntil = date
        updatedAt = Date()
    }
    
    /// Resume from pause (one-tap)
    mutating func resume() {
        status = .active
        pausedUntil = nil
        updatedAt = Date()
    }
    
    // MARK: - Waste Level
    var wasteLevel: WasteLevel {
        guard let score = wasteScore else { return .unknown }
        let scoreDouble = Double(truncating: score as NSNumber)
        switch scoreDouble {
        case 0.0..<0.2:   return .critical
        case 0.2..<0.4:   return .high
        case 0.4..<0.6:   return .moderate
        case 0.6..<0.8:   return .low
        case 0.8...1.0:   return .none
        default:          return .unknown
        }
    }
    
    var wasteRecommendation: WasteRecommendation {
        switch wasteLevel {
        case .critical:  return .cancelImmediately
        case .high:      return .considerPausing
        case .moderate:  return .reviewUsage
        case .low:       return .goodValue
        case .none:      return .excellentValue
        case .unknown:   return .insufficientData
        }
    }
}

// MARK: - Waste Level
enum WasteLevel: String, CaseIterable {
    case critical, high, moderate, low, none, unknown
    
    var color: Color {
        switch self {
        case .critical:  return .semanticDestructive
        case .high:      return .semanticWarning
        case .moderate:  return Color(hex: "#F59E0B").opacity(0.7)
        case .low:       return .semanticSuccess.opacity(0.7)
        case .none:      return .semanticSuccess
        case .unknown:   return .obsidianTextTertiary
        }
    }
    
    var label: String {
        switch self {
        case .critical:  return "Unused"
        case .high:      return "Barely Used"
        case .moderate:  return "Light Use"
        case .low:       return "Regular Use"
        case .none:      return "Great Value"
        case .unknown:   return "Unknown"
        }
    }
}

// MARK: - Waste Recommendation
enum WasteRecommendation: String {
    case cancelImmediately
    case considerPausing
    case reviewUsage
    case goodValue
    case excellentValue
    case insufficientData
    
    var title: String {
        switch self {
        case .cancelImmediately:  return "💡 Cancel Immediately"
        case .considerPausing:    return "⏸️ Consider Pausing"
        case .reviewUsage:        return "📊 Review Usage"
        case .goodValue:          return "✅ Good Value"
        case .excellentValue:     return "🔥 Excellent Value"
        case .insufficientData:   return "📈 Track Usage"
        }
    }
    
    var message: String {
        switch self {
        case .cancelImmediately:
            return "You haven't used this in weeks. Cancel and save money."
        case .considerPausing:
            return "Low usage detected. Consider pausing until you need it."
        case .reviewUsage:
            return "Moderate usage. Track for another month to decide."
        case .goodValue:
            return "You're getting good value from this subscription."
        case .excellentValue:
            return "Great investment! You use this regularly."
        case .insufficientData:
            return "Add usage data to see your waste score."
        }
    }
}
