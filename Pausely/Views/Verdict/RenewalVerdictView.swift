import SwiftUI

/// Keep it or cancel it. One renewal, only the facts that help decide, three answers.
/// Opened from a reminder, the dashboard's "Decide" card or the subscription screen.
struct RenewalVerdictView: View {
    let subscriptionId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var screenTime = ScreenTimeManager.shared

    @State private var showCancelFlow = false
    @State private var showPaywall = false
    @State private var showReceipt = false
    @State private var isKeeping = false
    @State private var outcome: Outcome?

    private enum Outcome: Equatable {
        case kept(askAgain: Date?)
        case cancelled
    }

    private var subscription: Subscription? { store.subscriptions.first { $0.id == subscriptionId } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidianBlack.ignoresSafeArea()
                if let sub = subscription {
                    if let outcome {
                        outcomeView(outcome, sub)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else {
                        verdict(sub)
                    }
                } else {
                    ContentUnavailableView("This subscription is gone", systemImage: "questionmark.circle",
                                           description: Text("It may have been removed from Pausely."))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .accessibilityIdentifier("verdictCloseButton")
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCancelFlow) {
            if let sub = subscription { CancelSubscriptionFlow(subscription: sub) }
        }
        .sheet(isPresented: $showPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
        .sheet(isPresented: $showReceipt) {
            SavingsReceiptView()
        }
        .onChange(of: subscription?.status) { _, status in
            if status == .cancelled, outcome == nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { outcome = .cancelled }
            }
        }
    }

    // MARK: - Verdict

    private func verdict(_ sub: Subscription) -> some View {
        let charge = RenewalDecisions.upcomingCharge(for: sub, now: Date())
        return ScrollView {
            VStack(spacing: 24) {
                header(sub, charge: charge)
                if sub.isPausely { PauselyPromiseCard() }
                factsCard(sub, charge: charge)
                decisionButtons(sub, hasCharge: charge != nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func header(_ sub: Subscription, charge: (date: Date, isTrialEnd: Bool)?) -> some View {
        VStack(spacing: 10) {
            ServiceLogoView(name: sub.name, category: sub.category, size: 64)
                .accessibilityHidden(true)
            Text("Keep \(sub.name)?")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let charge {
                Text(whenText(charge))
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(daysUntil(charge.date) <= 1 ? Color.orange : Color.obsidianTextSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(MoneyFormat.string(sub.amount, sub.currency))
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Color.accentMint)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(sub.billingFrequency.shortDisplay)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func whenText(_ charge: (date: Date, isTrialEnd: Bool)) -> String {
        let day = charge.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let days = daysUntil(charge.date)
        let relative = days == 0 ? String(localized: "today") : days == 1 ? String(localized: "tomorrow") : String(localized: "in \(days) days")
        return charge.isTrialEnd
            ? String(localized: "Free trial ends \(day) · \(relative)")
            : String(localized: "Renews \(day) · \(relative)")
    }

    private func daysUntil(_ date: Date) -> Int {
        Calendar.current.calendarDays(from: Date(), to: date)
    }

    // MARK: - Facts

    private func factsCard(_ sub: Subscription, charge: (date: Date, isTrialEnd: Bool)?) -> some View {
        VStack(spacing: 0) {
            factRow("calendar", yearlyText(sub))

            if let change = VerdictFacts.priceChange(for: sub.id, currentAmount: sub.amount, events: eventLog.events) {
                let up = sub.amount > change.from
                divider
                factRow(up ? "arrow.up.right" : "arrow.down.right",
                        up ? String(localized: "Up from \(MoneyFormat.string(change.from, sub.currency)) since \(change.since.formatted(.dateTime.month(.abbreviated).day()))")
                           : String(localized: "Down from \(MoneyFormat.string(change.from, sub.currency)) since \(change.since.formatted(.dateTime.month(.abbreviated).day()))"),
                        tint: up ? .orange : Color.accentMint)
            }

            if let usage = usageText(sub) {
                divider
                factRow("hourglass", usage)
            }

            if let charge {
                divider
                factRow("clock",
                        charge.isTrialEnd
                            ? String(localized: "Cancel before \(charge.date.formatted(.dateTime.month(.abbreviated).day())) and you won't be charged.")
                            : String(localized: "Cancel now and you usually keep it until \(charge.date.formatted(.dateTime.month(.abbreviated).day()))."))
            }

            if let kept = VerdictFacts.lastKept(for: sub.id, events: eventLog.events) {
                divider
                factRow("checkmark.circle", String(localized: "You kept it on \(kept.formatted(.dateTime.month(.abbreviated).day()))."))
            }

            if !sub.isPausely, let cheaper = cheaperOption(sub) {
                divider
                if paymentManager.isUnlocked(.cheaperAlternatives) {
                    factRow("arrow.left.arrow.right",
                            cheaper.monthly == 0
                                ? String(localized: "Free alternative: \(cheaper.name)")
                                : String(localized: "Cheaper: \(cheaper.name) at \(currencyManager.format(cheaper.monthly)) a month"),
                            tint: Color.accentMint)
                } else {
                    Button {
                        HapticStyle.light.trigger()
                        showPaywall = true
                    } label: {
                        factRow("lock.fill", String(localized: "Pro shows a cheaper option for this"), tint: Color.obsidianTextSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
    }

    private func yearlyText(_ sub: Subscription) -> String {
        let yearly = MoneyFormat.string(sub.annualCost, sub.currency)
        guard sub.currency != currencyManager.selectedCurrency else {
            return String(localized: "That's \(yearly) a year")
        }
        let converted = currencyManager.format(currencyManager.convertToSelected(sub.annualCost, from: sub.currency))
        return String(localized: "That's \(yearly) a year (about \(converted))")
    }

    private func usageText(_ sub: Subscription) -> String? {
        let minutes = screenTime.getCurrentMonthUsage(for: sub.name)
        guard minutes > 0 else { return nil }
        let duration = Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        if let perHour = screenTime.calculateCostPerHour(monthlyCost: sub.monthlyCost, subscriptionName: sub.name) {
            return String(localized: "Used \(duration) this month · \(MoneyFormat.string(perHour, sub.currency)) an hour")
        }
        return String(localized: "Used \(duration) this month")
    }

    private func cheaperOption(_ sub: Subscription) -> (name: String, monthly: Decimal)? {
        let current = currencyManager.convertToSelected(sub.monthlyCost, from: sub.currency)
        return SubscriptionActionManager.shared.findAlternatives(for: sub)
            .map { (name: $0.name, monthly: currencyManager.convertToSelected(Decimal($0.monthlyPrice), from: "USD")) }
            .filter { $0.monthly < current && $0.name.caseInsensitiveCompare(sub.name) != .orderedSame }
            .min { $0.monthly < $1.monthly }
    }

    private func factRow(_ icon: String, _ text: String, tint: Color = Color.accentMint) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 50)
    }

    // MARK: - Decision

    private func decisionButtons(_ sub: Subscription, hasCharge: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    Task { await keep(sub) }
                } label: {
                    Label(isKeeping ? String(localized: "Keeping…") : String(localized: "Keep it"), systemImage: "checkmark")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.accentMint))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isKeeping || !hasCharge)
                .accessibilityIdentifier("verdictKeepButton")

                Button {
                    HapticStyle.medium.trigger()
                    if sub.isPausely, let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    } else {
                        showCancelFlow = true
                    }
                } label: {
                    Label("Cancel it", systemImage: "xmark")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.red.opacity(0.12)))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("verdictCancelButton")
            }

            Button {
                dismiss()
            } label: {
                Text("Decide later")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func keep(_ sub: Subscription) async {
        isKeeping = true
        defer { isKeeping = false }
        let charge = RenewalDecisions.upcomingCharge(for: sub, now: Date())
        await VerdictCenter.shared.keep(subscriptionId: sub.id)
        HapticStyle.success.trigger()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            outcome = .kept(askAgain: charge.flatMap { VerdictFacts.renewal(after: $0.date, for: sub) })
        }
    }

    // MARK: - Outcome

    private func outcomeView(_ outcome: Outcome, _ sub: Subscription) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: outcome == .cancelled ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.accentMint)
                .accessibilityHidden(true)

            switch outcome {
            case .kept(let askAgain):
                Text("Kept")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(askAgain.map { String(localized: "No more reminders about this charge. We'll ask again before \($0.formatted(.dateTime.month(.abbreviated).day())).") }
                     ?? String(localized: "No more reminders about this charge."))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
            case .cancelled:
                let line = SavingsSummary.current().lines.last { $0.subscriptionId == sub.id }
                Text("\(sub.name) cancelled")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(line.map { String(localized: "That's \(MoneyFormat.string($0.onTrack, $0.currency)) you won't pay over the next 12 months. It's on your Savings Receipt.") }
                     ?? String(localized: "It's on your Savings Receipt."))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
                Button("See your Savings Receipt") { showReceipt = true }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.accentMint)
                    .padding(.top, 4)
            }

            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.accentMint))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - The Pausely Promise

/// Shown when the renewal is Pausely's own: what Pausely saved, compared with what it costs,
/// and an honest recommendation either way.
struct PauselyPromiseCard: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared

    var body: some View {
        let summary = SavingsSummary.current()
        VStack(alignment: .leading, spacing: 10) {
            Label("The Pausely Promise", systemImage: "seal")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Color.accentMint)
            Text(message(summary))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.accentMint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.accentMint.opacity(0.25), lineWidth: 1))
    }

    private func message(_ summary: SavingsSummary) -> String {
        guard let cost = summary.pauselyYearlyCost.map(summary.formatted) else {
            // Free customers: nothing to weigh yet, but the promise holds if they ever pay.
            return summary.isEmpty
                ? String(localized: "If you ever pay for Pausely and it doesn't save you more than it costs, it will tell you to cancel it.")
                : String(localized: "Pausely is free for you and on track to save you \(summary.formatted(summary.onTrack)) this year. If you ever pay for it, it has to save you more than it costs.")
        }
        if summary.isEmpty {
            return String(localized: "Pausely hasn't saved you anything yet. If it doesn't save you more than its \(cost), we'd rather you cancel it.")
        }
        if summary.paysForItself, let multiple = summary.returnMultiple {
            let times = multiple.formatted(.number.precision(.fractionLength(1)))
            return String(localized: "Pausely is on track to save you \(summary.formatted(summary.onTrack)) this year, \(times)× what it costs. Keeping it pays.")
        }
        return String(localized: "So far Pausely is on track to save you \(summary.formatted(summary.onTrack)), less than its \(cost). We'd rather you cancel than pay for nothing.")
    }
}
