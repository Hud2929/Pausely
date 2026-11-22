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
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selected: Set<String> = []
    @State private var expanded: Set<String> = []
    @State private var didPreselect = false
    @State private var importing = false
    @State private var outcome: TallyImporter.Outcome?
    @State private var imapPreset: IMAPPreset?
    @State private var imapAddress = ""
    @State private var showingIMAP = false
    @State private var showingProviders = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if let outcome {
                        InboxOutcome(outcome: outcome, onDone: { dismiss() }, onSeePro: { showingPaywall = true })
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
                IMAPConnectView(preset: imapPreset, startAddress: imapAddress)
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
                StoreKitUpgradeView()
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
                ProblemLine(message: error, identifier: "inboxProblem")
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The promise: it is the reason someone would let an app near their inbox. Each sentence is held
    /// by a test (`InboxPrivacyTests`). It is set on ink between two hairlines, not on paper: paper
    /// is for money decided or proven, and a promise is neither.
    private var privacyNotice: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            VStack(alignment: .leading, spacing: 8) {
                Text("Your email never leaves your iPhone.")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Pausely connects straight to your email provider, reads receipts on this iPhone and keeps only the name, amount and date of each charge. It only reads: it never sends, changes or deletes email.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 16)
            Hairline()
        }
        .accessibilityElement(children: .combine)
    }

    /// Which inbox: the same list here and in "Add an inbox".
    private var providerButtons: some View {
        InboxProviderList(onChoose: { showingProviders = false }, onAppPassword: openIMAP)
    }

    private func openIMAP(_ preset: IMAPPreset?) {
        imapPreset = preset
        imapAddress = ""
        showingProviders = false
        showingIMAP = true
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
                        .transition(.arriving(.move(edge: .top)))
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

            // An inbox that lost its access is reconnected first: searching again repeats the failure.
            if let failed = scanner.accounts.first(where: { scanner.accountErrors[$0.id] != nil }) {
                Button { reconnect(failed) } label: { Text("Reconnect \(failed.address)") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("reconnectButton")
                Button(action: { Task { await scanner.scanAll() } }) { Text("Search again") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("scanInboxesButton")
            } else {
                Button(action: { Task { await scanner.scanAll() } }) {
                    scanner.accounts.contains { $0.lastScan != nil } ? Text("Search again") : Text("Find subscriptions")
                }
                .buttonStyle(.ink)
                .accessibilityIdentifier("scanInboxesButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Signs in again where it can; an app-password inbox gets its page with the address filled in.
    private func reconnect(_ account: MailboxAccount) {
        if account.kind == .imap {
            imapPreset = account.presetID.flatMap(IMAPPreset.find)
            imapAddress = account.address
            showingIMAP = true
        } else {
            Task { await scanner.reconnect(account) }
        }
    }

    private func accountRow(_ account: MailboxAccount) -> some View {
        let failed = scanner.accountErrors[account.id] != nil
        let mark = Image(systemName: failed ? "exclamationmark.circle" : "envelope")
            .font(.body)
            .foregroundStyle(failed ? Color.due : Color.inkTextMuted)
            .accessibilityHidden(true)
        let words = VStack(alignment: .leading, spacing: 2) {
            // Whole, on as many lines as it needs: cut in the middle, two addresses at one
            // provider could not be told apart.
            Text(verbatim: AddressText.breakable(account.address))
                .font(.body.weight(.medium))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: account.address))
            Facts(accountDetail(account))
                .font(.subheadline)
                .foregroundStyle(failed ? Color.due : Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        let options = Menu {
            if failed {
                Button { reconnect(account) } label: { Label("Reconnect", systemImage: "arrow.clockwise") }
                    .accessibilityIdentifier("reconnectInbox")
            }
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

        return Group {
            if MarkPlacement.sitsAbove(largeText: typeSize.isAccessibilitySize) {
                // The mark and the options share a line and the address has the row: between
                // them at the largest text size it had half, the envelope lay over its first
                // letters, and "longer-company-name" was cut wherever the line ran out.
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        mark
                        Spacer(minLength: 8)
                        options
                    }
                    words
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    mark.frame(width: 28)
                    words
                    Spacer(minLength: 8)
                    options
                }
            }
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
    private var chosen: [FoundSubscription] {
        scanner.foundSubscriptions.filter { selected.contains($0.id) && !$0.isCancelled && !isOnList($0) }
    }

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
        selected = Set(live.filter { $0.proven.tier == .confirmed && !isOnList($0) }.map(\.id))
    }

    /// Already in the person's list, by the importer's own rule (the same name, any case).
    private func isOnList(_ found: FoundSubscription) -> Bool {
        store.subscriptions.contains { $0.name.caseInsensitiveCompare(found.name) == .orderedSame }
    }

    /// What the search found: the total first, then how it was worked out.
    private func summary(count: Int) -> some View {
        let currency = CurrencyManager.shared.selectedCurrency
        let monthly = scanner.report?.monthlyTotal(in: currency) ?? 0
        // Receipts in another currency are added at an exchange rate, and the total says so.
        let converted = scanner.report?.monthlyTotalIsConverted(to: currency) ?? false
        let ignored = scanner.stats.purchasesIgnored
        let stats = scanner.stats

        return VStack(alignment: .leading, spacing: 16) {
            Text("We found \(count) subscriptions")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            // Still said before the tap: under the heading, where it is read on arrival.
            if Self.barHoldsOnlyTheButton(largeText: typeSize.isAccessibilitySize) { freeLimitNote }

            PaperSlip(tornTop: true, tornBottom: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ProofLine(label: L10n.string("Each month"), value: MoneyFormat.total(monthly, currency, converted: converted), emphasised: true)
                    ProofLine(label: L10n.string("Each year"), value: MoneyFormat.total(monthly * 12, currency, converted: converted))
                    if ignored > 0 || stats.emailsChecked > 0 { Perforation() }
                    if stats.emailsChecked > 0 {
                        Facts(L10n.string("Emails checked: \(stats.emailsChecked) · read in full: \(stats.bodiesRead) · all on your phone"))
                            .font(.proof(.caption))
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if ignored > 0 {
                        Text("Other senders with charges that didn't look like subscriptions: \(ignored)")
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

    /// The widest price among everything found, in every section: one price column for the page.
    private var widestPrice: FoundRow.Price? {
        FoundRow.widestPrice(among: scanner.foundSubscriptions.filter { !$0.priceUnknown }.map {
            FoundRow.Price(amount: Self.money($0.amount, $0.currency), period: $0.billingFrequency.billingPeriodLabel)
        })
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
                            .tapArea(.trailing)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, found in
                    if index > 0 { Hairline() }
                    FoundRow(
                        found: found,
                        widestPrice: widestPrice,
                        isOnList: isOnList(found),
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
        payments.isUnlocked(.unlimitedSubscriptions) ? nil : FreeTier.room(in: store.subscriptions)
    }

    /// The chosen ones that aren't on the list already: the ones the free limit applies to.
    private var newlyChosen: Int {
        let listed = Set(store.subscriptions.map { $0.name.lowercased() })
        return chosen.filter { !listed.contains($0.name.lowercased()) }.count
    }

    /// Whether the bar at the bottom edge holds only "Add to my list", with the free-limit note
    /// under the heading instead. At the accessibility text sizes, yes: the note (six lines) and
    /// a button of two lines took most of the screen and left one line of what was found.
    nonisolated static func barHoldsOnlyTheButton(largeText: Bool) -> Bool { largeText }

    /// What the free limit will do with this choice. Said before the tap, not discovered after it.
    @ViewBuilder
    private var freeLimitNote: some View {
        if !chosen.isEmpty, let slots = freeSlots, newlyChosen > slots {
            Text(slots == 0
                 ? L10n.string("Free tracks \(FreeTier.subscriptionLimit) and your list is full. What you add now will wait until you make room or go Pro.")
                 : L10n.string("Free tracks \(FreeTier.subscriptionLimit). Added now, most expensive first: \(slots). Waiting until you make room or go Pro: \(newlyChosen - slots)."))
                .font(.footnote)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("freeLimitNote")
        }
    }

    @ViewBuilder
    private var addBar: some View {
        if outcome == nil, !scanner.isScanning, !scanner.foundSubscriptions.isEmpty, scanner.hasAccounts, !chosen.isEmpty {
            VStack(spacing: 8) {
                if !Self.barHoldsOnlyTheButton(largeText: typeSize.isAccessibilitySize) { freeLimitNote }
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
        // The landing is felt when something landed: nothing is, when every one was already listed
        // or is waiting for room.
        if !result.added.isEmpty || !result.datesFilled.isEmpty { Feel.landed() }
    }

    static func money(_ amount: Decimal, _ currency: String) -> String {
        MoneyFormat.string(amount, currency)
    }
}
