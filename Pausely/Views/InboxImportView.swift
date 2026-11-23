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
    /// The inbox whose Disconnect waits for a yes: it signs out and forgets what was found there.
    @State private var disconnecting: MailboxAccount?
    /// The finding last hidden with "This isn't a subscription", until it is undone or another is hidden.
    @State private var hidden: Hidden?
    /// Where the page should scroll next ("top", or a row's "why").
    @State private var scrollTarget: String?

    private struct Hidden {
        let found: FoundSubscription
        let previous: UserVerdict?
        let wasSelected: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { page in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 0).id("top")
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
            // The phone's reading width on iPad, its margins still scrolling the page (ReadableScroll).
            .readableScroll()
            // An opened "why" is brought into view (its last line was under the bar), and the page is back at
            // its top when the last inbox goes (it opened scrolled, its heading cut off) (2026-11-22).
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(Motion.unlessReduced(Motion.arrive)) { page.scrollTo(target, anchor: target == "top" ? .top : .bottom) }
                scrollTarget = nil
            }
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
                    // On iPad a form sheet squeezed the steps and fields into a small box (B1).
                    .presentationSizing(.page)
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
        .onAppear { scanner.showSaved() }
        // Only the person's own ticks are kept: the clearing a new search does is not a choice.
        .onChange(of: selected) { _, now in if didPreselect, !scanner.isScanning { scanner.savedSelection = now } }
        // On iPad a page, with the reading column inside it: from Home, the catalog and Profile it was a
        // 580 by 640 box, and opened by itself it ran edge to edge (the reach rating of 2026-11-22).
        .presentationSizing(.page)
        // Connecting is the request to search: a new inbox is searched at once, without a second tap.
        .onChange(of: scanner.accounts.count) { before, after in
            if after == 0, before > 0 { scrollTarget = "top" }
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

            InboxPrivacyNote().padding(.top, 24)

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
                if let minutes = scanner.minutesLeft {
                    Text("About \(minutes) min left. Keep Pausely open until it finishes.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("scanTimeLeft")
                }
            }

            if !scanner.receiptsSeen.isEmpty {
                ReceiptsSeenSlip(receipts: scanner.receiptsSeen)
            }

            Button(action: { scanner.cancelScan() }) { Text("Stop and show what's found") }
                .buttonStyle(.ink(.quiet))
                .accessibilityIdentifier("stopScanButton")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }


    // MARK: - Connected, nothing to show

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // A heading of its own when no outcome is said: the page had none for VoiceOver to find.
            if scanner.error == nil {
                Text("Your inboxes")
                    .font(.question(.title2))
                    .foregroundStyle(Color.inkText)
                    .accessibilityAddTraits(.isHeader)
            }
            if let message = scanner.error {
                SearchOutcome(message: message, stats: scanner.stats, explains: scanner.accountErrors.isEmpty)
            }

            inboxRows

            // An inbox that lost its access is reconnected first: searching again repeats the failure.
            if let failed = scanner.accounts.first(where: { scanner.accountErrors[$0.id] != nil }) {
                // The address breaks only after "@", "." and "-": at the largest size it broke mid-word,
                // with a hyphen that isn't in it (the reach rating of 2026-11-22).
                Button { reconnect(failed) } label: { Text(verbatim: L10n.string("Reconnect \(AddressText.breakable(failed.address))")) }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("reconnectButton")
                Button(action: { Task { await scanner.scanAll() } }) { Text("Search again") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("scanInboxesButton")
            } else if scanner.report != nil, !scanner.stats.stopped {
                // Nothing found in what was searched: the way forward is another inbox, which the words
                // above say; searching the same mail again finds the same nothing (the rating of 2026-11-22).
                Button(action: { showingProviders = true }) { Text("Add another inbox") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("addInboxMainButton")
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
                disconnecting = account
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
        // One stop for VoiceOver, with what the menu does as its actions: the address, its state and
        // "Options for …" were three stops (the reach rating of 2026-11-22).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(account.address), \(accountDetail(account))"))
        .accessibilityActions {
            if failed { Button("Reconnect") { reconnect(account) } }
            Button("Disconnect") { disconnecting = account }
        }
        .accessibilityIdentifier("inboxRow")
        .asksFirst(Text("Disconnect \(account.address)?"),
                   isPresented: Binding(get: { disconnecting?.id == account.id }, set: { if !$0 { disconnecting = nil } }),
                   message: Text("Pausely signs out of this inbox and forgets what it found there. Subscriptions you added stay on your list.")) {
            Button("Disconnect", role: .destructive) { Task { await scanner.disconnect(account) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func accountDetail(_ account: MailboxAccount) -> String {
        if let error = scanner.accountErrors[account.id] { return error }
        if let last = account.lastScan {
            return L10n.string("\(account.providerName) · searched \(last.formatted(.relative(presentation: .named).locale(L10n.locale)))")
        }
        return account.providerName
    }

    /// Each connected inbox with its menu, then the way to add another.
    private var inboxRows: some View {
        VStack(spacing: 0) {
            ForEach(scanner.accounts) { account in
                // "searched 2 seconds ago" stood for minutes: the row is drawn again as time passes.
                TimelineView(.periodic(from: .now, by: 15)) { _ in accountRow(account) }
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
    }

    // MARK: - Results

    private var live: [FoundSubscription] { scanner.foundSubscriptions.filter(\.isLive) }
    private var chosen: [FoundSubscription] {
        scanner.foundSubscriptions.filter { selected.contains($0.id) && !$0.isCancelled && !isOnList($0) && !isWaiting($0) }
    }

    private var resultsSection: some View {
        let confirmed = live.filter { $0.proven.tier == .confirmed }
        let worthALook = live.filter { $0.proven.tier != .confirmed }
        let ended = scanner.foundSubscriptions.filter { $0.proven.status == .likelyEnded }
        let cancelled = scanner.foundSubscriptions.filter(\.isCancelled)

        return VStack(spacing: 28) {
            summary(count: live.count)
            FoundInsights(insights: Array((scanner.report?.insights ?? []).prefix(4)))
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
            if !scanner.hiddenFindings.isEmpty {
                HiddenList(findings: scanner.hiddenFindings) { found in
                    withAnimation(Motion.unlessReduced(Motion.arrive)) {
                        scanner.undoNotSubscription(found, previous: nil)
                        if hidden?.found.id == found.id { hidden = nil }
                    }
                }
            }
            // The inboxes stay in reach under what they found: the results page had no way to disconnect,
            // add another inbox or search again (2026-11-22).
            VStack(alignment: .leading, spacing: 6) {
                Text("Your inboxes")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .accessibilityAddTraits(.isHeader)
                inboxRows
                Button(action: { Task { await scanner.scanAll() } }) { Text("Search again") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("scanInboxesButton")
                    .padding(.top, 8)
            }
        }
        .onAppear(perform: preselectConfirmed)
    }

    private func preselectConfirmed() {
        guard !didPreselect else { return }
        didPreselect = true
        if let saved = scanner.savedSelection { selected = saved; return }
        selected = Set(live.filter { $0.proven.tier == .confirmed && !isOnList($0) && !isWaiting($0) }.map(\.id))
    }

    /// Already in the person's list, by the importer's own rule (the same name, any case).
    private func isOnList(_ found: FoundSubscription) -> Bool {
        store.subscriptions.contains { ServiceName.same($0.name, found.name) }
    }

    /// What the search found: the total first, then how it was worked out.
    private func summary(count: Int) -> some View {
        let currency = CurrencyManager.shared.selectedCurrency
        // The total follows the ticks and says so: it counted rows nobody ticked and changed after adding
        // (the ratings of 2026-11-22). With nothing ticked it is everything found that isn't listed yet.
        let picked = chosen
        let base = picked.isEmpty ? live.filter { !isOnList($0) } : picked
        let (monthly, converted) = Self.slipTotal(base, in: currency, rates: CurrencyManager.shared.rates)
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
                    // Says what it sums: "For everything found" stood over only the rows not yet listed (2026-11-22).
                    Text(verbatim: !picked.isEmpty ? L10n.string("For the \(picked.count) you've ticked")
                                   : base.count < live.count ? L10n.string("For the \(base.count) not on your list yet")
                                   : L10n.string("For everything found"))
                        .font(.proof(.caption))
                        .foregroundStyle(Color.paperMuted)
                    ProofLine(label: L10n.string("Each month"), value: MoneyFormat.total(monthly, currency, converted: converted), emphasised: true)
                    ProofLine(label: L10n.string("Each year"), value: MoneyFormat.total(monthly * 12, currency, converted: converted))
                    if stats.emailsChecked > 0 { Perforation() }
                    if stats.emailsChecked > 0 {
                        // A later search reads only new mail while the findings come from every search (T31).
                        Facts(stats.onlyNewMail
                              ? L10n.string("New emails since the last search: \(stats.emailsChecked) · read in full: \(stats.bodiesRead) · all on your phone")
                              : L10n.string("Emails checked: \(stats.emailsChecked) · read in full: \(stats.bodiesRead) · all on your phone"))
                            .font(.proof(.caption))
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // What was left unread is said, not left to be assumed (T4, T16).
                    if stats.stopped {
                        Text("Stopped early, so some emails weren't read. Search again to read them all.")
                            .font(.proof(.caption))
                            .foregroundStyle(Color.paperInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("searchStoppedNote")
                    } else if stats.capped {
                        Text("One search reads at most \(InboxSearchPlan.standardLimit) possible receipts, newest first; older ones weren't read.")
                            .font(.proof(.caption))
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            if live.contains(where: { $0.proven.currencyAssumed }) {
                DollarNote(code: scanner.assumedDollar, onChoose: scanner.setAssumedDollar)
            }
            if ignored > 0 {
                OtherSenders(count: ignored, names: scanner.report?.ignoredSenders ?? [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The widest price among everything found, in every section: one price column for the page.
    private var widestPrice: FoundRow.Price? {
        FoundRow.widestPrice(among: scanner.foundSubscriptions.filter { !$0.priceUnknown }.map {
            FoundRow.Price(amount: Self.money($0.amount, $0.currency), period: $0.billingFrequency.billingPeriodLabel)
        })
    }

    private func listSection(title: LocalizedStringKey, subtitle: LocalizedStringKey, items: [FoundSubscription]) -> some View {
        let selectable = items.filter { !$0.isCancelled && !isOnList($0) && !isWaiting($0) }
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
                // Over a single row its own box says it all.
                if selectable.count > 1 {
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
                        // A row waiting for room is not a choice: ticking it again did nothing (2026-11-22).
                        isOnList: isOnList(found) || isWaiting(found),
                        isWaiting: isWaiting(found),
                        listedPrice: FoundRow.listedPrice(store.subscriptions.first { ServiceName.same($0.name, found.name) }, for: found),
                        onUpdatePrice: { Task { await useFoundPrice(found) } },
                        isSelected: selected.contains(found.id),
                        isExpanded: expanded.contains(found.id),
                        onToggle: { if selected.contains(found.id) { selected.remove(found.id) } else { selected.insert(found.id) } },
                        onExpand: {
                            withAnimation(Motion.unlessReduced(Motion.touch)) {
                                if expanded.contains(found.id) { expanded.remove(found.id) } else { expanded.insert(found.id) }
                            }
                            if expanded.contains(found.id) {
                                Task { try? await Task.sleep(for: .milliseconds(250)); scrollTarget = "why-\(found.id)" }
                            }
                        },
                        onReject: {
                            let wasSelected = selected.remove(found.id) != nil
                            withAnimation(Motion.unlessReduced(Motion.leave)) {
                                hidden = Hidden(found: found, previous: scanner.markNotSubscription(found), wasSelected: wasSelected)
                            }
                            AccessibilityNotification.Announcement(L10n.string("\(found.name) hidden")).post()
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
        chosen.filter { found in !store.subscriptions.contains { ServiceName.same($0.name, found.name) } }.count
    }

    /// Whether the bar at the bottom edge holds only "Add to my list", with the free-limit note
    /// under the heading instead. At the accessibility text sizes, yes: the note (six lines) and
    /// a button of two lines took most of the screen and left one line of what was found.
    nonisolated static func barHoldsOnlyTheButton(largeText: Bool) -> Bool { largeText }

    /// Waiting for room on the free list, from an earlier add.
    private func isWaiting(_ found: FoundSubscription) -> Bool {
        TallyImporter.waitingLines().contains { ServiceName.same($0.name, found.name) }
    }

    /// What the free limit will do with this choice. Said before the tap, not discovered after it.
    @ViewBuilder
    private var freeLimitNote: some View {
        if !chosen.isEmpty, let slots = freeSlots, newlyChosen > slots {
            // By name, in the importer's own order: a count left the person to guess which (2026-11-22).
            let split = Self.freeLimitSplit(chosen, existing: store.subscriptions.map(\.name), slots: slots,
                                            in: CurrencyManager.shared.selectedCurrency, rates: CurrencyManager.shared.rates)
            Text(slots == 0
                 ? L10n.string("Free tracks \(FreeTier.subscriptionLimit) and your list is full. What you add now will wait until you make room or go Pro.")
                 : L10n.string("Free tracks \(FreeTier.subscriptionLimit). Added now, most expensive first: \(Self.names(split.add))."))
                .font(.footnote)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("freeLimitNote")
        }
    }

    @ViewBuilder
    private var addBar: some View {
        let canAdd = outcome == nil && !scanner.isScanning && !scanner.foundSubscriptions.isEmpty && scanner.hasAccounts && !chosen.isEmpty
        if canAdd || (outcome == nil && hidden != nil) {
            VStack(spacing: 8) {
                // Undo where the eye is: at the top of the page it was 2,200 points from the row that was
                // hidden (the rating of 2026-11-22).
                if let hidden {
                    HiddenNote(name: hidden.found.name, onUndo: undoHide)
                }
                if canAdd {
                    if !Self.barHoldsOnlyTheButton(largeText: typeSize.isAccessibilitySize) { freeLimitNote }
                    Button(action: { Task { await addChosen() } }) {
                        if importing { Busy(Text("Adding…")) }
                        else if freeSlots == 0 { Text("Keep \(chosen.count) for when there's room") }
                        else if let slots = freeSlots, newlyChosen > slots { Text("Add \(slots), keep \(newlyChosen - slots) waiting") }
                        else { Text("Add \(chosen.count) to my list") }
                    }
                    .buttonStyle(.ink)
                    .disabled(importing)
                    .accessibilityIdentifier("importSelectedButton")
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            // In the page's column on iPad, as the page is (ReadableScroll).
            .frame(maxWidth: ReadableWidth.maxWidth)
            .frame(maxWidth: .infinity)
            .background(Color.ink)
            .overlay(alignment: .top) { Hairline() }
        }
    }

    /// The receipts' price, period and currency on the listed subscription: only when the person asks.
    private func useFoundPrice(_ found: FoundSubscription) async {
        guard var listed = store.subscriptions.first(where: { ServiceName.same($0.name, found.name) }) else { return }
        listed.amount = found.proven.comingAmount ?? found.amount
        listed.currency = found.currency
        listed.billingFrequency = found.billingFrequency
        await store.updateSubscription(listed)
        Feel.landed()
    }

    private func undoHide() {
        guard let hidden else { return }
        withAnimation(Motion.unlessReduced(Motion.arrive)) {
            scanner.undoNotSubscription(hidden.found, previous: hidden.previous)
            if hidden.wasSelected { selected.insert(hidden.found.id) }
            self.hidden = nil
        }
    }

    private func addChosen() async {
        importing = true
        let result = await scanner.importSubscriptions(chosen)
        // The findings stay: reopened after Done, the page showed only the inbox, with no sign of what was
        // added or of the ones waiting for room (the rating of 2026-11-22).
        selected = []
        expanded = []
        didPreselect = false
        importing = false
        outcome = result
        // The landing is felt when something landed: nothing is, when every one was already listed
        // or is waiting for room.
        if !result.added.isEmpty || !result.datesFilled.isEmpty { Feel.landed() }
    }

}
