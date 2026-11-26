import SwiftUI
import UserNotifications

/// Which reminders Pausely sends, plus editable default reminder timing and Home/Insights focus.
/// The notification switches only matter once iOS allows notifications, so the page says first
/// whether it does, and offers the one step that turns them on.
struct NotificationsSettingsView: View {
    @AppStorage(ReminderScheduler.renewalRemindersKey) private var renewalAlerts = true
    @AppStorage(ReminderScheduler.trialRemindersKey) private var trialEndingAlerts = true
    @AppStorage(ReminderScheduler.savingsMilestonesKey) private var savingsMilestoneAlerts = true

    private var notifications = NotificationManager.shared
    @State private var isAsking = false
    @State private var profile = OnboardingProfile.load()

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
                            detail: L10n.string("2 days before and the day before a free trial starts charging")) {
                    Toggle("", isOn: $trialEndingAlerts).labelsHidden().tint(Color.inkTextMuted)
                        .accessibilityLabel(Text("Free trial reminders"))
                        .accessibilityIdentifier("trialRemindersToggle")
                }
                SettingsRow(title: L10n.string("Savings milestones"),
                            detail: L10n.string("When a cancelled subscription's charge day passes without billing you")) {
                    Toggle("", isOn: $savingsMilestoneAlerts).labelsHidden().tint(Color.inkTextMuted)
                        .accessibilityLabel(Text("Savings milestones"))
                        .accessibilityIdentifier("savingsMilestonesToggle")
                }
            }
            .disabled(!notifications.isAuthorized)

            SettingsSection(title: "Default reminder",
                            footer: "Used for new subscriptions and updates existing ones still on your previous default.") {
                ForEach([7, 3, 1], id: \.self) { days in
                    ChoiceRow(title: SubscriptionEditDraft.reminderLabel(days),
                              isChosen: profile.validReminderDays == days) {
                        let previous = profile.validReminderDays
                        guard previous != days else { return }
                        profile.reminderDays = days
                        profile.save()
                        let updated = profile
                        Task { await updated.applyReminderDays(to: SubscriptionStore.shared, from: previous) }
                    }
                    .accessibilityIdentifier("defaultReminder_\(days)")
                }
            }

            SettingsSection(title: "Your focus",
                            footer: "Orders Home and Insights around what you want Pausely to catch first.") {
                ForEach(OnboardingProfile.Goal.allCases) { option in
                    ChoiceRow(title: option.shortLabel,
                              detail: option.detail,
                              isChosen: profile.goal == option) {
                        profile.goal = option
                        profile.save()
                    }
                    .accessibilityIdentifier("focusGoal_\(option.rawValue)")
                }
            }
        }
        .task {
            profile = OnboardingProfile.load()
            await notifications.refreshStatus()
        }
        .onChange(of: renewalAlerts) { _, _ in reschedule() }
        .onChange(of: trialEndingAlerts) { _, _ in reschedule() }
        .onChange(of: savingsMilestoneAlerts) { _, _ in reschedule() }
    }

    private func reschedule() {
        Task { await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions) }
    }

    /// Allowed, shown somewhere, and not held for a summary: a reminder arrives and is seen.
    private var reachesThePerson: Bool {
        notifications.isAuthorized && notifications.delivery == .shown
    }

    private var headline: String {
        guard notifications.isAuthorized else { return L10n.string("Reminders are off") }
        switch notifications.delivery {
        case .shown: return L10n.string("Reminders are on")
        case .hidden: return L10n.string("Reminders are allowed but hidden")
        case .late: return L10n.string("Reminders can arrive late")
        }
    }

    private func explanation(_ status: UNAuthorizationStatus) -> String {
        guard notifications.isAuthorized else {
            return status == .denied
                ? L10n.string("Notifications for Pausely are off in iOS Settings.")
                : L10n.string("Turn them on so renewals never surprise you.")
        }
        switch notifications.delivery {
        case .shown:
            return L10n.string("Pausely can warn you before you're charged.")
        case .hidden:
            return L10n.string("Banners, the Lock Screen and Notification Center are all off for Pausely in iOS Settings, so a reminder has nowhere to appear.")
        case .late:
            return L10n.string("Pausely is in your Scheduled Summary, so a reminder about tomorrow's charge can come after it. In iOS Settings, choose Immediate Delivery for Pausely.")
        }
    }

    /// Whether iOS lets Pausely notify, and the way to change it.
    @ViewBuilder
    private var permission: some View {
        let status = notifications.status
        VStack(alignment: .leading, spacing: 12) {
            MarkedWords {
                if !reachesThePerson { StateMark(state: .decide).accessibilityHidden(true) }
            } words: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: headline)
                        .font(.headline)
                        .foregroundStyle(Color.inkText)
                    Text(verbatim: explanation(status))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            if !reachesThePerson {
                Button {
                    if status == .denied || notifications.isAuthorized {
                        notifications.openSystemSettings()
                    } else {
                        isAsking = true
                        Task {
                            await notifications.requestPermission()
                            isAsking = false
                        }
                    }
                } label: {
                    status == .denied || notifications.isAuthorized ? Text("Open Settings") : Text("Turn on")
                }
                .buttonStyle(.ink)
                .disabled(isAsking)
                .accessibilityIdentifier("turnOnNotificationsButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
