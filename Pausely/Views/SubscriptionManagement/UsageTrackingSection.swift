import SwiftUI

struct UsageTrackingSection: View {
    let subscription: Subscription
    @ObservedObject var screenTimeManager: ScreenTimeManager
    let currentUsageMinutes: Int
    let costPerHour: Decimal?
    let usageStats: AppUsageStats?
    let onEditUsage: () -> Void
    let onViewInsights: () -> Void

    private var usageColor: Color {
        if currentUsageMinutes < 30 { return .red }
        if currentUsageMinutes < 60 { return .orange }
        if currentUsageMinutes < 180 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Usage Tracking")
                    .font(.body.weight(.bold))

                Spacer()

                if let source = usageStats?.source {
                    HStack(spacing: 4) {
                        Image(systemName: source.icon)
                            .font(.caption)
                        Text(source.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.secondary)
                    .cornerRadius(8)
                }

                Button(action: onViewInsights) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .accessibilityLabel("View usage insights")

                Button(action: onEditUsage) {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundColor(.luxuryPurple)
                }
                .accessibilityLabel("Edit usage")
            }

            ScreenTimeDisclaimer()

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("This Month's Usage")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            EstimateBadge(isEstimated: screenTimeManager.isEstimated(for: subscription.name))
                        }

                        if currentUsageMinutes > 0 {
                            Text(screenTimeManager.formatMinutes(currentUsageMinutes))
                                .font(.title.weight(.bold))
                        } else {
                            Text("No data yet")
                                .font(.title2.weight(.medium))
                                .foregroundColor(.secondary)
                        }

                        if let stats = usageStats, let lastUpdated = stats.lastUpdated {
                            Text("Updated \(lastUpdated, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: min(CGFloat(currentUsageMinutes) / 600, 1.0))
                            .stroke(usageColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: currentUsageMinutes)

                        VStack(spacing: 0) {
                            Text("\(min(currentUsageMinutes * 100 / 600, 100))%")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.primary)
                            Text("of 10h")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let cph = costPerHour {
                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cost Per Hour")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(formatCostPerHour(cph))
                                .font(.title2.weight(.bold))
                                .foregroundColor(costPerHourColor(cph))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(efficiencyRating(cph))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(costPerHourColor(cph))

                            Text(efficiencyDescription(cph))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    usageBarChart
                }

                HStack(spacing: 8) {
                    QuickAddButton(minutes: 30, subscriptionName: subscription.name)
                    QuickAddButton(minutes: 60, subscriptionName: subscription.name)
                    QuickAddButton(minutes: 120, subscriptionName: subscription.name)

                    Spacer()
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(16)

            if !screenTimeManager.isTrackingEnabled {
                enableTrackingButton
            } else if screenTimeManager.authorizationStatus == .authorized {
                manualModeInfo
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(20)
    }

    private var usageBarChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Usage")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                ForEach(0..<7) { day in
                    let minutes = usageStats?.dailyBreakdown?[day].minutes ?? 0
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(minutes > 0 ? usageColor : Color.gray.opacity(0.2))
                            .frame(height: max(CGFloat(minutes) / 120 * 40, 4))

                        Text("\(day)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 50)
        }
    }

    private var enableTrackingButton: some View {
        Button(action: {
            Task {
                try? await screenTimeManager.requestAuthorization()
            }
        }) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                Text("Enable Automatic Screen Time Tracking")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient.premium
            )
            .cornerRadius(12)
        }
    }

    private var manualModeInfo: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Manual Tracking Mode")
                    .font(.subheadline.weight(.semibold))
                Text("Tap + buttons to add usage time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("Screen time info")
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
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

    private func efficiencyRating(_ value: Decimal) -> String {
        let doubleValue = Double(truncating: value as NSNumber)
        if doubleValue > 20 { return "Poor Value" }
        if doubleValue > 10 { return "Fair Value" }
        if doubleValue > 5 { return "Good Value" }
        return "Great Value!"
    }

    private func efficiencyDescription(_ value: Decimal) -> String {
        let doubleValue = Double(truncating: value as NSNumber)
        if doubleValue > 20 { return "Very expensive per hour" }
        if doubleValue > 10 { return "Consider if worth it" }
        if doubleValue > 5 { return "Reasonable value" }
        return "Excellent value!"
    }
}
