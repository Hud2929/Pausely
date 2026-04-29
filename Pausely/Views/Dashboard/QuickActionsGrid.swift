import SwiftUI
import TipKit

struct QuickActionsGrid: View {
    let onAddTap: () -> Void
    let onPaywallTap: () -> Void

    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var showingPauseSheet = false
    @State private var showingCompareSheet = false
    private let addTip = AddSubscriptionTip()

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
                // .popoverTip(addTip, arrowEdge: .bottom) // Disabled for testing

                QuickActionButton(
                    icon: "pause.circle.fill",
                    title: "Pause",
                    subtitle: paymentManager.canPauseSubscriptions ? "\(store.activeSubscriptions.count)" : "Pro",
                    gradient: paymentManager.canPauseSubscriptions ? [.luxuryPink, .orange] : [.gray, .gray.opacity(0.5)]
                ) {
                    if paymentManager.canPauseSubscriptions {
                        showingPauseSheet = true
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
                    showingCompareSheet = true
                }
            }
        }
        .sheet(isPresented: $showingPauseSheet) {
            QuickPauseSheet()
        }
        .sheet(isPresented: $showingCompareSheet) {
            SubscriptionCompareView()
        }
    }
}

// MARK: - Quick Pause Sheet
struct QuickPauseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var selectedSubscription: Subscription? = nil
    @State private var showingPauseOptions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if store.activeSubscriptions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "pause.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            Text("No active subscriptions")
                                .font(.system(.title3, design: .rounded).weight(.semibold))

                            Text("Add a subscription first to set a pause reminder.")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 80)
                        .padding(.horizontal, 32)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose a subscription to pause")
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            ForEach(store.activeSubscriptions) { subscription in
                                QuickPauseRow(
                                    subscription: subscription,
                                    onPause: {
                                        selectedSubscription = subscription
                                        showingPauseOptions = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
            }
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Quick Pause")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .sheet(item: $selectedSubscription) { subscription in
                RevolutionaryPauseSheet(
                    subscription: subscription,
                    onPause: { duration in
                        let reminderDate = Calendar.current.date(
                            byAdding: duration.calendarComponent,
                            value: duration.value,
                            to: Date()
                        ) ?? Date()
                        let pauseURL = SubscriptionActionManager.shared.getService(for: subscription.name)?.pauseURL
                        NotificationManager.shared.schedulePauseReminder(
                            for: subscription,
                            reminderDate: reminderDate,
                            pauseURL: pauseURL
                        )
                        selectedSubscription = nil
                        dismiss()
                    },
                    onDismiss: {
                        selectedSubscription = nil
                    }
                )
            }
        }
    }
}

// MARK: - Quick Pause Row
struct QuickPauseRow: View {
    let subscription: Subscription
    let onPause: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentMint.opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(String(subscription.name.prefix(1)))
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.accentMint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text(CurrencyManager.shared.format(subscription.monthlyCost) + "/month")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onPause) {
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle.fill")
                        .font(.caption)
                    Text("Pause")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(Color.accentMint)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentMint.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
