import XCTest
@testable import Pausely

/// The promises printed on the "Find in Email" screen, each held by a test:
///
///   "Your email never leaves your iPhone."                      → the mail code talks only to mail providers
///   "keeps only the name, amount and date of each charge"       → the ledger has no field that holds email text
///   "It only reads: it never sends, changes or deletes email."  → read-only sign-in scopes, read-only IMAP commands
///   disconnecting removes an inbox's facts and its password      → `testDisconnectingForgetsTheInbox`
///
/// The source-scanning tests fail when someone adds a host, a scope or a command that breaks a promise,
/// which is the moment the wording on screen would become untrue.
final class InboxPrivacyTests: XCTestCase {

    private static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Every Swift file that reads or interprets mail.
    private func mailSources() throws -> [(path: String, text: String)] {
        let root = Self.root
        try XCTSkipUnless(FileManager.default.fileExists(atPath: root.appendingPathComponent("Pausely").path),
                          "Sources aren't readable from this test run")
        var sources: [(String, String)] = []
        for folder in ["Pausely/Services/Mailbox", "Pausely/Services/Intelligence"] {
            guard let files = FileManager.default.enumerator(at: root.appendingPathComponent(folder), includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in files where file.pathExtension == "swift" {
                sources.append((String(file.path.dropFirst(root.path.count + 1)), try String(contentsOf: file, encoding: .utf8)))
            }
        }
        XCTAssertGreaterThan(sources.count, 15, "the mail code should have been found")
        return sources
    }

    private func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.numberOfRanges > 1 ? $0.range(at: 1) : $0.range)
        }
    }

    // MARK: "Your email never leaves your iPhone."

    func testMailCodeOnlyTalksToMailProviders() throws {
        // Sign-in and mail APIs of the two providers Pausely signs in to. IMAP hosts are the person's own
        // mail servers (`IMAPPreset`), reached over TLS by `IMAPClient`.
        let allowed: Set<String> = [
            "gmail.googleapis.com", "accounts.google.com", "oauth2.googleapis.com", "www.googleapis.com",
            "graph.microsoft.com", "login.microsoftonline.com"
        ]
        // Pages opened in the browser for the person to create an app password, and links to documentation.
        let pagesForThePerson: Set<String> = [
            "account.apple.com", "login.yahoo.com", "login.aol.com", "myaccount.google.com", "www.gmx.com", "www.gmx.net",
            "web.de", "accounts.zoho.com", "app.fastmail.com", "www.xfinity.com", "schema.org"
        ]
        var seen = Set<String>()
        for source in try mailSources() {
            for line in source.text.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                // A merchant's cancel page is a link shown to the person, never a request the app makes.
                if line.contains("cancel: \"https://") { continue }
                for host in matches(#"https?://([A-Za-z0-9.\-]+)"#, in: line) {
                    seen.insert(host.lowercased())
                    XCTAssertTrue(allowed.contains(host.lowercased()) || pagesForThePerson.contains(host.lowercased()),
                                  "\(source.path) names \(host): mail code may only reach mail providers")
                }
            }
        }
        XCTAssertTrue(seen.contains("gmail.googleapis.com") && seen.contains("graph.microsoft.com"), "the scan should have found the provider hosts")
    }

    func testMailCodeHasNoOtherWayOut() throws {
        // No analytics, no backend calls, no uploads from anything that touches mail.
        for source in try mailSources() {
            for needle in ["SupabaseManager", ".from(\"", "Analytics", "uploadTask", "httpBody = try? JSONEncoder().encode(signal"] {
                XCTAssertFalse(source.text.contains(needle), "\(source.path) uses \(needle)")
            }
        }
    }

    // MARK: "keeps only the name, amount and date of each charge"

    func testTheLedgerHasNoFieldForEmailText() throws {
        let email = RawEmail(id: "privacy-1", date: Date(timeIntervalSince1970: 1_790_000_000),
                             from: "Netflix <info@account.netflix.com>", subject: "ZEBRA-SUBJECT-91 Your Netflix receipt",
                             bodyText: "PRIVATE-BODY-SENTENCE-77 Hi Jordan at 44 Elm Street.\nAmount charged: $15.49\nYour membership renews monthly.",
                             bodyHTML: nil, headers: ["message-id": "<abc@netflix.com>"], labelIds: [])
        let signal = try XCTUnwrap(EmailSignalExtractor.extractAll(email).first?.signal)
        XCTAssertEqual(signal.amount, Decimal(string: "15.49"))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(signal)
        let stored = try XCTUnwrap(String(data: data, encoding: .utf8))
        for secret in ["ZEBRA-SUBJECT-91", "PRIVATE-BODY-SENTENCE-77", "Jordan", "Elm Street", "Your Netflix receipt"] {
            XCTAssertFalse(stored.contains(secret), "the ledger must not hold \(secret)")
        }

        // A new field has to be added here on purpose, with a look at whether it can carry text.
        let allowed: Set<String> = [
            "id", "date", "senderDomain", "senderName", "merchantHint", "platform", "kind", "amount", "currency", "cadenceHint",
            "trialDays", "renewalLanguage", "oneTimeLanguage", "promotional", "markup", "hasUnsubscribe", "bulkMail", "sources",
            "spoofSuspected", "nextAmount", "introAmount"
        ]
        var everything = signal
        everything.cadenceHint = .monthly; everything.trialDays = 7; everything.markup = .subscription
        everything.hasUnsubscribe = true; everything.bulkMail = false; everything.sources = ["a"]; everything.spoofSuspected = false
        everything.nextAmount = 1; everything.introAmount = 1; everything.currency = "USD"; everything.merchantHint = "Netflix"
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(everything)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), allowed, "ReceiptSignal's stored fields changed")
    }

    // MARK: "It only reads: it never sends, changes or deletes email."

    func testOnlyReadOnlyAccessIsAskedFor() {
        XCTAssertEqual(GmailMailboxProvider.oauth.scopes, ["https://www.googleapis.com/auth/gmail.readonly"])
        XCTAssertEqual(Set(MicrosoftGraphProvider.oauth.scopes), ["offline_access", "User.Read", "Mail.Read"])
    }

    func testIMAPIssuesOnlyCommandsThatCannotChangeAMailbox() throws {
        // EXAMINE opens a folder read-only (SELECT would not); BODY.PEEK reads without marking as read.
        let forbidden = ["SELECT", "STORE", "APPEND", "EXPUNGE", "DELETE", "COPY", "MOVE", "CREATE", "RENAME", "CLOSE"]
        var commands = Set<String>()
        for source in try mailSources() where source.path.contains("/IMAP/") {
            for command in matches(#"\.raw\("([A-Z][A-Z ]*)"#, in: source.text) {
                let verb = command.trimmingCharacters(in: .whitespaces)
                commands.insert(verb)
                XCTAssertFalse(forbidden.contains { verb == $0 || verb.hasPrefix($0 + " ") || verb.hasSuffix(" " + $0) },
                               "\(source.path) sends \(verb)")
            }
            XCTAssertFalse(source.text.contains("BODY[]") && !source.text.contains("BODY.PEEK[]"), "\(source.path) fetches without PEEK")
        }
        XCTAssertTrue(commands.contains("EXAMINE") && commands.contains("UID SEARCH"), "the scan should have found the client's commands: \(commands)")
    }

    func testGmailAndOutlookRequestsOnlyRead() throws {
        // GET everywhere, except the token endpoints (sign-in) and Google's revoke call (sign-out).
        for source in try mailSources() where source.path.hasSuffix("GmailMailboxProvider.swift") || source.path.hasSuffix("MicrosoftGraphProvider.swift") {
            for method in matches(#"httpMethod\s*=\s*"([A-Z]+)""#, in: source.text) {
                XCTAssertTrue(["GET", "POST"].contains(method), "\(source.path) sends \(method)")
            }
            for forbidden in ["/send", "/trash", "/modify", "batchDelete", "batchModify", "/move", "/copy", "sendMail", "PATCH", "\"DELETE\""] {
                XCTAssertFalse(source.text.contains(forbidden), "\(source.path) mentions \(forbidden)")
            }
        }
    }

    // MARK: Disconnecting

    func testDisconnectingForgetsTheInbox() {
        let saved = ReceiptLedger.load()
        defer { ReceiptLedger.save(saved) }

        let account = MailboxAccount(id: "privacy-test-\(UUID().uuidString)", kind: .imap, address: "jordan@privacy.test",
                                     presetID: nil, host: "imap.privacy.test", port: 993, addedAt: Date())
        MailboxAccountStore.upsert(account)
        XCTAssertTrue(MailboxAccountStore.setSecret("app-password-abcd", .password, for: account.id))
        MailboxAccountStore.setCursor("{\"INBOX\":{\"validity\":1,\"lastUID\":9}}", for: account.id)

        func fact(_ id: String, sources: [String]) -> ReceiptSignal {
            ReceiptSignal(id: id, date: Date(), senderDomain: "netflix.com", senderName: "Netflix", merchantHint: nil, platform: "direct",
                          kind: .charge, amount: 15, currency: "USD", cadenceHint: nil, trialDays: nil, renewalLanguage: true,
                          oneTimeLanguage: false, promotional: false, sources: sources)
        }
        ReceiptLedger.save([fact("only-here", sources: [account.id]), fact("in-both", sources: [account.id, "other-inbox"])])

        // What `InboxScanner.disconnect` does for one inbox.
        MailboxAccountStore.remove(account.id)
        let kept = ReceiptLedger.removeSource(account.id, remainingAccounts: 1)

        XCTAssertNil(MailboxAccountStore.secret(.password, for: account.id), "the app password is gone from the Keychain")
        XCTAssertNil(MailboxAccountStore.cursor(for: account.id))
        XCTAssertFalse(MailboxAccountStore.all().contains { $0.id == account.id })
        XCTAssertEqual(kept.map(\.id), ["in-both"], "facts found only in that inbox are forgotten")
        XCTAssertEqual(kept.first?.sources, ["other-inbox"])
        XCTAssertEqual(ReceiptLedger.load().map(\.id), ["in-both"])
    }
}
