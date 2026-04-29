import SwiftUI

struct ActionsSection: View {
    let subscription: Subscription
    let alternatives: [AlternativeService]
    @ObservedObject var paymentManager: PaymentManager
    @ObservedObject var actionManager: SubscriptionActionManager
    let onPaywall: () -> Void
    let onUsageHistory: () -> Void
    let onSharing: () -> Void
    let onPriceHistory: () -> Void
    let onAnnualSavings: () -> Void
    let onCancellationRequest: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.title2.bold())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if paymentManager.isPremium {
                RevolutionaryCancelButton(subscription: subscription)
            } else {
                ActionButton(
                    title: "Cancel Subscription",
                    subtitle: "One-tap cancel (Pro)",
                    icon: "xmark.circle.fill",
                    color: .red,
                    isPremium: true,
                    action: onPaywall
                )
            }

            ActionButton(
                title: "Cancel for Me",
                subtitle: "We handle it — $5 one-time",
                icon: "xmark.shield.fill",
                color: .purple,
                isPremium: false,
                action: onCancellationRequest
            )

            if paymentManager.canPauseSubscriptions && actionManager.canPause(subscription) {
                if subscription.isPaused {
                    RevolutionaryResumeButton(subscription: subscription)
                } else {
                    RevolutionaryPauseButton(subscription: subscription)
                }
            }

            if !alternatives.isEmpty {
                ActionButton(
                    title: "Find Cheaper Alternative",
                    subtitle: "\(alternatives.count) options found",
                    icon: "arrow.left.arrow.right.circle.fill",
                    color: .green,
                    isPremium: true,
                    action: {
                        if paymentManager.isPremium {
                            // Scroll to alternatives
                        } else {
                            onPaywall()
                        }
                    }
                )
            }

            ActionButton(
                title: "View Usage History",
                subtitle: "See past months",
                icon: "chart.bar.fill",
                color: .blue,
                isPremium: false,
                action: onUsageHistory
            )

            ActionButton(
                title: "Edit Details",
                subtitle: "Update amount or billing",
                icon: "pencil.circle.fill",
                color: .blue,
                isPremium: false,
                action: { }
            )

            ActionButton(
                title: "Split Cost",
                subtitle: "Share with friends or family",
                icon: "person.2.fill",
                color: .purple,
                isPremium: false,
                action: onSharing
            )

            ActionButton(
                title: "Price History",
                subtitle: "Track price changes over time",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange,
                isPremium: false,
                action: onPriceHistory
            )

            if subscription.billingFrequency == .monthly {
                ActionButton(
                    title: "Annual Savings",
                    subtitle: "See savings with yearly billing",
                    icon: "calendar.badge.checkmark",
                    color: .green,
                    isPremium: false,
                    action: onAnnualSavings
                )
            }
        }
    }
}
