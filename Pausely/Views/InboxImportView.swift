//
//  InboxImportView.swift
//  Pausely
//
//  Find subscriptions in email: connect an inbox (Gmail, Outlook, iCloud, Yahoo, AOL or any IMAP inbox),
//  watch the receipts being read on this iPhone, choose what to keep, and see exactly what was added.
//

import SwiftUI

struct InboxImportView: View {
    @ObservedObject private var scanner = InboxScanner.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var payments = PaymentManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var expanded: Set<String> = []
    @State private var didPreselect = false
    @State private var importing = false
    @State private var outcome: TallyImporter.Outcome?
    @State private var imapPreset: IMAPPreset?
    @State private var showingIMAP = false
    @State private var showingProviders = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if let outcome {
                        outcomeSection(outcome)
                    } else if !scanner.hasAccounts {
                        connectSection
                    } else if scanner.isScanning {
                        scanningSection
                    } else if !scanner.foundSubscriptions.isEmpty {
                        resultsSection
                    } else {
                        connectedSection
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.ink.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { addBar }
            .navigationTitle("Find in Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.inkText)
                }
            }
            .sheet(isPresented: $showingIMAP) {
                IMAPConnectView(preset: imapPreset)
            }
            .sheet(isPresented: $showingProviders) {
                NavigationStack {
                    ScrollView {
                        providerButtons.padding(Layout.margin)
                    }
                    .background(Color.ink.ignoresSafeArea())
                    .navigationTitle("Add an inbox")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showingProviders = false }.foregroundStyle(Color.inkText)
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingPaywall) {
                StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
            }
        }
        // Connecting is the request to search: a new inbox is searched at once, without a second tap.
        .onChange(of: scanner.accounts.count) { before, after in
            guard after > before else { return }
            outcome = nil
            Task { await scanner.scanAll() }
        }
        .onChange(of: scanner.isScanning) { _, scanning in
            if scanning { didPreselect = false; selected = []; expanded = [] }
        }
    }

    // MARK: - Before any inbox is connected

    /// What this does, what it never does, and which inbox.
    private var connectSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Find subscriptions in your email")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Pausely reads the receipts in your inbox and finds what you pay for, including trials and price changes.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            privacyNotice.padding(.top, 24)

            providerButtons.padding(.top, 16)

            if let error = scanner.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color.due)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The promise, printed: it is the reason someone would let an app near their inbox. Each sentence is
    /// held by a test (`InboxPrivacyTests`).
    private var privacyNotice: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your email never leaves your iPhone.")
                    .font(.question(.title3))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Pausely connects straight to your email provider, reads receipts on this iPhone and keeps only the name, amount and date of each charge. It only reads: it never sends, changes or deletes email.")
                    .font(.footnote)
                    .foregroundStyle(Color.paperMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var providerButtons: some View {
        VStack(spacing: 0) {
            if FeatureFlags.gmailImportEnabled && GmailMailboxProvider.isConfigured {
                providerButton(Text(verbatim: "Gmail"), detail: Text("Sign in with Google"), icon: "Gmail", id: "connectGmail") {
                    showingProviders = false
                    Task { await scanner.connectGmail() }
                }
            }
            if FeatureFlags.microsoftImportEnabled && MicrosoftGraphProvider.isConfigured {
                providerButton(Text(verbatim: "Outlook, Hotmail, Live, MSN"), detail: Text("Sign in with Microsoft"), icon: "Outlook", id: "connectMicrosoft") {
                    showingProviders = false
                    Task { await scanner.connectMicrosoft() }
                }
            }
            if FeatureFlags.imapImportEnabled {
                ForEach(["icloud", "yahoo", "aol", "gmail-imap"], id: \.self) { id in
                    if let preset = IMAPPreset.find(id) {
                        providerButton(Text(verbatim: preset.name), detail: Text("With an app password"), icon: preset.name, id: "connect-\(id)") {
                            openIMAP(preset)
                        }
                    }
                }
                providerButton(Text("Other email"), detail: Text("GMX, WEB.DE, Zoho, Fastmail and more"), icon: "", id: "connect-other") {
                    openIMAP(nil)
                }
            }
        }
    }

    private func openIMAP(_ preset: IMAPPreset?) {
        imapPreset = preset
        showingProviders = false
        showingIMAP = true
    }

    private func providerButton(_ title: Text, detail: Text, icon: String, id: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    if icon.isEmpty {
                        Image(systemName: "envelope")
                            .font(.body)
                            .foregroundStyle(Color.inkTextMuted)
                            .frame(width: 36, height: 36)
                            .accessibilityHidden(true)
                    } else {
                        ServiceLogoView(name: icon, category: nil, size: 36)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        title
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        detail
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkTextFaint)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(id)
            Hairline()
        }
    }

    // MARK: - While searching

    /// The search, as it happens: each receipt read is printed on the slip, so the wait shows its work.
    private var scanningSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Searching your email")
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                ProgressView(value: scanner.progress)
                    .tint(Color.inkText)
                    .accessibilityLabel(Text("Search progress"))
                (scanner.statusLine.isEmpty ? Text("Connecting…") : Text(verbatim: scanner.statusLine))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("scanStatus")
            }

            if !scanner.receiptsSeen.isEmpty {
                receiptsSlip
            }

            Button(action: { scanner.cancelScan() }) { Text("Stop and show what's found") }
                .buttonStyle(.ink(.quiet))
                .accessibilityIdentifier("stopScanButton")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var receiptsSlip: some View {
        let shown = Array(scanner.receiptsSeen.prefix(8))
        let more = scanner.receiptsSeen.count - shown.count
        return PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Receipts read so far")
                    .font(.proof(.caption))
                    .foregroundStyle(Color.paperMuted)
                ForEach(shown) { receipt in
                    ProofLine(label: receipt.name, value: InboxImportView.money(receipt.amount, receipt.currency))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if more > 0 {
                    Text("and \(more) more")
                        .font(.proof(.caption))
                        .foregroundStyle(Color.paperMuted)
                }
            }
            .animation(Motion.unlessReduced(Motion.arrive), value: scanner.receiptsSeen.count)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("receiptsSlip")
    }

    // MARK: - Connected, nothing to show

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let message = scanner.error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: message)
                        .font(.question(.title2))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("searchOutcome")
                    if scanner.accountErrors.isEmpty {
                        Text("Emails checked: \(scanner.stats.emailsChecked). Receipts may go to another address: add that inbox too.")
                            .font(.body)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(scanner.accounts) { account in
                    accountRow(account)
                    Hairline()
                }
                Button(action: { showingProviders = true }) {
                    Label("Add another inbox", systemImage: "plus")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.inkText)
                        .frame(maxWidth: .infinity, minHeight: Layout.tapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addInboxButton")
            }

            Button(action: { Task { await scanner.scanAll() } }) {
                scanner.accounts.contains { $0.lastScan != nil } ? Text("Search again") : Text("Find subscriptions")
            }
            .buttonStyle(.ink)
            .accessibilityIdentifier("scanInboxesButton")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accountRow(_ account: MailboxAccount) -> some View {
        let failed = scanner.accountErrors[account.id] != nil
        return HStack(spacing: 12) {
            Image(systemName: failed ? "exclamationmark.circle" : "envelope")
                .font(.body)
                .foregroundStyle(failed ? Color.due : Color.inkTextMuted)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: account.address)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.inkText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(verbatim: accountDetail(account))
                    .font(.subheadline)
                    .foregroundStyle(failed ? Color.due : Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Menu {
                Button(role: .destructive) {
                    Task { await scanner.disconnect(account) }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .accessibilityIdentifier("disconnectInbox")
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(account.address)")
            .accessibilityIdentifier("inboxOptions")
        }
        .padding(.vertical, 8)
    }

    private func accountDetail(_ account: MailboxAccount) -> String {
        if let error = scanner.accountErrors[account.id] { return error }
        if let last = account.lastScan {
            return L10n.string("\(account.providerName) · searched \(last.formatted(.relative(presentation: .named).locale(L10n.locale)))")
        }
        return account.providerName
    }

    // MARK: - Results

    private var live: [FoundSubscription] { scanner.foundSubscriptions.filter(\.isLive) }
    private var chosen: [FoundSubscription] { scanner.foundSubscriptions.filter { selected.contains($0.id) && !$0.isCancelled } }

    private var resultsSection: some View {
        let confirmed = live.filter { $0.proven.tier == .confirmed }
        let worthALook = live.filter { $0.proven.tier != .confirmed }
        let ended = scanner.foundSubscriptions.filter { $0.proven.status == .likelyEnded }
        let cancelled = scanner.foundSubscriptions.filter(\.isCancelled)

        return VStack(spacing: 28) {
            summary(count: live.count)
            insights
            if !confirmed.isEmpty {
                listSection(title: "Confirmed", subtitle: "Your receipts show these renew", items: confirmed)
            }
            if !worthALook.isEmpty {
                listSection(title: "Worth a look", subtitle: "Check these before adding them", items: worthALook)
            }
            if !ended.isEmpty {
                listSection(title: "May have ended", subtitle: "No recent charge in this inbox", items: ended)
            }
            if !cancelled.isEmpty {
                listSection(title: "Cancelled", subtitle: "A cancellation email followed the last charge", items: cancelled)
            }
        }
        .onAppear(perform: preselectConfirmed)
    }

    private func preselectConfirmed() {
        guard !didPreselect else { return }
        didPreselect = true
        selected = Set(live.filter { $0.proven.tier == .confirmed }.map(\.id))
    }

    /// What the search found: the total first, then how it was worked out.
    private func summary(count: Int) -> some View {
        let currency = CurrencyManager.shared.selectedCurrency
        let monthly = scanner.report?.monthlyTotal(in: currency) ?? 0
        let ignored = scanner.stats.purchasesIgnored
        let stats = scanner.stats

        return VStack(alignment: .leading, spacing: 16) {
            Text("We found \(count) subscriptions")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            PaperSlip(tornTop: true, tornBottom: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ProofLine(label: L10n.string("Each month"), value: InboxImportView.money(monthly, currency), emphasised: true)
                    ProofLine(label: L10n.string("Each year"), value: InboxImportView.money(monthly * 12, currency))
                    if ignored > 0 || stats.emailsChecked > 0 { Perforation() }
                    if stats.emailsChecked > 0 {
                        Text("Emails checked: \(stats.emailsChecked) · read in full: \(stats.bodiesRead) · all on your phone")
                            .font(.proof(.caption))
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if ignored > 0 {
                        Text("Senders with only one-time purchases, left out: \(ignored)")
                            .font(.proof(.caption))
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var insights: some View {
        let insights = Array((scanner.report?.insights ?? []).prefix(4))
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Worth knowing")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .padding(.bottom, 4)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    if index > 0 { Hairline() }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        StateMark(state: state(for: insight.kind))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(insight.detail)
                                .font(.subheadline)
                                .foregroundStyle(Color.inkTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func state(for kind: IntelligenceInsight.Kind) -> MoneyState {
        switch kind {
        case .chargedAfterCancel, .paymentFailed: return .due
        case .priceIncrease, .priceChangeNotice, .trialEnding, .renewalSoon: return .decide
        case .likelyEnded: return .paused
        }
    }

    private func listSection(title: LocalizedStringKey, subtitle: LocalizedStringKey, items: [FoundSubscription]) -> some View {
        let selectable = items.filter { !$0.isCancelled }
        return VStack(alignment: .leading, spacing: 6) {
            AdaptiveRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.inkText)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } value: {
                if !selectable.isEmpty {
                    let allSelected = selectable.allSatisfy { selected.contains($0.id) }
                    Button {
                        if allSelected { selectable.forEach { selected.remove($0.id) } } else { selectable.forEach { selected.insert($0.id) } }
                    } label: {
                        (allSelected ? Text("Deselect all") : Text("Select all"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .frame(minHeight: Layout.tapTarget)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, found in
                    if index > 0 { Hairline() }
                    FoundRow(
                        found: found,
                        isSelected: selected.contains(found.id),
                        isExpanded: expanded.contains(found.id),
                        onToggle: { if selected.contains(found.id) { selected.remove(found.id) } else { selected.insert(found.id) } },
                        onExpand: {
                            withAnimation(Motion.unlessReduced(Motion.touch)) {
                                if expanded.contains(found.id) { expanded.remove(found.id) } else { expanded.insert(found.id) }
                            }
                        },
                        onReject: {
                            selected.remove(found.id)
                            withAnimation(Motion.unlessReduced(Motion.leave)) { scanner.markNotSubscription(found) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - The bar that adds

    /// How many of the chosen subscriptions fit under the free limit. Nil when there is no limit.
    private var freeSlots: Int? {
        payments.isUnlocked(.unlimitedSubscriptions) ? nil : max(0, FreeTier.subscriptionLimit - store.subscriptions.count)
    }

    /// The chosen ones that aren't on the list already: the ones the free limit applies to.
    private var newlyChosen: Int {
        let listed = Set(store.subscriptions.map { $0.name.lowercased() })
        return chosen.filter { !listed.contains($0.name.lowercased()) }.count
    }

    @ViewBuilder
    private var addBar: some View {
        if outcome == nil, !scanner.isScanning, !scanner.foundSubscriptions.isEmpty, scanner.hasAccounts, !chosen.isEmpty {
            VStack(spacing: 8) {
                if let slots = freeSlots, newlyChosen > slots {
                    // Said before the tap, not discovered after it.
                    Text(slots == 0
                         ? L10n.string("Free watches \(FreeTier.subscriptionLimit) and your list is full. What you add now will wait until you make room or go Pro.")
                         : L10n.string("Free watches \(FreeTier.subscriptionLimit). Added now, most expensive first: \(slots). Waiting until you make room or go Pro: \(newlyChosen - slots)."))
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("freeLimitNote")
                }
                Button(action: { Task { await addChosen() } }) {
                    if importing { ProgressView().tint(Color.paperInk) } else { Text("Add \(chosen.count) to my list") }
                }
                .buttonStyle(.ink)
                .disabled(importing)
                .accessibilityIdentifier("importSelectedButton")
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.ink)
            .overlay(alignment: .top) { Hairline() }
        }
    }

    private func addChosen() async {
        importing = true
        let result = await scanner.importSubscriptions(chosen)
        scanner.foundSubscriptions = []
        selected = []
        expanded = []
        didPreselect = false
        importing = false
        outcome = result
        Feel.landed()
    }

    // MARK: - What was added

    /// Exactly what happened to each one: added, waiting, or already there. Nothing is dropped unsaid.
    private func outcomeSection(_ outcome: TallyImporter.Outcome) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(outcomeTitle(outcome))
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("importOutcomeTitle")

            VStack(alignment: .leading, spacing: 0) {
                if !outcome.added.isEmpty {
                    outcomeLine(L10n.string("Each one now shows its next charge on Home."), names: outcome.added)
                }
                if !outcome.waiting.isEmpty {
                    if !outcome.added.isEmpty { Hairline() }
                    outcomeLine(L10n.string("Waiting: \(outcome.waiting.count). Free watches \(FreeTier.subscriptionLimit); Pro watches all of them."),
                                names: outcome.waiting)
                        .accessibilityIdentifier("importWaitingLine")
                }
                if !outcome.alreadyListed.isEmpty {
                    if !outcome.added.isEmpty || !outcome.waiting.isEmpty { Hairline() }
                    outcomeLine(outcome.datesFilled.isEmpty
                                ? L10n.string("Already on your list: \(outcome.alreadyListed.count).")
                                : L10n.string("Already on your list: \(outcome.alreadyListed.count). Missing renewal dates were filled in from your receipts."),
                                names: outcome.alreadyListed)
                }
            }

            VStack(spacing: 10) {
                Button(action: { dismiss() }) { Text("Done") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("importDoneButton")
                if !outcome.waiting.isEmpty {
                    Button(action: { showingPaywall = true }) { Text("See Pausely Pro") }
                        .buttonStyle(.ink(.quiet))
                        .accessibilityIdentifier("importSeeProButton")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One subscription is named; several are counted.
    private func outcomeTitle(_ outcome: TallyImporter.Outcome) -> String {
        switch outcome.added.count {
        case 0: return L10n.string("Nothing new was added")
        case 1: return L10n.string("\(outcome.added[0]) is on your list")
        default: return L10n.string("\(outcome.added.count) added to your list")
        }
    }

    private func outcomeLine(_ sentence: String, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: sentence)
                .font(.body)
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: names.formatted(.list(type: .and).locale(L10n.locale)))
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    static func money(_ amount: Decimal, _ currency: String) -> String {
        MoneyFormat.string(amount, currency)
    }
}

// MARK: - One found subscription

private struct FoundRow: View {
    let found: FoundSubscription
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void
    let onReject: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var proven: ProvenSubscription { found.proven }

    private var badge: (text: String, state: MoneyState?)? {
        switch proven.status {
        case .priceIncreased: return (L10n.string("Price went up"), .decide)
        case .trial: return (L10n.string("Free trial"), .decide)
        case .likelyEnded: return (L10n.string("May have ended"), nil)
        case .cancelled: return (L10n.string("Cancelled"), nil)
        case .active: return proven.chargedAfterCancel ? (L10n.string("Charged after cancelling"), .due) : nil
        }
    }

    private var evidenceLine: String {
        let day: (Date) -> String = { $0.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale)) }
        if proven.status == .trial, let ends = proven.trialEndsOn { return L10n.string("Trial ends \(day(ends))") }
        if let last = proven.lastChargeDate.map(day) { return L10n.string("Last charged \(last)") }
        return L10n.string("Detected from your emails")
    }

    private var priceText: String? {
        found.priceUnknown ? nil : InboxImportView.money(found.amount, found.currency)
    }

    private var accessibilitySummary: String {
        var parts = [found.name]
        if let priceText { parts.append(priceText + " " + found.billingFrequency.billingPeriodLabel) }
        parts.append(evidenceLine)
        if let badge { parts.append(badge.text) }
        if !found.isCancelled { parts.append(isSelected ? L10n.string("selected") : L10n.string("not selected")) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    HStack(spacing: 12) {
                        if !found.isCancelled { checkbox }
                        ServiceLogoView(name: found.name, category: nil, size: 36)
                        if typeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 3) { nameAndEvidence; price }
                            Spacer(minLength: 0)
                        } else {
                            nameAndEvidence
                            Spacer(minLength: 8)
                            price
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(found.isCancelled)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint(found.isCancelled ? Text(verbatim: "") : Text("Double tap to select or deselect"))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

                Button(action: onExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkTextFaint)
                        .frame(width: Layout.tapTarget, height: Layout.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? Text("Hide why") : Text("Show why we think this is a subscription"))
            }
            .padding(.vertical, 10)

            if isExpanded { evidenceDetail }
        }
    }

    private var nameAndEvidence: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: found.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.leading)
            Text(verbatim: evidenceLine)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .multilineTextAlignment(.leading)
            if let badge {
                HStack(spacing: 6) {
                    if let state = badge.state { StateMark(state: state) }
                    Text(verbatim: badge.text)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(badge.state.map { $0 == .due ? Color.due : Color.decide } ?? Color.inkTextMuted)
                }
            }
        }
    }

    @ViewBuilder private var price: some View {
        if let priceText {
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 1) {
                Text(verbatim: priceText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                Text(verbatim: found.billingFrequency.billingPeriodLabel)
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
            }
        }
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.paper : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Color.clear : Color.inkTextFaint, lineWidth: 1.5)
                )
                .frame(width: 22, height: 22)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.paperInk)
            }
        }
        .accessibilityHidden(true)
    }

    /// Why Pausely thinks so, and the charges it read: the proof behind the line.
    private var evidenceDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(proven.reasons.enumerated()), id: \.offset) { _, reason in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "·").foregroundStyle(Color.inkTextFaint).accessibilityHidden(true)
                    Text(verbatim: reason)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !proven.evidence.isEmpty {
                VStack(spacing: 6) {
                    ForEach(proven.evidence.suffix(5).reversed()) { charge in
                        HStack {
                            Text(charge.date, format: .dateTime.month(.abbreviated).day().year())
                            Spacer(minLength: 8)
                            Text(verbatim: InboxImportView.money(charge.amount, charge.currency))
                        }
                        .font(.proof(.footnote))
                        .foregroundStyle(Color.inkTextMuted)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 2)
            }
            if !found.isCancelled {
                Button(action: onReject) {
                    Text("This isn't a subscription")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(minHeight: Layout.tapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Removes it and Pausely will remember, so it won't appear again")
                .accessibilityIdentifier("notASubscriptionButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 46)
        .padding(.bottom, 12)
    }
}
