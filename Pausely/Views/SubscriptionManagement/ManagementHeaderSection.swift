import SwiftUI

struct ManagementHeaderSection: View {
    let subscription: Subscription
    let currentUsageMinutes: Int
    let usageStats: AppUsageStats?
    let costPerHour: Decimal?
    let difficulty: CancellationDifficulty
    let screenTimeManager: ScreenTimeManager

    private var iconColor: Color {
        switch subscription.category?.lowercased() {
        case "entertainment": return .red
        case "music": return .pink
        case "storage": return .blue
        case "productivity": return .green
        default: return .purple
        }
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .veryHard: return .red
        }
    }

    private var usageColor: Color {
        if currentUsageMinutes < 30 { return .red }
        if currentUsageMinutes < 60 { return .orange }
        if currentUsageMinutes < 180 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [iconColor.opacity(0.3), iconColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text(String(subscription.name.prefix(1)))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text(subscription.name)
                .font(.title.weight(.bold))
                .foregroundColor(.primary)

            Text(subscription.displayAmountInUserCurrency + "/" + subscription.billingFrequency.rawValue)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if currentUsageMinutes > 0 {
                HStack {
                    Image(systemName: usageStats?.source.icon ?? "clock")
                    Text("This month: \(screenTimeManager.formatMinutes(currentUsageMinutes))")
                    EstimateBadge(isEstimated: screenTimeManager.isEstimated(for: subscription.name))
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(usageColor.opacity(0.2))
                .foregroundStyle(usageColor)
                .cornerRadius(8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Usage this month: \(screenTimeManager.formatMinutes(currentUsageMinutes))")
            }

            if let cph = costPerHour {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Cost per hour: \(formatCostPerHour(cph))")
                }
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(costPerHourColor(cph).opacity(0.2))
                .foregroundStyle(costPerHourColor(cph))
                .cornerRadius(8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Cost per hour: \(formatCostPerHour(cph))")
            }

            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("Cancellation Difficulty: \(difficulty.rawValue)")
            }
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(difficultyColor.opacity(0.2))
            .foregroundColor(difficultyColor)
            .cornerRadius(8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cancellation difficulty: \(difficulty.rawValue)")
        }
        .padding()
        .glassCard(color: iconColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.name), \(subscription.displayAmountInUserCurrency) per \(subscription.billingFrequency.rawValue)")
        .accessibilityHint("Double-tap to view details")
    }

    private func formatCostPerHour(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = subscription.currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    private func costPerHourColor(_ value: Decimal) -> Color {
        let doubleValue = Double(truncating: value as NSNumber)
        if doubleValue > 20 { return .red }
        if doubleValue > 10 { return .orange }
        if doubleValue > 5 { return .yellow }
        return .green
    }
}
