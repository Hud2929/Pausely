import Foundation

/// Gmail through the Gmail API, read-only (`gmail.readonly`). Whole messages are read as raw MIME so every
/// provider goes through the same parser (and every character set is decoded correctly).
@MainActor
final class GmailMailboxProvider: MailboxProvider {
    let account: MailboxAccount

    static let api = "https://gmail.googleapis.com/gmail/v1/users/me"

    init(account: MailboxAccount) {
        self.account = account
    }

    static var clientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "GMAIL_CLIENT_ID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isConfigured: Bool { clientID.hasSuffix(".apps.googleusercontent.com") }

    static var oauth: OAuthSession.Provider {
        let prefix = clientID.components(separatedBy: ".apps.googleusercontent.com").first ?? ""
        let scheme = "com.googleusercontent.apps.\(prefix)"
        return OAuthSession.Provider(
            authorizeURL: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
            tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
            clientID: clientID,
            redirectURI: "\(scheme):/oauth2redirect",
            callbackScheme: scheme,
            scopes: ["https://www.googleapis.com/auth/gmail.readonly"],
            extraAuthorizeParameters: ["access_type": "offline", "prompt": "consent"])
    }

    // MARK: - Connecting

    @MainActor
    static func connect() async throws -> MailboxAccount {
        guard isConfigured else { throw MailboxError.notConfigured(L10n.string("Gmail sign-in isn't set up in this build.")) }
        return try await finishConnect(try await OAuthSession.signIn(oauth))
    }

    /// After sign-in: read the address, then save the account. The tokens are discarded if anything fails.
    static func finishConnect(_ tokens: OAuthSession.Tokens) async throws -> MailboxAccount {
        let id = UUID().uuidString
        OAuthSession.store(tokens, for: id)
        do {
            let request = URLRequest(url: URL(string: api + "/profile")!)
            let data = try await MailboxHTTP.data(request, token: { tokens.accessToken }, refresh: { throw MailboxError.authExpired })
            let profile = try JSONDecoder().decode(Profile.self, from: data)
            let account = MailboxAccount(id: id, kind: .gmail, address: profile.emailAddress, addedAt: Date())
            MailboxAccountStore.upsert(account)
            return account
        } catch {
            MailboxAccountStore.remove(id)
            throw error
        }
    }

    // MARK: - MailboxProvider

    func open() async throws {
        _ = try await token()
    }

    func candidates(plan: InboxSearchPlan, cursor: String?) async throws -> (refs: [MessageRef], cursor: String?) {
        if let historyID = cursor, !historyID.isEmpty {
            if let added = try await historySince(historyID) {
                let latest = try? await currentHistoryID()
                return (Array(added.prefix(plan.maxCandidates)).map { MessageRef(id: $0) }, latest ?? historyID)
            }
            // The history id expired (Gmail keeps about a week): fall back to a full search.
        }
        var ids: [String] = []
        var seen = Set<String>()
        for query in Self.searchQueries(plan) {
            try Task.checkCancellation()
            var pageToken: String?
            var pages = 0
            repeat {
                var components = URLComponents(string: Self.api + "/messages")!
                var items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "maxResults", value: "100")]
                if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
                components.queryItems = items
                let list = try JSONDecoder().decode(MessageList.self, from: try await get(components.url!))
                for message in list.messages ?? [] where seen.insert(message.id).inserted { ids.append(message.id) }
                pageToken = list.nextPageToken
                pages += 1
            } while pageToken != nil && pages < 5 && ids.count < plan.maxCandidates
            if ids.count >= plan.maxCandidates { break }
        }
        let latest = try? await currentHistoryID()
        return (ids.prefix(plan.maxCandidates).map { MessageRef(id: $0) }, latest)
    }

    /// Gmail's own purchase classification first, then billing language, lifecycle mail, senders and
    /// subject words in every supported language.
    static func searchQueries(_ plan: InboxSearchPlan) -> [String] {
        let after = "after:" + gmailDate(plan.since)
        var queries = [
            "category:purchases \(after)",
            "(subscription OR membership OR renewal OR \"auto-renew\" OR \"billing statement\" OR invoice OR receipt) -category:promotions \(after)",
            "(\"your trial\" OR \"free trial\" OR \"trial ends\" OR \"price increase\" OR \"price change\" OR \"subscription has been cancelled\" OR \"subscription has been canceled\" OR \"payment failed\") \(after)"
        ]
        for batch in InboxSearchPlan.batches(plan.platformDomains + plan.billerDomains, size: 30) {
            queries.append("from:(" + batch.joined(separator: " OR ") + ") \(after)")
        }
        let words = plan.subjectTerms.map { $0.contains(" ") ? "\"\($0)\"" : $0 }
        for batch in InboxSearchPlan.batches(words, size: 15) {
            queries.append("subject:(" + batch.joined(separator: " OR ") + ") -category:promotions \(after)")
        }
        return queries
    }

    static func gmailDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    /// How many header requests are in flight at once. Gmail allows about 250 quota units a second per
    /// person and a header read costs 5; twenty at a time had two thirds of a real inbox turned away.
    static let parallelHeaderReads = 10

    /// Gmail allows each person about 250 quota units a second, and a header or message read costs 5.
    /// Requests start at most 40 a second (25 ms apart), so the limit is never met: backing off it after
    /// the fact took a real scan of 1,500 emails over eight minutes (2026-11-18).
    static let minimumGap: TimeInterval = 0.025
    private var nextStart = Date.distantPast
    /// What Google allows one person varies, and the scan finds it: every refusal halves how many
    /// requests are in flight and doubles the gap between them; twenty answers in a row win one back.
    /// At a fixed 40 a second, ten at a time, a real inbox met 937 refusals in 2,934 requests and spent
    /// seven and a half minutes (2026-11-22).
    private var gap = GmailMailboxProvider.minimumGap
    private var inFlightLimit = GmailMailboxProvider.parallelHeaderReads
    private var answeredInARow = 0

    private func slowDown() {
        gap = min(gap * 2, 2)
        inFlightLimit = max(1, inFlightLimit / 2)
        answeredInARow = 0
    }

    private func answered() {
        answeredInARow += 1
        guard answeredInARow >= 20 else { return }
        answeredInARow = 0
        gap = max(Self.minimumGap, gap * 0.8)
        inFlightLimit = min(Self.parallelHeaderReads, inFlightLimit + 1)
    }

    /// Runs `work` for every ref with as many in flight as Google currently allows, a new one starting as
    /// each answers.
    private func paced<T: Sendable>(_ refs: [MessageRef], _ work: @escaping @Sendable (MessageRef) async -> T?) async -> [(MessageRef, T?)] {
        var out: [(MessageRef, T?)] = []
        var queue = refs[...]
        var inFlight = 0
        await withTaskGroup(of: (MessageRef, T?).self) { group in
            while inFlight < inFlightLimit, let ref = queue.popFirst() {
                inFlight += 1
                group.addTask { (ref, await work(ref)) }
            }
            for await result in group {
                inFlight -= 1
                out.append(result)
                while !Task.isCancelled, inFlight < inFlightLimit, let next = queue.popFirst() {
                    inFlight += 1
                    group.addTask { (next, await work(next)) }
                }
            }
        }
        return out
    }

    var parallelReads: Int { Self.parallelHeaderReads }

    /// Several whole messages at once (the requests are paced, so Google's limit is never met).
    func rawMessages(_ refs: [MessageRef]) async -> [MessageRef: Data] {
        var out: [MessageRef: Data] = [:]
        for (ref, raw) in await paced(refs, { try? await self.rawMessage($0) }) { if let raw { out[ref] = raw } }
        return out
    }

    private func pace() async throws {
        let now = Date()
        let start = max(now, nextStart)
        nextStart = start.addingTimeInterval(gap)
        let wait = start.timeIntervalSince(now)
        if wait > 0 { try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
    }

    func summaries(_ refs: [MessageRef]) async throws -> [MessageSummary] {
        var results: [MessageSummary] = []
        var missed: [MessageRef] = []
        // As many in flight as Google allows (a new one starting as each answers), within the pace above.
        try Task.checkCancellation()
        for (ref, summary) in await paced(refs, { try? await self.metadata($0) }) {
            if let summary { results.append(summary) } else { missed.append(ref) }
        }
        try Task.checkCancellation()
        // What Gmail turned away while busy is asked for again, one at a time, instead of being dropped
        // unsaid. Access that really was withdrawn now says so rather than ending as "nothing found".
        for ref in missed {
            try Task.checkCancellation()
            do {
                results.append(try await metadata(ref))
            } catch MailboxError.authExpired {
                throw MailboxError.authExpired
            } catch {
                continue
            }
        }
        return results
    }

    private func metadata(_ ref: MessageRef) async throws -> MessageSummary {
        var components = URLComponents(string: Self.api + "/messages/\(ref.id)")!
        components.queryItems = [URLQueryItem(name: "format", value: "metadata")]
            + ["From", "Subject", "Date", "Message-ID"].map { URLQueryItem(name: "metadataHeaders", value: $0) }
        let detail = try JSONDecoder().decode(MessageDetail.self, from: try await get(components.url!))
        let headers = detail.headerMap
        return MessageSummary(ref: ref, from: headers["from"] ?? "", subject: headers["subject"] ?? "",
                              snippet: detail.snippet ?? "", labelIds: detail.labelIds ?? [],
                              receivedDate: detail.receivedDate,
                              messageID: MIMEParser.normalizedMessageID(headers["message-id"]))
    }

    func rawMessage(_ ref: MessageRef) async throws -> Data? {
        var components = URLComponents(string: Self.api + "/messages/\(ref.id)")!
        components.queryItems = [URLQueryItem(name: "format", value: "raw")]
        struct Raw: Decodable { let raw: String? }
        let raw = try JSONDecoder().decode(Raw.self, from: try await get(components.url!))
        return raw.raw.flatMap(OAuthSession.decodeBase64URL)
    }

    func close() async {}

    /// Revokes Pausely's access at Google, so the token is useless even if it were ever copied.
    func revoke() async {
        guard let tokens = OAuthSession.load(for: account.id) else { return }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(OAuthSession.formEncode(["token": tokens.refreshToken ?? tokens.accessToken]).utf8)
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - History (only new mail)

    private func historySince(_ historyID: String) async throws -> [String]? {
        var ids: [String] = []
        var pageToken: String?
        var pages = 0
        repeat {
            var components = URLComponents(string: Self.api + "/history")!
            var items = [URLQueryItem(name: "startHistoryId", value: historyID),
                         URLQueryItem(name: "historyTypes", value: "messageAdded"),
                         URLQueryItem(name: "maxResults", value: "500")]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = items
            let data: Data
            do { data = try await get(components.url!) } catch MailboxError.notFound { return nil }
            let page = try JSONDecoder().decode(HistoryPage.self, from: data)
            for record in page.history ?? [] {
                for added in record.messagesAdded ?? [] where !ids.contains(added.message.id) { ids.append(added.message.id) }
            }
            pageToken = page.nextPageToken
            pages += 1
        } while pageToken != nil && pages < 10
        return ids
    }

    private func currentHistoryID() async throws -> String? {
        try JSONDecoder().decode(Profile.self, from: try await get(URL(string: Self.api + "/profile")!)).historyId
    }

    // MARK: - HTTP

    private func token() async throws -> String {
        try await OAuthSession.validAccessToken(Self.oauth, accountID: account.id)
    }

    private func get(_ url: URL) async throws -> Data {
        guard url.host == "gmail.googleapis.com" else { throw MailboxError.insecure(L10n.string("Pausely stopped because a reply came from an unexpected server.")) }
        try await pace()
        var request = URLRequest(url: url)
        request.timeoutInterval = 40
        let accountID = account.id
        let data = try await MailboxHTTP.data(request,
                                              token: { try await self.token() },
                                              refresh: { try await OAuthSession.forceRefresh(Self.oauth, accountID: accountID) },
                                              onRateLimit: { self.slowDown() })
        answered()
        return data
    }

    // MARK: - Response models

    struct Profile: Decodable {
        let emailAddress: String
        let historyId: String?
    }

    struct MessageList: Decodable {
        let messages: [Item]?
        let nextPageToken: String?
        struct Item: Decodable { let id: String }
    }

    struct HistoryPage: Decodable {
        let history: [Record]?
        let nextPageToken: String?
        struct Record: Decodable {
            let messagesAdded: [Added]?
            struct Added: Decodable { let message: MessageList.Item }
        }
    }

    struct MessageDetail: Decodable {
        let id: String
        let internalDate: String?
        let labelIds: [String]?
        let snippet: String?
        let payload: Payload?

        struct Payload: Decodable { let headers: [Header]? }
        struct Header: Decodable { let name: String; let value: String }

        var headerMap: [String: String] {
            var map: [String: String] = [:]
            for header in payload?.headers ?? [] where map[header.name.lowercased()] == nil {
                map[header.name.lowercased()] = header.value
            }
            return map
        }

        var receivedDate: Date? {
            guard let internalDate, let milliseconds = Double(internalDate) else { return nil }
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
    }
}
