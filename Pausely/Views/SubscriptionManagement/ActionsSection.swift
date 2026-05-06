import SwiftUI

struct ActionsSection: View {
    let subscription: Subscription
    let alternatives: [AlternativeService]
    @ObservedObject var paymentManager: PaymentManager
    @ObservedObject var actionManager: SubscriptionActionManager
    let onPaywall: () -> Void
    let onUsageHistory: () -> Void
    let onPriceHistory: () -> Void
    let onAnnualSavings: () -> Void

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
