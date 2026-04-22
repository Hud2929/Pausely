//
//  DashboardViewModel.swift
//  Pausely
//
//  Dashboard ViewModel with @Observable
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class DashboardViewModel {
    // MARK: - State
    var state: DataState = .loading
    var subscriptions: [Subscription] = []
    var insights: [STInsight] = []
    var spendingTrend: STSpendingTrend?
    var categoryBreakdown: [STCategoryBreakdown] = []
    
    // MARK: - Computed Properties
    var monthlySpend: Decimal {
        subscriptions
            .filter { $0.status == .active }
            .reduce(0) { $0 + $1.monthlyCost }
    }
    
    var annualSpend: Decimal {
        subscriptions
            .filter { $0.status == .active }
            .reduce(0) { $0 + $1.annualCost }
    }
    
    var activeSubscriptionCount: Int {
        subscriptions.filter { $0.status == .active }.count
    }
    
    var upcomingRenewals: [Subscription] {
        subscriptions
            .filter { $0.status == .active && ($0.daysUntilRenewal ?? 999) <= 7 }
            .sorted { ($0.daysUntilRenewal ?? 999) < ($1.daysUntilRenewal ?? 999) }
    }
    
    var overallWasteScore: Double {
        let scores = subscriptions.compactMap { $0.wasteScore }
        guard !scores.isEmpty else { return 0 }
        let sum = scores.reduce(Decimal(0)) { $0 + $1 }
        return Double(truncating: sum as NSNumber) / Double(scores.count)
    }
    
    var highWasteSubscriptions: [Subscription] {
        subscriptions.filter { sub in
            guard let score = sub.wasteScore else { return false }
            return Double(truncating: score as NSNumber) < 0.4
        }
    }
    
    var potentialSavings: Decimal {
        highWasteSubscriptions.reduce(0) { $0 + $1.annualCost }
    }
    
    // MARK: - Private Properties
    private let subscriptionRepo = SubscriptionRepository.shared
    private let insightsRepo = InsightsRepository.shared
    private let plaidRepo = PlaidRepository.shared
    
    // MARK: - Public Methods
    
    func loadData() async {
        state = .loading
        
        // Load subscriptions
        await subscriptionRepo.loadSubscriptions()
        subscriptions = subscriptionRepo.subscriptions
        
        // Load insights if premium
        if PaymentManager.shared.canUseAnalytics {
            await insightsRepo.loadInsights()
            insights = insightsRepo.activeInsights
            spendingTrend = await insightsRepo.getSpendingTrend()
            categoryBreakdown = insightsRepo.getCategoryBreakdown(from: subscriptions)
        }
        
        state = subscriptions.isEmpty ? .empty : .loaded
    }
    
    func refresh() async {
        await loadData()
    }
    
    func syncBankTransactions() async {
        guard !plaidRepo.connectedAccounts.isEmpty else { return }
        
        do {
            try await plaidRepo.syncTransactions()
            // Reload data after sync
            await loadData()
        } catch {
            print("Sync failed: \(error)")
        }
    }
}
