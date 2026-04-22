//
//  ModernDashboardView.swift
//  Pausely
//
//  Revolutionary Dashboard with Obsidian Design
//

import SwiftUI

struct ModernDashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var showingPaywall = false
    @State private var showingAddSheet = false
    @State private var selectedSubscription: Subscription?
    
    var body: some View {
        ScrollView {
            VStack(spacing: STSpacing.xl) {
                // Header
                headerSection
                
                // Spend Ring Card
                spendRingSection
                
                // Upcoming Renewals
                if !viewModel.upcomingRenewals.isEmpty {
                    upcomingRenewalsSection
                }
                
                // Waste Score (Premium)
                if PaymentManager.shared.canUseWasteScore && viewModel.overallWasteScore > 0 {
                    wasteScoreSection
                }
                
                // Insights (Premium)
                if PaymentManager.shared.canUseAnalytics && !viewModel.insights.isEmpty {
                    insightsSection
                }
            }
            .padding(.horizontal, STSpacing.screenHorizontal)
            .padding(.vertical, STSpacing.screenVertical)
        }
        .background(Color.obsidianBlack.ignoresSafeArea())
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: viewModel.activeSubscriptionCount)
        }
        .sheet(isPresented: $showingAddSheet) {
            EnhancedAddSubscriptionView()
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .font(STFont.headlineLarge)
                    .foregroundStyle(Color.obsidianText)
                
                Text("\(viewModel.activeSubscriptionCount) active subscriptions")
                    .font(STFont.bodyMedium)
                    .foregroundStyle(Color.obsidianTextSecondary)
            }
            
            Spacer()
        }
    }
    
    private var spendRingSection: some View {
        VStack(spacing: STSpacing.lg) {
            // Circular spend indicator
            ZStack {
                Circle()
                    .stroke(Color.obsidianElevated, lineWidth: 12)
                    .frame(width: 180, height: 180)
                
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        Color.accentMint.gradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.accentMintGlow, radius: 10)
                
                VStack(spacing: 4) {
                    AnimatedCounter(
                        value: viewModel.monthlySpend,
                        font: STFont.monoMedium,
                        color: Color.obsidianText
                    )
                    
                    Text("per month")
                        .font(STFont.labelMedium)
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
            }
            
            // Stats row
            HStack(spacing: STSpacing.lg) {
                StatPill(
                    value: "\(viewModel.activeSubscriptionCount)",
                    label: "Active",
                    color: .accentMint
                )
                
                StatPill(
                    value: "\(viewModel.upcomingRenewals.count)",
                    label: "Due Soon",
                    color: viewModel.upcomingRenewals.isEmpty ? .obsidianTextTertiary : .semanticWarning
                )
                
                StatPill(
                    value: formatCurrency(viewModel.annualSpend, currencyCode: "USD"),
                    label: "Annual",
                    color: .obsidianText
                )
            }
        }
        .padding(STSpacing.xl)
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: STRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: STRadius.lg)
                .stroke(Color.obsidianBorder, lineWidth: 1)
        )
    }
    
    private var upcomingRenewalsSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.base) {
            HStack {
                Text("Upcoming Renewals")
                    .font(STFont.headlineSmall)
                    .foregroundStyle(Color.obsidianText)
                
                Spacer()
                
                Text("See All")
                    .font(STFont.labelMedium)
                    .foregroundStyle(Color.accentMint)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: STSpacing.base) {
                    ForEach(viewModel.upcomingRenewals.prefix(5)) { subscription in
                        UpcomingRenewalCard(subscription: subscription)
                    }
                }
            }
        }
    }
    
    private var wasteScoreSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.base) {
            HStack {
                Text("Spending Efficiency")
                    .font(STFont.headlineSmall)
                    .foregroundStyle(Color.obsidianText)
                
                Spacer()
                
                if !viewModel.highWasteSubscriptions.isEmpty {
                    Text("\(viewModel.highWasteSubscriptions.count) wasting money")
                        .font(STFont.labelSmall)
                        .foregroundStyle(Color.semanticDestructive)
                }
            }
            
            OverallWasteScoreCard(
                subscriptions: viewModel.subscriptions,
                onTap: {
                    if !PaymentManager.shared.canUseWasteScore {
                        showingPaywall = true
                    }
                }
            )
        }
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: STSpacing.base) {
            HStack {
                Text("Smart Insights")
                    .font(STFont.headlineSmall)
                    .foregroundStyle(Color.obsidianText)
                
                Spacer()
                
                if viewModel.insights.filter({ !$0.isRead }).count > 0 {
                    Text("\(viewModel.insights.filter({ !$0.isRead }).count) new")
                        .font(STFont.labelSmall)
                        .foregroundStyle(Color.accentMint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentMint.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            VStack(spacing: STSpacing.base) {
                ForEach(viewModel.insights.prefix(3)) { insight in
                    STInsightCard(insight: insight)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Decimal, currencyCode: String) -> String {
        value.formatted(.currency(code: currencyCode))
    }
}

// MARK: - Supporting Views

struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(STFont.labelLarge)
                .foregroundStyle(color)
            
            Text(label)
                .font(STFont.labelSmall)
                .foregroundStyle(Color.obsidianTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.obsidianElevated)
        .clipShape(Capsule())
    }
}

struct UpcomingRenewalCard: View {
    let subscription: Subscription
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon
            RoundedRectangle(cornerRadius: STRadius.sm)
                .fill(Color.obsidianElevated)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(subscription.name.prefix(1)))
                        .font(STFont.headlineSmall)
                        .foregroundStyle(Color.accentMint)
                )
            
            Text(subscription.name)
                .font(STFont.labelMedium)
                .foregroundStyle(Color.obsidianText)
                .lineLimit(1)
            
            Text(subscription.displayAmount)
                .font(STFont.monoSmall)
                .foregroundStyle(Color.obsidianText)
            
            if let days = subscription.daysUntilRenewal {
                Text(days <= 3 ? "In \(days) days" : "\(days) days")
                    .font(STFont.labelSmall)
                    .foregroundStyle(days <= 3 ? Color.semanticWarning : Color.obsidianTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(days <= 3 ? Color.semanticWarning.opacity(0.15) : Color.obsidianElevated)
                    .clipShape(Capsule())
            }
        }
        .frame(width: 120)
        .padding()
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: STRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: STRadius.md)
                .stroke(Color.obsidianBorder, lineWidth: 1)
        )
    }
}

struct STInsightCard: View {
    let insight: STInsight
    
    var body: some View {
        HStack(spacing: STSpacing.base) {
            // Icon
            ZStack {
                Circle()
                    .fill(insight.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: insight.type.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(insight.type.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(STFont.labelLarge)
                    .foregroundStyle(Color.obsidianText)
                
                Text(insight.body)
                    .font(STFont.bodySmall)
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.obsidianTextTertiary)
        }
        .padding()
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: STRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: STRadius.md)
                .stroke(Color.obsidianBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    ModernDashboardView()
        .preferredColorScheme(.dark)
}
