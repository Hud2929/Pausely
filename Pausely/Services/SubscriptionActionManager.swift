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
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "yellow"
        case .hard: return "orange"
        case .veryHard: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "Can be cancelled online instantly"
        case .medium: return "May require a few clicks or confirmation"
        case .hard: return "Requires contacting support or multiple steps"
        case .veryHard: return "Phone call required or very difficult process"
        }
    }
    
    var estimatedMinutes: Int {
        switch self {
        case .easy: return 2
        case .medium: return 5
        case .hard: return 15
        case .veryHard: return 30
        }
    }
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
    
    var displayName: String {
        switch self {
        case .oneWeek: return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .oneMonth: return "1 Month"
        case .twoMonths: return "2 Months"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        }
    }
}

/// Data source for pause suggestions
enum PauseDataSource: String, Codable {
    case manual = "manual"
    case screenTime = "screenTime"
    case spending = "spending"
    case seasonal = "seasonal"
    case ai = "ai"
}

/// Pause suggestion for a subscription
struct PauseSuggestion: Identifiable {
    let id: UUID
    let subscription: Subscription
    let currentUsageMinutes: Int
    let monthlyCost: Decimal
    let costPerHour: Decimal
    let suggestedDuration: PauseDuration
    let potentialSavings: Decimal
    let reason: String
    let dataSource: PauseDataSource
    var urgencyLevel: UrgencyLevel
    
    init(id: UUID = UUID(), subscription: Subscription, currentUsageMinutes: Int, 
         monthlyCost: Decimal, costPerHour: Decimal, suggestedDuration: PauseDuration,
         potentialSavings: Decimal, reason: String, dataSource: PauseDataSource,
         urgencyLevel: UrgencyLevel? = nil) {
        self.id = id
        self.subscription = subscription
        self.currentUsageMinutes = currentUsageMinutes
        self.monthlyCost = monthlyCost
        self.costPerHour = costPerHour
        self.suggestedDuration = suggestedDuration
        self.potentialSavings = potentialSavings
        self.reason = reason
        self.dataSource = dataSource
        // Calculate urgency based on cost per hour if not provided
        self.urgencyLevel = urgencyLevel ?? PauseSuggestion.calculateUrgency(costPerHour: costPerHour)
    }
    
    private static func calculateUrgency(costPerHour: Decimal) -> UrgencyLevel {
        if costPerHour > 50 { return .critical }
        if costPerHour > 20 { return .high }
        if costPerHour > 10 { return .medium }
        return .low
    }
    
    /// Formatted savings string
    var formattedSavings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: potentialSavings as NSDecimalNumber) ?? "\(potentialSavings)"
    }
    
    /// Formatted usage string
    var formattedUsage: String {
        if currentUsageMinutes < 60 {
            return "\(currentUsageMinutes) min"
        } else {
            let hours = currentUsageMinutes / 60
            let mins = currentUsageMinutes % 60
            if mins == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(mins) min"
            }
        }
    }
    
    /// Formatted cost per hour string
    var formattedCostPerHour: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: costPerHour as NSDecimalNumber) ?? "\(costPerHour)"
    }
}

/// Types of support contact methods
enum SupportType: String, Codable {
    case phone = "phone"
    case chat = "chat"
    case email = "email"
    case webForm = "webForm"
    
    var icon: String {
        switch self {
        case .phone: return "phone.fill"
        case .chat: return "message.fill"
        case .email: return "envelope.fill"
        case .webForm: return "doc.text.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .phone: return "Call"
        case .chat: return "Chat"
        case .email: return "Email"
        case .webForm: return "Contact Form"
        }
    }
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
    case other = "Other"
    
    var icon: String {
        switch self {
        case .streaming: return "play.tv.fill"
        case .music: return "music.note"
        case .productivity: return "checkmark.square.fill"
        case .storage: return "cloud.fill"
        case .security: return "shield.fill"
        case .gaming: return "gamecontroller.fill"
        case .fitness: return "figure.run"
        case .food: return "fork.knife"
        case .news: return "newspaper.fill"
        case .dating: return "heart.fill"
        case .shopping: return "bag.fill"
        case .finance: return "dollarsign.circle.fill"
        case .education: return "book.fill"
        case .design: return "paintbrush.fill"
        case .communication: return "bubble.left.fill"
        case .cloudComputing: return "server.rack"
        case .other: return "app.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .streaming: return .red
        case .music: return .pink
        case .productivity: return .blue
        case .storage: return .cyan
        case .security: return .green
        case .gaming: return .purple
        case .fitness: return .orange
        case .food: return .red.opacity(0.8)
        case .news: return .gray
        case .dating: return .pink.opacity(0.8)
        case .shopping: return .yellow
        case .finance: return .green.opacity(0.8)
        case .education: return .indigo
        case .design: return .purple.opacity(0.8)
        case .communication: return .blue.opacity(0.8)
        case .cloudComputing: return .cyan.opacity(0.8)
        case .other: return .secondary
        }
    }
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
    
    static func webForm(_ url: String, label: String = "Contact Form") -> SupportContact {
        SupportContact(type: .webForm, value: url, label: label, hours: nil)
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

/// Alternative service option
struct AlternativeService: Identifiable, Codable {
    var id = UUID()
    let name: String
    let description: String
    let monthlyPrice: Double
    let annualPrice: Double?
    let features: [String]
    let pros: [String]
    let cons: [String]
    let websiteURL: String
    let rating: Double
    let category: ServiceCategory
    let savingsPercentage: Double?
    
    var annualCost: Double {
        annualPrice ?? monthlyPrice * 12
    }
    
    func calculateSavings(comparedTo currentMonthly: Double) -> Double {
        let currentAnnual = currentMonthly * 12
        return currentAnnual - annualCost
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
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endsAt)
        return max(0, components.day ?? 0)
    }
    
    var isExpired: Bool {
        Date() >= endsAt
    }
}

