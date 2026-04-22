import Foundation
import SwiftUI

// MARK: - Neural Subscription Entity
/// Represents a subscription in the 4D spacetime continuum
struct NeuralSubscription: Identifiable, Codable, Equatable {
    let id: UUID
    var appName: String
    var appIcon: String // SF Symbol or asset name
    var serviceType: NeuralServiceType
    var billingCycle: NeuralBillingCycle
    var cost: Decimal
    var currency: String
    var nextBillingDate: Date
    var status: NeuralSubscriptionStatus
    var category: NeuralSubscriptionCategory
    var deepLinkURL: String?
    var metadata: SubscriptionMetadata
    var createdAt: Date
    var lastModified: Date
    
    // MARK: - Computed Properties
    var monthlyCost: Decimal {
        switch billingCycle {
        case .weekly: return cost * 4.33
        case .monthly: return cost
        case .quarterly: return cost / 3
        case .biannual: return cost / 6
        case .annual: return cost / 12
        case .lifetime: return 0
        }
    }
    
    var annualCost: Decimal {
        monthlyCost * 12
    }
    
    var daysUntilRenewal: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: nextBillingDate).day ?? 0
    }
    
    var urgencyLevel: UrgencyLevel {
        let days = daysUntilRenewal
        if days <= 1 { return .critical }
        if days <= 3 { return .high }
        if days <= 7 { return .medium }
        return .low
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        appName: String,
        appIcon: String = "app.fill",
        serviceType: NeuralServiceType,
        billingCycle: NeuralBillingCycle,
        cost: Decimal,
        currency: String = "USD",
        nextBillingDate: Date,
        status: NeuralSubscriptionStatus = .active,
        category: NeuralSubscriptionCategory,
        deepLinkURL: String? = nil,
        metadata: SubscriptionMetadata = SubscriptionMetadata()
    ) {
        self.id = id
        self.appName = appName
        self.appIcon = appIcon
        self.serviceType = serviceType
        self.billingCycle = billingCycle
        self.cost = cost
        self.currency = currency
        self.nextBillingDate = nextBillingDate
        self.status = status
        self.category = category
        self.deepLinkURL = deepLinkURL
        self.metadata = metadata
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

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

enum NeuralBillingCycle: String, Codable, CaseIterable {
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case quarterly = "QUARTERLY"
    case biannual = "BIANNUAL"
    case annual = "ANNUAL"
    case lifetime = "LIFETIME"
    
    var displayName: String {
        switch self {
        case .weekly: return "WEEK"
        case .monthly: return "MONTH"
        case .quarterly: return "QUARTER"
        case .biannual: return "6 MONTHS"
        case .annual: return "YEAR"
        case .lifetime: return "FOREVER"
        }
    }
    
    var interval: TimeInterval {
        switch self {
        case .weekly: return 7 * 24 * 3600
        case .monthly: return 30 * 24 * 3600
        case .quarterly: return 91 * 24 * 3600
        case .biannual: return 182 * 24 * 3600
        case .annual: return 365 * 24 * 3600
        case .lifetime: return 0
        }
    }
}

enum NeuralSubscriptionStatus: String, Codable, CaseIterable {
    case active = "ACTIVE"
    case paused = "PAUSED"
    case cancelled = "CANCELLED"
    case expired = "EXPIRED"
    case trialing = "TRIALING"
    case gracePeriod = "GRACE_PERIOD"
    
    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .expired: return "exclamationmark.circle.fill"
        case .trialing: return "sparkles"
        case .gracePeriod: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .green
        case .paused: return .orange
        case .cancelled: return .red
        case .expired: return .gray
        case .trialing: return .cyan
        case .gracePeriod: return .yellow
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

enum UrgencyLevel: String, CaseIterable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        }
    }
    
    var glowIntensity: Double {
        switch self {
        case .critical: return 1.0
        case .high: return 0.7
        case .medium: return 0.4
        case .low: return 0.2
        }
    }
    
    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark"
        case .low: return "info.circle"
        }
    }
    
    var title: String {
        switch self {
        case .critical: return "High Priority"
        case .high: return "Important"
        case .medium: return "Consider"
        case .low: return "Optional"
        }
    }
}

// MARK: - Metadata

struct SubscriptionMetadata: Codable, Equatable {
    var usageScore: Double? // 0-1 how much user uses this
    var satisfactionRating: Int? // 1-5 stars
    var cancellationDifficulty: NeuralCancellationDifficulty?
    var notes: String?
    var tags: [String]
    var autoDetected: Bool
    var detectionSource: DetectionSource?
    
    init(
        usageScore: Double? = nil,
        satisfactionRating: Int? = nil,
        cancellationDifficulty: NeuralCancellationDifficulty? = nil,
        notes: String? = nil,
        tags: [String] = [],
        autoDetected: Bool = false,
        detectionSource: DetectionSource? = nil
    ) {
        self.usageScore = usageScore
        self.satisfactionRating = satisfactionRating
        self.cancellationDifficulty = cancellationDifficulty
        self.notes = notes
        self.tags = tags
        self.autoDetected = autoDetected
        self.detectionSource = detectionSource
    }
}

enum NeuralCancellationDifficulty: String, Codable {
    case easy = "EASY"
    case medium = "MEDIUM"
    case hard = "HARD"
    case impossible = "IMPOSSIBLE"
}

enum DetectionSource: String, Codable {
    case screenTime = "SCREEN_TIME"
    case emailScan = "EMAIL_SCAN"
    case manual = "MANUAL"
    case importFile = "IMPORT_FILE"
    case appStore = "APP_STORE"
}

// MARK: - Neural Insights

struct NeuralInsight: Identifiable {
    let id = UUID()
    let type: NeuralInsightType
    let title: String
    let description: String
    let affectedSubscriptions: [UUID]
    let potentialSavings: Decimal?
    let action: InsightAction?
    let priority: Int
}

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

struct TemporalAnalytics {
    let totalMonthlySpend: Decimal
    let totalAnnualSpend: Decimal
    let projectedSavings: Decimal
    let subscriptionCount: Int
    let upcomingCharges: [UpcomingCharge]
    let categoryBreakdown: [CategoryBreakdown]
    let spendingTrend: SpendingTrend
}

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

struct SubscriptionDatabase {
    static let knownSubscriptions: [KnownSubscription] = [
        KnownSubscription(
            appName: "Netflix",
            appIcon: "tv.fill",
            serviceType: .streaming,
            category: .entertainment,
            deepLinkURL: "https://www.netflix.com/cancelplan",
            typicalCost: 15.49,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Spotify",
            appIcon: "music.note",
            serviceType: .music,
            category: .entertainment,
            deepLinkURL: "https://www.spotify.com/account/subscription",
            typicalCost: 10.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "YouTube Premium",
            appIcon: "play.rectangle.fill",
            serviceType: .streaming,
            category: .entertainment,
            deepLinkURL: "https://www.youtube.com/paid_memberships",
            typicalCost: 11.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Disney+",
            appIcon: "star.fill",
            serviceType: .streaming,
            category: .entertainment,
            deepLinkURL: "https://www.disneyplus.com/account",
            typicalCost: 10.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Apple TV+",
            appIcon: "appletv.fill",
            serviceType: .streaming,
            category: .entertainment,
            deepLinkURL: "https://tv.apple.com/settings",
            typicalCost: 6.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "HBO Max",
            appIcon: "play.tv.fill",
            serviceType: .streaming,
            category: .entertainment,
            deepLinkURL: "https://play.hbomax.com/manage-profile",
            typicalCost: 15.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Amazon Prime",
            appIcon: "cart.fill",
            serviceType: .streaming,
            category: .utility,
            deepLinkURL: "https://www.amazon.com/gp/primecentral",
            typicalCost: 14.99,
            cancellationDifficulty: NeuralCancellationDifficulty.medium
        ),
        KnownSubscription(
            appName: "Hulu",
            appIcon: "tv.fill",
            serviceType: .streaming,
            category: .entertainment,
            deepLinkURL: "https://www.hulu.com/account",
            typicalCost: 7.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Apple Music",
            appIcon: "music.note",
            serviceType: .music,
            category: .entertainment,
            deepLinkURL: "https://music.apple.com/account/settings",
            typicalCost: 10.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Tidal",
            appIcon: "waveform",
            serviceType: .music,
            category: .entertainment,
            deepLinkURL: "https://tidal.com/account",
            typicalCost: 10.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Headspace",
            appIcon: "brain.head.profile",
            serviceType: .fitness,
            category: .lifestyle,
            deepLinkURL: "https://www.headspace.com/account",
            typicalCost: 12.99,
            cancellationDifficulty: NeuralCancellationDifficulty.medium
        ),
        KnownSubscription(
            appName: "Calm",
            appIcon: "leaf.fill",
            serviceType: .fitness,
            category: .lifestyle,
            deepLinkURL: "https://www.calm.com/settings",
            typicalCost: 14.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Peloton",
            appIcon: "figure.run",
            serviceType: .fitness,
            category: .lifestyle,
            deepLinkURL: "https://www.onepeloton.com/membership",
            typicalCost: 44.00,
            cancellationDifficulty: NeuralCancellationDifficulty.hard
        ),
        KnownSubscription(
            appName: "Strava",
            appIcon: "figure.run",
            serviceType: .fitness,
            category: .lifestyle,
            deepLinkURL: "https://www.strava.com/settings",
            typicalCost: 11.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "MyFitnessPal",
            appIcon: "heart.fill",
            serviceType: .fitness,
            category: .lifestyle,
            deepLinkURL: "https://www.myfitnesspal.com/account/settings",
            typicalCost: 19.99,
            cancellationDifficulty: NeuralCancellationDifficulty.medium
        ),
        KnownSubscription(
            appName: "Duolingo Plus",
            appIcon: "character.bubble.fill",
            serviceType: .education,
            category: .lifestyle,
            deepLinkURL: "https://www.duolingo.com/settings",
            typicalCost: 6.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "LinkedIn Premium",
            appIcon: "person.fill.badge.plus",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://www.linkedin.com/premium/settings",
            typicalCost: 29.99,
            cancellationDifficulty: NeuralCancellationDifficulty.hard
        ),
        KnownSubscription(
            appName: "Notion",
            appIcon: "doc.text.fill",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://www.notion.so/settings",
            typicalCost: 10.00,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Adobe Creative Cloud",
            appIcon: "paintbrush.fill",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://account.adobe.com/plans",
            typicalCost: 54.99,
            cancellationDifficulty: NeuralCancellationDifficulty.hard
        ),
        KnownSubscription(
            appName: "Figma",
            appIcon: "wand.and.stars",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://www.figma.com/settings",
            typicalCost: 12.00,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Dropbox",
            appIcon: "icloud.fill",
            serviceType: .cloud,
            category: .utility,
            deepLinkURL: "https://www.dropbox.com/account/plan",
            typicalCost: 11.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "iCloud+",
            appIcon: "cloud.fill",
            serviceType: .cloud,
            category: .utility,
            deepLinkURL: "https://www.icloud.com/settings",
            typicalCost: 2.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Google One",
            appIcon: "icloud.fill",
            serviceType: .cloud,
            category: .utility,
            deepLinkURL: "https://one.google.com/storage",
            typicalCost: 1.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Microsoft 365",
            appIcon: "doc.text.fill",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://account.microsoft.com/services",
            typicalCost: 6.99,
            cancellationDifficulty: NeuralCancellationDifficulty.medium
        ),
        KnownSubscription(
            appName: "The New York Times",
            appIcon: "newspaper.fill",
            serviceType: .news,
            category: .entertainment,
            deepLinkURL: "https://www.nytimes.com/subscription",
            typicalCost: 17.00,
            cancellationDifficulty: NeuralCancellationDifficulty.hard
        ),
        KnownSubscription(
            appName: "Tinder Gold",
            appIcon: "heart.fill",
            serviceType: .dating,
            category: .lifestyle,
            deepLinkURL: "https://tinder.com/settings",
            typicalCost: 14.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Bumble Premium",
            appIcon: "hexagon.fill",
            serviceType: .dating,
            category: .lifestyle,
            deepLinkURL: "https://bumble.com/settings",
            typicalCost: 19.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "PlayStation Plus",
            appIcon: "gamecontroller.fill",
            serviceType: .gaming,
            category: .entertainment,
            deepLinkURL: "https://store.playstation.com/subscriptions",
            typicalCost: 9.99,
            cancellationDifficulty: NeuralCancellationDifficulty.medium
        ),
        KnownSubscription(
            appName: "Xbox Game Pass",
            appIcon: "gamecontroller.fill",
            serviceType: .gaming,
            category: .entertainment,
            deepLinkURL: "https://account.xbox.com/Subscriptions",
            typicalCost: 9.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Nintendo Switch Online",
            appIcon: "gamecontroller.fill",
            serviceType: .gaming,
            category: .entertainment,
            deepLinkURL: "https://accounts.nintendo.com/subscriptions",
            typicalCost: 3.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "YNAB",
            appIcon: "dollarsign.circle.fill",
            serviceType: .finance,
            category: .utility,
            deepLinkURL: "https://app.youneedabudget.com/settings",
            typicalCost: 14.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Truebill/Rocket Money",
            appIcon: "dollarsign.circle.fill",
            serviceType: .finance,
            category: .utility,
            deepLinkURL: "https://www.rocketmoney.com/account",
            typicalCost: 4.99,
            cancellationDifficulty: NeuralCancellationDifficulty.medium
        ),
        KnownSubscription(
            appName: "Patreon",
            appIcon: "heart.fill",
            serviceType: .other,
            category: .entertainment,
            deepLinkURL: "https://www.patreon.com/settings",
            typicalCost: 5.00,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "OnlyFans",
            appIcon: "person.fill",
            serviceType: .other,
            category: .entertainment,
            deepLinkURL: "https://onlyfans.com/my/subscribers",
            typicalCost: 10.00,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "ChatGPT Plus",
            appIcon: "bubble.left.fill",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://chat.openai.com/account",
            typicalCost: 20.00,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Midjourney",
            appIcon: "photo.fill",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://www.midjourney.com/account",
            typicalCost: 10.00,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Canva Pro",
            appIcon: "wand.and.stars",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://www.canva.com/settings",
            typicalCost: 12.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "Todoist",
            appIcon: "checkmark.circle.fill",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://todoist.com/app/settings",
            typicalCost: 4.00,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "LastPass",
            appIcon: "key.fill",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://www.lastpass.com/account",
            typicalCost: 3.00,
            cancellationDifficulty: NeuralCancellationDifficulty.medium
        ),
        KnownSubscription(
            appName: "1Password",
            appIcon: "key.fill",
            serviceType: .productivity,
            category: .utility,
            deepLinkURL: "https://my.1password.com/profile",
            typicalCost: 2.99,
            cancellationDifficulty: NeuralCancellationDifficulty.easy
        ),
        KnownSubscription(
            appName: "NordVPN",
            appIcon: "network",
            serviceType: .utility,
            category: .utility,
            deepLinkURL: "https://nordaccount.com/dashboard",
            typicalCost: 11.99,
            cancellationDifficulty: NeuralCancellationDifficulty.medium
        ),
        KnownSubscription(
            appName: "ExpressVPN",
            appIcon: "network",
            serviceType: .utility,
            category: .utility,
            deepLinkURL: "https://www.expressvpn.com/support",
            typicalCost: 12.95,
            cancellationDifficulty: NeuralCancellationDifficulty.medium
        )
    ]
}

struct KnownSubscription {
    let appName: String
    let appIcon: String
    let serviceType: NeuralServiceType
    let category: NeuralSubscriptionCategory
    let deepLinkURL: String?
    let typicalCost: Double
    let cancellationDifficulty: NeuralCancellationDifficulty
}
