import Foundation

/// iCloud, Yahoo, AOL, Gmail (app password), GMX, WEB.DE, Zoho, Fastmail and any IMAP server, read-only.
final class IMAPMailboxProvider: MailboxProvider {
    let account: MailboxAccount
    private let client: IMAPClient
    private let passwordOverride: String?
    private(set) var folders: [String] = []

    /// - Parameter password: used while connecting for the first time, before it is in the Keychain.
    init(account: MailboxAccount, password: String? = nil, allowsInsecureLocalhost: Bool = false) {
        self.account = account
        self.passwordOverride = password
        var configuration = IMAPClient.Configuration(host: account.host ?? "")
        configuration.port = UInt16(clamping: account.port ?? 993)
        configuration.allowsInsecureLocalhost = allowsInsecureLocalhost
        client = IMAPClient(configuration)
    }

    func open() async throws {
        guard let host = account.host, !host.isEmpty else { throw MailboxError.notConfigured("No mail server for this inbox.") }
        guard let password = passwordOverride ?? MailboxAccountStore.secret(.password, for: account.id), !password.isEmpty else {
            throw MailboxError.authExpired
        }
        try await client.connect()
        try await client.login(user: account.address, password: password)
        folders = Self.searchFolders(try await client.listFolders())
    }

    /// Where receipts live: Gmail's "All Mail" covers everything; elsewhere the inbox, the archive and any
    /// folder named for receipts or purchases. Never Trash, Junk, Sent or Drafts.
    static func searchFolders(_ list: [IMAPParser.Folder]) -> [String] {
        let skipFlags: Set<String> = ["\\TRASH", "\\JUNK", "\\SENT", "\\DRAFTS"]
        let selectable = list.filter { $0.isSelectable && $0.flags.isDisjoint(with: skipFlags) }
        if let all = selectable.first(where: { $0.flags.contains("\\ALL") }) { return [all.name] }

        var result: [String] = []
        func add(_ name: String) { if !result.contains(name) { result.append(name) } }
        add(selectable.first { $0.name.uppercased() == "INBOX" }?.name ?? "INBOX")
        if let archive = selectable.first(where: { $0.flags.contains("\\ARCHIVE") })
            ?? selectable.first(where: { ["archive", "archives"].contains($0.name.lowercased()) }) {
            add(archive.name)
        }
        for folder in selectable {
            let name = folder.name.lowercased()
            if name.contains("receipt") || name.contains("purchase") || name.contains("bills") || name.contains("subscriptions") {
                add(folder.name)
            }
        }
        return result
    }

    // MARK: - Candidates

    func candidates(plan: InboxSearchPlan, cursor: String?) async throws -> (refs: [MessageRef], cursor: String?) {
        let previous = SyncCursor.decode(cursor)
        var next: [String: SyncCursor.Entry] = [:]
        var refs: [MessageRef] = []

        for folder in folders {
            try Task.checkCancellation()
            let status: IMAPClient.FolderStatus
            do { status = try await client.examine(folder) } catch MailboxError.server { continue }
            let validity = status.uidValidity ?? 0
            let newest = status.uidNext.map { $0 > 0 ? $0 - 1 : 0 } ?? 0
            var uids = Set<UInt32>()

            if let entry = previous[folder], entry.validity == validity, validity != 0 {
                // Only mail that arrived since the last scan. "n:*" always includes the newest message,
                // so drop anything not newer than the last one seen.
                if newest > entry.lastUID {
                    let found = try await client.uidSearch(.uidRange(lower: entry.lastUID + 1, upper: nil))
                    uids.formUnion(found.filter { $0 > entry.lastUID })
                }
                next[folder] = SyncCursor.Entry(validity: validity, lastUID: max(entry.lastUID, newest))
            } else if status.exists > 0 {
                for key in Self.searchKeys(plan) {
                    try Task.checkCancellation()
                    do { uids.formUnion(try await client.uidSearch(key)) }
                    catch MailboxError.server { continue }  // e.g. a server without UTF-8 search skips that pass
                }
                next[folder] = SyncCursor.Entry(validity: validity, lastUID: newest)
            } else {
                next[folder] = SyncCursor.Entry(validity: validity, lastUID: newest)
            }
            refs += uids.sorted(by: >).prefix(plan.maxCandidates).map { MessageRef(id: String($0), folder: folder) }
        }
        return (refs, SyncCursor.encode(next))
    }

    /// The search passes as IMAP searches: senders in batches, then subject words (ASCII and UTF-8 apart,
    /// since some servers can't search UTF-8).
    static func searchKeys(_ plan: InboxSearchPlan) -> [IMAPSearchKey] {
        let since = IMAPSearchKey.since(plan.since)
        var keys: [IMAPSearchKey] = []
        for batch in InboxSearchPlan.batches(plan.platformDomains + plan.billerDomains, size: 20) {
            if let any = IMAPSearchKey.anyOf(batch.map(IMAPSearchKey.from)) { keys.append(.and([since, any])) }
        }
        let ascii = plan.subjectTerms.filter { !IMAPArgument.needsLiteral($0) }
        let unicode = plan.subjectTerms.filter { IMAPArgument.needsLiteral($0) }
        for batch in InboxSearchPlan.batches(ascii, size: 12) + InboxSearchPlan.batches(unicode, size: 8) {
            if let any = IMAPSearchKey.anyOf(batch.map(IMAPSearchKey.subject)) { keys.append(.and([since, any])) }
        }
        return keys
    }

    // MARK: - Reading

    static let headerFields = "FROM SUBJECT DATE MESSAGE-ID LIST-UNSUBSCRIBE LIST-ID PRECEDENCE"

    func summaries(_ refs: [MessageRef]) async throws -> [MessageSummary] {
        var summaries: [MessageSummary] = []
        let byFolder = Dictionary(grouping: refs) { $0.folder ?? "INBOX" }
        for (folder, folderRefs) in byFolder {
            try await select(folder)
            let uids = folderRefs.compactMap { UInt32($0.id) }
            for batch in InboxSearchPlan.batches(uids, size: 60) {
                try Task.checkCancellation()
                let items = try await client.uidFetch(batch, items: "(UID INTERNALDATE BODY.PEEK[HEADER.FIELDS (\(Self.headerFields))])")
                for item in items {
                    guard let uid = item.uid else { continue }
                    let headers = item.section.map(MIMEParser.parseHeaders) ?? [:]
                    summaries.append(MessageSummary(
                        ref: MessageRef(id: String(uid), folder: folder),
                        from: headers["from"] ?? "", subject: headers["subject"] ?? "",
                        receivedDate: item.internalDate ?? headers["date"].flatMap(MIMEParser.parseDate),
                        messageID: MIMEParser.normalizedMessageID(headers["message-id"])))
                }
            }
        }
        return summaries
    }

    func rawMessage(_ ref: MessageRef) async throws -> Data? {
        guard let uid = UInt32(ref.id) else { return nil }
        try await select(ref.folder ?? "INBOX")
        let items = try await client.uidFetch([uid], items: "(UID BODY.PEEK[]<0.\(MIMEParser.maxMessageBytes)>)")
        return items.first { $0.uid == uid }?.section
    }

    func close() async {
        await client.logout()
    }

    /// App passwords are revoked by the person at their provider; Pausely deletes its copy.
    func revoke() async {}

    private func select(_ folder: String) async throws {
        if await client.selectedFolder != folder { _ = try await client.examine(folder) }
    }

    // MARK: - Sync position

    /// Per folder: UIDVALIDITY and the highest UID seen.
    enum SyncCursor {
        struct Entry: Codable, Equatable {
            var validity: UInt32
            var lastUID: UInt32
        }

        static func decode(_ text: String?) -> [String: Entry] {
            guard let data = text?.data(using: .utf8) else { return [:] }
            return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
        }

        static func encode(_ entries: [String: Entry]) -> String? {
            guard let data = try? JSONEncoder().encode(entries) else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }
}
