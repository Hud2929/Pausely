import SwiftUI

/// What opens when you tap a subscription. Calm and minimal: who it is, what it costs, when it renews,
/// then only the tools that apply. Every control on this screen works.
struct SubscriptionManagementView: View {
    let subscription: Subscription

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var pausePlanStore = PausePlanStore.shared
    @ObservedObject private var screenTimeManager = UsageLog.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var route: Route?
    /// The column the row marks sit in. It grows with the text: at the largest sizes a mark was
    /// twice as wide as a fixed column and lay over the words beside it.
    @ScaledMetric(relativeTo: .body) private var markColumn: CGFloat = 24
    @State private var showRemoveConfirm = false
    @State private var isRemoving = false

    private enum Route: String, Identifiable {
        case edit, paywall, cancel, priceHistory, usage, verdict, receipt, pausePlan
        var id: String { rawValue }
    }

    /// Always the freshest copy, so the screen updates the moment an edit is saved.
    private var current: Subscription {
        store.subscriptions.first { $0.id == subscription.id } ?? subscription
    }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // The bar and what it is about are one group, closer than the groups below.
                VStack(alignment: .leading, spacing: 12) {
                    topBar
                    hero
                }
                decisionGroup
                factsCard
                if current.calculatedNextBillingDate != nil, current.renewsAutomatically {
                    CancelTimingCard(subscription: current)
                }
                toolsGroup
                // What it will cost over the years is a question about something still being paid for.
                if current.status != .cancelled { LifetimeCostCard(subscription: current) }
                actions
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .inkScreen()
        .preferredColorScheme(.dark)
        .sheet(item: $route) { route in
            sheetContent(for: route)
        }
    }

    private var topBar: some View {
        HStack {
            LeaveButton("Done") { dismiss() }
            .accessibilityIdentifier("subscriptionDoneButton")
            Spacer()
            Button { route = .edit } label: {
                Text("Edit")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 34)
                    .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
                    .tapArea()
            }
            .accessibilityIdentifier("editSubscriptionButton")
        }
    }

    // MARK: - What it is and what it costs

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ServiceLogoView(name: current.name, category: current.category, size: 48)
                Text(current.name)
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }

            PricePerPeriod(amount: MoneyFormat.string(current.amount, current.currency), frequency: current.billingFrequency,
                           amountFont: .question(.largeTitle, weight: .bold), periodFont: .title3, periodColor: .inkTextMuted)
                .foregroundStyle(Color.inkText)
                .padding(.top, 8)

            if current.currency != currencyManager.selectedCurrency,
               let converted = currencyManager.convertToSelected(current.amount, from: current.currency) {
                Text("About \(MoneyFormat.string(converted, currencyManager.selectedCurrency)) in your currency")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
            }

            LineOrStack(spacing: 8, lineSpacing: 4) { statusChip; renewalText }

            if current.nextBillingDate == nil, current.status == .active || current.status == .trial {
                Button { route = .edit } label: {
                    Text("Add its renewal date").underline()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(minHeight: Layout.tapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var renewalText: some View {
        if let line = renewalLine {
            Facts(line.text)
                .font(.subheadline)
                .foregroundStyle(line.tint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The state in words, with its mark: colour is never the only signal.
    private var statusChip: some View {
        let (text, state): (LocalizedStringKey, MoneyState?) = {
            switch current.status {
            case .active: return ("Active", nil)
            case .trial: return ("Free trial", .decide)
            case .cancelled: return ("Cancelled", .kept)
            }
        }()
        return HStack(spacing: 6) {
            if let state { StateMark(state: state) }
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(state?.color ?? Color.inkText)
        }
        .accessibilityElement(children: .combine)
    }

    /// The day a free trial stops being free: its first charge. A trial doesn't "renew".
    private var trialEnd: Date? {
        guard current.status == .trial, let end = current.trialEndsAt,
              Calendar.billing.startOfDay(for: end) >= Calendar.billing.startOfDay(for: Date()) else { return nil }
        return end
    }

    private var renewalLine: (text: String, tint: Color)? {
        if let end = trialEnd {
            let days = Calendar.billing.calendarDays(from: Date(), to: end)
            let dateText = L10n.day(end)
            if days <= 1 { return (L10n.string("Trial ends \(L10n.relativeDay(days))"), Color.due) }
            return (L10n.breakingAfterDots(L10n.string("Trial ends \(dateText)") + " · " + L10n.whole(L10n.relativeDay(days))), Color.inkTextMuted)
        }
        guard current.status == .active || current.status == .trial,
              let date = current.calculatedNextBillingDate, let days = current.daysUntilRenewal else { return nil }
        let dateText = L10n.day(date)
        if days < 0 { return (L10n.string("Payment was due \(L10n.relativeDay(days))"), Color.due) }
        if days <= 1 { return (L10n.string("Renews \(L10n.relativeDay(days))"), Color.due) }
        return (L10n.breakingAfterDots(L10n.string("Renews \(dateText) · \(L10n.whole(L10n.relativeDay(days)))")), Color.inkTextMuted)
    }

    /// The day it was cancelled, from the history on this device.
    private var cancelledOn: Date? {
        guard current.status == .cancelled else { return nil }
        return eventLog.events.last { $0.kind == .cancelled && $0.subscriptionId == current.id }?.date
    }

    // MARK: - Facts

    private var factsCard: some View {
        VStack(spacing: 0) {
            fact(L10n.string("Billing cycle"), current.billingFrequency.displayName)
            divider
            // One date, named for what happens on it. A cancelled subscription has no next renewal
            // (it showed the last one, in the past) and no yearly cost; it has the day it stopped.
            if current.status == .cancelled {
                if let cancelledOn {
                    fact(L10n.string("Cancelled"), day(cancelledOn))
                    divider
                }
            } else if let trialEnd {
                fact(L10n.string("Trial ends"), day(trialEnd))
                divider
            } else {
                fact(L10n.string("Next renewal"), current.calculatedNextBillingDate.map(day) ?? L10n.string("Not set"))
                divider
            }
            fact(L10n.string("Category"), SubscriptionCategory.localizedLabel(for: current.category))
            divider
            if current.status != .cancelled {
                fact(L10n.string("Per year"), MoneyFormat.string(current.amount * ProvenSubscription.periodsPerYear(current.billingFrequency), current.currency))
                divider
            }
            fact(L10n.string("Tracking since"), current.createdAt.formatted(.dateTime.month(.abbreviated).year().locale(L10n.locale)))
        }
        .accessibilityElement(children: .contain)
    }

    private func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year().locale(L10n.locale))
    }

    private func fact(_ title: String, _ value: String) -> some View {
        AdaptiveRow {
            Text(title)
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
        } value: {
            Text(value)
                .font(.body)
                .foregroundStyle(Color.inkText)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View { Hairline() }


    @ViewBuilder
    private var decisionGroup: some View {
        if let pending = RenewalDecisions.pending(for: current, kept: RenewalDecisions.keptKeys(in: eventLog.events), now: Date()) {
            let days = Calendar.billing.calendarDays(from: Date(), to: pending.date)
            let when = L10n.relativeDay(days)
            VStack(spacing: 0) {
                toolRow(icon: "questionmark.circle", state: .decide,
                        title: L10n.string("Keep it or cancel it?"),
                        subtitle: pending.isTrialEnd ? L10n.string("Free trial ends \(when)") : L10n.string("Renews \(when)")) {
                    route = .verdict
                }
            }

        } else if current.status == .cancelled,
                  let line = SavingsSummary.current().lines.last(where: { $0.subscriptionId == current.id }) {
            VStack(spacing: 0) {
                toolRow(icon: "doc.text", state: .kept,
                        title: L10n.string("On your Savings Receipt"),
                        subtitle: L10n.string("\(MoneyFormat.string(line.onTrack, line.currency)) on track over 12 months")) {
                    route = .receipt
                }
            }
        }
    }

    // MARK: - Tools

    @ViewBuilder
    private var toolsGroup: some View {
        VStack(spacing: 0) {
            toolRow(icon: "chart.line.uptrend.xyaxis", title: L10n.string("Price history"), subtitle: nil) { route = .priceHistory }


            if PausePlanSchedule.isEligible(current) {
                divider
                if pausePlanStore.contains(current.id) {
                    toolRow(icon: "arrow.triangle.2.circlepath", title: L10n.string("In your Pause Plan"), subtitle: nil) { route = .pausePlan }
                } else {
                    // The feature's name is the row; what it does is under it (they were the other way round).
                    toolRow(icon: "arrow.triangle.2.circlepath", title: L10n.string("Pause Plan"),
                            subtitle: L10n.string("Rotate with your other streaming"), isPro: !paymentManager.isUnlocked(.pausePlan)) { route = .pausePlan }
                        .accessibilityIdentifier("pausePlanRow")
                }
            }

            // How much it is used matters while it is being paid for.
            if current.status != .cancelled {
                divider
                toolRow(icon: "gauge.with.dots.needle.33percent", title: L10n.string("Usage and value"), subtitle: nil) { route = .usage }
                    .accessibilityIdentifier("usageRow")
            }
        }
    }

    /// Whether "Pro" sits under a row's words instead of at the end of the row.
    nonisolated static func proSitsUnderTheWords(largeText: Bool) -> Bool { largeText }

    private func toolRow(icon: String, state: MoneyState? = nil, title: String, subtitle: String?, isPro: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button {
            Feel.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                // The mark is above its words at the accessibility text sizes, like every other
                // mark: beside them it left "Usage and value" a word to a line.
                let markWidth: CGFloat? = MarkPlacement.sitsAbove(largeText: typeSize.isAccessibilitySize) ? nil : markColumn
                MarkedWords(alignment: .center, spacing: 14) {
                    if let state {
                        StateMark(state: state).frame(width: markWidth)
                    } else {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(Color.inkTextMuted)
                            .frame(width: markWidth)
                            .accessibilityHidden(true)
                    }
                } words: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.body)
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(state?.color ?? Color.inkTextMuted)
                                .multilineTextAlignment(.leading)
                        }
                        // Under the words at the accessibility text sizes. Beside them it left the
                        // words a fifth of the row: "Paus", "e", "Plan", and "strea" above "ming".
                        if isPro, Self.proSitsUnderTheWords(largeText: typeSize.isAccessibilitySize) {
                            ProPill().padding(.top, 4)
                        }
                    }
                }
                Spacer(minLength: 8)
                if isPro, !Self.proSitsUnderTheWords(largeText: typeSize.isAccessibilitySize) { ProPill() }
                RowChevron()
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }


    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if current.status != .cancelled {
                Button { route = .cancel } label: { Text("Cancel subscription") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("cancelSubscriptionButton")
            } else {
                // Signed up again, or cancelled here by mistake: it charges from today, on this day of
                // the month. On the free plan it needs a place; without one, the upgrade page says so.
                Button {
                    Task {
                        if await store.startAgain(id: current.id) { Feel.selection() } else { route = .paywall }
                    }
                } label: { Text("I'm paying for this again") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("startAgainButton")
            }

            Button { showRemoveConfirm = true } label: {
                Text(isRemoving ? "Removing…" : "Remove from Pausely")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(maxWidth: .infinity, minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRemoving)
            .accessibilityIdentifier("removeSubscriptionButton")
            .asksFirst(Text("Remove \"\(current.name)\"?"), isPresented: $showRemoveConfirm,
                       message: Text("This only removes it from Pausely. It won't cancel the subscription itself.")) {
                Button("Remove", role: .destructive) { Task { await remove() } }
                Button("Keep", role: .cancel) {}
            }
        }
    }

    private func remove() async {
        isRemoving = true
        defer { isRemoving = false }
        await store.deleteSubscription(id: current.id)
        dismiss()
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(for route: Route) -> some View {
        switch route {
        case .edit:
            SubscriptionEditView(subscription: current)
        case .paywall:
            StoreKitUpgradeView()
        case .cancel:
            CancelSubscriptionFlow(subscription: current)
        case .priceHistory:
            PriceHistoryView(subscription: current)
        case .usage:
            UsageSheet(subscription: current)
        case .verdict:
            RenewalVerdictView(subscriptionId: current.id)
        case .receipt:
            SavingsReceiptView()
        case .pausePlan:
            PausePlanView()
        }
    }
}

// MARK: - Usage

private struct UsageSheet: View {
    let subscription: Subscription

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var screenTimeManager = UsageLog.shared
    @State private var showInput = false

    private var minutes: Int { screenTimeManager.getCurrentMonthUsage(for: subscription) }
    private var costPerHour: Decimal? {
        screenTimeManager.calculateCostPerHour(for: subscription)
    }

    /// What the person says they used it, and what that makes an hour cost. No score, no verdict:
    /// the figure is theirs, and so is the judgment.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton("Done") { dismiss() }
                    Spacer()
                }

                Text(L10n.string("How much do you use \(subscription.name)?"))
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)

                Text("You enter this yourself. Pausely doesn't read your Screen Time.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                PaperSlip(tornTop: true, tornBottom: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        ProofLine(label: L10n.string("This month"),
                                  value: minutes > 0
                                    ? Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(L10n.locale))
                                    : L10n.string("Not entered"),
                                  emphasised: true)
                        ProofLine(label: L10n.string("It costs"), value: subscription.billingFrequency.pricedShort(subscription.chargeText))
                        if let costPerHour {
                            Perforation()
                            ProofLine(label: L10n.string("Each hour of use"),
                                      value: MoneyFormat.string(costPerHour, subscription.currency, locale: L10n.locale), emphasised: true)
                        }
                    }
                }
                .padding(.top, 24)

                Button { showInput = true } label: {
                    Text(minutes > 0 ? L10n.string("Change this month's hours") : L10n.string("Enter this month's hours"))
                }
                .buttonStyle(.ink)
                .padding(.top, 20)
                .accessibilityIdentifier("enterUsageButton")

            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .inkScreen()
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showInput) {
            UsageInputSheet(subscriptionName: subscription.name, currentMinutes: minutes) { newMinutes in
                screenTimeManager.setMonthlyUsage(minutes: newMinutes, for: subscription)
            }
        }
    }
}
