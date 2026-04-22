import SwiftUI

struct HeroSpendCard: View {
    let amount: Decimal
    @Binding var timeframe: DashboardTimeframe
    let subscriptionCount: Int
    var isLoading: Bool = false

    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var appear = false
    @State private var animateChart = false

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                skeletonContent
            } else {
                headerRow
                chartRow
                statsRow
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.obsidianBorder, lineWidth: 1)
                )
        )
        .shadow(color: .luxuryPurple.opacity(0.15), radius: 30, x: 0, y: 15)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animateChart = true
            }
        }
    }

    private var skeletonContent: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 100, height: 14)
                        .shimmer()

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 140, height: 14)
                        .shimmer()
                }

                Spacer()

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 28)
                    .shimmer()
            }

            HStack(spacing: 24) {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .shimmer()

                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 140, height: 36)
                        .shimmer()

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 80, height: 18)
                        .shimmer()
                }

                Spacer()
            }

            HStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 50)
                        .shimmer()
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Spending")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("\(subscriptionCount) active subscription\(subscriptionCount == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            timeframeSelector
        }
    }

    private var timeframeSelector: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTimeframe.allCases, id: \.self) { tf in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        timeframe = tf
                    }
                    HapticStyle.light.trigger()
                }) {
                    Text(tf.short.uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(timeframe == tf ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(timeframe == tf ? Color.luxuryPurple : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    private var chartRow: some View {
        HStack(spacing: 24) {
            circularChart
            amountDisplay
        }
    }

    private var circularChart: some View {
        ZStack {
            Circle()
                .stroke(Color.obsidianElevated, lineWidth: 12)
                .frame(width: 100, height: 100)

            Circle()
                .trim(from: 0, to: animateChart ? 1 : 0)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.accentMint,
                            Color.accentMint.opacity(0.6),
                            Color.luxuryPurple,
                            Color.luxuryPink,
                            Color.luxuryGold,
                            Color.accentMint
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(currencyManager.currencySymbol(for: currencyManager.selectedCurrency))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)

                Text(formatAmount(amount))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.obsidianText)
            }
        }
    }

    private var amountDisplay: some View {
        VStack(alignment: .leading, spacing: 4) {
            AnimatedCounter(
                value: amount,
                currencyCode: currencyManager.selectedCurrency,
                font: .system(size: 36, weight: .bold, design: .rounded),
                color: .luxuryGold
            )

            Text("per \(timeframeLabel)")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if currencyManager.selectedCurrency != "USD" {
                HStack(spacing: 4) {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(currencyManager.currentCurrency.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.luxuryGold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeframeLabel: String {
        switch timeframe {
        case .weekly: return "week"
        case .monthly: return "month"
        case .yearly: return "year"
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            HeroStatPill(
                title: "Monthly",
                value: currencyManager.currencySymbol(for: currencyManager.selectedCurrency) + formatAmount(amount),
                color: Color.accentMint
            )

            HeroStatPill(
                title: "Yearly",
                value: currencyManager.currencySymbol(for: currencyManager.selectedCurrency) + formatAmount(amount * 12),
                color: Color.luxuryGold
            )

            HeroStatPill(
                title: "Weekly",
                value: currencyManager.currencySymbol(for: currencyManager.selectedCurrency) + formatAmount(Decimal(Double(truncating: amount as NSDecimalNumber) / 4.33)),
                color: Color.luxuryPurple
            )
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let doubleAmount = Double(truncating: amount as NSDecimalNumber)
        if doubleAmount >= 1000 {
            return String(format: "%.1fK", doubleAmount / 1000)
        } else if doubleAmount == floor(doubleAmount) {
            return String(format: "%.0f", doubleAmount)
        } else {
            return String(format: "%.2f", doubleAmount)
        }
    }
}

struct HeroStatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.obsidianTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.obsidianElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
