import XCTest
@testable import Pausely

/// Deep links: in `pausely://auth/confirm` the first part is the URL's host, not its path. These links
/// used to fall through to "unknown", so password-reset links did nothing.
@MainActor
final class DeepLinkTests: XCTestCase {

    private func route(_ string: String) -> DeepLinkRoute {
        DeepLinkManager.shared.handle(URL(string: string)!)
    }

    func testRouteSegmentsTreatHostAndPathTheSame() {
        XCTAssertEqual(URL(string: "pausely://auth/confirm?token=x")!.routeSegments, ["auth", "confirm"])
        XCTAssertEqual(URL(string: "pausely://subscription/manage?id=1")!.routeSegments, ["subscription", "manage"])
    }

    func testAuthLinks() {
        guard case .authConfirm = route("pausely://auth/confirm?token=abc&email=a@b.c&type=signup") else { return XCTFail("confirm") }
        guard case .authResetPassword = route("pausely://auth/reset-password#access_token=x") else { return XCTFail("reset") }
        guard case .authConfirm = route("pausely://auth/callback?code=x") else { return XCTFail("callback") }
    }

    /// Referral links are no longer a feature: an old one opens the app and does nothing else.
    func testOldReferralLinksGoNowhere() {
        guard case .unknown = route("pausely://r/ABCD1234") else { return XCTFail("short form") }
        guard case .unknown = route("pausely://referral?code=WXYZ9876") else { return XCTFail("query form") }
        guard case .unknown = route("https://pausely.pro/r/QWER5678") else { return XCTFail("web form") }
    }

    /// The app claims no web links (no associated domain), so none is acted on: an `https` link that
    /// reaches it by some other road opens nothing, whatever its path says.
    func testWebLinksAreNotTheApps() {
        let id = UUID()
        guard case .unknown = route("https://pausely.pro/subscription/manage?id=\(id.uuidString)") else { return XCTFail("subscription") }
        guard case .unknown = route("https://pausely.pro/auth/confirm?code=x") else { return XCTFail("account link") }
    }

    /// What the app is entitled to is what it uses: Sign in with Apple and the group it shares with its
    /// widgets. A capability nobody uses (universal links, Screen Time, push) fails here.
    func testTheAppClaimsOnlyWhatItUses() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func keys(_ path: String) throws -> [String] {
            let url = root.appendingPathComponent(path)
            try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
            let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
            return try XCTUnwrap(plist as? [String: Any]).keys.sorted()
        }
        XCTAssertEqual(try keys("Pausely/Pausely.entitlements"),
                       ["com.apple.developer.applesignin", "com.apple.security.application-groups"])
        XCTAssertEqual(try keys("PauselyWidget/PauselyWidget.entitlements"), ["com.apple.security.application-groups"])
    }

    func testSubscriptionLink() {
        let id = UUID()
        guard case .subscriptionManage(let routed) = route("pausely://subscription/manage?id=\(id.uuidString)"), routed == id else {
            return XCTFail("subscription")
        }
    }

    func testVerdictLink() {
        let id = UUID()
        guard case .subscriptionVerdict(let routed) = route("pausely://verdict?id=\(id.uuidString)"), routed == id else {
            return XCTFail("verdict")
        }
    }

    func testReceiptLink() {
        guard case .savingsReceipt = route("pausely://receipt") else {
            return XCTFail("receipt")
        }
    }

    func testUnknownLinks() {
        guard case .unknown = route("pausely://somewhere/else") else { return XCTFail("unknown path") }
        guard case .unknown = route("https://example.com/r/ABCD1234") else { return XCTFail("other domain") }
    }
}
