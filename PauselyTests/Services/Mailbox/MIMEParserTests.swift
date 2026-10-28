import XCTest
@testable import Pausely

/// The parser every inbox shares (IMAP, Microsoft Graph `$value`, Gmail `format=raw`).
final class MIMEParserTests: XCTestCase {

    private func data(_ text: String, encoding: String.Encoding = .utf8) -> Data {
        text.replacingOccurrences(of: "\n", with: "\r\n").data(using: encoding)!
    }

    func testSimplePlainMessage() throws {
        let raw = data("""
        From: Netflix <info@account.netflix.com>
        Subject: Your Netflix receipt
        Date: Tue, 14 Oct 2026 09:30:00 -0400
        Message-ID: <ABC123@netflix.com>
        Content-Type: text/plain; charset=utf-8

        Thanks for your payment of $15.49. Your membership renews on November 14, 2026. This is the long enough body text so the plain part is used instead of any html alternative that might exist.
        """)
        let email = try XCTUnwrap(MIMEParser.parse(raw, id: "1"))
        XCTAssertEqual(email.from, "Netflix <info@account.netflix.com>")
        XCTAssertEqual(email.subject, "Your Netflix receipt")
        XCTAssertTrue(email.bodyText.contains("$15.49"))
        XCTAssertEqual(email.headers["message-id"], "<ABC123@netflix.com>")
        XCTAssertEqual(MIMEParser.normalizedMessageID(email.headers["message-id"]), "abc123@netflix.com")
        XCTAssertEqual(email.date, MIMEParser.parseDate("Tue, 14 Oct 2026 13:30:00 +0000"))
    }

    func testFoldedAndEncodedHeaders() throws {
        let raw = data("""
        From: =?UTF-8?B?U3BvdGlmeSDwn46n?= <no-reply@spotify.com>
        Subject: =?ISO-8859-1?Q?Votre_re=E7u?=
         =?ISO-8859-1?Q?_Spotify_Premium?=
        Date: 3 Oct 2026 10:00:00 +0000
        Content-Type: text/plain

        Merci pour votre paiement de 10,99 EUR. Votre abonnement se renouvelle le 3 novembre. Texte assez long pour être utilisé comme corps principal du message sans repli sur le HTML.
        """)
        let email = try XCTUnwrap(MIMEParser.parse(raw, id: "2"))
        XCTAssertEqual(email.from, "Spotify 🎧 <no-reply@spotify.com>")
        XCTAssertEqual(email.subject, "Votre reçu Spotify Premium")
    }

    func testRawUTF8InHeaders() throws {
        let raw = data("""
        From: ヘルプ <help@example.jp>
        Subject: 領収書のお知らせ
        Date: Mon, 5 Oct 2026 12:00:00 +0900
        Content-Type: text/plain; charset=utf-8

        ご利用ありがとうございます。
        """)
        let email = try XCTUnwrap(MIMEParser.parse(raw, id: "3"))
        XCTAssertEqual(email.subject, "領収書のお知らせ")
    }

    /// The old Gmail reader decoded every body as UTF-8 and silently lost Latin-1 receipts.
    func testMultipartWithLatin1QuotedPrintableAndBase64HTML() throws {
        let html = "<html><body><p>Re\u{E7}u : 12,99 \u{20AC} – abonnement renouvel\u{E9}</p></body></html>"
        let htmlBase64 = Data(html.utf8).base64EncodedString()
        let raw = data("""
        From: Deezer <noreply@deezer.com>
        Subject: Votre facture
        Date: Wed, 1 Oct 2026 08:00:00 +0200
        MIME-Version: 1.0
        Content-Type: multipart/alternative; boundary="b1"

        --b1
        Content-Type: text/plain; charset="iso-8859-1"
        Content-Transfer-Encoding: quoted-printable

        Votre re=E7u : 12,99 EUR. Votre abonnement a =E9t=E9 renouvel=E9 avec succ=E8s=
         pour le mois prochain, merci de votre confiance et =E0 bient=F4t sur Deezer.
        --b1
        Content-Type: text/html; charset=utf-8
        Content-Transfer-Encoding: base64

        \(htmlBase64)
        --b1--
        """)
        let email = try XCTUnwrap(MIMEParser.parse(raw, id: "4"))
        XCTAssertTrue(email.bodyText.contains("Votre reçu : 12,99 EUR"), email.bodyText)
        XCTAssertTrue(email.bodyText.contains("renouvelé avec succès pour le mois"), "soft line break joined")
        XCTAssertEqual(email.bodyHTML, html)
    }

    func testShortPlainPartFallsBackToHTML() throws {
        let raw = data("""
        From: Apple <no_reply@email.apple.com>
        Subject: Your receipt from Apple.
        Date: Thu, 2 Oct 2026 18:00:00 -0700
        Content-Type: multipart/alternative; boundary=XYZ

        --XYZ
        Content-Type: text/plain

        View this email in your browser.
        --XYZ
        Content-Type: text/html

        <table><tr><td>iCloud+ 50 GB</td><td>CA$1.29</td></tr><tr><td>Renews Nov 2, 2026</td></tr></table>
        --XYZ--
        """)
        let email = try XCTUnwrap(MIMEParser.parse(raw, id: "5"))
        XCTAssertEqual(email.bodyText, "", "a one-line plain part shouldn't hide the real receipt in the HTML")
        XCTAssertTrue(email.bodyHTML?.contains("iCloud+ 50 GB") == true)
    }

    func testNestedMultipartSkipsAttachments() throws {
        let raw = data("""
        From: Adobe <mail@mail.adobe.com>
        Subject: Your Adobe invoice
        Date: Fri, 3 Oct 2026 10:00:00 +0000
        Content-Type: multipart/mixed; boundary="outer"

        --outer
        Content-Type: multipart/alternative; boundary="inner"

        --inner
        Content-Type: text/plain; charset=utf-8

        Your Creative Cloud All Apps plan was renewed. Amount charged: US$59.99. Your next billing date is November 3, 2026. Thank you for being an Adobe customer, we appreciate you.
        --inner--
        --outer
        Content-Type: text/plain; name="invoice.txt"
        Content-Disposition: attachment; filename="invoice.txt"

        THIS ATTACHMENT MUST NOT BE READ
        --outer--
        """)
        let email = try XCTUnwrap(MIMEParser.parse(raw, id: "6"))
        XCTAssertTrue(email.bodyText.contains("US$59.99"))
        XCTAssertFalse(email.bodyText.contains("ATTACHMENT"))
    }

    func testJapaneseCharsets() throws {
        let body = "お支払いありがとうございます。ご請求額は1,200円です。次回の更新日は11月3日です。定期購入の内容をご確認ください。サブスクリプションはいつでも解約できます。今後ともよろしくお願いいたします。この文章は十分な長さがあります。"
        for charset in [("Shift_JIS", String.Encoding.shiftJIS), ("ISO-2022-JP", String.Encoding.iso2022JP), ("EUC-JP", String.Encoding.japaneseEUC)] {
            var raw = Data("From: shop@example.jp\r\nSubject: =?UTF-8?B?\(Data("領収書".utf8).base64EncodedString())?=\r\nDate: Sat, 4 Oct 2026 09:00:00 +0900\r\nContent-Type: text/plain; charset=\(charset.0)\r\n\r\n".utf8)
            raw.append(body.data(using: charset.1)!)
            let email = try XCTUnwrap(MIMEParser.parse(raw, id: charset.0))
            XCTAssertEqual(email.bodyText, body, charset.0)
            XCTAssertEqual(email.subject, "領収書")
        }
    }

    func testBareLineFeedsAndUnknownCharset() throws {
        let raw = Data("From: a@b.com\nSubject: Hi\nDate: Sun, 5 Oct 2026 09:00:00 +0000\nContent-Type: text/plain; charset=x-unknown\n\nCaf\u{E9} receipt with enough words to be the main body of this message, which is now definitely long enough for it.".utf8)
        let email = try XCTUnwrap(MIMEParser.parse(raw, id: "7"))
        XCTAssertEqual(email.subject, "Hi")
        XCTAssertTrue(email.bodyText.hasPrefix("Café receipt"))
    }

    func testBoundaryTextInsideBodyIsNotASplit() throws {
        let raw = data("""
        From: a@b.com
        Subject: x
        Date: Sun, 5 Oct 2026 09:00:00 +0000
        Content-Type: multipart/alternative; boundary="sep"

        --sep
        Content-Type: text/plain

        Words that mention --sep in the middle of a line must stay in the body, which is long enough to be used directly as the text of this receipt email.
        --sep--
        """)
        let email = try XCTUnwrap(MIMEParser.parse(raw, id: "8"))
        XCTAssertTrue(email.bodyText.contains("mention --sep in the middle"))
    }

    func testReceivedDateBeatsTheHeader() throws {
        let received = Date(timeIntervalSince1970: 1_790_000_000)
        let raw = data("From: a@b.com\nSubject: x\nDate: Thu, 1 Jan 1970 00:00:00 +0000\nContent-Type: text/plain\n\nbody")
        XCTAssertEqual(MIMEParser.parse(raw, id: "9", receivedDate: received)?.date, received)
    }

    func testDateFormatsSeenInTheWild() {
        XCTAssertNotNil(MIMEParser.parseDate("Tue, 14 Oct 2026 09:30:00 -0400"))
        XCTAssertNotNil(MIMEParser.parseDate("14 Oct 2026 09:30:00 +0000"))
        XCTAssertNotNil(MIMEParser.parseDate("Tue, 14 Oct 2026 09:30:00 +0000 (UTC)"))
        XCTAssertNotNil(MIMEParser.parseDate("Tue,  4 Oct 2026 09:30:00 GMT"))
        XCTAssertNotNil(MIMEParser.parseDate("Tue, 14 Oct 26 09:30:00 +0000"))
        XCTAssertNil(MIMEParser.parseDate("not a date"))
    }

    func testMissingDateWithoutFallbackIsRejected() {
        XCTAssertNil(MIMEParser.parse(data("From: a@b.com\nSubject: x\n\nbody"), id: "10"))
    }

    func testHugeMessagesAreCappedNotCrashed() throws {
        var raw = data("From: a@b.com\nSubject: big\nDate: Sun, 5 Oct 2026 09:00:00 +0000\nContent-Type: text/plain\n\n")
        raw.append(Data(repeating: UInt8(ascii: "a"), count: MIMEParser.maxMessageBytes + 500_000))
        let email = try XCTUnwrap(MIMEParser.parse(raw, id: "11"))
        XCTAssertLessThanOrEqual(email.bodyText.utf8.count, MIMEParser.maxMessageBytes)
    }

    func testMessageIDNormalization() {
        XCTAssertEqual(MIMEParser.normalizedMessageID(" <Abc.123@Mail.Example.COM> "), "abc.123@mail.example.com")
        XCTAssertNil(MIMEParser.normalizedMessageID("<x>"))
        XCTAssertNil(MIMEParser.normalizedMessageID(nil))
    }

    func testRFC2231ParameterAndQuotedBoundary() {
        let type = MIMEParser.ContentType(#"multipart/mixed; boundary="a;b=c"; charset*=utf-8''%E2%82%AC"#)
        XCTAssertEqual(type.type, "multipart")
        XCTAssertEqual(type.parameters["boundary"], "a;b=c")
        XCTAssertEqual(type.parameters["charset"], "€")
    }
}
