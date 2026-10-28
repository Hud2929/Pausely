import Foundation

/// Outlook.com, Hotmail, Live, MSN and Microsoft 365 through Microsoft Graph, read-only (`Mail.Read`).
/// Search results come with sender, subject and date; whole messages are read as raw MIME (`$value`),
/// so every provider goes through the same parser.
final class MicrosoftGraphProvider: MailboxProvider {
    let account: MailboxAccount
    private var cachedSummaries: [String: MessageSummary] = [:]
    private var excludedFolderIDs: Set<String> = []

    static let graph = URL(string: "https://graph.microsoft.com/v1.0")!

    init(account: MailboxAccount) {
        self.account = account
    }

    /// The app registration's client id (Info.plist `MS_CLIENT_ID`). Empty until the owner registers the app.
    static var clientID: String {
        (Bundle.main.object(forInfoDictionaryKey: "MS_CLIENT_ID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isConfigured: Bool {
        let id = clientID
        return !id.isEmpty && !id.hasPrefix("$(")
    }

    static var oauth: OAuthSession.Provider {
        OAuthSession.Provider(
            authorizeURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
            tokenURL: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!,
            clientID: clientID,
            redirectURI: "msauth.com.pausely.app.Pausely://auth",
            callbackScheme: "msauth.com.pausely.app.Pausely",
            scopes: ["offline_access", "User.Read", "Mail.Read"],
            extraAuthorizeParameters: ["prompt": "select_account", "response_mode": "query"],
            sendsScopeOnTokenRequest: true)
    }

    // MARK: - Connecting

    /// Signs in and returns the new account (tokens stored in the Keychain).
    @MainActor
    static func connect() async throws -> MailboxAccount {
        guard isConfigured else {
            throw MailboxError.notConfigured("Outlook sign-in isn't set up in this build yet.")
        }
        let tokens = try await OAuthSession.signIn(oauth)
        let id = UUID().uuidString
        OAuthSession.store(tokens, for: id)
        do {
            let address = try await fetchAddress(token: tokens.accessToken)
            let account = MailboxAccount(id: id, kind: .microsoft, address: address, addedAt: Date())
            MailboxAccountStore.upsert(account)
            return account
        } catch {
            MailboxAccountStore.remove(id)
            throw error
        }
    }

    private static func fetchAddress(token: String) async throws -> String {
        let request = URLRequest(url: URL(string: graph.absoluteString + "/me?$select=mail,userPrincipalName")!)
        let data = try await MailboxHTTP.data(request, token: { token }, refresh: { throw MailboxError.authExpired })
        struct Me: Decodable { let mail: String?; let userPrincipalName: String? }
        let me = try JSONDecoder().decode(Me.self, from: data)
        guard let address = me.mail ?? me.userPrincipalName else { throw MailboxError.server("No email address on this account.") }
        return address
    }

    // MARK: - MailboxProvider

    func open() async throws {
        _ = try await token()
        // Never read Junk or Deleted Items.
        for wellKnown in ["junkemail", "deleteditems"] {
            if let data = try? await get("/me/mailFolders/\(wellKnown)?$select=id"),
               let folder = try? JSONDecoder().decode(GraphFolder.self, from: data) {
                excludedFolderIDs.insert(folder.id)
            }
        }
    }

    func candidates(plan: InboxSearchPlan, cursor: String?) async throws -> (refs: [MessageRef], cursor: String?) {
        var found: [GraphMessage] = []
        if let deltaLink = cursor, deltaLink.hasPrefix("https://graph.microsoft.com/") {
            // Only mail that arrived since the last scan.
            let changes = try await followDelta(deltaLink)
            return (store(changes.messages, limit: plan.maxCandidates), changes.deltaLink ?? deltaLink)
        }
        for query in Self.searchQueries(plan) {
            try Task.checkCancellation()
            found += try await search(query, maxPages: 4)
            if found.count >= plan.maxCandidates * 2 { break }
        }
        // Start watching for new mail from now on.
        let deltaLink = try? await startDelta()
        return (store(found, limit: plan.maxCandidates), deltaLink)
    }

    func summaries(_ refs: [MessageRef]) async throws -> [MessageSummary] {
        refs.compactMap { cachedSummaries[$0.id] }
    }

    func rawMessage(_ ref: MessageRef) async throws -> Data? {
        guard let encoded = ref.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return try await get("/me/messages/\(encoded)/$value")
    }

    func close() async {}

    /// Microsoft offers no token revocation for this kind of app; Pausely deletes its tokens, and the person
    /// can remove access at account.live.com/consent/Manage.
    func revoke() async {}

    // MARK: - Search

    /// KQL searches: senders in batches, then subject words. Graph searches every folder.
    static func searchQueries(_ plan: InboxSearchPlan) -> [String] {
        let since = "received>=" + kqlDate(plan.since)
        var queries: [String] = []
        for batch in InboxSearchPlan.batches(plan.platformDomains + plan.billerDomains, size: 12) {
            queries.append("\(since) AND (" + batch.map { "from:\($0)" }.joined(separator: " OR ") + ")")
        }
        // Phrases can't be quoted inside $search, so only single words are used.
        let words = Array(Set(plan.subjectTerms.filter { !$0.contains(" ") && !$0.contains("-") })).sorted()
        for batch in InboxSearchPlan.batches(words, size: 10) {
            queries.append("\(since) AND (" + batch.map { "subject:\($0)" }.joined(separator: " OR ") + ")")
        }
        return queries
    }

    static func kqlDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    private static let select = "id,subject,from,receivedDateTime,internetMessageId,bodyPreview,parentFolderId"

    private func search(_ kql: String, maxPages: Int) async throws -> [GraphMessage] {
        var components = URLComponents(string: Self.graph.absoluteString + "/me/messages")!
        components.queryItems = [
            URLQueryItem(name: "$search", value: "\"\(kql)\""),
            URLQueryItem(name: "$select", value: Self.select),
            URLQueryItem(name: "$top", value: "50")
        ]
        var next = components.url
        var messages: [GraphMessage] = []
        var pages = 0
        while let url = next, pages < maxPages {
            try Task.checkCancellation()
            let page = try JSONDecoder().decode(GraphPage.self, from: try await getURL(url))
            messages += page.value
            next = page.nextLink.flatMap(URL.init(string:))
            pages += 1
        }
        return messages
    }

    private func startDelta() async throws -> String? {
        var components = URLComponents(string: Self.graph.absoluteString + "/me/mailFolders/inbox/messages/delta")!
        let now = ISO8601DateFormatter().string(from: Date())
        components.queryItems = [
            URLQueryItem(name: "$select", value: Self.select),
            URLQueryItem(name: "$filter", value: "receivedDateTime ge \(now)")
        ]
        guard let url = components.url else { return nil }
        return try await followDelta(url.absoluteString).deltaLink
    }

    private func followDelta(_ link: String) async throws -> (messages: [GraphMessage], deltaLink: String?) {
        var next = URL(string: link)
        var messages: [GraphMessage] = []
        var pages = 0
        while let url = next, pages < 20 {
            let page = try JSONDecoder().decode(GraphPage.self, from: try await getURL(url))
            messages += page.value.filter { $0.removed == nil }
            if let delta = page.deltaLink { return (messages, delta) }
            next = page.nextLink.flatMap(URL.init(string:))
            pages += 1
        }
        return (messages, nil)
    }

    private func store(_ messages: [GraphMessage], limit: Int) -> [MessageRef] {
        var seen = Set<String>()
        let kept = messages
            .filter { !excludedFolderIDs.contains($0.parentFolderId ?? "") }
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.receivedDate ?? .distantPast) > ($1.receivedDate ?? .distantPast) }
            .prefix(limit)
        for message in kept {
            let sender = message.from?.emailAddress
            let from = sender.map { address -> String in
                let name = address.name ?? ""
                return name.isEmpty ? (address.address ?? "") : "\(name) <\(address.address ?? "")>"
            } ?? ""
            cachedSummaries[message.id] = MessageSummary(
                ref: MessageRef(id: message.id), from: from, subject: message.subject ?? "",
                snippet: message.bodyPreview ?? "", receivedDate: message.receivedDate,
                messageID: MIMEParser.normalizedMessageID(message.internetMessageId))
        }
        return kept.map { MessageRef(id: $0.id) }
    }

    // MARK: - HTTP

    private func token() async throws -> String {
        try await OAuthSession.validAccessToken(Self.oauth, accountID: account.id)
    }

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: Self.graph.absoluteString + path) else { throw MailboxError.server("Bad address") }
        return try await getURL(url)
    }

    private func getURL(_ url: URL) async throws -> Data {
        guard url.host == "graph.microsoft.com" else { throw MailboxError.insecure("Unexpected server in a Graph response.") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 40
        let accountID = account.id
        return try await MailboxHTTP.data(request,
                                          token: { try await self.token() },
                                          refresh: { try await OAuthSession.forceRefresh(Self.oauth, accountID: accountID) })
    }

    // MARK: - Response models

    struct GraphPage: Decodable {
        let value: [GraphMessage]
        let nextLink: String?
        let deltaLink: String?

        enum CodingKeys: String, CodingKey {
            case value
            case nextLink = "@odata.nextLink"
            case deltaLink = "@odata.deltaLink"
        }
    }

    struct GraphMessage: Decodable {
        let id: String
        let subject: String?
        let from: Recipient?
        let receivedDateTime: String?
        let internetMessageId: String?
        let bodyPreview: String?
        let parentFolderId: String?
        let removed: Removed?

        struct Recipient: Decodable {
            let emailAddress: Address?
            struct Address: Decodable { let name: String?; let address: String? }
        }
        struct Removed: Decodable { let reason: String? }

        enum CodingKeys: String, CodingKey {
            case id, subject, from, receivedDateTime, internetMessageId, bodyPreview, parentFolderId
            case removed = "@removed"
        }

        var receivedDate: Date? {
            guard let receivedDateTime else { return nil }
            return ISO8601DateFormatter().date(from: receivedDateTime)
        }
    }

    struct GraphFolder: Decodable { let id: String }
}
