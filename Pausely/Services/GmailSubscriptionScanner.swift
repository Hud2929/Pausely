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
    /// Full result of the last analysis: tiers, evidence, lifecycle insights.
    @Published var report: IntelligenceReport?

    struct ScanStats {
        var emailsScanned = 0
        var receiptsFound = 0
        var unknownServicesFound = 0
        var purchasesIgnored = 0
        var confirmed = 0
        /// Emails read in full (the rest were skipped after a cheap header check).
        var bodiesRead = 0
        /// Receipts decided with help from the on-device model.
        var aiAssisted = 0
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

    /// Apple's on-device model, when this iPhone supports it. Nil otherwise; the rules work without it.
    private let ambiguousClassifier: AmbiguousReceiptClassifier? = OnDeviceReceiptClassifier.makeIfAvailable()

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
        report = nil
        lastHistoryId = nil
        ReceiptLedger.clear()
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
                // Full scan: last 2 years, paginate all results
                messageIds = try await fetchAllMessageIds(token: token)
            }

            scanProgress = 0.25
            scanStats.emailsScanned = messageIds.count

            // Each email becomes a tiny on-device "signal"; the intelligence engine decides what truly recurs.
            let catalog = Self.buildCatalog()
            var newSignals: [ReceiptSignal] = []
            var aiBudget = 40
            let batches = stride(from: 0, to: messageIds.count, by: 20).map {
                Array(messageIds[$0..<min($0 + 20, messageIds.count)])
            }

            for (batchIdx, batch) in batches.enumerated() {
                let outcome = await readBatch(batch, token: token, catalog: catalog)
                scanStats.bodiesRead += outcome.bodiesRead

                for result in outcome.results {
                    var signal = result.signal
                    if let excerpt = result.ambiguousExcerpt, let classifier = ambiguousClassifier, aiBudget > 0 {
                        aiBudget -= 1
                        let verdict = await classifier.classify(merchantGuess: result.merchantGuess,
                                                                subject: result.subject, excerpt: excerpt)
                        if verdict != .unsure { scanStats.aiAssisted += 1 }
                        signal = signal.applying(verdict)
                    }
                    newSignals.append(signal)
                }
                scanProgress = 0.25 + (Double(batchIdx + 1) / Double(max(batches.count, 1))) * 0.65
            }

            // Save historyId from the latest message for next incremental sync
            if let newHistoryId = try? await fetchLatestHistoryId(token: token) {
                lastHistoryId = newHistoryId
            }

            // Merge with on-device history so recurrence can be proven across the whole mailbox, then analyze.
            let ledger = ReceiptLedger.merge(newSignals, into: ReceiptLedger.load())
            ReceiptLedger.save(ledger)
            scanProgress = 0.95

            analyzeLedger(ledger, catalog: catalog)
            scanProgress = 1.0

            if foundSubscriptions.isEmpty {
                error = "No recurring subscriptions found in your emails."
            }

        } catch {
            self.error = "Scan failed: \(error.localizedDescription)"
            os_log("Gmail scan error: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    // MARK: - Analysis & learning

    private static func buildCatalog() -> MerchantCatalog {
        let extras = SubscriptionCatalogService.shared.catalog.map {
            (name: $0.name, category: $0.category.rawValue, cancelURL: $0.cancellationURL)
        }
        return MerchantCatalog.builtin.extending(with: extras)
    }

    private func analyzeLedger(_ ledger: [ReceiptSignal], catalog: MerchantCatalog) {
        let engine = SubscriptionIntelligenceEngine(catalog: catalog)
        let analysis = engine.analyze(signals: ledger, now: Date(),
                                      defaultCurrency: CurrencyManager.shared.selectedCurrency,
                                      corrections: UserCorrections.load())
        report = analysis
        foundSubscriptions = analysis.subscriptions.map(Self.makeImport)
        scanStats.confirmed = analysis.subscriptions.filter { $0.tier == .confirmed }.count
        scanStats.receiptsFound = scanStats.confirmed
        scanStats.purchasesIgnored = analysis.ignoredPurchaseGroups
    }

    /// Re-runs detection on the on-device history only. Instant, offline, no email access.
    func reanalyze() {
        analyzeLedger(ReceiptLedger.load(), catalog: Self.buildCatalog())
    }

    /// "This isn't a subscription": remembered forever on this device and applied to every future scan.
    func markNotSubscription(_ subscription: SmartImportManager.ImportSubscription) {
        guard let key = subscription.proven?.merchantKey else { return }
        UserCorrections.set(key, .notSubscription)
        reanalyze()
    }

    func importSubscriptions(_ selected: [SmartImportManager.ImportSubscription]) async -> (added: Int, duplicates: Int) {
        // Importing something confirms it: future scans will always rank it as a subscription.
        for sub in selected { if let key = sub.proven?.merchantKey { UserCorrections.set(key, .trusted) } }
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
        // Layered searches. The first uses Gmail's OWN receipt classifier; the rest catch billing language,
        // lifecycle emails (trials, price changes, cancellations) and the biggest known billers.
        let queries = [
            "category:purchases newer_than:2y",
            "(subscription OR membership OR renewal OR \"auto-renew\" OR \"billing statement\" OR invoice OR receipt) -category:promotions newer_than:2y",
            "(\"your trial\" OR \"free trial\" OR \"trial ends\" OR \"price increase\" OR \"price change\" OR \"subscription has been cancelled\" OR \"subscription has been canceled\" OR \"cancellation\") newer_than:1y",
            "from:(netflix.com OR spotify.com OR apple.com OR google.com OR amazon.com OR openai.com OR anthropic.com OR adobe.com OR microsoft.com OR youtube.com OR disneyplus.com OR hulu.com OR max.com OR paramountplus.com OR dropbox.com OR notion.so OR github.com) (receipt OR invoice OR subscription OR billing OR renewal) newer_than:2y",
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
                if allIds.count >= 800 { return allIds }
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

    private func fetchMessageDetail(id: String, token: String, metadataOnly: Bool = false) async throws -> GmailMessageDetail {
        // metadata = headers + snippet + labels only (cheap triage); full = complete MIME body for real receipts.
        let format = metadataOnly
            ? "format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date"
            : "format=full"
        guard let url = URL(string: "https://www.googleapis.com/gmail/v1/users/me/messages/\(id)?\(format)") else {
            throw ScanError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            if await refreshAccessToken() {
                return try await fetchMessageDetail(id: id, token: accessToken ?? "", metadataOnly: metadataOnly)
            }
            throw ScanError.authExpired
        }

        return try JSONDecoder().decode(GmailMessageDetail.self, from: data)
    }

    // MARK: - Reading emails (metadata first, then only what matters)

    /// Fetches cheap metadata for a batch, reads full bodies only for emails that look financial,
    /// and reduces each to a signal. Email text never outlives this function.
    private func readBatch(_ ids: [String], token: String, catalog: MerchantCatalog) async -> (results: [ExtractionResult], bodiesRead: Int) {
        var metas: [GmailMessageDetail] = []
        await withTaskGroup(of: GmailMessageDetail?.self) { group in
            for id in ids {
                group.addTask { try? await self.fetchMessageDetail(id: id, token: token, metadataOnly: true) }
            }
            for await meta in group { if let meta { metas.append(meta) } }
        }

        let wanted = metas.filter { meta in
            let headers = meta.headerMap
            return EmailTriage.shouldReadBody(from: headers["from"] ?? "", subject: headers["subject"] ?? "",
                                              snippet: meta.snippet ?? "", labelIds: meta.labelIds ?? [], catalog: catalog)
        }.map(\.id)

        var fulls: [GmailMessageDetail] = []
        await withTaskGroup(of: GmailMessageDetail?.self) { group in
            for id in wanted {
                group.addTask { try? await self.fetchMessageDetail(id: id, token: token) }
            }
            for await full in group { if let full { fulls.append(full) } }
        }

        let results = fulls.compactMap { detail -> ExtractionResult? in
            guard let raw = Self.rawEmail(from: detail) else { return nil }
            return EmailSignalExtractor.extract(raw, catalog: catalog)
        }
        return (results, fulls.count)
    }

    private static func rawEmail(from detail: GmailMessageDetail) -> RawEmail? {
        guard let date = detail.emailDate else { return nil }
        let headers = detail.headerMap
        return RawEmail(id: detail.id, date: date, from: headers["from"] ?? "", subject: headers["subject"] ?? "",
                        bodyText: detail.bodyText, bodyHTML: detail.bodyHTML, headers: headers,
                        labelIds: detail.labelIds ?? [])
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
            nextBillingDate: sub.nextBillingDate, confidence: confidence, source: "Gmail", proven: sub)
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
        let labelIds: [String]?
        let snippet: String?
        let payload: Payload

        struct Payload: Decodable {
            let mimeType: String?
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

        /// Lower-cased header name → first value.
        var headerMap: [String: String] {
            var map: [String: String] = [:]
            for header in payload.headers {
                let key = header.name.lowercased()
                if map[key] == nil { map[key] = header.value }
            }
            return map
        }

        /// Readable text: the text/plain part when there is one, otherwise the HTML converted to text.
        var bodyText: String {
            if let plain = firstPart(mimeType: "text/plain") { return plain }
            if let html = bodyHTML { return HTMLText.plain(html) }
            return ""
        }

        /// Raw HTML part, used to read structured receipt markup.
        var bodyHTML: String? { firstPart(mimeType: "text/html") }

        private func firstPart(mimeType wanted: String) -> String? {
            if payload.mimeType == wanted, let data = payload.body?.data, let decoded = Self.decodeBase64URL(data) { return decoded }
            if payload.mimeType == nil, payload.parts == nil, let data = payload.body?.data, let decoded = Self.decodeBase64URL(data) {
                // Single-part message with no declared type: treat as plain text.
                return wanted == "text/plain" ? decoded : nil
            }
            return Self.search(parts: payload.parts, mimeType: wanted)
        }

        private static func search(parts: [Payload.Part]?, mimeType wanted: String) -> String? {
            guard let parts else { return nil }
            for part in parts {
                if part.mimeType == wanted, let data = part.body?.data, let decoded = decodeBase64URL(data) { return decoded }
                if let nested = search(parts: part.parts, mimeType: wanted) { return nested }
            }
            return nil
        }

        private static func decodeBase64URL(_ base64url: String) -> String? {
            // Gmail uses URL-safe base64 (- instead of +, _ instead of /)
            var base64 = base64url.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            while base64.count % 4 != 0 { base64 += "=" }
            guard let data = Data(base64Encoded: base64) else { return nil }
            return String(data: data, encoding: .utf8)
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
