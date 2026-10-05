import SwiftUI

struct ArtisticSubscriptionCard: View {
    let subscription: Subscription
    let index: Int
    let onTap: () -> Void
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var isPressed = false
    @State private var appear = false

    private var cardAccessibilityLabel: String {
        let amount = currencyManager.format(currencyManager.convertToSelected(subscription.amount, from: subscription.currency))
        var parts = [subscription.name, amount + " per " + subscription.billingFrequency.displayName.lowercased()]
        if subscription.isPaused { parts.append("paused") }
        if let days = subscription.daysUntilRenewal, days >= 0, days <= 7 {
            parts.append(days == 0 ? "renews today" : "renews in \(days) \(days == 1 ? "day" : "days")")
        }
        return parts.joined(separator: ", ")
    }

    var cardColor: Color {
        if let days = subscription.daysUntilRenewal {
            if days <= 2 { return Color.semanticDestructive }
            if days <= 6 { return Color.semanticWarning }
        }
        return Color.accentMint
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 40pt circle avatar — compact, colored
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Text(String(subscription.name.prefix(1)))
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(cardColor)
                }

                // Name + frequency
                VStack(alignment: .leading, spacing: 3) {
                    Text(subscription.name)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(subscription.billingFrequency.displayName)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)

                        if subscription.isPaused {
                            Text("Paused")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.semanticWarning)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.semanticWarning.opacity(0.15))
                                )
                        }
                    }
                }

                Spacer()

                // Amount + countdown
                VStack(alignment: .trailing, spacing: 3) {
                    let converted = currencyManager.convertToSelected(
                        subscription.amount,
                        from: subscription.currency
                    )
                    Text(currencyManager.format(converted))
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(cardColor)

                    if let days = subscription.daysUntilRenewal {
                        let countdownText: String = {
                            if days < 0 { return "Overdue" }
                            if days == 0 { return "Today" }
                            if days == 1 { return "Tomorrow" }
                            return "in \(days)d"
                        }()
                        Text(countdownText)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(days <= 3 ? Color.semanticDestructive : Color.obsidianTextTertiary)
                    } else {
                        Text("No date")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.15)) { isPressed = false }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Double tap to view details and manage")
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(Double(index) * 0.04)) {
                appear = true
            }
        }
    }
}
