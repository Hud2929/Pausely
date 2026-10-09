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
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var route: Route?
    @State private var showRemoveConfirm = false
    @State private var isRemoving = false
    @State private var errorMessage: String?

    private enum Route: String, Identifiable {
        case edit, paywall, cancel, priceHistory, annualSavings, alternatives, usage
        var id: String { rawValue }
    }

    /// Always the freshest copy, so the screen updates the moment an edit is saved.
    private var current: Subscription {
        store.subscriptions.first { $0.id == subscription.id } ?? subscription
    }

    private var alternatives: [AlternativeService] { actionManager.findAlternatives(for: current) }
    private var contacts: [SupportContact] { actionManager.getSupportContacts(for: current) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidianBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        hero
                        factsCard
                        toolsGroup
                        supportGroup
                        actions
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .accessibilityIdentifier("subscriptionDoneButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        HapticStyle.light.trigger()
                        route = .edit
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentMint)
                    .accessibilityIdentifier("editSubscriptionButton")
                }
            }
        }
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

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            ServiceLogoView(name: current.name, category: current.category, size: 68)
                .accessibilityHidden(true)

            Text(current.name)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(MoneyFormat.string(current.amount, current.currency))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Color.accentMint)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(current.billingFrequency.shortDisplay)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(MoneyFormat.string(current.amount, current.currency)) \(current.billingFrequency.billingPeriodLabel)")

            if current.currency != currencyManager.selectedCurrency {
                let converted = currencyManager.convertToSelected(current.amount, from: current.currency)
                Text("About \(MoneyFormat.string(converted, currencyManager.selectedCurrency)) in your currency")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }

            HStack(spacing: 8) {
                statusChip
                if let line = renewalLine {
                    Text(line.text)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(line.tint)
                }
            }
            .padding(.top, 2)

            if current.nextBillingDate == nil, current.status == .active || current.status == .trial {
                Button {
                    HapticStyle.light.trigger()
                    route = .edit
                } label: {
                    Text("Add a payment date")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.accentMint)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusChip: some View {
        let (text, tint): (String, Color) = {
            switch current.status {
            case .active: return ("Active", Color.accentMint)
            case .trial: return ("Free trial", Color.accentMint)
            case .paused: return ("Paused", .orange)
            case .cancelled: return ("Cancelled", .red)
            case .expired: return ("Expired", Color.obsidianTextSecondary)
            }
        }()
        return Text(text)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.15)))
    }

    private var renewalLine: (text: String, tint: Color)? {
        guard current.status == .active || current.status == .trial,
              let date = current.nextBillingDate, let days = current.daysUntilRenewal else { return nil }
        let dateText = date.formatted(.dateTime.month(.abbreviated).day())
        if days < 0 { return ("Payment was due \(-days) day\(-days == 1 ? "" : "s") ago", .orange) }
        if days == 0 { return ("Renews today", .orange) }
        if days == 1 { return ("Renews tomorrow", Color.obsidianTextSecondary) }
        return ("Renews \(dateText) · in \(days) days", Color.obsidianTextSecondary)
    }

    // MARK: - Facts

    private var factsCard: some View {
        let startedOn = current.startDate ?? current.createdAt
        return VStack(spacing: 0) {
            fact("Billing cycle", current.billingFrequency.displayName)
            divider
            fact("Next payment", current.nextBillingDate.map { $0.formatted(.dateTime.month(.abbreviated).day().year()) } ?? "Not set")
            divider
            fact("Category", current.category ?? "Other")
            divider
            fact("Per year", MoneyFormat.string(current.amount * ProvenSubscription.periodsPerYear(current.billingFrequency), current.currency))
            divider
            fact("Tracking since", startedOn.formatted(.dateTime.month(.abbreviated).year()))
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
        .accessibilityElement(children: .contain)
    }

    private func fact(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 16)
    }

    // MARK: - Tools

    @ViewBuilder
    private var toolsGroup: some View {
        VStack(spacing: 0) {
            toolRow(icon: "chart.line.uptrend.xyaxis", title: "Price history", subtitle: nil) { route = .priceHistory }

            if current.billingFrequency == .monthly {
                divider
                toolRow(icon: "calendar.badge.checkmark", title: "Switch to yearly", subtitle: "See what you'd save") { route = .annualSavings }
            }

            if !alternatives.isEmpty {
                divider
                toolRow(icon: "arrow.left.arrow.right", title: "Cheaper alternatives",
                        subtitle: "\(alternatives.count) option\(alternatives.count == 1 ? "" : "s")",
                        isPro: !paymentManager.isPremium) {
                    route = paymentManager.isPremium ? .alternatives : .paywall
                }
            }

            divider
            toolRow(icon: "gauge.with.dots.needle.33percent", title: "Usage and value", subtitle: nil) { route = .usage }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
    }

    private func toolRow(icon: String, title: String, subtitle: String?, isPro: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            HapticStyle.light.trigger()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentMint)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                    }
                }
                Spacer(minLength: 8)
                if isPro {
                    Text("Pro")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.accentMint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentMint.opacity(0.15)))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Support

    @ViewBuilder
    private var supportGroup: some View {
        let phone = contacts.first { $0.type == .phone }
        let chat = contacts.first { $0.type == .chat || $0.type == .email }
        if phone != nil || chat != nil {
            VStack(spacing: 0) {
                if let phone, let url = Self.url(for: phone) {
                    toolRow(icon: "phone", title: "Call support", subtitle: phone.value) { openURL(url) }
                }
                if phone != nil, chat != nil { divider }
                if let chat, let url = Self.url(for: chat) {
                    toolRow(icon: chat.type == .email ? "envelope" : "bubble.left", title: "Contact support", subtitle: chat.label) { openURL(url) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
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
        VStack(spacing: 12) {
            if current.isPaused {
                RevolutionaryResumeButton(subscription: current)
            }

            if current.status != .cancelled {
                Button {
                    HapticStyle.medium.trigger()
                    route = paymentManager.isPremium ? .cancel : .paywall
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: paymentManager.isPremium ? "xmark.circle" : "lock.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Cancel subscription")
                        if !paymentManager.isPremium {
                            Text("Pro")
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .foregroundStyle(Color.accentMint)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentMint.opacity(0.15)))
                        }
                    }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(paymentManager.isPremium ? Color.red : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(paymentManager.isPremium ? Color.red.opacity(0.12) : Color.obsidianSurface)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityIdentifier("cancelSubscriptionButton")
            }

            Button {
                HapticStyle.light.trigger()
                showRemoveConfirm = true
            } label: {
                Text(isRemoving ? "Removing…" : "Remove from Pausely")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isRemoving)
            .accessibilityIdentifier("removeSubscriptionButton")
        }
    }

    private func remove() async {
        isRemoving = true
        defer { isRemoving = false }
        do {
            try await store.deleteSubscription(id: current.id)
            HapticStyle.success.trigger()
            dismiss()
        } catch {
            HapticStyle.error.trigger()
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
        case .annualSavings:
            AnnualSavingsCalculatorView(subscription: current)
        case .alternatives:
            AlternativesSheet(subscription: current, alternatives: alternatives) { self.route = .paywall }
        case .usage:
            UsageSheet(subscription: current)
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
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Alternatives")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accentMint)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CostPerUseDetailSection(subscription: subscription)

                    UsageTrackingSection(
                        subscription: subscription,
                        screenTimeManager: screenTimeManager,
                        currentUsageMinutes: minutes,
                        costPerHour: costPerHour,
                        usageStats: screenTimeManager.getUsageStats(for: subscription.name),
                        onEditUsage: { showInput = true }
                    )

                    Button {
                        showHistory = true
                    } label: {
                        HStack {
                            Text("Usage history")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.obsidianTextTertiary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(20)
            }
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Usage and value")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accentMint)
                }
            }
            .sheet(isPresented: $showInput) {
                UsageInputSheet(subscriptionName: subscription.name, currentMinutes: minutes) { newMinutes in
                    screenTimeManager.setMonthlyUsage(minutes: newMinutes, for: subscription.name)
                }
            }
            .sheet(isPresented: $showHistory) {
                UsageHistorySheet(subscriptionName: subscription.name)
            }
        }
        .preferredColorScheme(.dark)
    }
}
