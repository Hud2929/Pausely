import SwiftUI
import UserNotifications

// MARK: - Turn on reminders

/// Reminders are Pausely's main promise, so the dashboard asks for permission in context: after the
/// first subscription exists, naming the next charge. When reminders were turned off, it explains
/// where to turn them back on.
struct RemindersPermissionCard: View {
    let nextCharge: Subscription?
    private var notifications = NotificationManager.shared
    @State private var isAsking = false

    init(nextCharge: Subscription?) {
        self.nextCharge = nextCharge
    }

    var body: some View {
        if !notifications.isAuthorized {
            let denied = notifications.status == .denied
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: denied ? "bell.slash.fill" : "bell.badge.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(denied ? Color.orange : Color.accentMint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill((denied ? Color.orange : Color.accentMint).opacity(0.15)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(denied ? String(localized: "Reminders are off") : String(localized: "Get a heads-up before you're charged"))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(detail(denied: denied))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    HapticStyle.light.trigger()
                    if denied {
                        notifications.openSystemSettings()
                    } else {
                        isAsking = true
                        Task {
                            await notifications.requestPermission()
                            isAsking = false
                        }
                    }
                } label: {
                    Text(denied ? String(localized: "Settings") : String(localized: "Turn on"))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Capsule().fill(denied ? Color.orange : Color.accentMint))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isAsking)
                .accessibilityIdentifier("turnOnRemindersButton")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.obsidianSurface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke((denied ? Color.orange : Color.accentMint).opacity(0.3), lineWidth: 1))
        }
    }

    private func detail(denied: Bool) -> String {
        if denied { return String(localized: "Turn on notifications for Pausely in Settings so renewals don't surprise you.") }
        if let sub = nextCharge, let date = sub.calculatedNextBillingDate {
            return String(localized: "Pausely will remind you before \(sub.name) charges you on \(date.formatted(.dateTime.month(.abbreviated).day())).")
        }
        return String(localized: "Pausely reminds you before each renewal so you can keep it or cancel it.")
    }
}

// MARK: - Decisions waiting

/// Renewals inside their reminder window that haven't been decided yet.
struct PendingDecisionsCard: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        let pending = Array(VerdictCenter.shared.pendingDecisions().prefix(3))
        if !pending.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Decide before you're charged")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(pending.count)")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange))
                        .accessibilityLabel("\(pending.count) waiting")
                }
                VStack(spacing: 0) {
                    ForEach(Array(pending.enumerated()), id: \.element.id) { index, item in
                        if let sub = store.subscriptions.first(where: { $0.id == item.subscriptionId }) {
                            if index > 0 { Divider().overlay(Color.white.opacity(0.06)) }
                            row(sub, item)
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.obsidianSurface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.orange.opacity(0.25), lineWidth: 1))
        }
    }

    private func row(_ sub: Subscription, _ item: RenewalDecisions.Pending) -> some View {
        Button {
            HapticStyle.light.trigger()
            VerdictCenter.shared.open(subscriptionId: sub.id)
        } label: {
            HStack(spacing: 12) {
                ServiceLogoView(name: sub.name, category: sub.category, size: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(whenText(item))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
                Spacer(minLength: 8)
                // The customer's currency, like every other card on the dashboard.
                Text(currencyManager.format(currencyManager.convertToSelected(sub.amount, from: sub.currency)))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text("Decide")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Capsule().fill(Color.accentMint))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("decideRow")
    }

    private func whenText(_ item: RenewalDecisions.Pending) -> String {
        let days = Calendar.current.calendarDays(from: Date(), to: item.date)
        let relative = days == 0 ? String(localized: "today") : days == 1 ? String(localized: "tomorrow") : String(localized: "in \(days) days")
        return item.isTrialEnd ? String(localized: "Trial ends \(relative)") : String(localized: "Renews \(relative)")
    }
}

// MARK: - Saved with Pausely

/// The Savings Receipt at a glance, with the Pausely Promise when Pausely is a paid subscription.
struct SavingsReceiptCard: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showReceipt = false

    var body: some View {
        let summary = SavingsSummary.current()
        Button {
            HapticStyle.light.trigger()
            showReceipt = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentMint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.accentMint.opacity(0.15)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved with Pausely")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.obsidianTextSecondary)
                    if summary.isEmpty {
                        Text("Your Savings Receipt starts with your first cancel")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text(summary.formatted(summary.savedSoFar))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.accentMint)
                        Text(subtitle(summary))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color.obsidianTextSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.obsidianSurface))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("savingsReceiptCard")
        .sheet(isPresented: $showReceipt) { SavingsReceiptView() }
    }

    private func subtitle(_ summary: SavingsSummary) -> String {
        if let multiple = summary.returnMultiple, summary.paysForItself {
            return String(localized: "\(summary.formatted(summary.onTrack)) on track this year · pays for Pausely \(multiple.formatted(.number.precision(.fractionLength(1))))×")
        }
        return String(localized: "\(summary.formatted(summary.onTrack)) on track over 12 months")
    }
}
