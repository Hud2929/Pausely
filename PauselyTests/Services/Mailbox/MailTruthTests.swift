import XCTest
@testable import Pausely

/// What a test mailbox really contains, written by whoever built it (`scripts/mailtest/make_test_mailbox.py`
/// for the synthetic one; by hand, outside the repository, for a real sample). A scan is judged against it
/// on everything a person would see: the name, the amount, the currency, the billing period and the state.
struct MailTruth: Decodable {
    struct Expected: Decodable {
        var name: String
        var amount: String
        var currency: String
        var period: String
        var state: String
        var minTier: String
        var why: String?
    }
    struct Rejected: Decodable {
        var name: String
        var why: String?
    }

    var now: String?
    var expect: [Expected]
    var reject: [Rejected]

    static func load(_ url: URL) throws -> MailTruth {
        try JSONDecoder().decode(MailTruth.self, from: Data(contentsOf: url))
    }

    /// Noon UTC on the day the mailbox was built for, so dates in it never drift.
    var date: Date? {
        guard let now else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: now + " 12:00")
    }

    struct Score {
        var problems: [String] = []
        var found = 0
        var expected = 0
        var wrongDetail = 0
        var falsePositives: [String] = []
        var summary: String {
            let recall = expected == 0 ? 1 : Double(found) / Double(expected)
            return "found \(found) of \(expected) (\(Int((recall * 100).rounded()))%), wrong details \(wrongDetail), "
                + "false positives \(falsePositives.count)" + (problems.isEmpty ? "" : "\n  - " + problems.joined(separator: "\n  - "))
        }
    }

    private static func tier(_ name: String) -> ProvenSubscription.Tier {
        switch name {
        case "confirmed": return .confirmed
        case "likely": return .likely
        default: return .review
        }
    }

    private static func state(_ status: ProvenSubscription.Status) -> String {
        switch status {
        case .active: return "active"
        case .trial: return "trial"
        case .priceIncreased: return "priceIncreased"
        case .likelyEnded: return "ended"
        case .cancelled: return "cancelled"
        }
    }

    func score(_ report: IntelligenceReport) -> Score {
        var score = Score(expected: expect.count)
        for item in expect {
            guard let sub = report.subscriptions.first(where: { $0.name == item.name }) else {
                score.problems.append("MISSED \(item.name) (\(item.why ?? ""))")
                continue
            }
            score.found += 1
            var wrong: [String] = []
            // A trial has no charge yet; its price is what the email says it will cost.
            if let amount = Decimal(string: item.amount), sub.amount != amount { wrong.append("amount \(sub.amount), not \(item.amount)") }
            if sub.currency != item.currency { wrong.append("currency \(sub.currency), not \(item.currency)") }
            if sub.frequency.rawValue != item.period { wrong.append("period \(sub.frequency.rawValue), not \(item.period)") }
            if Self.state(sub.status) != item.state { wrong.append("state \(Self.state(sub.status)), not \(item.state)") }
            if sub.tier < Self.tier(item.minTier) { wrong.append("shown as \(sub.tier), below \(item.minTier)") }
            if !wrong.isEmpty {
                score.wrongDetail += 1
                score.problems.append("WRONG \(item.name): " + wrong.joined(separator: "; "))
            }
        }
        for item in reject {
            let needle = item.name.lowercased()
            for sub in report.subscriptions where sub.name.lowercased().contains(needle) {
                // "Amazon" is rejected while "Amazon Prime" is expected: an expected name is never a false positive.
                if expect.contains(where: { $0.name == sub.name }) { continue }
                score.falsePositives.append(sub.name)
                score.problems.append("FALSE POSITIVE \(sub.name) as \(sub.tier) (\(item.why ?? ""))")
            }
        }
        let known = Set(expect.map(\.name))
        for sub in report.subscriptions where !known.contains(sub.name) && !score.falsePositives.contains(sub.name) {
            score.falsePositives.append(sub.name)
            score.problems.append("UNEXPECTED \(sub.name) · \(sub.amount) \(sub.currency) · \(sub.frequency.rawValue) · \(sub.tier)")
        }
        return score
    }
}

/// Runs a mailbox folder (the layout the test IMAP server serves) through parse → extract → analyze, the
/// same code a scan runs after it has fetched a message, and holds the result to the mailbox's truth.
///
///     python3 scripts/mailtest/make_test_mailbox.py /tmp/mailbox
///     xcodebuild test … -only-testing:PauselyTests/MailTruthTests TEST_RUNNER_PAUSELY_MAIL_TRUTH_DIR=/tmp/mailbox
final class MailTruthTests: XCTestCase {

    private func environment(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]
        return (value?.isEmpty == false) ? value : nil
    }

    /// Folders a scan never opens (see `IMAPMailboxProvider.searchFolders`).
    private static let skipped: Set<String> = ["trash", "junk", "spam", "sent", "drafts", "html"]

    static func loadMailbox(_ root: URL) throws -> [RawEmail] {
        let manager = FileManager.default
        var files: [URL] = []
        let entries = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])
        for entry in entries.sorted(by: { $0.path < $1.path }) {
            if (try entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                if skipped.contains(entry.lastPathComponent.lowercased()) { continue }
                files += try manager.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "eml" }.sorted { $0.path < $1.path }
            } else if entry.pathExtension == "eml" {
                files.append(entry)
            }
        }
        var emails: [RawEmail] = []
        for file in files {
            let data = try Data(contentsOf: file)
            guard var email = MIMEParser.parse(data, id: file.lastPathComponent) else {
                XCTFail("could not parse \(file.lastPathComponent)")
                continue
            }
            // A scan identifies a receipt by its Message-ID, so a copy in a second folder counts once.
            if let id = MIMEParser.normalizedMessageID(email.headers["message-id"]) { email.id = id }
            emails.append(email)
        }
        return emails
    }

    @MainActor
    func testMailboxFolderMatchesItsTruth() throws {
        guard let path = environment("PAUSELY_MAIL_TRUTH_DIR") else { throw XCTSkip("set PAUSELY_MAIL_TRUTH_DIR") }
        let root = URL(fileURLWithPath: path)
        let truth = try MailTruth.load(root.appendingPathComponent("truth.json"))
        let emails = try Self.loadMailbox(root)
        XCTAssertFalse(emails.isEmpty)

        let catalog = InboxScanner.buildCatalog()
        var lines: [String] = []
        var signals: [ReceiptSignal] = []
        for email in emails {
            if let result = EmailSignalExtractor.extract(email, catalog: catalog) {
                let s = result.signal
                signals.append(s)
                lines.append("SIGNAL \(s.senderDomain) | \(email.subject.prefix(46)) | hint=\(s.merchantHint ?? "-") kind=\(s.kind) "
                             + "amount=\(s.amount.map { "\($0)" } ?? "-") \(s.currency ?? "-") cadence=\(s.cadenceHint?.rawValue ?? "-") "
                             + "platform=\(s.platform) renewal=\(s.renewalLanguage) oneTime=\(s.oneTimeLanguage) promo=\(s.promotional) "
                             + "spoof=\(s.spoofSuspected ?? false)")
            } else {
                lines.append("DROPPED \(email.from.prefix(36)) | \(email.subject.prefix(46))")
            }
        }
        let report = SubscriptionIntelligenceEngine(catalog: catalog)
            .analyze(signals: signals, now: truth.date ?? Date(), defaultCurrency: environment("PAUSELY_MAIL_CURRENCY") ?? "USD")
        lines.append("FOUND \(report.subscriptions.count)")
        for sub in report.subscriptions {
            lines.append("  \(sub.name) · \(sub.amount) \(sub.currency) · \(sub.frequency.rawValue) · \(sub.tier) · \(sub.status) · \(sub.evidence.count) receipts")
        }
        let score = truth.score(report)
        lines.append("SCORE " + score.summary)
        let text = lines.joined(separator: "\n")
        print(text)
        if let report = environment("PAUSELY_REPORT_PATH") { try text.write(toFile: report, atomically: true, encoding: .utf8) }
        XCTAssertTrue(score.problems.isEmpty, score.summary)
    }
}
