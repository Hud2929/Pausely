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
    /// The column the row icons sit in; it widens with the reader's text size, as the icons do.
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 24
    @Environment(\.dynamicTypeSize) private var typeSize
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
                            value: inboxes.isEmpty ? nil : (inboxes.count == 1 ? inboxes[0].address : L10n.number(inboxes.count)),
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

                // As wide as its words, so the question comes up from them and not from the
                // middle of an empty row.
                Button { confirmSignOut = true } label: {
                    Text("Sign out")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.due)
                        .tapArea(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("signOutButton")
                .asksFirst(Text("Sign out of Pausely?"), isPresented: $confirmSignOut,
                           message: Text("Your data is saved and will be here when you return.")) {
                    Button("Sign out", role: .destructive) { Task { await authManager.signOut() } }
                    Button("Cancel", role: .cancel) {}
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 28)
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .inkScreen()
        .task(id: paymentManager.currentTier) {
            #if DEBUG
            // `--demo-pro`, `=trial`, `=ending`, `=problem`: the plan group in each of its states,
            // which otherwise needs a purchase through the App Store.
            if let shown = LaunchFlag.value(of: "--demo-pro") {
                plan = .demo(shown)
                return
            }
            #endif
            plan = paymentManager.isPremium ? await StoreKitManager.shared.ownSubscription(for: paymentManager.currentTier) : nil
        }
        // Apple's own sheets: changing or cancelling the plan, and asking for money back.
        .manageSubscriptionsSheet(isPresented: $managingPlan)
        .refundRequestSheet(for: plan?.transactionId ?? 0, isPresented: $requestingRefund)
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

    /// The page's title: the name the person gave, when the account has one (Apple hands one over
    /// at the first sign-in), and "Profile" for an account made with an address. It used to make a
    /// name out of the address: "Jane.Doe", and for an address Apple hides, a run of letters.
    nonisolated static func title(for user: User?) -> String {
        user?.fullName ?? L10n.string("Profile")
    }

    /// Who the header names. A demo launch has nobody signed in, so no capture had ever shown the
    /// header a person with an account sees: `--demo-account` (DEBUG) puts one there, with an
    /// address only, as most accounts are, or with `=named` a name as well.
    private var shownUser: User? {
        #if DEBUG
        if let kind = LaunchFlag.value(of: "--demo-account") { return Self.demoAccount(kind) }
        #endif
        return authManager.currentUser
    }

    #if DEBUG
    nonisolated static func demoAccount(_ kind: String) -> User {
        kind == "named" ? User(id: "demo", email: "jane.doe@example.com", firstName: "Jane", lastName: "Doe")
                        : User(id: "demo", email: "jane.doe@longer-company-name.example.co.uk")
    }
    #endif

    private var header: some View {
        let user = shownUser
        let isPro = paymentManager.isPremium
        return VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: Self.title(for: user))
                .font(.question(.largeTitle, weight: .bold))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let email = user?.email, !email.isEmpty {
                // The address the account is under: whole, on as many lines as it needs, and
                // never hyphenated (`AddressText`).
                Text(verbatim: AddressText.breakable(email))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: email))
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
            // A free trial has been charged nothing, so there is nothing to refund: Manage ends it.
            row("creditcard", L10n.string("Manage subscription"), value: plan.statusLine(), id: "managePlanButton",
                last: plan.transactionId == nil || plan.isTrial) { managingPlan = true }
            if plan.transactionId != nil, !plan.isTrial {
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

    private func rowTitle(_ title: String) -> some View {
        Text(verbatim: title)
            .font(.body)
            .foregroundStyle(Color.inkText)
            .multilineTextAlignment(.leading)
    }

    private func rowValue(_ value: String) -> some View {
        Text(verbatim: value)
            .font(.body)
            .foregroundStyle(Color.inkTextMuted)
            .multilineTextAlignment(.leading)
    }

    private func row(_ icon: String, _ title: String, value: String? = nil, id: String, last: Bool = false,
                     action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button {
                Feel.selection()
                action()
            } label: {
                HStack(spacing: 14) {
                    // The symbol is above its words at the accessibility text sizes, like every
                    // other mark: beside them, in a column as wide as the text is tall, it left
                    // "Your year in subscriptions" four lines and "What's new" a word to a line.
                    MarkedWords(alignment: .center, spacing: 14) {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(Color.inkTextMuted)
                            .frame(width: MarkPlacement.sitsAbove(largeText: typeSize.isAccessibilitySize) ? nil : iconWidth)
                            .accessibilityHidden(true)
                    } words: {
                        // The value sits beside the title when both fit on one line, and under it when
                        // they do not: at accessibility text sizes ("Same as iP…" was cut short), and for a
                        // long value at any size ("Manage subscription" broke in two beside its date).
                        LineOrStack(spacing: 12, lineSpacing: 2, spread: true) {
                            rowTitle(title)
                            if let value { rowValue(value) }
                        }
                    }
                    RowChevron()
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
    private var isEmpty: Bool { stats.hasNothingToShow }
    /// The slip as a picture for sharing, drawn once when the screen opens (it was drawn on every
    /// pass of the screen's body).
    @State private var picture: Image?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton("Done") { dismiss() }
                    Spacer()
                    if !isEmpty, let image = picture {
                        ShareLink(item: image, preview: SharePreview(L10n.string("Your year in subscriptions"), image: image)) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .frame(width: Layout.tapTarget, height: Layout.tapTarget, alignment: .trailing)
                        }
                        .accessibilityLabel(Text("Share"))
                    }
                }

                if isEmpty {
                    // Nothing listed and nothing cancelled: a slip of zeros with a share button said
                    // "about $0 a year" as if it were a finding.
                    Text("Nothing to add up yet.")
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .accessibilityAddTraits(.isHeader)
                    Text("Add what you pay for and this page shows what a year of it costs.")
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                } else {
                    Text(L10n.string("Your subscriptions cost about \(MoneyFormat.string(stats.yearlyCost, currencyManager.selectedCurrency, locale: L10n.locale, wholeUnits: true)) a year."))
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .accessibilityAddTraits(.isHeader)

                    YearSlip(stats: stats, currency: currencyManager.selectedCurrency)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .inkScreen()
        .preferredColorScheme(.dark)
        .task(id: "\(subscriptions.count)|\(currencyManager.selectedCurrency)") {
            picture = isEmpty ? nil : YearSlip.image(stats: stats, currency: currencyManager.selectedCurrency)
        }
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
                Wordmark(text: "Pausely \(stats.yearText)")
                Perforation()
                ProofLine(label: L10n.string("Subscriptions"), value: L10n.number(stats.totalCount))
                ProofLine(label: L10n.string("Each month"), value: money(stats.monthlyCost))
                ProofLine(label: L10n.string("Each year"), value: money(stats.yearlyCost), emphasised: true)
                Perforation()
                ProofLine(label: L10n.string("Biggest"), value: stats.topService)
                ProofLine(label: L10n.string("Most goes to"), value: SubscriptionCategory.localizedLabel(for: stats.topCategory))
                if stats.cancelledCount > 0 || !kept.isEmpty {
                    Perforation()
                    ProofLine(label: L10n.string("Cancelled this year"), value: L10n.number(stats.cancelledCount))
                    if !kept.isEmpty {
                        // Every cancellation's charges so far, not only this calendar year's: said as that.
                        ProofLine(label: L10n.string("Kept so far"), value: kept.total(kept.savedSoFar), emphasised: true)
                            .foregroundStyle(Color.paperKept)
                    }
                }
            }
        }
    }

    @MainActor
    static func image(stats: WrappedStats, currency: String) -> Image? {
        let renderer = ImageRenderer(content: YearSlip(stats: stats, currency: currency)
            .frame(width: 360).padding(24).background(Color.ink)
            .inTheAppsLanguage())
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

    /// Nothing is being paid for and nothing was cancelled this year: there is no year to print.
    /// (Everything cancelled is a year worth printing: it costs nothing now and something was kept.)
    var hasNothingToShow: Bool { totalCount == 0 && cancelledCount == 0 }

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
