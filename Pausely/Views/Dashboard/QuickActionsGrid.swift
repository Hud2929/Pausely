import SwiftUI

struct QuickActionsGrid: View {
    let onAddTap: () -> Void
    let onPaywallTap: () -> Void

    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var showingComingSoonAlert = false
    @State private var comingSoonMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Add",
                    subtitle: paymentManager.isPremium ? "New" : "\(store.subscriptions.count)/2",
                    gradient: [.luxuryTeal, .luxuryPurple]
                ) {
                    if paymentManager.canAddSubscription(currentCount: store.subscriptions.count) {
                        onAddTap()
                    } else {
                        onPaywallTap()
                    }
                }

                QuickActionButton(
                    icon: "pause.circle.fill",
                    title: "Pause",
                    subtitle: paymentManager.canPauseSubscriptions ? "\(store.pausableSubscriptions.count) avail" : "Pro",
                    gradient: paymentManager.canPauseSubscriptions ? [.luxuryPink, .orange] : [.gray, .gray.opacity(0.5)]
                ) {
                    if paymentManager.canPauseSubscriptions {
                        comingSoonMessage = "Pause feature is coming soon! You'll be able to pause select subscriptions that support it."
                        showingComingSoonAlert = true
                    } else {
                        onPaywallTap()
                    }
                }

                QuickActionButton(
                    icon: "chart.pie.fill",
                    title: "Compare",
                    subtitle: "Analyze",
                    gradient: [.luxuryGold, .luxuryPink]
                ) {
                    comingSoonMessage = "Compare feature is coming soon! You'll be able to compare subscription plans side-by-side."
                    showingComingSoonAlert = true
                }
            }
        }
        .alert("Coming Soon", isPresented: $showingComingSoonAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(comingSoonMessage)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticStyle.medium.trigger()
            action()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: gradient[0].opacity(0.4), radius: 10, x: 0, y: 5)

                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassBackground(cornerRadius: 20, strokeColor: .white.opacity(0.2), strokeWidth: 0.5)
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}
