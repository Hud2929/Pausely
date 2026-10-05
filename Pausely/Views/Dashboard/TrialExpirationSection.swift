import SwiftUI

// MARK: - Trial Expiration Section
//
// Shows subscriptions whose free trial ends within 7 days.
// Only appears when there are expiring trials — otherwise hidden entirely.

struct TrialExpirationSection: View {
    let subscriptions: [Subscription]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trials Ending Soon")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .tracking(0.3)

                Spacer()

                Text("\(subscriptions.count) ending")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.semanticWarning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.semanticWarning.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(spacing: 8) {
                ForEach(subscriptions.sorted(by: { ($0.trialEndsAt ?? .distantFuture) < ($1.trialEndsAt ?? .distantFuture) })) { sub in
                    TrialExpirationRow(subscription: sub)
                }
            }
        }
    }
}

private struct TrialExpirationRow: View {
    let subscription: Subscription

    private var daysLeft: Int {
        guard let trial = subscription.trialEndsAt else { return 0 }
        return Calendar.current.dateComponents([.day], from: Date(), to: trial).day ?? 0
    }

    private var urgencyColor: Color {
        if daysLeft <= 1 { return .semanticDestructive }
        if daysLeft <= 3 { return .semanticWarning }
        return Color.obsidianTextSecondary
    }

    private var urgencyLabel: String {
        if daysLeft == 0 { return "Ends today" }
        if daysLeft == 1 { return "Ends tomorrow" }
        return "Ends in \(daysLeft) days"
    }

    var body: some View {
        HStack(spacing: 12) {
            ServiceLogoView(name: subscription.name, category: subscription.category, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text(urgencyLabel)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(urgencyColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyManager.shared.format(subscription.monthlyCost))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text("then /\(subscription.billingFrequency.shortDisplay)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(urgencyColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(urgencyColor.opacity(0.18), lineWidth: 1)
                )
        )
    }
}
