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
        ServiceLogoView(name: subscription?.name ?? "", category: subscription?.category, size: 52)
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
            Text(sub.chargeText)  // the charge itself, in what it's billed in
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
        return Calendar.current.calendarDays(from: Date(), to: nextDate)
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
        let amount = sub.chargeText
        if sub.calculatedNextBillingDate != nil {
            return "Next payment: \(sub.name), \(amount), \(renewalDateText), \(daysUntilText)"
        } else {
            return "Next payment: \(sub.name), \(amount). Billing date not set."
        }
    }
}


