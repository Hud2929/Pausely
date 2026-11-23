import Foundation
import os.log
import UIKit

/// A subscription a search of the person's email found, as the results screen lists it.
struct FoundSubscription: Identifiable, Equatable {
    let proven: ProvenSubscription

    /// Stable across a re-analysis (merchant, period, currency), so what was ticked stays ticked. A currency
    /// that was only assumed is left out: choosing another dollar for "$" unticked every row it relabelled
    /// (the rating of 2026-11-23).
    var id: String {
        guard proven.currencyAssumed else { return proven.id }
        return proven.id.split(separator: "|").dropLast().joined(separator: "|") + "|$"
    }
    var name: String { proven.name }
    var amount: Decimal { proven.amount }
    var currency: String { proven.currency }
    var billingFrequency: BillingFrequency { proven.frequency }

    /// A cancellation email came after the last charge: shown, never offered for import.
    var isCancelled: Bool { proven.status == .cancelled }
    /// Still charging as far as the receipts show.
    var isLive: Bool { proven.status != .likelyEnded && proven.status != .cancelled }
    /// A trial whose email didn't say what it costs afterwards.
    var priceUnknown: Bool { proven.status == .trial && proven.amount == 0 }

    /// The line this becomes on the person's list. The anchor is the day of the last charge the receipts
    /// show (a real date the renewal schedule rolls forward), never a date worked out from it.
    var line: TallyLine {
        TallyLine(name: name, category: SubscriptionCategory.matching(proven.category).displayName,
                  // What the next renewal charges, when an email said so: the reminder is about that charge.
                  amount: proven.comingAmount ?? amount, currency: currency, isConfirmed: true, frequency: billingFrequency,
                  // No date for one that may have ended: its old charge would make Home promise a next one.
                  anchor: proven.status == .trial || proven.status == .likelyEnded ? nil : (proven.lastChargeDate ?? proven.nextBillingDate),
                  trialEndsAt: proven.status == .trial ? proven.trialEndsOn : nil)
    }
}

/// One receipt read during a search, shown while the search runs: who charged, how much, when.
struct ReceiptSeen: Identifiable, Equatable {
    var name: String
    var amount: Decimal
    var currency: String
    var date: Date
    var id: String { name.lowercased() }
}

/// Finds subscriptions in every connected inbox, on the iPhone. For each inbox: search (or only new mail),
/// read headers, open only the messages that look financial, parse them with the same MIME parser, and
/// keep a few facts per receipt. Email text never outlives a single message's processing, and nothing
/// is sent anywhere except to the mail provider itself.
@MainActor
final class InboxScanner: ObservableObject {
    static let shared = InboxScanner()

    @Published private(set) var accounts: [MailboxAccount] = []
    @Published private(set) var isScanning = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var statusLine = ""
    /// Minutes the running search still needs, from its own pace so far; nil until that is known. A
    /// first Gmail search is about six minutes on Google's quota for one person, and nothing said so.
    @Published private(set) var minutesLeft: Int?
    @Published var foundSubscriptions: [FoundSubscription] = []
    /// What was ticked on the results, kept on this iPhone: closing the page lost every tick (the rating of
    /// 2026-11-22), and a relaunch ticked eleven the person had unticked (11-23). Nil until the person has
    /// chosen; a new search starts over.
    static let selectionKey = "inbox_ticked"
    var savedSelection: Set<String>? {
        get { (UserDefaults.standard.array(forKey: Self.selectionKey) as? [String]).map(Set.init) }
        set {
            if let newValue { UserDefaults.standard.set(newValue.sorted(), forKey: Self.selectionKey) }
            else { UserDefaults.standard.removeObject(forKey: Self.selectionKey) }
        }
    }
    /// The dollar a receipt that says only "$" is taken as, when the person chose one.
    static let assumedDollarKey = "inbox_assumed_dollar"
    var assumedDollar: String {
        UserDefaults.standard.string(forKey: Self.assumedDollarKey)
            ?? DollarHint.assumed(readerCurrency: CurrencyManager.shared.selectedCurrency)
    }

    func setAssumedDollar(_ code: String) {
        UserDefaults.standard.set(code, forKey: Self.assumedDollarKey)
        reanalyze()
    }

    /// What the person said isn't a subscription, from the same facts, so it can be shown again later.
    @Published private(set) var hiddenFindings: [FoundSubscription] = []
    /// The latest receipt read for each sender during the running search, in the order the senders were first
    /// read: a line never moves once it is on the slip.
    @Published private(set) var receiptsSeen: [ReceiptSeen] = []
    @Published var report: IntelligenceReport?
    @Published var error: String?
    @Published private(set) var accountErrors: [String: String] = [:]
    @Published private(set) var stats = ScanStats()

    struct AccountStats: Equatable, Codable {
        var candidates = 0
        var checked = 0
        var read = 0
        var receipts = 0
        var incremental = false
        /// The search found as many possible receipts as one search reads; older ones were left.
        var capped = false
    }

    struct ScanStats: Equatable, Codable {
        var emailsChecked = 0
        var bodiesRead = 0
        var receipts = 0
        var aiAssisted = 0
        var purchasesIgnored = 0
        var confirmed = 0
        var perAccount: [String: AccountStats] = [:]
        /// The person stopped the search: what is shown is from what was read before that.
        var stopped = false
        var capped: Bool { perAccount.values.contains(where: \.capped) }
        /// Every inbox searched only mail newer than its last search.
        var onlyNewMail: Bool { !perAccount.isEmpty && perAccount.values.allSatisfy(\.incremental) }
    }

    /// What the last search read, kept with the facts it found: after a relaunch the slip lost its "Emails
    /// checked: 112 · read in full: 111" while the findings came back (the rating of 2026-11-23).
    static let lastSearchKey = "inbox_last_search"

    static func savedStats(defaults: UserDefaults = .standard) -> ScanStats? {
        defaults.data(forKey: lastSearchKey).flatMap { try? JSONDecoder().decode(ScanStats.self, from: $0) }
    }

    static func saveStats(_ stats: ScanStats?, defaults: UserDefaults = .standard) {
        if let stats, let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: lastSearchKey)
        } else {
            defaults.removeObject(forKey: lastSearchKey)
        }
    }

    /// Full messages read per inbox per scan, the most likely receipts first.
    nonisolated static let bodyBudget = 400
    /// How far back a first scan looks.
    static let lookback: TimeInterval = 2 * 365 * 86_400

    private let classifier: AmbiguousReceiptClassifier? = OnDeviceReceiptClassifier.makeIfAvailable()
    private var scanTask: Task<Void, Never>?

    private init() {
        migrateLegacyGmail()
        accounts = MailboxAccountStore.all()
    }

    var hasAccounts: Bool { !accounts.isEmpty }

    // MARK: - Connecting

    func connectGmail() async {
        await connect { try await GmailMailboxProvider.connect() }
    }

    func connectMicrosoft() async {
        await connect { try await MicrosoftGraphProvider.connect() }
    }

    /// Signs in again to an inbox whose access ended, in its own place: the new sign-in's tokens go to the
    /// same inbox, so its receipt facts stay with it, and a search follows. "Your sign-in expired.
    /// Reconnect this inbox." had nothing to reconnect with (both ratings of 2026-11-22). A sign-in to
    /// another address is simply another inbox.
    func reconnect(_ old: MailboxAccount, signIn: (() async throws -> MailboxAccount)? = nil) async {
        error = nil
        do {
            let fresh: MailboxAccount
            if let signIn {
                fresh = try await signIn()
            } else {
                switch old.kind {
                case .gmail: fresh = try await GmailMailboxProvider.connect()
                case .microsoft: fresh = try await MicrosoftGraphProvider.connect()
                case .imap: return  // an app password is given on its own page (`connectIMAP` reconnects in place)
                }
            }
            if fresh.id != old.id, fresh.kind == old.kind,
               fresh.address.caseInsensitiveCompare(old.address) == .orderedSame,
               let tokens = OAuthSession.load(for: fresh.id) {
                OAuthSession.store(tokens, for: old.id)
                MailboxAccountStore.remove(fresh.id)
            }
            accounts = MailboxAccountStore.all()
            accountErrors[old.id] = nil
            await scanAll()
        } catch MailboxError.cancelled {
            return
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Signs in to an IMAP server and keeps the account only if the sign-in and folder listing work.
    func connectIMAP(address: String, password: String, preset: IMAPPreset?, host customHost: String? = nil,
                     port customPort: Int? = nil) async throws -> MailboxAccount {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@"), trimmed.split(separator: "@").count == 2 else {
            throw MailboxError.notConfigured(L10n.string("Enter your full email address."))
        }
        let cleanPassword = IMAPPreset.cleanPassword(password, for: preset)
        guard !cleanPassword.isEmpty else { throw MailboxError.notConfigured(L10n.string("Enter the app password.")) }
        guard let host = (customHost?.isEmpty == false ? customHost : preset?.host)?.lowercased() else {
            throw MailboxError.notConfigured(L10n.string("Choose your email provider or enter its IMAP server."))
        }
        if let existing = accounts.first(where: { $0.address == trimmed && $0.kind == .imap }) {
            // An inbox whose sign-in stopped working takes the new password in its own place.
            guard accountErrors[existing.id] != nil else {
                throw MailboxError.notConfigured(L10n.string("\(existing.address) is already connected."))
            }
            let provider = makeProvider(existing, password: cleanPassword)
            try await provider.open()
            await provider.close()
            guard MailboxAccountStore.setSecret(cleanPassword, .password, for: existing.id) else {
                throw MailboxError.server(L10n.string("Couldn't save the password securely on this iPhone."))
            }
            accountErrors[existing.id] = nil
            Task { await scanAll() }
            return existing
        }

        let account = MailboxAccount(id: UUID().uuidString, kind: .imap, address: trimmed, presetID: preset?.id,
                                     host: host, port: customPort ?? 993, addedAt: Date())
        let provider = makeProvider(account, password: cleanPassword)
        try await provider.open()
        await provider.close()
        guard MailboxAccountStore.setSecret(cleanPassword, .password, for: account.id) else {
            throw MailboxError.server(L10n.string("Couldn't save the password securely on this iPhone."))
        }
        MailboxAccountStore.upsert(account)
        accounts = MailboxAccountStore.all()
        return account
    }

    /// Runs a provider's connect step and keeps the result (the first account wins if it was already connected).
    func connect(_ action: () async throws -> MailboxAccount) async {
        error = nil
        do {
            let account = try await action()
            accounts = MailboxAccountStore.all()
            if accounts.filter({ $0.address == account.address && $0.kind == account.kind }).count > 1 {
                MailboxAccountStore.remove(account.id)  // already connected: keep the first
                accounts = MailboxAccountStore.all()
            }
        } catch MailboxError.cancelled {
            return
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Disconnecting

    func disconnect(_ account: MailboxAccount) async {
        await stopScan()
        await makeProvider(account).revoke()
        MailboxAccountStore.remove(account.id)
        accounts = MailboxAccountStore.all()
        accountErrors[account.id] = nil
        _ = ReceiptLedger.removeSource(account.id, remainingAccounts: accounts.count)
        if accounts.isEmpty {
            ReceiptLedger.clear()
            UserCorrections.clear()
            hiddenFindings = []
            foundSubscriptions = []
            report = nil
            stats = ScanStats()
            Self.saveStats(nil)
            savedSelection = nil
        } else {
            reanalyze()
        }
    }

    /// Account deletion and sign-out: forget every inbox and every receipt fact.
    func disconnectAll() async {
        await stopScan()
        for account in accounts { await makeProvider(account).revoke() }
        MailboxAccountStore.removeAll()
        ReceiptLedger.clear()
        accounts = []
        UserCorrections.clear()
        hiddenFindings = []
        foundSubscriptions = []
        report = nil
        stats = ScanStats()
        Self.saveStats(nil)
        savedSelection = nil
        accountErrors = [:]
        #if DEBUG
        isShowingDemo = false
        #endif
    }

    // MARK: - Scanning

    func scanAll() async {
        guard !isScanning else { return }
        #if DEBUG
        // The demo's inbox is made up, so there is nothing to search: connecting it used to start
        // a search that wiped the demo's results, and the screen fell back to its first page.
        if isShowingDemo { return }
        #endif
        let task = Task { await runScan() }
        scanTask = task
        await task.value
        scanTask = nil
    }

    /// How many messages a search will open, projected from the share of the headers checked so far that
    /// looked like receipts, within the most one search reads.
    nonisolated static func projectedReads(wanted: Int, checked: Int, of total: Int) -> Int {
        guard checked > 0 else { return min(bodyBudget, max(1, total / 4)) }
        return min(bodyBudget, max(1, Int((Double(wanted) / Double(checked) * Double(total)).rounded())))
    }

    /// Whole minutes still needed at the pace so far, rounded up; nil under a minute.
    nonisolated static func minutesLeft(done: Int, total: Int, elapsed: TimeInterval) -> Int? {
        guard done > 0, total > done, elapsed > 0 else { return nil }
        let seconds = elapsed / Double(done) * Double(total - done)
        return seconds < 60 ? nil : Int((seconds / 60).rounded(.up))
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    /// Cancels a running scan and waits for it to stop, so nothing it saves lands after a disconnect.
    private func stopScan() async {
        guard let task = scanTask else { return }
        task.cancel()
        await task.value
    }

    private func runScan() async {
        isScanning = true
        progress = 0
        error = nil
        accountErrors = [:]
        stats = ScanStats()
        receiptsSeen = []
        minutesLeft = nil
        savedSelection = nil
        // The usual half minute more when the app is left: without it, the requests in flight were cut.
        let background = BackgroundTime()
        defer { isScanning = false; statusLine = ""; minutesLeft = nil; background.end() }

        let catalog = Self.buildCatalog()
        var newSignals: [ReceiptSignal] = []
        var aiBudget = 40
        let total = max(accounts.count, 1)

        for (index, account) in accounts.enumerated() {
            if Task.isCancelled { break }
            statusLine = L10n.string("Searching \(account.searchName)…")
            do {
                let (signals, accountStats) = try await scan(account, catalog: catalog, aiBudget: &aiBudget) { [weak self] fraction, line in
                    self?.progress = (Double(index) + fraction) / Double(total)
                    self?.statusLine = line
                }
                newSignals += signals
                stats.perAccount[account.id] = accountStats
                stats.emailsChecked += accountStats.checked
                stats.bodiesRead += accountStats.read
                var updated = account
                updated.lastScan = Date()
                MailboxAccountStore.update(updated)
            } catch MailboxError.cancelled {
                stats.stopped = true
                break
            } catch is CancellationError {
                stats.stopped = true
                break
            } catch {
                accountErrors[account.id] = error.localizedDescription
                os_log("Inbox scan failed for one account: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
            }
        }
        accounts = MailboxAccountStore.all()
        // Receipts from an inbox disconnected during the scan are dropped with it.
        let connected = Set(accounts.map(\.id))
        newSignals.removeAll { !($0.sources ?? []).contains(where: connected.contains) }

        let ledger = ReceiptLedger.add(newSignals)
        progress = 1
        analyze(ledger, catalog: catalog)
        stats.receipts = newSignals.count
        if Task.isCancelled { stats.stopped = true }
        Self.saveStats(stats)
        if foundSubscriptions.isEmpty && stats.stopped {
            error = L10n.string("The search was stopped before it found anything")
        } else if foundSubscriptions.isEmpty && accountErrors.count < accounts.count {
            error = L10n.string("No subscriptions found")
        } else if foundSubscriptions.isEmpty, !accounts.isEmpty {
            error = L10n.string("The search couldn't be finished")
        }
    }

    /// One inbox. Returns the receipt facts found and what was read.
    private func scan(_ account: MailboxAccount, catalog: MerchantCatalog, aiBudget: inout Int,
                      progress report: (Double, String) -> Void) async throws -> ([ReceiptSignal], AccountStats) {
        let provider = makeProvider(account)
        try await provider.open()
        var accountStats = AccountStats()
        do {
            let since = Date().addingTimeInterval(-Self.lookback)
            let plan = InboxSearchPlan.standard(catalog: catalog, since: since)
            let cursor = MailboxAccountStore.cursor(for: account.id)
            accountStats.incremental = cursor != nil
            let (refs, nextCursor) = try await provider.candidates(plan: plan, cursor: cursor)
            accountStats.candidates = refs.count
            accountStats.capped = refs.count >= plan.maxCandidates
            report(0.05, L10n.string("Checking \(L10n.string("\(refs.count) emails")) in \(account.searchName)…"))
            // The bar follows requests: headers and bodies cost one each, and headers are most of them. Given
            // 15% of the bar, a real search crawled for minutes and then leapt (A12, 2026-11-22). The bodies to
            // read are projected from the headers checked so far, and the bar never goes back. Guessed at a
            // quarter of the headers, a mailbox of receipts stood at 77% on "Read 1 of 111" (2026-11-23).
            var expectedBodies = min(Self.bodyBudget, max(1, refs.count / 4))
            var wantedSoFar = 0
            var headerEnd = 0.05
            let started = Date()
            func estimate(done: Int, of total: Int) {
                let elapsed = Date().timeIntervalSince(started)
                guard done >= 30, elapsed >= 10 else { return }
                minutesLeft = Self.minutesLeft(done: done, total: total, elapsed: elapsed)
            }

            // Headers in steps of a hundred, so the page counts up instead of standing still: a real
            // inbox spent five minutes on "Checking 1,500 emails" with a bar that never moved.
            var summaries: [MessageSummary] = []
            for chunk in InboxSearchPlan.batches(refs, size: 100) {
                let checked = try await provider.summaries(chunk)
                summaries += checked
                wantedSoFar += Self.triage(checked, catalog: catalog).count
                expectedBodies = Self.projectedReads(wanted: wantedSoFar, checked: summaries.count, of: refs.count)
                headerEnd = max(headerEnd, 0.05 + 0.9 * Double(summaries.count) / Double(max(refs.count + expectedBodies, 1)))
                estimate(done: summaries.count, of: refs.count + expectedBodies)
                report(headerEnd, L10n.string("Checked \(summaries.count) of \(refs.count) in \(account.searchName)"))
            }
            accountStats.checked = summaries.count
            let wanted = Self.triage(summaries, catalog: catalog).prefix(Self.bodyBudget)
            if !wanted.isEmpty {
                report(headerEnd, L10n.string("Reading \(L10n.string("\(wanted.count) emails")) from \(account.searchName)…"))
            }

            var signals: [ReceiptSignal] = []
            var stopped = false
            var offset = -1
            // Read in small batches (several at once where the provider allows), weighed in order.
            for batch in InboxSearchPlan.batches(Array(wanted), size: max(1, provider.parallelReads)) {
                // Stopping keeps what has been read so far: the person asked to see it, not to throw it away.
                if Task.isCancelled { stopped = true; break }
                let raws = await provider.rawMessages(batch.map(\.ref))
                for summary in batch {
                    offset += 1
                    guard let raw = raws[summary.ref] else { continue }
                    accountStats.read += 1
                    let id = summary.messageID ?? "\(account.id):\(summary.ref.folder ?? ""):\(summary.ref.id)"
                    guard let email = MIMEParser.parse(raw, id: id, receivedDate: summary.receivedDate, labelIds: summary.labelIds) else { continue }
                    // One email is one fact, except a store receipt that lists several subscriptions.
                    for result in EmailSignalExtractor.extractAll(email, catalog: catalog) {
                        var signal = result.signal
                        if let excerpt = result.ambiguousExcerpt, let classifier, aiBudget > 0 {
                            aiBudget -= 1
                            let verdict = await classifier.classify(merchantGuess: result.merchantGuess, subject: result.subject, excerpt: excerpt)
                            if verdict != .unsure { stats.aiAssisted += 1 }
                            signal = signal.applying(verdict)
                        }
                        signal.sources = [account.id]
                        signals.append(signal)
                        noteReceipt(signal, catalog: catalog)
                    }
                    if offset % 10 == 0 {
                        estimate(done: refs.count + offset + 1, of: refs.count + wanted.count)
                        report(headerEnd + (0.95 - headerEnd) * Double(offset + 1) / Double(max(wanted.count, 1)),
                               L10n.string("Read \(offset + 1) of \(wanted.count) in \(account.searchName)"))
                    }
                }
            }
            accountStats.receipts = signals.count
            if stopped { stats.stopped = true }
            // A search that was stopped hasn't read everything, so the next one starts over instead of
            // looking only at newer mail.
            if !stopped, MailboxAccountStore.all().contains(where: { $0.id == account.id }) {
                MailboxAccountStore.setCursor(nextCursor, for: account.id)
            }
            await provider.close()
            return (signals, accountStats)
        } catch {
            await provider.close()
            throw error
        }
    }

    /// Shows a charge as soon as its receipt is read. One line per sender, its latest receipt; promotions
    /// and anything without an amount or a usable name are left out. These are receipts, not yet
    /// subscriptions: the list of subscriptions comes when the search has weighed them all.
    private func noteReceipt(_ signal: ReceiptSignal, catalog: MerchantCatalog) {
        // Only receipts that read as recurring: "DoorDash $22.90" and "Skip The Dishes $26.39" on the slip
        // made a person think the app took their dinner for a subscription (the rating of 2026-11-22).
        let recurring = (signal.renewalLanguage || signal.cadenceHint != nil) && !signal.oneTimeLanguage
        guard signal.kind == .charge, recurring, !signal.promotional, signal.spoofSuspected != true, let amount = signal.amount,
              let merchant = catalog.resolve(hint: signal.merchantHint, senderName: signal.senderName, senderDomain: signal.senderDomain)
        else { return }
        let seen = ReceiptSeen(name: merchant.displayName, amount: amount,
                               currency: signal.currency ?? assumedDollar, date: signal.date)
        // A sender's newer receipt changes its line where it is, and a new sender goes at the end. Put at the
        // top, every line moved down with each receipt, and while receipts came faster than the move the lines
        // were drawn over each other (both ratings of 2026-11-22 and the one of 11-23).
        if let index = receiptsSeen.firstIndex(where: { $0.id == seen.id }) {
            if receiptsSeen[index].date < seen.date { receiptsSeen[index] = seen }
            return
        }
        receiptsSeen.append(seen)
    }

    /// Which messages are worth reading in full, most promising first: known billers and platforms, then
    /// everything else that passed triage, newest first within each.
    nonisolated static func triage(_ summaries: [MessageSummary], catalog: MerchantCatalog) -> [MessageSummary] {
        let wanted = summaries.filter {
            EmailTriage.shouldReadBody(from: $0.from, subject: $0.subject, snippet: $0.snippet,
                                       labelIds: $0.labelIds, catalog: catalog)
        }
        // Each receipt once, even if it matched several searches or folders.
        var seen = Set<String>()
        let unique = wanted.filter { seen.insert($0.messageID ?? "\($0.ref.folder ?? ""):\($0.ref.id)").inserted }
        return unique.sorted { a, b in
            let aKnown = catalog.isKnownDomain(EmailSignalExtractor.parseSender(a.from).domain)
            let bKnown = catalog.isKnownDomain(EmailSignalExtractor.parseSender(b.from).domain)
            if aKnown != bKnown { return aKnown }
            return (a.receivedDate ?? .distantPast) > (b.receivedDate ?? .distantPast)
        }
    }

    func makeProvider(_ account: MailboxAccount, password: String? = nil) -> MailboxProvider {
        switch account.kind {
        case .gmail: return GmailMailboxProvider(account: account)
        case .microsoft: return MicrosoftGraphProvider(account: account)
        case .imap:
            #if DEBUG
            let local = account.host == "127.0.0.1" || account.host == "localhost"
            return IMAPMailboxProvider(account: account, password: password, allowsInsecureLocalhost: local)
            #else
            return IMAPMailboxProvider(account: account, password: password)
            #endif
        }
    }

    // MARK: - Analysis and import

    static func buildCatalog() -> MerchantCatalog {
        let extras = SubscriptionCatalogService.shared.catalog.map {
            (name: $0.name, category: $0.category.rawValue, cancelURL: $0.cancellationURL)
        }
        return MerchantCatalog.builtin.extending(with: extras)
    }

    func analyze(_ ledger: [ReceiptSignal], catalog: MerchantCatalog) {
        let engine = SubscriptionIntelligenceEngine(catalog: catalog)
        let corrections = UserCorrections.load()
        let currency = assumedDollar
        let analysis = engine.analyze(signals: ledger, now: Date(), defaultCurrency: currency,
                                      corrections: corrections, rates: CurrencyManager.shared.rates)
        report = analysis
        foundSubscriptions = analysis.subscriptions.map(Self.makeImport)
        // Hidden ones are kept in view at the end of the page: once the page was closed, "This isn't a
        // subscription" could not be taken back (the rating of 2026-11-22).
        let hiddenKeys = Set(corrections.filter { $0.value == .notSubscription }.map(\.key))
        if hiddenKeys.isEmpty {
            hiddenFindings = []
        } else {
            let unhidden = engine.analyze(signals: ledger, now: Date(), defaultCurrency: currency,
                                          corrections: corrections.filter { $0.value != .notSubscription },
                                          rates: CurrencyManager.shared.rates)
            hiddenFindings = unhidden.subscriptions.filter { hiddenKeys.contains($0.merchantKey) }.map(Self.makeImport)
        }
        stats.confirmed = analysis.subscriptions.filter { $0.tier == .confirmed }.count
        stats.purchasesIgnored = analysis.ignoredPurchaseGroups
    }

    /// Shows what earlier searches found, from the facts kept on this iPhone, when the page opens. After a
    /// relaunch the page offered only "Search again" over 139 saved facts, and a first Gmail search is
    /// about six minutes (2026-11-22). Nothing is read from the inbox.
    func showSaved() {
        guard hasAccounts, !isScanning, foundSubscriptions.isEmpty, report == nil else { return }
        #if DEBUG
        if isShowingDemo { return }
        #endif
        if stats == ScanStats(), let saved = Self.savedStats() { stats = saved }
        reanalyze()
    }

    /// Re-runs detection on the on-device facts only. Instant, offline, no email access.
    func reanalyze() {
        analyze(ReceiptLedger.load(), catalog: Self.buildCatalog())
    }

    /// Hides a finding for good. Returns what the person had said about it before, so Undo can put it back.
    @discardableResult
    func markNotSubscription(_ subscription: FoundSubscription, defaults: UserDefaults = .standard) -> UserVerdict? {
        let previous = UserCorrections.load(defaults: defaults)[subscription.proven.merchantKey]
        UserCorrections.set(subscription.proven.merchantKey, .notSubscription, defaults: defaults)
        reanalyze()
        return previous
    }

    /// Undo for "This isn't a subscription": a tap meant for the row's box could hide a real one, with
    /// no way back (the rating of 2026-11-22).
    func undoNotSubscription(_ subscription: FoundSubscription, previous: UserVerdict?, defaults: UserDefaults = .standard) {
        UserCorrections.set(subscription.proven.merchantKey, previous, defaults: defaults)
        reanalyze()
    }

    /// Adds what the person chose to their list. Under the free limit, the ones that cost most are added
    /// and the rest wait (see `TallyImporter`); the outcome says which, so the screen can too.
    func importSubscriptions(_ selected: [FoundSubscription]) async -> TallyImporter.Outcome {
        for found in selected where !found.isCancelled { UserCorrections.set(found.proven.merchantKey, .trusted) }
        return await TallyImporter.add(selected.filter { !$0.isCancelled }.map(\.line), into: SubscriptionStore.shared)
    }

    static func makeImport(from sub: ProvenSubscription) -> FoundSubscription {
        FoundSubscription(proven: sub)
    }

    #if DEBUG
    /// True once `presentDemo` has put a made-up inbox and its findings on screen.
    private(set) var isShowingDemo = false

    /// DEBUG only: shows a synthetic result for screenshots and reviews (`--demo-gmail-results`).
    func presentDemo(_ analysis: IntelligenceReport, account: MailboxAccount, checked: Int, read: Int) {
        isShowingDemo = true
        accounts = [account]
        report = analysis
        foundSubscriptions = analysis.subscriptions.map(Self.makeImport)
        stats = ScanStats(emailsChecked: checked, bodiesRead: read, receipts: 0, aiAssisted: 0,
                          purchasesIgnored: analysis.ignoredPurchaseGroups,
                          confirmed: analysis.subscriptions.filter { $0.tier == .confirmed }.count)
    }

    /// DEBUG only: made-up inboxes with nothing found in them, as the page stands before a search,
    /// after one that found nothing, or after one that an inbox refused (`--demo-inbox=…`).
    func presentDemo(connected: [MailboxAccount], outcome: String?, refused: [String: String], checked: Int) {
        isShowingDemo = true
        accounts = connected
        report = nil
        foundSubscriptions = []
        error = outcome
        accountErrors = refused
        stats = ScanStats(emailsChecked: checked, bodiesRead: 0, receipts: 0, aiAssisted: 0, purchasesIgnored: 0, confirmed: 0)
    }
    #endif

    // MARK: - Migration

    /// Moves a Gmail connection made by the previous Gmail-only scanner into the inbox list.
    private func migrateLegacyGmail() {
        let defaults = UserDefaults.standard
        guard let email = defaults.string(forKey: "gmail_connected_email") else { return }
        defer {
            defaults.removeObject(forKey: "gmail_connected_email")
            defaults.removeObject(forKey: "gmail_last_history_id")
            KeychainManager.shared.delete(key: "gmail_access_token")
            KeychainManager.shared.delete(key: "gmail_refresh_token")
        }
        guard !MailboxAccountStore.all().contains(where: { $0.kind == .gmail && $0.address == email }),
              let refresh = KeychainManager.shared.get("gmail_refresh_token") else { return }
        let account = MailboxAccount(id: UUID().uuidString, kind: .gmail, address: email, addedAt: Date())
        OAuthSession.store(OAuthSession.Tokens(accessToken: KeychainManager.shared.get("gmail_access_token") ?? "",
                                               refreshToken: refresh, expiresAt: .distantPast), for: account.id)
        MailboxAccountStore.upsert(account)
        if let history = defaults.string(forKey: "gmail_last_history_id") { MailboxAccountStore.setCursor(history, for: account.id) }
    }
}

/// Asks iOS for the usual extra time while a search runs and the app is left, and gives it back after.
@MainActor
private final class BackgroundTime {
    private var id = UIBackgroundTaskIdentifier.invalid

    init() {
        id = UIApplication.shared.beginBackgroundTask(withName: "Inbox search") { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
