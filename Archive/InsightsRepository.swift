//
//  InsightsRepository.swift
//  Pausely
//
//  AI Insights & Waste Analysis
//

import Foundation
import SwiftUI

// MARK: - Insights Repository
@Observable
@MainActor
final class InsightsRepository {
    static let shared = InsightsRepository()
    
    // MARK: - State
    private(set) var insights: [STInsight] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    // MARK: - Computed Properties
    var unreadCount: Int {
        insights.filter { !$0.isRead }.count
    }
    
    var activeInsights: [STInsight] {
        insights.filter { !$0.isDismissed }
            .sorted { $0.priority > $1.priority }
    }
    
    var wasteAlerts: [STInsight] {
        activeInsights.filter { $0.type == .wasteAlert }
    }
    
    var priceIncreaseAlerts: [STInsight] {
        activeInsights.filter { $0.type == .priceIncrease }
    }
    
    // MARK: - Private Properties
    private let supabase = SupabaseManager.shared.client
    
    // MARK: - Initialization
    private init() {
        Task {
            await loadInsights()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load insights from Supabase
    func loadInsights() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let userId = try await getCurrentUserId()
            
            let response = try await supabase
                .from("insights")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_dismissed", value: false)
                .order("priority", ascending: false)
                .order("created_at", ascending: false)
                .execute()
            
            insights = try JSONDecoder().decode([STInsight].self, from: response.data)
        } catch {
            self.error = error
        }
    }
    
    /// Generate new insights based on subscription data
    func generateInsights(from subscriptions: [Subscription]) async throws {
        guard PaymentManager.shared.canUseAnalytics else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Stub implementation - would call Supabase Edge Function
        // guard let accessToken = try? await supabase.auth.session.accessToken else { ... }
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Reload insights
        await loadInsights()
    }
    
    /// Mark insight as read
    func markAsRead(_ insightId: UUID) async throws {
        try await supabase
            .from("insights")
            .update(["is_read": true])
            .eq("id", value: insightId.uuidString)
            .execute()
        
        // Update local state
        if let index = insights.firstIndex(where: { $0.id == insightId }) {
            insights[index].isRead = true
        }
    }
    
    /// Dismiss insight
    func dismissInsight(_ insightId: UUID) async throws {
        try await supabase
            .from("insights")
            .update(["is_dismissed": true])
            .eq("id", value: insightId.uuidString)
            .execute()
        
        // Update local state
        insights.removeAll { $0.id == insightId }
    }
    
    /// Calculate total potential savings from waste alerts
    func calculatePotentialSavings() -> Decimal {
        wasteAlerts.compactMap { $0.potentialSavings }.reduce(0, +)
    }
    
    /// Get spending trend (month over month)
    func getSpendingTrend() async -> STSpendingTrend {
        // Stub implementation - would call Supabase RPC
        return STSpendingTrend(currentMonth: 0, previousMonth: 0, percentChange: 0)
    }
    
    /// Get category breakdown
    func getCategoryBreakdown(from subscriptions: [Subscription]) -> [STCategoryBreakdown] {
        let active = subscriptions.filter { $0.status == .active }
        let grouped = Dictionary(grouping: active) { $0.category ?? "Other" }
        
        var total = Decimal(0)
        for sub in active {
            total += sub.monthlyCost
        }
        
        return grouped.map { category, subs in
            var amount = Decimal(0)
            for sub in subs {
                amount += sub.monthlyCost
            }
            return STCategoryBreakdown(
                category: category,
                amount: amount,
                percentage: total > 0 ? Double(truncating: (amount / total) as NSNumber) : 0,
                count: subs.count,
                color: categoryColor(for: category)
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    // MARK: - Private Helpers
    
    private func getCurrentUserId() async throws -> UUID {
        guard let session = supabase.auth.currentSession else {
            throw InsightsError.notAuthenticated
        }
        return session.user.id
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "entertainment": return .catEntertainment
        case "productivity": return .catProductivity
        case "health", "fitness", "wellness": return .catHealth
        case "news": return .catNews
        case "social": return .catSocial
        case "cloud", "storage": return .catCloud
        case "finance": return .catFinance
        case "education": return .catEducation
        case "shopping": return .catShopping
        default: return .catOther
        }
    }
}

// MARK: - Data Models

struct STInsight: Identifiable, Codable {
    let id: UUID
    let type: STInsightType
    let title: String
    let body: String
    let subscriptionId: UUID?
    let metadata: InsightMetadata?
    var isRead: Bool
    var isDismissed: Bool
    let priority: Int
    let potentialSavings: Decimal?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, body, metadata
        case subscriptionId = "subscription_id"
        case isRead = "is_read"
        case isDismissed = "is_dismissed"
        case priority
        case potentialSavings = "potential_savings"
        case createdAt = "created_at"
    }
}

enum STInsightType: String, Codable, CaseIterable {
    case wasteAlert = "waste_alert"
    case priceIncrease = "price_increase"
    case duplicate = "duplicate"
    case cheaperAlternative = "cheaper_alternative"
    case trialExpiring = "trial_expiring"
    case spendingTrend = "spending_trend"
    case annualSave = "annual_save"
    case unusedSub = "unused_sub"
    
    var icon: String {
        switch self {
        case .wasteAlert: return "exclamationmark.triangle"
        case .priceIncrease: return "arrow.up.right"
        case .duplicate: return "doc.on.doc"
        case .cheaperAlternative: return "dollarsign.arrow.circlepath"
        case .trialExpiring: return "clock.badge.exclamationmark"
        case .spendingTrend: return "chart.line.uptrend.xyaxis"
        case .annualSave: return "dollarsign.circle"
        case .unusedSub: return "xmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .wasteAlert, .unusedSub: return .semanticDestructive
        case .priceIncrease: return .semanticWarning
        case .duplicate: return .semanticInfo
        case .cheaperAlternative, .annualSave: return .semanticSuccess
        case .trialExpiring: return .semanticWarning
        case .spendingTrend: return .accentMint
        }
    }
    
    var displayName: String {
        switch self {
        case .wasteAlert: return "Waste Alert"
        case .priceIncrease: return "Price Increase"
        case .duplicate: return "Duplicate Found"
        case .cheaperAlternative: return "Cheaper Alternative"
        case .trialExpiring: return "Trial Expiring"
        case .spendingTrend: return "Spending Trend"
        case .annualSave: return "Annual Savings"
        case .unusedSub: return "Unused Subscription"
        }
    }
}

struct InsightMetadata: Codable {
    let oldPrice: Decimal?
    let newPrice: Decimal?
    let percentChange: Double?
    let alternativeName: String?
    let alternativePrice: Decimal?
    
    enum CodingKeys: String, CodingKey {
        case oldPrice = "old_price"
        case newPrice = "new_price"
        case percentChange = "percent_change"
        case alternativeName = "alternative_name"
        case alternativePrice = "alternative_price"
    }
}

struct STSpendingTrend {
    let currentMonth: Decimal
    let previousMonth: Decimal
    let percentChange: Double
    
    var isIncreasing: Bool { percentChange > 0 }
    var isDecreasing: Bool { percentChange < 0 }
    
    var formattedChange: String {
        let prefix = percentChange > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", percentChange))%"
    }
}

struct STCategoryBreakdown: Identifiable {
    let id = UUID()
    let category: String
    let amount: Decimal
    let percentage: Double
    let count: Int
    let color: Color
    
    var formattedPercentage: String {
        "\(Int(percentage * 100))%"
    }
}

// MARK: - Errors
enum InsightsError: LocalizedError {
    case notAuthenticated
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to view insights"
        case .generationFailed:
            return "Failed to generate insights"
        }
    }
}
