import SwiftUI

struct ArtisticSubscriptionCard: View {
    let subscription: Subscription
    let index: Int
    let onTap: () -> Void
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var isPressed = false
    @State private var appear = false

    var cardColor: Color {
        let colors: [Color] = [
            BrandColors.primary,
            BrandColors.secondary,
            BrandColors.accent,
            SemanticColors.success,
            SemanticColors.info,
            SemanticColors.warning
        ]
        return colors[index % colors.count]
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left color bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(cardColor)
                    .frame(width: 4)
                    .padding(.vertical, 20)

                // Content
                HStack(spacing: 16) {
                    // Icon with gradient background
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [cardColor.opacity(0.3), cardColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)

                        Text(String(subscription.name.prefix(1)))
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(subscription.name)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 8) {
                            // Billing frequency badge
                            Text(subscription.billingFrequency.displayName)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(BackgroundColors.tertiary)
                                )
                                .foregroundColor(TextColors.secondary)

                            if subscription.isPaused {
                                Text("Paused")
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(SemanticColors.warning.opacity(0.2))
                                    )
                                    .foregroundColor(SemanticColors.warning)
                            }
                        }
                    }

                    Spacer()

                    // Price
                    VStack(alignment: .trailing, spacing: 4) {
                        let converted = currencyManager.convertToSelected(
                            subscription.amount,
                            from: subscription.currency
                        )
                        Text(currencyManager.format(converted))
                            .font(.headline.weight(.bold))
                            .foregroundColor(cardColor)

                        if let days = subscription.daysUntilRenewal {
                            Text(days == 0 ? "Today" : "\(days)d")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(days <= 3 ? SemanticColors.error : TextColors.tertiary)
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 20)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(BackgroundColors.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(cardColor.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: cardColor.opacity(0.1), radius: 10, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 20)
        }
        .buttonStyle(PlainButtonStyle())
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.name), \(currencyManager.format(currencyManager.convertToSelected(subscription.amount, from: subscription.currency))) per \(subscription.billingFrequency.displayName.lowercased())\(subscription.isPaused ? ", paused" : "")")
        .accessibilityHint("Double-tap to view details")
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(Double(index) * 0.05)) {
                appear = true
            }
        }
    }
}
