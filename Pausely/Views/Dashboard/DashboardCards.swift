import SwiftUI

struct UpcomingRenewalsCarousel: View {
    let subscriptions: [Subscription]

    @ObservedObject private var currencyManager = CurrencyManager.shared

    var urgentRenewals: [Subscription] {
        subscriptions
            .filter { ($0.daysUntilRenewal ?? 8) <= 7 }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(urgentRenewals.count) this week")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(urgentRenewals) { sub in
                        RenewalCard(subscription: sub)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct RenewalCard: View {
    let subscription: Subscription

    @ObservedObject private var currencyManager = CurrencyManager.shared

    var urgencyColor: Color {
        let days = subscription.daysUntilRenewal ?? 7
        if days <= 1 { return .red }
        if days <= 3 { return .orange }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(subscription.daysUntilRenewal ?? 0)d")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(urgencyColor)
                    .clipShape(Capsule())
            }

            Spacer()

            Text(subscription.name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            let converted = currencyManager.convertToSelected(subscription.amount, from: subscription.currency)
            Text(currencyManager.format(converted))
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 120, height: 120)
        .glassBackground(cornerRadius: 20, strokeColor: urgencyColor.opacity(0.3), strokeWidth: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.name), renews in \(subscription.daysUntilRenewal ?? 0) days, \(currencyManager.format(currencyManager.convertToSelected(subscription.amount, from: subscription.currency)))")
        .accessibilityHint("Double-tap to view details")
    }
}

struct RecentSubscriptionsCarousel: View {
    let subscriptions: [Subscription]

    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                NavigationLink {
                    SubscriptionsListView()
                } label: {
                    Text("See All")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.luxuryPurple)
                }
            }
            .padding(.horizontal, 20)

            if subscriptions.isEmpty {
                EmptySubscriptionsCard()
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(subscriptions.prefix(5)) { sub in
                            RecentSubCard(subscription: sub)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct RecentSubCard: View {
    let subscription: Subscription

    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.luxuryPurple.opacity(0.3), .luxuryPink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Text(String(subscription.name.prefix(1)))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 2) {
                Text(subscription.name)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                let converted = currencyManager.convertToSelected(subscription.amount, from: subscription.currency)
                Text(currencyManager.format(converted))
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100)
        .padding(.vertical, 16)
        .glassBackground(cornerRadius: 20, strokeColor: .white.opacity(0.15), strokeWidth: 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.name), \(currencyManager.format(currencyManager.convertToSelected(subscription.amount, from: subscription.currency)))")
        .accessibilityHint("Double-tap to view details")
    }
}

struct EmptySubscriptionsCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.luxuryPurple.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "plus.circle")
                    .font(.title.weight(.regular))
                    .foregroundStyle(Color.luxuryPurple)
            }

            VStack(spacing: 4) {
                Text("No subscriptions yet")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Add your first subscription to start tracking")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .glassBackground(cornerRadius: 20, strokeColor: .white.opacity(0.1), strokeWidth: 0.5)
    }
}

struct UsageHighlightsSection: View {
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var store = SubscriptionStore.shared

    var topUsage: [(name: String, minutes: Int, isEstimated: Bool)] {
        store.subscriptions
            .compactMap { sub in
                let usage = screenTimeManager.getUsage(for: sub.name)
                let minutes = usage?.minutesUsed ?? 0
                let isEstimated = usage?.isEstimated ?? false
                return minutes > 0 ? (sub.name, minutes, isEstimated) : nil
            }
            .sorted { $0.minutes > $1.minutes }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Usage")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                EstimateBadge(isEstimated: true)
            }

            VStack(spacing: 8) {
                ForEach(topUsage, id: \.name) { item in
                    UsageHighlightRow(name: item.name, minutes: item.minutes, isEstimated: item.isEstimated)
                }
            }

            Text("Usage is estimated from Screen Time session data")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct UsageHighlightRow: View {
    let name: String
    let minutes: Int
    let isEstimated: Bool

    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.luxuryPurple, .luxuryPink], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * usageProgress)
                }
            }
            .frame(width: 60, height: 6)

            Text(String(name.prefix(12)))
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(formatMinutes(minutes))
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)

            EstimateBadge(isEstimated: isEstimated)
        }
        .padding(12)
        .glassBackground(cornerRadius: 12, strokeColor: .clear, strokeWidth: 0)
    }

    private var usageProgress: CGFloat {
        CGFloat(minutes) / 3000
    }

    private func formatMinutes(_ mins: Int) -> String {
        if mins < 60 {
            return "\(mins)m"
        } else {
            let hours = mins / 60
            let remainingMins = mins % 60
            return remainingMins > 0 ? "\(hours)h \(remainingMins)m" : "\(hours)h"
        }
    }
}
