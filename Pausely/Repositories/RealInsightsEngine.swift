//
//  RealInsightsEngine.swift
//  Pausely
//
//  REAL subscription insights powered by actual data analysis
//

import Foundation
import SwiftUI
import Combine

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
    private var currencyCancellable: AnyCancellable?

    private init() {
        currencyCancellable = CurrencyManager.shared.$selectedCurrency
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    let subs = SubscriptionStore.shared.subscriptions
                    guard !subs.isEmpty else { return }
                    _ = await self.analyze(subscriptions: subs)
                }
            }
    }

    // MARK: - Currency conversion helpers
    /// Monthly cost of a subscription converted to the user's selected display currency.
    private func monthly(_ sub: Subscription) -> Decimal {
        CurrencyManager.shared.convertToSelected(sub.monthlyCost, from: sub.currency)
    }
    /// Annual cost of a subscription converted to the user's selected display currency.
    private func annual(_ sub: Subscription) -> Decimal {
        CurrencyManager.shared.convertToSelected(sub.annualCost, from: sub.currency)
    }

    // MARK: - Formatting Helpers


    private func formatCurrency(_ value: Decimal) -> String {
        CurrencyManager.shared.format(value)
    }

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
        let wasteSavings = waste.alerts.reduce(Decimal(0)) { $0 + $1.potentialSavings }
        spendingForecast = calculateSpendingForecast(subscriptions: subscriptions, totalMonthlySavings: wasteSavings)

        // 4. Detect Duplicate Categories
        let duplicates = detectDuplicateCategories(subscriptions: subscriptions)
        wasteAlerts.append(contentsOf: duplicates.alerts)
        allInsights.append(contentsOf: duplicates.insights)

        // 5. Calculate Category Breakdown
        categoryBreakdown = calculateCategoryBreakdown(subscriptions: subscriptions)

        // 6. ROI Analysis (annual savings recommendations live in Genius tab — no duplication here)
        let roiInsights = calculateROIInsights(subscriptions: subscriptions)
        allInsights.append(contentsOf: roiInsights)

        // 8. Money Story — personalized, context-rich spending story
        let moneyStory = generateMoneyStoryInsights(subscriptions: subscriptions)
        allInsights.append(contentsOf: moneyStory)

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

    /// Unified subscription health score (0-100).
    /// Single source of truth used by Dashboard, Insights, and Financial Advisor.
    /// Measures: organization, affordability, value, diversity, and structure.
    func calculateHealthScore(subscriptions: [Subscription]) -> Int {
        guard !subscriptions.isEmpty else { return 0 }

        let active = subscriptions.filter { $0.status == .active }
        guard !active.isEmpty else { return 100 }

        let count = active.count
        var score = 0.0

        // 1. Billing Organization (20 pts) — billing dates set for all subs
        let withBilling = active.filter { $0.nextBillingDate != nil }.count
        score += (Double(withBilling) / Double(count)) * 20

        // 2. Cost Efficiency (30 pts) — reasonable average monthly spend per subscription
        let totalMonthly = active.reduce(Decimal(0)) { $0 + monthly($1) }
        let avgCost = NSDecimalNumber(decimal: totalMonthly / Decimal(count)).doubleValue
        // $5 avg = 30 pts, $15 avg = 15 pts, $30+ avg = 0 pts
        score += max(0, 30 - (avgCost - 5) * 1.2)

        // 3. Usage Value (25 pts) — only deduct when we have actual ScreenTime data showing low use
        var valueScore = 25.0
        for sub in active {
            let usage = screenTimeManager.getUsage(for: sub.name)
            guard let usage = usage else { continue } // No data = neutral, no penalty
            let minutes = usage.minutesUsed
            if minutes == 0 {
                valueScore -= 3
            } else {
                let hours = Double(minutes) / 60.0
                let cph = NSDecimalNumber(decimal: monthly(sub) / Decimal(hours)).doubleValue
                if cph > 20 { valueScore -= 4 }
                else if cph > 10 { valueScore -= 2 }
            }
        }
        score += max(0, valueScore)

        // 4. Category Diversity (15 pts) — not spending all money in one category
        let categories = Set(active.compactMap { $0.category })
        score += min(15, Double(categories.count) * 3)

        // 5. Structural Health (10 pts) — no exact duplicate names
        let grouped = Dictionary(grouping: active) { $0.name.lowercased() }
        let duplicatePenalty = grouped.values
            .filter { $0.count > 1 }
            .reduce(0) { $0 + ($1.count - 1) } * 5
        score += max(0, 10 - Double(duplicatePenalty))

        return min(100, max(0, Int(score)))
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
        case duplicate   // multiple services in same category (streaming, cloud, music)
    }

    func detectWaste(subscriptions: [Subscription]) -> WasteDetection {
        var alerts: [WasteAlert] = []
        var insights: [RealInsight] = []

        let active = subscriptions.filter { $0.status == .active }
        let calendar = Calendar.current
        let today = Date()

        for sub in active {
            let cost = monthly(sub)

            // 1. Ghost detection: no billing date AND not updated in 90+ days
            //    Signals a subscription the user may have forgotten about.
            let daysSinceUpdate = calendar.dateComponents([.day], from: sub.updatedAt, to: today).day ?? 0
            if sub.nextBillingDate == nil && daysSinceUpdate > 90 {
                alerts.append(WasteAlert(
                    subscription: sub,
                    wasteType: .ghost,
                    potentialSavings: cost,
                    reason: "No billing date set and not updated in \(daysSinceUpdate) days. Still using this?"
                ))
                insights.append(RealInsight(
                    type: .waste,
                    title: "Forgotten? \(sub.name)",
                    description: "No billing date and untouched for \(daysSinceUpdate) days.",
                    icon: "eye.slash.fill",
                    iconColor: .orange,
                    priority: 80,
                    potentialSavings: cost,
                    subscriptionId: sub.id,
                    action: .cancel
                ))
                continue
            }

            // 2. High-cost review: subscriptions costing >$30/mo deserve periodic review
            if cost >= 30 {
                let monthsActive = calendar.dateComponents([.month], from: sub.startDate ?? sub.createdAt, to: today).month ?? 0
                if monthsActive >= 6 {
                    let totalPaid = cost * Decimal(monthsActive)
                    insights.append(RealInsight(
                        type: .waste,
                        title: "Review: \(sub.name)",
                        description: "You've paid \(formatCurrency(totalPaid)) over \(monthsActive) months at \(formatCurrency(cost))/mo. Still worth it?",
                        icon: "magnifyingglass.circle.fill",
                        iconColor: .yellow,
                        priority: 60,
                        potentialSavings: nil,
                        subscriptionId: sub.id,
                        action: .explore
                    ))
                }
            }

            // Costing a lot is not waste on its own. Waste needs evidence: a forgotten entry (above),
            // a duplicate in the same category (detectDuplicateCategories) or low measured usage.
            if let minutes = screenTimeManager.getUsage(for: sub.name)?.minutesUsed, minutes < 30, cost >= 5 {
                alerts.append(WasteAlert(
                    subscription: sub,
                    wasteType: .overpriced,
                    potentialSavings: cost,
                    reason: minutes == 0
                        ? "Not used this month, but it costs \(formatCurrency(cost)) a month."
                        : "Used \(minutes) minutes this month for \(formatCurrency(cost))."
                ))
            }
        }

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

    func calculateSpendingForecast(subscriptions: [Subscription], totalMonthlySavings: Decimal = 0) -> SpendingForecast {
        let active = subscriptions.filter { $0.status == .active }

        let currentMonthly = active.reduce(Decimal(0)) { $0 + monthly($1) }

        // Check if any subscriptions have manual usage data
        let hasUsageData = active.contains { screenTimeManager.getUsage(for: $0.name) != nil }

        var optimizedMonthly: Decimal
        var aggressiveMonthly: Decimal
        if hasUsageData {
            // Usage-based: remove ghost subs (0 usage) and low-use subs (<30 min)
            var usageOptimized = Decimal(0)
            var usageAggressive = Decimal(0)
            for sub in active {
                let usage = screenTimeManager.getUsage(for: sub.name)
                let minutes = usage?.minutesUsed ?? 0
                if minutes > 0 { usageOptimized += monthly(sub) }
                if minutes >= 30 { usageAggressive += monthly(sub) }
            }
            optimizedMonthly = usageOptimized
            aggressiveMonthly = usageAggressive
        } else {
            // No usage data: only the savings Pausely can actually point to. No invented "minimal" plan.
            optimizedMonthly = max(0, currentMonthly - totalMonthlySavings)
            aggressiveMonthly = optimizedMonthly
        }

        // subscription.annualCost (price × charges per year), converted to display currency
        let trueAnnual = active.reduce(Decimal(0)) { $0 + annual($1) }

        return SpendingForecast(
            currentMonthly: currentMonthly,
            optimizedMonthly: optimizedMonthly,
            aggressiveMonthly: aggressiveMonthly,
            annualCurrent: trueAnnual,
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
            if let nextRenewal = sub.calculatedNextBillingDate {
                dates[sub.id] = max(0, calendar.calendarDays(from: today, to: nextRenewal))
            }
        }
        return dates
    }

    // MARK: - Duplicate Detection

    struct DuplicateDetection {
        let alerts: [WasteAlert]
        let insights: [RealInsight]
    }

    /// Groups with overlap thresholds: streaming ≥3, cloud ≥2, music ≥2
    private let overlapGroups: [(label: String, icon: String, threshold: Int, keywords: [String])] = [
        ("Streaming", "play.tv.fill", 3, ["netflix", "hulu", "disney", "max", "hbo", "peacock", "paramount", "prime video", "apple tv", "youtube tv", "crunchyroll", "tubi", "fubo", "sling", "philo", "mubi", "shudder", "britbox", "acorn", "discovery+"]),
        ("Music", "music.note.list", 2, ["spotify", "apple music", "tidal", "deezer", "pandora", "iheartradio", "siriusxm", "youtube music", "amazon music", "soundcloud", "napster", "bandcamp"]),
        ("Cloud Storage", "icloud.fill", 2, ["icloud", "google one", "dropbox", "onedrive", "box.com", "pcloud", "backblaze", "carbonite", "wasabi", "idrive", "tresorit"]),
    ]

    func detectDuplicateCategories(subscriptions: [Subscription]) -> DuplicateDetection {
        let active = subscriptions.filter { $0.status == .active }
        var alerts: [WasteAlert] = []
        var insights: [RealInsight] = []

        // Smart overlap detection for high-value groups
        for group in overlapGroups {
            let matched = active.filter { sub in
                let nameLower = sub.name.lowercased()
                return group.keywords.contains { nameLower.contains($0) }
            }
            guard matched.count >= group.threshold else { continue }

            let sorted = matched.sorted { monthly($0) > monthly($1) }
            // Savings = cancel everything except the most expensive one (keep best value)
            let keepCost = sorted.first.map { monthly($0) } ?? 0
            let totalCost = sorted.reduce(Decimal(0)) { $0 + monthly($1) }
            let savings = totalCost - keepCost
            let names = sorted.map { $0.name }.joined(separator: ", ")

            // One WasteAlert per group (attach to cheapest subscription as the cancel candidate)
            if let cancelCandidate = sorted.last {
                alerts.append(WasteAlert(
                    subscription: cancelCandidate,
                    wasteType: .duplicate,
                    potentialSavings: savings,
                    reason: "\(matched.count) \(group.label) services: \(names). Save \(formatCurrency(savings))/mo by cutting extras."
                ))
            }

            insights.append(RealInsight(
                type: .duplicate,
                title: "\(matched.count) \(group.label) Services",
                description: "\(names) — save \(formatCurrency(savings))/mo by keeping just one.",
                icon: group.icon,
                iconColor: .orange,
                priority: 75,
                potentialSavings: savings,
                subscriptionId: nil,
                action: .explore
            ))
        }

        // Generic category-level duplicates (catch anything not in the smart groups)
        let grouped = Dictionary(grouping: active) { $0.category ?? "Other" }
        for (category, subs) in grouped where subs.count > 1 && category != "Other" {
            // Skip if already covered by a smart group
            let alreadyCovered = overlapGroups.contains { group in
                subs.allSatisfy { sub in
                    let nameLower = sub.name.lowercased()
                    return group.keywords.contains { nameLower.contains($0) }
                }
            }
            guard !alreadyCovered else { continue }

            let totalCost = subs.reduce(Decimal(0)) { $0 + monthly($1) }
            let names = subs.map { $0.name }.joined(separator: ", ")
            insights.append(RealInsight(
                type: .duplicate,
                title: "Multiple \(category) Subs",
                description: "\(subs.count) subscriptions: \(names). Total: \(formatCurrency(totalCost))/month",
                icon: "doc.on.doc.fill",
                iconColor: .orange,
                priority: 65,
                potentialSavings: nil,
                subscriptionId: nil,
                action: .explore
            ))
        }

        return DuplicateDetection(alerts: alerts, insights: insights)
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

        let totalMonthly = active.reduce(Decimal(0)) { $0 + monthly($1) }

        let sorted = grouped.map { category, subs in
            (category: category, subs: subs, amount: subs.reduce(Decimal(0)) { $0 + monthly($1) })
        }.sorted { ($0.amount, $1.category) > ($1.amount, $0.category) }

        // Every slice gets its own colour: the category's usual colour if it's free, else the next unused one.
        var used: Set<String> = []
        return sorted.map { item in
            let percentage = totalMonthly > 0 ? NSDecimalNumber(decimal: item.amount / totalMonthly).doubleValue : 0
            let color = Self.distinctColor(for: item.category, used: &used)
            return CategoryInsight(
                category: Self.displayName(for: item.category),
                amount: item.amount,
                percentage: percentage,
                count: item.subs.count,
                color: color
            )
        }
    }

    /// Keeps names people typed ("AI Tools", "Health & Fitness") and tidies all-lowercase ones.
    static func displayName(for category: String) -> String {
        category == category.lowercased() ? category.capitalized : category
    }

    private static let palette: [(name: String, color: Color)] = [
        ("red", .red), ("blue", .blue), ("green", .green), ("orange", .orange), ("purple", .purple),
        ("teal", .teal), ("pink", .pink), ("yellow", .yellow), ("indigo", .indigo), ("mint", .mint),
        ("cyan", .cyan), ("brown", .brown)
    ]

    private static func preferredColor(for category: String) -> String {
        let c = category.lowercased()
        if c.contains("entertain") || c.contains("stream") || c.contains("video") { return "red" }
        if c.contains("product") || c.contains("work") { return "blue" }
        if c.contains("health") || c.contains("fitness") { return "green" }
        if c.contains("music") || c.contains("audio") { return "pink" }
        if c.contains("ai") { return "purple" }
        if c.contains("news") || c.contains("read") { return "yellow" }
        if c.contains("educat") || c.contains("learn") { return "orange" }
        if c.contains("cloud") || c.contains("storage") || c.contains("util") { return "teal" }
        if c.contains("food") || c.contains("meal") { return "brown" }
        if c.contains("shop") { return "indigo" }
        if c.contains("game") { return "cyan" }
        return "mint"
    }

    private static func distinctColor(for category: String, used: inout Set<String>) -> Color {
        let preferred = preferredColor(for: category)
        let name = used.contains(preferred) ? (palette.first { !used.contains($0.name) }?.name ?? preferred) : preferred
        used.insert(name)
        return palette.first { $0.name == name }?.color ?? .gray
    }

    // MARK: - Annual Savings


    // MARK: - ROI Analysis

    func calculateROIInsights(subscriptions: [Subscription]) -> [RealInsight] {
        var insights: [RealInsight] = []

        let active = subscriptions.filter { $0.status == .active }

        for sub in active {
            let usage = screenTimeManager.getUsage(for: sub.name)
            let minutes = usage?.minutesUsed ?? 0

            guard minutes > 0 else { continue }

            let hours = Double(minutes) / 60.0
            let costPerHour = NSDecimalNumber(decimal: monthly(sub) / Decimal(hours)).doubleValue

            // High cost per hour
            if costPerHour > 10 {
                insights.append(RealInsight(
                    type: .roi,
                    title: "Low ROI: \(sub.name)",
                    description: "\(formatCurrency(monthly(sub) / Decimal(hours)))/hour. Consider pausing if usage doesn't increase.",
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

    // MARK: - Money Story Insights

    private func generateMoneyStoryInsights(subscriptions: [Subscription]) -> [RealInsight] {
        let active = subscriptions.filter { $0.status == .active }
        guard !active.isEmpty else { return [] }

        var insights: [RealInsight] = []
        let calendar = Calendar.current
        let today = Date()

        let totalMonthly = active.reduce(Decimal(0)) { $0 + monthly($1) }

        // 1. Total Paid This Year
        // Count months elapsed since Jan 1, 2026
        var jan2026Components = DateComponents()
        jan2026Components.year = 2026
        jan2026Components.month = 1
        jan2026Components.day = 1
        if let jan2026 = calendar.date(from: jan2026Components) {
            let monthsElapsed = calendar.dateComponents([.month], from: jan2026, to: today).month ?? 0
            if monthsElapsed > 0 {
                let totalPaidThisYear = totalMonthly * Decimal(monthsElapsed)
                if totalPaidThisYear > 0 {
                    insights.append(RealInsight(
                        type: .summary,
                        title: "Total Paid This Year",
                        description: "You've spent \(formatCurrency(totalPaidThisYear)) on subscriptions in 2026 so far.",
                        icon: "calendar.circle.fill",
                        iconColor: .blue,
                        priority: 50,
                        potentialSavings: nil,
                        subscriptionId: nil,
                        action: .none
                    ))
                }
            }
        }

        // 2. Cost Per Day — most expensive subscription
        if let mostExpensive = active.max(by: { monthly($0) < monthly($1) }) {
            let costPerDay = monthly(mostExpensive) / 30
            insights.append(RealInsight(
                type: .roi,
                title: "Cost Per Day: \(mostExpensive.name)",
                description: "\(mostExpensive.name) costs you \(formatCurrency(costPerDay))/day — more than a coffee every week.",
                icon: "clock.fill",
                iconColor: .orange,
                priority: 45,
                potentialSavings: nil,
                subscriptionId: mostExpensive.id,
                action: .none
            ))
        }

        // 3. Annual Equivalent
        let annualEquivalent = totalMonthly * 12
        insights.append(RealInsight(
            type: .summary,
            title: "Annual Equivalent",
            description: "Your subscriptions will cost you \(formatCurrency(annualEquivalent)) this year if nothing changes.",
            icon: "dollarsign.circle.fill",
            iconColor: .green,
            priority: 40,
            potentialSavings: nil,
            subscriptionId: nil,
            action: .none
        ))

        // 4. Subscription Birthday — active for over 11 months
        for sub in active {
            let referenceDate = sub.startDate ?? sub.createdAt
            let monthsActive = calendar.dateComponents([.month], from: referenceDate, to: today).month ?? 0
            if monthsActive > 11 {
                let totalPaid = monthly(sub) * Decimal(monthsActive)
                insights.append(RealInsight(
                    type: .roi,
                    title: "Subscription Birthday: \(sub.name)",
                    description: "You've had \(sub.name) for over a year! You've paid approximately \(formatCurrency(totalPaid)) total.",
                    icon: "gift.fill",
                    iconColor: .purple,
                    priority: 35,
                    potentialSavings: nil,
                    subscriptionId: sub.id,
                    action: .none
                ))
                break // Only show one birthday insight
            }
        }

        return insights
    }

    // MARK: - Spending Trend

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
        case summary
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
