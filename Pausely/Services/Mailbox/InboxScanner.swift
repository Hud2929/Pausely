import Foundation
import os.log

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
    @Published var foundSubscriptions: [SmartImportManager.ImportSubscription] = []
    @Published var report: IntelligenceReport?
    @Published var error: String?
    @Published private(set) var accountErrors: [String: String] = [:]
    @Published private(set) var stats = ScanStats()

    struct AccountStats: Equatable {
        var candidates = 0
        var checked = 0
        var read = 0
        var receipts = 0
        var incremental = false
    }

    struct ScanStats: Equatable {
        var emailsChecked = 0
        var bodiesRead = 0
        var receipts = 0
        var aiAssisted = 0
        var purchasesIgnored = 0
        var confirmed = 0
        var perAccount: [String: AccountStats] = [:]
    }

    /// Full messages read per inbox per scan, the most likely receipts first.
    static let bodyBudget = 400
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

    /// Signs in to an IMAP server and keeps the account only if the sign-in and folder listing work.
    func connectIMAP(address: String, password: String, preset: IMAPPreset?, host customHost: String? = nil,
                     port customPort: Int? = nil) async throws -> MailboxAccount {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@"), trimmed.split(separator: "@").count == 2 else {
            throw MailboxError.notConfigured("Enter your full email address.")
        }
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPassword.isEmpty else { throw MailboxError.notConfigured("Enter the app password.") }
        guard let host = (customHost?.isEmpty == false ? customHost : preset?.host)?.lowercased() else {
            throw MailboxError.notConfigured("Choose your email provider or enter its IMAP server.")
        }
        if let existing = accounts.first(where: { $0.address == trimmed && $0.kind == .imap }) {
            throw MailboxError.notConfigured("\(existing.address) is already connected.")
        }

        let account = MailboxAccount(id: UUID().uuidString, kind: .imap, address: trimmed, presetID: preset?.id,
                                     host: host, port: customPort ?? 993, addedAt: Date())
        let provider = makeProvider(account, password: cleanPassword)
        try await provider.open()
        await provider.close()
        guard MailboxAccountStore.setSecret(cleanPassword, .password, for: account.id) else {
            throw MailboxError.server("Couldn't save the password securely on this iPhone.")
        }
        MailboxAccountStore.upsert(account)
        accounts = MailboxAccountStore.all()
        return account
    }

    private func connect(_ action: () async throws -> MailboxAccount) async {
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
        if scanTask != nil { cancelScan() }
        await makeProvider(account).revoke()
        MailboxAccountStore.remove(account.id)
        accounts = MailboxAccountStore.all()
        accountErrors[account.id] = nil
        _ = ReceiptLedger.removeSource(account.id, remainingAccounts: accounts.count)
        if accounts.isEmpty {
            ReceiptLedger.clear()
            foundSubscriptions = []
            report = nil
            stats = ScanStats()
        } else {
            reanalyze()
        }
    }

    /// Account deletion and sign-out: forget every inbox and every receipt fact.
    func disconnectAll() async {
        for account in accounts { await makeProvider(account).revoke() }
        MailboxAccountStore.removeAll()
        ReceiptLedger.clear()
        accounts = []
        foundSubscriptions = []
        report = nil
        stats = ScanStats()
        accountErrors = [:]
    }

    // MARK: - Scanning

    func scanAll() async {
        guard !isScanning else { return }
        let task = Task { await runScan() }
        scanTask = task
        await task.value
        scanTask = nil
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    private func runScan() async {
        isScanning = true
        progress = 0
        error = nil
        accountErrors = [:]
        stats = ScanStats()
        defer { isScanning = false; statusLine = "" }

        let catalog = Self.buildCatalog()
        var newSignals: [ReceiptSignal] = []
        var aiBudget = 40
        let total = max(accounts.count, 1)

        for (index, account) in accounts.enumerated() {
            if Task.isCancelled { break }
            statusLine = "Searching \(account.providerName)…"
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
                MailboxAccountStore.upsert(updated)
            } catch MailboxError.cancelled {
                break
            } catch is CancellationError {
                break
            } catch {
                accountErrors[account.id] = error.localizedDescription
                os_log("Inbox scan failed for one account: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
            }
        }
        accounts = MailboxAccountStore.all()

        let ledger = ReceiptLedger.merge(newSignals, into: ReceiptLedger.load())
        ReceiptLedger.save(ledger)
        progress = 1
        analyze(ledger, catalog: catalog)
        stats.receipts = newSignals.count
        if foundSubscriptions.isEmpty && accountErrors.count < accounts.count {
            error = "No recurring subscriptions found in your email yet."
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
            report(0.2, "Checking \(refs.count) emails in \(account.providerName)…")

            let summaries = try await provider.summaries(refs)
            accountStats.checked = summaries.count
            let wanted = Self.triage(summaries, catalog: catalog).prefix(Self.bodyBudget)
            report(0.35, "Reading \(wanted.count) receipts from \(account.providerName)…")

            var signals: [ReceiptSignal] = []
            for (offset, summary) in wanted.enumerated() {
                try Task.checkCancellation()
                guard let raw = try? await provider.rawMessage(summary.ref) else { continue }
                accountStats.read += 1
                let id = summary.messageID ?? "\(account.id):\(summary.ref.folder ?? ""):\(summary.ref.id)"
                guard let email = MIMEParser.parse(raw, id: id, receivedDate: summary.receivedDate, labelIds: summary.labelIds),
                      let result = EmailSignalExtractor.extract(email, catalog: catalog) else { continue }
                var signal = result.signal
                if let excerpt = result.ambiguousExcerpt, let classifier, aiBudget > 0 {
                    aiBudget -= 1
                    let verdict = await classifier.classify(merchantGuess: result.merchantGuess, subject: result.subject, excerpt: excerpt)
                    if verdict != .unsure { stats.aiAssisted += 1 }
                    signal = signal.applying(verdict)
                }
                signal.sources = [account.id]
                signals.append(signal)
                if offset % 10 == 0 {
                    report(0.35 + 0.6 * Double(offset + 1) / Double(max(wanted.count, 1)),
                           "Read \(offset + 1) of \(wanted.count) in \(account.providerName)")
                }
            }
            accountStats.receipts = signals.count
            MailboxAccountStore.setCursor(nextCursor, for: account.id)
            await provider.close()
            return (signals, accountStats)
        } catch {
            await provider.close()
            throw error
        }
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
        let analysis = engine.analyze(signals: ledger, now: Date(),
                                      defaultCurrency: CurrencyManager.shared.selectedCurrency,
                                      corrections: UserCorrections.load())
        report = analysis
        foundSubscriptions = analysis.subscriptions.map(Self.makeImport)
        stats.confirmed = analysis.subscriptions.filter { $0.tier == .confirmed }.count
        stats.purchasesIgnored = analysis.ignoredPurchaseGroups
    }

    /// Re-runs detection on the on-device facts only. Instant, offline, no email access.
    func reanalyze() {
        analyze(ReceiptLedger.load(), catalog: Self.buildCatalog())
    }

    func markNotSubscription(_ subscription: SmartImportManager.ImportSubscription) {
        guard let key = subscription.proven?.merchantKey else { return }
        UserCorrections.set(key, .notSubscription)
        reanalyze()
    }

    func importSubscriptions(_ selected: [SmartImportManager.ImportSubscription]) async -> (added: Int, duplicates: Int) {
        for sub in selected { if let key = sub.proven?.merchantKey { UserCorrections.set(key, .trusted) } }
        let result = SmartImportManager.ImportResult(subscriptions: selected, errors: [])
        await SmartImportManager.shared.processImports(from: [result])
        return (SmartImportManager.shared.importedCount, SmartImportManager.shared.duplicatesFound)
    }

    static func makeImport(from sub: ProvenSubscription) -> SmartImportManager.ImportSubscription {
        let confidence: SmartImportManager.ImportSubscription.Confidence
        switch sub.tier {
        case .confirmed: confidence = .high
        case .likely: confidence = .medium
        default: confidence = .low
        }
        return SmartImportManager.ImportSubscription(
            name: sub.name, amount: sub.amount, currency: sub.currency, billingFrequency: sub.frequency,
            nextBillingDate: sub.nextBillingDate, confidence: confidence, source: "Email", proven: sub)
    }

    #if DEBUG
    /// DEBUG only: shows a synthetic result for screenshots and reviews (`--demo-gmail-results`).
    func presentDemo(_ analysis: IntelligenceReport, account: MailboxAccount, checked: Int, read: Int) {
        accounts = [account]
        report = analysis
        foundSubscriptions = analysis.subscriptions.map(Self.makeImport)
        stats = ScanStats(emailsChecked: checked, bodiesRead: read, receipts: 0, aiAssisted: 0,
                          purchasesIgnored: analysis.ignoredPurchaseGroups,
                          confirmed: analysis.subscriptions.filter { $0.tier == .confirmed }.count)
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
