import XCTest
@testable import Pausely

/// Rules every screen keeps, each found broken by the Arabic screen tour on 2026-11-12.
///
/// A place to tap is a fingertip in both directions. Text buttons used to be given a height and
/// left as wide as their word, which was fine for "Done" in English and 15 points wide in Arabic
/// ("تم"): the system's accessibility audit found it on three screens.
///
/// And a screen that draws its own top row keeps the status bar's strip solid. Without it, scrolled
/// text slides under the clock and is read through it: the paywall and the subscription screen did.
final class ScreenRulesTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// A service with no icon is shown by its first letter, whatever comes before that letter.
    func testALogoTileShowsTheNamesFirstLetter() {
        XCTAssertEqual(ServiceLogoView.initial(of: "Netflix"), "N")
        XCTAssertEqual(ServiceLogoView.initial(of: "\u{200F}Gmail (كلمة مرور التطبيق)"), "G", "a right-to-left mark is not a letter")
        XCTAssertEqual(ServiceLogoView.initial(of: " 1Password"), "1")
        XCTAssertEqual(ServiceLogoView.initial(of: "étoile"), "É")
        XCTAssertEqual(ServiceLogoView.initial(of: ""), "")
    }

    /// A notice stays for as long as it takes to read. It used to be gone in four seconds whether it
    /// was two words or two sentences.
    func testANoticeStaysLongEnoughToRead() {
        XCTAssertEqual(NoticeModifier.seconds(toRead: "Saved."), 4)
        XCTAssertEqual(NoticeModifier.seconds(toRead: String(repeating: "a", count: 60)), 5.6, accuracy: 0.001)
        let longest = "Saved on this iPhone. It hasn't reached your account yet. Pausely will keep trying."
        XCTAssertGreaterThan(NoticeModifier.seconds(toRead: longest), 6.5)
        XCTAssertEqual(NoticeModifier.seconds(toRead: String(repeating: "a", count: 400)), 9, "and never so long that it is in the way")
    }

    /// With Reduce Motion on, what arrives fades in and nothing slides, scales or shifts. Six
    /// transitions did, whatever the setting said; they all go through `AnyTransition.arriving` now.
    func testNoTransitionMovesWithoutAskingReduceMotion() throws {
        let appFolder = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: appFolder.path), "Sources aren't readable from this test run")
        var moving: [String] = []
        var asking = 0
        let files = try XCTUnwrap(FileManager.default.enumerator(at: appFolder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            for (index, line) in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n").enumerated()
            where line.contains(".transition(") {
                if line.contains(".arriving(") { asking += 1 }
                let moves = [".move(", ".scale", ".offset(", ".slide", ".push("].contains(where: line.contains)
                if moves, !line.contains(".arriving(") { moving.append("\(file.lastPathComponent):\(index + 1)") }
            }
        }
        XCTAssertEqual(moving, [])
        XCTAssertGreaterThanOrEqual(asking, 6)
    }

    /// The day picked on Home's line is held only while a finger is on it. Kept as ordinary view state
    /// it was cleared when the drag reported its end, and a drag the scroll view takes over (a scroll
    /// that begins on the line) never does: the rows after that day could stay faded to a third.
    func testTheDayPickedOnHomesLineLetsGoWithTheFinger() throws {
        let home = root.appendingPathComponent("Pausely/Views/DashboardView.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: home.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: home, encoding: .utf8)
        XCTAssertTrue(source.contains("@GestureState private var selectedDay: Int?"))
        XCTAssertFalse(source.contains("@State private var selectedDay"))
        XCTAssertTrue(source.contains(".updating($selectedDay)"))
    }

    func testAFingertipIsFortyFourPoints() {
        XCTAssertEqual(Layout.tapTarget, 44)
    }

    /// No screen sizes a tap target by height alone: it goes through `tapArea`, or states its width.
    func testNoScreenSizesATapTargetByHeightAlone() throws {
        let views = root.appendingPathComponent("Pausely/Views")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: views.path), "Sources aren't readable from this test run")
        let heightAlone = "frame(minHeight: Layout.tapTarget)"
        var offenders: [String] = []
        let files = try XCTUnwrap(FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            for (index, line) in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n").enumerated()
            where line.contains(heightAlone) {
                offenders.append("\(file.lastPathComponent):\(index + 1)")
            }
        }
        XCTAssertEqual(offenders, [])

        // The rule every one of them uses gives both directions.
        let system = try String(contentsOf: root.appendingPathComponent("Pausely/DesignSystem/InkPaper.swift"), encoding: .utf8)
        XCTAssertTrue(system.contains("frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget, alignment: alignment)"))
        // And the one row sized by height in the design system is as wide as the screen.
        let settings = try String(contentsOf: root.appendingPathComponent("Pausely/DesignSystem/SettingsParts.swift"), encoding: .utf8)
        XCTAssertEqual(settings.components(separatedBy: heightAlone).count - 1, 1)
        XCTAssertTrue(settings.contains("Spacer(minLength: 8)"), "the settings row runs edge to edge")
    }

    /// Ink is painted through `inkScreen()`, which carries the solid strip. Painting it bare is left to
    /// screens with a navigation bar, where the system keeps the top of the screen clear itself.
    func testAScreenWithoutANavigationBarKeepsTheStatusStripSolid() throws {
        let views = root.appendingPathComponent("Pausely/Views")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: views.path), "Sources aren't readable from this test run")
        var bare: [String] = []
        var withStrip = 0
        let files = try XCTUnwrap(FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            withStrip += text.components(separatedBy: ".inkScreen()").count - 1
            let hasBar = text.contains(".navigationTitle(") || text.contains(".toolbar {")
            if text.contains("Color.ink.ignoresSafeArea()"), !hasBar { bare.append(file.lastPathComponent) }
        }
        XCTAssertEqual(bare.sorted(), [])
        XCTAssertGreaterThanOrEqual(withStrip, 17, "the four tabs, the paywall, the receipt, the verdict and the rest")
    }
}
