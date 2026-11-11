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

    // MARK: Resend

    func testResendWaitsOutTheMinuteThenOpens() {
        let sent = Date(timeIntervalSince1970: 1_000_000)
        let countdown = ResendCountdown(lastSent: sent)
        XCTAssertEqual(countdown.secondsLeft(at: sent), 60)
        XCTAssertFalse(countdown.canResend(at: sent))
        XCTAssertEqual(countdown.secondsLeft(at: sent.addingTimeInterval(41.2)), 19)
        XCTAssertFalse(countdown.canResend(at: sent.addingTimeInterval(59.5)))
        XCTAssertEqual(countdown.secondsLeft(at: sent.addingTimeInterval(60)), 0)
        XCTAssertTrue(countdown.canResend(at: sent.addingTimeInterval(60)), "the old screen never re-enabled the button")
        XCTAssertTrue(countdown.canResend(at: sent.addingTimeInterval(600)))
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
}
