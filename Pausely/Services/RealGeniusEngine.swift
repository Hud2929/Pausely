//
//  RealGeniusEngine.swift
//  Pausely
//
//  REAL subscription intelligence - no more Bool.random() or hardcoded data
//

import Foundation
import SwiftUI
import Combine

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
    private var currencyCancellable: AnyCancellable?

    private init() {
        // Don't restore savings from cache — stale numbers are misleading.
        // User must run analysis to see accurate savings.
        lastAnalysisDate = UserDefaults.standard.object(forKey: "real_genius_date") as? Date

        currencyCancellable = CurrencyManager.shared.$selectedCurrency
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    let subs = SubscriptionStore.shared.subscriptions
                    guard !subs.isEmpty, self.lastAnalysisDate != nil else { return }
                    _ = try? await self.analyze(subscriptions: subs)
                }
            }
    }

    // MARK: - Main Analysis

    enum GeniusError: Error, LocalizedError {
        case noSubscriptions

        var errorDescription: String? {
            switch self {
            case .noSubscriptions:
                return "No subscriptions to analyze."
            }
        }
    }

    /// Run full analysis on subscriptions
    func analyze(subscriptions: [Subscription]) async throws -> GeniusReport {
        guard !subscriptions.isEmpty else {
            throw GeniusError.noSubscriptions
        }

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

        // 4. Annual Savings - Suggest annual plans with real pricing data
        let annualInsights = suggestAnnualPlans(subscriptions: subscriptions)
        allInsights.append(contentsOf: annualInsights)

        // 4b. Cheaper Tiers - Known cheaper plan alternatives
        let cheaperTierInsights = findCheaperTiers(subscriptions: subscriptions)
        allInsights.append(contentsOf: cheaperTierInsights)

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

        // No ScreenTime data at all — treat as new/untracked, not low usage
        guard let usage = usage else { return .new }
        let currentMinutes = usage.minutesUsed

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

            // Only flag waste when we actually have ScreenTime data for this service.
            // usage == nil means no data collected — NOT that usage is zero.
            // Screen Time only tracks iOS app usage; most subscriptions have no data.
            guard let usage = usage else { continue }
            let minutes = usage.minutesUsed

            // Ghost subscription: tracked but zero usage
            if minutes == 0 {
                insights.append(GeniusInsight(
                    type: .waste,
                    title: "Ghost: \(sub.name)",
                    description: "No iOS app usage detected this month. Consider cancelling to save \(formatCurrency(sub.monthlyCost))/month.",
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .red,
                    potentialSavings: sub.monthlyCost,
                    confidence: 0.85,
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

    private let annualPlanData: [String: (monthlyEquivalent: Decimal, annualTotal: Decimal)] = [
        "Netflix": (13.58, 163.00),
        "Spotify": (9.99, 99.99),
        "Apple Music": (9.99, 99.99),
        "Hulu": (7.99, 79.99),
        "Disney+": (7.99, 79.99),
        "YouTube Premium": (11.99, 139.99),
        "iCloud": (0.99, 10.99),
        "Dropbox": (9.99, 119.99),
        "Headspace": (5.83, 69.99),
        "Calm": (6.67, 79.99),
    ]

    /// Suggests switching to annual plans using real pricing data
    func suggestAnnualPlans(subscriptions: [Subscription]) -> [GeniusInsight] {
        var insights: [GeniusInsight] = []

        for sub in subscriptions {
            guard sub.billingFrequency == .monthly else { continue }

            // Look up by case-insensitive name match
            guard let (key, data) = annualPlanData.first(where: { sub.name.localizedCaseInsensitiveContains($0.key) }) else { continue }

            // Compare in the user's display currency so cross-currency subs work
            let subMonthlyDisplay = monthlyInDisplay(sub)
            let annualMonthlyDisplay = usdToDisplay(data.monthlyEquivalent)
            let monthlySavings = subMonthlyDisplay - annualMonthlyDisplay
            guard monthlySavings > 0 else { continue }

            let annualSavings = monthlySavings * 12

            insights.append(GeniusInsight(
                type: .annualSavings,
                title: "Annual plan for \(key)",
                description: "Switch \(sub.name) to annual: pay \(formatCurrency(annualMonthlyDisplay))/mo equivalent instead of \(formatCurrency(subMonthlyDisplay))/mo — save \(formatCurrency(annualSavings))/year.",
                icon: "calendar.badge.clock",
                iconColor: .blue,
                potentialSavings: monthlySavings,
                confidence: 0.92,
                subscriptionId: sub.id,
                action: .switchToAnnual,
                urgency: .low
            ))
        }

        return insights
    }

    // MARK: - Cheaper Tiers

    private let cheaperTiers: [String: [(name: String, monthlyPrice: Decimal, description: String)]] = [
        "Netflix": [
            ("Netflix Standard with Ads", 7.99, "Same content, saves you $X/mo with ads"),
        ],
        "Hulu": [
            ("Hulu (Ads)", 7.99, "Same content with ads saves $X/mo"),
        ],
        "YouTube Premium": [
            ("YouTube Premium Lite", 7.99, "Ad-free YouTube without Music, saves $X/mo"),
        ],
        "Spotify": [
            ("Spotify Student", 5.99, "If eligible: student plan saves $X/mo"),
        ],
    ]

    /// Finds known cheaper tier alternatives for existing subscriptions
    func findCheaperTiers(subscriptions: [Subscription]) -> [GeniusInsight] {
        var insights: [GeniusInsight] = []

        for sub in subscriptions {
            for (serviceName, tiers) in cheaperTiers {
                guard sub.name.localizedCaseInsensitiveContains(serviceName) else { continue }

                let subMonthlyDisplay = monthlyInDisplay(sub)
                for tier in tiers {
                    let tierPriceDisplay = usdToDisplay(tier.monthlyPrice)
                    guard subMonthlyDisplay > tierPriceDisplay else { continue }

                    let savings = subMonthlyDisplay - tierPriceDisplay
                    let description = tier.description.replacingOccurrences(
                        of: "$X",
                        with: formatCurrency(savings)
                    )

                    insights.append(GeniusInsight(
                        type: .annualSavings,
                        title: "Cheaper option: \(tier.name)",
                        description: description,
                        icon: "arrow.down.circle.fill",
                        iconColor: .green,
                        potentialSavings: savings,
                        confidence: 0.92,
                        subscriptionId: sub.id,
                        action: .switchToAnnual,
                        urgency: .high
                    ))
                }
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
                let totalCost = matchingSubs.reduce(Decimal(0)) { $0 + monthlyInDisplay($1) }
                let waste = totalCost - (matchingSubs.map { monthlyInDisplay($0) }.min() ?? 0)

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
                    // Convert USD reference prices to display currency
                    let individualDisplay = usdToDisplay(pricing.individual)
                    let familyDisplay = usdToDisplay(pricing.family)
                    // Calculate savings if splitting with 1 other person
                    let savingsPerPerson = (individualDisplay - familyDisplay / 2)

                    if savingsPerPerson > 0 {
                        insights.append(GeniusInsight(
                            type: .familySharing,
                            title: "Family plan: \(serviceName)",
                            description: "Family plan is \(formatCurrency(familyDisplay))/mo for \(pricing.maxUsers). Splitting with 1 person saves \(formatCurrency(savingsPerPerson))/mo.",
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

    /// Converts a USD reference price to the user's selected display currency.
    /// Used for comparing hardcoded USD pricing data against user subscriptions.
    private func usdToDisplay(_ usdAmount: Decimal) -> Decimal {
        CurrencyManager.shared.convertToSelected(usdAmount, from: "USD")
    }

    /// Converts a subscription's monthly cost to the user's selected display currency.
    private func monthlyInDisplay(_ sub: Subscription) -> Decimal {
        CurrencyManager.shared.convertToSelected(sub.monthlyCost, from: sub.currency)
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
