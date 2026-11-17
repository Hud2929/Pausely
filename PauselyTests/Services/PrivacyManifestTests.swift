import XCTest
@testable import Pausely

/// The privacy manifests say which protected system APIs each bundle uses and why, and what the app
/// collects. Apple reads them at upload; a customer reads the label made from them. These tests hold
/// them to what the code does: nothing declared that isn't used, nothing used that isn't declared.
/// Reason codes: developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
final class PrivacyManifestTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func manifest(_ path: String) throws -> [String: Any] {
        let url = root.appendingPathComponent(path)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: root.appendingPathComponent("Pausely").path), "Sources aren't readable from this test run")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func reasons(_ manifest: [String: Any]) -> [String: [String]] {
        let entries = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        return Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            guard let type = entry["NSPrivacyAccessedAPIType"] as? String,
                  let reasons = entry["NSPrivacyAccessedAPITypeReasons"] as? [String] else { return nil }
            return (type.replacingOccurrences(of: "NSPrivacyAccessedAPICategory", with: ""), reasons.sorted())
        })
    }

    /// Whether any source file of a bundle mentions one of the API names. A bundle is its own folder
    /// and the shared one, which is compiled into both the app and the widgets.
    private func sources(in folder: String, mention names: [String]) throws -> Bool {
        for folder in [folder, "Shared"] {
            let files = try XCTUnwrap(FileManager.default.enumerator(at: root.appendingPathComponent(folder), includingPropertiesForKeys: nil))
            for case let file as URL in files where file.pathExtension == "swift" {
                let text = try String(contentsOf: file, encoding: .utf8)
                if names.contains(where: text.contains) { return true }
            }
        }
        return false
    }

    private static let userDefaults = ["UserDefaults", "@AppStorage"]
    private static let fileTimestamps = [".modificationDate", ".creationDate", "contentModificationDate", "attributesOfItem"]
    private static let bootTime = ["systemUptime", "mach_absolute_time", "kern.boottime"]
    private static let diskSpace = ["volumeAvailableCapacity", "attributesOfFileSystem", "systemFreeSize"]

    func testTheAppDeclaresTheProtectedAPIsItUsesAndNoOthers() throws {
        let declared = reasons(try manifest("Pausely/PrivacyInfo.xcprivacy"))
        // Its own saved settings (CA92.1) and the ones it shares with its widgets (1C8F.1); the age of
        // a logo file in its own cache (C617.1).
        XCTAssertEqual(declared, ["UserDefaults": ["1C8F.1", "CA92.1"], "FileTimestamp": ["C617.1"]])

        XCTAssertTrue(try sources(in: "Pausely", mention: Self.userDefaults))
        XCTAssertTrue(try sources(in: "Pausely", mention: Self.fileTimestamps))
        XCTAssertFalse(try sources(in: "Pausely", mention: Self.bootTime), "Boot time is read: declare it with its reason")
        XCTAssertFalse(try sources(in: "Pausely", mention: Self.diskSpace), "Disk space is read: declare it with its reason")
    }

    func testTheWidgetsDeclareTheSettingsTheyShareWithTheApp() throws {
        let declared = reasons(try manifest("PauselyWidget/PrivacyInfo.xcprivacy"))
        XCTAssertEqual(declared, ["UserDefaults": ["1C8F.1"]])
        XCTAssertTrue(try sources(in: "PauselyWidget", mention: Self.userDefaults))
        XCTAssertFalse(try sources(in: "PauselyWidget", mention: Self.fileTimestamps + Self.bootTime + Self.diskSpace))
        XCTAssertEqual((try manifest("PauselyWidget/PrivacyInfo.xcprivacy")["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0)
    }

    /// What leaves the iPhone: the address and id of the account, the subscription list (names, and
    /// what each costs), and when the person confirmed their age. Nothing is used to track anyone.
    /// A name and typed hours stay on the iPhone, so they are not here.
    func testTheAppDeclaresWhatItSendsAndNothingElse() throws {
        let app = try manifest("Pausely/PrivacyInfo.xcprivacy")
        let collected = (app["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? [])
        let types = collected.compactMap { ($0["NSPrivacyCollectedDataType"] as? String)?.replacingOccurrences(of: "NSPrivacyCollectedDataType", with: "") }
        XCTAssertEqual(types.sorted(), ["EmailAddress", "OtherDataTypes", "OtherFinancialInfo", "OtherUserContent", "UserID"])
        XCTAssertEqual(app["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((app["NSPrivacyTrackingDomains"] as? [Any])?.count, 0)
        for entry in collected {
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypePurposes"] as? [String], ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
        }
    }

    /// The answers typed into App Store Connect are kept in `docs/APP_PRIVACY_ANSWERS.md`. Its table
    /// has a row for each type the manifest declares and no other. It used to list a name and
    /// "minutes of use, if the user grants Screen Time access": neither leaves the iPhone, and
    /// Pausely does not read Screen Time.
    func testTheAnswersForAppStoreConnectListWhatTheManifestDeclares() throws {
        let app = try manifest("Pausely/PrivacyInfo.xcprivacy")
        let declared = (app["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? [])
            .compactMap { ($0["NSPrivacyCollectedDataType"] as? String)?.replacingOccurrences(of: "NSPrivacyCollectedDataType", with: "") }
        let answers = try String(contentsOf: root.appendingPathComponent("docs/APP_PRIVACY_ANSWERS.md"), encoding: .utf8)
        // A row reads "| Contact Info → **Email Address** | …": Apple's name for the type, in bold.
        let listed = answers.components(separatedBy: "\n").filter { $0.hasPrefix("| ") }.compactMap { row -> String? in
            guard let start = row.range(of: "→ **"),
                  let end = row.range(of: "**", range: start.upperBound..<row.endIndex) else { return nil }
            return row[start.upperBound..<end.lowerBound].replacingOccurrences(of: " ", with: "")
        }
        XCTAssertEqual(listed.sorted(), declared.sorted())
    }
}
