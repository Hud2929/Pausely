//
//  NextPaymentCard.swift
//  Pausely
//
//  Shows the nearest upcoming subscription renewal prominently
//

import SwiftUI

struct NextPaymentCard: View {
    let subscription: Subscription?

    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var appear = false

    var body: some View {
        if let sub = subscription {
            cardContent(for: sub)
        }
    }

    private func cardContent(for sub: Subscription) -> some View {
        Button(action: {
            NotificationCenter.default.post(
                name: .showSubscriptionManagement,
                object: nil,
                userInfo: ["subscription_id": sub.id.uuidString]
            )
        }) {
            HStack(spacing: 16) {
                cardIcon
                cardInfo(for: sub)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .background(cardBackground)
            .shadow(color: urgencyColor.opacity(0.08), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                appear = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("Double-tap to view subscription details")
    }

    private var cardIcon: some View {
        ZStack {
            Circle()
                .fill(urgencyColor.opacity(0.15))
                .frame(width: 52, height: 52)

            Image(systemName: "creditcard.fill")
                .font(.title3)
                .foregroundStyle(urgencyColor)
        }
    }

    private func cardInfo(for sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Next Payment")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if daysUntil <= 3 {
                    Text("SOON")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(urgencyColor)
                        .clipShape(Capsule())
                }
            }

            Text(sub.name)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            cardAmountAndDate(for: sub)
        }
    }

    private func cardAmountAndDate(for sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let converted = currencyManager.convertToSelected(sub.amount, from: sub.currency)
            Text(currencyManager.format(converted))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(urgencyColor)
                .lineLimit(1)

            if sub.calculatedNextBillingDate != nil {
                HStack(spacing: 8) {
                    Text(renewalDateText)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(daysUntilText)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(daysUntil <= 3 ? urgencyColor : .secondary)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.accentMint)
                    Text("Tap to set billing date")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.accentMint)
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.obsidianSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(urgencyColor.opacity(0.2), lineWidth: 1.5)
            )
    }

    private var daysUntil: Int {
        guard let nextDate = subscription?.calculatedNextBillingDate else { return Int.max }
        return Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
    }

    private var urgencyColor: Color {
        guard subscription?.calculatedNextBillingDate != nil else { return .accentMint }
        if daysUntil <= 1 { return .red }
        if daysUntil <= 3 { return .orange }
        if daysUntil <= 7 { return .yellow }
        return .accentMint
    }

    private var renewalDateText: String {
        guard let nextDate = subscription?.calculatedNextBillingDate else { return "Tap to set billing date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: nextDate)
    }

    private var daysUntilText: String {
        guard subscription?.calculatedNextBillingDate != nil else { return "Tap to set billing date" }
        if daysUntil == 0 { return "Today" }
        if daysUntil == 1 { return "Tomorrow" }
        if daysUntil < 0 { return "Overdue" }
        return "In \(daysUntil) days"
    }

    private var accessibilityLabelText: String {
        guard let sub = subscription else { return "Next payment" }
        let amount = currencyManager.format(currencyManager.convertToSelected(sub.amount, from: sub.currency))
        if sub.calculatedNextBillingDate != nil {
            return "Next payment: \(sub.name), \(amount), \(renewalDateText), \(daysUntilText)"
        } else {
            return "Next payment: \(sub.name), \(amount). Billing date not set."
        }
    }
}

// MARK: - Total Spend Summary Card
struct TotalSpendSummaryCard: View {
    let monthlySpend: Decimal
    let yearlySpend: Decimal
    let subscriptionCount: Int

    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var appear = false
    @State private var selectedTimeframe: DashboardTimeframe = .monthly

    var displayAmount: Decimal {
        switch selectedTimeframe {
        case .weekly: return monthlySpend / 4.33
        case .monthly: return monthlySpend
        case .yearly: return yearlySpend
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header with count
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Subscription Spend")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("\(subscriptionCount) active subscription\(subscriptionCount == 1 ? "" : "s") tracked")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Timeframe picker
                HStack(spacing: 0) {
                    ForEach(DashboardTimeframe.allCases, id: \.self) { tf in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTimeframe = tf
                            }
                            HapticStyle.light.trigger()
                        }) {
                            Text(tf.short.uppercased())
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(selectedTimeframe == tf ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(selectedTimeframe == tf ? Color.luxuryPurple : Color.clear)
                                )
                        }
                    }
                }
                .padding(3)
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(Capsule())
            }

            // Main amount
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currencyManager.currencySymbol(for: currencyManager.selectedCurrency))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.luxuryGold)

                Text(formattedAmount(displayAmount))
                    .font(.system(.largeTitle, design: .rounded).weight(.black))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text("/ \(timeframeLabel)")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Mini breakdown
            HStack(spacing: 12) {
                MiniSpendPill(
                    label: "Monthly",
                    amount: monthlySpend,
                    color: .accentMint
                )
                MiniSpendPill(
                    label: "Yearly",
                    amount: yearlySpend,
                    color: .luxuryGold
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
        .shadow(color: .luxuryPurple.opacity(0.1), radius: 30, x: 0, y: 15)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appear = true
            }
        }
    }

    private var timeframeLabel: String {
        switch selectedTimeframe {
        case .weekly: return "week"
        case .monthly: return "month"
        case .yearly: return "year"
        }
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        let doubleAmount = Double(truncating: amount as NSDecimalNumber)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: doubleAmount)) ?? "0.00"
    }
}

struct MiniSpendPill: View {
    let label: String
    let amount: Decimal
    let color: Color

    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(.tertiary)

                let converted = currencyManager.convertToSelected(amount, from: currencyManager.selectedCurrency)
                Text(currencyManager.format(converted))
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.obsidianElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }
}
