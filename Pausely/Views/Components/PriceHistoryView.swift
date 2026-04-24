//
//  PriceHistoryView.swift
//  Pausely
//
//  View subscription price changes over time
//

import SwiftUI

struct PriceHistoryView: View {
    let subscription: Subscription
    @ObservedObject private var tracker = PriceHistoryTracker.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.dismiss) private var dismiss

    var history: [PriceHistoryEntry] {
        tracker.history(for: subscription.id)
    }

    var trend: PriceTrend {
        tracker.priceTrend(for: subscription.id)
    }

    var percentageChange: Double {
        tracker.percentageIncrease(for: subscription.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if history.count >= 2 {
                        trendCard
                        historyList
                        projectionCard
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle("Price History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var trendCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Price Trend")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 6) {
                        let converted = currencyManager.convertToSelected(subscription.amount, from: subscription.currency)
                        Text(currencyManager.format(converted))
                            .font(.system(.largeTitle, design: .rounded).weight(.black))
                            .foregroundStyle(.primary)

                        if percentageChange != 0 {
                            HStack(spacing: 4) {
                                Image(systemName: trend == .increasing ? "arrow.up" : "arrow.down")
                                Text("\(String(format: "%.1f", abs(percentageChange)))%")
                            }
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(trend == .increasing ? Color.semanticDestructive : Color.semanticSuccess)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                (trend == .increasing ? Color.semanticDestructive : Color.semanticSuccess).opacity(0.12)
                            )
                            .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(trendColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: trendIcon)
                        .font(.title2)
                        .foregroundStyle(trendColor)
                }
            }

            if history.count >= 2, let first = history.first {
                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Originally")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        let originalConverted = currencyManager.convertToSelected(first.amount, from: first.currency)
                        Text(currencyManager.format(originalConverted))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                            .strikethrough(trend == .increasing)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Since Tracked")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        let totalIncrease = tracker.totalPriceIncrease(for: subscription.id)
                        let converted = currencyManager.convertToSelected(totalIncrease, from: subscription.currency)
                        Text(currencyManager.format(converted))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(trend == .increasing ? Color.semanticDestructive : Color.semanticSuccess)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changes")
                .font(.system(.headline, design: .rounded).weight(.bold))

            VStack(spacing: 8) {
                ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                    HistoryEntryRow(
                        entry: entry,
                        previousEntry: index > 0 ? history[index - 1] : nil,
                        currencyManager: currencyManager
                    )
                }
            }
        }
    }

    private var projectionCard: some View {
        let projected = tracker.projectedAnnualCost(for: subscription)
        let currentAnnual = subscription.annualCost
        let diff = projected - currentAnnual

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.luxuryGold.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundStyle(Color.luxuryGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Year Projection")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("Based on historical price changes")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            let projectedConverted = currencyManager.convertToSelected(projected, from: subscription.currency)
            Text(currencyManager.format(projectedConverted))
                .font(.system(.title2, design: .rounded).weight(.bold))

            if diff > 0 {
                let diffConverted = currencyManager.convertToSelected(diff, from: subscription.currency)
                Text("+\(currencyManager.format(diffConverted)) more than current annual cost")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.semanticDestructive)
            }
        }
        .padding(16)
        .background(Color.luxuryGold.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.luxuryGold.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(Color.luxuryGold.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.largeTitle)
                    .foregroundStyle(Color.luxuryGold)
            }

            VStack(spacing: 8) {
                Text("No Price History")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text("Price changes will be tracked automatically when you edit a subscription's cost.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    private var trendColor: Color {
        switch trend {
        case .increasing: return .semanticDestructive
        case .decreasing: return .semanticSuccess
        case .stable: return .secondary
        }
    }

    private var trendIcon: String {
        switch trend {
        case .increasing: return "arrow.up.forward"
        case .decreasing: return "arrow.down.forward"
        case .stable: return "minus"
        }
    }
}

// MARK: - History Entry Row

struct HistoryEntryRow: View {
    let entry: PriceHistoryEntry
    let previousEntry: PriceHistoryEntry?
    let currencyManager: CurrencyManager

    var changePercentage: Double? {
        guard let prev = previousEntry else { return nil }
        let oldAmount = Double(truncating: prev.amount as NSDecimalNumber)
        let newAmount = Double(truncating: entry.amount as NSDecimalNumber)
        guard oldAmount > 0 else { return nil }
        return ((newAmount - oldAmount) / oldAmount) * 100
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                let converted = currencyManager.convertToSelected(entry.amount, from: entry.currency)
                Text(currencyManager.format(converted))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))

                Text(entry.date, style: .date)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let change = changePercentage {
                HStack(spacing: 4) {
                    Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text("\(String(format: "%.1f", abs(change)))%")
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(change > 0 ? Color.semanticDestructive : Color.semanticSuccess)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (change > 0 ? Color.semanticDestructive : Color.semanticSuccess).opacity(0.12)
                )
                .clipShape(Capsule())
            } else {
                Text("First Record")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.obsidianElevated)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.obsidianElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
