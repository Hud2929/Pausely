import XCTest
@testable import Pausely

/// The project file itself, held to a few rules that were each broken until 2026-11-12: the test
/// bundles had the app's own bundle id, the shared scheme ran tests in parallel (simulator clones that
/// sometimes fail to boot), the widget linked a framework nothing uses, a build phase held an entry
/// with no file, and three configuration files described keys for services the app never had.
final class ProjectFileTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func project() throws -> String {
        let url = root.appendingPathComponent("Pausely.xcodeproj/project.pbxproj")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testEveryTargetHasItsOwnBundleId() throws {
        let ids = try project().components(separatedBy: "\n")
            .filter { $0.contains("PRODUCT_BUNDLE_IDENTIFIER = ") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t;")).replacingOccurrences(of: "PRODUCT_BUNDLE_IDENTIFIER = ", with: "") }
        // Four targets, each with a Debug and a Release setting.
        XCTAssertEqual(ids.sorted(), ["com.pausely.app.Pausely", "com.pausely.app.Pausely",
                                      "com.pausely.app.Pausely.PauselyWidget", "com.pausely.app.Pausely.PauselyWidget",
                                      "com.pausely.app.PauselyTests", "com.pausely.app.PauselyTests",
                                      "com.pausely.app.PauselyUITests", "com.pausely.app.PauselyUITests"])
    }

    func testTheSharedSchemeRunsTestsOneAtATime() throws {
        let url = root.appendingPathComponent("Pausely.xcodeproj/xcshareddata/xcschemes/Pausely.xcscheme")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let scheme = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(scheme.contains("parallelizable = \"YES\""))
        XCTAssertEqual(scheme.components(separatedBy: "parallelizable = \"NO\"").count - 1, 2, "the unit tests and the UI tests")
    }

    /// The app and the widgets are built in the Swift 6 language mode: a value shared between threads
    /// without protection is a build error there, not a warning someone may read. (Getting here took
    /// 58 warnings to zero; one of them was a real fault, the export reading the list off the main thread.)
    func testTheAppAndTheWidgetsAreBuiltWithDataRaceChecking() throws {
        let settings = try project().components(separatedBy: "isa = XCBuildConfiguration;").map { $0.components(separatedBy: "name = ")[0] }
        let shipped = settings.filter {
            $0.contains("PRODUCT_BUNDLE_IDENTIFIER = com.pausely.app.Pausely;")
                || $0.contains("PRODUCT_BUNDLE_IDENTIFIER = com.pausely.app.Pausely.PauselyWidget;")
        }
        XCTAssertEqual(shipped.count, 4, "the app and the widgets, Debug and Release")
        for configuration in shipped {
            XCTAssertTrue(configuration.contains("SWIFT_VERSION = 6.0;"))
            XCTAssertTrue(configuration.contains("SWIFT_STRICT_CONCURRENCY = complete;"))
        }
    }

    /// Two colours the system draws for the app come from the palette. The accent colour was unset,
    /// so the keyboard's search key and every text cursor were iOS blue; the launch screen was a dark
    /// purple, which showed for a moment before the app's own ink.
    func testTheSystemsColoursComeFromThePalette() throws {
        func colours(_ name: String) throws -> [String] {
            let url = root.appendingPathComponent("Pausely/Assets.xcassets/\(name).colorset/Contents.json")
            try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let entries = try XCTUnwrap(json["colors"] as? [[String: Any]])
            return try entries.map { entry in
                let components = try XCTUnwrap((entry["color"] as? [String: Any])?["components"] as? [String: String])
                let channels = try ["red", "green", "blue"].map { try XCTUnwrap(components[$0]) }
                XCTAssertTrue(channels.allSatisfy { $0.hasPrefix("0x") }, "written as the palette writes them")
                return "#" + channels.map { String($0.dropFirst(2)).uppercased() }.joined()
            }
        }
        XCTAssertEqual(try colours("AccentColor"), [Palette.text, Palette.text], "light and dark: the app is dark only")
        XCTAssertEqual(try colours("LaunchBackground"), [Palette.ink, Palette.ink])
    }

    func testNothingIsLinkedOrListedThatIsNotUsed() throws {
        let project = try project()
        XCTAssertFalse(project.contains("ActivityKit"), "Live Activities were removed; the widget must not link their framework")
        XCTAssertFalse(project.contains("(null) in "), "a build phase entry with no file behind it")
        XCTAssertFalse(project.contains(".xcconfig"), "the app's settings are in the target; a config file beside them is a second, wrong answer")
        let configuration = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Configuration").path)
        XCTAssertEqual(configuration.filter { $0.hasSuffix(".xcconfig") || $0.hasSuffix(".template") }, [])
    }
}
