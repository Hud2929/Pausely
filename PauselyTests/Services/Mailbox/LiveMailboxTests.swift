import XCTest
@testable import Pausely

/// Tests against real servers. Each is skipped unless its environment variable is set, so the regular
/// suite stays offline. Run with TEST_RUNNER_<NAME>=… on the xcodebuild command line.
final class LiveMailboxTests: XCTestCase {

    private func environment(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]
        return (value?.isEmpty == false) ? value : nil
    }

    // MARK: 1. A whole scan through the real IMAP stack, against a local IMAP server

    /// PAUSELY_LOCAL_IMAP=host:port:user:password (the Twisted test server in the job folder).
    func testLocalIMAPServerEndToEnd() async throws {
        guard let spec = environment("PAUSELY_LOCAL_IMAP").map({ $0.split(separator: ":").map(String.init) }), spec.count == 4 else {
            throw XCTSkip("set PAUSELY_LOCAL_IMAP=host:port:user:password")
        }
        let account = MailboxAccount(id: "local-test", kind: .imap, address: spec[2], presetID: nil,
                                     host: spec[0], port: Int(spec[1]), addedAt: Date())

        let provider = IMAPMailboxProvider(account: account, password: spec[3], allowsInsecureLocalhost: true)
        try await provider.open()
        XCTAssertEqual(provider.folders, ["INBOX", "Archive"])

        let catalog = MerchantCatalog.builtin
        let plan = InboxSearchPlan.standard(catalog: catalog, since: Date(timeIntervalSince1970: 1_767_225_600))
        let (refs, cursor) = try await provider.candidates(plan: plan, cursor: nil)
        XCTAssertNotNil(cursor)
        let summaries = try await provider.summaries(refs)
        XCTAssertEqual(summaries.count, refs.count, "every candidate has headers")
        XCTAssertTrue(summaries.allSatisfy { $0.messageID != nil && $0.receivedDate != nil })

        let wanted = InboxScanner.triage(summaries, catalog: catalog)
        var signals: [ReceiptSignal] = []
        for summary in wanted {
            let fetched = try await provider.rawMessage(summary.ref)
            let raw = try XCTUnwrap(fetched)
            let email = try XCTUnwrap(MIMEParser.parse(raw, id: summary.messageID!, receivedDate: summary.receivedDate))
            if let result = EmailSignalExtractor.extract(email, catalog: catalog) {
                signals.append(result.signal)
                let s = result.signal
                print("  SIGNAL \(s.senderDomain) hint=\(s.merchantHint ?? "-") kind=\(s.kind) amount=\(s.amount.map { "\($0)" } ?? "-") \(s.currency ?? "-") platform=\(s.platform) renewal=\(s.renewalLanguage) oneTime=\(s.oneTimeLanguage) promo=\(s.promotional) spoof=\(s.spoofSuspected ?? false)")
            } else {
                print("  DROPPED \(email.from) | \(email.subject) | text=\(email.bodyText.prefix(80)) | html=\(email.bodyHTML != nil)")
            }
        }
        let report = SubscriptionIntelligenceEngine(catalog: catalog)
            .analyze(signals: signals, now: Date(timeIntervalSince1970: 1_792_497_600), defaultCurrency: "USD")
        let found = Dictionary(report.subscriptions.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        print("LOCAL IMAP: candidates \(refs.count), read \(wanted.count), receipts \(signals.count)")
        for sub in report.subscriptions { print("  \(sub.name) · \(sub.amount) \(sub.currency) · \(sub.frequency) · \(sub.tier) · \(sub.status)") }

        XCTAssertEqual(found["Netflix"]?.amount, Decimal(string: "15.49"), "the forged $99.99 'Netflix' receipt must not win")
        XCTAssertEqual(found["Netflix"]?.tier, .confirmed)
        XCTAssertEqual(found["Netflix"]?.frequency, .monthly)
        XCTAssertEqual(found["Spotify"]?.currency, "EUR")
        XCTAssertEqual(found["Spotify"]?.amount, Decimal(string: "10.99"))
        XCTAssertNotNil(report.subscriptions.first { $0.name.contains("iCloud") }, "App Store receipts in HTML only")
        XCTAssertEqual(found["Disney+"]?.currency, "JPY", "Japanese ISO-2022-JP receipt")
        XCTAssertNil(found["Uber"])
        XCTAssertFalse(report.subscriptions.contains { $0.name.lowercased().contains("amazon") }, "one-time order")
        XCTAssertFalse(report.subscriptions.contains { $0.name.lowercased().contains("promo") || $0.name.contains("Best Deals") })

        // A second scan only looks at mail that arrived since: here, nothing.
        let second = try await provider.candidates(plan: plan, cursor: cursor)
        XCTAssertEqual(second.refs.count, 0)
        await provider.close()
    }

    // MARK: 1a. The app's own scanner (connect, search, triage, read, ledger, engine) against a local IMAP server

    /// PAUSELY_LOCAL_IMAP_APP=host:port:user:password. Connects the inbox the way the app does, scans it, prints
    /// the result, then disconnects (removing the account, its password and its receipts).
    @MainActor
    func testAppScanAgainstLocalIMAPServer() async throws {
        guard let spec = environment("PAUSELY_LOCAL_IMAP_APP").map({ $0.split(separator: ":").map(String.init) }), spec.count == 4 else {
            throw XCTSkip("set PAUSELY_LOCAL_IMAP_APP=host:port:user:password")
        }
        let scanner = InboxScanner.shared
        let account = try await scanner.connectIMAP(address: spec[2], password: spec[3], preset: nil, host: spec[0], port: Int(spec[1]))
        defer { Task { @MainActor in await scanner.disconnect(account) } }
        XCTAssertNotNil(MailboxAccountStore.secret(.password, for: account.id), "password kept in the Keychain")

        await scanner.scanAll()
        let stats = scanner.stats.perAccount[account.id]
        var lines = ["APP SCAN: candidates \(stats?.candidates ?? 0), checked \(stats?.checked ?? 0), read \(stats?.read ?? 0), receipts \(stats?.receipts ?? 0)"
                     + (scanner.accountErrors[account.id].map { " — ERROR: \($0)" } ?? "")]
        for sub in scanner.report?.subscriptions ?? [] {
            lines.append("  \(sub.name) · \(sub.amount) \(sub.currency) · \(sub.frequency.rawValue) · \(sub.tier) · \(sub.status)")
        }
        for insight in scanner.report?.insights ?? [] { lines.append("  INSIGHT \(insight.title)") }
        lines.append("  IMPORT LIST: " + scanner.foundSubscriptions.map(\.name).joined(separator: ", "))
        let text = lines.joined(separator: "\n")
        print(text)
        if let path = environment("PAUSELY_REPORT_PATH") { try text.write(toFile: path, atomically: true, encoding: .utf8) }
        XCTAssertTrue(scanner.accountErrors.isEmpty, "\(scanner.accountErrors)")

        // Second scan: only mail that arrived since the first.
        await scanner.scanAll()
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.candidates, 0)
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.incremental, true)

        await scanner.disconnect(account)
        XCTAssertNil(MailboxAccountStore.secret(.password, for: account.id), "password removed on disconnect")
        XCTAssertFalse(MailboxAccountStore.all().contains { $0.id == account.id })
    }

    // MARK: 1b. Real receipts saved as .eml, through the same parse → extract → analyze path as a scan

    /// PAUSELY_REAL_MAIL_DIR=<folder of .eml files>. Prints what each message became and the final list,
    /// and writes it to PAUSELY_REPORT_PATH when set. Real mail stays outside the repository.
    func testRealMailDirectory() throws {
        guard let directory = environment("PAUSELY_REAL_MAIL_DIR").map({ URL(fileURLWithPath: $0) }) else {
            throw XCTSkip("set PAUSELY_REAL_MAIL_DIR")
        }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "eml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        try XCTSkipIf(files.isEmpty, "no .eml files")

        let catalog = MerchantCatalog.builtin
        var lines: [String] = []
        var signals: [ReceiptSignal] = []
        for file in files {
            let data = try Data(contentsOf: file)
            let name = file.deletingPathExtension().lastPathComponent
            guard let email = MIMEParser.parse(data, id: name, receivedDate: nil) else {
                lines.append("UNPARSED \(name)")
                continue
            }
            if let result = EmailSignalExtractor.extract(email, catalog: catalog) {
                let s = result.signal
                signals.append(s)
                lines.append("SIGNAL \(name) \(s.senderDomain) | \(email.subject.prefix(50)) | hint=\(s.merchantHint ?? "-") kind=\(s.kind) "
                             + "amount=\(s.amount.map { "\($0)" } ?? "-") \(s.currency ?? "-") cadence=\(s.cadenceHint.map { "\($0)" } ?? "-") "
                             + "platform=\(s.platform) renewal=\(s.renewalLanguage) oneTime=\(s.oneTimeLanguage) promo=\(s.promotional) "
                             + "spoof=\(s.spoofSuspected ?? false)")
            } else {
                lines.append("DROPPED \(name) \(email.from.prefix(40)) | \(email.subject.prefix(50)) | text=\(email.bodyText.count) html=\(email.bodyHTML?.count ?? 0)")
            }
        }
        let report = SubscriptionIntelligenceEngine(catalog: catalog)
            .analyze(signals: signals, now: Date(), defaultCurrency: "CAD")
        lines.append("FOUND \(report.subscriptions.count) (ignored purchase groups: \(report.ignoredPurchaseGroups))")
        for sub in report.subscriptions {
            lines.append("  \(sub.name) · \(sub.amount) \(sub.currency) · \(sub.frequency.rawValue) · \(sub.tier) · \(sub.status) · \(sub.evidence.count) receipts · \(sub.reasons.joined(separator: "; "))")
        }
        for insight in report.insights { lines.append("  INSIGHT \(insight.kind): \(insight.title)") }
        let text = lines.joined(separator: "\n")
        print(text)
        if let path = environment("PAUSELY_REPORT_PATH") { try text.write(toFile: path, atomically: true, encoding: .utf8) }
    }

    // MARK: 2. Real providers: TLS, greeting, capabilities, and a rejected sign-in handled cleanly

    /// PAUSELY_LIVE_SERVERS=1. One connection and one deliberately wrong sign-in per provider.
    func testRealProviderServers() async throws {
        try XCTSkipUnless(environment("PAUSELY_LIVE_SERVERS") == "1", "set PAUSELY_LIVE_SERVERS=1")
        var report: [String] = []
        var failures: [String] = []
        for preset in IMAPPreset.all {
            let client = IMAPClient(IMAPClient.Configuration(host: preset.host, commandTimeout: 20))
            do {
                try await client.connect()
                let capabilities = await client.capabilities
                guard capabilities.contains("IMAP4REV1") || capabilities.contains("IMAP4REV2") else {
                    failures.append("\(preset.name): no IMAP4rev1 capability")
                    await client.logout()
                    continue
                }
                do {
                    try await client.login(user: "pausely-connectivity-check@example.invalid", password: "not-a-real-password")
                    failures.append("\(preset.name): accepted a fake sign-in?")
                } catch let error as MailboxError {
                    if case .authFailed = error {
                        report.append("✓ \(preset.name) (\(preset.host)): TLS ok, \(capabilities.count) capabilities, wrong password rejected cleanly")
                    } else {
                        report.append("✓ \(preset.name) (\(preset.host)): TLS ok, sign-in refused: \(error.localizedDescription)")
                    }
                }
                await client.cancel()
            } catch {
                failures.append("\(preset.name) (\(preset.host)): \(error.localizedDescription)")
                await client.cancel()
            }
        }
        print("LIVE IMAP SERVERS\n" + report.joined(separator: "\n") + "\n" + failures.map { "✗ " + $0 }.joined(separator: "\n"))
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    /// PAUSELY_LIVE_SERVERS=1. Microsoft Graph and Google reject a bad token, and the providers turn that
    /// into "reconnect this inbox" instead of an error loop.
    func testRealCloudAPIsRejectBadTokensCleanly() async throws {
        try XCTSkipUnless(environment("PAUSELY_LIVE_SERVERS") == "1", "set PAUSELY_LIVE_SERVERS=1")
        for url in ["https://graph.microsoft.com/v1.0/me", "https://gmail.googleapis.com/gmail/v1/users/me/profile"] {
            var refreshes = 0
            do {
                _ = try await MailboxHTTP.data(URLRequest(url: URL(string: url)!),
                                               token: { "not-a-real-token" },
                                               refresh: { refreshes += 1; return "still-not-real" })
                XCTFail("\(url) accepted a fake token")
            } catch let error as MailboxError {
                XCTAssertEqual(error, .authExpired, url)
                XCTAssertEqual(refreshes, 1, "one refresh, then stop")
            }
        }
    }

    // MARK: 3. Real inboxes connected in the app on this simulator

    /// PAUSELY_REAL_ACCOUNTS=1. Scans every inbox connected in the app (Find in Email) and writes a report.
    @MainActor
    func testRealConnectedInboxes() async throws {
        try XCTSkipUnless(environment("PAUSELY_REAL_ACCOUNTS") == "1", "set PAUSELY_REAL_ACCOUNTS=1")
        let scanner = InboxScanner.shared
        try XCTSkipIf(scanner.accounts.isEmpty, "Connect inboxes in the app first")
        // Full scans: forget sync positions so every pass runs.
        for account in scanner.accounts { MailboxAccountStore.setCursor(nil, for: account.id) }
        await scanner.scanAll()

        var lines = ["REAL INBOX SCAN \(Date())"]
        for account in scanner.accounts {
            let stats = scanner.stats.perAccount[account.id]
            lines.append("\(account.providerName) \(account.address): candidates \(stats?.candidates ?? 0), checked \(stats?.checked ?? 0), read \(stats?.read ?? 0), receipts \(stats?.receipts ?? 0)"
                         + (scanner.accountErrors[account.id].map { " — ERROR: \($0)" } ?? ""))
        }
        for sub in scanner.report?.subscriptions ?? [] {
            lines.append("  \(sub.name) · \(sub.amount) \(sub.currency) · \(sub.frequency.rawValue) · \(sub.tier) · \(sub.status) · \(sub.evidence.count) receipts")
        }
        let text = lines.joined(separator: "\n")
        print(text)
        if let path = environment("PAUSELY_REPORT_PATH") { try text.write(toFile: path, atomically: true, encoding: .utf8) }
        XCTAssertTrue(scanner.accountErrors.isEmpty, "\(scanner.accountErrors)")
    }
}
