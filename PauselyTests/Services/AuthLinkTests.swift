import XCTest
@testable import Pausely

/// Links from account emails come in whatever shape the account service's templates and settings give
/// them. Each shape here is one the service really produces; a sign-up must survive all of them.
final class AuthLinkTests: XCTestCase {

    private func link(_ string: String) -> AuthLink { AuthLink.parse(URL(string: string)!) }

    func testCodeLink_theServiceDefaultForApps() {
        XCTAssertEqual(link("pausely://auth/confirm?code=8a4f1c2e-77aa-4c1d-9d0e-1b2c3d4e5f60"),
                       .code("8a4f1c2e-77aa-4c1d-9d0e-1b2c3d4e5f60"))
        // The service's own default address, when the app's address isn't on its allowed list.
        XCTAssertEqual(link("pausely://auth/callback?code=abc123"), .code("abc123"))
    }

    func testSessionInTheFragment() {
        let url = "pausely://auth/callback#access_token=AAA.BBB.CCC&expires_in=3600&refresh_token=rrr111&token_type=bearer&type=signup"
        XCTAssertEqual(link(url), .tokens(access: "AAA.BBB.CCC", refresh: "rrr111"))
    }

    func testSessionNeedsBothTokens() {
        XCTAssertEqual(link("pausely://auth/callback#access_token=AAA&token_type=bearer"), .none)
    }

    func testTokenHashLink() {
        XCTAssertEqual(link("pausely://auth/confirm?token_hash=pkce_9f8e7d&type=email"), .tokenHash("pkce_9f8e7d", type: "email"))
        XCTAssertEqual(link("pausely://auth/confirm?token_hash=abc"), .tokenHash("abc", type: "email"),
                       "a link that doesn't say its type is an email sign-in")
    }

    func testCodePlacedInALink() {
        XCTAssertEqual(link("pausely://auth/confirm?token=482913&type=magiclink&email=jane%40example.com"),
                       .emailToken("482913", email: "jane@example.com", type: "magiclink"))
        XCTAssertEqual(link("pausely://auth/confirm?token=482913&email=jane@example.com&verification_type=signup"),
                       .emailToken("482913", email: "jane@example.com", type: "signup"))
    }

    func testExpiredLinkIsReportedNotIgnored() {
        let query = link("pausely://auth/confirm?error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired")
        XCTAssertEqual(query, .failed("Email link is invalid or has expired"))
        let fragment = link("pausely://auth/callback#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired")
        XCTAssertEqual(fragment, .failed("Email link is invalid or has expired"))
    }

    func testAnErrorWinsOverACode() {
        XCTAssertEqual(link("pausely://auth/confirm?code=abc&error=server_error"), .failed("server_error"))
    }

    func testOtherLinksAreNotAccountLinks() {
        XCTAssertEqual(link("pausely://auth/confirm"), .none)
        XCTAssertEqual(link("pausely://auth/confirm?token=482913"), .none, "a token without the email can't be checked")
        XCTAssertEqual(link("pausely://subscription/manage?id=1"), .none)
    }

    func testRecoveryIsRecognisedFromTheLink() {
        XCTAssertTrue(AuthLink.isRecovery(URL(string: "pausely://auth/reset-password?code=abc")!))
        XCTAssertTrue(AuthLink.isRecovery(URL(string: "pausely://auth/callback#access_token=A&refresh_token=B&type=recovery")!))
        XCTAssertTrue(AuthLink.isRecovery(URL(string: "pausely://auth/confirm?token_hash=x&type=recovery")!))
        XCTAssertFalse(AuthLink.isRecovery(URL(string: "pausely://auth/confirm?code=abc")!))
        XCTAssertFalse(AuthLink.isRecovery(URL(string: "pausely://auth/callback#access_token=A&refresh_token=B&type=signup")!))
    }

    // MARK: Which links are acted on

    private let asked = Date(timeIntervalSince1970: 1_800_000_000)

    /// Jane asked for a code on this phone and nobody is signed in.
    private func janeIsSigningUp(signedIn: Bool = false) -> AuthLinkGate {
        AuthLinkGate(requestedEmail: "jane@example.com", requestedAt: asked, isSignedIn: signedIn)
    }

    private var tenMinutesLater: Date { asked.addingTimeInterval(600) }

    func testALinkForTheAddressThatAskedIsActedOn() {
        let gate = janeIsSigningUp()
        XCTAssertTrue(gate.allows(link("pausely://auth/confirm?token=482913&type=email&email=jane%40example.com"), now: tenMinutesLater))
        XCTAssertTrue(gate.allows(link("pausely://auth/confirm?token=482913&type=email&email=%20Jane%40Example.COM"), now: tenMinutesLater),
                      "the same address in another case, with a stray space")
        XCTAssertTrue(gate.allows(link("pausely://auth/confirm?code=abc123"), now: tenMinutesLater))
        XCTAssertTrue(gate.allows(link("pausely://auth/confirm?token_hash=pkce_9f8e7d&type=email"), now: tenMinutesLater))
    }

    /// The attack this gate exists for: someone asks for a code for their own account, wraps it in a link
    /// and sends it. Tapping it must not sign the person holding the phone into the sender's account.
    func testSomeoneElsesCodeInALinkIsIgnored() {
        let attack = link("pausely://auth/confirm?token=111222&type=email&email=attacker%40example.net")
        XCTAssertEqual(attack, .emailToken("111222", email: "attacker@example.net", type: "email"))
        XCTAssertFalse(janeIsSigningUp().allows(attack, now: tenMinutesLater))
    }

    func testNoLinkIsActedOnWhenNothingWasAskedFor() {
        let nothingAsked = AuthLinkGate(requestedEmail: nil, requestedAt: nil, isSignedIn: false)
        for url in ["pausely://auth/confirm?code=abc123",
                    "pausely://auth/callback#access_token=AAA.BBB.CCC&refresh_token=rrr111",
                    "pausely://auth/confirm?token_hash=pkce_9f8e7d&type=magiclink",
                    "pausely://auth/confirm?token=482913&type=email&email=jane%40example.com"] {
            XCTAssertFalse(nothingAsked.allows(link(url), now: tenMinutesLater), url)
        }
    }

    func testALinkIsIgnoredOnceSomeoneIsSignedIn() {
        XCTAssertFalse(janeIsSigningUp(signedIn: true).allows(link("pausely://auth/callback#access_token=AAA.BBB.CCC&refresh_token=rrr111"),
                                                             now: tenMinutesLater))
    }

    func testARequestLastsOneHour() {
        let gate = janeIsSigningUp()
        let code = link("pausely://auth/confirm?code=abc123")
        XCTAssertTrue(gate.allows(code, now: asked.addingTimeInterval(3_600)))
        XCTAssertFalse(gate.allows(code, now: asked.addingTimeInterval(3_601)))
    }

    /// A session or token hash doesn't name its address, so the account that comes back is checked.
    func testTheAccountThatComesBackMustBeTheOneAskedFor() {
        let gate = janeIsSigningUp()
        XCTAssertTrue(gate.accepts(accountEmail: "jane@example.com"))
        XCTAssertTrue(gate.accepts(accountEmail: "JANE@example.com"))
        XCTAssertFalse(gate.accepts(accountEmail: "attacker@example.net"))
        XCTAssertFalse(gate.accepts(accountEmail: nil), "an account with no address can't be matched")
        XCTAssertFalse(AuthLinkGate(requestedEmail: nil, requestedAt: nil, isSignedIn: false).accepts(accountEmail: "jane@example.com"))
    }

    func testAddressesAreComparedWithoutCaseOrOuterSpaces() {
        XCTAssertTrue(AuthLinkGate.sameAddress(" Jane@Example.com", "jane@example.com\n"))
        XCTAssertFalse(AuthLinkGate.sameAddress("jane@example.com", "jane@example.org"))
        XCTAssertFalse(AuthLinkGate.sameAddress("", ""), "two missing addresses are not a match")
    }

    // MARK: Why an email request failed

    private struct ServiceError: Error, CustomStringConvertible {
        let description: String
    }

    /// Seen on the live project on 2026-11-11: the mailer refused a correct address, and the form told
    /// the person to "check the address". Only a malformed address is the person's to fix.
    func testAFailureToSendIsNotBlamedOnTheAddress() {
        for refusal in ["Email address \"new@example.com\" cannot be used as it is not authorized",
                        "Error sending confirmation email",
                        "unexpected_failure"] {
            XCTAssertEqual(CodeProblem.sending(ServiceError(description: refusal)),
                           L10n.string("We couldn't send the email. The problem is on our side. Try again in a few minutes."), refusal)
        }
    }

    func testAMalformedAddressIsReportedAsTheAddress() {
        XCTAssertEqual(CodeProblem.sending(ServiceError(description: "validation_failed: Unable to validate email address: invalid format")),
                       L10n.string("That email address doesn't look right. Check it and try again."))
    }

    func testAskingAgainTooSoonSaysToWait() {
        XCTAssertEqual(CodeProblem.sending(ServiceError(description: "over_email_send_rate_limit (429)")),
                       L10n.string("That was too soon after the last email. Wait a minute and try again."))
    }

    // MARK: Resend

    func testResendWaitsOutTheMinuteThenOpens() {
        let sent = Date(timeIntervalSince1970: 1_000_000)
        let countdown = ResendCountdown(lastSent: sent)
        XCTAssertEqual(countdown.secondsLeft(at: sent), 60)
        XCTAssertEqual(countdown.secondsLeft(at: sent.addingTimeInterval(41.2)), 19)
        XCTAssertEqual(countdown.secondsLeft(at: sent.addingTimeInterval(59.5)), 1, "half a second left still counts as waiting")
        XCTAssertEqual(countdown.secondsLeft(at: sent.addingTimeInterval(60)), 0)
        XCTAssertEqual(countdown.secondsLeft(at: sent.addingTimeInterval(600)), 0, "it never goes below nothing: the old screen never re-enabled the button")
    }

    // MARK: Code entry

    func testCodeKeepsOnlySixDigits() {
        XCTAssertEqual(EmailCode.digits(from: "482913"), "482913")
        XCTAssertEqual(EmailCode.digits(from: "482 913"), "482913", "codes are shown in two groups")
        XCTAssertEqual(EmailCode.digits(from: "Your code is 482913."), "482913", "pasting the whole line")
        XCTAssertEqual(EmailCode.digits(from: "4829137"), "482913")
        XCTAssertEqual(EmailCode.digits(from: "48a"), "48")
        XCTAssertEqual(EmailCode.digits(from: ""), "")
    }

    func testCodeAcceptsArabicAndFullWidthDigits() {
        XCTAssertEqual(EmailCode.digits(from: "٤٨٢٩١٣"), "482913")
        XCTAssertEqual(EmailCode.digits(from: "４８２９１３"), "482913")
    }

    // MARK: Password rules

    func testPasswordNeedsAllFourRules() {
        XCTAssertEqual(PasswordStrength.rulesMet("Abcdefg1"), 4)
        XCTAssertEqual(PasswordStrength.rulesMet("abcdefg1"), 3, "no capital")
        XCTAssertEqual(PasswordStrength.rulesMet("ABCDEFG1"), 3, "no small letter")
        XCTAssertEqual(PasswordStrength.rulesMet("Abcdefgh"), 3, "no number")
        XCTAssertEqual(PasswordStrength.rulesMet("Abcdef1"), 3, "seven characters")
        XCTAssertEqual(PasswordStrength.rulesMet(""), 0)
    }
    /// The waiting line under the code is redrawn once a second while there is a wait, and not at
    /// all after it: the last moment it changes is the one at which it reads "Send a new code".
    func testTheResendLineStopsTickingWhenTheWaitIsOver() {
        let sent = Date(timeIntervalSince1970: 1_800_000_000)
        let countdown = ResendCountdown(lastSent: sent)
        let ticks = countdown.ticks(from: sent.addingTimeInterval(57.5))
        XCTAssertEqual(ticks.count, 4, "3 seconds left: now, and one for each of them")
        XCTAssertEqual(ticks.map { countdown.secondsLeft(at: $0) }, [3, 2, 1, 0])
        XCTAssertEqual(countdown.ticks(from: sent.addingTimeInterval(300)).count, 1, "no wait, nothing to count")
    }

    /// An address is shown whole. It may break after "@", after a dot and before a slash, and
    /// nowhere else: every other pair of characters is joined, so iOS cannot hyphenate inside it
    /// at the accessibility text sizes ("accoun-t.apple.-com" was what the button said).
    func testAnAddressBreaksOnlyWhereItsPartsMeet() {
        func marked(_ text: String) -> String {
            text.replacingOccurrences(of: AddressText.gap, with: "|").replacingOccurrences(of: AddressText.joiner, with: "")
        }
        func plain(_ text: String) -> String {
            text.replacingOccurrences(of: AddressText.gap, with: "").replacingOccurrences(of: AddressText.joiner, with: "")
        }
        let shown = AddressText.breakable("jane.doe@example.co.uk")
        XCTAssertEqual(marked(shown), "jane.|doe@|example.|co.|uk")
        XCTAssertEqual(plain(shown), "jane.doe@example.co.uk", "nothing else is changed")
        XCTAssertEqual(AddressText.breakable("ab.cd"), "a\u{2060}b\u{2060}.\u{200B}c\u{2060}d", "joined wherever it may not break")
        XCTAssertEqual(marked(AddressText.breakable("myaccount.google.com/apppasswords")), "myaccount.|google.|com|/apppasswords")
        // After a hyphen that is part of the address, never one that was added.
        XCTAssertEqual(marked(AddressText.breakable("jane@longer-company-name.example")), "jane@|longer-|company-|name.|example")
        XCTAssertEqual(AddressText.breakable(""), "")
        XCTAssertEqual(AddressText.breakable("x"), "x")

        // Inside a sentence only the address is touched, and the full stop that ends the sentence
        // is not part of it.
        XCTAssertEqual(AddressText.inSentence("Open account.apple.com and sign in."),
                       "Open " + AddressText.breakable("account.apple.com") + " and sign in.")
        XCTAssertEqual(AddressText.inSentence("Open myaccount.google.com/apppasswords and create one named Pausely."),
                       "Open " + AddressText.breakable("myaccount.google.com/apppasswords") + " and create one named Pausely.")
        XCTAssertEqual(AddressText.inSentence("account.apple.comを開いてサインインします。"),
                       AddressText.breakable("account.apple.com") + "を開いてサインインします。")
        XCTAssertEqual(AddressText.inSentence("Write to jane.doe@example.co.uk."),
                       "Write to " + AddressText.breakable("jane.doe@example.co.uk") + ".")
        for untouched in ["Choose Generate app password and name it Pausely.", "Version 1.0.3 is here.",
                          "People 16+. No more.", "e.g. this", ""] {
            XCTAssertEqual(AddressText.inSentence(untouched), untouched)
        }

        // Every step of every provider: the words are the same, and a step that names a page has
        // it protected.
        var protected = 0
        for preset in IMAPPreset.all {
            for step in preset.steps {
                let drawn = AddressText.inSentence(step)
                XCTAssertEqual(plain(drawn), step, preset.id)
                if drawn != step { protected += 1 }
            }
        }
        XCTAssertGreaterThanOrEqual(protected, 2, "iCloud's and Gmail's steps name the page to open")
    }

    /// The address people write to is drawn like every other address, wherever a screen shows it.
    /// On Help it was "pausely@pro-" above "ton.me" at the largest text size (seen 2026-11-17):
    /// a hyphen the address does not have.
    func testTheSupportAddressIsNeverHyphenated() throws {
        let shown = AddressText.breakable(AppConfig.supportEmail)
        XCTAssertEqual(shown.replacingOccurrences(of: AddressText.joiner, with: "").components(separatedBy: AddressText.gap),
                       ["pausely@", "proton.", "me"], "it may go on to the next line after its @ and after its dot, and nowhere else")
        // What is said aloud and what is compared has no marks in it, and other words are untouched.
        XCTAssertEqual(AddressText.plain(shown), AppConfig.supportEmail)
        XCTAssertEqual(AddressText.plain("Same as iPhone"), "Same as iPhone")
        let sentence = AddressText.inSentence("If it keeps failing, email \(AppConfig.supportEmail) and we'll delete it within 30 days.")
        XCTAssertTrue(sentence.contains(shown))
        XCTAssertEqual(AddressText.plain(sentence), "If it keeps failing, email \(AppConfig.supportEmail) and we'll delete it within 30 days.")

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let views = root.appendingPathComponent("Pausely/Views")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: views.path), "Sources aren't readable from this test run")
        var shownIn = 0
        for file in try FileManager.default.subpathsOfDirectory(atPath: views.path) where file.hasSuffix(".swift") {
            let text = try String(contentsOf: views.appendingPathComponent(file), encoding: .utf8)
            for line in text.components(separatedBy: "\n") where line.contains("AppConfig.supportEmail") && !line.contains("mailto:") {
                XCTAssertTrue(line.contains("AddressText."), "\(file): \(line.trimmingCharacters(in: .whitespaces))")
                shownIn += 1
            }
        }
        XCTAssertEqual(shownIn, 2, "Help's row and the sentence when an account could not be deleted")
        let rows = try String(contentsOf: root.appendingPathComponent("Pausely/DesignSystem/SettingsParts.swift"), encoding: .utf8)
        XCTAssertTrue(rows.contains(".accessibilityLabel(Text(verbatim: AddressText.plain(detail)))"))
    }
}
