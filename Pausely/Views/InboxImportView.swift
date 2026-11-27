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
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selected: Set<String> = []
    @State private var expanded: Set<String> = []
    @State private var didPreselect = false
    @State private var importing = false
    @State private var outcome: TallyImporter.Outcome?
    @State private var imapPreset: IMAPPreset?
    @State private var imapAddress = ""
    @State private var pendingIMAP: (preset: IMAPPreset?, address: String)?
    @State private var pendingOAuth: MailboxKind?
    @State private var showingIMAP = false
    @State private var showingProviders = false
    @State private var showingPaywall = false
    /// The finding last hidden with "This isn't a subscription", until it is undone or another is hidden.
    @State private var hidden: Hidden?
    /// Where the page should scroll next ("top", or a row's "why").
    @State private var scrollTarget: String?
    /// A listed subscription as it was before the receipts' price or date was put on it, until undone.
    @State private var listingBefore: Subscription?
    /// The inbox just disconnected, said at the top until something else happens: the page went back to its
    /// first state with nothing to confirm it (the rating of 2026-11-23).
    @State private var disconnected: String?
    /// A sender to add by hand, from the other senders or from a search that found nothing.
    @State private var addingByHand: ByHand?
    /// What "Done" after adding does when the page was opened from another sheet: the outcome names Home,
    /// and "Done" from the catalog landed on the catalog (the rating of 2026-11-23).
    private let onFinished: (() -> Void)?

    init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }

    private struct ByHand: Identifiable {
        let name: String
        var id: String { name }
    }

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
                    if let disconnected, outcome == nil, !scanner.isScanning {
                        Label {
                            Text(verbatim: L10n.string("\(AddressText.breakable(disconnected)) is disconnected."))
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: { Image(systemName: "checkmark.circle") }
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(verbatim: L10n.string("\(disconnected) is disconnected.")))
                            .accessibilityIdentifier("disconnectedNote")
                    }
                    if let outcome {
                        InboxOutcome(outcome: outcome, list: store.subscriptions,
                                     onDone: { if let onFinished { onFinished() } else { dismiss() } },
                                     onSeePro: { showingPaywall = true })
                    } else if !scanner.hasAccounts {
                        connectSection
                    } else if scanner.isScanning {
                        SearchingSection(scanner: scanner)
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
            // its top when the last inbox goes (it opened scrolled, its heading cut off) (2026-11-22). At the
            // largest text a "why" is taller than the screen: its row goes to the top instead, or the reader
            // landed on its last charges (the reach rating of 2026-11-23).
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                // An opened "why" moves only as far as it must to be seen: aligned to the bottom, a row that fitted
                // jumped 203 points under the finger (the rating of 2026-11-23).
                let top = target == "top" || target.hasPrefix("row-")
                withAnimation(Motion.unlessReduced(Motion.arrive)) { page.scrollTo(target, anchor: top ? .top : nil) }
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
            .sheet(isPresented: $showingProviders, onDismiss: {
                if let pending = pendingIMAP {
                    pendingIMAP = nil
                    imapPreset = pending.preset; imapAddress = pending.address; showingIMAP = true
                } else if let oauth = pendingOAuth {
                    pendingOAuth = nil
                    Task { if oauth == .gmail { await scanner.connectGmail() } else { await scanner.connectMicrosoft() } }
                }
            }) {
                ProviderSheet(onChoose: { showingProviders = false }, onAppPassword: openIMAP,
                              onOAuth: { pendingOAuth = $0; showingProviders = false },
                              onCancel: { showingProviders = false })
            }
            .sheet(isPresented: $showingPaywall) {
                StoreKitUpgradeView(context: Self.paywallContext(
                    waiting: TallyImporter.waitingLines(),
                    existingChargingCount: store.subscriptions.charging.count,
                    displayCurrency: currencyManager.selectedCurrency
                )) {
                    if let current = outcome {
                        outcome = ScreenshotImportSupport.promotedOutcome(current)
                    }
                }
            }
            .sheet(item: $addingByHand) { AddSubscriptionView(startName: $0.name) }
        }
        .onAppear { scanner.showSaved() }
        // Only the person's own ticks are kept: the clearing a new search does is not a choice.
        .onChange(of: selected) { _, now in if didPreselect, !scanner.isScanning { scanner.savedSelection = now } }
        // On iPad a page, with the reading column inside it: from Home, the catalog and Profile it was a
        // 580 by 640 box, and opened by itself it ran edge to edge (the reach rating of 2026-11-22).
        .presentationSizing(.page)
        // Connecting is the request to search: a new inbox is searched at once, without a second tap.
        .onChange(of: scanner.accounts.count) { before, after in
            // An Undo from before stays with what it was about: it sat over the next search and the first page.
            hidden = nil
            listingBefore = nil
            if after == 0, before > 0 { scrollTarget = "top" }
            if after > before { disconnected = nil }
            guard after > before else { return }
            outcome = nil
            Task { await scanner.scanAll() }
        }
        .onChange(of: scanner.isScanning) { _, scanning in
            if scanning { didPreselect = false; selected = []; expanded = []; hidden = nil; listingBefore = nil; disconnected = nil }
            // A search that couldn't reach an inbox is said aloud as well as shown (VoiceOver users heard nothing).
            if !scanning, let problem = scanner.accounts.lazy.compactMap({ scanner.accountErrors[$0.id] }).first {
                AccessibilityNotification.Announcement(problem).post()
            }
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

            // At the accessibility text sizes the inboxes come first: after the promise, the first one was
            // five screens down (the reach rating of 2026-11-23). The promise follows them, before any sign-in.
            if Self.inboxesFirst(largeText: typeSize.isAccessibilitySize) {
                providerButtons.padding(.top, 16)
                InboxPrivacyNote().padding(.top, 24)
            } else {
                InboxPrivacyNote().padding(.top, 24)
                providerButtons.padding(.top, 16)
            }

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
        if showingProviders {
            pendingIMAP = (preset, "")
            showingProviders = false
        } else {
            imapPreset = preset
            imapAddress = ""
            showingIMAP = true
        }
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

            // At the accessibility text sizes what to do comes before the inboxes: after them it was a screen
            // and a half down (the reach rating of 2026-11-23).
            if !typeSize.isAccessibilitySize { inboxRows(showsAdd: !offersAnotherInbox) }
            connectedActions
            if typeSize.isAccessibilitySize { inboxRows(showsAdd: !offersAnotherInbox) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What to do next with the inboxes connected and nothing on screen to add.
    @ViewBuilder
    private var connectedActions: some View {
        // An inbox that lost its access is reconnected first: searching again repeats the failure.
        if let failed = scanner.accounts.first(where: { scanner.accountErrors[$0.id] != nil }) {
            // The address breaks only after "@", "." and "-": at the largest size it broke mid-word,
            // with a hyphen that isn't in it (the reach rating of 2026-11-22).
            Button { reconnect(failed) } label: { Text(verbatim: L10n.string("Reconnect \(AddressText.breakable(failed.address))")) }
                .buttonStyle(.ink)
                // Read with the plain address: the break marks between its letters went to VoiceOver too.
                .accessibilityLabel(Text(verbatim: L10n.string("Reconnect \(failed.address)")))
                .accessibilityIdentifier("reconnectButton")
            Button(action: { Task { await scanner.scanAll() } }) { Text("Search again") }
                .buttonStyle(.ink(.quiet))
                .accessibilityIdentifier("scanInboxesButton")
        } else if offersAnotherInbox {
            // Nothing found in what was searched: the way forward is another inbox, or the list by hand,
            // which the words above say; searching the same mail again finds the same nothing (the
            // ratings of 2026-11-22 and 11-23).
            Button(action: { showingProviders = true }) { Text("Add another inbox") }
                .buttonStyle(.ink)
                .accessibilityIdentifier("addInboxMainButton")
            Button(action: { Task { await scanner.scanAll() } }) { Text("Search again") }
                .buttonStyle(.ink(.quiet))
                .accessibilityIdentifier("scanInboxesButton")
            Button(action: { addingByHand = ByHand(name: "") }) {
                Text("Add a subscription by hand")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .tapArea(.leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addByHandButton")
        } else {
            Button(action: { Task { await scanner.scanAll() } }) {
                scanner.accounts.contains { $0.lastScan != nil } ? Text("Search again") : Text("Find subscriptions")
            }
            .buttonStyle(.ink)
            .accessibilityIdentifier("scanInboxesButton")
        }
    }

    /// Whether the kinds of inbox come before the privacy promise on the first page: at the accessibility
    /// text sizes, where the promise alone is several screens.
    nonisolated static func inboxesFirst(largeText: Bool) -> Bool { largeText }

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

    /// Each connected inbox with its menu, then the way to add another (left out where the page's main button
    /// is that: "Add another inbox" was there twice, one above the other, the ratings of 2026-11-23).
    private func inboxRows(showsAdd: Bool = true) -> some View {
        InboxRows(scanner: scanner, showsAdd: showsAdd, onReconnect: reconnect, onAdd: { showingProviders = true },
                  onDisconnected: { address in
                      disconnected = address
                      AccessibilityNotification.Announcement(L10n.string("\(address) is disconnected.")).post()
                  })
    }

    /// The search found nothing in the inboxes it read: the way forward is another inbox.
    private var offersAnotherInbox: Bool {
        !scanner.accounts.contains { scanner.accountErrors[$0.id] != nil }
            && scanner.accounts.contains { $0.lastScan != nil } && !scanner.stats.stopped
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
            let failedAccounts = scanner.accounts.filter { scanner.accountErrors[$0.id] != nil }
            if !failedAccounts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(failedAccounts) { failed in
                        if let problem = scanner.accountErrors[failed.id] {
                            VStack(alignment: .leading, spacing: 4) {
                                ProblemLine(message: L10n.string("\(failed.address) couldn't be searched: \(problem) What's below is from earlier searches."),
                                            identifier: "searchFailedNote")
                                Button { reconnect(failed) } label: {
                                    Text("Reconnect").font(.subheadline.weight(.semibold)).foregroundStyle(Color.inkText).tapArea(.leading)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(verbatim: L10n.string("Reconnect \(failed.address)")))
                            }
                        }
                    }
                }
            }
            summary(count: live.count)
            // At the accessibility text sizes what was found comes first: under the insights, the first row
            // was 4,900 points down (the reach rating of 2026-11-23).
            if !typeSize.isAccessibilitySize { insights }
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
            if typeSize.isAccessibilitySize { insights }
            if !scanner.hiddenFindings.isEmpty {
                HiddenList(findings: scanner.hiddenFindings) { found in
                    withAnimation(Motion.unlessReduced(Motion.arrive)) {
                        scanner.undoNotSubscription(found, previous: nil)
                        if hidden?.found.id == found.id { hidden = nil }
                        // Shown again, it is a subscription after all: it came back unticked (2026-11-23).
                        if found.isLive, !isOnList(found), !isWaiting(found) { selected.insert(found.id) }
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
                inboxRows()
                if !scanner.stats.stopped { searchAgainButton.padding(.top, 8) }
            }
        }
        .onAppear(perform: preselectConfirmed)
    }

    private var searchAgainButton: some View {
        Button(action: { Task { await scanner.scanAll() } }) { Text("Search again") }
            .buttonStyle(.ink(.quiet))
            .accessibilityIdentifier("scanInboxesButton")
    }

    private func preselectConfirmed() {
        guard !didPreselect else { return }
        didPreselect = true
        if let saved = scanner.savedSelection { selected = saved; return }
        selected = Set(live.filter { $0.proven.tier == .confirmed && !isOnList($0) && !isWaiting($0) }.map(\.id))
    }

    /// Already charging on the person's list, by the importer's own rule (cancelled entries never block re-adding).
    private func isOnList(_ found: FoundSubscription) -> Bool {
        store.subscriptions.charging.contains { ServiceName.same($0.name, found.name) }
    }

    private var insights: some View {
        FoundInsights(insights: Array((scanner.report?.insights ?? []).prefix(4)))
    }

    /// What the search found: the total first, then how it was worked out.
    private func summary(count: Int) -> some View {
        let currency = currencyManager.selectedCurrency
        // The total follows the ticks and says so: it counted rows nobody ticked and changed after adding
        // (the ratings of 2026-11-22). With nothing ticked it is everything found that isn't listed yet.
        let picked = chosen
        let base = picked.isEmpty ? live.filter { !isOnList($0) } : picked
        let (monthly, converted) = Self.slipTotal(base, in: currency, rates: currencyManager.rates)
        let ignored = scanner.stats.purchasesIgnored
        let stats = scanner.stats

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("We found \(count) subscriptions")
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                // The count is what still charges; the rest are said, not left to be counted against it ("We
                // found 20" stood over 22 rows, the rating of 2026-11-23).
                let over = scanner.foundSubscriptions.count - count
                if over > 0 {
                    Text("And \(over) that ended or were cancelled, at the end of the list.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Still said before the tap: under the heading, where it is read on arrival.
            if Self.barHoldsOnlyTheButton(largeText: typeSize.isAccessibilitySize) { freeLimitNote }

            PaperSlip(tornTop: true, tornBottom: true) {
                VStack(alignment: .leading, spacing: 10) {
                    // Says what it sums: "For everything found" stood over only the rows not yet listed (2026-11-22).
                    Text(verbatim: !picked.isEmpty ? L10n.string("For the \(picked.count) you've ticked")
                                   : base.isEmpty ? L10n.string("Everything found is already on your list")
                                   : base.count < live.count ? L10n.string("For the \(base.count) not on your list yet")
                                   : L10n.string("For everything found"))
                        .font(.proof(.caption))
                        .foregroundStyle(Color.paperMuted)
                    ProofLine(label: L10n.string("Each month"), value: MoneyFormat.total(monthly, currency, converted: converted), emphasised: true)
                    ProofLine(label: L10n.string("Each year"), value: MoneyFormat.total(monthly * 12, currency, converted: converted))
                    // Which currency a converted total is in: a bare "$" stood beside "US$" rows (2026-11-23).
                    if converted {
                        Text("≈ converted to \(MoneyFormat.normalizedCode(currency))")
                            .font(.proof(.caption))
                            .foregroundStyle(Color.paperMuted)
                    }
                    SearchFacts(stats: stats)
                }
            }
            .accessibilityElement(children: .combine)

            // Beside the note that asks for it: at the bottom of the page it was 3,000 points away (2026-11-23).
            if stats.stopped { searchAgainButton }

            if live.contains(where: { $0.proven.currencyAssumed }) {
                DollarNote(code: scanner.assumedDollar, onChoose: scanner.setAssumedDollar)
            }
            if ignored > 0 {
                OtherSenders(count: ignored, names: scanner.report?.ignoredSenders ?? []) { addingByHand = ByHand(name: $0) }
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
                // The heading and its line are read together, then "Select all": in Arabic the button came
                // between them (the reach rating of 2026-11-23).
                .accessibilityElement(children: .contain)
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
                        keptForLater: keptForLater(found),
                        listed: store.subscriptions.charging.first { ServiceName.same($0.name, found.name) },
                        onUseReceipts: { Task { await useReceipts(found) } },
                        isSelected: selected.contains(found.id),
                        isExpanded: expanded.contains(found.id),
                        onToggle: { if selected.contains(found.id) { selected.remove(found.id) } else { selected.insert(found.id) } },
                        onExpand: {
                            withAnimation(Motion.unlessReduced(Motion.touch)) {
                                if expanded.contains(found.id) { expanded.remove(found.id) } else { expanded.insert(found.id) }
                            }
                            if expanded.contains(found.id) {
                                let target = typeSize.isAccessibilitySize ? "row-\(found.id)" : "why-\(found.id)"
                                Task { try? await Task.sleep(for: .milliseconds(250)); scrollTarget = target }
                            }
                        },
                        onReject: {
                            let wasSelected = selected.remove(found.id) != nil
                            withAnimation(Motion.unlessReduced(Motion.leave)) {
                                listingBefore = nil
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

    /// The chosen ones that aren't charging on the list already: the ones the free limit applies to.
    private var newlyChosen: Int {
        chosen.filter { found in !store.subscriptions.charging.contains { ServiceName.same($0.name, found.name) } }.count
    }

    /// Whether the bar at the bottom edge holds only "Add to my list", with the free-limit note
    /// under the heading instead. At the accessibility text sizes, yes: the note (six lines) and
    /// a button of two lines took most of the screen and left one line of what was found.
    nonisolated static func barHoldsOnlyTheButton(largeText: Bool) -> Bool { largeText }

    /// Kept for later from an earlier add while the free list has no room: shown, not offered. With room it
    /// is a choice again: two waited while the freed place went to the next add (the rating of 2026-11-23).
    private func isWaiting(_ found: FoundSubscription) -> Bool {
        freeSlots == 0 && keptForLater(found)
    }

    /// Kept for when there's room, from an earlier add.
    private func keptForLater(_ found: FoundSubscription) -> Bool {
        TallyImporter.waitingLines().contains { ServiceName.same($0.name, found.name) }
    }

    /// What the free limit will do with this choice. Said before the tap, not discovered after it.
    @ViewBuilder
    private var freeLimitNote: some View {
        if !chosen.isEmpty, let slots = freeSlots, newlyChosen > slots {
            // By name, in the importer's own order: a count left the person to guess which (2026-11-22).
            let split = Self.freeLimitSplit(chosen, existing: store.subscriptions.charging.map(\.name), slots: slots,
                                            in: currencyManager.selectedCurrency, rates: currencyManager.rates)
            Text(slots == 0
                 // What happens to what waits, as it happens: Home offers it when a place is free (2026-11-23).
                 ? L10n.string("The free plan tracks \(FreeTier.subscriptionLimit) and your list is full. What you add now waits, and Home offers it when there's room.")
                 : L10n.string("The free plan tracks \(FreeTier.subscriptionLimit). Added now, most expensive first: \(Self.names(split.add))."))
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
        if canAdd || (outcome == nil && (hidden != nil || listingBefore != nil)) {
            VStack(spacing: 8) {
                // Undo where the eye is: at the top of the page it was 2,200 points from the row that was
                // hidden (the rating of 2026-11-22). A listing changed from the receipts can be put back too:
                // the price changed with no way back (the rating of 2026-11-23).
                if let hidden {
                    HiddenNote(name: hidden.found.name, onUndo: undoHide)
                } else if let listingBefore {
                    UndoNote(message: Text("\(listingBefore.name) on your list was updated from your receipts."),
                             undoLabel: Text("Undo the change to \(listingBefore.name)"), identifier: "undoListingUpdate") {
                        Task { await undoListingUpdate() }
                    }
                }
                if canAdd {
                    if !Self.barHoldsOnlyTheButton(largeText: typeSize.isAccessibilitySize) { freeLimitNote }
                    Button(action: { Task { await addChosen() } }) {
                        if importing { Busy(Text("Adding…")) }
                        // Short, so at the largest text it is two lines, not three: the note says what "later" is.
                        else if freeSlots == 0 { Text("Keep \(chosen.count) for later") }
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

    /// The receipts' price, and their renewal day where the list has none, on the listed subscription: only
    /// when the person asks, and with the way back.
    private func useReceipts(_ found: FoundSubscription) async {
        guard let listed = store.subscriptions.charging.first(where: { ServiceName.same($0.name, found.name) }) else { return }
        let updated = FoundRow.updatedFromReceipts(listed, by: found)
        guard updated != listed else { return }
        await store.updateSubscription(updated)
        withAnimation(Motion.unlessReduced(Motion.arrive)) { hidden = nil; listingBefore = listed }
        Feel.landed()
    }

    private func undoListingUpdate() async {
        guard let before = listingBefore else { return }
        await store.updateSubscription(before)
        withAnimation(Motion.unlessReduced(Motion.leave)) { listingBefore = nil }
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
        // The outcome starts at its title: at the largest text it opened at its end (the reach rating of 2026-11-23).
        scrollTarget = "top"
        // The landing is felt when something landed: nothing is, when every one was already listed
        // or is waiting for room.
        if !result.added.isEmpty || !result.datesFilled.isEmpty { Feel.landed() }
    }

}
