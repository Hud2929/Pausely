//
//  PerceptionGapCard.swift
//  Pausely
//
//  TopOpportunityCard: shows the single highest-impact action right now.
//  Three states: waste detected → savings insight → all healthy.
//

import SwiftUI

struct TopOpportunityCard: View {
    @ObservedObject private var insightsEngine = RealInsightsEngine.shared
    @ObservedObject private var geniusEngine = RealGeniusEngine.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    private enum State {
        case waste(alert: RealInsightsEngine.WasteAlert)
        case saving(insight: GeniusInsight)
        case healthy
    }

    private var cardState: State {
        if let top = insightsEngine.wasteAlerts.first {
            return .waste(alert: top)
        }
        if let top = geniusEngine.insights.first(where: { $0.potentialSavings > 0 }) {
            return .saving(insight: top)
        }
        return .healthy
    }

    private var accentColor: Color {
        switch cardState {
        case .waste:   return .orange
        case .saving:  return Color.accentMint
        case .healthy: return Color.accentMint
        }
    }

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .switchToAnalysisTab, object: nil)
        } label: {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 12)
                    .padding(.leading, 14)

                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                .padding(.leading, 12)

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .lineLimit(2)
                }
                .padding(.leading, 10)

                Spacer(minLength: 8)

                // Savings amount (if applicable)
                if let savings = savingsAmount {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(currencyManager.format(savings))
                            .font(.system(.callout, design: .rounded).weight(.bold))
                            .foregroundStyle(accentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("/mo")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                    }
                    .padding(.trailing, 4)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .padding(.trailing, 14)
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(accentColor.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isCritical ? accentColor.opacity(0.25) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch cardState {
        case .waste:               return "flame.fill"
        case .saving(let insight): return insight.icon
        case .healthy:             return "checkmark.seal.fill"
        }
    }

    private var title: String {
        switch cardState {
        case .waste(let alert):
            return "\(alert.subscription.name): possible waste"
        case .saving(let insight):
            return insight.title
        case .healthy:
            return "Subscriptions look healthy"
        }
    }

    private var subtitle: String {
        switch cardState {
        case .waste(let alert):
            return alert.reason
        case .saving(let insight):
            return insight.description
        case .healthy:
            return "No waste or overspend detected right now."
        }
    }

    private var isCritical: Bool {
        switch cardState {
        case .waste, .saving: return true
        case .healthy:        return false
        }
    }

    private var savingsAmount: Decimal? {
        switch cardState {
        case .waste(let alert):
            return alert.potentialSavings > 0 ? alert.potentialSavings : nil
        case .saving(let insight):
            return insight.potentialSavings > 0 ? insight.potentialSavings : nil
        case .healthy:
            return nil
        }
    }
}


// MARK: - Waste Score Callout Card

struct WasteScoreCalloutCard: View {
    @ObservedObject private var insightsEngine = RealInsightsEngine.shared

    private var wasteCount: Int { insightsEngine.wasteAlerts.count }

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .switchToAnalysisTab, object: nil)
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if wasteCount > 0 {
                        Text("We found \(wasteCount) waste \(wasteCount == 1 ? "issue" : "issues") in your subs")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Tap to see what you could cut")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color.obsidianTextSecondary)
                            .lineLimit(2)
                    } else {
                        Text("Hidden waste adds up fast")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Tap to run a waste scan on your subscriptions")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color.obsidianTextSecondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                wasteCount > 0 ? Color.orange.opacity(0.25) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
