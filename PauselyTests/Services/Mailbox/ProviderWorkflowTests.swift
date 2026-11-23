import XCTest
@testable import Pausely

// MARK: - A mailbox for the fake servers

/// One message as a provider stores it.
struct FixtureMessage {
    let id: String
    let raw: Data
    let date: Date
    var labels: [String] = []        // Gmail labels (SPAM and TRASH are never searched)
    var folder = "INBOX"             // Graph folder id (JUNK and TRASH are never read)
    var addedAtHistory = 0           // Gmail history id / Graph delta token when it arrived
}

enum FixtureMailbox {
    /// The real receipts in PAUSELY_REAL_MAIL_DIR when set, otherwise a made-up mailbox with the same shapes.
    static func load() -> (messages: [FixtureMessage], isReal: Bool) {
        if let dir = ProcessInfo.processInfo.environment["PAUSELY_REAL_MAIL_DIR"], !dir.isEmpty,
           let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil) {
            let messages = files.filter { $0.pathExtension == "eml" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
                .compactMap { file -> FixtureMessage? in
                    guard let data = try? Data(contentsOf: file),
                          let email = MIMEParser.parse(data, id: file.lastPathComponent) else { return nil }
                    return FixtureMessage(id: file.deletingPathExtension().lastPathComponent, raw: data, date: email.date)
                }
            if !messages.isEmpty { return (messages, true) }
        }
        return (synthetic(), false)
    }

    static func mime(from: String, subject: String, date: Date, body: String, authenticated: Bool = true,
                     domain: String, extraHeaders: String = "") -> Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let auth = authenticated
            ? "mx.example.net; dkim=pass header.d=\(domain); spf=pass smtp.mailfrom=bounce.\(domain); dmarc=pass header.from=\(domain)"
            : "mx.example.net; dkim=fail header.d=\(domain); spf=fail smtp.mailfrom=attacker.example; dmarc=fail header.from=\(domain)"
        let text = """
        Authentication-Results: \(auth)
        From: \(from)
        To: tester@example.test
        Subject: \(subject)
        Date: \(formatter.string(from: date))
        Message-ID: <\(UUID().uuidString)@\(domain)>
        MIME-Version: 1.0
        \(extraHeaders)Content-Type: text/plain; charset=utf-8
        Content-Transfer-Encoding: 8bit

        \(body)
        """
        return Data(text.replacingOccurrences(of: "\n", with: "\r\n").utf8)
    }

    /// Made-up mail in real shapes: a monthly SaaS on Stripe, a known streaming service, an order, a promo,
    /// a forged receipt, and a receipt sitting in Junk.
    static func synthetic(now: Date = Date()) -> [FixtureMessage] {
        var out: [FixtureMessage] = []
        func add(_ id: String, _ daysAgo: Int, _ data: Data, labels: [String] = [], folder: String = "INBOX") {
            out.append(FixtureMessage(id: id, raw: data, date: now.addingTimeInterval(-Double(daysAgo) * 86_400),
                                      labels: labels, folder: folder))
        }
        for (index, daysAgo) in [92, 61, 31, 1].enumerated() {
            let date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
            add("inkwell\(index)", daysAgo, mime(
                from: "\"Inkwell Labs, Inc.\" <invoice+statements@mail.inkwell-labs.com>",
                subject: "Your receipt from Inkwell Labs, Inc. #10\(index)", date: date,
                body: "Receipt from Inkwell Labs, Inc. CA$22.60\nReceipt #10\(index) Billing period 20 Jul – 20 Aug 2026 Inkwell Pro Qty 1 CA$20.00\nTotal CA$22.60 Amount paid CA$22.60",
                domain: "mail.inkwell-labs.com"))
        }
        for (index, daysAgo) in [64, 34, 4].enumerated() {
            let date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
            add("spotify\(index)", daysAgo, mime(
                from: "Spotify <no-reply@spotify.com>", subject: "Your Spotify Premium receipt", date: date,
                body: "Thanks for your payment of $11.99 for Spotify Premium. Your subscription renews automatically every month.",
                domain: "spotify.com"))
        }
        add("order", 10, mime(from: "QuickBite <orders@quickbite.example>", subject: "Order Confirmation #5521",
                              date: now.addingTimeInterval(-10 * 86_400),
                              body: "Thanks for your order! Order #5521. Your delivery is on the way. Total $23.40", domain: "quickbite.example"))
        add("promo", 5, mime(from: "Best Deals <deals@promo.example>", subject: "Save 50% on annual plans today only!",
                             date: now.addingTimeInterval(-5 * 86_400),
                             body: "Upgrade now: Premium only $4.99/month, renews automatically. Limited offer.", domain: "promo.example",
                             extraHeaders: "List-Unsubscribe: <mailto:unsub@promo.example>\nPrecedence: bulk\n"),
            labels: ["CATEGORY_PROMOTIONS"])
        add("forged", 2, mime(from: "Netflix <billing@netflix.com>", subject: "Your Netflix payment receipt",
                              date: now.addingTimeInterval(-2 * 86_400),
                              body: "We received your payment of $99.99 for your Premium plan. Your membership renews automatically every month.",
                              authenticated: false, domain: "netflix.com"))
        add("junk", 3, mime(from: "\"Inkwell Labs, Inc.\" <invoice+statements@mail.inkwell-labs.com>",
                            subject: "Your receipt from Inkwell Labs, Inc. #999", date: now.addingTimeInterval(-3 * 86_400),
                            body: "Receipt #999 Billing period 20 Oct – 20 Nov 2026 Inkwell Pro Qty 1 Total CA$990.00 Amount paid CA$990.00",
                            domain: "mail.inkwell-labs.com"),
            labels: ["SPAM"], folder: "JUNK")
        return out
    }
}

// MARK: - Fake Gmail API and Microsoft Graph

/// Plays gmail.googleapis.com, graph.microsoft.com and both token endpoints, following their documented
/// response shapes. Every request must carry the current access token, as the real servers require.
final class FakeMailAPI: URLProtocol {
    struct State {
        var messages: [FixtureMessage] = []
        var address = "tester@example.test"
        var historyID = 1_000
        var validTokens: Set<String> = []
        var refreshToken = "refresh-1"
        var issued = 0
        var historyExpired = false
        var deltaExpired = false
        var throttleNext = 0
        /// The next this-many Gmail header reads are refused the way Gmail refuses a busy person:
        /// 403 userRateLimitExceeded. `gmailHeadersForbidden` refuses them all as a real permission error.
        var gmailRateLimitBurst = 0
        var gmailHeadersForbidden = false
        var revokeNextTokenAfter: Int?
        var pageSize = 7
        var foreignNextLink = false
        var log: [String] = []
        var revoked: [String] = []
        var tokenRequests: [String] = []
        var responseDelay: TimeInterval = 0   // a slow connection, to stop or disconnect mid-scan
    }

    static let hosts: Set<String> = ["gmail.googleapis.com", "oauth2.googleapis.com", "graph.microsoft.com", "login.microsoftonline.com"]
    private static let lock = NSLock()
    private static var _state = State()
    static func with<T>(_ body: (inout State) -> T) -> T { lock.lock(); defer { lock.unlock() }; return body(&_state) }

    override class func canInit(with request: URLRequest) -> Bool { hosts.contains(request.url?.host ?? "") || request.url?.host == "evil.example" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let delay = Self.with { $0.responseDelay }
        if delay > 0 { Thread.sleep(forTimeInterval: delay) }
        let (status, headers, body) = Self.respond(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func json(_ object: Any, status: Int = 200) -> (Int, [String: String], Data) {
        (status, ["Content-Type": "application/json"], (try? JSONSerialization.data(withJSONObject: object)) ?? Data())
    }

    private static func body(of request: URLRequest) -> String {
        if let data = request.httpBody { return String(decoding: data, as: UTF8.self) }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
        return String(decoding: data, as: UTF8.self)
    }

    private static func form(_ text: String) -> [String: String] {
        var out: [String: String] = [:]
        for pair in text.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map { String($0).removingPercentEncoding ?? String($0) }
            if parts.count == 2 { out[parts[0]] = parts[1] }
        }
        return out
    }

    static func issueToken(_ s: inout State) -> String {
        s.issued += 1
        let token = "access-\(s.issued)"
        s.validTokens.insert(token)
        return token
    }

    private static func respond(_ request: URLRequest) -> (Int, [String: String], Data) {
        let url = request.url!
        let query = Dictionary(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map { ($0.name, $0.value ?? "") } ?? [],
                               uniquingKeysWith: { a, _ in a })
        return with { s in
            s.log.append("\(request.httpMethod ?? "GET") \(url.host ?? "")\(url.path)")
            if url.host == "evil.example" { return json(["value": []]) }

            // Token endpoints
            if url.host == "oauth2.googleapis.com" || url.host == "login.microsoftonline.com" {
                let params = form(body(of: request))
                if url.path.hasSuffix("/revoke") { s.revoked.append(params["token"] ?? ""); return json([:]) }
                s.tokenRequests.append(params["grant_type"] ?? "")
                guard params["grant_type"] == "refresh_token", params["refresh_token"] == s.refreshToken else {
                    return json(["error": "invalid_grant"], status: 400)
                }
                return json(["access_token": issueToken(&s), "expires_in": 3600, "token_type": "Bearer"])
            }

            // Every API call needs a valid bearer token.
            let bearer = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "") ?? ""
            if let after = s.revokeNextTokenAfter {
                if after <= 0 { s.validTokens.remove(bearer); s.revokeNextTokenAfter = nil } else { s.revokeNextTokenAfter = after - 1 }
            }
            guard s.validTokens.contains(bearer) else { return json(["error": ["code": 401, "message": "Invalid Credentials"]], status: 401) }
            if s.throttleNext > 0 {
                s.throttleNext -= 1
                return (429, ["Retry-After": "1"], Data())
            }
            if url.host == "gmail.googleapis.com", url.path.contains("/messages/"), query["format"] == "metadata" {
                if s.gmailHeadersForbidden {
                    return json(["error": ["code": 403, "message": "Request had insufficient authentication scopes.",
                                           "errors": [["message": "Insufficient Permission", "domain": "global",
                                                       "reason": "insufficientPermissions"]],
                                           "status": "PERMISSION_DENIED"]], status: 403)
                }
                if s.gmailRateLimitBurst > 0 {
                    s.gmailRateLimitBurst -= 1
                    var refusal = json(["error": ["code": 403, "message": "User-rate limit exceeded.",
                                                  "errors": [["message": "User-rate limit exceeded.", "domain": "usageLimits",
                                                              "reason": "userRateLimitExceeded"]],
                                                  "status": "PERMISSION_DENIED"]], status: 403)
                    refusal.1["Retry-After"] = "0"
                    return refusal
                }
            }

            if url.host == "gmail.googleapis.com" { return gmail(url: url, query: query, state: &s) }
            return graph(url: url, query: query, state: &s)
        }
    }

    // MARK: Gmail

    private static func gmail(url: URL, query: [String: String], state s: inout State) -> (Int, [String: String], Data) {
        let path = url.path.replacingOccurrences(of: "/gmail/v1/users/me", with: "")
        if path == "/profile" { return json(["emailAddress": s.address, "historyId": String(s.historyID)]) }
        if path == "/history" {
            if s.historyExpired { return json(["error": ["code": 404, "message": "Requested entity was not found."]], status: 404) }
            let start = Int(query["startHistoryId"] ?? "") ?? 0
            let added = s.messages.filter { $0.addedAtHistory > start }
            return json(["historyId": String(s.historyID),
                         "history": added.map { ["id": String($0.addedAtHistory), "messagesAdded": [["message": ["id": $0.id]]]] }])
        }
        if path == "/messages" {
            // Spam and Trash are never searched; `after:` limits by date like Gmail does.
            var results = s.messages.filter { !$0.labels.contains("SPAM") && !$0.labels.contains("TRASH") }
            if let q = query["q"], let range = q.range(of: #"after:(\d{4})/(\d{2})/(\d{2})"#, options: .regularExpression) {
                let parts = q[range].dropFirst(6).split(separator: "/").compactMap { Int($0) }
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "UTC")!
                if parts.count == 3, let after = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) {
                    results = results.filter { $0.date >= after }
                }
            }
            let offset = Int(query["pageToken"] ?? "") ?? 0
            let page = Array(results.dropFirst(offset).prefix(s.pageSize))
            var object: [String: Any] = ["messages": page.map { ["id": $0.id, "threadId": $0.id] }, "resultSizeEstimate": results.count]
            if offset + page.count < results.count { object["nextPageToken"] = String(offset + page.count) }
            return json(object)
        }
        if path.hasPrefix("/messages/") {
            let id = String(path.dropFirst("/messages/".count))
            guard let message = s.messages.first(where: { $0.id == id }) else { return json(["error": ["code": 404]], status: 404) }
            if query["format"] == "raw" {
                let raw = message.raw.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
                return json(["id": id, "raw": raw])
            }
            let headers = MIMEParser.parseHeaders(message.raw)
            return json(["id": id, "threadId": id, "labelIds": message.labels.isEmpty ? ["INBOX"] : message.labels,
                         "snippet": "", "internalDate": String(Int64(message.date.timeIntervalSince1970 * 1000)),
                         "payload": ["headers": ["From", "Subject", "Date", "Message-ID"].compactMap { name in
                             headers[name.lowercased()].map { ["name": name, "value": $0] } }]])
        }
        return json(["error": ["code": 404]], status: 404)
    }

    // MARK: Microsoft Graph

    /// Real Graph ids are base64 and contain "/", "+" and "=".
    static func graphID(_ m: FixtureMessage) -> String { "AAMkAD\(m.id)/Zx+Q==" }

    private static func graphMessage(_ m: FixtureMessage) -> [String: Any] {
        let headers = MIMEParser.parseHeaders(m.raw)
        let from = headers["from"] ?? ""
        let address = from.range(of: #"<([^>]+)>"#, options: .regularExpression).map { String(from[$0].dropFirst().dropLast()) } ?? from
        let name = from.components(separatedBy: "<").first?.trimmingCharacters(in: CharacterSet(charactersIn: " \"")) ?? ""
        return ["id": graphID(m), "subject": headers["subject"] ?? "", "bodyPreview": "",
                "from": ["emailAddress": ["name": name, "address": address]],
                "receivedDateTime": ISO8601DateFormatter().string(from: m.date),
                "internetMessageId": headers["message-id"] ?? "", "parentFolderId": m.folder]
    }

    private static func graph(url: URL, query: [String: String], state s: inout State) -> (Int, [String: String], Data) {
        let path = url.path.replacingOccurrences(of: "/v1.0", with: "")
        if path == "/me" { return json(["mail": s.address, "userPrincipalName": s.address]) }
        if path == "/me/mailFolders/junkemail" { return json(["id": "JUNK"]) }
        if path == "/me/mailFolders/deleteditems" { return json(["id": "TRASH"]) }
        if path == "/me/messages" {
            // Graph's $search covers every folder, Junk included: the provider must drop those itself.
            let offset = Int(query["$skiptoken"] ?? "") ?? 0
            let page = Array(s.messages.dropFirst(offset).prefix(s.pageSize))
            var object: [String: Any] = ["value": page.map(graphMessage)]
            if offset + page.count < s.messages.count {
                var next = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                next.queryItems = (next.queryItems ?? []).filter { $0.name != "$skiptoken" } + [URLQueryItem(name: "$skiptoken", value: String(offset + page.count))]
                if s.foreignNextLink { next.host = "evil.example" }
                object["@odata.nextLink"] = next.url!.absoluteString
            }
            return json(object)
        }
        // Routed by path segment, as Graph does: an id whose "/" isn't encoded splits into two segments.
        let segments = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? "")
            .replacingOccurrences(of: "/v1.0", with: "").split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if segments.count == 5, segments[1] == "me", segments[2] == "messages", segments[4] == "$value" {
            let id = segments[3].removingPercentEncoding ?? ""
            guard let message = s.messages.first(where: { graphID($0) == id }) else { return json(["error": ["code": "ErrorItemNotFound"]], status: 404) }
            return (200, ["Content-Type": "text/plain"], message.raw)
        }
        if path == "/me/mailFolders/inbox/messages/delta" {
            let link = "https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages/delta?$deltatoken=\(s.historyID)"
            guard let token = query["$deltatoken"].flatMap(Int.init) else { return json(["value": [], "@odata.deltaLink": link]) }
            if s.deltaExpired { return json(["error": ["code": "SyncStateNotFound"]], status: 410) }
            let added = s.messages.filter { $0.addedAtHistory > token && $0.folder == "INBOX" }
            return json(["value": added.map(graphMessage), "@odata.deltaLink": link])
        }
        return json(["error": ["code": "ResourceNotFound"]], status: 404)
    }
}

// MARK: - The workflows

@MainActor
final class ProviderWorkflowTests: XCTestCase {

    private var scanner: InboxScanner { InboxScanner.shared }
    private var fixture: (messages: [FixtureMessage], isReal: Bool) = ([], false)

    override func setUp() async throws {
        // Never touch inboxes someone connected for real on this simulator. Asked of what is saved, not of
        // the scanner's copy: that copy can be empty in a test run while real inboxes are saved, and
        // `disconnectAll` then wiped two real inboxes (2026-11-18). The stand-in is in place before
        // anything is disconnected, so no revoke can reach a real server.
        try XCTSkipIf(MailboxAccountStore.all().contains { !$0.address.hasSuffix(".test") }
                      || InboxScanner.shared.accounts.contains { !$0.address.hasSuffix(".test") },
                      "real inboxes are connected on this simulator")
        fixture = FixtureMailbox.load()
        FakeMailAPI.with { $0 = FakeMailAPI.State(); $0.messages = fixture.messages }
        URLProtocol.registerClass(FakeMailAPI.self)
        tookOver = true
        await InboxScanner.shared.disconnectAll()
    }

    /// Whether this test's setUp took the inboxes over. XCTest calls tearDown even when setUp skipped,
    /// and an unconditional disconnect there erased real inboxes and revoked a real Gmail sign-in at
    /// Google, with no stand-in registered (found 2026-11-22, after three lost connections).
    private var tookOver = false

    override func tearDown() async throws {
        guard tookOver else { return }
        await InboxScanner.shared.disconnectAll()
        URLProtocol.unregisterClass(FakeMailAPI.self)
        tookOver = false
    }

    /// `--demo-gmail-results` puts a made-up inbox and its findings on screen. Connecting an inbox
    /// starts a search, and the search of that made-up inbox wiped the findings: the screen tour's
    /// "results" capture was the first page for weeks. The demo's inbox is never searched (it would
    /// also have dialled a real mail server), and disconnecting ends the demo.
    func testTheDemosInboxIsNeverSearched() async throws {
        scanner.loadDemoResults()
        XCTAssertTrue(scanner.isShowingDemo)
        XCTAssertEqual(scanner.accounts.map(\.address), ["demo@pausely.app"])
        XCTAssertGreaterThan(scanner.foundSubscriptions.count, 5)

        // Read from the source, not by running it: a search that did start would open a connection.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Pausely/Services/Mailbox/InboxScanner.swift"), encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "func scanAll() async {"))
        let run = try XCTUnwrap(source.range(of: "await runScan()", range: start.upperBound..<source.endIndex))
        XCTAssertTrue(source[start.upperBound..<run.lowerBound].contains("if isShowingDemo { return }"))

        await scanner.disconnectAll()
        XCTAssertFalse(scanner.isShowingDemo)
        XCTAssertEqual(scanner.foundSubscriptions.count, 0)
    }

    /// Tokens as sign-in leaves them: a fresh access token and a refresh token.
    private func signedInTokens() -> OAuthSession.Tokens {
        FakeMailAPI.with { s in
            OAuthSession.Tokens(accessToken: FakeMailAPI.issueToken(&s), refreshToken: s.refreshToken, expiresAt: Date().addingTimeInterval(3_600))
        }
    }

    /// An hour later: the saved access token has expired, so the next call must refresh it first.
    private func expireSavedToken(_ account: MailboxAccount) {
        guard var tokens = OAuthSession.load(for: account.id) else { return XCTFail("no saved tokens") }
        tokens.expiresAt = Date().addingTimeInterval(-60)
        OAuthSession.store(tokens, for: account.id)
    }

    /// What the scan must find, for whichever mailbox the fake is serving.
    private func assertFindsTheRightSubscriptions(_ label: String) {
        let names = Set(scanner.report?.subscriptions.map(\.name) ?? [])
        if fixture.isReal {
            // What the real mailbox must and must not show comes from the environment, so nobody's
            // subscriptions end up in the repository: PAUSELY_REAL_MAIL_EXPECT / _REJECT="Name A,Name B".
            let environment = ProcessInfo.processInfo.environment
            func list(_ name: String) -> [String] { (environment[name] ?? "").split(separator: ",").map(String.init) }
            for expected in list("PAUSELY_REAL_MAIL_EXPECT") { XCTAssertTrue(names.contains(expected), "\(label): missing \(expected) in \(names)") }
            for rejected in list("PAUSELY_REAL_MAIL_REJECT") { XCTAssertFalse(names.contains { $0.contains(rejected) }, "\(label): \(rejected) in \(names)") }
            XCTAssertFalse(names.isEmpty, "\(label): the real mailbox should show subscriptions")
        } else {
            XCTAssertTrue(names.contains("Inkwell Labs"), "\(label): \(names)")
            XCTAssertTrue(names.contains("Spotify"), "\(label): \(names)")
            XCTAssertFalse(names.contains("Netflix"), "\(label): a forged receipt was trusted")
            XCTAssertFalse(names.contains { $0.contains("QuickBite") || $0.contains("Best Deals") }, "\(label): \(names)")
            let inkwell = scanner.report?.subscriptions.first { $0.name == "Inkwell Labs" }
            XCTAssertEqual(inkwell?.amount, Decimal(string: "22.60"), "\(label): the receipt in Junk must not count")
            XCTAssertEqual(inkwell?.frequency, .monthly)
        }
    }

    // MARK: Gmail

    func testGmailWorkflow() async throws {
        // 1. Connect: after sign-in, the profile gives the address and the account is saved.
        await scanner.connect { try await GmailMailboxProvider.finishConnect(signedInTokens()) }
        let account = try XCTUnwrap(scanner.accounts.first { $0.kind == .gmail })
        XCTAssertEqual(account.address, "tester@example.test")
        XCTAssertNil(scanner.error)

        // 2. First scan an hour later: the expired token is refreshed, a throttle answered, results correct.
        expireSavedToken(account)
        FakeMailAPI.with { $0.throttleNext = 1 }
        await scanner.scanAll()
        XCTAssertTrue(scanner.accountErrors.isEmpty, "\(scanner.accountErrors)")
        let stats = try XCTUnwrap(scanner.stats.perAccount[account.id])
        let searchable = fixture.messages.filter { !$0.labels.contains("SPAM") }.count
        XCTAssertEqual(stats.candidates, searchable, "every searchable message considered once, across all queries and pages")
        XCTAssertGreaterThan(stats.read, 0)
        assertFindsTheRightSubscriptions("Gmail first scan")
        let log = FakeMailAPI.with { $0.log }
        XCTAssertFalse(log.contains { $0.contains("/messages/junk") }, "Spam is never read")
        XCTAssertEqual(FakeMailAPI.with { $0.tokenRequests }, ["refresh_token"], "one refresh for the expired token")

        // 3. A token revoked mid-scan: one refresh, then carry on.
        FakeMailAPI.with { s in s.revokeNextTokenAfter = 0; s.historyID += 1 }
        await scanner.scanAll()
        XCTAssertTrue(scanner.accountErrors.isEmpty, "\(scanner.accountErrors)")
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.incremental, true)
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.candidates, 0, "nothing new since the last scan")

        // 4. New mail arrives: only it is read.
        FakeMailAPI.with { s in
            s.historyID += 5
            let raw = FixtureMailbox.mime(from: "Spotify <no-reply@spotify.com>", subject: "Your Spotify Premium receipt", date: Date(),
                                          body: "Thanks for your payment of $11.99 for Spotify Premium. Your subscription renews automatically every month.",
                                          domain: "spotify.com")
            s.messages.append(FixtureMessage(id: "fresh", raw: raw, date: Date(), addedAtHistory: s.historyID))
        }
        await scanner.scanAll()
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.candidates, 1)
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.read, 1)

        // 5. Gmail forgot the sync position (it keeps about a week): full search again, not an error.
        FakeMailAPI.with { $0.historyExpired = true }
        await scanner.scanAll()
        XCTAssertTrue(scanner.accountErrors.isEmpty, "\(scanner.accountErrors)")
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.candidates, searchable + 1)

        // 6. Disconnect: access revoked at Google, secrets and receipt facts gone.
        await scanner.disconnect(account)
        XCTAssertEqual(FakeMailAPI.with { $0.revoked }, [FakeMailAPI.with { $0.refreshToken }])
        XCTAssertNil(MailboxAccountStore.secret(.accessToken, for: account.id))
        XCTAssertNil(MailboxAccountStore.secret(.refreshToken, for: account.id))
        XCTAssertTrue(ReceiptLedger.load().isEmpty)
        XCTAssertFalse(scanner.hasAccounts)
    }

    /// Gmail turns a busy person away with 403 userRateLimitExceeded. On a real inbox (2026-11-18) that was
    /// read as "sign in again" and 966 of 1,500 emails were dropped without a word. Every email is checked.
    func testGmailRateLimit_isWaitedOutAndNothingIsDropped() async throws {
        await scanner.connect { try await GmailMailboxProvider.finishConnect(signedInTokens()) }
        let account = try XCTUnwrap(scanner.accounts.first { $0.kind == .gmail })
        let searchable = fixture.messages.filter { !$0.labels.contains("SPAM") }.count
        // Enough refusals to be met on the first reads; each halves the pace, so more only add waiting.
        FakeMailAPI.with { $0.gmailRateLimitBurst = 6 }
        await scanner.scanAll()
        XCTAssertTrue(scanner.accountErrors.isEmpty, "\(scanner.accountErrors)")
        let stats = try XCTUnwrap(scanner.stats.perAccount[account.id])
        XCTAssertEqual(stats.candidates, searchable)
        XCTAssertEqual(stats.checked, searchable, "every email's headers were read in the end")
        XCTAssertEqual(FakeMailAPI.with { $0.gmailRateLimitBurst }, 0, "the refusals were really met")
        assertFindsTheRightSubscriptions("Gmail through rate limits")
        XCTAssertEqual(GmailMailboxProvider.parallelHeaderReads, 10)
        XCTAssertEqual(GmailMailboxProvider.minimumGap, 0.18, "about 330 a minute: inside the 370 a minute the quota admits")
    }

    /// An inbox whose access ended is reconnected in its own place: the new sign-in's tokens go to the same
    /// inbox, nothing is duplicated, the failure clears and a search follows. "Your sign-in expired.
    /// Reconnect this inbox." had no way to do it (both ratings of 2026-11-22).
    func testAnExpiredInboxIsReconnectedInItsOwnPlace() async throws {
        await scanner.connect { try await GmailMailboxProvider.finishConnect(signedInTokens()) }
        let old = try XCTUnwrap(scanner.accounts.first { $0.kind == .gmail })
        // Access withdrawn: every token refused and the refresh token no longer accepted.
        FakeMailAPI.with { s in s.validTokens = []; s.refreshToken = "withdrawn" }
        await scanner.scanAll()
        XCTAssertNotNil(scanner.accountErrors[old.id], "the expired sign-in is shown")

        FakeMailAPI.with { $0.refreshToken = "refresh-2" }
        let tokens = signedInTokens()
        await scanner.reconnect(old) { try await GmailMailboxProvider.finishConnect(tokens) }
        XCTAssertEqual(scanner.accounts.map(\.id), [old.id], "the same inbox, not a second one")
        XCTAssertNil(scanner.accountErrors[old.id])
        XCTAssertGreaterThan(scanner.stats.perAccount[old.id]?.candidates ?? 0, 0, "a search ran with the new sign-in")
    }

    /// What an earlier search found is shown again when the page opens, from the facts kept on the phone and
    /// with no request to the inbox: after a relaunch the page offered only "Search again" (2026-11-22).
    func testWhatWasFoundComesBackWithoutSearchingAgain() async throws {
        await scanner.connect { try await GmailMailboxProvider.finishConnect(signedInTokens()) }
        await scanner.scanAll()
        let found = scanner.foundSubscriptions.map(\.id)
        XCTAssertFalse(found.isEmpty)

        // As after a relaunch: the inbox and its facts are saved, nothing has been worked out yet.
        scanner.foundSubscriptions = []
        scanner.report = nil
        let asked = FakeMailAPI.with { $0.log.count }
        scanner.showSaved()
        XCTAssertEqual(scanner.foundSubscriptions.map(\.id), found)
        XCTAssertEqual(FakeMailAPI.with { $0.log.count }, asked, "nothing is asked of the inbox")
    }

    /// A 403 that is a real refusal (a permission taken away) says so instead of ending as "nothing found".
    func testGmailHeadersRefused_saysToReconnect() async throws {
        await scanner.connect { try await GmailMailboxProvider.finishConnect(signedInTokens()) }
        let account = try XCTUnwrap(scanner.accounts.first { $0.kind == .gmail })
        FakeMailAPI.with { $0.gmailHeadersForbidden = true }
        await scanner.scanAll()
        XCTAssertNotNil(scanner.accountErrors[account.id], "the refusal is shown, not hidden as an empty inbox")
    }

    func testRateLimitBodies_areToldApartFromRefusals() {
        func body(_ object: Any) -> Data { try! JSONSerialization.data(withJSONObject: object) }
        let gmailBusy = body(["error": ["code": 403, "errors": [["domain": "usageLimits", "reason": "userRateLimitExceeded"]],
                                        "status": "PERMISSION_DENIED"]])
        let googleTooMany = body(["error": ["code": 429, "status": "RESOURCE_EXHAUSTED"]])
        let concurrent = body(["error": ["code": 403, "message": "Too many concurrent requests for user"]])
        let noScope = body(["error": ["code": 403, "errors": [["domain": "global", "reason": "insufficientPermissions"]],
                                      "status": "PERMISSION_DENIED"]])
        XCTAssertTrue(MailboxHTTP.isRateLimit(gmailBusy))
        XCTAssertTrue(MailboxHTTP.isRateLimit(googleTooMany))
        XCTAssertTrue(MailboxHTTP.isRateLimit(concurrent))
        XCTAssertFalse(MailboxHTTP.isRateLimit(noScope), "a missing permission still means signing in again")
        XCTAssertFalse(MailboxHTTP.isRateLimit(Data()))
        XCTAssertFalse(MailboxHTTP.isRateLimit(Data("<html>Forbidden</html>".utf8)))
        XCTAssertEqual(MailboxHTTP.rateLimitDelay(retryAfter: nil, attempt: 1), 1)
        XCTAssertEqual(MailboxHTTP.rateLimitDelay(retryAfter: nil, attempt: 3), 4)
        XCTAssertEqual(MailboxHTTP.rateLimitDelay(retryAfter: "2", attempt: 1), 2)
        XCTAssertEqual(MailboxHTTP.rateLimitDelay(retryAfter: "-5", attempt: 1), 0)
    }

    func testGmailSignInThatCantBeRefreshed_asksToReconnect() async throws {
        await scanner.connect { try await GmailMailboxProvider.finishConnect(signedInTokens()) }
        let account = try XCTUnwrap(scanner.accounts.first)
        FakeMailAPI.with { $0.refreshToken = "rotated-elsewhere" }   // the user revoked access at Google
        expireSavedToken(account)
        await scanner.scanAll()
        XCTAssertEqual(scanner.accountErrors[account.id], MailboxError.authExpired.localizedDescription)
    }

    /// Waits until the scan is reading messages (or gives up after a few seconds).
    private func waitUntilReading() async throws {
        // The status line, not a share of the bar: the bar follows requests and passes any fixed mark while
        // headers are still being checked.
        for _ in 0..<300 where !(scanner.isScanning && scanner.statusLine.hasPrefix("Read")) {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testDisconnectDuringScan_forgetsTheInboxForGood() async throws {
        // Slow enough to be caught mid-read: bodies are read several at a time now.
        FakeMailAPI.with { $0.responseDelay = 0.15 }
        await scanner.connect { try await GmailMailboxProvider.finishConnect(signedInTokens()) }
        let account = try XCTUnwrap(scanner.accounts.first)
        let scan = Task { await scanner.scanAll() }
        try await waitUntilReading()
        XCTAssertTrue(scanner.isScanning, "the scan should still be running")

        await scanner.disconnect(account)
        await scan.value
        XCTAssertFalse(scanner.isScanning)
        XCTAssertTrue(MailboxAccountStore.all().isEmpty, "a scan that ends after a disconnect must not bring the inbox back")
        XCTAssertNil(MailboxAccountStore.cursor(for: account.id))
        XCTAssertNil(OAuthSession.load(for: account.id))
        XCTAssertTrue(ReceiptLedger.load().isEmpty, "no receipts from a disconnected inbox")
        XCTAssertTrue(scanner.foundSubscriptions.isEmpty)
    }

    /// The rule behind both tests above: saving scan progress never brings back a removed inbox.
    func testUpdatingARemovedInboxDoesNotBringItBack() {
        let account = MailboxAccount(id: UUID().uuidString, kind: .imap, address: "gone@example.test", addedAt: Date())
        MailboxAccountStore.upsert(account)
        MailboxAccountStore.remove(account.id)
        var later = account
        later.lastScan = Date()
        XCTAssertFalse(MailboxAccountStore.update(later))
        XCTAssertFalse(MailboxAccountStore.all().contains { $0.id == account.id })
    }

    func testDeletingTheAccountDuringScan_forgetsEveryInbox() async throws {
        FakeMailAPI.with { $0.responseDelay = 0.03 }
        await scanner.connect { try await GmailMailboxProvider.finishConnect(signedInTokens()) }
        FakeMailAPI.with { $0.address = "second@example.test" }
        await scanner.connect { try await MicrosoftGraphProvider.finishConnect(signedInTokens()) }
        XCTAssertEqual(scanner.accounts.count, 2)
        let scan = Task { await scanner.scanAll() }
        try await waitUntilReading()

        await scanner.disconnectAll()
        await scan.value
        XCTAssertTrue(MailboxAccountStore.all().isEmpty)
        XCTAssertTrue(ReceiptLedger.load().isEmpty)
        XCTAssertTrue(scanner.foundSubscriptions.isEmpty)
        XCTAssertNil(scanner.report)
    }

    // MARK: Outlook / Hotmail / Microsoft 365

    func testOutlookWorkflow() async throws {
        await scanner.connect { try await MicrosoftGraphProvider.finishConnect(signedInTokens()) }
        let account = try XCTUnwrap(scanner.accounts.first { $0.kind == .microsoft })
        XCTAssertEqual(account.address, "tester@example.test")

        FakeMailAPI.with { $0.throttleNext = 1 }
        await scanner.scanAll()
        XCTAssertTrue(scanner.accountErrors.isEmpty, "\(scanner.accountErrors)")
        let stats = try XCTUnwrap(scanner.stats.perAccount[account.id])
        let readable = fixture.messages.filter { $0.folder != "JUNK" }.count
        XCTAssertEqual(stats.candidates, readable, "every message outside Junk, once, across queries and pages")
        assertFindsTheRightSubscriptions("Outlook first scan")
        XCTAssertFalse(FakeMailAPI.with { $0.log }.contains { $0.contains("/me/messages/junk/") }, "Junk is never read")

        // Second scan: the delta link brings only what arrived since.
        await scanner.scanAll()
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.incremental, true)
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.candidates, 0)

        FakeMailAPI.with { s in
            s.historyID += 3
            let raw = FixtureMailbox.mime(from: "Spotify <no-reply@spotify.com>", subject: "Your Spotify Premium receipt", date: Date(),
                                          body: "Thanks for your payment of $11.99 for Spotify Premium. Your subscription renews automatically every month.",
                                          domain: "spotify.com")
            s.messages.append(FixtureMessage(id: "fresh", raw: raw, date: Date(), addedAtHistory: s.historyID))
        }
        await scanner.scanAll()
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.candidates, 1)

        // The sync position expired (410 Gone): a full search, not an error.
        FakeMailAPI.with { $0.deltaExpired = true }
        await scanner.scanAll()
        XCTAssertTrue(scanner.accountErrors.isEmpty, "\(scanner.accountErrors)")
        XCTAssertEqual(scanner.stats.perAccount[account.id]?.candidates, readable + 1)

        await scanner.disconnect(account)
        XCTAssertNil(MailboxAccountStore.secret(.accessToken, for: account.id))
        XCTAssertFalse(scanner.hasAccounts)
    }

    func testOutlookNextLinkToAnotherServer_isRefused() async throws {
        await scanner.connect { try await MicrosoftGraphProvider.finishConnect(signedInTokens()) }
        let account = try XCTUnwrap(scanner.accounts.first)
        FakeMailAPI.with { $0.foreignNextLink = true }
        await scanner.scanAll()
        XCTAssertNotNil(scanner.accountErrors[account.id], "a redirect to another host must stop the scan")
        XCTAssertFalse(FakeMailAPI.with { $0.log }.contains { $0.contains("evil.example") }, "the token was never sent elsewhere")
    }

    // MARK: Two inboxes at once

    func testGmailAndOutlookTogether_countEachReceiptOnce() async throws {
        await scanner.connect { try await GmailMailboxProvider.finishConnect(signedInTokens()) }
        FakeMailAPI.with { $0.address = "second@example.test" }
        await scanner.connect { try await MicrosoftGraphProvider.finishConnect(signedInTokens()) }
        XCTAssertEqual(scanner.accounts.count, 2)
        await scanner.scanAll()
        XCTAssertTrue(scanner.accountErrors.isEmpty, "\(scanner.accountErrors)")
        // Both inboxes hold the same messages (same Message-IDs): each charge is counted once.
        let ledger = ReceiptLedger.load()
        XCTAssertEqual(ledger.count, Set(ledger.map(\.id)).count)
        XCTAssertTrue(ledger.contains { ($0.sources ?? []).count == 2 }, "receipts seen in both inboxes carry both sources")
        assertFindsTheRightSubscriptions("two inboxes")

        // Removing one inbox keeps what the other still shows.
        let gmail = try XCTUnwrap(scanner.accounts.first { $0.kind == .gmail })
        await scanner.disconnect(gmail)
        assertFindsTheRightSubscriptions("after removing Gmail")
    }
}
