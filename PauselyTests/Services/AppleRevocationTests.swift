import AuthenticationServices
import XCTest
@testable import Pausely

/// Deleting an account that signs in with Apple: confirm with Apple, hand the code to the server,
/// and never let trouble on Apple's side stand between a person and deleting their account.
@MainActor
final class AppleRevocationTests: XCTestCase {

    func testTheCodeAppleIssuesIsWhatTheServerIsGiven() async {
        var sent: [String] = []
        let revocation = AppleRevocation(authorizationCode: { "the-code-apple-issued" },
                                         revoke: { sent.append($0) })
        let outcome = await revocation.run()
        XCTAssertEqual(outcome, .revoked)
        XCTAssertEqual(sent, ["the-code-apple-issued"])
    }

    func testClosingApplesSheetStopsTheDeletionAndAsksTheServerNothing() async {
        var asked = false
        let revocation = AppleRevocation(authorizationCode: { throw ASAuthorizationError(.canceled) },
                                         revoke: { _ in asked = true })
        let outcome = await revocation.run()
        XCTAssertEqual(outcome, .backedOut)
        XCTAssertFalse(asked)
    }

    func testTroubleWithAppleDoesNotStopTheDeletion() async {
        let failed = AppleRevocation(authorizationCode: { throw ASAuthorizationError(.failed) }, revoke: { _ in })
        let failedOutcome = await failed.run()
        XCTAssertEqual(failedOutcome, .notRevoked)

        struct ServerHasNoKey: Error {}
        let refused = AppleRevocation(authorizationCode: { "code" }, revoke: { _ in throw ServerHasNoKey() })
        let refusedOutcome = await refused.run()
        XCTAssertEqual(refusedOutcome, .notRevoked)
    }
}
