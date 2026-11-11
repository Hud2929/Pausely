import Foundation
import Combine
import SwiftUI

// MARK: - Supporting Types

/// Represents the difficulty level of canceling a subscription
enum CancellationDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case veryHard = "Very Hard"
    
    var displayName: String { rawValue }
}

/// Pause duration options for services that support pausing
enum PauseDuration: Int, CaseIterable, Identifiable, Codable {
    case oneWeek = 7
    case twoWeeks = 14
    case oneMonth = 30
    case twoMonths = 60
    case threeMonths = 90
    case sixMonths = 180
    
    var id: Int { rawValue }
}


/// Types of support contact methods
enum SupportType: String, Codable {
    case phone = "phone"
    case chat = "chat"
    case email = "email"
    case webForm = "webForm"
}

/// Service category types
enum ServiceCategory: String, Codable, CaseIterable {
    case streaming = "Streaming"
    case music = "Music"
    case productivity = "Productivity"
    case storage = "Storage"
    case security = "Security"
    case gaming = "Gaming"
    case fitness = "Fitness"
    case food = "Food & Meal Kits"
    case news = "News & Media"
    case dating = "Dating"
    case shopping = "Shopping"
    case finance = "Finance"
    case education = "Education"
    case design = "Design & Creative"
    case communication = "Communication"
    case cloudComputing = "Cloud Computing"
    case aiTools = "AI & Productivity Tools"
    case other = "Other"
}

/// Support contact information
struct SupportContact: Codable, Identifiable {
    var id = UUID()
    let type: SupportType
    let value: String
    let label: String
    let hours: String?
    
    static func phone(_ number: String, label: String = "Support", hours: String? = nil) -> SupportContact {
        SupportContact(type: .phone, value: number, label: label, hours: hours)
    }
    
    static func chat(_ url: String, label: String = "Live Chat", hours: String? = nil) -> SupportContact {
        SupportContact(type: .chat, value: url, label: label, hours: hours)
    }
    
    static func email(_ address: String, label: String = "Email Support") -> SupportContact {
        SupportContact(type: .email, value: address, label: label, hours: nil)
    }
    
}

/// Represents a subscription service with all management details
struct SubscriptionService: Identifiable, Codable {
    let id: String
    let name: String
    let category: ServiceCategory
    let domain: String
    let cancelURL: String
    let pauseURL: String?
    let supportURL: String
    let contacts: [SupportContact]
    let canPause: Bool
    let pauseDurations: [PauseDuration]
    let difficulty: CancellationDifficulty
    let instructions: [CancellationStep]
    let aliases: [String]
    let averageMonthlyPrice: Double?
    
    var primaryContact: SupportContact? { contacts.first }
    var phoneNumber: String? { contacts.first { $0.type == .phone }?.value }
    var chatURL: String? { contacts.first { $0.type == .chat }?.value }
    
    init(
        id: String,
        name: String,
        category: ServiceCategory,
        domain: String,
        cancelURL: String,
        pauseURL: String? = nil,
        supportURL: String,
        contacts: [SupportContact] = [],
        canPause: Bool = false,
        pauseDurations: [PauseDuration] = [],
        difficulty: CancellationDifficulty = .medium,
        instructions: [CancellationStep] = [],
        aliases: [String] = [],
        averageMonthlyPrice: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.domain = domain
        self.cancelURL = cancelURL
        self.pauseURL = pauseURL
        self.supportURL = supportURL
        self.contacts = contacts
        self.canPause = canPause
        self.pauseDurations = pauseDurations.isEmpty && canPause ? [.oneMonth, .twoMonths, .threeMonths] : pauseDurations
        self.difficulty = difficulty
        self.instructions = instructions
        self.aliases = aliases
        self.averageMonthlyPrice = averageMonthlyPrice
    }
}

/// A step in the cancellation process
struct CancellationStep: Codable, Identifiable {
    var id = UUID()
    let order: Int
    let title: String
    let description: String
    let actionURL: String?
    let isCritical: Bool
    
    init(order: Int, title: String, description: String, actionURL: String? = nil, isCritical: Bool = false) {
        self.order = order
        self.title = title
        self.description = description
        self.actionURL = actionURL
        self.isCritical = isCritical
    }
}

/// Pause record for tracking paused subscriptions
struct PauseRecord: Identifiable, Codable {
    let id: UUID
    let subscriptionId: UUID
    let serviceId: String
    let startedAt: Date
    let endsAt: Date
    let reminderSet: Bool
    let reminderDate: Date?
    var status: PauseStatus
    
    enum PauseStatus: String, Codable {
        case active = "active"
        case ended = "ended"
        case cancelled = "cancelled"
    }
    
    var isExpired: Bool {
        Date() >= endsAt
    }
}

