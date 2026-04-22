//
//  RevolutionaryScreenTimeView.swift
//  Pausely
//
//  REVOLUTIONARY Screen Time Dashboard with Smart Insights
//

import SwiftUI

// MARK: - Revolutionary Screen Time Dashboard
struct RevolutionaryScreenTimeDashboard: View {
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    let subscriptions: [Subscription]
    
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showingAuthorizationSheet = false
    @State private var selectedInsight: SubscriptionInsight?
    @State private var cachedInsights: [SubscriptionInsight] = []
    @State private var isCalculating = false
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard
                
                // Auto-tracking status
                autoTrackingStatusSection
                
                timeRangeSelector

                // Disclaimer about estimated data
                ScreenTimeDisclaimer()
                    .padding(.horizontal, 4)

                summaryCards

                if !wasteInsights.isEmpty {
                    wasteReportSection
                }
                
                insightsSection
                
                if !screenTimeManager.isAuthorized {
                    manualEntrySection
                }
            }
            .padding()
        }
        .background(Color.obsidianBlack.ignoresSafeArea())
        .navigationTitle("Usage Insights")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAuthorizationSheet) {
            ScreenTimeAuthorizationSheet()
        }
        .sheet(item: $selectedInsight) { insight in
            STInsightDetailSheet(insight: insight)
        }
        .task {
            if screenTimeManager.isAuthorized {
                await screenTimeManager.autoTrackSubscriptions(subscriptions)
            }
            await calculateInsights()
        }
        .onChange(of: subscriptions) { oldValue, newValue in
            Task {
                await calculateInsights()
            }
        }
    }
    
    private var autoTrackingStatusSection: some View {
        let trackable = screenTimeManager.getAutoTrackableSubscriptions(from: subscriptions)
        let total = subscriptions.count
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.accentColor)
                Text("Auto-Tracking")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(trackable.count)/\(total) subs")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if screenTimeManager.isAuthorized {
                Text("✅ Automatically tracking \(trackable.count) subscriptions via Screen Time")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("Connect Screen Time to automatically track your subscriptions without manual entry")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            // Show which subscriptions are auto-tracked
            if !trackable.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(trackable.prefix(5)) { sub in
                        let status = screenTimeManager.getTrackingStatus(for: sub)
                        HStack(spacing: 4) {
                            Image(systemName: status.icon)
                                .font(.caption)
                            Text(sub.name)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status.color.opacity(0.2))
                        .foregroundColor(status.color)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func calculateInsights() async {
        guard !isCalculating else { return }
        isCalculating = true
        
        // Generate insights on main actor since ScreenTimeManager is @MainActor
        let insights = subscriptions.map { screenTimeManager.generateInsight(for: $0) }
        
        cachedInsights = insights
        isCalculating = false
    }
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: screenTimeManager.authorizationStatus.icon)
                    .font(.largeTitle)
                    .foregroundColor(screenTimeManager.authorizationStatus.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(screenTimeManager.authorizationStatus.displayText)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(screenTimeManager.authorizationStatus.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if !screenTimeManager.isAuthorized {
                    Button("Enable") {
                        showingAuthorizationSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            if screenTimeManager.isAuthorized, let lastSync = screenTimeManager.lastSyncDate {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Last updated: \(lastSync, style: .relative) ago")
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(screenTimeManager.authorizationStatus.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var timeRangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(range.rawValue) {
                    selectedTimeRange = range
                }
                .buttonStyle(.bordered)
                .tint(selectedTimeRange == range ? .accentColor : .gray)
            }
        }
    }
    
    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryCard(
                title: "Total Time",
                value: screenTimeManager.formatMinutes(totalMinutes),
                subtitle: "Across all subscriptions",
                icon: "clock.fill",
                color: .mint
            )
            
            SummaryCard(
                title: "Money at Risk",
                value: "$",
                valueSuffix: String(format: "%.0f", totalWaste),
                subtitle: "Potentially wasted",
                icon: "flame.fill",
                color: .red
            )
            
            SummaryCard(
                title: "Avg Cost/Hour",
                value: "$",
                valueSuffix: String(format: "%.2f", averageCostPerHour),
                subtitle: "Across all subs",
                icon: "dollarsign.circle.fill",
                color: .purple
            )
            
            SummaryCard(
                title: "Smart Insights",
                value: "\(insights.count)",
                subtitle: "Actionable recommendations",
                icon: "lightbulb.fill",
                color: .orange
            )
        }
    }
    
    private var wasteReportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Waste Alert")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(wasteInsights.count) subscriptions")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 8) {
                ForEach(wasteInsights.prefix(3)) { insight in
                    WasteInsightCard(insight: insight) {
                        selectedInsight = insight
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Insights")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if screenTimeManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if insights.isEmpty {
                STEmptyInsightsView()
            } else {
                VStack(spacing: 8) {
                    ForEach(insights) { insight in
                        STInsightRow(insight: insight) {
                            selectedInsight = insight
                        }
                    }
                }
            }
        }
    }
    
    private var manualEntrySection: some View {
        VStack(spacing: 12) {
            Text("Don't want to connect Screen Time?")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Enter your usage manually for personalized insights.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Enter Usage Manually") {
                // Show manual entry sheet
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var insights: [SubscriptionInsight] {
        cachedInsights
    }
    
    private var wasteInsights: [SubscriptionInsight] {
        cachedInsights.filter { $0.wasteScore > 50 }.sorted { $0.wasteScore > $1.wasteScore }
    }
    
    private var totalMinutes: Int {
        cachedInsights.reduce(0) { $0 + $1.monthlyMinutesUsed }
    }
    
    private var totalWaste: Double {
        wasteInsights.reduce(0) { $0 + Double(truncating: $1.monthlyCost as NSNumber) }
    }
    
    private var averageCostPerHour: Double {
        let insightsWithUsage = cachedInsights.filter { $0.costPerHour != nil }
        guard !insightsWithUsage.isEmpty else { return 0 }
        let total = insightsWithUsage.reduce(0.0) { $0 + ($1.costPerHour ?? 0) }
        return total / Double(insightsWithUsage.count)
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    var valueSuffix: String? = nil
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if let suffix = valueSuffix {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(value)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(suffix)
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                } else {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct WasteInsightCard: View {
    let insight: SubscriptionInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(insight.wasteLevel.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Text("\(insight.wasteScore)")
                        .font(.headline)
                        .foregroundColor(insight.wasteLevel.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.subscriptionName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(insight.recommendation.description)
                        .font(.caption)
                        .foregroundColor(insight.recommendation.color)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(insight.formattedCostPerHour)/hr")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Text(ScreenTimeManager.shared.formatMinutes(insight.monthlyMinutesUsed))
                            .font(.caption)
                            .foregroundColor(.gray)
                        EstimateBadge(isEstimated: insight.isEstimated)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(insight.wasteLevel.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct STInsightRow: View {
    let insight: SubscriptionInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: insight.usageCategory.icon)
                    .font(.title3)
                    .foregroundColor(insight.usageCategory.color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.subscriptionName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Label(
                            ScreenTimeManager.shared.formatMinutes(insight.monthlyMinutesUsed),
                            systemImage: "clock"
                        )
                        .font(.caption)
                        .foregroundColor(.gray)

                        EstimateBadge(isEstimated: insight.isEstimated)

                        if let cph = insight.costPerHour {
                            Label(
                                String(format: "%.2f", cph),
                                systemImage: "dollarsign"
                            )
                            .font(.caption)
                            .foregroundColor(cph > 10 ? .orange : .green)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.subscriptionName), \(ScreenTimeManager.shared.formatMinutes(insight.monthlyMinutesUsed)) used this month")
        .accessibilityHint("Double-tap to view details")
    }
}

struct STEmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("No Usage Data Yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Connect Screen Time or enter usage manually to see insights.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

struct ScreenTimeAuthorizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = ScreenTimeManager.shared
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        headerView
                        benefitsView
                        privacyView
                        actionButtons
                    }
                    .padding()
                }
            }
            .navigationTitle("Connect Screen Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Connection Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.mint, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "chart.bar.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Smart Usage Insights")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Connect Screen Time to automatically track your subscription usage and get personalized recommendations to save money.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var benefitsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What You'll Get")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                STBenefitRow(icon: "gauge.with.dots.needle.67percent", color: .mint,
                          title: "Cost Per Hour", description: "See exactly how much each subscription costs you per hour of use")
                STBenefitRow(icon: "flame.fill", color: .red,
                          title: "Waste Detection", description: "Identify unused subscriptions that are draining your wallet")
                STBenefitRow(icon: "lightbulb.fill", color: .orange,
                          title: "Smart Suggestions", description: "Get personalized recommendations on when to pause or cancel")
                STBenefitRow(icon: "chart.pie.fill", color: .purple,
                          title: "Visual Reports", description: "Beautiful charts showing your subscription ROI")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var privacyView: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Data Stays Private")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Usage data never leaves your device. We only store insights to help you save money.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                requestAuthorization()
            } label: {
                HStack(spacing: 8) {
                    if manager.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "link.circle.fill")
                    }
                    
                    Text(manager.isLoading ? "Connecting..." : "Connect Screen Time")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.mint, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(manager.isLoading)
            .accessibilityHint(manager.isLoading ? "Please wait, connecting to Screen Time" : "")

            Button {
                dismiss()
            } label: {
                Text("Not Now")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func requestAuthorization() {
        Task {
            do {
                try await manager.requestAuthorization()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct STBenefitRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

struct STInsightDetailSheet: View {
    let insight: SubscriptionInsight
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            Image(systemName: insight.usageCategory.icon)
                                .font(.largeTitle)
                                .foregroundColor(insight.usageCategory.color)
                            
                            Text(insight.subscriptionName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(insight.usageCategory.rawValue)
                                .font(.subheadline)
                                .foregroundColor(insight.usageCategory.color)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(insight.usageCategory.color.opacity(0.15))
                                .cornerRadius(8)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            STStatBox(title: "Monthly Cost", value: "$\(insight.monthlyCost)", color: .purple)
                            VStack(spacing: 4) {
                                STStatBox(title: "Time Used", value: ScreenTimeManager.shared.formatMinutes(insight.monthlyMinutesUsed), color: .mint)
                                EstimateBadge(isEstimated: insight.isEstimated)
                            }
                            STStatBox(title: "Cost/Hour", value: " $\(insight.formattedCostPerHour)", color: .orange)
                            STStatBox(title: "Waste Score", value: "\(insight.wasteScore)/100", color: insight.wasteLevel.color)
                        }

                        // Disclaimer
                        Text("Note: Apple Screen Time API provides session counts, not exact minutes. Usage is estimated based on session frequency.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommendation")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                Image(systemName: insight.recommendation.icon)
                                    .font(.title2)
                                    .foregroundColor(insight.recommendation.color)
                                
                                Text(insight.recommendation.description)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(insight.recommendation.color.opacity(0.1))
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Usage Insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct STStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

extension Date {
    func formattedRelative() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Flow Layout Helper
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.positions[index].x + bounds.minX, 
                                     y: result.positions[index].y + bounds.minY), 
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
