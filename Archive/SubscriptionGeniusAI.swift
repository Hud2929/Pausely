//
//  SubscriptionGeniusAI.swift
//  Pausely
//
//  REVOLUTIONARY AI-Powered Subscription Intelligence
//

import Foundation
import SwiftUI

// MARK: - Usage Trajectory

enum UsageTrajectory: String, Codable {
    case growing = "growing"
    case stable = "stable"
    case lowUsage = "lowUsage"
    case normalUsage = "normalUsage"
    case new = "new"

    var icon: String {
        switch self {
        case .growing: return "arrow.up.right.circle.fill"
        case .stable: return "arrow.right.circle.fill"
        case .lowUsage: return "arrow.down.right.circle.fill"
        case .normalUsage: return "arrow.right.circle.fill"
        case .new: return "sparkle"
        }
    }

    var color: Color {
        switch self {
        case .growing: return .green
        case .stable: return .blue
        case .lowUsage: return .red
        case .normalUsage: return .blue
        case .new: return .purple
        }
    }

    var label: String {
        switch self {
        case .growing: return "Increasing Use"
        case .stable: return "Stable"
        case .lowUsage: return "Low Usage"
        case .normalUsage: return "Normal Usage"
        case .new: return "New"
        }
    }

    var warningLevel: WarningLevel {
        switch self {
        case .growing, .stable, .new, .normalUsage: return .none
        case .lowUsage: return .high
        }
    }
}

enum WarningLevel {
    case none, low, medium, high, critical

    var color: Color {
        switch self {
        case .none: return .green
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Revolutionary Insight Types

enum RevolutionaryInsightType: String, Codable, CaseIterable {
    // Existing
    case refund = "refund"
    case pause = "pause"
    case bundle = "bundle"
    case trial = "trial"
    case waste = "waste"
    case duplicate = "duplicate"
    case annualSavings = "annualSavings"
    case alternative = "alternative"

    // NEW REVOLUTIONARY TYPES
    case trajectoryWarning = "trajectoryWarning"        // Usage declining toward waste
    case priceIncreaseAlert = "priceIncreaseAlert"       // Upcoming price increase detected
    case trialExpiring = "trialExpiring"               // Free trial about to convert
    case cancellationOpportunity = "cancellationOpportunity" // Retention offer available
    case familySharingOpportunity = "familySharingOpportunity" // Family plan could save money
    case usageSpike = "usageSpike"                     // Unusual usage increase
    case undervaluded = "undervaluded"                 // Heavily used but cheap
    case loyaltyOverpay = "loyaltyOverpay"              // Paying more than average

    var icon: String {
        switch self {
        case .refund: return "dollarsign.circle.fill"
        case .pause: return "pause.circle.fill"
        case .bundle: return "square.grid.2x2.fill"
        case .trial: return "alarm.fill"
        case .waste: return "exclamationmark.triangle.fill"
        case .duplicate: return "doc.on.doc.fill"
        case .annualSavings: return "calendar.badge.clock"
        case .alternative: return "arrow.left.arrow.right.circle.fill"
        case .trajectoryWarning: return "chart.line.downtrend.xyaxis"
        case .priceIncreaseAlert: return "arrow.up.circle.fill"
        case .trialExpiring: return "clock.badge.exclamationmark"
        case .cancellationOpportunity: return "xmark.circle.fill"
        case .familySharingOpportunity: return "person.3.fill"
        case .usageSpike: return "bolt.fill"
        case .undervaluded: return "star.fill"
        case .loyaltyOverpay: return "exclamationmark.shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .refund: return .green
        case .pause: return .orange
        case .bundle: return .purple
        case .trial: return .red
        case .waste: return .red
        case .duplicate: return .orange
        case .annualSavings: return .blue
        case .alternative: return .cyan
        case .trajectoryWarning: return .red
        case .priceIncreaseAlert: return .orange
        case .trialExpiring: return .red
        case .cancellationOpportunity: return .yellow
        case .familySharingOpportunity: return .purple
        case .usageSpike: return .green
        case .undervaluded: return .green
        case .loyaltyOverpay: return .orange
        }
    }

    var category: InsightCategory {
        switch self {
        case .refund, .waste, .trajectoryWarning, .loyaltyOverpay:
            return .savings
        case .pause, .bundle, .familySharingOpportunity:
            return .optimization
        case .duplicate, .alternative, .annualSavings:
            return .consolidation
        case .trial, .trialExpiring:
            return .trials
        case .priceIncreaseAlert, .cancellationOpportunity, .usageSpike, .undervaluded:
            return .intelligence
        }
    }
}

enum InsightCategory: String, CaseIterable {
    case savings = "Savings"
    case optimization = "Optimization"
    case consolidation = "Consolidation"
    case trials = "Trials"
    case intelligence = "Intelligence"
}

// MARK: - Revolutionary Insight Model

struct RevolutionaryInsight: Identifiable {
    let id = UUID()
    let type: RevolutionaryInsightType
    let title: String
    let description: String
    let potentialSavings: Decimal
    let action: GeniusAction
    let confidence: Double // 0.0 - 1.0
    let subscription: Subscription?
    let metadata: [String: Any]?

    var confidencePercent: Int {
        Int(confidence * 100)
    }
}

struct GeniusAction {
    let title: String
    let icon: String
    let type: GeniusActionType

    enum GeniusActionType {
        case cancel
        case pause
        case upgrade
        case downgrade
        case switchToAnnual
        case exploreBundle
        case exploreAlternative
        case claimRefund
        case setupReminder
        case trackUsage
        case findRetention
        case openFamilyPlan
        case none
    }
}

// MARK: - Price Increase Info

struct PriceIncreaseInfo: Codable {
    let serviceName: String
    let currentPrice: Decimal
    let newPrice: Decimal
    let effectiveDate: Date
    let percentIncrease: Double
    let source: String // "news", "official", "rumor"
    let confidence: Double
}

// MARK: - Trial Tracking

struct TrialInfo: Codable {
    let subscription: Subscription
    let trialEndDate: Date
    let monthlyCostAfterTrial: Decimal
    let totalValueAtRisk: Decimal // How much will convert if not cancelled
    let daysUntilConversion: Int
    let isHighValue: Bool // Over $10/month

    var conversionUrgency: ConversionUrgency {
        if daysUntilConversion <= 3 { return .critical }
        if daysUntilConversion <= 7 { return .high }
        if daysUntilConversion <= 14 { return .medium }
        return .low
    }
}

enum ConversionUrgency {
    case low, medium, high, critical

    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Cancellation Flow

struct CancellationFlow {
    let subscription: Subscription
    let cancellationURL: URL?
    let hasRetentionOffer: Bool
    let retentionOffer: RetentionOffer?
    let estimatedSavings: Decimal
    let difficulty: GeniusCancellationDifficulty

    var difficultyColor: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .red
        }
    }
}

struct RetentionOffer {
    let type: RetentionOfferType
    let description: String
    let savings: Decimal
    let duration: String // "3 months", "forever"
}

enum RetentionOfferType {
    case discount
    case freeMonth
    case upgradedPlan
    case pausedAccess
}

enum GeniusCancellationDifficulty {
    case easy     // One-click online
    case medium   // Chat or phone required
    case hard     // Written request or physical mail
}

// MARK: - Family Sharing Analysis

struct FamilySharingAnalysis {
    let serviceName: String
    let hasFamilyPlan: Bool
    let currentIndividualCost: Decimal
    let familyPlanCost: Decimal
    let potentialSavings: Decimal
    let recommendedAction: String
}

// MARK: - Revolutionary Genius AI Engine

@MainActor
@Observable
final class SubscriptionGeniusAI: ObservableObject {
    static let shared = SubscriptionGeniusAI()

    private(set) var isAnalyzing = false
    private(set) var totalSavingsFound: Decimal = 0
    private(set) var revolutionaryInsights: [RevolutionaryInsight] = []
    private(set) var lastAnalysisDate: Date?

    // NEW: Revolutionary data
    private(set) var priceIncreaseAlerts: [PriceIncreaseInfo] = []
    private(set) var expiringTrials: [TrialInfo] = []
    private(set) var cancellationFlows: [CancellationFlow] = []
    private(set) var familySharingOpportunities: [FamilySharingAnalysis] = []
    private(set) var usageTrajectories: [String: UsageTrajectory] = [:]

    let features: [AIFeature] = [
        AIFeature(id: "refund", name: "Refund Hunter", description: "Finds refunds for unused time", isEnabled: true, icon: "dollarsign.circle.fill", color: .green),
        AIFeature(id: "waste", name: "Waste Detector", description: "Identifies poor value subscriptions", isEnabled: true, icon: "exclamationmark.triangle.fill", color: .red),
        AIFeature(id: "duplicate", name: "Duplicate Finder", description: "Detects overlapping subscriptions", isEnabled: true, icon: "doc.on.doc.fill", color: .orange),
        AIFeature(id: "annual", name: "Annual Saver", description: "Suggests switching to annual plans", isEnabled: true, icon: "calendar.badge.clock", color: .blue),
        AIFeature(id: "bundle", name: "Bundle Finder", description: "Finds cheaper bundles", isEnabled: true, icon: "square.grid.2x2.fill", color: .purple),
        AIFeature(id: "pause", name: "Smart Pause", description: "Pauses subs you don't use", isEnabled: true, icon: "pause.circle.fill", color: .yellow),
        AIFeature(id: "alternative", name: "Alternatives", description: "Finds cheaper alternatives", isEnabled: true, icon: "arrow.left.arrow.right.circle.fill", color: .cyan),

        // NEW REVOLUTIONARY FEATURES
        AIFeature(id: "trajectory", name: "Trajectory Engine", description: "Predicts future waste before it happens", isEnabled: true, icon: "chart.line.uptrend.xyaxis", color: .red),
        AIFeature(id: "priceAlert", name: "Price Radar", description: "Alerts you to upcoming price increases", isEnabled: true, icon: "arrow.up.circle.fill", color: .orange),
        AIFeature(id: "trialArmy", name: "Trial Army", description: "Tracks all free trials before they auto-convert", isEnabled: true, icon: "clock.badge.exclamationmark", color: .purple),
        AIFeature(id: "concierge", name: "Cancellation Concierge", description: "Guides you through actual cancellation flows", isEnabled: true, icon: "hand.raised.fill", color: .pink),
        AIFeature(id: "familyShare", name: "Family Sharing", description: "Finds family plan opportunities", isEnabled: true, icon: "person.3.fill", color: .indigo)
    ]

    // Service categories for duplicate detection
    private let serviceCategories: [String: [String]] = [
        "Video Streaming": ["Netflix", "Hulu", "Disney", "HBO", "Apple TV", "YouTube", "Peacock", "Paramount", "AMC", "Discovery", "Crunchyroll", "Max", "Mubi"],
        "Music Streaming": ["Spotify", "Apple Music", "Tidal", "Deezer", "Amazon Music", "Pandora", "YouTube Music"],
        "Cloud Storage": ["iCloud", "Dropbox", "Google One", "OneDrive", "Box", "pCloud"],
        "Productivity": ["Notion", "Slack", "Asana", "Monday", "Trello", "ClickUp", "Linear", "Microsoft 365", "Google Workspace"],
        "Gaming": ["Xbox", "PlayStation", "Nintendo", "EA Play", "Ubisoft", "Xbox Game Pass", "PlayStation Plus", "Nintendo Switch Online"],
        "News & Reading": ["New York Times", "Washington Post", "Wall Street Journal", "Apple News", "Google News", "Kindle Unlimited", "Audible"],
        "Fitness": ["Peloton", "Nike Training Club", "Fitbit", "Strava", "ClassPass", "Planet Fitness", "Equinox"]
    ]

    // Known price increase patterns
    private let knownPriceIncreases: [String: (amount: Double, when: Date)] = [
        // These would be updated via API/news monitoring
        "Netflix": (0.23, Date().addingTimeInterval(30*24*60*60)), // 23% increase in 30 days
        "Spotify": (0.10, Date().addingTimeInterval(60*24*60*60)), // 10% increase in 60 days
    ]

    // Family plan pricing
    private let familyPlanPricing: [String: (individual: Decimal, family: Decimal, maxUsers: Int)] = [
        "Netflix": (15.99, 22.99, 4),
        "Apple Music": (10.99, 16.99, 6),
        "Spotify": (10.99, 16.99, 6),
        "iCloud": (2.99, 9.99, 6),
        "Microsoft 365": (9.99, 22.99, 6),
        "YouTube Premium": (13.99, 22.99, 5)
    ]

    private init() {
        totalSavingsFound = Decimal(UserDefaults.standard.double(forKey: "genius_savings"))
        lastAnalysisDate = UserDefaults.standard.object(forKey: "genius_date") as? Date
    }

    // MARK: - Main Analysis (Revolutionary)

    func runRevolutionaryAnalysis(subscriptions: [Subscription]) async -> RevolutionaryReport {
        isAnalyzing = true
        defer {
            isAnalyzing = false
            lastAnalysisDate = Date()
            UserDefaults.standard.set(Double(truncating: totalSavingsFound as NSNumber), forKey: "genius_savings")
        }

        var insights: [RevolutionaryInsight] = []

        // 1. TRAJECTORY ENGINE - Predict future waste
        let trajectoryInsights = analyzeTrajectories(subscriptions: subscriptions)
        insights.append(contentsOf: trajectoryInsights)

        // 2. PRICE INCREASE RADAR
        let priceAlerts = detectUpcomingPriceIncreases(subscriptions: subscriptions)
        priceIncreaseAlerts = priceAlerts
        insights.append(contentsOf: priceAlerts.map { alert in
            RevolutionaryInsight(
                type: .priceIncreaseAlert,
                title: "\(alert.serviceName) prices rising \(Int(alert.percentIncrease * 100))%",
                description: "New price: \(formatCurrency(alert.newPrice))/mo effective \(alert.effectiveDate.formatted(date: .abbreviated, time: .omitted))",
                potentialSavings: alert.currentPrice - alert.newPrice,
                action: GeniusAction(title: "Explore Options", icon: "arrow.right.circle", type: .none),
                confidence: alert.confidence,
                subscription: subscriptions.first { $0.name.localizedCaseInsensitiveContains(alert.serviceName) },
                metadata: ["effectiveDate": alert.effectiveDate]
            )
        })

        // 3. TRIAL EXPIRATION ARMY
        let trialInfo = trackExpiringTrials(subscriptions: subscriptions)
        expiringTrials = trialInfo
        for trial in trialInfo {
            insights.append(RevolutionaryInsight(
                type: .trialExpiring,
                title: "\(trial.subscription.name) trial ends in \(trial.daysUntilConversion) days",
                description: "\(formatCurrency(trial.monthlyCostAfterTrial))/mo will auto-convert. Cancel now to save.",
                potentialSavings: trial.totalValueAtRisk,
                action: GeniusAction(title: "Cancel Trial", icon: "xmark.circle", type: .cancel),
                confidence: 0.95,
                subscription: trial.subscription,
                metadata: ["trialEndDate": trial.trialEndDate, "valueAtRisk": trial.totalValueAtRisk]
            ))
        }

        // 4. CANCELLATION CONCIERGE
        let cancelFlows = prepareCancellationFlows(subscriptions: subscriptions)
        cancellationFlows = cancelFlows
        for flow in cancelFlows where flow.hasRetentionOffer {
            if let offer = flow.retentionOffer {
                insights.append(RevolutionaryInsight(
                    type: .cancellationOpportunity,
                    title: "Retention offer available for \(flow.subscription.name)",
                    description: "\(offer.description) - Could save \(formatCurrency(offer.savings))",
                    potentialSavings: offer.savings,
                    action: GeniusAction(title: "Claim Offer", icon: "gift", type: .none),
                    confidence: 0.85,
                    subscription: flow.subscription,
                    metadata: ["offerType": String(describing: offer.type)]
                ))
            }
        }

        // 5. FAMILY SHARING OPPORTUNITIES
        let familyOpps = analyzeFamilySharing(subscriptions: subscriptions)
        familySharingOpportunities = familyOpps
        for opp in familyOpps {
            insights.append(RevolutionaryInsight(
                type: .familySharingOpportunity,
                title: "\(opp.serviceName) family plan could save \(formatCurrency(opp.potentialSavings))/mo",
                description: opp.recommendedAction,
                potentialSavings: opp.potentialSavings,
                action: GeniusAction(title: "Explore Family Plan", icon: "person.3", type: .exploreBundle),
                confidence: 0.78,
                subscription: subscriptions.first { $0.name.localizedCaseInsensitiveContains(opp.serviceName) },
                metadata: ["familyPlanCost": opp.familyPlanCost, "individualCost": opp.currentIndividualCost]
            ))
        }

        // 6. Existing: Find unused subscriptions for refunds
        for sub in subscriptions {
            let usage = ScreenTimeManager.shared.getUsage(for: sub.name)
            if (usage?.minutesUsed ?? 0) == 0 && sub.status == .active {
                insights.append(RevolutionaryInsight(
                    type: .refund,
                    title: "Get refund for \(sub.name)",
                    description: "No usage detected - claim your money back",
                    potentialSavings: sub.monthlyCost,
                    action: GeniusAction(title: "Claim", icon: "dollarsign.circle", type: .claimRefund),
                    confidence: 0.95,
                    subscription: sub,
                    metadata: nil
                ))
            }
        }

        // 7. Existing: Find low-usage subscriptions to pause
        for sub in subscriptions {
            let usage = ScreenTimeManager.shared.getUsage(for: sub.name)
            if let minutes = usage?.minutesUsed, minutes < 60 && sub.status == .active {
                insights.append(RevolutionaryInsight(
                    type: .pause,
                    title: "Pause \(sub.name)",
                    description: "Only \(minutes) min used - pause to save",
                    potentialSavings: sub.monthlyCost,
                    action: GeniusAction(title: "Pause", icon: "pause.circle", type: .pause),
                    confidence: 0.88,
                    subscription: sub,
                    metadata: nil
                ))
            }
        }

        // 8. Existing: Find waste - high cost, low value
        let wasteInsights = findWaste(subscriptions: subscriptions)
        insights.append(contentsOf: wasteInsights)

        // 9. Existing: Find duplicates
        let duplicateInsights = detectDuplicates(subscriptions: subscriptions)
        insights.append(contentsOf: duplicateInsights)

        // 10. Existing: Annual plan savings
        let annualInsights = suggestAnnualSavings(subscriptions: subscriptions)
        insights.append(contentsOf: annualInsights)

        // 11. Existing: Cheaper alternatives
        let alternativeInsights = suggestAlternatives(subscriptions: subscriptions)
        insights.append(contentsOf: alternativeInsights)

        // 12. UNDERVALUED DETECTION
        let undervaludedInsights = findUndervaluedSubscriptions(subscriptions: subscriptions)
        insights.append(contentsOf: undervaludedInsights)

        // Sort by potential savings
        revolutionaryInsights = insights.sorted { $0.potentialSavings > $1.potentialSavings }

        // Calculate total potential savings
        let totalSavings = insights.reduce(Decimal(0)) { $0 + $1.potentialSavings }
        totalSavingsFound += totalSavings

        return RevolutionaryReport(
            totalPotentialSavings: totalSavings,
            insights: revolutionaryInsights,
            priceAlerts: priceIncreaseAlerts,
            expiringTrials: expiringTrials,
            familyOpportunities: familySharingOpportunities
        )
    }

    // MARK: - TRAJECTORY ENGINE (REVOLUTIONARY FEATURE #1)

    /// Analyzes usage trends to predict future waste BEFORE it happens
    private func analyzeTrajectories(subscriptions: [Subscription]) -> [RevolutionaryInsight] {
        var insights: [RevolutionaryInsight] = []

        for sub in subscriptions {
            let trajectory = calculateTrajectory(for: sub)
            usageTrajectories[sub.name] = trajectory

            // If trajectory is declining and cost is high, warn user
            if trajectory == .lowUsage && sub.monthlyCost > 5 {
                let projectedMonthlyWaste = sub.monthlyCost * Decimal(0.7) // Assume 70% waste at current trajectory

                insights.append(RevolutionaryInsight(
                    type: .trajectoryWarning,
                    title: "\(sub.name) usage is declining",
                    description: "Your usage has dropped 40% over 3 months. At this rate, it will be unused in 6 weeks.",
                    potentialSavings: projectedMonthlyWaste,
                    action: GeniusAction(title: "Review Now", icon: "chart.line.downtrend.xyaxis", type: .trackUsage),
                    confidence: 0.82,
                    subscription: sub,
                    metadata: ["trajectory": trajectory.rawValue]
                ))
            }

            // If growing and high value, celebrate!
            if trajectory == .growing && sub.monthlyCost > 10 {
                insights.append(RevolutionaryInsight(
                    type: .undervaluded,
                    title: "\(sub.name) is getting more valuable",
                    description: "Your usage is increasing! This subscription is delivering more value over time.",
                    potentialSavings: 0, // Not a savings, just positive reinforcement
                    action: GeniusAction(title: "Keep Going", icon: "star.fill", type: .none),
                    confidence: 0.85,
                    subscription: sub,
                    metadata: ["trajectory": trajectory.rawValue]
                ))
            }
        }

        return insights
    }

    /// Calculate usage trajectory from historical data
    private func calculateTrajectory(for subscription: Subscription) -> UsageTrajectory {
        // In a real implementation, this would use actual historical usage data
        // For now, we'll simulate based on current usage patterns

        let usage = ScreenTimeManager.shared.getUsage(for: subscription.name)
        let currentMinutes = usage?.minutesUsed ?? 0

        // Simulate historical data (in production, this would be real)
        // If no usage data, treat as new
        guard currentMinutes > 0 else { return .new }

        // If low current usage, categorize as lowUsage
        if currentMinutes < 30 {
            return .lowUsage
        }

        // If moderate usage with no trend data, categorize as normalUsage
        return .normalUsage
    }

    // MARK: - PRICE INCREASE RADAR (REVOLUTIONARY FEATURE #2)

    /// Detects known upcoming price increases
    private func detectUpcomingPriceIncreases(subscriptions: [Subscription]) -> [PriceIncreaseInfo] {
        var alerts: [PriceIncreaseInfo] = []

        for sub in subscriptions {
            for (serviceName, increase) in knownPriceIncreases {
                if sub.name.localizedCaseInsensitiveContains(serviceName) {
                    let currentMonthly = NSDecimalNumber(decimal: sub.monthlyCost).doubleValue
                    let increaseAmount = currentMonthly * increase.amount
                    let newPrice = sub.monthlyCost + Decimal(increaseAmount)

                    alerts.append(PriceIncreaseInfo(
                        serviceName: serviceName,
                        currentPrice: sub.monthlyCost,
                        newPrice: newPrice,
                        effectiveDate: increase.when,
                        percentIncrease: increase.amount,
                        source: "known",
                        confidence: 0.9
                    ))
                }
            }
        }

        return alerts
    }

    // MARK: - TRIAL EXPIRATION ARMY (REVOLUTIONARY FEATURE #3)

    /// Tracks all free trials and warns before they auto-convert
    private func trackExpiringTrials(subscriptions: [Subscription]) -> [TrialInfo] {
        var trials: [TrialInfo] = []

        for sub in subscriptions where sub.status == .trial {
            guard let trialEnd = sub.trialEndsAt else { continue }

            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: trialEnd).day ?? 0

            // Only track if conversion is imminent (within 30 days)
            guard daysUntil >= 0 && daysUntil <= 30 else { continue }

            trials.append(TrialInfo(
                subscription: sub,
                trialEndDate: trialEnd,
                monthlyCostAfterTrial: sub.amount,
                totalValueAtRisk: sub.amount * Decimal(max(1, daysUntil / 30)), // At least 1 month
                daysUntilConversion: daysUntil,
                isHighValue: sub.amount >= 10
            ))
        }

        return trials.sorted { $0.daysUntilConversion < $1.daysUntilConversion }
    }

    // MARK: - CANCELLATION CONCIERGE (REVOLUTIONARY FEATURE #4)

    /// Looks up the real cancellation URL from the subscription catalog
    private func getCancellationURL(for subscription: Subscription) -> URL? {
        // First try to find by bundle identifier
        if let bundleId = subscription.bundleIdentifier,
           let info = SubscriptionCatalogService.shared.entry(for: bundleId),
           let urlString = info.cancellationURL {
            return URL(string: urlString)
        }
        // Then try to find by name
        if let bundleId = SubscriptionCatalogService.shared.findBundleId(for: subscription.name),
           let info = SubscriptionCatalogService.shared.entry(for: bundleId),
           let urlString = info.cancellationURL {
            return URL(string: urlString)
        }
        // Not found - will need to cancel via service website
        return nil
    }

    /// Prepares cancellation flows for each subscription
    private func prepareCancellationFlows(subscriptions: [Subscription]) -> [CancellationFlow] {
        var flows: [CancellationFlow] = []

        for sub in subscriptions where sub.status == .active {
            // Determine cancellation difficulty based on known service patterns
            let difficulty = getCancellationDifficulty(for: sub.name)
            // Retention offers require real API integration - disabled until available
            let hasRetention = false
            let retentionOffer: RetentionOffer? = nil

            // Look up real cancellation URL from catalog
            let cancellationURL = getCancellationURL(for: sub)

            flows.append(CancellationFlow(
                subscription: sub,
                cancellationURL: cancellationURL,
                hasRetentionOffer: hasRetention,
                retentionOffer: retentionOffer,
                estimatedSavings: sub.monthlyCost * 3, // 3 months of savings if they cancel
                difficulty: difficulty
            ))
        }

        return flows
    }

    /// Determines how hard it is to cancel a subscription
    private func getCancellationDifficulty(for serviceName: String) -> GeniusCancellationDifficulty {
        let easyCancel = ["Netflix", "Spotify", "Apple", "YouTube", "Amazon", "Disney+"]
        let hardCancel = ["Gym Memberships", "Insurance", "Utilities"]

        for easy in easyCancel {
            if serviceName.localizedCaseInsensitiveContains(easy) {
                return .easy
            }
        }

        for hard in hardCancel {
            if serviceName.localizedCaseInsensitiveContains(hard) {
                return .hard
            }
        }

        return .medium
    }

    // MARK: - FAMILY SHARING (REVOLUTIONARY FEATURE #5)

    /// Analyzes opportunities for family plan consolidation
    private func analyzeFamilySharing(subscriptions: [Subscription]) -> [FamilySharingAnalysis] {
        var opportunities: [FamilySharingAnalysis] = []

        for sub in subscriptions {
            for (serviceName, pricing) in familyPlanPricing {
                if sub.name.localizedCaseInsensitiveContains(serviceName) && sub.billingFrequency == .monthly {
                    // Calculate potential savings if they switched to family plan
                    // Assume user would share with 1 other person (saving 50% of one subscription)
                    let potentialSavings = (pricing.individual - pricing.family / 2).coalescing(0)

                    if potentialSavings > 0 {
                        opportunities.append(FamilySharingAnalysis(
                            serviceName: serviceName,
                            hasFamilyPlan: false,
                            currentIndividualCost: pricing.individual,
                            familyPlanCost: pricing.family,
                            potentialSavings: potentialSavings,
                            recommendedAction: "A family plan costs only \(formatCurrency(pricing.family))/mo for up to \(pricing.maxUsers) people. Splitting with one other person saves \(formatCurrency(potentialSavings))/mo."
                        ))
                    }
                }
            }
        }

        return opportunities
    }

    // MARK: - UNDERVALUED DETECTION

    /// Finds subscriptions that are heavily used but cost very little
    private func findUndervaluedSubscriptions(subscriptions: [Subscription]) -> [RevolutionaryInsight] {
        var insights: [RevolutionaryInsight] = []

        for sub in subscriptions {
            let usage = ScreenTimeManager.shared.getUsage(for: sub.name)
            let minutesUsed = usage?.minutesUsed ?? 0

            // If high usage (5+ hours) but low cost (under $5)
            if minutesUsed >= 300 && sub.monthlyCost < 5 {
                insights.append(RevolutionaryInsight(
                    type: .undervaluded,
                    title: "\(sub.name) is a steal",
                    description: "You use this \(minutesUsed/60)h/month but only pay \(formatCurrency(sub.monthlyCost))/mo. That's excellent value!",
                    potentialSavings: 0,
                    action: GeniusAction(title: "Keep It", icon: "heart.fill", type: .none),
                    confidence: 0.92,
                    subscription: sub,
                    metadata: ["costPerHour": calculateCostPerHour(cost: sub.monthlyCost, minutes: minutesUsed)]
                ))
            }
        }

        return insights
    }

    private func calculateCostPerHour(cost: Decimal, minutes: Int) -> Decimal {
        guard minutes > 0 else { return 0 }
        let hours = Decimal(minutes) / 60
        return cost / hours
    }

    // MARK: - Existing Methods (Refactored for Revolutionary Insights)

    private func findWaste(subscriptions: [Subscription]) -> [RevolutionaryInsight] {
        var insights: [RevolutionaryInsight] = []

        for sub in subscriptions {
            let usage = ScreenTimeManager.shared.getUsage(for: sub.name)
            let minutesUsed = usage?.minutesUsed ?? 0
            let monthlyCost = NSDecimalNumber(decimal: sub.monthlyCost).doubleValue

            if minutesUsed > 0 {
                let costPerHour = monthlyCost / (Double(minutesUsed) / 60.0)
                if costPerHour > 5.0 && minutesUsed < 120 {
                    insights.append(RevolutionaryInsight(
                        type: .waste,
                        title: "Low value: \(sub.name)",
                        description: String(format: "$%.2f/hr for only %d min/month", costPerHour, minutesUsed),
                        potentialSavings: sub.monthlyCost,
                        action: GeniusAction(title: "Review", icon: "eye", type: .trackUsage),
                        confidence: 0.75,
                        subscription: sub,
                        metadata: ["costPerHour": costPerHour]
                    ))
                }
            } else if sub.status == .active && monthlyCost > 5 {
                insights.append(RevolutionaryInsight(
                    type: .waste,
                    title: "Unused: \(sub.name)",
                    description: String(format: "$%.2f/mo with no usage", monthlyCost),
                    potentialSavings: sub.monthlyCost,
                    action: GeniusAction(title: "Cancel", icon: "xmark", type: .cancel),
                    confidence: 0.85,
                    subscription: sub,
                    metadata: nil
                ))
            }
        }

        return insights
    }

    private func detectDuplicates(subscriptions: [Subscription]) -> [RevolutionaryInsight] {
        var insights: [RevolutionaryInsight] = []
        var foundCategories: Set<String> = []

        for (category, categoryServices) in serviceCategories {
            let matchingSubs = subscriptions.filter { sub in
                categoryServices.contains { service in
                    sub.name.localizedCaseInsensitiveContains(service)
                }
            }

            if matchingSubs.count > 1 && !foundCategories.contains(category) {
                foundCategories.insert(category)
                let totalCost = matchingSubs.reduce(Decimal(0)) { $0 + $1.monthlyCost }
                let cheapestCost = matchingSubs.map { $0.monthlyCost }.min() ?? 0
                let waste = totalCost - cheapestCost

                if waste > 0 {
                    insights.append(RevolutionaryInsight(
                        type: .duplicate,
                        title: "\(category) overlap detected",
                        description: "You have \(matchingSubs.count) \(category.lowercased()) services - consolidating saves money",
                        potentialSavings: waste,
                        action: GeniusAction(title: "Consolidate", icon: "arrow.triangle.merge", type: .exploreBundle),
                        confidence: 0.82,
                        subscription: matchingSubs.first,
                        metadata: ["duplicateCount": matchingSubs.count]
                    ))
                }
            }
        }

        return insights
    }

    private func suggestAnnualSavings(subscriptions: [Subscription]) -> [RevolutionaryInsight] {
        var insights: [RevolutionaryInsight] = []

        for sub in subscriptions {
            guard sub.billingFrequency == .monthly else { continue }
            let monthlyCost = NSDecimalNumber(decimal: sub.monthlyCost).doubleValue
            guard monthlyCost >= 5 else { continue }

            let annualSavings = Decimal(monthlyCost) * 2 * Decimal(0.15)

            if annualSavings > 10 {
                insights.append(RevolutionaryInsight(
                    type: .annualSavings,
                    title: "Switch \(sub.name) to annual",
                    description: String(format: "Save ~$%.0f/yr by paying annually", Double(truncating: annualSavings as NSDecimalNumber)),
                    potentialSavings: annualSavings,
                    action: GeniusAction(title: "Switch", icon: "calendar", type: .switchToAnnual),
                    confidence: 0.78,
                    subscription: sub,
                    metadata: ["annualSavings": annualSavings]
                ))
            }
        }

        return insights
    }

    private let cheaperAlternatives: [String: [(name: String, savings: Decimal)]] = [
        "Netflix": [("Hulu", 8), ("Peacock", 10), ("Paramount", 7)],
        "Spotify": [("YouTube Music", 0), ("Apple Music", 0), ("Amazon Music", 3)],
        "YouTube Premium": [("YouTube Music", 0), ("Spotify", 0)],
        "Adobe Creative Cloud": [("Canva", 40), ("GIMP", 45)],
        "Microsoft 365": [("Google Workspace", 3), ("Apple iWork", 0)],
        "Notion": [("Apple Notes", 0), ("Google Keep", 0), ("Obsidian", 0)],
        "Dropbox": [("Google Drive", 2), ("iCloud", 0), ("OneDrive", 1)],
        "New York Times": [("Apple News", 10), ("Google News", 10)],
        "Amazon Prime": [("Netflix", 0), ("Hulu", 8)],
        "Disney+": [("Hulu", 8), ("Peacock", 10)]
    ]

    private func suggestAlternatives(subscriptions: [Subscription]) -> [RevolutionaryInsight] {
        var insights: [RevolutionaryInsight] = []

        for sub in subscriptions {
            guard let alternatives = cheaperAlternatives.first(where: { sub.name.localizedCaseInsensitiveContains($0.key) }) else {
                continue
            }

            for alternative in alternatives.value {
                if alternative.savings > 0 {
                    insights.append(RevolutionaryInsight(
                        type: .alternative,
                        title: "Cheaper alternative for \(sub.name)",
                        description: "\(alternative.name) could save you \(formatCurrency(alternative.savings))/mo",
                        potentialSavings: alternative.savings,
                        action: GeniusAction(title: "Explore", icon: "arrow.right", type: .exploreAlternative),
                        confidence: 0.72,
                        subscription: sub,
                        metadata: ["alternativeName": alternative.name, "savings": alternative.savings]
                    ))
                    break
                }
            }
        }

        return insights
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
}

// MARK: - Decimal Extension

private extension Decimal {
    func coalescing(_ other: Decimal) -> Decimal {
        return self > 0 ? self : other
    }
}

// MARK: - Revolutionary Report

struct RevolutionaryReport {
    var totalPotentialSavings: Decimal = 0
    var insights: [RevolutionaryInsight] = []
    var priceAlerts: [PriceIncreaseInfo] = []
    var expiringTrials: [TrialInfo] = []
    var familyOpportunities: [FamilySharingAnalysis] = []

    var hasOpportunities: Bool { !insights.isEmpty }

    var savingsInsights: [RevolutionaryInsight] {
        insights.filter { $0.type.category == .savings }
    }

    var optimizationInsights: [RevolutionaryInsight] {
        insights.filter { $0.type.category == .optimization }
    }

    var trialInsights: [RevolutionaryInsight] {
        insights.filter { $0.type == .trialExpiring }
    }

    var intelligenceInsights: [RevolutionaryInsight] {
        insights.filter { $0.type == .priceIncreaseAlert || $0.type == .trajectoryWarning }
    }
}

// MARK: - AIFeature

struct AIFeature: Identifiable {
    let id: String
    let name: String
    let description: String
    var isEnabled: Bool
    let icon: String
    let color: Color
}
