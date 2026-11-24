#if DEBUG
import Foundation

extension InboxScanner {
    /// DEBUG only. Fills the results screen with a synthetic mailbox so the experience can be reviewed
    /// without a Google sign-in. Launch the app with `--demo-gmail-results`. Compiled out of release builds.
    func loadDemoResults() {
        let calendar = Calendar.billing
        let now = Date()
        var signals: [ReceiptSignal] = []
        var counter = 0

        func date(monthsAgo: Int, daysAgo: Int) -> Date {
            let base = calendar.date(byAdding: .month, value: -monthsAgo, to: now) ?? now
            return calendar.date(byAdding: .day, value: -daysAgo, to: base) ?? base
        }

        func add(_ domain: String, _ name: String, monthsAgo: Int, daysAgo: Int, amount: Decimal?, hint: String? = nil,
                 kind: EmailKind = .charge, renewal: Bool = true, oneTime: Bool = false, platform: String = "direct",
                 trialDays: Int? = nil, cadence: BillingFrequency? = nil) {
            counter += 1
            signals.append(ReceiptSignal(
                id: "demo-\(counter)", date: date(monthsAgo: monthsAgo, daysAgo: daysAgo), senderDomain: domain, senderName: name,
                merchantHint: hint, platform: platform, kind: kind, amount: amount, currency: "CAD", cadenceHint: cadence,
                trialDays: trialDays, renewalLanguage: renewal, oneTimeLanguage: oneTime, promotional: false))
        }

        // Real subscriptions
        for m in 0..<6 { add("netflix.com", "Netflix", monthsAgo: m, daysAgo: 12, amount: 16.49) }
        for m in 1..<4 { add("spotify.com", "Spotify", monthsAgo: m, daysAgo: 5, amount: 11.99) }
        add("spotify.com", "Spotify", monthsAgo: 0, daysAgo: 5, amount: 12.99)
        for m in 0..<4 { add("apple.com", "Apple", monthsAgo: m, daysAgo: 3, amount: 3.99, hint: "iCloud+", platform: "apple") }
        for m in 0..<4 { add("amazon.ca", "Amazon.ca", monthsAgo: m, daysAgo: 9, amount: 9.99, hint: "Amazon Prime") }
        for m in 0..<4 { add("ironsidefitness.ca", "Ironside Fitness", monthsAgo: m, daysAgo: 3, amount: 34.99) }
        add("adobe.com", "Adobe", monthsAgo: 12, daysAgo: -20, amount: 779.88)
        add("adobe.com", "Adobe", monthsAgo: 24, daysAgo: -20, amount: 779.88)
        add("notion.so", "Notion", monthsAgo: 0, daysAgo: 2, amount: nil, kind: .trialStarted, trialDays: 14)
        for m in 6..<9 { add("hulu.com", "Hulu", monthsAgo: m, daysAgo: 8, amount: 11.99) }
        for m in 3..<6 { add("disneyplus.com", "Disney+", monthsAgo: m, daysAgo: 12, amount: 11.99) }
        add("disneyplus.com", "Disney+", monthsAgo: 3, daysAgo: 2, amount: nil, kind: .cancellation, renewal: false)

        // Things a naive scanner would have listed
        for (m, d, amount) in [(0, 4, "42.17"), (1, 14, "18.99"), (2, 22, "126.40"), (3, 9, "33.15"), (4, 1, "64.80")] {
            add("amazon.ca", "Amazon.ca", monthsAgo: m, daysAgo: d, amount: Decimal(string: amount), renewal: false, oneTime: true)
        }
        for (m, d, amount) in [(0, 6, "39.25"), (1, 11, "27.30"), (2, 17, "12.90"), (3, 29, "48.04"), (4, 4, "21.50")] {
            add("doordash.com", "DoorDash", monthsAgo: m, daysAgo: d, amount: Decimal(string: amount), renewal: false, oneTime: true)
        }
        for (m, d, amount) in [(0, 2, "19.35"), (1, 9, "27.60"), (2, 3, "12.95"), (3, 7, "31.80")] {
            add("uber.com", "Uber Receipts", monthsAgo: m, daysAgo: d, amount: Decimal(string: amount), renewal: false, oneTime: true)
        }
        add("frontgatetickets.com", "Frontgate Tickets", monthsAgo: 4, daysAgo: 1, amount: 394.99, renewal: false, oneTime: true)

        let analysis = SubscriptionIntelligenceEngine().analyze(signals: signals, now: now, defaultCurrency: "CAD")
        presentDemo(analysis, account: MailboxAccount(id: "demo", kind: .imap, address: "demo@pausely.app",
                                                      presetID: "icloud", host: "imap.mail.me.com", addedAt: now),
                    checked: 312, read: 87)
    }

    /// DEBUG only. The page with inboxes connected and nothing found, which no search of a
    /// made-up mailbox reaches: `--demo-inbox=connected` (not searched yet), `=nothing` (searched,
    /// nothing found) or `=failed` (one inbox refused the search).
    func loadDemoConnected(_ state: String) {
        let demo = Self.demoInboxes(state, now: Date())
        presentDemo(connected: demo.accounts, outcome: demo.outcome, refused: demo.refused, checked: demo.checked)
    }

    /// What `loadDemoConnected` puts on the page: two inboxes (one with an address long enough to
    /// wrap), what the search reported, and which inbox refused it.
    struct DemoInboxes {
        let accounts: [MailboxAccount]
        let outcome: String?
        let refused: [String: String]
        let checked: Int
    }

    nonisolated static func demoInboxes(_ state: String, now: Date) -> DemoInboxes {
        let searched = state == "connected" ? nil : now.addingTimeInterval(-2 * 3600)
        let inboxes = [
            MailboxAccount(id: "demo-icloud", kind: .imap, address: "jane.doe@icloud.com", presetID: "icloud",
                           host: "imap.mail.me.com", addedAt: now, lastScan: searched),
            MailboxAccount(id: "demo-work", kind: .imap, address: "jane.doe@longer-company-name.example.co.uk",
                           presetID: "fastmail", host: "imap.fastmail.com", addedAt: now, lastScan: searched)
        ]
        switch state {
        case "nothing":
            return DemoInboxes(accounts: inboxes, outcome: L10n.string("No subscriptions found"), refused: [:], checked: 312)
        case "failed":
            return DemoInboxes(accounts: inboxes, outcome: L10n.string("The search couldn't be finished"),
                               refused: ["demo-work": MailboxError.authExpired.localizedDescription], checked: 140)
        default:
            return DemoInboxes(accounts: inboxes, outcome: nil, refused: [:], checked: 0)
        }
    }
}
#endif
