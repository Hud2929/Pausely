import SwiftUI

@MainActor
struct CategorySpendingSection: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var appear = false

    private var categoryData: [(category: SubscriptionCategory, amount: Decimal, percentage: Double)] {
        let byCategory = store.subscriptionsByCategory()
        let total = byCategory.reduce(Decimal(0)) { $0 + $1.total }
        guard total > 0 else { return [] }

        return byCategory
            .map {
                let catEnum = SubscriptionCategory(rawValue: $0.category) ?? .other
                let pct = Double(truncating: ($0.total / total * 100) as NSNumber)
                return (category: catEnum, amount: $0.total, percentage: pct)
            }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spending by Category")
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.primary)

                    Text("Where your money actually goes")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if categoryData.isEmpty {
                Text("Add subscriptions to see your category breakdown")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(categoryData.prefix(6), id: \.category) { item in
                        CategorySpendingBarRow(
                            category: item.category,
                            amount: item.amount,
                            percentage: item.percentage,
                            maxPercentage: categoryData.first?.percentage ?? 1
                        )
                    }
                }

                if categoryData.count > 6 {
                    Text("+ \(categoryData.count - 6) more categories")
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                appear = true
            }
        }
    }
}

struct CategorySpendingBarRow: View {
    let category: SubscriptionCategory
    let amount: Decimal
    let percentage: Double
    let maxPercentage: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundStyle(barColor)
                .frame(width: 24, height: 24)
                .background(barColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.displayName)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(CurrencyManager.shared.format(amount))
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(.primary)
                        .fontWeight(.semibold)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor)
                            .frame(width: maxPercentage > 0 ? CGFloat(percentage / maxPercentage) * geo.size.width : 0, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private var barColor: Color {
        switch category {
        case .entertainment: return .purple
        case .music: return .pink
        case .productivity: return .blue
        case .healthFitness: return .green
        case .cloudStorage: return .cyan
        case .education: return .orange
        case .news: return .brown
        case .utilities: return .gray
        case .social: return .teal
        case .shopping: return .red
        case .food: return .yellow
        case .sports: return .indigo
        case .finance: return .mint
        case .phone: return .blue.opacity(0.7)
        case .insurance: return .green.opacity(0.7)
        case .gym: return .orange.opacity(0.8)
        case .automotive: return .red.opacity(0.7)
        case .home: return .purple.opacity(0.7)
        case .pet: return .brown.opacity(0.8)
        case .personalCare: return .pink.opacity(0.7)
        case .other: return .secondary
        }
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        ScrollView {
            CategorySpendingSection()
                .padding(.top, 40)
        }
    }
}
