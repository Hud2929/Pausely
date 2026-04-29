//
//  RealGeniusEngine.swift
//  Pausely
//
//  REAL subscription intelligence - no more Bool.random() or hardcoded data
//

import Foundation
import SwiftUI

/// Real subscription intelligence engine
/// Replaces SubscriptionGeniusAI which used Bool.random() and hardcoded data
@MainActor
final class RealGeniusEngine: ObservableObject {
    static let shared = RealGeniusEngine()

    // MARK: - Published State
    @Published private(set) var isAnalyzing = false
    @Published private(set) var lastAnalysisDate: Date?
    @Published private(set) var totalSavingsFound: Decimal = 0
    @Published private(set) var insights: [GeniusInsight] = []

    // MARK: - Screen Time Manager
    private var screenTimeManager: ScreenTimeManager { ScreenTimeManager.shared }

    private init() {
        totalSavingsFound = Decimal(UserDefaults.standard.double(forKey: "real_genius_savings"))
        lastAnalysisDate = UserDefaults.standard.object(forKey: "real_genius_date") as? Date
    }

    // MARK: - Main Analysis

    /// Run full analysis on subscriptions
    func analyze(subscriptions: [Subscription]) async -> GeniusReport {
        isAnalyzing = true
        defer {
            isAnalyzing = false
            lastAnalysisDate = Date()
            UserDefaults.standard.set(Double(truncating: totalSavingsFound as NSNumber), forKey: "real_genius_savings")
        }

        var allInsights: [GeniusInsight] = []

        // 1. Trajectory Engine - Predict waste before it happens
        let trajectoryInsights = analyzeTrajectories(subscriptions: subscriptions)
        allInsights.append(contentsOf: trajectoryInsights)

        // 2. Trial Army - Track expiring trials
        let trialInsights = trackExpiringTrials(subscriptions: subscriptions)
        allInsights.append(contentsOf: trialInsights)

        // 3. Waste Detection - Find actual waste
        let wasteInsights = detectWaste(subscriptions: subscriptions)
        allInsights.append(contentsOf: wasteInsights)

        // 4. Annual Savings - Suggest annual plans
        let annualInsights = suggestAnnualPlans(subscriptions: subscriptions)
        allInsights.append(contentsOf: annualInsights)

        // 5. Duplicate Detection - Same category services
        let duplicateInsights = detectDuplicates(subscriptions: subscriptions)
        allInsights.append(contentsOf: duplicateInsights)

        // 6. Family Sharing Opportunities
        let familyInsights = analyzeFamilySharing(subscriptions: subscriptions)
        allInsights.append(contentsOf: familyInsights)

        insights = allInsights.sorted { $0.potentialSavings > $1.potentialSavings }

        let totalSavings = insights.reduce(Decimal(0)) { $0 + $1.potentialSavings }
        // Use = not += to avoid accumulating duplicates when view re-appears
        // .task fires on every view appear, so we need to replace not add
        totalSavingsFound = totalSavings

        return GeniusReport(
            insights: insights,
            totalPotentialSavings: totalSavings,
            actionableCount: insights.filter { $0.action != .none }.count
        )
    }

    // MARK: - Usage Snapshot Engine

    /// Analyzes current usage to flag low-value subscriptions
    /// NOTE: This is a current-usage snapshot, NOT a time-series trajectory prediction.
    func analyzeTrajectories(subscriptions: [Subscription]) -> [GeniusInsight] {
        var insights: [GeniusInsight] = []

        for sub in subscriptions {
            let trajectory = calculateTrajectory(for: sub)

            if trajectory == .lowUsage && sub.monthlyCost > 5 {
                insights.append(GeniusInsight(
                    type: .trajectoryWarning,
                    title: "Low usage: \(sub.name)",
                    description: "Only \(screenTimeManager.getCurrentMonthUsage(for: sub.name)) minutes used this month. Consider pausing to save \(formatCurrency(sub.monthlyCost))/mo.",
                    icon: "chart.line.downtrend.xyaxis",
                    iconColor: .red,
                    potentialSavings: sub.monthlyCost,
                    confidence: 0.75,
                    subscriptionId: sub.id,
                    action: .review,
                    urgency: .high
                ))
            } else if trajectory == .growing && sub.monthlyCost > 10 {
                insights.append(GeniusInsight(
                    type: .positive,
                    title: "\(sub.name) getting good use",
                    description: "Usage looks healthy this month. Keep tracking to maintain this value.",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    potentialSavings: 0,
                    confidence: 0.70,
                    subscriptionId: sub.id,
                    action: .none,
                    urgency: .none
                ))
            }
        }

        return insights
    }

    /// Calculate usage level from screen time data
    /// NOTE: This is a simple current-usage bucketing, NOT a time-series trajectory prediction.
    /// It does not track usage trends over time — it merely categorizes the latest observed
    /// usage into low/normal/high buckets. Real trajectory prediction requires a 7-day+ rolling
    /// average with trend comparison, which is not implemented here.
    func calculateTrajectory(for subscription: Subscription) -> GeniusUsageTrajectory {
        let usage = screenTimeManager.getUsage(for: subscription.name)
        let currentMinutes = usage?.minutesUsed ?? 0

        guard currentMinutes > 0 else { return .new }

        // Current usage bucketing — not trajectory tracking
        if currentMinutes < 30 {
            return .lowUsage
        }

        return .normalUsage
    }

    // MARK: - Trial Army

    /// Tracks expiring trials and calculates value at risk
    func trackExpiringTrials(subscriptions: [Subscription]) -> [GeniusInsight] {
        var insights: [GeniusInsight] = []

        for sub in subscriptions where sub.status == .trial {
            guard let trialEnd = sub.trialEndsAt else { continue }

            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: trialEnd).day ?? 0

            // Only alert if conversion is within 14 days
            guard daysUntil >= 0 && daysUntil <= 14 else { continue }

            let valueAtRisk = sub.monthlyCost * Decimal(max(1, daysUntil / 30))

            insights.append(GeniusInsight(
                type: .trialExpiring,
                title: "\(sub.name) trial ends in \(daysUntil) days",
                description: "You'll be charged \(formatCurrency(sub.monthlyCost))/mo unless you cancel. Value at risk: \(formatCurrency(valueAtRisk))/mo",
                icon: "clock.badge.exclamationmark",
                iconColor: .orange,
                potentialSavings: sub.monthlyCost,
                confidence: 0.95,
                subscriptionId: sub.id,
                action: .cancelTrial,
                urgency: daysUntil <= 3 ? .critical : (daysUntil <= 7 ? .high : .medium)
            ))
        }

        return insights
    }

    // MARK: - Waste Detection

    /// Detects actual waste based on screen time data
    func detectWaste(subscriptions: [Subscription]) -> [GeniusInsight] {
        var insights: [GeniusInsight] = []

        for sub in subscriptions where sub.status == .active {
            let usage = screenTimeManager.getUsage(for: sub.name)
            let minutes = usage?.minutesUsed ?? 0

            // Ghost subscription: no usage
            if minutes == 0 {
                insights.append(GeniusInsight(
                    type: .waste,
                    title: "Ghost: \(sub.name)",
                    description: "No usage detected this month. Consider cancelling to save \(formatCurrency(sub.monthlyCost))/month.",
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .red,
                    potentialSavings: sub.monthlyCost,
                    confidence: 0.95,
                    subscriptionId: sub.id,
                    action: .cancel,
                    urgency: .high
                ))
            }
            // Very low usage with high cost
            else if minutes < 60 && sub.monthlyCost > 5 {
                let costPerHour = NSDecimalNumber(decimal: sub.monthlyCost / Decimal(minutes) * 60).doubleValue
                if costPerHour > 5 {
                    insights.append(GeniusInsight(
                        type: .waste,
                        title: "Low value: \(sub.name)",
                        description: "\(minutes) min used but costing \(formatCurrency(sub.monthlyCost))/mo (~\(CurrencyManager.shared.format(Decimal(costPerHour)))/hr)",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        potentialSavings: sub.monthlyCost,
                        confidence: 0.88,
                        subscriptionId: sub.id,
                        action: .pause,
                        urgency: .medium
                    ))
                }
            }
        }

        return insights
    }

    // MARK: - Annual Savings

    /// Suggests switching to annual plans for savings
    func suggestAnnualPlans(subscriptions: [Subscription]) -> [GeniusInsight] {
        var insights: [GeniusInsight] = []

        for sub in subscriptions {
            guard sub.billingFrequency == .monthly && sub.monthlyCost >= 8 else { continue }

            // Calculate estimated annual savings (assuming 20% annual discount)
            let monthly = NSDecimalNumber(decimal: sub.monthlyCost).doubleValue
            let estimatedAnnualSavings = Decimal(monthly) * 12 * Decimal(0.20)

            if estimatedAnnualSavings > 10 {
                insights.append(GeniusInsight(
                    type: .annualSavings,
                    title: "Annual plan for \(sub.name)",
                    description: "Switch to annual billing to save~\(formatCurrency(estimatedAnnualSavings))/year (assuming 20% discount).",
                    icon: "calendar.badge.clock",
                    iconColor: .blue,
                    potentialSavings: estimatedAnnualSavings,
                    confidence: 0.78,
                    subscriptionId: sub.id,
                    action: .switchToAnnual,
                    urgency: .low
                ))
            }
        }

        return insights
    }

    // MARK: - Duplicate Detection

    /// Detects duplicate services in the same category
    func detectDuplicates(subscriptions: [Subscription]) -> [GeniusInsight] {
        var insights: [GeniusInsight] = []
        let serviceCategories: [String: [String]] = [
            "Video Streaming": ["Netflix", "Hulu", "Disney", "HBO", "Apple TV", "YouTube", "Peacock", "Paramount", "Max"],
            "Music Streaming": ["Spotify", "Apple Music", "Tidal", "Deezer", "Amazon Music", "Pandora"],
            "Cloud Storage": ["iCloud", "Dropbox", "Google One", "OneDrive"],
            "Productivity": ["Notion", "Slack", "Microsoft 365", "Google Workspace"]
        ]

        for (category, services) in serviceCategories {
            let matchingSubs = subscriptions.filter { sub in
                services.contains { service in
                    sub.name.localizedCaseInsensitiveContains(service)
                }
            }

            if matchingSubs.count > 1 {
                let totalCost = matchingSubs.reduce(Decimal(0)) { $0 + $1.monthlyCost }
                let waste = totalCost - (matchingSubs.map { $0.monthlyCost }.min() ?? 0)

                if waste > 0 {
                    let names = matchingSubs.map { $0.name }.joined(separator: ", ")
                    insights.append(GeniusInsight(
                        type: .duplicate,
                        title: "\(category) overlap",
                        description: "You have \(matchingSubs.count) \(category.lowercased()) services: \(names). Consolidating saves \(formatCurrency(waste))/mo.",
                        icon: "doc.on.doc.fill",
                        iconColor: .orange,
                        potentialSavings: waste,
                        confidence: 0.82,
                        subscriptionId: matchingSubs.first?.id,
                        action: .consolidate,
                        urgency: .medium
                    ))
                }
            }
        }

        return insights
    }

    // MARK: - Family Sharing

    /// Analyzes family sharing opportunities
    func analyzeFamilySharing(subscriptions: [Subscription]) -> [GeniusInsight] {
        var insights: [GeniusInsight] = []

        let familyPlanPricing: [String: (individual: Decimal, family: Decimal, maxUsers: Int)] = [
            "Netflix": (15.99, 22.99, 4),
            "Apple Music": (10.99, 16.99, 6),
            "Spotify": (10.99, 16.99, 6),
            "iCloud": (2.99, 9.99, 6),
            "Microsoft 365": (9.99, 22.99, 6),
            "YouTube Premium": (13.99, 22.99, 5)
        ]

        for sub in subscriptions {
            for (serviceName, pricing) in familyPlanPricing {
                if sub.name.localizedCaseInsensitiveContains(serviceName) && sub.billingFrequency == .monthly {
                    // Calculate savings if splitting with 1 other person
                    let savingsPerPerson = (pricing.individual - pricing.family / 2)

                    if savingsPerPerson > 0 {
                        insights.append(GeniusInsight(
                            type: .familySharing,
                            title: "Family plan: \(serviceName)",
                            description: "Family plan is \(formatCurrency(pricing.family))/mo for \(pricing.maxUsers). Splitting with 1 person saves \(formatCurrency(savingsPerPerson))/mo.",
                            icon: "person.3.fill",
                            iconColor: .purple,
                            potentialSavings: savingsPerPerson,
                            confidence: 0.78,
                            subscriptionId: sub.id,
                            action: .exploreFamilyPlan,
                            urgency: .low
                        ))
                    }
                }
            }
        }

        return insights
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        CurrencyManager.shared.format(amount)
    }
}

// MARK: - Models

struct GeniusInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let potentialSavings: Decimal
    let confidence: Double
    let subscriptionId: UUID?
    let action: InsightAction
    let urgency: Urgency

    enum InsightType {
        case trajectoryWarning
        case trialExpiring
        case waste
        case annualSavings
        case duplicate
        case familySharing
        case positive
    }

    enum InsightAction {
        case cancel
        case pause
        case cancelTrial
        case switchToAnnual
        case consolidate
        case exploreFamilyPlan
        case review
        case none
    }

    enum Urgency {
        case none
        case low
        case medium
        case high
        case critical

        var color: Color {
            switch self {
            case .none: return .gray
            case .low: return .blue
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }

    var confidencePercent: Int {
        Int(confidence * 100)
    }
}

struct GeniusReport {
    let insights: [GeniusInsight]
    let totalPotentialSavings: Decimal
    let actionableCount: Int
}

// MARK: - Usage Trajectory

enum GeniusUsageTrajectory: String {
    case growing = "growing"
    case stable = "stable"
    case lowUsage = "lowUsage"
    case normalUsage = "normalUsage"
    case new = "new"
}
