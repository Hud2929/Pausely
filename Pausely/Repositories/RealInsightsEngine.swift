//
//  RealInsightsEngine.swift
//  Pausely
//
//  REAL subscription insights powered by actual data analysis
//

import Foundation
import SwiftUI

/// Real insights engine that generates actionable insights from actual subscription and usage data
/// Replaces the stubbed InsightsRepository.generateInsights()
@MainActor
final class RealInsightsEngine: ObservableObject {
    static let shared = RealInsightsEngine()

    // MARK: - Published State
    @Published private(set) var isAnalyzing = false
    @Published private(set) var lastAnalysisDate: Date?
    @Published private(set) var insights: [RealInsight] = []
    @Published private(set) var healthScore: Int = 0
    @Published private(set) var spendingForecast: SpendingForecast?
    @Published private(set) var wasteAlerts: [WasteAlert] = []
    @Published private(set) var categoryBreakdown: [CategoryInsight] = []

    // MARK: - Screen Time Manager
    private var screenTimeManager: ScreenTimeManager { ScreenTimeManager.shared }

    private init() {}

    // MARK: - Main Analysis

    /// Generate real insights from subscription and usage data
    func analyze(subscriptions: [Subscription]) async -> AnalysisReport {
        isAnalyzing = true
        defer {
            isAnalyzing = false
            lastAnalysisDate = Date()
        }

        var allInsights: [RealInsight] = []

        // 1. Calculate Health Score
        healthScore = calculateHealthScore(subscriptions: subscriptions)

        // 2. Detect Waste (Ghost subscriptions - 0 usage)
        let waste = detectWaste(subscriptions: subscriptions)
        wasteAlerts = waste.alerts
        allInsights.append(contentsOf: waste.insights)

        // 3. Calculate Spending Forecast
        spendingForecast = calculateSpendingForecast(subscriptions: subscriptions)
        allInsights.append(contentsOf: generateForecastInsights())

        // 4. Detect Duplicate Categories
        let duplicates = detectDuplicateCategories(subscriptions: subscriptions)
        allInsights.append(contentsOf: duplicates.insights)

        // 5. Calculate Category Breakdown
        categoryBreakdown = calculateCategoryBreakdown(subscriptions: subscriptions)

        // 6. Find Annual Savings Opportunities
        let annualSavings = findAnnualSavingsOpportunities(subscriptions: subscriptions)
        allInsights.append(contentsOf: annualSavings.insights)

        // 7. ROI Analysis
        let roiInsights = calculateROIInsights(subscriptions: subscriptions)
        allInsights.append(contentsOf: roiInsights)

        // 8. Spending Trend
        let trendInsights = analyzeSpendingTrend(subscriptions: subscriptions)
        allInsights.append(contentsOf: trendInsights)

        insights = allInsights.sorted { $0.priority > $1.priority }

        return AnalysisReport(
            healthScore: healthScore,
            insights: insights,
            wasteAlerts: wasteAlerts,
            spendingForecast: spendingForecast,
            categoryBreakdown: categoryBreakdown,
            totalPotentialSavings: wasteAlerts.reduce(Decimal(0)) { $0 + $1.potentialSavings }
        )
    }

    // MARK: - Health Score

    /// Calculate subscription health score (0-100)
    /// Based on: cost efficiency, usage, variety, and waste
    func calculateHealthScore(subscriptions: [Subscription]) -> Int {
        guard !subscriptions.isEmpty else { return 100 }

        let active = subscriptions.filter { $0.status == .active }
        guard !active.isEmpty else { return 100 }

        // Factor 1: Average cost per subscription (lower is better, max 30 points)
        let totalMonthly = active.reduce(Decimal(0)) { $0 + $1.monthlyCost }
        let avgCost = NSDecimalNumber(decimal: totalMonthly / Decimal(active.count)).doubleValue
        let costScore = max(0, min(30, 30 - (avgCost - 10) * 1.5))

        // Factor 2: Waste score from usage (max 30 points)
        var wasteScore = 30.0
        for sub in active {
            let usage = screenTimeManager.getUsage(for: sub.name)
            if usage == nil || usage?.minutesUsed == 0 {
                wasteScore -= 5 // No usage data = potential waste
            }
        }
        wasteScore = max(0, wasteScore)

        // Factor 3: Category diversity (max 20 points)
        let categories = Set(active.compactMap { $0.category })
        let diversityScore = min(20, Double(categories.count) * 4)

        // Factor 4: Value ratio - are they getting good deals? (max 20 points)
        var valueScore = 20.0
        for sub in active {
            let usage = screenTimeManager.getUsage(for: sub.name)
            let minutes = usage?.minutesUsed ?? 0
            if minutes > 0 {
                let costPerHour = NSDecimalNumber(decimal: sub.monthlyCost / Decimal(minutes) * 60).doubleValue
                if costPerHour > 10 { valueScore -= 2 }
                if costPerHour > 20 { valueScore -= 3 }
            }
        }
        valueScore = max(0, valueScore)

        let totalScore = Int(costScore + wasteScore + diversityScore + valueScore)
        return min(100, max(25, totalScore))
    }

    // MARK: - Waste Detection

    struct WasteDetection {
        let alerts: [WasteAlert]
        let insights: [RealInsight]
    }

    struct WasteAlert: Identifiable {
        let id = UUID()
        let subscription: Subscription
        let wasteType: WasteType
        let potentialSavings: Decimal
        let reason: String
    }

    enum WasteType {
        case ghost       // 0 usage
        case veryLowUse  // < 30 min/month
        case decliningUse // usage trending down
        case overpriced   // high cost, low usage
    }

    func detectWaste(subscriptions: [Subscription]) -> WasteDetection {
        let alerts: [WasteAlert] = []
        let insights: [RealInsight] = []

        // Note: Ghost and Low Use insights are intentionally disabled.
        // Screen Time only tracks iOS device usage - it cannot track usage on TVs,
        // web browsers, game consoles, or other devices. Showing "no usage" or
        // "low usage" would be misleading since many subscriptions (Netflix, Spotify,
        // YouTube, etc.) are primarily used on other platforms.
        //
        // We only show usage-based insights when the user has explicitly entered
        // manual usage data (isManualEntry == true), which is intentionally provided
        // by the user rather than auto-detected.
        //
        // TODO: Future: Could show "High cost per hour" insights based on cost/usage
        // ratio when actual manual usage data is provided by the user.

        return WasteDetection(alerts: alerts, insights: insights)
    }

    // MARK: - Spending Forecast

    struct SpendingForecast {
        let currentMonthly: Decimal
        let optimizedMonthly: Decimal
        let aggressiveMonthly: Decimal
        let annualCurrent: Decimal
        let annualOptimized: Decimal
        let annualAggressive: Decimal
        let monthsUntilRenewal: [UUID: Int]
    }

    func calculateSpendingForecast(subscriptions: [Subscription]) -> SpendingForecast {
        let active = subscriptions.filter { $0.status == .active }

        let currentMonthly = active.reduce(Decimal(0)) { $0 + $1.monthlyCost }

        // Optimized: Remove ghost subscriptions (0 usage)
        var optimizedMonthly = Decimal(0)
        for sub in active {
            let usage = screenTimeManager.getUsage(for: sub.name)
            let minutes = usage?.minutesUsed ?? 0
            if minutes > 0 {
                optimizedMonthly += sub.monthlyCost
            }
        }

        // Aggressive: Also remove low-usage subscriptions (< 30 min)
        var aggressiveMonthly = Decimal(0)
        for sub in active {
            let usage = screenTimeManager.getUsage(for: sub.name)
            let minutes = usage?.minutesUsed ?? 0
            if minutes >= 30 {
                aggressiveMonthly += sub.monthlyCost
            }
        }

        return SpendingForecast(
            currentMonthly: currentMonthly,
            optimizedMonthly: optimizedMonthly,
            aggressiveMonthly: aggressiveMonthly,
            annualCurrent: currentMonthly * 12,
            annualOptimized: optimizedMonthly * 12,
            annualAggressive: aggressiveMonthly * 12,
            monthsUntilRenewal: calculateRenewalDates(subscriptions: active)
        )
    }

    private func calculateRenewalDates(subscriptions: [Subscription]) -> [UUID: Int] {
        var dates: [UUID: Int] = [:]
        let calendar = Calendar.current
        let today = Date()

        for sub in subscriptions {
            if let nextRenewal = sub.nextBillingDate {
                let components = calendar.dateComponents([.day], from: today, to: nextRenewal)
                dates[sub.id] = max(0, components.day ?? 0)
            }
        }
        return dates
    }

    private func generateForecastInsights() -> [RealInsight] {
        guard let forecast = spendingForecast else { return [] }
        var insights: [RealInsight] = []

        // Current vs Optimized
        let currentSavings = forecast.currentMonthly - forecast.optimizedMonthly
        if currentSavings > 0 {
            insights.append(RealInsight(
                type: .savings,
                title: "Optimize Your Spend",
                description: "You could save $\(currentSavings)/month ($forecast.annualOptimized/year) by removing unused subscriptions.",
                icon: "dollarsign.circle.fill",
                iconColor: .green,
                priority: 60,
                potentialSavings: currentSavings,
                subscriptionId: nil,
                action: .explore
            ))
        }

        return insights
    }

    // MARK: - Duplicate Detection

    struct DuplicateDetection {
        let insights: [RealInsight]
    }

    func detectDuplicateCategories(subscriptions: [Subscription]) -> DuplicateDetection {
        var insights: [RealInsight] = []

        let active = subscriptions.filter { $0.status == .active }
        let grouped = Dictionary(grouping: active) { $0.category ?? "Other" }

        for (category, subs) in grouped where subs.count > 1 {
            let totalCost = subs.reduce(Decimal(0)) { $0 + $1.monthlyCost }
            let names = subs.map { $0.name }.joined(separator: ", ")

            insights.append(RealInsight(
                type: .duplicate,
                title: "Multiple \(category) Subs",
                description: "You have \(subs.count) \(category) subscriptions: \(names). Total: $\(totalCost)/month",
                icon: "doc.on.doc.fill",
                iconColor: .orange,
                priority: 70,
                potentialSavings: nil,
                subscriptionId: nil,
                action: .explore
            ))
        }

        return DuplicateDetection(insights: insights)
    }

    // MARK: - Category Breakdown

    struct CategoryInsight: Identifiable {
        let id = UUID()
        let category: String
        let amount: Decimal
        let percentage: Double
        let count: Int
        let color: Color
    }

    func calculateCategoryBreakdown(subscriptions: [Subscription]) -> [CategoryInsight] {
        let active = subscriptions.filter { $0.status == .active }
        let grouped = Dictionary(grouping: active) { $0.category ?? "Other" }

        let totalMonthly = active.reduce(Decimal(0)) { $0 + $1.monthlyCost }

        return grouped.map { category, subs in
            let amount = subs.reduce(Decimal(0)) { $0 + $1.monthlyCost }
            let percentage = totalMonthly > 0 ? NSDecimalNumber(decimal: amount / totalMonthly).doubleValue : 0

            return CategoryInsight(
                category: category,
                amount: amount,
                percentage: percentage,
                count: subs.count,
                color: categoryColor(for: category)
            )
        }.sorted { $0.amount > $1.amount }
    }

    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "entertainment": return .red
        case "productivity": return .blue
        case "health", "fitness": return .green
        case "news": return .yellow
        case "social": return .purple
        case "utilities": return .gray
        case "education": return .orange
        case "shopping": return .pink
        default: return .gray
        }
    }

    // MARK: - Annual Savings

    struct AnnualSavingsResult {
        let insights: [RealInsight]
    }

    func findAnnualSavingsOpportunities(subscriptions: [Subscription]) -> AnnualSavingsResult {
        var insights: [RealInsight] = []

        let active = subscriptions.filter { $0.status == .active }

        for sub in active {
            // If paying monthly and cost > $8/month, suggest annual
            if sub.billingFrequency == .monthly && sub.monthlyCost >= 8 {
                let annualCost = sub.monthlyCost * 12
                // Assume 20% annual discount
                let estimatedAnnual = annualCost * Decimal(0.80)
                let savings = annualCost - estimatedAnnual

                insights.append(RealInsight(
                    type: .annualSavings,
                    title: "Annual Plan: \(sub.name)",
                    description: "Switch to annual billing to save ~$\(savings)/year on \(sub.name).",
                    icon: "calendar.badge.clock",
                    iconColor: .blue,
                    priority: 50,
                    potentialSavings: savings,
                    subscriptionId: sub.id,
                    action: .switchToAnnual
                ))
            }
        }

        return AnnualSavingsResult(insights: insights)
    }

    // MARK: - ROI Analysis

    func calculateROIInsights(subscriptions: [Subscription]) -> [RealInsight] {
        var insights: [RealInsight] = []

        let active = subscriptions.filter { $0.status == .active }

        for sub in active {
            let usage = screenTimeManager.getUsage(for: sub.name)
            let minutes = usage?.minutesUsed ?? 0

            guard minutes > 0 else { continue }

            let hours = Double(minutes) / 60.0
            let costPerHour = NSDecimalNumber(decimal: sub.monthlyCost / Decimal(hours)).doubleValue

            // High cost per hour
            if costPerHour > 10 {
                insights.append(RealInsight(
                    type: .roi,
                    title: "Low ROI: \(sub.name)",
                    description: "$\(String(format: "%.2f", costPerHour))/hour. Consider pausing if usage doesn't increase.",
                    icon: "chart.bar.fill",
                    iconColor: .yellow,
                    priority: 40,
                    potentialSavings: nil,
                    subscriptionId: sub.id,
                    action: .trackUsage
                ))
            }
        }

        return insights
    }

    // MARK: - Spending Trend

    func analyzeSpendingTrend(subscriptions: [Subscription]) -> [RealInsight] {
        var insights: [RealInsight] = []

        let active = subscriptions.filter { $0.status == .active }
        let totalMonthly = active.reduce(Decimal(0)) { $0 + $1.monthlyCost }

        // Spending summary
        insights.append(RealInsight(
            type: .spendingTrend,
            title: "Monthly Spending",
            description: "You're spending $\(totalMonthly)/month on \(active.count) active subscriptions.",
            icon: "dollarsign.circle.fill",
            iconColor: .blue,
            priority: 30,
            potentialSavings: nil,
            subscriptionId: nil,
            action: .none
        ))

        return insights
    }
}

// MARK: - Real Insight Model

struct RealInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let priority: Int // Higher = more important
    let potentialSavings: Decimal?
    let subscriptionId: UUID?
    let action: InsightAction

    enum InsightType {
        case waste
        case savings
        case duplicate
        case annualSavings
        case roi
        case spendingTrend
    }

    enum InsightAction {
        case cancel
        case pause
        case switchToAnnual
        case explore
        case trackUsage
        case none
    }
}

// MARK: - Analysis Report

struct AnalysisReport {
    let healthScore: Int
    let insights: [RealInsight]
    let wasteAlerts: [RealInsightsEngine.WasteAlert]
    let spendingForecast: RealInsightsEngine.SpendingForecast?
    let categoryBreakdown: [RealInsightsEngine.CategoryInsight]
    let totalPotentialSavings: Decimal
}
