import SwiftUI
import UserNotifications

/// Reminder settings. Every switch here changes which reminders are scheduled; nothing is decorative.
struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(ReminderScheduler.renewalRemindersKey) private var renewalAlerts = true
    @AppStorage(ReminderScheduler.trialRemindersKey) private var trialEndingAlerts = true

    private var notifications = NotificationManager.shared
    @State private var isAsking = false

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

                    permissionCard
                        .padding(.horizontal, 20)

                    notificationSection(
                        title: "REMINDERS",
                        rows: [
                            NotifRow(icon: "calendar.badge.exclamationmark",
                                     title: "Renewal reminders",
                                     subtitle: "Before each renewal, so you can keep it or cancel it",
                                     binding: $renewalAlerts),
                            NotifRow(icon: "clock.fill",
                                     title: "Free trial reminders",
                                     subtitle: "The day before a free trial starts charging",
                                     binding: $trialEndingAlerts),
                        ]
                    )
                    .padding(.horizontal, 20)
                    .disabled(!notifications.isAuthorized)
                    .opacity(notifications.isAuthorized ? 1 : 0.5)

                    Text("Renewal reminders come at 9am the number of days you choose for each subscription (\"Remind me\" when you edit it), again the day before, and the morning of. \"Keep it\" on a reminder stops the rest for that charge.")
                        .font(.footnote)
                        .foregroundColor(Color.obsidianTextTertiary)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 60)
                }
            }
        }
        .task { await notifications.refreshStatus() }
        .onChange(of: renewalAlerts) { _, _ in reschedule() }
        .onChange(of: trialEndingAlerts) { _, _ in reschedule() }
    }

    private func reschedule() {
        Task { await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions) }
    }

    // MARK: - Permission

    @ViewBuilder
    private var permissionCard: some View {
        let status = notifications.status
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((notifications.isAuthorized ? Color.accentMint : Color.orange).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: notifications.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                    .font(.title3)
                    .foregroundColor(notifications.isAuthorized ? Color.accentMint : Color.orange)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(notifications.isAuthorized ? "Reminders are on" : "Reminders are off")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                Text(notifications.isAuthorized
                     ? "Pausely can warn you before you're charged."
                     : status == .denied
                        ? "Notifications for Pausely are off in iOS Settings."
                        : "Turn them on so renewals never surprise you.")
                    .font(.footnote)
                    .foregroundColor(Color.obsidianTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if !notifications.isAuthorized {
                Button {
                    if status == .denied {
                        notifications.openSystemSettings()
                    } else {
                        isAsking = true
                        Task {
                            await notifications.requestPermission()
                            isAsking = false
                        }
                    }
                } label: {
                    Text(status == .denied ? "Settings" : "Turn on")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule().fill(status == .denied ? Color.orange : Color.accentMint))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isAsking)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.obsidianSurface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    // MARK: - Rows

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
