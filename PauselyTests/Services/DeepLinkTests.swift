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
        XCTAssertEqual(URL(string: "https://pausely.pro/subscription/manage?id=1")!.routeSegments, ["subscription", "manage"])
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
        guard case .unknown = route("https://pausely.pro/r/QWER5678") else { return XCTFail("universal link") }
    }

    func testSubscriptionLink() {
        let id = UUID()
        guard case .subscriptionManage(let routed) = route("pausely://subscription/manage?id=\(id.uuidString)"), routed == id else {
            return XCTFail("subscription")
        }
    }

    func testUnknownLinks() {
        guard case .unknown = route("pausely://somewhere/else") else { return XCTFail("unknown path") }
        guard case .unknown = route("https://example.com/r/ABCD1234") else { return XCTFail("other domain") }
    }
}
