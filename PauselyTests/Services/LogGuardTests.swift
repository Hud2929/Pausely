import XCTest
@testable import Pausely

/// A link from an account email carries a sign-in code, and a mail address is personal. Neither may be
/// written to the device log, in any build: logs are read by anyone holding the phone and travel in
/// sysdiagnoses. This reads the sources and fails on a logging call that names a link or an address.
final class LogGuardTests: XCTestCase {

    func testNoLogLineCarriesALinkOrAnAddress() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var offenders: [String] = []
        for folder in ["Pausely", "PauselyWidget", "Shared"] {
            let folderURL = root.appendingPathComponent(folder)
            try XCTSkipUnless(FileManager.default.fileExists(atPath: folderURL.path), "Sources aren't readable from this test run")
            let files = try XCTUnwrap(FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: nil))
            for case let file as URL in files where file.pathExtension == "swift" {
                let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
                for (index, line) in lines.enumerated() where Self.isLogCall(line) {
                    // A call may run on to the next line.
                    let call = line + (index + 1 < lines.count ? lines[index + 1] : "")
                    if Self.forbidden.contains(where: { call.range(of: $0, options: .regularExpression) != nil }) {
                        offenders.append("\(file.path.dropFirst(root.path.count + 1)):\(index + 1)")
                    }
                }
            }
        }
        XCTAssertEqual(offenders, [], "These logging calls name a link, an address or a code")
    }

    private static func isLogCall(_ line: String) -> Bool {
        line.contains("os_log(") || line.contains("PauselyLogger.") || line.contains("NSLog(") || line.contains("print(")
    }

    /// A whole link, a mail address, a token or a code, written into the message or passed to it.
    private static let forbidden = [
        #"absoluteString"#, #"\\\(url\)"#, #", url\)"#, #"url\.(query|fragment)"#,
        #"\\\([^)]*[eE]mail"#, #", [A-Za-z.]*[eE]mail[A-Za-z.? ]*\)"#,
        #"\\\([^)]*[tT]oken"#, #"\\\(code\)"#, #", code\)"#,
    ]
}
