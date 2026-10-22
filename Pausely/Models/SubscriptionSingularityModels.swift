import Foundation
import SwiftUI


// MARK: - Enums

enum NeuralServiceType: String, Codable, CaseIterable {
    case streaming = "STREAMING"
    case music = "MUSIC"
    case productivity = "PRODUCTIVITY"
    case fitness = "FITNESS"
    case gaming = "GAMING"
    case news = "NEWS"
    case cloud = "CLOUD"
    case dating = "DATING"
    case education = "EDUCATION"
    case finance = "FINANCE"
    case utility = "UTILITY"
    case other = "OTHER"
    
    var icon: String {
        switch self {
        case .streaming: return "play.tv.fill"
        case .music: return "music.note"
        case .productivity: return "bolt.fill"
        case .fitness: return "figure.run"
        case .gaming: return "gamecontroller.fill"
        case .news: return "newspaper.fill"
        case .cloud: return "icloud.fill"
        case .dating: return "heart.fill"
        case .education: return "graduationcap.fill"
        case .finance: return "dollarsign.circle.fill"
        case .utility: return "network"
        case .other: return "app.fill"
        }
    }
    
    var color: String {
        switch self {
        case .streaming: return "FF3B30" // Red
        case .music: return "FF2D55" // Pink
        case .productivity: return "5856D6" // Purple
        case .fitness: return "34C759" // Green
        case .gaming: return "AF52DE" // Purple
        case .news: return "FF9500" // Orange
        case .cloud: return "007AFF" // Blue
        case .dating: return "FF2D55" // Pink
        case .education: return "5AC8FA" // Light Blue
        case .finance: return "4CD964" // Green
        case .utility: return "5AC8FA" // Light Blue
        case .other: return "8E8E93" // Gray
        }
    }
}


enum NeuralSubscriptionCategory: String, Codable, CaseIterable {
    case essential = "ESSENTIAL"
    case lifestyle = "LIFESTYLE"
    case entertainment = "ENTERTAINMENT"
    case utility = "UTILITY"
    case luxury = "LUXURY"
}


// MARK: - Metadata


enum NeuralCancellationDifficulty: String, Codable {
    case easy = "EASY"
    case medium = "MEDIUM"
    case hard = "HARD"
    case impossible = "IMPOSSIBLE"
}


// MARK: - Neural Insights


enum NeuralInsightType {
    case duplicate // You have overlapping subscriptions
    case unused // High cost, low usage
    case priceIncrease // Price went up
    case trialEnding // Free trial expires soon
    case betterAlternative // Cheaper alternative exists
    case bundleOpportunity // Could bundle with another service
    case seasonal // Seasonal usage pattern detected
}

enum InsightAction {
    case cancel(subscriptionId: UUID)
    case pause(subscriptionId: UUID)
    case compare(subscriptionIds: [UUID])
    case review(subscriptionId: UUID)
    case nothing
}

// MARK: - Temporal Analytics


struct UpcomingCharge: Identifiable {
    let id = UUID()
    let subscriptionId: UUID
    let appName: String
    let amount: Decimal
    let date: Date
    let daysUntil: Int
}

struct CategoryBreakdown: Identifiable {
    let id = UUID()
    let category: NeuralSubscriptionCategory
    let amount: Decimal
    let percentage: Double
    let count: Int
}

enum SpendingTrend {
    case increasing // Spending more than last month
    case decreasing // Spending less
    case stable // About the same
    case volatile // Unpredictable
}

// MARK: - Preset Subscription Database


