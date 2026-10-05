import SwiftUI
import TipKit

struct QuickActionsGrid: View {
    let onAddTap: () -> Void
    let onPaywallTap: () -> Void

    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var showingUpcomingSheet = false
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
                    gradient: [.accentMint, .accentMint]
                ) {
                    if paymentManager.canAddSubscription(currentCount: store.subscriptions.count) {
                        onAddTap()
                    } else {
                        onPaywallTap()
                    }
                }
                // .popoverTip(addTip, arrowEdge: .bottom) // Disabled for testing

                QuickActionButton(
                    icon: "calendar.badge.clock",
                    title: "Upcoming",
                    subtitle: "Bills",
                    gradient: [.accentMint, .accentMint]
                ) {
                    showingUpcomingSheet = true
                }

                QuickActionButton(
                    icon: "arrow.left.arrow.right.circle.fill",
                    title: "Compare",
                    subtitle: "Catalog",
                    gradient: [.accentMint, .accentMint]
                ) {
                    showingCompareSheet = true
                }
            }
        }
        .sheet(isPresented: $showingUpcomingSheet) {
            UpcomingBillsSheet()
        }
        .sheet(isPresented: $showingCompareSheet) {
            CatalogCategoryCompareView()
        }
    }
}

// MARK: - Upcoming Bills Sheet
struct UpcomingBillsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared

    private var sortedByBillingDate: [Subscription] {
        store.subscriptions
            .filter { $0.nextBillingDate != nil }
            .sorted { ($0.nextBillingDate ?? .distantFuture) < ($1.nextBillingDate ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if sortedByBillingDate.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No upcoming bills")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                            Text("Add subscriptions to see their renewal dates here.")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 80)
                        .padding(.horizontal, 32)
                    } else {
                        ForEach(sortedByBillingDate) { sub in
                            UpcomingBillRow(subscription: sub)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Upcoming Bills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Upcoming Bill Row
struct UpcomingBillRow: View {
    let subscription: Subscription

    private var daysUntilBilling: Int? {
        guard let date = subscription.nextBillingDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day
    }

    private var urgencyColor: Color {
        guard let days = daysUntilBilling else { return .secondary }
        if days < 0 { return Color.semanticDestructive }
        if days <= 3 { return .orange }
        if days <= 7 { return .yellow }
        return Color.semanticSuccess
    }

    private var daysLabel: String {
        guard let days = daysUntilBilling else { return "Unknown" }
        if days < 0 { return "Overdue" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(urgencyColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(subscription.name.prefix(1)))
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(urgencyColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                if let date = subscription.nextBillingDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                let converted = CurrencyManager.shared.convertToSelected(subscription.amount, from: subscription.currency)
                Text(CurrencyManager.shared.format(converted))
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(daysLabel)
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(urgencyColor)
            }
        }
        .padding(14)
        .surfaceCard(cornerRadius: 16)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]   // kept for API compatibility — accent color is used instead
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
                        .fill(Color.accentMint.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentMint)
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.obsidianText)

                    Text(subtitle)
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .surfaceCard(cornerRadius: 18)
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
