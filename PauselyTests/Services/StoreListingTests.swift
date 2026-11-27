import XCTest
@testable import Pausely

/// The App Store listing (`metadata/`) says only what the app keeps. Its numbers are counted from the
/// code, its names are the app's own in each language, every language says the same things, and
/// nothing the release build hides is offered. The listing used to promise "1,000+ services with
/// their plans and prices" (848, and no prices), "900+ cancel links" (522 real pages), a weekly
/// total, "savings analysis" in Pro, and a generator script that would have put "cheaper
/// alternatives" back.
final class StoreListingTests: XCTestCase {

    private struct Listing {
        let locale: String
        let name: String, subtitle: String, keywords: String, promo: String, description: String, whatsNew: String
        var language: String { String(locale.prefix(2)) }
    }

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func listings() throws -> [Listing] {
        let info = root.appendingPathComponent("metadata/app-info")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: info.path), "Sources aren't readable from this test run")
        let versions = root.appendingPathComponent("metadata/version")
        let newest = try XCTUnwrap(try FileManager.default.contentsOfDirectory(atPath: versions.path)
            .filter { !$0.hasPrefix(".") }
            .max { $0.compare($1, options: .numeric) == .orderedAscending })
        func fields(_ url: URL) throws -> [String: String] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: String])
        }
        return try FileManager.default.contentsOfDirectory(atPath: info.path).filter { $0.hasSuffix(".json") }.sorted().map { file in
            let app = try fields(info.appendingPathComponent(file))
            let version = try fields(versions.appendingPathComponent(newest).appendingPathComponent(file))
            return Listing(locale: String(file.dropLast(5)),
                           name: app["name"] ?? "", subtitle: app["subtitle"] ?? "",
                           keywords: version["keywords"] ?? "", promo: version["promotionalText"] ?? "",
                           description: version["description"] ?? "", whatsNew: version["whatsNew"] ?? "")
        }
    }

    private func english() throws -> Listing {
        try XCTUnwrap(try listings().first { $0.locale == "en-US" })
    }

    private func number(_ pattern: String, in text: String) throws -> Int {
        let match = try XCTUnwrap(text.range(of: pattern, options: .regularExpression), "the listing no longer says \(pattern)")
        return try XCTUnwrap(Int(text[match].filter(\.isNumber)))
    }

    private func numbers(in text: String) -> Set<Int> {
        var found: Set<Int> = []
        var digits = ""
        for character in text + " " {
            if character.isASCII, character.isNumber { digits.append(character) } else if !digits.isEmpty {
                if let value = Int(digits) { found.insert(value) }
                digits = ""
            }
        }
        return found
    }

    // MARK: - Limits

    func testEveryFieldFitsTheStoresLimits() throws {
        let all = try listings()
        XCTAssertEqual(all.map(\.locale), ["ar-SA", "de-DE", "en-AU", "en-CA", "en-GB", "en-US", "es-ES", "es-MX", "fr-CA", "fr-FR", "ja"])
        for listing in all {
            XCTAssertLessThanOrEqual(listing.name.count, 30, "\(listing.locale) name")
            XCTAssertLessThanOrEqual(listing.subtitle.count, 30, "\(listing.locale) subtitle")
            XCTAssertLessThanOrEqual(listing.keywords.count, 100, "\(listing.locale) keywords")
            XCTAssertLessThanOrEqual(listing.promo.count, 170, "\(listing.locale) promotional text")
            XCTAssertLessThanOrEqual(listing.description.count, 4000, "\(listing.locale) description")
            XCTAssertLessThanOrEqual(listing.whatsNew.count, 4000, "\(listing.locale) what's new")
            XCTAssertFalse(listing.description.isEmpty || listing.whatsNew.isEmpty || listing.promo.isEmpty, listing.locale)
        }
    }

    /// A keyword is spent once: not repeated, and not a word the name or subtitle already holds.
    func testKeywordsAreNotWasted() throws {
        for listing in try listings() {
            let keywords = listing.keywords.components(separatedBy: ",")
            XCTAssertFalse(listing.keywords.contains(" "), "\(listing.locale): a space after a comma counts against the limit")
            XCTAssertEqual(Set(keywords).count, keywords.count, "\(listing.locale) repeats a keyword")
            let title = Set((listing.name + " " + listing.subtitle).lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
            XCTAssertEqual(keywords.filter { title.contains($0.lowercased()) }, [], "\(listing.locale) repeats its name or subtitle")
        }
    }

    // MARK: - Truth

    func testTheNumbersAreCountedFromTheApp() throws {
        let text = try english().description

        let services = try number(#"\d+\+ popular services"#, in: text)
        XCTAssertLessThanOrEqual(services, CatalogData.entries.count)
        XCTAssertGreaterThan(services + 100, CatalogData.entries.count, "the catalog has grown past what the listing says")

        // A page on the service's own site where it is cancelled; a link to a front page is not one.
        func isAPage(_ address: String?) -> Bool {
            guard let address, let url = URL(string: address) else { return false }
            return !CancelHelp.isFrontPage(url)
        }
        let pages = Set(ServiceDatabase.services.filter { isAPage($0.cancelURL) }.map { $0.name.lowercased() })
            .union(CatalogData.entries.filter { isAPage($0.cancellationURL) }.map { $0.name.lowercased() })
        XCTAssertLessThanOrEqual(try number(#"cancellation page of \d+\+ services"#, in: text), pages.count)

        XCTAssertEqual(try number(#"\d+ currencies"#, in: text), CurrencyManager.shared.allCurrencies.count)
        XCTAssertFalse(text.contains("130+ currencies"), "exact currency count (130), not 130+")
        XCTAssertEqual(try number(#"up to \d+ subscriptions for free"#, in: text), FreeTier.subscriptionLimit)
        XCTAssertEqual(SubscriptionEditDraft.reminderOptions.filter { $0 > 0 }, [1, 3, 7], "the listing says 1, 3 or 7 days before")

        // Every language gives the same figures.
        let figures = numbers(in: text)
        for listing in try listings() {
            XCTAssertEqual(numbers(in: listing.description), figures, listing.locale)
        }
    }

    /// Pro is exactly what `ProFeature` unlocks, and the listing names nothing else as paid.
    func testProIsWhatTheAppUnlocks() throws {
        XCTAssertEqual(ProFeature.allCases, [.unlimitedSubscriptions, .pausePlan, .spendForecast, .batchScreenshotImport, .cancelConcierge])
        XCTAssertTrue(try english().description.contains("Pausely Pro tracks all of them and adds Pause Plan, 12-month forecast and cut simulator, batch screenshot import (up to 10 at once), and cancellation and refund email drafts."))
        // The repository's front page says the same. It used to add "the full savings analysis".
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        XCTAssertTrue(readme.contains("Pausely Pro: unlimited subscriptions, Pause Plan, 12-month forecast & cut simulator, batch screenshot\nimport, and cancellation & refund email drafts."))
    }

    func testNothingTheAppCannotKeepIsOffered() throws {
        // Reading receipts in email is switched off in release builds; the rest never existed or is gone.
        let neverSaid = ["inbox", "gmail", "receipts from", "scan", "wrapped", "renewal verdict", "dashboard", "weekly",
                         "plans and prices", "savings analysis", "cheaper", "alternative", "in one tap", "automatically cancel",
                         "ai-powered", "bank", "face id"]
        for listing in try listings() where listing.language == "en" {
            let said = [listing.description, listing.whatsNew, listing.promo, listing.subtitle].joined(separator: "\n").lowercased()
            XCTAssertEqual(neverSaid.filter { said.contains($0) }, [], listing.locale)
        }
        // A search term the app cannot answer is a promise too: "find", "hidden", "cheaper" in six languages.
        let neverSearched: Set = ["find", "hidden", "cheaper", "alternative", "cache", "trouver", "versteckt", "خفية", "escondido", "oculto"]
        for listing in try listings() {
            XCTAssertEqual(listing.keywords.components(separatedBy: ",").filter { neverSearched.contains($0) }, [], listing.locale)
        }
    }

    // MARK: - One voice

    /// What the listing calls a thing is what the app calls it, in each language.
    func testTheListingUsesTheAppsOwnNames() throws {
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(contentsOf: root.appendingPathComponent("Pausely/Localizable.xcstrings"))) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: [String: Any]])
        func name(_ key: String, in language: String) -> String? {
            guard language != "en" else { return key }
            let unit = ((strings[key]?["localizations"] as? [String: Any])?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
            return unit?["value"] as? String
        }
        for listing in try listings() {
            for key in ["Savings Receipt", "Pause Plan", "Your year in subscriptions"] {
                let appsName = try XCTUnwrap(name(key, in: listing.language), "\(key) in \(listing.language)")
                XCTAssertNotNil(listing.description.range(of: appsName, options: .caseInsensitive),
                                "\(listing.locale) doesn't call \(key) \"\(appsName)\"")
            }
        }
    }

    func testEveryLanguageSaysTheSameThings() throws {
        let master = try english()
        func bullets(_ text: String) -> Int { text.components(separatedBy: "•").count - 1 }
        for listing in try listings() {
            XCTAssertEqual(bullets(listing.description), bullets(master.description), "\(listing.locale) description")
            XCTAssertEqual(bullets(listing.whatsNew), bullets(master.whatsNew), "\(listing.locale) what's new")
            XCTAssertEqual(listing.description.components(separatedBy: "\n\n").count,
                           master.description.components(separatedBy: "\n\n").count, "\(listing.locale) sections")
            for link in ["https://pausely.pro/terms.html", "https://pausely.pro/privacy.html", "pausely@proton.me"] {
                XCTAssertTrue(listing.description.contains(link), "\(listing.locale) is missing \(link)")
            }
        }
    }

    /// The eight pictures on the listing are captures of a debug build, which has what the
    /// release build has not: finding subscriptions in email. A capture run (`--screenshots`)
    /// switches that off, so no picture shows a way in that a customer will not find; the tour's
    /// capture test takes every picture in such a run, of one list. (The pictures in the
    /// repository until 2026-11-17 were of the design before this one.)
    func testAPictureForTheStoreShowsOnlyWhatTheReleaseBuildShows() throws {
        // Unit tests are not a capture run: in a debug build the features are there to be tested.
        #if DEBUG
        XCTAssertFalse(LaunchFlag.screenshots.isSet)
        XCTAssertTrue(FeatureFlags.inboxImportEnabled)
        #endif
        let flags = try String(contentsOf: root.appendingPathComponent("Pausely/Core/FeatureFlags.swift"), encoding: .utf8)
        XCTAssertTrue(flags.contains("#if DEBUG\n        return !LaunchFlag.screenshots.isSet\n        #else\n        return false\n        #endif"))
        for flag in ["gmailImportEnabled", "microsoftImportEnabled", "imapImportEnabled"] {
            XCTAssertTrue(flags.contains("static let \(flag) = onInDebugBuilds"), flag)
        }
        let tour = try String(contentsOf: root.appendingPathComponent("PauselyUITests/ScreenTourTests.swift"), encoding: .utf8)
        let capture = try XCTUnwrap(tour.range(of: "func testStoreScreenshots() throws {"))
        let body = String(tour[capture.upperBound...].prefix(1400))
        XCTAssertTrue(body.contains("[\"--uitesting\", \"--demo-mode\", \"--screenshots\", \"--varied-demo-data\"] + screen.flags"))
        // And the pictures are the eight the listing has places for, on both devices.
        let names = ["01_verdict", "02_dashboard", "03_receipt", "04_pauseplan", "05_subscription", "06_analysis", "07_catalog", "08_wrapped"]
        for name in names { XCTAssertTrue(body.contains("\"\(name)\""), name) }
        for device in ["iphone-6.9", "ipad-13"] {
            let folder = root.appendingPathComponent("AppStoreScreenshots/\(device)")
            let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".png") }.sorted()
            XCTAssertEqual(files, names.map { $0 + ".png" }, device)
        }
    }
}
