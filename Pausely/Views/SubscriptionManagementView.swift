import SwiftUI

/// What opens when you tap a subscription. Calm and minimal: who it is, what it costs, when it renews,
/// then only the tools that apply. Every control on this screen works.
struct SubscriptionManagementView: View {
    let subscription: Subscription

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var actionManager = SubscriptionActionManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var route: Route?
    @State private var showRemoveConfirm = false
    @State private var isRemoving = false
    @State private var errorMessage: String?

    private enum Route: String, Identifiable {
        case edit, paywall, cancel, priceHistory, alternatives, usage, verdict, receipt, pausePlan
        var id: String { rawValue }
    }

    /// Always the freshest copy, so the screen updates the moment an edit is saved.
    private var current: Subscription {
        store.subscriptions.first { $0.id == subscription.id } ?? subscription
    }

    private var alternatives: [AlternativeService] { actionManager.findAlternatives(for: current) }
    private var contacts: [SupportContact] { actionManager.getSupportContacts(for: current) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                topBar
                hero
                decisionGroup
                factsCard
                if current.calculatedNextBillingDate != nil, current.renewsAutomatically {
                    CancelTimingCard(subscription: current)
                }
                toolsGroup
                LifetimeCostCard(subscription: current)
                supportGroup
                actions
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $route) { route in
            sheetContent(for: route)
        }
        .confirmationDialog("Remove \"\(current.name)\"?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { Task { await remove() } }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This only removes it from Pausely. It won't cancel the subscription itself.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("subscriptionDoneButton")
            Spacer()
            Button { route = .edit } label: {
                Text("Edit")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 34)
                    .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                    .frame(minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("editSubscriptionButton")
        }
        .padding(.bottom, -16)
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

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(MoneyFormat.string(current.amount, current.currency))
                    .font(.question(.largeTitle, weight: .bold))
                    .foregroundStyle(Color.inkText)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(current.billingFrequency.shortDisplay)
                    .font(.title3)
                    .foregroundStyle(Color.inkTextMuted)
            }
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(MoneyFormat.string(current.amount, current.currency)) \(current.billingFrequency.billingPeriodLabel)")

            if current.currency != currencyManager.selectedCurrency {
                let converted = currencyManager.convertToSelected(current.amount, from: current.currency)
                Text("About \(MoneyFormat.string(converted, currencyManager.selectedCurrency)) in your currency")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { statusChip; renewalText }
                VStack(alignment: .leading, spacing: 4) { statusChip; renewalText }
            }

            if current.nextBillingDate == nil, current.status == .active || current.status == .trial {
                Button { route = .edit } label: {
                    Text("Add a payment date").underline()
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
            Text(line.text)
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
            case .paused: return ("Paused", .paused)
            case .cancelled: return ("Cancelled", .kept)
            case .expired: return ("Expired", nil)
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

    private var renewalLine: (text: String, tint: Color)? {
        guard current.status == .active || current.status == .trial,
              let date = current.calculatedNextBillingDate, let days = current.daysUntilRenewal else { return nil }
        let dateText = date.formatted(.dateTime.month(.abbreviated).day())
        if days < 0 { return ("Payment was due \(-days) day\(-days == 1 ? "" : "s") ago", Color.due) }
        if days == 0 { return ("Renews today", Color.due) }
        if days == 1 { return ("Renews tomorrow", Color.due) }
        return ("Renews \(dateText) · in \(days) days", Color.inkTextMuted)
    }

    // MARK: - Facts

    private var factsCard: some View {
        let startedOn = current.startDate ?? current.createdAt
        return VStack(spacing: 0) {
            fact(L10n.string("Billing cycle"), current.billingFrequency.displayName)
            divider
            fact(L10n.string("Next payment"), current.calculatedNextBillingDate.map { $0.formatted(.dateTime.month(.abbreviated).day().year().locale(L10n.locale)) } ?? L10n.string("Not set"))
            divider
            fact(L10n.string("Category"), SubscriptionCategory.localizedLabel(for: current.category))
            divider
            fact(L10n.string("Per year"), MoneyFormat.string(current.amount * ProvenSubscription.periodsPerYear(current.billingFrequency), current.currency))
            divider
            fact(L10n.string("Tracking since"), startedOn.formatted(.dateTime.month(.abbreviated).year().locale(L10n.locale)))
        }
        .accessibilityElement(children: .contain)
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
            let days = Calendar.current.calendarDays(from: Date(), to: pending.date)
            let when = days == 0 ? L10n.string("today") : days == 1 ? L10n.string("tomorrow") : L10n.string("in \(days) days")
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
                        subtitle: L10n.string("\(MoneyFormat.string(line.onTrack, line.currency)) avoided over 12 months")) {
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

            if !alternatives.isEmpty {
                divider
                toolRow(icon: "arrow.left.arrow.right", title: L10n.string("Cheaper alternatives"),
                        subtitle: L10n.string("\(alternatives.count) options"),
                        isPro: !paymentManager.isUnlocked(.cheaperAlternatives)) {
                    route = paymentManager.isUnlocked(.cheaperAlternatives) ? .alternatives : .paywall
                }
            }

            if PausePlanSchedule.isEligible(current) {
                divider
                if PausePlanStore.shared.contains(current.id) {
                    toolRow(icon: "arrow.triangle.2.circlepath", title: L10n.string("In your Pause Plan"), subtitle: nil) { route = .pausePlan }
                } else {
                    toolRow(icon: "arrow.triangle.2.circlepath", title: L10n.string("Rotate with your other streaming"),
                            subtitle: L10n.string("Pause Plan"), isPro: !paymentManager.isUnlocked(.pausePlan)) { route = .pausePlan }
                }
            }

            divider
            toolRow(icon: "gauge.with.dots.needle.33percent", title: L10n.string("Usage and value"), subtitle: nil) { route = .usage }
        }
    }

    private func toolRow(icon: String, state: MoneyState? = nil, title: String, subtitle: String?, isPro: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button {
            Feel.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                if let state {
                    StateMark(state: state).frame(width: 24)
                } else {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                }
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
                }
                Spacer(minLength: 8)
                if isPro {
                    Text("Pro")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.inkTextFaint)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }


    @ViewBuilder
    private var supportGroup: some View {
        let phone = contacts.first { $0.type == .phone }
        let chat = contacts.first { $0.type == .chat || $0.type == .email }
        if phone != nil || chat != nil {
            VStack(spacing: 0) {
                if let phone, let url = Self.url(for: phone) {
                    toolRow(icon: "phone", title: L10n.string("Call support"), subtitle: phone.value) { openURL(url) }
                }
                if phone != nil, chat != nil { divider }
                if let chat, let url = Self.url(for: chat) {
                    toolRow(icon: chat.type == .email ? "envelope" : "bubble.left", title: L10n.string("Contact support"), subtitle: chat.label) { openURL(url) }
                }
            }
        }
    }

    /// Phone numbers, e-mail addresses and links all become real, tappable URLs.
    static func url(for contact: SupportContact) -> URL? {
        let value = contact.value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch contact.type {
        case .phone:
            let digits = value.filter { $0.isNumber || $0 == "+" }
            return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
        case .email:
            return value.contains("@") ? URL(string: "mailto:\(value)") : URL(string: value)
        default:
            if value.contains("@"), !value.contains("/") { return URL(string: "mailto:\(value)") }
            return URL(string: value.hasPrefix("http") ? value : "https://\(value)")
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if current.isPaused {
                RevolutionaryResumeButton(subscription: current)
            }

            if current.status != .cancelled {
                Button { route = .cancel } label: { Text("Cancel subscription") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("cancelSubscriptionButton")
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
        }
    }

    private func remove() async {
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await store.deleteSubscription(id: current.id)
            dismiss()
        } catch {
            errorMessage = "\"\(current.name)\" couldn't be removed. \(error.localizedDescription)"
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(for route: Route) -> some View {
        switch route {
        case .edit:
            SubscriptionEditView(subscription: current)
        case .paywall:
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        case .cancel:
            CancelSubscriptionFlow(subscription: current)
        case .priceHistory:
            PriceHistoryView(subscription: current)
        case .alternatives:
            AlternativesSheet(subscription: current, alternatives: alternatives) { self.route = .paywall }
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

// MARK: - Alternatives

private struct AlternativesSheet: View {
    let subscription: Subscription
    let alternatives: [AlternativeService]
    let onPaywall: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var actionManager = SubscriptionActionManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @State private var selected: AlternativeService?

    var body: some View {
        NavigationStack {
            ScrollView {
                AlternativesSection(
                    subscription: subscription,
                    alternatives: alternatives,
                    paymentManager: paymentManager,
                    actionManager: actionManager,
                    onSelectAlternative: { selected = $0 },
                    onPaywall: onPaywall
                )
                .padding(20)
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("Alternatives")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.inkText)
                }
            }
            .sheet(item: $selected) { alternative in
                AlternativeDetailView(alternative: alternative, current: subscription)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Usage

private struct UsageSheet: View {
    let subscription: Subscription

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var showInput = false
    @State private var showHistory = false

    private var minutes: Int { screenTimeManager.getCurrentMonthUsage(for: subscription.name) }
    private var costPerHour: Decimal? {
        screenTimeManager.calculateCostPerHour(monthlyCost: subscription.monthlyCost, subscriptionName: subscription.name)
    }

    /// What the person says they used it, and what that makes an hour cost. No score, no verdict:
    /// the figure is theirs, and so is the judgment.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Text("Done")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkTextMuted)
                            .frame(minHeight: Layout.tapTarget)
                            .contentShape(Rectangle())
                    }
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
                                    ? Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
                                    : L10n.string("Not entered"),
                                  emphasised: true)
                        ProofLine(label: L10n.string("It costs"), value: subscription.chargeText + subscription.billingFrequency.shortDisplay)
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

                Button { showHistory = true } label: {
                    Text("Usage history")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .frame(maxWidth: .infinity, minHeight: Layout.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showInput) {
            UsageInputSheet(subscriptionName: subscription.name, currentMinutes: minutes) { newMinutes in
                screenTimeManager.setMonthlyUsage(minutes: newMinutes, for: subscription.name)
            }
        }
        .sheet(isPresented: $showHistory) {
            UsageHistorySheet(subscriptionName: subscription.name)
        }
    }
}
