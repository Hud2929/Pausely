import XCTest
@testable import Pausely

/// Launch arguments are for tests, captures and demos. Only `LaunchFlag` reads them, and it answers
/// false in a release build, so a customer's app can never be steered by one.
final class LaunchFlagGuardTests: XCTestCase {

    func testOnlyLaunchFlagReadsLaunchArguments() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let appFolder = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: appFolder.path), "Sources aren't readable from this test run")

        var readers: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: appFolder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            if text.contains("processInfo.arguments") || text.contains("CommandLine.arguments") {
                readers.append(String(file.path.dropFirst(root.path.count + 1)))
            }
        }
        XCTAssertEqual(readers, ["Pausely/Core/Utilities/LaunchFlag.swift"])
    }

    /// The tests run a DEBUG build, where a flag is read; this pins the name each one answers to.
    func testEachFlagHasItsArgument() {
        XCTAssertEqual(LaunchFlag.uiTesting.rawValue, "--uitesting")
        XCTAssertEqual(LaunchFlag.demoMode.rawValue, "--demo-mode")
        XCTAssertEqual(LaunchFlag.screenshots.rawValue, "--screenshots")
        XCTAssertFalse(LaunchFlag.isSet("--an-argument-nobody-passes"))
    }
}
