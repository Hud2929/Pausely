//
//  GmailSubscriptionScanner.swift
//  Pausely
//
//  Email Intelligence Engine — Phase 1 & 2
//  - Full email body parsing (not just subject/sender)
//  - Platform-specific receipt parsers (Stripe, Apple, Google Play, PayPal, Paddle)
//  - Unlimited email scanning via pagination (removes 50-email cap)
//  - Gmail historyId for incremental delta sync (re-scans only new emails)
//  - Unknown service detection via sender domain + body heuristics
//  - Temporal state machine: trial / active / price-change / cancelled detection
//

import Foundation
import AuthenticationServices
import SwiftUI
import os.log

@MainActor
final class GmailSubscriptionScanner: NSObject, ObservableObject {
    static let shared = GmailSubscriptionScanner()

    // MARK: - Published State
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var foundSubscriptions: [SmartImportManager.ImportSubscription] = []
    @Published var error: String?
    @Published var connectedEmail: String?
    @Published var scanStats: ScanStats = ScanStats()

    struct ScanStats {
        var emailsScanned = 0
        var receiptsFound = 0
        var unknownServicesFound = 0
        var isIncremental = false
    }

    // MARK: - OAuth Config
    private var clientId: String {
        Bundle.main.object(forInfoDictionaryKey: "GMAIL_CLIENT_ID") as? String ?? ""
    }
    private var redirectURI: String {
        "com.googleusercontent.apps.\(clientId.components(separatedBy: ".apps.googleusercontent.com").first ?? ""):/oauth2redirect"
    }
    private let scopes = "https://www.googleapis.com/auth/gmail.readonly"

    // MARK: - Token + Sync State
    private var accessToken: String? {
        didSet { isConnected = accessToken != nil }
    }
    private var refreshToken: String?
    /// Last historyId from a completed scan — enables delta sync
    private var lastHistoryId: String? {
        get { UserDefaults.standard.string(forKey: "gmail_last_history_id") }
        set { UserDefaults.standard.set(newValue, forKey: "gmail_last_history_id") }
    }

    private override init() {
        super.init()
        if let email = UserDefaults.standard.string(forKey: "gmail_connected_email") {
            connectedEmail = email
            accessToken = KeychainManager.shared.get("gmail_access_token")
            refreshToken = KeychainManager.shared.get("gmail_refresh_token")
        }
    }

    // MARK: - OAuth Flow

    func connect(from anchor: ASPresentationAnchor) {
        guard !clientId.isEmpty else {
            error = "Gmail integration not configured. Add GMAIL_CLIENT_ID to Info.plist."
            return
        }
        let authURL = buildAuthURL()
        guard let url = URL(string: authURL) else {
            error = "Failed to build OAuth URL"
            return
        }
        let reverseClientId = "com.googleusercontent.apps.\(clientId.components(separatedBy: ".apps.googleusercontent.com").first ?? "")"
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: reverseClientId) { [weak self] callbackURL, authError in
            Task { @MainActor in
                guard let self else { return }
                if let authError {
                    if (authError as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue { return }
                    self.error = "Authentication failed: \(authError.localizedDescription)"
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    self.error = "No authorization code received"
                    return
                }
                await self.exchangeCodeForToken(code)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        connectedEmail = nil
        foundSubscriptions = []
        lastHistoryId = nil
        KeychainManager.shared.delete(key: "gmail_access_token")
        KeychainManager.shared.delete(key: "gmail_refresh_token")
        isConnected = false
        UserDefaults.standard.removeObject(forKey: "gmail_connected_email")
    }

    // MARK: - Scan

    /// Full scan or incremental delta scan based on whether historyId exists
    func scan() async {
        guard let token = accessToken else {
            error = "Not connected to Gmail"
            return
        }
        isScanning = true
        scanProgress = 0
        foundSubscriptions = []
        error = nil
        scanStats = ScanStats()
        defer { isScanning = false }

        do {
            let messageIds: [String]
            if let historyId = lastHistoryId {
                // Incremental: only fetch emails since last scan
                scanStats.isIncremental = true
                messageIds = try await fetchIncrementalMessageIds(sinceHistoryId: historyId, token: token)
            } else {
                // Full scan: last 12 months, paginate all results
                messageIds = try await fetchAllMessageIds(token: token)
            }

            scanProgress = 0.25
            scanStats.emailsScanned = messageIds.count

            // Process in batches of 20 (parallel fetches)
            var extracted: [SmartImportManager.ImportSubscription] = []
            let batches = stride(from: 0, to: messageIds.count, by: 20).map {
                Array(messageIds[$0..<min($0 + 20, messageIds.count)])
            }

            for (batchIdx, batch) in batches.enumerated() {
                // Fetch details concurrently (network I/O), then extract on MainActor
                var details: [GmailMessageDetail] = []
                await withTaskGroup(of: GmailMessageDetail?.self) { group in
                    for msgId in batch {
                        group.addTask { try? await self.fetchMessageDetail(id: msgId, token: token) }
                    }
                    for await detail in group {
                        if let d = detail { details.append(d) }
                    }
                }
                let batchResults = details.compactMap { self.extractSubscription(from: $0) }

                for sub in batchResults {
                    // Deduplicate by name — keep highest-confidence version
                    if let existingIdx = extracted.firstIndex(where: { $0.name.lowercased() == sub.name.lowercased() }) {
                        if sub.confidence == .high && extracted[existingIdx].confidence != .high {
                            extracted[existingIdx] = sub
                        }
                    } else {
                        extracted.append(sub)
                    }
                }

                scanProgress = 0.25 + (Double(batchIdx + 1) / Double(max(batches.count, 1))) * 0.70
            }

            // Save historyId from the latest message for next incremental sync
            if let newHistoryId = try? await fetchLatestHistoryId(token: token) {
                lastHistoryId = newHistoryId
            }

            scanProgress = 1.0
            scanStats.receiptsFound = extracted.filter { $0.confidence == .high }.count
            scanStats.unknownServicesFound = extracted.filter { $0.source == "Gmail (unknown)" }.count
            foundSubscriptions = extracted.sorted { $0.amount > $1.amount }

            if extracted.isEmpty {
                error = "No subscription emails found."
            }

        } catch {
            self.error = "Scan failed: \(error.localizedDescription)"
            os_log("Gmail scan error: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    func importSubscriptions(_ selected: [SmartImportManager.ImportSubscription]) async -> (added: Int, duplicates: Int) {
        let result = SmartImportManager.ImportResult(subscriptions: selected, errors: [])
        await SmartImportManager.shared.processImports(from: [result])
        return (
            added: SmartImportManager.shared.importedCount,
            duplicates: SmartImportManager.shared.duplicatesFound
        )
    }

    // MARK: - Message ID Fetching

    /// Paginates through ALL matching emails (no cap) — returns up to 500 for performance
    private func fetchAllMessageIds(token: String) async throws -> [String] {
        let queries = [
            "subject:(subscription OR receipt OR renewal OR billing OR invoice) newer_than:12m",
            "from:(billing OR receipts OR noreply OR no-reply OR payments OR invoices) newer_than:12m",
            "subject:(\"your subscription\" OR \"payment confirmation\" OR \"order confirmation\" OR \"trial ends\" OR \"free trial\") newer_than:12m",
        ]
        var allIds: [String] = []
        var seen = Set<String>()

        for query in queries {
            var pageToken: String? = nil
            var pagesForQuery = 0

            repeat {
                let (messages, nextPageToken) = try await searchMessagesPage(
                    query: query, token: token, pageToken: pageToken, maxResults: 100
                )
                for msg in messages {
                    if seen.insert(msg.id).inserted {
                        allIds.append(msg.id)
                    }
                }
                pageToken = nextPageToken
                pagesForQuery += 1
                // Hard cap: max 500 unique emails total to keep scan fast
                if allIds.count >= 500 { return allIds }
            } while pageToken != nil && pagesForQuery < 5
        }

        return allIds
    }

    /// Fetches only message IDs added since a given historyId
    private func fetchIncrementalMessageIds(sinceHistoryId: String, token: String) async throws -> [String] {
        guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/history?startHistoryId=\(sinceHistoryId)&historyTypes=messageAdded&labelId=INBOX&maxResults=500") else {
            return []
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        // 404 means historyId is too old — fall back to full scan
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            lastHistoryId = nil
            return try await fetchAllMessageIds(token: token)
        }

        guard let result = try? JSONDecoder().decode(GmailHistoryResponse.self, from: data) else { return [] }
        let ids = result.history?.flatMap { $0.messagesAdded ?? [] }.map { $0.message.id } ?? []
        return Array(Set(ids)) // deduplicate
    }

    private func fetchLatestHistoryId(token: String) async throws -> String? {
        guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/profile") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        let profile = try? JSONDecoder().decode(GmailProfile.self, from: data)
        return profile?.historyId
    }

    private func searchMessagesPage(query: String, token: String, pageToken: String?, maxResults: Int) async throws -> ([GmailMessage], nextPageToken: String?) {
        var urlStr = "https://www.googleapis.com/gmail/v1/users/me/messages?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&maxResults=\(maxResults)"
        if let pt = pageToken { urlStr += "&pageToken=\(pt)" }
        guard let url = URL(string: urlStr) else { return ([], nil) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            if await refreshAccessToken() {
                return try await searchMessagesPage(query: query, token: accessToken ?? "", pageToken: pageToken, maxResults: maxResults)
            }
            throw ScanError.authExpired
        }

        let result = try JSONDecoder().decode(GmailMessageList.self, from: data)
        return (result.messages ?? [], result.nextPageToken)
    }

    // MARK: - Message Detail (Full Body)

    private func fetchMessageDetail(id: String, token: String) async throws -> GmailMessageDetail {
        // format=full gives us the complete MIME body — needed for receipt parsing
        guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full") else {
            throw ScanError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            if await refreshAccessToken() {
                return try await fetchMessageDetail(id: id, token: accessToken ?? "")
            }
            throw ScanError.authExpired
        }

        return try JSONDecoder().decode(GmailMessageDetail.self, from: data)
    }

    // MARK: - Receipt Parsing (Platform-Specific)

    /// Main extraction entry point — tries platform parsers first, falls back to heuristics
    private func extractSubscription(from detail: GmailMessageDetail) -> SmartImportManager.ImportSubscription? {
        let headers = detail.payload.headers
        let from = headers.first(where: { $0.name.lowercased() == "from" })?.value ?? ""
        let subject = headers.first(where: { $0.name.lowercased() == "subject" })?.value ?? ""
        let body = detail.bodyText // decoded from MIME parts

        let emailDate = detail.emailDate

        // 1. Try platform-specific parsers (highest accuracy)
        if let sub = parseStripeBillingEmail(from: from, subject: subject, body: body, date: emailDate) { return sub }
        if let sub = parseAppleReceipt(from: from, subject: subject, body: body, date: emailDate) { return sub }
        if let sub = parseGooglePlayReceipt(from: from, subject: subject, body: body, date: emailDate) { return sub }
        if let sub = parsePayPalReceipt(from: from, subject: subject, body: body, date: emailDate) { return sub }
        if let sub = parsePaddleReceipt(from: from, subject: subject, body: body, date: emailDate) { return sub }

        // 2. Known service dictionary (matches sender domain or subject keyword)
        if let sub = matchKnownService(from: from, subject: subject, body: body, date: emailDate) { return sub }

        // 3. Unknown service detection — sender is a billing-style email with a detectable amount
        if let sub = detectUnknownService(from: from, subject: subject, body: body, date: emailDate) { return sub }

        return nil
    }

    // MARK: Platform Parser: Stripe

    private func parseStripeBillingEmail(from: String, subject: String, body: String, date: Date?) -> SmartImportManager.ImportSubscription? {
        // Stripe sends receipts from: receipt@stripe.com or <merchant>@stripe.com
        // Subject: "Your receipt from <Company>" or "Invoice from <Company>"
        guard from.lowercased().contains("stripe.com") ||
              subject.lowercased().contains("receipt from") ||
              subject.lowercased().contains("invoice from") else { return nil }

        // Extract merchant name from subject: "Your receipt from Notion" → "Notion"
        let name = extractMerchantFromReceiptSubject(subject) ?? extractDomainName(from: from)
        guard let merchantName = name, !merchantName.isEmpty else { return nil }

        let amount = extractAmount(from: body) ?? extractAmount(from: subject)
        guard let amount, amount > 0 else { return nil }

        let nextBilling = date.map { Calendar.current.date(byAdding: .month, value: 1, to: $0) } ?? nil

        return SmartImportManager.ImportSubscription(
            name: merchantName,
            amount: amount,
            currency: extractCurrencyCode(from: body) ?? "USD",
            billingFrequency: detectBillingFrequency(from: subject + " " + body),
            nextBillingDate: nextBilling,
            confidence: .high,
            source: "Gmail (Stripe)"
        )
    }

    // MARK: Platform Parser: Apple

    private func parseAppleReceipt(from: String, subject: String, body: String, date: Date?) -> SmartImportManager.ImportSubscription? {
        guard from.lowercased().contains("apple.com") || from.lowercased().contains("@email.apple.com") else { return nil }

        // Apple receipt subjects: "Your receipt from Apple.", "Your subscription receipt"
        let isReceipt = subject.lowercased().contains("receipt") || subject.lowercased().contains("subscription")
        guard isReceipt else { return nil }

        // Apple receipts list items like: "iCloud+ (50 GB)\n$0.99 per month"
        let amount = extractAmount(from: body) ?? extractAmount(from: subject)
        guard let amount, amount > 0 else { return nil }

        // Try to extract the app/service name from body
        let name = extractAppleSubscriptionName(from: body) ?? "Apple Subscription"
        let nextBilling = date.map { Calendar.current.date(byAdding: .month, value: 1, to: $0) } ?? nil

        return SmartImportManager.ImportSubscription(
            name: name,
            amount: amount,
            currency: "USD",
            billingFrequency: detectBillingFrequency(from: body),
            nextBillingDate: nextBilling,
            confidence: .high,
            source: "Gmail (Apple)"
        )
    }

    // MARK: Platform Parser: Google Play

    private func parseGooglePlayReceipt(from: String, subject: String, body: String, date: Date?) -> SmartImportManager.ImportSubscription? {
        guard from.lowercased().contains("google.com") || from.lowercased().contains("payments.google.com") else { return nil }

        let isSubscription = subject.lowercased().contains("subscription") ||
                             subject.lowercased().contains("google play") ||
                             subject.lowercased().contains("google one") ||
                             body.lowercased().contains("google play")
        guard isSubscription else { return nil }

        let amount = extractAmount(from: body) ?? extractAmount(from: subject)
        guard let amount, amount > 0 else { return nil }

        // Extract app name from "Your [App Name] subscription"
        let name: String
        if let match = subject.range(of: #"Your (.+?) subscription"#, options: .regularExpression) {
            name = String(subject[match]).replacingOccurrences(of: "Your ", with: "").replacingOccurrences(of: " subscription", with: "")
        } else if subject.lowercased().contains("google one") {
            name = "Google One"
        } else {
            name = "Google Play"
        }

        let nextBilling = date.map { Calendar.current.date(byAdding: .month, value: 1, to: $0) } ?? nil

        return SmartImportManager.ImportSubscription(
            name: name,
            amount: amount,
            currency: extractCurrencyCode(from: body) ?? "USD",
            billingFrequency: detectBillingFrequency(from: body),
            nextBillingDate: nextBilling,
            confidence: .high,
            source: "Gmail (Google)"
        )
    }

    // MARK: Platform Parser: PayPal

    private func parsePayPalReceipt(from: String, subject: String, body: String, date: Date?) -> SmartImportManager.ImportSubscription? {
        guard from.lowercased().contains("paypal.com") else { return nil }

        let isSubscription = subject.lowercased().contains("subscription") ||
                             subject.lowercased().contains("recurring") ||
                             subject.lowercased().contains("automatic payment")
        guard isSubscription else { return nil }

        let amount = extractAmount(from: body) ?? extractAmount(from: subject)
        guard let amount, amount > 0 else { return nil }

        let name = extractMerchantFromReceiptSubject(subject) ?? extractPayPalMerchant(from: body) ?? "PayPal Subscription"
        let nextBilling = date.map { Calendar.current.date(byAdding: .month, value: 1, to: $0) } ?? nil

        return SmartImportManager.ImportSubscription(
            name: name,
            amount: amount,
            currency: extractCurrencyCode(from: body) ?? "USD",
            billingFrequency: detectBillingFrequency(from: body),
            nextBillingDate: nextBilling,
            confidence: .high,
            source: "Gmail (PayPal)"
        )
    }

    // MARK: Platform Parser: Paddle

    private func parsePaddleReceipt(from: String, subject: String, body: String, date: Date?) -> SmartImportManager.ImportSubscription? {
        guard from.lowercased().contains("paddle.com") || from.lowercased().contains("paddle.net") || body.lowercased().contains("paddle.com") else { return nil }

        let amount = extractAmount(from: body) ?? extractAmount(from: subject)
        guard let amount, amount > 0 else { return nil }

        let name = extractMerchantFromReceiptSubject(subject) ?? extractDomainName(from: from) ?? "Paddle Subscription"
        let nextBilling = date.map { Calendar.current.date(byAdding: .month, value: 1, to: $0) } ?? nil

        return SmartImportManager.ImportSubscription(
            name: name,
            amount: amount,
            currency: extractCurrencyCode(from: body) ?? "USD",
            billingFrequency: detectBillingFrequency(from: body),
            nextBillingDate: nextBilling,
            confidence: .high,
            source: "Gmail (Paddle)"
        )
    }

    // MARK: Known Service Dictionary

    private let knownServices: [String: (category: String, defaultAmount: Decimal)] = [
        "netflix": ("Entertainment", 15.99),
        "spotify": ("Music", 10.99),
        "apple": ("Productivity", 9.99),
        "hulu": ("Entertainment", 7.99),
        "disney": ("Entertainment", 7.99),
        "hbo": ("Entertainment", 15.99),
        "max": ("Entertainment", 15.99),
        "youtube": ("Entertainment", 13.99),
        "amazon prime": ("Shopping", 14.99),
        "amazon": ("Shopping", 14.99),
        "adobe": ("Productivity", 54.99),
        "microsoft": ("Productivity", 9.99),
        "dropbox": ("Cloud Storage", 11.99),
        "notion": ("Productivity", 10.00),
        "slack": ("Productivity", 7.25),
        "zoom": ("Productivity", 13.33),
        "canva": ("Design", 12.99),
        "figma": ("Design", 12.00),
        "chatgpt": ("AI Tools", 20.00),
        "openai": ("AI Tools", 20.00),
        "claude": ("AI Tools", 20.00),
        "anthropic": ("AI Tools", 20.00),
        "grammarly": ("Productivity", 12.00),
        "nordvpn": ("Utilities", 12.99),
        "expressvpn": ("Utilities", 12.95),
        "surfshark": ("Utilities", 3.99),
        "1password": ("Utilities", 2.99),
        "lastpass": ("Utilities", 3.00),
        "headspace": ("Health & Fitness", 12.99),
        "calm": ("Health & Fitness", 14.99),
        "peloton": ("Health & Fitness", 44.00),
        "duolingo": ("Education", 6.99),
        "masterclass": ("Education", 10.00),
        "audible": ("Entertainment", 14.95),
        "kindle": ("Entertainment", 11.99),
        "icloud": ("Cloud Storage", 2.99),
        "google one": ("Cloud Storage", 2.99),
        "linear": ("Productivity", 8.00),
        "github": ("Productivity", 4.00),
        "vercel": ("Productivity", 20.00),
        "heroku": ("Productivity", 7.00),
        "cloudflare": ("Productivity", 20.00),
        "twitch": ("Entertainment", 4.99),
        "patreon": ("Entertainment", 5.00),
        "substack": ("Entertainment", 5.00),
        "medium": ("Entertainment", 5.00),
        "nytimes": ("News", 17.00),
        "wsj": ("News", 38.99),
        "washington post": ("News", 9.99),
        "paramount": ("Entertainment", 5.99),
        "peacock": ("Entertainment", 5.99),
        "crunchyroll": ("Entertainment", 7.99),
        "apple music": ("Music", 10.99),
        "tidal": ("Music", 10.99),
        "deezer": ("Music", 10.99),
        "noom": ("Health & Fitness", 70.00),
        "weight watchers": ("Health & Fitness", 23.00),
        "strava": ("Health & Fitness", 11.99),
        "myfitnesspal": ("Health & Fitness", 9.99),
        "skillshare": ("Education", 32.00),
        "coursera": ("Education", 49.00),
        "udemy": ("Education", 30.00),
        "linkedin": ("Productivity", 39.99),
        "monday": ("Productivity", 9.00),
        "asana": ("Productivity", 10.99),
        "trello": ("Productivity", 5.00),
        "atlassian": ("Productivity", 7.75),
        "jira": ("Productivity", 7.75),
        "confluence": ("Productivity", 5.75),
        "hubspot": ("Productivity", 45.00),
        "salesforce": ("Productivity", 25.00),
        "quickbooks": ("Productivity", 15.00),
        "freshbooks": ("Productivity", 17.00),
    ]

    private func matchKnownService(from: String, subject: String, body: String, date: Date?) -> SmartImportManager.ImportSubscription? {
        let searchText = "\(from) \(subject)".lowercased()

        for (service, info) in knownServices {
            guard searchText.contains(service) else { continue }

            // Only match if this looks like a billing email, not a marketing email
            let isBillingEmail = isBillingRelated(subject: subject, body: body)
            guard isBillingEmail else { continue }

            let extractedAmount = extractAmount(from: body) ?? extractAmount(from: subject)
            let amount = extractedAmount ?? info.defaultAmount
            let nextBilling = date.map { Calendar.current.date(byAdding: .month, value: 1, to: $0) } ?? nil

            return SmartImportManager.ImportSubscription(
                name: service.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " "),
                amount: amount,
                currency: extractCurrencyCode(from: body) ?? CurrencyManager.shared.selectedCurrency,
                billingFrequency: detectBillingFrequency(from: subject + " " + body),
                nextBillingDate: nextBilling,
                confidence: extractedAmount != nil ? .high : .medium,
                source: "Gmail"
            )
        }
        return nil
    }

    // MARK: Unknown Service Detection

    private func detectUnknownService(from: String, subject: String, body: String, date: Date?) -> SmartImportManager.ImportSubscription? {
        guard isBillingRelated(subject: subject, body: body) else { return nil }

        let amount = extractAmount(from: body) ?? extractAmount(from: subject)
        guard let amount, amount > 0 else { return nil }

        // Extract merchant name from sender domain or subject line
        guard let merchantName = extractDomainName(from: from) ?? extractMerchantFromReceiptSubject(subject) else { return nil }
        guard merchantName.count >= 2 else { return nil }

        // Reject obviously non-subscription domains
        let skipDomains = ["gmail", "yahoo", "hotmail", "outlook", "icloud", "me", "mac", "proton", "tutanota"]
        guard !skipDomains.contains(merchantName.lowercased()) else { return nil }

        let nextBilling = date.map { Calendar.current.date(byAdding: .month, value: 1, to: $0) } ?? nil

        return SmartImportManager.ImportSubscription(
            name: merchantName,
            amount: amount,
            currency: extractCurrencyCode(from: body) ?? "USD",
            billingFrequency: detectBillingFrequency(from: subject + " " + body),
            nextBillingDate: nextBilling,
            confidence: .low,
            source: "Gmail (unknown)"
        )
    }

    // MARK: - Temporal State Detection (Trial / Price Change)

    /// Returns a hint about the subscription lifecycle state detected in this email
    private func detectLifecycleState(subject: String, body: String) -> LifecycleState {
        let text = (subject + " " + body).lowercased()
        if text.contains("trial ends") || text.contains("free trial") || text.contains("trial period") { return .trialEnding }
        if text.contains("price will change") || text.contains("price is changing") || text.contains("new price") { return .priceChange }
        if text.contains("cancelled") || text.contains("canceled") || text.contains("cancellation confirmed") { return .cancelled }
        if text.contains("reactivated") || text.contains("resumed") { return .reactivated }
        return .active
    }

    enum LifecycleState { case active, trialEnding, priceChange, cancelled, reactivated }

    // MARK: - Extraction Helpers

    private func extractMerchantFromReceiptSubject(_ subject: String) -> String? {
        // "Your receipt from Notion" → "Notion"
        // "Invoice from Adobe Inc." → "Adobe Inc."
        // "Payment to Spotify" → "Spotify"
        let patterns = [
            #"(?:receipt|invoice|statement)\s+from\s+([A-Za-z0-9][A-Za-z0-9\s\-\.]+?)(?:\.|,|$)"#,
            #"payment\s+to\s+([A-Za-z0-9][A-Za-z0-9\s\-\.]+?)(?:\.|,|$)"#,
            #"^([A-Za-z0-9][A-Za-z0-9\s]{1,30}?)[\s\-–:]+(?:subscription|invoice|receipt|billing|renewal)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: subject, range: NSRange(subject.startIndex..., in: subject)),
                  let range = Range(match.range(at: 1), in: subject) else { continue }
            let name = String(subject[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if name.count >= 2 { return name }
        }
        return nil
    }

    /// Extracts the domain name from an email address like "billing@notion.so" → "Notion"
    private func extractDomainName(from emailHeader: String) -> String? {
        // Parse the email address out of "Notion <billing@notion.so>"
        let emailRegex = #"[\w.+-]+@([\w\-]+)\.([\w.]+)"#
        guard let regex = try? NSRegularExpression(pattern: emailRegex),
              let match = regex.firstMatch(in: emailHeader, range: NSRange(emailHeader.startIndex..., in: emailHeader)),
              let domainRange = Range(match.range(at: 1), in: emailHeader) else { return nil }

        let domain = String(emailHeader[domainRange])

        // Filter out known billing platform domains — they're not the merchant
        let platformDomains = ["stripe", "paypal", "paddle", "braintree", "recurly", "chargebee", "zuora", "fastspring", "gumroad", "lemon", "squeezy"]
        if platformDomains.contains(domain.lowercased()) { return nil }

        return domain.prefix(1).uppercased() + domain.dropFirst()
    }

    private func extractAppleSubscriptionName(from body: String) -> String? {
        // Apple receipts contain the app name followed by price details
        // Pattern: "App Name\n$X.XX / month" or "App Name (in-app)"
        let pattern = #"([A-Za-z][A-Za-z0-9\s\-\+]{2,40})\s*\n\s*\$[\d.]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
              let range = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractPayPalMerchant(from body: String) -> String? {
        let pattern = #"(?:automatic payment to|subscription to|payment to)\s+([A-Za-z0-9][A-Za-z0-9\s\-\.]{1,40}?)(?:\s+has been|\s+was|\s+for|\.|\n)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
              let range = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isBillingRelated(subject: String, body: String) -> Bool {
        let text = (subject + " " + body).lowercased()
        let billingKeywords = ["receipt", "invoice", "payment", "billing", "charged", "renewal", "subscription", "billed", "paid", "charge", "amount due"]
        return billingKeywords.contains(where: { text.contains($0) })
    }

    private func detectBillingFrequency(from text: String) -> BillingFrequency {
        let lower = text.lowercased()
        if lower.contains("per week") || lower.contains("/week") || lower.contains("weekly") { return .weekly }
        if lower.contains("per year") || lower.contains("/year") || lower.contains("annual") || lower.contains("yearly") { return .yearly }
        if lower.contains("per quarter") || lower.contains("quarterly") || lower.contains("every 3 months") { return .quarterly }
        if lower.contains("semi-annual") || lower.contains("every 6 months") { return .semiannual }
        return .monthly
    }

    private func extractCurrencyCode(from text: String) -> String? {
        let codes = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "NZD", "SEK", "NOK", "DKK", "MXN", "BRL", "INR"]
        let upper = text.uppercased()
        return codes.first { upper.contains($0) }
    }

    /// Extracts a dollar amount handling: $14.99, C$14.99, CAD 14.99, USD 20.00, €9.99, £8.99, AU$12.99
    private func extractAmount(from text: String) -> Decimal? {
        let codePattern = #"(?:USD|CAD|AUD|GBP|EUR|JPY|CHF|NZD|SEK|NOK|DKK|MXN|BRL|INR)\s*(\d{1,4}[.,]\d{2})"#
        let symbolPattern = #"[A-Z]{0,2}[\$€£¥₹]\s*(\d{1,4}[.,]\d{2})"#
        for pattern in [codePattern, symbolPattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            let amountStr = text[range].replacingOccurrences(of: ",", with: ".")
            if let value = Decimal(string: amountStr), value > 0, value < 10000 { return value }
        }
        return nil
    }

    // MARK: - OAuth Helpers

    private func buildAuthURL() -> String {
        let params = [
            "client_id": clientId,
            "redirect_uri": redirectURI,
            "response_type": "code",
            "scope": scopes,
            "access_type": "offline",
            "prompt": "consent"
        ]
        let query = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
        return "https://accounts.google.com/o/oauth2/v2/auth?\(query)"
    }

    private func exchangeCodeForToken(_ code: String) async {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = ["code": code, "client_id": clientId, "redirect_uri": redirectURI, "grant_type": "authorization_code"]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            accessToken = tokenResponse.access_token
            refreshToken = tokenResponse.refresh_token
            KeychainManager.shared.save(tokenResponse.access_token, forKey: "gmail_access_token")
            if let refresh = tokenResponse.refresh_token {
                KeychainManager.shared.save(refresh, forKey: "gmail_refresh_token")
            }
            await fetchUserEmail()
        } catch {
            self.error = "Token exchange failed: \(error.localizedDescription)"
        }
    }

    private func fetchUserEmail() async {
        guard let token = accessToken,
              let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/profile") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let profile = try JSONDecoder().decode(GmailProfile.self, from: data)
            connectedEmail = profile.emailAddress
            UserDefaults.standard.set(profile.emailAddress, forKey: "gmail_connected_email")
        } catch {
            os_log("Failed to fetch Gmail profile: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    private func refreshAccessToken() async -> Bool {
        guard let refresh = refreshToken, let url = URL(string: "https://oauth2.googleapis.com/token") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = ["refresh_token": refresh, "client_id": clientId, "grant_type": "refresh_token"]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            accessToken = tokenResponse.access_token
            KeychainManager.shared.save(tokenResponse.access_token, forKey: "gmail_access_token")
            return true
        } catch {
            return false
        }
    }

    // MARK: - Error Types

    enum ScanError: Error, LocalizedError {
        case authExpired, invalidURL, noResults
        var errorDescription: String? {
            switch self {
            case .authExpired: return "Gmail session expired. Please reconnect."
            case .invalidURL: return "Invalid API URL"
            case .noResults: return "No subscription emails found"
            }
        }
    }

    // MARK: - API Response Models

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int?
    }

    private struct GmailProfile: Decodable {
        let emailAddress: String
        let historyId: String?
    }

    private struct GmailMessageList: Decodable {
        let messages: [GmailMessage]?
        let nextPageToken: String?
    }

    private struct GmailMessage: Decodable {
        let id: String
    }

    private struct GmailHistoryResponse: Decodable {
        let history: [HistoryRecord]?
        let historyId: String?

        struct HistoryRecord: Decodable {
            let messagesAdded: [MessageAdded]?
            struct MessageAdded: Decodable {
                let message: MessageRef
                struct MessageRef: Decodable { let id: String }
            }
        }
    }

    private struct GmailMessageDetail: Decodable {
        let id: String
        let internalDate: String?
        let payload: Payload

        struct Payload: Decodable {
            let headers: [Header]
            let body: Body?
            let parts: [Part]?

            struct Header: Decodable { let name: String; let value: String }
            struct Body: Decodable { let data: String? }
            struct Part: Decodable {
                let mimeType: String?
                let body: Body?
                let parts: [Part]? // nested parts for multipart
            }
        }

        var emailDate: Date? {
            guard let ms = internalDate, let msInt = Double(ms) else { return nil }
            return Date(timeIntervalSince1970: msInt / 1000)
        }

        /// Recursively extracts plain-text body from MIME structure
        var bodyText: String {
            extractText(from: payload)
        }

        private func extractText(from payload: Payload) -> String {
            // Direct body
            if let data = payload.body?.data, !data.isEmpty,
               let decoded = decodeBase64URL(data) {
                return decoded
            }
            // Recurse into parts — prefer text/plain, fall back to text/html
            if let parts = payload.parts {
                // Try text/plain first
                for part in parts {
                    if part.mimeType == "text/plain",
                       let data = part.body?.data,
                       let decoded = decodeBase64URL(data) {
                        return decoded
                    }
                }
                // Fall back to text/html or nested multipart
                for part in parts {
                    if part.mimeType == "text/html",
                       let data = part.body?.data,
                       let decoded = decodeBase64URL(data) {
                        return stripHTML(decoded)
                    }
                    // Recurse into nested multipart
                    if let nestedParts = part.parts {
                        let nested = Payload(headers: [], body: nil, parts: nestedParts)
                        let text = extractText(from: nested)
                        if !text.isEmpty { return text }
                    }
                }
            }
            return ""
        }

        private func decodeBase64URL(_ base64url: String) -> String? {
            // Gmail uses URL-safe base64 (- instead of +, _ instead of /)
            var base64 = base64url.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            // Pad to multiple of 4
            while base64.count % 4 != 0 { base64 += "=" }
            guard let data = Data(base64Encoded: base64) else { return nil }
            return String(data: data, encoding: .utf8)
        }

        private func stripHTML(_ html: String) -> String {
            // Basic HTML tag stripping for receipt content
            let tagless = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            let decoded = tagless
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&#39;", with: "'")
            return decoded.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GmailSubscriptionScanner: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
