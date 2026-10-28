import XCTest
@testable import Pausely

/// Microsoft Graph and Gmail requests and responses, sign-in security, forged senders, and how receipts
/// from several inboxes are kept.
final class MailboxProvidersTests: XCTestCase {

    private let since = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01
    private var plan: InboxSearchPlan { InboxSearchPlan.standard(catalog: .builtin, since: since) }

    // MARK: Microsoft Graph

    func testGraphQueriesUseKQLWithoutPhrases() {
        let queries = MicrosoftGraphProvider.searchQueries(plan)
        XCTAssertTrue(queries.allSatisfy { $0.hasPrefix("received>=2026-01-01 AND (") && $0.hasSuffix(")") })
        XCTAssertTrue(queries.contains { $0.contains("from:netflix.com") })
        XCTAssertTrue(queries.contains { $0.contains("subject:receipt") })
        XCTAssertTrue(queries.contains { $0.contains("subject:領収書") })
        XCTAssertFalse(queries.contains { $0.contains("\"") }, "quotes inside $search break Graph queries")
        XCTAssertFalse(queries.contains { $0.contains("subject:free") }, "multi-word phrases are left out, not split")
    }

    func testGraphPagesDecode() throws {
        let json = """
        {"@odata.context":"x","value":[
          {"id":"AAMk1","subject":"Your Xbox Game Pass receipt","from":{"emailAddress":{"name":"Microsoft","address":"microsoft-noreply@microsoft.com"}},
           "receivedDateTime":"2026-10-12T15:04:05Z","internetMessageId":"<abc@microsoft.com>","bodyPreview":"Thanks","parentFolderId":"inbox1"},
          {"id":"AAMk2","@removed":{"reason":"deleted"}}
        ],"@odata.nextLink":"https://graph.microsoft.com/v1.0/me/messages?$skip=50","@odata.deltaLink":null}
        """
        let page = try JSONDecoder().decode(MicrosoftGraphProvider.GraphPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.value.count, 2)
        XCTAssertEqual(page.value[0].from?.emailAddress?.address, "microsoft-noreply@microsoft.com")
        XCTAssertNotNil(page.value[0].receivedDate)
        XCTAssertNotNil(page.value[1].removed)
        XCTAssertEqual(page.nextLink, "https://graph.microsoft.com/v1.0/me/messages?$skip=50")
    }

    func testMicrosoftSignInSettings() {
        let oauth = MicrosoftGraphProvider.oauth
        XCTAssertEqual(Set(oauth.scopes), ["offline_access", "User.Read", "Mail.Read"], "read-only mail access")
        XCTAssertEqual(oauth.authorizeURL.host, "login.microsoftonline.com")
        XCTAssertTrue(oauth.redirectURI.hasPrefix(oauth.callbackScheme + "://"))
    }

    // MARK: Gmail

    func testGmailQueriesCoverEveryPass() {
        let queries = GmailMailboxProvider.searchQueries(plan)
        XCTAssertEqual(queries.first, "category:purchases after:2026/01/01")
        XCTAssertTrue(queries.contains { $0.hasPrefix("from:(") && $0.contains("netflix.com") })
        XCTAssertTrue(queries.contains { $0.contains("\"free trial\"") })
        XCTAssertTrue(queries.allSatisfy { $0.contains("after:2026/01/01") })
    }

    func testGmailSignInIsReadOnly() {
        XCTAssertEqual(GmailMailboxProvider.oauth.scopes, ["https://www.googleapis.com/auth/gmail.readonly"])
    }

    func testGmailMetadataDecodes() throws {
        let json = """
        {"id":"18f","internalDate":"1791000000000","labelIds":["CATEGORY_PURCHASES","INBOX"],"snippet":"Receipt",
         "payload":{"headers":[{"name":"From","value":"Spotify <no-reply@spotify.com>"},{"name":"Message-ID","value":"<X@spotify.com>"},{"name":"from","value":"later"}]}}
        """
        let detail = try JSONDecoder().decode(GmailMailboxProvider.MessageDetail.self, from: Data(json.utf8))
        XCTAssertEqual(detail.headerMap["from"], "Spotify <no-reply@spotify.com>", "first header wins")
        XCTAssertEqual(detail.receivedDate, Date(timeIntervalSince1970: 1_791_000_000))
    }

    // MARK: Sign-in security

    /// RFC 7636 appendix B.
    func testPKCEChallengeMatchesTheStandard() {
        XCTAssertEqual(OAuthSession.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
                       "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testRandomValuesAreURLSafeAndUnique() {
        let a = OAuthSession.randomURLSafe(bytes: 32), b = OAuthSession.randomURLSafe(bytes: 32)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.count, 43)
        XCTAssertNil(a.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
    }

    func testFormBodiesAreEncoded() {
        let body = OAuthSession.formEncode(["code": "4/0Ab+c d&e=f", "grant_type": "authorization_code"])
        XCTAssertEqual(body, "code=4%2F0Ab%2Bc%20d%26e%3Df&grant_type=authorization_code")
    }

    func testTokensKnowWhenTheyExpire() {
        XCTAssertTrue(OAuthSession.Tokens(accessToken: "a", refreshToken: nil, expiresAt: Date().addingTimeInterval(600)).isFresh)
        XCTAssertFalse(OAuthSession.Tokens(accessToken: "a", refreshToken: nil, expiresAt: Date().addingTimeInterval(30)).isFresh)
    }

    // MARK: Forged senders

    private func email(from: String, authentication: String?) -> RawEmail {
        var headers: [String: String] = [:]
        if let authentication { headers["authentication-results"] = authentication }
        return RawEmail(id: UUID().uuidString, date: Date(), from: from, subject: "Your Netflix receipt",
                        bodyText: "Thanks for your payment of $15.49. Your membership renews monthly on the 14th. Total charged $15.49.",
                        bodyHTML: nil, headers: headers, labelIds: [])
    }

    func testForgedBrandReceiptsAreFlaggedAndIgnored() throws {
        let forged = try XCTUnwrap(EmailSignalExtractor.extract(email(
            from: "Netflix <billing@netflix.com>",
            authentication: "mx.google.com; dkim=fail header.d=netflix.com; spf=fail smtp.mailfrom=evil.example; dmarc=fail (p=REJECT) header.from=netflix.com")))
        XCTAssertEqual(forged.signal.spoofSuspected, true)

        let genuine = try XCTUnwrap(EmailSignalExtractor.extract(email(
            from: "Netflix <info@account.netflix.com>",
            authentication: "mx.google.com; dkim=pass header.i=@netflix.com header.s=s1; spf=pass smtp.mailfrom=bounces.netflix.com; dmarc=pass")))
        XCTAssertNil(genuine.signal.spoofSuspected)

        let unknown = try XCTUnwrap(EmailSignalExtractor.extract(email(from: "Netflix <info@netflix.com>", authentication: nil)))
        XCTAssertNil(unknown.signal.spoofSuspected, "no verdict recorded is not proof of forgery")

        // A small company sending through an email service isn't a forgery just because it's unaligned.
        let small = try XCTUnwrap(EmailSignalExtractor.extract(email(
            from: "SmallCo <billing@smallco.io>",
            authentication: "mx.google.com; dkim=pass header.d=mailgun.org; spf=pass smtp.mailfrom=mg.mailgun.org")))
        XCTAssertNil(small.signal.spoofSuspected)

        let report = SubscriptionIntelligenceEngine().analyze(signals: [forged.signal])
        XCTAssertTrue(report.subscriptions.isEmpty, "a forged receipt alone proves nothing")
    }

    func testUnverifiedDKIMSignatureHeaderIsNotTrusted() {
        let intel = HeaderIntel.analyze(headers: ["dkim-signature": "v=1; a=rsa-sha256; d=netflix.com; s=x; b=forged"])
        XCTAssertNil(intel.authenticatedDomain)
    }

    // MARK: Several inboxes

    private func signal(_ id: String, sources: [String]?) -> ReceiptSignal {
        ReceiptSignal(id: id, date: Date(), senderDomain: "netflix.com", senderName: "Netflix", merchantHint: nil,
                      platform: "direct", kind: .charge, amount: 15.49, currency: "USD", cadenceHint: .monthly,
                      trialDays: nil, renewalLanguage: true, oneTimeLanguage: false, promotional: false, sources: sources)
    }

    func testSameReceiptInTwoInboxesIsOneFactWithBothSources() {
        let merged = ReceiptLedger.merge([signal("m1@netflix.com", sources: ["B"])],
                                         into: [signal("m1@netflix.com", sources: ["A"])])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.sources, ["A", "B"])
    }

    func testDisconnectingKeepsReceiptsAnotherInboxStillHas() {
        ReceiptLedger.save([signal("shared@x.com", sources: ["A", "B"]), signal("onlyA@x.com", sources: ["A"]),
                            signal("legacy@x.com", sources: nil)])
        defer { ReceiptLedger.clear() }
        let kept = ReceiptLedger.removeSource("A", remainingAccounts: 1)
        XCTAssertEqual(Set(kept.map(\.id)), ["shared@x.com", "legacy@x.com"])
        XCTAssertEqual(kept.first { $0.id == "shared@x.com" }?.sources, ["B"])
        XCTAssertTrue(ReceiptLedger.removeSource("B", remainingAccounts: 0).isEmpty, "the last inbox takes everything")
    }

    func testTriageReadsKnownBillersFirstAndEachReceiptOnce() {
        let old = Date(timeIntervalSince1970: 1_780_000_000), new = Date(timeIntervalSince1970: 1_790_000_000)
        let summaries = [
            MessageSummary(ref: MessageRef(id: "1"), from: "Shop <orders@unknownshop.com>", subject: "Your receipt", receivedDate: new, messageID: "a@x"),
            MessageSummary(ref: MessageRef(id: "2"), from: "Netflix <info@netflix.com>", subject: "Your receipt", receivedDate: old, messageID: "b@x"),
            MessageSummary(ref: MessageRef(id: "3", folder: "Archive"), from: "Netflix <info@netflix.com>", subject: "Your receipt", receivedDate: old, messageID: "b@x"),
            MessageSummary(ref: MessageRef(id: "4"), from: "Friend <amy@gmail.com>", subject: "Dinner Friday?", receivedDate: new, messageID: "c@x")
        ]
        let wanted = InboxScanner.triage(summaries, catalog: .builtin)
        XCTAssertEqual(wanted.map(\.ref.id), ["2", "1"])
    }
}
