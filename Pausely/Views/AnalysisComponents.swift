//
//  AnalysisComponents.swift
//  Pausely
//
//  Card components used by AnalysisView.
//  Extracted here so AnalysisView stays focused on layout logic.
//

import SwiftUI
import Charts

// MARK: - Health Score Card

struct HealthScoreCard: View {
    let score: Int

    private var scoreColor: Color {
        switch score {
        case 80...: return .green
        case 60..<80: return Color.accentMint
        case 40..<60: return .yellow
        default: return .orange
        }
    }

    private var scoreLabel: String {
        switch score {
        case 80...: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs Attention"
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 6)
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(scoreColor)
                    Text("/100")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Subscription Health")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(scoreLabel)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(scoreColor)
                Text("Based on organization, costs, and value")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20)
    }
}

// MARK: - Category Breakdown Card

struct CategoryBreakdownCard: View {
    let categories: [RealInsightsEngine.CategoryInsight]
    @ObservedObject private var currencyManager = CurrencyManager.shared

    private var totalMonthly: Decimal {
        categories.reduce(into: Decimal(0)) { $0 += $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)

            if categories.isEmpty {
                Text("No category data yet")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                // Donut chart
                ZStack {
                    Chart(categories.prefix(6)) { cat in
                        SectorMark(
                            angle: .value("Amount", cat.amount),
                            innerRadius: .ratio(0.58),
                            angularInset: 1.5
                        )
                        .foregroundStyle(cat.color)
                        .cornerRadius(3)
                    }
                    .frame(height: 180)

                    // Center label
                    VStack(spacing: 2) {
                        Text(CurrencyManager.shared.format(totalMonthly))
                            .font(.system(.callout, design: .rounded).weight(.black).monospacedDigit())
                            .foregroundStyle(Color.accentMint)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("/ mo")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                    }
                    .padding(.horizontal, 8)
                }

                // Legend — 2-column grid
                let visibleCats = Array(categories.prefix(6))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(visibleCats) { cat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 7, height: 7)
                            Text(cat.category.capitalized)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.obsidianTextSecondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(Int(cat.percentage * 100))%")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20)
    }
}

// MARK: - Spending Forecast Card

struct SpendingForecastCard: View {
    let forecast: RealInsightsEngine.SpendingForecast
    @State private var appeared = false

    private var allEqual: Bool {
        forecast.currentMonthly == forecast.optimizedMonthly &&
        forecast.currentMonthly == forecast.aggressiveMonthly
    }

    var body: some View {
        if allEqual {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("Spending Forecast")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                let maxAmount = max(forecast.currentMonthly, forecast.optimizedMonthly, forecast.aggressiveMonthly)
                let maxHeight: CGFloat = 60

                HStack(alignment: .bottom, spacing: 0) {
                    ForecastBar(
                        label: "Current",
                        monthly: forecast.currentMonthly,
                        maxAmount: maxAmount,
                        maxHeight: maxHeight,
                        color: Color.semanticDestructive,
                        appeared: appeared
                    )
                    ForecastBar(
                        label: "Optimized",
                        monthly: forecast.optimizedMonthly,
                        maxAmount: maxAmount,
                        maxHeight: maxHeight,
                        color: Color.semanticWarning,
                        appeared: appeared
                    )
                    ForecastBar(
                        label: "Minimal",
                        monthly: forecast.aggressiveMonthly,
                        maxAmount: maxAmount,
                        maxHeight: maxHeight,
                        color: Color.accentMint,
                        appeared: appeared
                    )
                }
            }
            .padding(16)
            .surfaceCard(cornerRadius: 20)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }
}

private struct ForecastBar: View {
    let label: String
    let monthly: Decimal
    let maxAmount: Decimal
    let maxHeight: CGFloat
    let color: Color
    let appeared: Bool
    @ObservedObject private var currencyManager = CurrencyManager.shared

    private var barHeight: CGFloat {
        guard maxAmount > 0 else { return 4 }
        let ratio = CGFloat(truncating: (monthly / maxAmount) as NSDecimalNumber)
        return max(4, ratio * maxHeight)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(CurrencyManager.shared.format(monthly))
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.opacity(0.8))
                .frame(height: appeared ? barHeight : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)

            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.obsidianTextTertiary)
            Text("/mo")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.obsidianTextTertiary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Waste Alerts Section

struct WasteAlertsSection: View {
    let alerts: [RealInsightsEngine.WasteAlert]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption.weight(.semibold))
                Text("Waste Alerts")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(alerts.count)")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }

            ForEach(alerts) { alert in
                WasteAlertRow(alert: alert)
            }
        }
        .padding(16)
        .surfaceCard(cornerRadius: 20)
    }
}

private struct WasteAlertRow: View {
    let alert: RealInsightsEngine.WasteAlert
    @ObservedObject private var currencyManager = CurrencyManager.shared

    private var wasteIcon: String {
        switch alert.wasteType {
        case .ghost:        return "eye.slash.fill"
        case .veryLowUse:   return "clock.badge.xmark.fill"
        case .decliningUse: return "chart.line.downtrend.xyaxis"
        case .overpriced:   return "arrow.up.circle.fill"
        case .duplicate:    return "doc.on.doc.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: wasteIcon)
                .font(.system(size: 14))
                .foregroundStyle(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.subscription.name)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(alert.reason)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if alert.potentialSavings > 0 {
                Text(CurrencyManager.shared.format(alert.potentialSavings))
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.accentMint)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Genius Insight Card

struct GeniusInsightCard: View {
    let insight: GeniusInsight
    @State private var isPressed = false
    @ObservedObject private var currencyManager = CurrencyManager.shared

    private var accentColor: Color {
        switch insight.urgency {
        case .high:   return Color.semanticDestructive
        case .medium: return Color.semanticWarning
        default:      return Color.accentMint
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left urgency accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 10)
                .padding(.leading, 12)

            // Icon circle
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: insight.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            .padding(.leading, 12)

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(insight.title)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    // Urgency text badge
                    if insight.urgency == .high || insight.urgency == .critical {
                        Text(insight.urgency == .critical ? "URGENT" : "HIGH")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(insight.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .lineLimit(2)
            }
            .padding(.leading, 10)

            Spacer(minLength: 8)

            // Savings amount + chevron
            VStack(alignment: .trailing, spacing: 2) {
                if insight.potentialSavings > 0 {
                    Text(CurrencyManager.shared.format(insight.potentialSavings))
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("/mo")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
            }
            .padding(.trailing, 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.obsidianTextTertiary)
                .padding(.trailing, 14)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accentColor.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - B4: Savings Opportunity Badge

struct SavingsOpportunityBadge: View {
    let monthlyAmount: Decimal
    let alertCount: Int

    private var annualAmount: Decimal { monthlyAmount * 12 }

    @State private var pulse = false
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        HStack(spacing: 14) {
            // Pulsing icon
            ZStack {
                Circle()
                    .fill(Color.accentMint.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .scaleEffect(pulse ? 1.12 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                        value: pulse
                    )
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accentMint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("SAVINGS OPPORTUNITY")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.accentMint.opacity(0.7))
                        .tracking(1.2)

                    Text("\(alertCount) \(alertCount == 1 ? "issue" : "issues")")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.accentMint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentMint.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text("Save up to \(CurrencyManager.shared.format(monthlyAmount))/mo")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(.white)

                Text("That's \(CurrencyManager.shared.format(annualAmount)) back in your pocket this year")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.accentMint.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear { pulse = true }
    }
}
