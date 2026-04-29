import SwiftUI

@MainActor
struct BiggestExpensesSection: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var appear = false

    private var topExpenses: [Subscription] {
        store.activeSubscriptions
            .sorted { $0.monthlyCost > $1.monthlyCost }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Biggest Expenses")
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.primary)

                    Text("Your top 3 highest-cost subscriptions")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(Array(topExpenses.enumerated()), id: \.element.id) { index, sub in
                    BiggestExpenseRow(rank: index + 1, subscription: sub)
                }
            }

            if store.activeSubscriptions.count > 3 {
                let totalTop = topExpenses.reduce(Decimal(0)) { $0 + $1.monthlyCost }
                let percentage = store.totalMonthlySpend > 0
                    ? Int(Double(truncating: (totalTop / store.totalMonthlySpend * 100) as NSNumber))
                    : 0

                Text("These 3 make up \(percentage)% of your monthly spend")
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appear = true
            }
        }
    }
}

struct BiggestExpenseRow: View {
    let rank: Int
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(rankColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subscription.billingFrequency.displayName)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(subscription.displayMonthlyCostInUserCurrency)
                .font(AppTypography.headlineSmall)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .glassBackground(cornerRadius: 14, strokeColor: rankColor.opacity(0.15), strokeWidth: 0.5)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .semanticDestructive
        case 2: return .semanticWarning
        case 3: return Color.luxuryTeal
        default: return .secondary
        }
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        ScrollView {
            BiggestExpensesSection()
                .padding(.top, 40)
        }
    }
}
