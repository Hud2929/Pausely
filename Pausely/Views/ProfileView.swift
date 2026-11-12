import StoreKit
import SwiftUI

/// Profile: who is signed in, which plan they are on, and every setting. One list, no cards.
struct ProfileView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.openURL) private var openURL
    @AppStorage("app_language") private var appLanguage = "system"

    @State private var sheet: Sheet?
    @State private var confirmSignOut = false
    /// Pausely Pro as the App Store states it, for someone paying through it. Nil for the free plan and
    /// for Pro given on the account, where there is nothing to manage or refund.
    @State private var plan: StoreKitManager.OwnSubscription?
    @State private var managingPlan = false
    @State private var requestingRefund = false

    private enum Sheet: String, Identifiable {
        case paywall, notifications, receipt, currency, privacy, help, export, whatsNew, wrapped, inbox, language
        var id: String { rawValue }
    }

    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                group(nil) {
                    row("doc.text", L10n.string("Savings Receipt"), id: "savingsReceiptButton") { sheet = .receipt }
                    row("calendar", L10n.string("Your year in subscriptions"), id: "wrappedButton") { sheet = .wrapped }
                    if FeatureFlags.inboxImportEnabled {
                        let inboxes = InboxScanner.shared.accounts
                        row("envelope",
                            L10n.string("Find in Email"),
                            value: inboxes.isEmpty ? nil : (inboxes.count == 1 ? inboxes[0].address : "\(inboxes.count)"),
                            id: "inboxImportButton") { sheet = .inbox }
                    }
                    row("arrow.up.forward.app", L10n.string("Apple subscriptions"), id: "importFromAppStoreButton", last: true) {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
                    }
                }

                if paymentManager.isPremium, let plan {
                    planGroup(plan)
                }

                group(L10n.string("Settings")) {
                    row("bell", L10n.string("Notifications"), id: "notificationsSettingsButton") { sheet = .notifications }
                    row("dollarsign.circle", L10n.string("Currency"), value: currencyManager.selectedCurrency,
                        id: "currencySettingsButton") { sheet = .currency }
                    row("globe", L10n.string("Language"), value: LanguageSettingsView.displayName(for: appLanguage),
                        id: "languageSettingsButton") { sheet = .language }
                    row("square.and.arrow.up", L10n.string("Export your list"), id: "exportDataButton") { sheet = .export }
                    row("lock", L10n.string("Privacy & security"), id: "privacySecurityButton") { sheet = .privacy }
                    row("questionmark.circle", L10n.string("Help & support"), id: "helpSupportButton", last: true) { sheet = .help }
                }

                group(L10n.string("About")) {
                    row("sparkles", L10n.string("What's new"), value: version, id: "whatsNewButton") { sheet = .whatsNew }
                    row("doc.plaintext", L10n.string("Terms of Service"), id: "termsButton") { open(AppConfig.termsOfServiceURL) }
                    row("hand.raised", L10n.string("Privacy Policy"), id: "privacyPolicyButton", last: true) { open(AppConfig.privacyPolicyURL) }
                }

                Button { confirmSignOut = true } label: {
                    Text("Sign out")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.due)
                        .frame(maxWidth: .infinity, minHeight: Layout.tapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 28)
                .accessibilityIdentifier("signOutButton")
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.ink.ignoresSafeArea())
        .task(id: paymentManager.currentTier) {
            plan = paymentManager.isPremium ? await StoreKitManager.shared.ownSubscription(for: paymentManager.currentTier) : nil
        }
        // Apple's own sheets: changing or cancelling the plan, and asking for money back.
        .manageSubscriptionsSheet(isPresented: $managingPlan)
        .refundRequestSheet(for: plan?.transactionId ?? 0, isPresented: $requestingRefund)
        .confirmationDialog("Sign out of Pausely?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await authManager.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data is saved and will be here when you return.")
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .paywall: StoreKitUpgradeView()
            case .notifications: NotificationsSettingsView()
            case .receipt: SavingsReceiptView()
            case .currency: CurrencySettingsView()
            case .privacy: PrivacySecurityView()
            case .help: HelpSupportView()
            case .export: ExportDataView()
            case .whatsNew: WhatsNewSheet()
            case .wrapped: SubscriptionWrappedView(subscriptions: store.subscriptions)
            case .inbox: InboxImportView()
            case .language: LanguageSettingsView()
            }
        }
    }

    // MARK: - Who and which plan

    private var header: some View {
        let user = authManager.currentUser
        let isPro = paymentManager.isPremium
        return VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: user?.displayName ?? L10n.string("Profile"))
                .font(.question(.largeTitle, weight: .bold))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let email = user?.email, !email.isEmpty {
                Text(verbatim: email)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
            }
            Text(isPro ? L10n.string("Pausely Pro")
                       : L10n.string("Free plan: Pausely tracks up to \(FreeTier.subscriptionLimit) subscriptions."))
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            if !isPro {
                Button { sheet = .paywall } label: { Text("See Pro") }
                    .buttonStyle(.ink(.quiet))
                    .padding(.top, 12)
                    .accessibilityIdentifier("upgradePromptCard")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - The plan, for someone paying through the App Store

    /// When it renews or ends, a warning if Apple couldn't charge for it, and Apple's sheets for
    /// managing it and for asking for a refund. Pausely tells people to cancel it if it isn't saving
    /// them more than it costs, so the way to do that is two taps from here.
    private func planGroup(_ plan: StoreKitManager.OwnSubscription) -> some View {
        group(L10n.string("Pausely Pro")) {
            if plan.hasBillingProblem {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    StateMark(state: .due).accessibilityHidden(true)
                    Text("Apple couldn't take the payment for Pausely Pro. Update your payment method to keep it.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("planBillingProblem")
                Hairline()
            }
            row("creditcard", L10n.string("Manage subscription"), value: plan.statusLine(), id: "managePlanButton",
                last: plan.transactionId == nil) { managingPlan = true }
            if plan.transactionId != nil {
                row("arrow.uturn.backward", L10n.string("Request a refund"), id: "refundPlanButton", last: true) { requestingRefund = true }
            }
        }
    }

    // MARK: - Rows

    private func group<Content: View>(_ title: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(verbatim: title)
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .padding(.bottom, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            content()
        }
        .padding(.top, 28)
    }

    private func row(_ icon: String, _ title: String, value: String? = nil, id: String, last: Bool = false,
                     action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button {
                Feel.selection()
                action()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    Text(verbatim: title)
                        .font(.body)
                        .foregroundStyle(Color.inkText)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    if let value {
                        Text(verbatim: value)
                            .font(.body)
                            .foregroundStyle(Color.inkTextMuted)
                            .lineLimit(1)
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
            .accessibilityIdentifier(id)
            if !last { Hairline() }
        }
    }

    private func open(_ address: String) {
        if let url = URL(string: address) { openURL(url) }
    }
}

// MARK: - Your year in subscriptions

/// The year on one slip: what the list costs, the biggest line, what was cancelled and what that kept.
/// It states what the current list costs, never what was "spent": Pausely doesn't know what was
/// charged before a subscription was added.
struct SubscriptionWrappedView: View {
    let subscriptions: [Subscription]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    private var stats: WrappedStats { WrappedStats(subscriptions: subscriptions, events: LifecycleEventLog.shared.events) }

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
                    if let image = YearSlip.image(stats: stats, currency: currencyManager.selectedCurrency) {
                        ShareLink(item: image, preview: SharePreview(L10n.string("Your year in subscriptions"), image: image)) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .frame(width: Layout.tapTarget, height: Layout.tapTarget, alignment: .trailing)
                        }
                        .accessibilityLabel(Text("Share"))
                    }
                }

                Text(L10n.string("Your subscriptions cost about \(MoneyFormat.string(stats.yearlyCost, currencyManager.selectedCurrency, locale: L10n.locale, wholeUnits: true)) a year."))
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)

                YearSlip(stats: stats, currency: currencyManager.selectedCurrency)
                    .padding(.top, 24)
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

/// The printed year. Also what is shared.
private struct YearSlip: View {
    let stats: WrappedStats
    let currency: String

    private func money(_ amount: Decimal) -> String {
        MoneyFormat.total(amount, currency, converted: stats.isConverted, locale: L10n.locale)
    }

    var body: some View {
        let kept = SavingsSummary.current()
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Capsule().frame(width: 4, height: 14)
                        Capsule().frame(width: 4, height: 14)
                    }
                    .accessibilityHidden(true)
                    Text(verbatim: "Pausely \(stats.yearText)").font(.headline)
                }
                Perforation()
                ProofLine(label: L10n.string("Subscriptions"), value: "\(stats.totalCount)")
                ProofLine(label: L10n.string("Each month"), value: money(stats.monthlyCost))
                ProofLine(label: L10n.string("Each year"), value: money(stats.yearlyCost), emphasised: true)
                Perforation()
                ProofLine(label: L10n.string("Biggest"), value: stats.topService)
                ProofLine(label: L10n.string("Most goes to"), value: SubscriptionCategory.localizedLabel(for: stats.topCategory))
                if stats.cancelledCount > 0 || !kept.isEmpty {
                    Perforation()
                    ProofLine(label: L10n.string("Cancelled this year"), value: "\(stats.cancelledCount)")
                    if !kept.isEmpty {
                        // Every cancellation's charges so far, not only this calendar year's: said as that.
                        ProofLine(label: L10n.string("Kept so far"), value: kept.formatted(kept.savedSoFar), emphasised: true)
                            .foregroundStyle(Color.paperKept)
                    }
                }
            }
        }
    }

    @MainActor
    static func image(stats: WrappedStats, currency: String) -> Image? {
        let renderer = ImageRenderer(content: YearSlip(stats: stats, currency: currency)
            .frame(width: 360).padding(24).background(Color.ink))
        renderer.scale = 3
        return renderer.uiImage.map(Image.init(uiImage:))
    }
}

/// The numbers on the year slip. Pure: the list, the event history and the day go in.
struct WrappedStats {
    let year: Int
    /// The year the slip counts, as the reader writes it. It is a Gregorian year (the count runs from
    /// 1 January), shown in their digits.
    let yearText: String
    let yearlyCost: Decimal
    let monthlyCost: Decimal
    /// Some of it is charged in another currency, so the two costs are estimates ("≈").
    let isConverted: Bool
    let totalCount: Int
    let cancelledCount: Int
    let topService: String
    let topCategory: String

    init(subscriptions: [Subscription], events: [LifecycleEvent],
         now: Date = Date(), calendar: Calendar = .billing,
         currency: String = CurrencyManager.shared.selectedCurrency, rates: CurrencyRates = CurrencyManager.shared.rates) {
        year = calendar.component(.year, from: now)
        yearText = now.formatted(Date.FormatStyle(locale: L10n.locale, calendar: calendar).year())
        let active = subscriptions.charging
        totalCount = active.count
        // What the current list costs, in the display currency. Pausely doesn't know what was
        // charged before a subscription was added, so the slip never claims an amount "spent".
        yearlyCost = active.annualTotal(in: currency, rates: rates)
        monthlyCost = active.monthlyTotal(in: currency, rates: rates)
        isConverted = active.isConverted(to: currency)
        cancelledCount = Self.cancelledThisYear(events, year: year, calendar: calendar)
        // Compared in one currency; one with no rate is never "the biggest".
        topService = active.max(by: {
            ($0.monthlyCost(in: currency, rates: rates) ?? -1) < ($1.monthlyCost(in: currency, rates: rates) ?? -1)
        })?.name ?? "–"
        // The same grouping Insights uses, so "entertainment" and "Entertainment" are one category.
        topCategory = subscriptions.categoryTotals(in: currency, rates: rates).first?.category ?? "–"
    }

    /// Subscriptions cancelled in `year` and still cancelled, counted from the history. The record's
    /// own "last changed" date moves on any edit or sync, so it says nothing about when it was cancelled.
    static func cancelledThisYear(_ events: [LifecycleEvent], year: Int, calendar: Calendar = .billing) -> Int {
        var latest: [UUID: LifecycleEvent] = [:]
        for event in events where event.kind == .cancelled || event.kind == .reactivated {
            if let seen = latest[event.subscriptionId], seen.date > event.date { continue }
            latest[event.subscriptionId] = event
        }
        return latest.values.filter { $0.kind == .cancelled && calendar.component(.year, from: $0.date) == year }.count
    }
}

#Preview {
    ProfileView()
}
