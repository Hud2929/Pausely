import SwiftUI

/// Which reminders Pausely sends. The switches only matter once iOS allows notifications, so the page
/// says first whether it does, and offers the one step that turns them on.
struct NotificationsSettingsView: View {
    @AppStorage(ReminderScheduler.renewalRemindersKey) private var renewalAlerts = true
    @AppStorage(ReminderScheduler.trialRemindersKey) private var trialEndingAlerts = true

    private var notifications = NotificationManager.shared
    @State private var isAsking = false

    var body: some View {
        SettingsPage(title: "Notifications") {
            permission

            SettingsSection(footer: "Renewal reminders come at 9am the number of days you choose for each subscription (\"Remind me\" when you edit it), again the day before, and the morning of. \"Keep it\" on a reminder stops the rest for that charge.") {
                SettingsRow(title: L10n.string("Renewal reminders"),
                            detail: L10n.string("Before each renewal, so you can keep it or cancel it")) {
                    Toggle("", isOn: $renewalAlerts).labelsHidden().tint(Color.inkTextMuted)
                        .accessibilityLabel(Text("Renewal reminders"))
                        .accessibilityIdentifier("renewalRemindersToggle")
                }
                SettingsRow(title: L10n.string("Free trial reminders"),
                            detail: L10n.string("The day before a free trial starts charging")) {
                    Toggle("", isOn: $trialEndingAlerts).labelsHidden().tint(Color.inkTextMuted)
                        .accessibilityLabel(Text("Free trial reminders"))
                        .accessibilityIdentifier("trialRemindersToggle")
                }
            }
            .disabled(!notifications.isAuthorized)
            .opacity(notifications.isAuthorized ? 1 : 0.5)
        }
        .task { await notifications.refreshStatus() }
        .onChange(of: renewalAlerts) { _, _ in reschedule() }
        .onChange(of: trialEndingAlerts) { _, _ in reschedule() }
    }

    private func reschedule() {
        Task { await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions) }
    }

    /// Whether iOS lets Pausely notify, and the way to change it.
    @ViewBuilder
    private var permission: some View {
        let status = notifications.status
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if !notifications.isAuthorized { StateMark(state: .decide).accessibilityHidden(true) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(notifications.isAuthorized ? "Reminders are on" : "Reminders are off")
                        .font(.headline)
                        .foregroundStyle(Color.inkText)
                    Text(notifications.isAuthorized
                         ? "Pausely can warn you before you're charged."
                         : status == .denied
                            ? "Notifications for Pausely are off in iOS Settings."
                            : "Turn them on so renewals never surprise you.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

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
                    status == .denied ? Text("Settings") : Text("Turn on")
                }
                .buttonStyle(.ink)
                .disabled(isAsking)
                .accessibilityIdentifier("turnOnNotificationsButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
