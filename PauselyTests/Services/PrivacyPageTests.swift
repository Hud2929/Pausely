import XCTest
@testable import Pausely

/// Profile → Privacy & security makes four statements. Each is set here against what the build
/// does, so a change to the build that makes one untrue fails a test instead of a promise.
final class PrivacyPageTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func text(_ path: String) throws -> String {
        let url = root.appendingPathComponent(path)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Every Swift file of the app, by its path under `Pausely/`.
    private func appSources() throws -> [String: String] {
        let folder = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: folder.path), "Sources aren't readable from this test run")
        var sources: [String: String] = [:]
        for file in try FileManager.default.subpathsOfDirectory(atPath: folder.path) where file.hasSuffix(".swift") {
            sources[file] = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
        }
        return sources
    }

    private func captures(_ pattern: String, in text: String) throws -> [String] {
        let expression = try NSRegularExpression(pattern: pattern)
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    /// "Synced to Pausely's servers over an encrypted connection and encrypted at rest. Other
    /// accounts can't read it."
    func testTheListIsSentEncryptedKeptEncryptedAndReadByItsOwnerOnly() throws {
        let page = try text("Pausely/Views/Settings/PrivacySecurityView.swift")
        XCTAssertTrue(page.contains("Synced to Pausely's servers over an encrypted connection and encrypted at rest. Other accounts can't read it."))

        // The connection: one server, addressed over https in both configurations, and the app
        // asks iOS for no exception to App Transport Security.
        let project = try text("Pausely.xcodeproj/project.pbxproj")
        let servers = try captures("SUPABASE_URL = \"([^\"]+)\";", in: project)
        XCTAssertEqual(servers.count, 2, "Debug and Release")
        for server in servers {
            let url = try XCTUnwrap(URL(string: server))
            XCTAssertEqual(url.scheme, "https")
            // At rest: the list lives with one host, whose own statement this sentence repeats.
            // supabase.com/security, read 2026-11-16: "All customer data is encrypted at rest
            // with AES-256 and in transit via TLS."
            XCTAssertEqual(url.host?.hasSuffix(".supabase.co"), true, "another host needs its own statement about encryption at rest")
        }
        XCTAssertFalse(project.contains("NSAllowsArbitraryLoads"))
        XCTAssertFalse(project.contains("NSExceptionDomains"))

        // Other accounts: the rules on the table are proven against a stand-in database by
        // `scripts/dbtest/run.sh`. These are its checks, by name: the sentence leans on them.
        let rig = try text("scripts/dbtest/run.sh")
        for check in ["a person sees only their own subscriptions",
                      "a person cannot add a subscription to someone else's account",
                      "a person cannot hand their subscription to someone else",
                      "a person cannot edit someone else's subscription",
                      "a person cannot delete someone else's subscription",
                      "a signed-out visitor sees no subscriptions"] {
            XCTAssertTrue(rig.contains("\"\(check)\""), "the database rig no longer checks that \(check)")
        }
    }

    /// "History, receipt and Pause Plan: Protected on this iPhone by iOS data protection, and synced
    /// to your account when you sign in so reinstalling never loses them."
    func testHistoryTheReceiptAndThePlanStayProtectedAndOwnerOnly() throws {
        let page = try text("Pausely/Views/Settings/PrivacySecurityView.swift")
        XCTAssertTrue(page.contains("Protected on this iPhone by iOS data protection, and synced to your account when you sign in so reinstalling never loses them."))

        let sources = try appSources()
        // What goes to the server: the list, the account's own row (age confirmation & Pro grant),
        // Savings Receipt lifecycle history, the Pause Plan, account deletion, and Apple token revocation.
        var tables = Set<String>(), calls = Set<String>(), functions = Set<String>()
        for source in sources.values {
            tables.formUnion(try captures("\\.from\\(\"([^\"]+)\"\\)", in: source))
            calls.formUnion(try captures("\\.rpc\\(\"([^\"]+)\"", in: source))
            functions.formUnion(try captures("functions\\.invoke\\(\"([^\"]+)\"", in: source))
        }
        XCTAssertEqual(tables, ["subscriptions", "profiles", "lifecycle_events", "pause_plans"])
        XCTAssertEqual(calls, ["delete_my_account"])
        XCTAssertEqual(functions, ["apple-revoke"])

        // History, Pause Plan, and cached local blobs are written with iOS hardware data protection.
        for file in ["Core/Renewals/LifecycleEventLog.swift", "Services/PausePlanStore.swift"] {
            let source = try XCTUnwrap(sources[file], file)
            XCTAssertTrue(source.contains("DeviceFile.save("), file)
            XCTAssertFalse(source.contains("SupabaseManager"), "\(file) keeps local persistence separate from sync")
        }
        let settings = try XCTUnwrap(sources["Services/Settings/AppSettings.swift"])
        XCTAssertTrue(settings.contains(".completeFileProtectionUntilFirstUserAuthentication"), "cached subscriptions and sync queue use hardware protection")
        let receipt = try XCTUnwrap(sources["Core/Renewals/SavingsLedger.swift"])
        XCTAssertFalse(receipt.contains("SupabaseManager"))
        let deviceFile = try XCTUnwrap(sources["Core/Utilities/DeviceFile.swift"])
        XCTAssertTrue(deviceFile.contains("options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]"))
        // Nothing in the app lowers a file's protection to none, but for one file: "Keep it" pressed
        // before the phone's first unlock, when no other kind of file can be written. It may hold
        // only which subscription, the charge's day and when the button was pressed: no name, no
        // amount, nothing that says who the person is.
        for (file, source) in sources where file != "Core/Utilities/LockedKeeps.swift" {
            XCTAssertFalse(source.contains("noFileProtection") || source.contains("FileProtectionType.none"), file)
        }
        let press = LockedKeeps.Press(subscriptionId: UUID(), renewalDay: "2026-12-01", pressedAt: Date())
        XCTAssertEqual(Mirror(reflecting: press).children.compactMap(\.label), ["subscriptionId", "renewalDay", "pressedAt"])
    }

    /// "Find in Email: Receipts are read on this iPhone. A few facts of each charge are kept (who charged,
    /// how much, when, how often), never the email itself." Shown only where the feature is; its promises are held by
    /// `InboxPrivacyTests`.
    func testTheEmailSentenceIsShownOnlyWhereTheFeatureIs() throws {
        let page = try text("Pausely/Views/Settings/PrivacySecurityView.swift")
        let sentence = try XCTUnwrap(page.range(of: "Receipts are read on this iPhone. A few facts of each charge are kept (who charged, how much, when, how often), never the email itself."))
        XCTAssertTrue(page[..<sentence.lowerBound].suffix(260).contains("if FeatureFlags.inboxImportEnabled {"))
    }

    /// "No ads, no selling data: Pausely has no ad or tracking SDKs and never sells your data."
    func testNothingInTheBuildAdvertisesOrTracks() throws {
        let page = try text("Pausely/Views/Settings/PrivacySecurityView.swift")
        XCTAssertTrue(page.contains("Pausely has no ad or tracking SDKs and never sells your data."))

        // Every package the app is built with: the database client and what it is built on.
        let resolved = try text("Pausely.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
        let pins = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(resolved.utf8)) as? [String: Any])["pins"] as? [[String: Any]]
        let packages = try XCTUnwrap(pins).compactMap { $0["identity"] as? String }.sorted()
        XCTAssertEqual(packages, ["supabase-swift", "swift-asn1", "swift-clocks", "swift-concurrency-extras", "swift-crypto",
                                  "swift-http-types", "xctest-dynamic-overlay"],
                       "a new package: say here what it is, and check the sentence on the Privacy page still holds")

        // Every framework a source file imports: Apple's own and that client. None advertises,
        // asks to track, or reports what people do.
        var imported = Set<String>()
        for folder in ["Pausely", "PauselyWidget", "Shared"] {
            let url = root.appendingPathComponent(folder)
            for file in try FileManager.default.subpathsOfDirectory(atPath: url.path) where file.hasSuffix(".swift") {
                let source = try String(contentsOf: url.appendingPathComponent(file), encoding: .utf8)
                imported.formUnion(try captures("(?m)^(?:@preconcurrency )?import (?:struct |class |enum |func )?([A-Za-z_]+)", in: source))
            }
        }
        XCTAssertEqual(imported.sorted(), ["AppIntents", "Auth", "AuthenticationServices", "Combine", "CoreGraphics",
                                           "CoreSpotlight", "CryptoKit", "Dispatch", "Foundation", "FoundationModels",
                                           "LocalAuthentication", "MessageUI", "Network", "PhotosUI", "PostgREST",
                                           "SafariServices", "Security", "StoreKit", "Supabase", "SwiftUI", "TipKit",
                                           "UIKit", "UniformTypeIdentifiers", "UserNotifications", "Vision", "WidgetKit", "os"],
                       "a new framework: say here what it is for")
        // And the app's privacy manifest says the same to Apple (`PrivacyManifestTests`).
    }
}
