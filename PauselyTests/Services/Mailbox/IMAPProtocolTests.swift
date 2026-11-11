import XCTest
@testable import Pausely

/// The IMAP client's pure half: framing, parsing and query building, byte for byte.
final class IMAPProtocolTests: XCTestCase {

    private func bytes(_ text: String) -> [UInt8] { Array(text.utf8) }

    private func parse(_ text: String) throws -> IMAPResponse {
        try IMAPParser.parseResponse(bytes(text))
    }

    // MARK: Framing

    func testFramingWaitsForWholeLinesAndLiterals() throws {
        XCTAssertNil(try IMAPFraming.completeResponseLength(in: bytes("* OK Gimap ready")))
        XCTAssertEqual(try IMAPFraming.completeResponseLength(in: bytes("* OK ready\r\nP1 OK")), 12)

        let fetch = "* 1 FETCH (UID 7 BODY[] {11}\r\nhello\r\nworld)\r\n"
        XCTAssertNil(try IMAPFraming.completeResponseLength(in: bytes(String(fetch.prefix(30)))), "literal not all here yet")
        XCTAssertEqual(try IMAPFraming.completeResponseLength(in: bytes(fetch)), fetch.utf8.count)

        let two = "* 2 FETCH (BODY[HEADER] {3}\r\nabc BODY[TEXT] {2}\r\nde)\r\nP2 OK done\r\n"
        let first = try XCTUnwrap(try IMAPFraming.completeResponseLength(in: bytes(two)))
        XCTAssertEqual(String(decoding: bytes(two)[0..<first], as: UTF8.self), "* 2 FETCH (BODY[HEADER] {3}\r\nabc BODY[TEXT] {2}\r\nde)\r\n")
    }

    func testFramingRefusesAbsurdLiterals() {
        XCTAssertThrowsError(try IMAPFraming.completeResponseLength(in: bytes("* 1 FETCH (BODY[] {999999999}\r\n")))
    }

    // MARK: Status responses

    func testGreetingWithCapabilities() throws {
        let response = try parse("* OK [CAPABILITY IMAP4rev1 LITERAL+ SASL-IR AUTH=PLAIN] Dovecot ready.\r\n")
        XCTAssertEqual(response.kind, .untagged)
        XCTAssertEqual(response.status, "OK")
        XCTAssertEqual(response.code, ["CAPABILITY", "IMAP4rev1", "LITERAL+", "SASL-IR", "AUTH=PLAIN"])
        XCTAssertEqual(response.text, "Dovecot ready.")
    }

    func testFailedLoginCarriesItsCode() throws {
        let response = try parse("P2 NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)\r\n")
        XCTAssertEqual(response.kind, .tagged("P2"))
        XCTAssertEqual(response.status, "NO")
        XCTAssertEqual(response.code, ["AUTHENTICATIONFAILED"])
    }

    func testExamineResponses() throws {
        XCTAssertEqual(try parse("* 172 EXISTS\r\n").number, 172)
        XCTAssertEqual(try parse("* 172 EXISTS\r\n").status, "EXISTS")
        XCTAssertEqual(try parse("* OK [UIDVALIDITY 3857529045] UIDs valid\r\n").code, ["UIDVALIDITY", "3857529045"])
        XCTAssertEqual(try parse("+ Ready for literal data\r\n").kind, .continuation)
    }

    // MARK: Data responses

    func testSearchResults() throws {
        XCTAssertEqual(IMAPParser.searchResults(try parse("* SEARCH 2 84 882\r\n")), [2, 84, 882])
        XCTAssertEqual(IMAPParser.searchResults(try parse("* SEARCH\r\n")), [])
    }

    func testListResponses() throws {
        let inbox = try XCTUnwrap(IMAPParser.folder(try parse(#"* LIST (\HasNoChildren) "/" "INBOX""# + "\r\n")))
        XCTAssertEqual(inbox.name, "INBOX")
        let all = try XCTUnwrap(IMAPParser.folder(try parse(#"* LIST (\All \HasNoChildren) "/" "[Gmail]/All Mail""# + "\r\n")))
        XCTAssertEqual(all.name, "[Gmail]/All Mail")
        XCTAssertTrue(all.flags.contains("\\ALL"))
        let noselect = try XCTUnwrap(IMAPParser.folder(try parse(#"* LIST (\Noselect \HasChildren) "/" "[Gmail]""# + "\r\n")))
        XCTAssertFalse(noselect.isSelectable)
        let atom = try XCTUnwrap(IMAPParser.folder(try parse(#"* LIST () "." Archive"# + "\r\n")))
        XCTAssertEqual(atom.name, "Archive")
        let nilDelimiter = try XCTUnwrap(IMAPParser.folder(try parse(#"* LIST (\Archive) NIL "Archive""# + "\r\n")))
        XCTAssertEqual(nilDelimiter.name, "Archive")
    }

    func testFetchWithHeaderLiteral() throws {
        let headers = "From: Netflix <info@netflix.com>\r\nSubject: Your receipt\r\n\r\n"
        let text = "* 12 FETCH (UID 345 INTERNALDATE \"17-Jul-2026 02:44:25 -0700\" BODY[HEADER.FIELDS (FROM SUBJECT)] {\(headers.utf8.count)}\r\n\(headers))\r\n"
        let item = try XCTUnwrap(IMAPParser.fetchItem(try parse(text)))
        XCTAssertEqual(item.sequence, 12)
        XCTAssertEqual(item.uid, 345)
        XCTAssertNotNil(item.internalDate)
        XCTAssertEqual(item.section.map { String(decoding: $0, as: UTF8.self) }, headers)
        XCTAssertEqual(MIMEParser.parseHeaders(item.section ?? Data())["subject"], "Your receipt")
    }

    func testFetchWithPartialBodyAndNil() throws {
        let item = try XCTUnwrap(IMAPParser.fetchItem(try parse("* 3 FETCH (BODY[]<0> {5}\r\nhello UID 9)\r\n")))
        XCTAssertEqual(item.uid, 9)
        XCTAssertEqual(item.section, Data("hello".utf8))
        let empty = try XCTUnwrap(IMAPParser.fetchItem(try parse("* 4 FETCH (UID 10 BODY[HEADER.FIELDS (FROM)] NIL)\r\n")))
        XCTAssertNil(empty.section)
        XCTAssertNil(IMAPParser.fetchItem(try parse("* 5 FETCH (FLAGS (\\Seen))\r\n"))?.uid, "flag updates aren't messages")
    }

    func testQuotedStringEscapes() throws {
        let response = try parse(#"* LIST () "/" "Quotes \"and\" \\backslash""# + "\r\n")
        XCTAssertEqual(IMAPParser.folder(response)?.name, #"Quotes "and" \backslash"#)
    }

    func testMalformedResponsesThrowInsteadOfCrashing() {
        XCTAssertThrowsError(try parse("* LIST (\\HasNoChildren \"/\" \"INBOX\"\r\n"))
        XCTAssertThrowsError(try parse("* 1 FETCH (BODY[] {10}\r\nshort)\r\n"))
        XCTAssertThrowsError(try parse("* LIST () \"/\" \"unterminated\r\n"))
    }

    /// A server that announces a negative length must get an error back, not take the app down.
    func testNegativeLiteralLengthIsMalformed() {
        XCTAssertThrowsError(try parse("* 1 FETCH (BODY[] {-5}\r\n)\r\n")) { error in
            guard case IMAPProtocolError.malformed(let reason) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(reason, "bad literal")
        }
    }

    /// A message size beyond what an Int holds is dropped; the rest of the item is still read.
    func testImpossibleMessageSizeIsDropped() throws {
        let item = try XCTUnwrap(IMAPParser.fetchItem(try parse("* 7 FETCH (UID 42 RFC822.SIZE 18446744073709551615)\r\n")))
        XCTAssertEqual(item.uid, 42)
        XCTAssertNil(item.size)
        let ordinary = try XCTUnwrap(IMAPParser.fetchItem(try parse("* 8 FETCH (UID 43 RFC822.SIZE 2048)\r\n")))
        XCTAssertEqual(ordinary.size, 2048)
    }

    func testInternalDate() {
        // The exact moment, time zone included (RFC 3501 date-time; a single-digit day starts with a space).
        XCTAssertEqual(IMAPParser.parseInternalDate("17-Jul-1996 02:44:25 -0700")?.timeIntervalSince1970, 837596665)
        XCTAssertEqual(IMAPParser.parseInternalDate(" 7-Jul-2026 02:44:25 +0000")?.timeIntervalSince1970, 1783392265)
        XCTAssertNil(IMAPParser.parseInternalDate("not a date"))
    }

    // MARK: Commands

    func testSearchKeysNestOrsAndQuoteSafely() {
        let key = IMAPSearchKey.and([.since(Date(timeIntervalSince1970: 1_767_225_600)),
                                     IMAPSearchKey.anyOf([.from("netflix.com"), .from("spotify.com"), .from("hulu.com")])!])
        let rendered = key.arguments.map { argument -> String in
            switch argument {
            case .raw(let text): return text
            case .string(let value): return IMAPArgument.quoted(value)
            }
        }.joined(separator: " ")
        XCTAssertEqual(rendered, #"SINCE 1-Jan-2026 OR FROM "netflix.com" OR FROM "spotify.com" FROM "hulu.com""#)
        XCTAssertFalse(key.needsUTF8)
        XCTAssertTrue(IMAPSearchKey.subject("領収書").needsUTF8)
        XCTAssertEqual(IMAPArgument.quoted(#"a"b\c"#), #""a\"b\\c""#)
        XCTAssertTrue(IMAPArgument.needsLiteral("pass\r\nword"))
    }

    func testBalancedOrStaysShallow() {
        let keys = (0..<20).map { IMAPSearchKey.from("d\($0).com") }
        func depth(_ key: IMAPSearchKey) -> Int {
            if case .or(let a, let b) = key { return 1 + max(depth(a), depth(b)) }
            return 0
        }
        XCTAssertEqual(depth(IMAPSearchKey.anyOf(keys)!), 5)
    }

    func testSequenceSetCompresses() {
        XCTAssertEqual(IMAPClient.sequenceSet([9, 1, 2, 3, 7, 10, 3]), "1:3,7,9:10")
        XCTAssertEqual(IMAPClient.sequenceSet([5]), "5")
    }

    // MARK: Provider decisions

    func testFolderChoice() {
        func folder(_ name: String, _ flags: [String] = []) -> IMAPParser.Folder {
            IMAPParser.Folder(name: name, flags: Set(flags.map { $0.uppercased() }))
        }
        XCTAssertEqual(IMAPMailboxProvider.searchFolders([folder("INBOX"), folder("[Gmail]/All Mail", ["\\All"]),
                                                          folder("[Gmail]/Spam", ["\\Junk"])]), ["[Gmail]/All Mail"])
        XCTAssertEqual(IMAPMailboxProvider.searchFolders([folder("INBOX"), folder("Archive", ["\\Archive"]),
                                                          folder("Junk", ["\\Junk"]), folder("Deleted Messages", ["\\Trash"]),
                                                          folder("Receipts")]), ["INBOX", "Archive", "Receipts"])
        XCTAssertEqual(IMAPMailboxProvider.searchFolders([folder("Inbox"), folder("Archive")]), ["Inbox", "Archive"])
        XCTAssertEqual(IMAPMailboxProvider.searchFolders([]), ["INBOX"])
    }

    func testSearchPlanBecomesIMAPSearches() {
        let plan = InboxSearchPlan.standard(catalog: .builtin, since: Date(timeIntervalSince1970: 1_767_225_600))
        let keys = IMAPMailboxProvider.searchKeys(plan)
        let senders = plan.platformDomains.count + plan.billerDomains.count
        let ascii = plan.subjectTerms.filter { !IMAPArgument.needsLiteral($0) }.count
        let unicode = plan.subjectTerms.count - ascii
        func batches(_ count: Int, _ size: Int) -> Int { (count + size - 1) / size }
        XCTAssertEqual(keys.count, batches(senders, 20) + batches(ascii, 12) + batches(unicode, 8))
        XCTAssertTrue(keys.contains { $0.needsUTF8 })
        XCTAssertGreaterThan(plan.billerDomains.count, 100, "every built-in biller is searched")
        XCTAssertFalse(plan.billerDomains.contains("apple.com"), "platforms aren't duplicated as billers")
    }

    func testSyncCursorRoundTrip() {
        let entries = ["INBOX": IMAPMailboxProvider.SyncCursor.Entry(validity: 7, lastUID: 1234)]
        XCTAssertEqual(IMAPMailboxProvider.SyncCursor.decode(IMAPMailboxProvider.SyncCursor.encode(entries)), entries)
        XCTAssertEqual(IMAPMailboxProvider.SyncCursor.decode("garbage"), [:])
    }

    func testPresetsMatchAddresses() {
        XCTAssertEqual(IMAPPreset.forAddress("jane@me.com")?.id, "icloud")
        XCTAssertEqual(IMAPPreset.forAddress("JANE@ICLOUD.COM")?.id, "icloud")
        XCTAssertEqual(IMAPPreset.forAddress("joe@yahoo.co.uk")?.id, "yahoo")
        XCTAssertEqual(IMAPPreset.forAddress("bob@verizon.net")?.id, "aol")
        XCTAssertEqual(IMAPPreset.forAddress("amy@gmail.com")?.id, "gmail-imap")
        XCTAssertEqual(IMAPPreset.forAddress("hans@gmx.de")?.host, "imap.gmx.net")
        XCTAssertNil(IMAPPreset.forAddress("me@mycompany.com"))
        XCTAssertTrue(IMAPPreset.all.allSatisfy { !$0.host.isEmpty && !$0.steps.isEmpty })
    }

    func testPastedAppPasswordsLoseTheirDisplaySpaces() {
        // Google and Yahoo show app passwords in groups of four; the spaces aren't part of them.
        XCTAssertEqual(IMAPPreset.cleanPassword(" abcd efgh ijkl mnop\n", for: IMAPPreset.find("gmail-imap")), "abcdefghijklmnop")
        XCTAssertEqual(IMAPPreset.cleanPassword("abcd efgh ijkl mnop", for: IMAPPreset.find("yahoo")), "abcdefghijklmnop")
        XCTAssertEqual(IMAPPreset.cleanPassword("abcd-efgh-ijkl-mnop", for: IMAPPreset.find("icloud")), "abcd-efgh-ijkl-mnop")
        // Elsewhere a password can really contain a space: only the ends are trimmed.
        XCTAssertEqual(IMAPPreset.cleanPassword(" my pass word ", for: nil), "my pass word")
        XCTAssertEqual(IMAPPreset.cleanPassword("my pass word", for: IMAPPreset.find("fastmail")), "my pass word")
    }

    /// A wrong server name or port is reported at once, in words a person can act on.
    func testUnreachableServersFailFastWithAPlainMessage() async throws {
        let cases: [(String, UInt16, String)] = [("127.0.0.1", 1, "turned the connection away"),
                                                 ("imap.pausely-check.invalid", 993, "No server by that name")]
        for (host, port, says) in cases {
            let start = Date()
            let client = IMAPClient(IMAPClient.Configuration(host: host, port: port, commandTimeout: 20))
            do {
                try await client.connect()
                XCTFail("\(host):\(port) should not connect")
            } catch {
                let message = error.localizedDescription
                print("UNREACHABLE \(host):\(port) after \(Date().timeIntervalSince(start))s: \(message)")
                XCTAssertFalse(message.contains("POSIX") || message.contains("NWError") || message.contains("rawValue"), message)
                XCTAssertTrue(message.hasPrefix("Couldn't reach the mail server."), message)
                XCTAssertTrue(message.contains(says), "\(host):\(port) should say what to check: \(message)")
            }
            XCTAssertLessThan(Date().timeIntervalSince(start), 8, "\(host):\(port) should fail fast")
            await client.cancel()
        }
    }

    func testPasswordPageLinksNameThePageTheyOpen() {
        XCTAssertEqual(IMAPConnectView.pageName(URL(string: "https://account.apple.com/account/manage")!), "account.apple.com")
        XCTAssertEqual(IMAPConnectView.pageName(URL(string: "https://www.gmx.com")!), "gmx.com")
        for preset in IMAPPreset.all {
            let page = try? XCTUnwrap(preset.passwordPage, preset.name)
            XCTAssertEqual(page?.scheme, "https", preset.name)
            XCTAssertNotNil(page.flatMap(IMAPConnectView.pageName), preset.name)
        }
    }
}
