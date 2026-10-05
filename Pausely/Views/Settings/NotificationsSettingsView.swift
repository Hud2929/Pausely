import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("renewalAlerts") private var renewalAlerts = true
    @AppStorage("priceChangeAlerts") private var priceChangeAlerts = true
    @AppStorage("usageReminders") private var usageReminders = false
    @AppStorage("weeklyReports") private var weeklyReports = true
    @AppStorage("trialEndingAlerts") private var trialEndingAlerts = true
    @AppStorage("savingsOpportunities") private var savingsOpportunities = true

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(Color.obsidianTextSecondary)
                        }
                        .accessibilityLabel("Back")

                        Spacer()

                        Text("Notifications")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)

                        Spacer()

                        Color.clear.frame(width: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.accentMint.opacity(0.12))
                            .frame(width: 80, height: 80)

                        Image(systemName: "bell.badge.fill")
                            .font(.title)
                            .foregroundColor(Color.accentMint)
                    }

                    // Alerts Section
                    notificationSection(
                        title: "ALERTS",
                        rows: [
                            NotifRow(icon: "calendar.badge.exclamationmark",
                                     title: "Renewal Alerts",
                                     subtitle: "Get notified before subscriptions renew",
                                     binding: $renewalAlerts),
                            NotifRow(icon: "tag.fill",
                                     title: "Price Change Alerts",
                                     subtitle: "Notify when subscription prices change",
                                     binding: $priceChangeAlerts),
                            NotifRow(icon: "clock.fill",
                                     title: "Trial Ending Alerts",
                                     subtitle: "Remind before free trials expire",
                                     binding: $trialEndingAlerts),
                        ]
                    )
                    .padding(.horizontal, 20)

                    // Insights Section
                    notificationSection(
                        title: "INSIGHTS",
                        rows: [
                            NotifRow(icon: "chart.pie.fill",
                                     title: "Weekly Reports",
                                     subtitle: "Summary of your spending each week",
                                     binding: $weeklyReports),
                            NotifRow(icon: "dollarsign.circle.fill",
                                     title: "Savings Opportunities",
                                     subtitle: "Alert when we find ways to save",
                                     binding: $savingsOpportunities),
                            NotifRow(icon: "eye.fill",
                                     title: "Usage Reminders",
                                     subtitle: "Track subscriptions you don't use",
                                     binding: $usageReminders),
                        ]
                    )
                    .padding(.horizontal, 20)

                    Spacer(minLength: 60)
                }
            }
        }
    }

    private struct NotifRow {
        let icon: String
        let title: String
        let subtitle: String
        let binding: Binding<Bool>
    }

    @ViewBuilder
    private func notificationSection(title: String, rows: [NotifRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(Color.obsidianTextTertiary)
                .tracking(1.5)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentMint.opacity(0.12))
                                .frame(width: 38, height: 38)

                            Image(systemName: row.icon)
                                .font(.callout)
                                .foregroundColor(Color.accentMint)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.white)

                            Text(row.subtitle)
                                .font(.footnote)
                                .foregroundColor(Color.obsidianTextSecondary)
                        }

                        Spacer()

                        Toggle("", isOn: row.binding)
                            .tint(Color.accentMint)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < rows.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 68)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    NotificationsSettingsView()
}
