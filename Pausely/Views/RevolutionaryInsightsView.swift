//
//  RevolutionaryInsightsView.swift
//  Pausely
//
//  REAL insights powered by actual data analysis
//

import SwiftUI

// MARK: - Revolutionary Insights View

struct RevolutionaryInsightsView: View {
    @ObservedObject private var engine = RealInsightsEngine.shared
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared
    @State private var selectedTimeRange: TimeRange = .month
    @State private var appeared = false

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isAnalyzing {
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Analyzing your subscriptions...")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        insightsHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // Health Score Card
                        HealthScoreCard(score: engine.healthScore)
                            .padding(.horizontal, 20)
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.95)

                        // Spending Forecast
                        if let forecast = engine.spendingForecast {
                            SpendingForecastCard(forecast: forecast)
                                .padding(.horizontal, 20)
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(appeared ? 1 : 0.95)
                        }

                        // Category Breakdown
                        if !engine.categoryBreakdown.isEmpty {
                            CategoryBreakdownCard(categories: engine.categoryBreakdown)
                                .padding(.horizontal, 20)
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(appeared ? 1 : 0.95)
                        }

                        // Waste Alerts
                        if !engine.wasteAlerts.isEmpty {
                            WasteAlertsSection(alerts: engine.wasteAlerts)
                                .padding(.horizontal, 20)
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(appeared ? 1 : 0.95)
                        }

                        // Insights List
                        InsightsListSection(insights: engine.insights)
                            .padding(.horizontal, 20)
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.95)

                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .task {
            await runAnalysis()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.05)) {
                appeared = true
            }
        }
    }

    private var insightsHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Insights")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if let lastDate = engine.lastAnalysisDate {
                Text("Analyzed \(lastDate.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            } else {
                Text("Real analysis of your subscription health")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func runAnalysis() async {
        let subs = subscriptionStore.subscriptions
        _ = await engine.analyze(subscriptions: subs)
    }
}

// MARK: - Health Score Card

struct HealthScoreCard: View {
    let score: Int

    private var scoreColor: Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }

    private var scoreLabel: String {
        if score >= 80 { return "Excellent" }
        if score >= 60 { return "Good" }
        if score >= 40 { return "Fair" }
        return "Needs Attention"
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscription Health")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(scoreLabel)
                        .font(.subheadline)
                        .foregroundColor(scoreColor)
                }

                Spacer()

                // Score Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    Text("\(score)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }

            // Score breakdown
            HStack(spacing: 16) {
                ScoreIndicator(label: "Cost", value: score >= 50 ? "Good" : "High", color: score >= 50 ? .green : .red)
                ScoreIndicator(label: "Usage", value: score >= 60 ? "Active" : "Low", color: score >= 60 ? .green : .orange)
                ScoreIndicator(label: "Value", value: score >= 40 ? "Fair" : "Poor", color: score >= 40 ? .yellow : .red)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ScoreIndicator: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Spending Forecast Card

struct SpendingForecastCard: View {
    let forecast: RealInsightsEngine.SpendingForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Spending Forecast")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
            }

            // Monthly breakdown
            VStack(spacing: 12) {
                ForecastRow(label: "Current Monthly", amount: forecast.currentMonthly, color: .white)
                ForecastRow(label: "Optimized", amount: forecast.optimizedMonthly, color: .green, badge: "Save \(formatCurrency(forecast.currentMonthly - forecast.optimizedMonthly))/mo")
                ForecastRow(label: "Aggressive", amount: forecast.aggressiveMonthly, color: .blue, badge: "Save \(formatCurrency(forecast.currentMonthly - forecast.aggressiveMonthly))/mo")
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Annual projection
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Annual Cost")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatCurrency(forecast.annualCurrent))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("If Optimized")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatCurrency(forecast.annualOptimized))
                        .font(.title3.bold())
                        .foregroundColor(.green)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        return String(format: "$%.0f", value)
    }
}

struct ForecastRow: View {
    let label: String
    let amount: Decimal
    let color: Color
    var badge: String? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()

            if let badge = badge {
                Text(badge)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.2))
                    )
            }

            Text("$\(NSDecimalNumber(decimal: amount).intValue)/mo")
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
    }
}

// MARK: - Category Breakdown Card

struct CategoryBreakdownCard: View {
    let categories: [RealInsightsEngine.CategoryInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Category Breakdown")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.purple)
            }

            ForEach(categories) { category in
                HStack {
                    Circle()
                        .fill(category.color)
                        .frame(width: 12, height: 12)

                    Text(category.category)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(category.count) sub\(category.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("$\(NSDecimalNumber(decimal: category.amount).intValue)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }

                // Progress bar
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(category.color.opacity(0.3))
                        .frame(width: geo.size.width)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(category.color)
                                .frame(width: geo.size.width * category.percentage),
                            alignment: .leading
                        )
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Waste Alerts Section

struct WasteAlertsSection: View {
    let alerts: [RealInsightsEngine.WasteAlert]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Waste Alerts")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(alerts.count) issues")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.2))
                    )
            }

            ForEach(alerts) { alert in
                WasteAlertRow(alert: alert)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.red.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct WasteAlertRow: View {
    let alert: RealInsightsEngine.WasteAlert

    private var wasteTypeIcon: String {
        switch alert.wasteType {
        case .ghost: return "exclamationmark.triangle.fill"
        case .veryLowUse: return "clock.fill"
        case .decliningUse: return "chart.line.downtrend.xyaxis"
        case .overpriced: return "dollarsign.circle.fill"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: wasteTypeIcon)
                .foregroundColor(.red)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.subscription.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Text(alert.reason)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Save")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("$\(NSDecimalNumber(decimal: alert.potentialSavings).intValue)/mo")
                    .font(.subheadline.bold())
                    .foregroundColor(.green)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Insights List Section

struct InsightsListSection: View {
    let insights: [RealInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(insights) { insight in
                InsightRow(insight: insight)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct InsightRow: View {
    let insight: RealInsight

    var body: some View {
        HStack {
            Image(systemName: insight.icon)
                .foregroundColor(insight.iconColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()

            if let savings = insight.potentialSavings {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Save")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("$\(NSDecimalNumber(decimal: savings).intValue)")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    RevolutionaryInsightsView()
}
