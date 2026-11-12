import XCTest
@testable import Pausely

/// The website (`pausely.pro/`) and the one email the website causes say what the app does. The
/// policy pages are the ones the app links to, so a wrong sentence there is the app's wrong sentence.
/// Found on 2026-11-12: the privacy policy described reading Screen Time and collecting crash logs
/// (the app does neither), put the data in "your region" (it is in the United States), offered an
/// export in a format the app doesn't make, and sent deletion requests to another domain; the terms
/// set two minimum ages and sold "deep savings analysis and cheaper alternatives"; the welcome email
/// promised early access, analytics and perks, and no way to leave the list.
final class WebsiteTruthTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// What a visitor reads: the page without its markup, styles and scripts.
    private func text(of page: String) throws -> String {
        let url = root.appendingPathComponent("pausely.pro").appendingPathComponent(page)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        var html = try String(contentsOf: url, encoding: .utf8)
        for block in ["<script[\\s\\S]*?</script>", "<style[\\s\\S]*?</style>", "<[^>]+>"] {
            html = html.replacingOccurrences(of: block, with: " ", options: .regularExpression)
        }
        return html.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func welcomeEmail() throws -> String {
        let url = root.appendingPathComponent("supabase/functions/waitlist-signup/index.ts")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private let pages = ["index.html", "privacy.html", "terms.html", "refunds.html", "cookies.html",
                         "support.html", "delete.html", "waitlist.html"]

    func testNoPageOffersWhatTheAppDoesNotDo() throws {
        let neverSaid = ["early access", "advanced analytics", "advanced subscription analytics", "perks", "cheaper alternatives",
                         "savings analysis", "spending analysis", "smart subscription", "screen time api", "crash logs",
                         "referral", "renewal verdict", "session duration", "(json)", "tls 1.3", "your region",
                         "import from gmail", "pausely.app"]
        for page in pages {
            let said = try text(of: page).lowercased()
            XCTAssertEqual(neverSaid.filter { said.contains($0) }, [], page)
        }
        let email = try welcomeEmail().lowercased()
        XCTAssertEqual(neverSaid.filter { email.contains($0) }, [], "the welcome email")
    }

    func testTheTermsAndThePolicyGiveTheAppsOwnFigures() throws {
        let terms = try text(of: "terms.html")
        let privacy = try text(of: "privacy.html")

        let age = AgeConsentManager.minimumAge
        XCTAssertTrue(terms.contains("at least \(age) years of age"), "the terms' minimum age")
        XCTAssertTrue(terms.contains("aged \(age) and over"))
        XCTAssertTrue(privacy.contains("aged \(age) and over"))
        XCTAssertNil(terms.range(of: #"at least (?!16)\d+ years"#, options: .regularExpression), "one minimum age, not two")

        XCTAssertTrue(terms.contains("Track up to \(FreeTier.subscriptionLimit) subscriptions"))
        XCTAssertEqual(ProFeature.allCases, [.unlimitedSubscriptions, .pausePlan])
        XCTAssertTrue(terms.contains("Tracks all of your subscriptions and adds Pause Plan"))
    }

    /// Everyone the app or the website sends anything to is named in the policy.
    func testThePolicyNamesEveryoneTheAppTalksTo() throws {
        let privacy = try text(of: "privacy.html")
        let rates = try XCTUnwrap(URL(string: AppConfig.exchangeRatesURL)?.host)
        XCTAssertEqual(rates, "api.exchangerate-api.com")
        for processor in ["Supabase", "Apple", "Google", "ExchangeRate-API", "Resend", "Each service's own website"] {
            XCTAssertTrue(privacy.contains(processor), "\(processor) is missing from the policy")
        }
    }

    /// What the policy says about the app's data is what the code does.
    func testThePolicyDescribesWhatTheAppKeepsAndWhere() throws {
        let privacy = try text(of: "privacy.html")
        XCTAssertTrue(privacy.contains("Pausely does not read Screen Time. The hours you enter stay on your device."))
        XCTAssertTrue(LocalUserData.personalKeyPrefixes.contains("usage_"), "hours of use are kept on the device and wiped with it")
        XCTAssertTrue(privacy.contains("no analytics, advertising or crash-reporting software"))
        // The copies the policy promises are the ones the export screen makes.
        XCTAssertEqual(ExportFormat.allCases.map(\.rawValue), ["CSV", "PDF", "JSON"])
        XCTAssertTrue(privacy.contains("a CSV spreadsheet, or a JSON file with your list and its history; both from Profile → Export your list, which can also make a PDF to print"))
        XCTAssertTrue(privacy.contains("Profile → Privacy & security → Delete account"))
        XCTAssertTrue(try text(of: "delete.html").contains("Profile → Privacy & security → Delete account"))
        XCTAssertTrue(privacy.contains("not yet switched on in the App Store version"), "Find in Email is off in release builds")
    }

    func testEveryPageGivesOneAddressAndOneAnswerTime() throws {
        for page in ["privacy.html", "terms.html", "refunds.html", "cookies.html", "support.html"] {
            XCTAssertTrue(try text(of: page).contains(AppConfig.supportEmail) || page == "support.html", page)
        }
        XCTAssertTrue(try text(of: "support.html").contains("within 48 hours"))
        XCTAssertTrue(try text(of: "terms.html").contains("Within 48 hours"))
        XCTAssertFalse(try text(of: "support.html").contains("24 hours"))
    }

    /// The welcome email promises one email and a way out; the way out has to reach someone.
    func testTheWelcomeEmailKeepsItsWord() throws {
        let email = try welcomeEmail()
        XCTAssertTrue(email.contains("To leave the list, reply to this email or write to pausely@proton.me"))
        XCTAssertTrue(email.contains("reply_to: 'pausely@proton.me'"), "a reply must reach a mailbox someone reads")
        XCTAssertTrue(try text(of: "waitlist.html").contains("To leave the list, reply to the email we send you or write to pausely@proton.me."))
    }
}
