import SwiftUI

/// Profile: who is signed in, which plan they are on, and every setting. One list, no cards.
struct PremiumProfileView: View {
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.openURL) private var openURL
    @AppStorage("app_language") private var appLanguage = "system"

    @State private var sheet: Sheet?
    @State private var confirmSignOut = false

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
                            inboxes.isEmpty ? L10n.string("Find subscriptions in email") : L10n.string("Email inboxes"),
                            value: inboxes.isEmpty ? nil : (inboxes.count == 1 ? inboxes[0].address : L10n.string("\(inboxes.count) connected")),
                            id: "inboxImportButton") { sheet = .inbox }
                    }
                    row("arrow.up.forward.app", L10n.string("Apple Subscriptions"), id: "importFromAppStoreButton", last: true) {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
                    }
                }

                group(L10n.string("Settings")) {
                    row("bell", L10n.string("Notifications"), id: "notificationsSettingsButton") { sheet = .notifications }
                    row("dollarsign.circle", L10n.string("Currency"), value: currencyManager.selectedCurrency,
                        id: "currencySettingsButton") { sheet = .currency }
                    row("globe", L10n.string("Language"), value: LanguageSettingsView.displayName(for: appLanguage),
                        id: "languageSettingsButton") { sheet = .language }
                    row("square.and.arrow.up", L10n.string("Export Data"), id: "exportDataButton") { sheet = .export }
                    row("lock", L10n.string("Privacy & Security"), id: "privacySecurityButton") { sheet = .privacy }
                    row("questionmark.circle", L10n.string("Help & Support"), id: "helpSupportButton", last: true) { sheet = .help }
                }

                group(L10n.string("About")) {
                    row("sparkles", L10n.string("What's New"), value: version, id: "whatsNewButton") { sheet = .whatsNew }
                    row("doc.plaintext", L10n.string("Terms of Service"), id: "termsButton") { open(AppConfig.termsOfServiceURL) }
                    row("hand.raised", L10n.string("Privacy Policy"), id: "privacyPolicyButton", last: true) { open(AppConfig.privacyPolicyURL) }
                }

                Button { confirmSignOut = true } label: {
                    Text("Sign Out")
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
        .confirmationDialog("Sign out of Pausely?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { Task { await authManager.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data is saved and will be here when you return.")
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .paywall: StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
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
                       : L10n.string("Free plan: Pausely watches up to \(FreeTier.subscriptionLimit) subscriptions."))
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

    private var stats: WrappedStats { WrappedStats(subscriptions: subscriptions) }

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

    private func money(_ amount: Decimal) -> String { MoneyFormat.string(amount, currency, locale: L10n.locale) }

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
                    Text(verbatim: "Pausely \(stats.year)").font(.headline)
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
                        ProofLine(label: L10n.string("Kept with Pausely"), value: kept.formatted(kept.savedSoFar), emphasised: true)
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

struct WrappedStats {
    let year: Int
    let yearlyCost: Decimal
    let monthlyCost: Decimal
    let totalCount: Int
    let cancelledCount: Int
    let topService: String
    let topCategory: String

    init(subscriptions: [Subscription]) {
        year = Calendar.current.component(.year, from: Date())
        let active = subscriptions.filter { $0.status == .active || $0.status == .trial }
        let yearStart = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let cancelled = subscriptions.filter {
            $0.status == .cancelled &&
            $0.updatedAt >= yearStart
        }
        totalCount = active.count
        cancelledCount = cancelled.count
        // What the current list costs, in the display currency. Pausely doesn't know what was
        // charged before a subscription was added, so Wrapped never claims an amount "spent".
        yearlyCost = active.annualTotal()
        monthlyCost = active.monthlyTotal()
        topService = active.max(by: { [$0].monthlyTotal() < [$1].monthlyTotal() })?.name ?? "–"
        let grouped = Dictionary(grouping: active) { $0.category ?? "Other" }
        topCategory = grouped.max(by: { $0.value.monthlyTotal() < $1.value.monthlyTotal() })?.key ?? "–"
    }
}

#Preview {
    PremiumProfileView()
}
