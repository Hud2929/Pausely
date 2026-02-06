import Foundation

struct UserPerk: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let sourceType: PerkSourceType
    let sourceName: String
    let perkName: String
    let serviceCategory: String?
    let estimatedValue: Decimal?
    let activationUrl: String?
    let activationCode: String?
    let isActivated: Bool
    let activatedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sourceType = "source_type"
        case sourceName = "source_name"
        case perkName = "perk_name"
        case serviceCategory = "service_category"
        case estimatedValue = "estimated_value"
        case activationUrl = "activation_url"
        case activationCode = "activation_code"
        case isActivated = "is_activated"
        case activatedAt = "activated_at"
        case createdAt = "created_at"
    }
}

enum PerkSourceType: String, Codable, CaseIterable {
    case creditCard = "credit_card"
    case employer = "employer"
    case library = "library"
    case insurance = "insurance"
    case membership = "membership"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .creditCard: return "Credit Card"
        case .employer: return "Employer"
        case .library: return "Library"
        case .insurance: return "Insurance"
        case .membership: return "Membership"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .creditCard: return "creditcard"
        case .employer: return "building.2"
        case .library: return "book"
        case .insurance: return "shield"
        case .membership: return "person.2"
        case .other: return "gift"
        }
    }
}

struct PerkOpportunity: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let subscriptionId: UUID
    let userPerkId: UUID
    let savingsAmount: Decimal?
    let isDismissed: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case subscriptionId = "subscription_id"
        case userPerkId = "user_perk_id"
        case savingsAmount = "savings_amount"
        case isDismissed = "is_dismissed"
        case createdAt = "created_at"
    }
}
