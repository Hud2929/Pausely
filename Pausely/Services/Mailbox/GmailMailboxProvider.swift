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
            extraAuthorizeParameters: ["access_type": "offline", "prompt": "select_account consent"])
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
        guard OAuthSession.store(tokens, for: id) else {
            throw MailboxError.server(L10n.string("Couldn't save the sign-in securely on this iPhone."))
        }
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
        let queries = Self.searchQueries(plan)
        let perQueryCap = max(150, plan.maxCandidates / max(1, queries.count))
        var ids: [String] = []
        var seen = Set<String>()
        for query in queries {
            try Task.checkCancellation()
            var pageToken: String?
            var pages = 0
            var queryAdded = 0
            repeat {
                var components = URLComponents(string: Self.api + "/messages")!
                var items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "maxResults", value: "100")]
                if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
                components.queryItems = items
                let list = try JSONDecoder().decode(MessageList.self, from: try await get(components.url!))
                for message in list.messages ?? [] where seen.insert(message.id).inserted {
                    ids.append(message.id)
                    queryAdded += 1
                }
                pageToken = list.nextPageToken
                pages += 1
            } while pageToken != nil && pages < 5 && queryAdded < perQueryCap && ids.count < plan.maxCandidates
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

    /// Pausely's Gmail quota is "6,000 units a minute per user" (Cloud console, 2026-11-22). In practice
    /// it admits about 370 reads a minute: a real scan's first half minute took 352 and the next was refused
    /// with exactly that limit's name. Requests start 0.18 s apart (about 330 a minute), a steady pace just
    /// inside it: a burst spends the minute's budget in 30 seconds and then waits out the other 30.
    static let minimumGap: TimeInterval = 0.18
    private var nextStart = Date.distantPast
    /// If Google refuses anyway, the pace drops by a quarter (never below two a second) and creeps back
    /// as answers come. Halving at each refusal left a real scan at half a read a second for minutes
    /// (614 s for 130 refusals); halving the reads in flight too, 1,026 s.
    private var rate = 1 / GmailMailboxProvider.minimumGap
    private var answeredInARow = 0
    private let inFlightLimit = GmailMailboxProvider.parallelHeaderReads

    private func slowDown() {
        rate = max(2, rate * 0.75)
        answeredInARow = 0
    }

    private func answered() {
        answeredInARow += 1
        guard answeredInARow >= 10 else { return }
        answeredInARow = 0
        rate = min(1 / Self.minimumGap, rate + 0.25)
    }

    /// Runs `work` for every ref with as many in flight as Google currently allows, a new one starting as
    /// each answers.
    private func paced<T: Sendable>(_ refs: [MessageRef], _ work: @escaping @Sendable (MessageRef) async throws -> T) async -> [(MessageRef, Result<T, Error>)] {
        var out: [(MessageRef, Result<T, Error>)] = []
        var queue = refs[...]
        var inFlight = 0
        await withTaskGroup(of: (MessageRef, Result<T, Error>).self) { group in
            while inFlight < inFlightLimit, let ref = queue.popFirst() {
                inFlight += 1
                group.addTask {
                    do { return (ref, .success(try await work(ref))) }
                    catch { return (ref, .failure(error)) }
                }
            }
            for await result in group {
                inFlight -= 1
                out.append(result)
                while !Task.isCancelled, inFlight < inFlightLimit, let next = queue.popFirst() {
                    inFlight += 1
                    group.addTask {
                        do { return (next, .success(try await work(next))) }
                        catch { return (next, .failure(error)) }
                    }
                }
            }
        }
        return out
    }

    var parallelReads: Int { Self.parallelHeaderReads }

    /// Several whole messages at once (the requests are paced, so Google's limit is never met).
    func rawMessages(_ refs: [MessageRef]) async throws -> [MessageRef: Data] {
        var out: [MessageRef: Data] = [:]
        var lastFailure: Error?
        var succeeded = 0
        try Task.checkCancellation()
        for (ref, result) in await paced(refs, { try await self.rawMessage($0) }) {
            switch result {
            case .success(let raw):
                succeeded += 1
                if let raw { out[ref] = raw }
            case .failure(let error):
                if Self.isFatalBatchError(error) { throw error }
                lastFailure = error
            }
        }
        try Task.checkCancellation()
        if succeeded == 0, !refs.isEmpty, let lastFailure { throw lastFailure }
        return out
    }

    private static func isFatalBatchError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        switch error as? MailboxError {
        case .authExpired, .throttled, .cancelled: return true
        default: return false
        }
    }

    private func pace() async throws {
        let now = Date()
        let start = max(now, nextStart)
        nextStart = start.addingTimeInterval(1 / rate)
        let wait = start.timeIntervalSince(now)
        if wait > 0 { try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
    }

    func summaries(_ refs: [MessageRef]) async throws -> [MessageSummary] {
        var results: [MessageSummary] = []
        var missed: [MessageRef] = []
        var lastFailure: Error?
        // As many in flight as Google allows (a new one starting as each answers), within the pace above.
        try Task.checkCancellation()
        for (ref, result) in await paced(refs, { try await self.metadata($0) }) {
            switch result {
            case .success(let summary):
                results.append(summary)
            case .failure(let error):
                if case MailboxError.authExpired = error { throw MailboxError.authExpired }
                if case MailboxError.cancelled = error { throw MailboxError.cancelled }
                if error is CancellationError { throw error }
                missed.append(ref)
                lastFailure = error
            }
        }
        try Task.checkCancellation()
        // What Gmail turned away while busy is asked for again, one at a time, instead of being dropped
        // unsaid. Access expiry, persistent throttling, or complete network failure propagates instead of ending empty.
        var consecutiveFailures = 0
        for ref in missed {
            try Task.checkCancellation()
            do {
                results.append(try await metadata(ref))
                consecutiveFailures = 0
            } catch {
                if Self.isFatalBatchError(error) { throw error }
                if let urlError = error as? URLError,
                   urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                    throw MailboxError.network(urlError.localizedDescription)
                }
                lastFailure = error
                consecutiveFailures += 1
                if consecutiveFailures >= 3 { throw error }
            }
        }
        if results.isEmpty, !refs.isEmpty, let lastFailure { throw lastFailure }
        return results
    }

    private static let messageIDAllowed: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return allowed
    }()

    private func messageURL(for ref: MessageRef, queryItems: [URLQueryItem]) throws -> URL {
        guard let encoded = ref.id.addingPercentEncoding(withAllowedCharacters: Self.messageIDAllowed),
              var components = URLComponents(string: Self.api + "/messages/\(encoded)") else {
            throw MailboxError.server(L10n.string("Pausely built a request it couldn't send."))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw MailboxError.server(L10n.string("Pausely built a request it couldn't send."))
        }
        return url
    }

    private func metadata(_ ref: MessageRef) async throws -> MessageSummary {
        let items = [URLQueryItem(name: "format", value: "metadata")]
            + ["From", "Subject", "Date", "Message-ID"].map { URLQueryItem(name: "metadataHeaders", value: $0) }
        let detail = try JSONDecoder().decode(MessageDetail.self, from: try await get(try messageURL(for: ref, queryItems: items)))
        let headers = detail.headerMap
        return MessageSummary(ref: ref, from: headers["from"] ?? "", subject: headers["subject"] ?? "",
                              snippet: detail.snippet ?? "", labelIds: detail.labelIds ?? [],
                              receivedDate: detail.receivedDate,
                              messageID: MIMEParser.normalizedMessageID(headers["message-id"]))
    }

    func rawMessage(_ ref: MessageRef) async throws -> Data? {
        let url = try messageURL(for: ref, queryItems: [URLQueryItem(name: "format", value: "raw")])
        struct Raw: Decodable { let raw: String?; let sizeEstimate: Int? }
        // Guard memory against giant attachment-laden emails (> 8 MiB encoded JSON)
        let data = try await get(url, maxBytes: 12 * 1024 * 1024)
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        if let est = raw.sizeEstimate, est > MIMEParser.maxMessageBytes { return nil }
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
        _ = try? await URLSession.shared.safeData(for: request)
    }

    // MARK: - History (only new mail)

    private func historySince(_ historyID: String) async throws -> [String]? {
        var ids: [String] = []
        var seen = Set<String>()
        var pageToken: String?
        var pages = 0
        repeat {
            try Task.checkCancellation()
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
                for added in record.messagesAdded ?? [] where seen.insert(added.message.id).inserted { ids.append(added.message.id) }
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

    private func get(_ url: URL, maxBytes: Int = 4 * 1024 * 1024) async throws -> Data {
        guard url.scheme?.lowercased() == "https",
              url.host == "gmail.googleapis.com",
              url.port == nil else {
            throw MailboxError.insecure(L10n.string("Pausely stopped because a reply came from an unexpected server."))
        }
        try await pace()
        var request = URLRequest(url: url)
        request.timeoutInterval = 40
        let accountID = account.id
        let data = try await MailboxHTTP.data(request,
                                              token: { try await self.token() },
                                              refresh: { try await OAuthSession.forceRefresh(Self.oauth, accountID: accountID) },
                                              onRateLimit: { self.slowDown() })
        guard data.count <= maxBytes else {
            throw MailboxError.server(L10n.string("The server sent more data than expected."))
        }
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
