import Foundation

struct Subscription: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let logoUrl: String?
    let category: String?
    let amount: Decimal
    let currency: String
    let billingFrequency: BillingFrequency
    let nextBillingDate: Date?
    let monthlyUsageMinutes: Int
    let costPerHour: Decimal?
    let roiScore: Decimal?
    let status: SubscriptionStatus
    let isDetected: Bool
    let canPause: Bool
    let pauseUrl: String?
    let pausedUntil: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case logoUrl = "logo_url"
        case category
        case amount
        case currency
        case billingFrequency = "billing_frequency"
        case nextBillingDate = "next_billing_date"
        case monthlyUsageMinutes = "monthly_usage_minutes"
        case costPerHour = "cost_per_hour"
        case roiScore = "roi_score"
        case status
        case isDetected = "is_detected"
        case canPause = "can_pause"
        case pauseUrl = "pause_url"
        case pausedUntil = "paused_until"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var displayCostPerHour: String {
        guard let cost = costPerHour else { return "N/A" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: cost as NSDecimalNumber) ?? "$0.00"
    }
    
    var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    var annualCost: Decimal {
        switch billingFrequency {
        case .monthly:
            return amount * 12
        case .yearly:
            return amount
        case .weekly:
            return amount * 52
        }
    }
}

enum BillingFrequency: String, Codable, CaseIterable {
    case monthly = "monthly"
    case yearly = "yearly"
    case weekly = "weekly"
    
    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .weekly: return "Weekly"
        }
    }
}

enum SubscriptionStatus: String, Codable {
    case active = "active"
    case paused = "paused"
    case cancelled = "cancelled"
    case trial = "trial"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .cancelled: return "Cancelled"
        case .trial: return "Trial"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .paused: return "yellow"
        case .cancelled: return "red"
        case .trial: return "blue"
        }
    }
}
