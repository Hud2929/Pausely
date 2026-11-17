import SwiftUI
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

    /// A name is one line of text even when its field wraps to show it: Return takes no line break
    /// into the name, it moves on to the next field. Both forms that take a name use this.
    func testANameNeverHoldsALineBreak() throws {
        XCTAssertEqual(NameField.withoutBreaks("Adobe Creative Cloud").text, "Adobe Creative Cloud")
        XCTAssertFalse(NameField.withoutBreaks("Adobe Creative Cloud").hadBreak)
        XCTAssertEqual(NameField.withoutBreaks("Netflix\n").text, "Netflix")
        XCTAssertTrue(NameField.withoutBreaks("Netflix\n").hadBreak)
        XCTAssertEqual(NameField.withoutBreaks("Disney\r\n+").text, "Disney+")

        for file in ["Pausely/Views/Subscriptions/SubscriptionEditView.swift", "Pausely/Views/AddSubscription/AddSubscriptionView.swift"] {
            let url = root.appendingPathComponent(file)
            try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
            let source = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(source.contains("axis: .vertical"), "\(file): a long name wraps instead of being cut")
            XCTAssertTrue(source.contains(".returnMovesOn(from:"), "\(file): and Return leaves no line break in it")
        }
    }

    /// The words on a button are never cut: the button takes the height they need.
    func testAButtonGrowsToHoldItsWords() throws {
        let system = try String(contentsOf: root.appendingPathComponent("Pausely/DesignSystem/InkPaper.swift"), encoding: .utf8)
        let start = try XCTUnwrap(system.range(of: "struct InkButtonStyle: ButtonStyle"))
        let end = try XCTUnwrap(system.range(of: ".frame(maxWidth: .infinity, minHeight: 54)", range: start.upperBound..<system.endIndex))
        let label = system[start.upperBound..<end.lowerBound]
        XCTAssertTrue(label.contains(".fixedSize(horizontal: false, vertical: true)"))
        XCTAssertFalse(label.contains("lineLimit"), "no limit on its lines")
    }

    /// The stamp on a decided slip is one whole word at every text size: it shrinks to fit the slip
    /// and is never cut to "CANCELL…".
    func testAStampIsNeverCutShort() throws {
        let verdict = try String(contentsOf: root.appendingPathComponent("Pausely/Views/Verdict/RenewalVerdictView.swift"), encoding: .utf8)
        let start = try XCTUnwrap(verdict.range(of: "Text(verbatim: stamp)"))
        let end = try XCTUnwrap(verdict.range(of: "Perforation()", range: start.upperBound..<verdict.endIndex))
        let stamp = verdict[start.upperBound..<end.lowerBound]
        XCTAssertTrue(stamp.contains(".lineLimit(1)"), "one line")
        XCTAssertTrue(stamp.contains(".minimumScaleFactor(0.5)"), "shrinks instead of ending in an ellipsis")
    }

    /// Buttons stay at the bottom edge on an iPhone at ordinary text sizes. They follow the content
    /// at the accessibility sizes, where pinned they covered more than half the screen, and on iPad,
    /// where pinned they sat half a screen below what they are about.
    func testButtonsLeaveTheBottomEdgeAtAccessibilitySizesAndOnIPad() {
        typealias Screen = ActionScreen<EmptyView, EmptyView>
        for size in [DynamicTypeSize.xSmall, .large, .xxxLarge] {
            XCTAssertTrue(Screen.pinsActions(at: size, onPad: false), "\(size)")
            XCTAssertFalse(Screen.pinsActions(at: size, onPad: true), "\(size) on iPad")
        }
        for size in [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5] {
            XCTAssertFalse(Screen.pinsActions(at: size, onPad: false), "\(size)")
            XCTAssertFalse(Screen.pinsActions(at: size, onPad: true), "\(size) on iPad")
        }
    }

    /// No screen pins its own buttons under a scroll view: that is `ActionScreen`'s job, so the rule
    /// above holds everywhere. (The first-run tally's slip and the inbox's Add bar are not button
    /// bars: one is the slip itself, the other appears only while something is chosen.)
    func testNoScreenPinsItsOwnButtons() throws {
        let views = root.appendingPathComponent("Pausely/Views")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: views.path), "Sources aren't readable from this test run")
        var offenders: [String] = []
        let files = FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        for file in files + [root.appendingPathComponent("Pausely/ContentView.swift")] where file.pathExtension == "swift" {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let name = file.lastPathComponent
                if line.contains(".safeAreaInset(edge: .bottom"), name != "InboxImportView.swift" {
                    offenders.append("\(name):\(index + 1)")
                }
                // `VStack(spacing: 0) {` directly holding `ScrollView {` with something after it.
                if line.trimmingCharacters(in: .whitespaces) == "VStack(spacing: 0) {", index + 1 < lines.count,
                   lines[index + 1].trimmingCharacters(in: .whitespaces) == "ScrollView {",
                   name != "TallyStep.swift", name != "InboxImportView.swift" {
                    offenders.append("\(name):\(index + 1)")
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }

    /// Every field that wraps goes through `returnMovesOn`, and that is where it is built again when
    /// the text size changes: SwiftUI otherwise keeps the line count of the old size, and the edit
    /// screen's header stayed three lines tall around a one-line name.
    func testAWrappingFieldIsMeasuredAgainWhenTheTextSizeChanges() throws {
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        var wrapping = 0
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        for file in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            let fields = source.components(separatedBy: "axis: .vertical").count - 1
            let guarded = source.components(separatedBy: ".returnMovesOn(from:").count - 1
            XCTAssertEqual(fields, guarded, "\(file.lastPathComponent): every wrapping field uses returnMovesOn")
            wrapping += fields
        }
        XCTAssertEqual(wrapping, 2, "The two forms that take a name")

        let controls = try String(contentsOf: sources.appendingPathComponent("DesignSystem/InkControls.swift"), encoding: .utf8)
        let function = try XCTUnwrap(controls.range(of: "func returnMovesOn"))
        let body = controls[function.lowerBound...].prefix(500)
        XCTAssertTrue(body.contains(".modifier(MeasuredAgainAtEachTextSize())"))
        XCTAssertTrue(controls.contains("content.id(typeSize)"))
    }

    /// The first question keeps its answer beside it on iPad: at the bottom edge, the number, its
    /// slider and the button were a thousand points below "What do you think you pay?". On an
    /// iPhone they stay low, where a thumb reaches them, until the text is at an accessibility
    /// size: there they took the screen and the question was cut after its third line, so the
    /// step is one page read from the top.
    func testTheFirstQuestionIsOnePageOnIPadAndAtTheLargestText() throws {
        XCTAssertTrue(GuessStep.answerSitsLow(onPad: false, largeText: false))
        XCTAssertFalse(GuessStep.answerSitsLow(onPad: true, largeText: false))
        XCTAssertFalse(GuessStep.answerSitsLow(onPad: false, largeText: true))
        XCTAssertFalse(GuessStep.answerSitsLow(onPad: true, largeText: true))

        // Beside the track the two ends left it a third of the width at those sizes.
        XCTAssertFalse(GuessStep.endsSitUnderTheTrack(largeText: false))
        XCTAssertTrue(GuessStep.endsSitUnderTheTrack(largeText: true))

        let url = root.appendingPathComponent("Pausely/Views/FirstRun/GuessStep.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: url, encoding: .utf8)
        let step = try XCTUnwrap(source.range(of: "struct GuessStep: View"))
        let body = String(source[step.lowerBound...].prefix(2600))
        XCTAssertTrue(body.contains("if Self.answerSitsLow(onPad: onPad, largeText: typeSize.isAccessibilitySize) {"))
        // The other arrangement is one scroll that holds all four parts, in reading order.
        let onePage = try XCTUnwrap(body.range(of: "} else {"))
        let parts = ["ScrollView {", "header", "question", "answer", "nextButton"]
        var from = onePage.upperBound
        for part in parts {
            let found = try XCTUnwrap(body.range(of: part, range: from..<body.endIndex), "\(part) is missing from the one-page arrangement")
            from = found.upperBound
        }
    }

    /// "Pausely" is one word and is never broken: beside "Sign in" at the largest text size it was
    /// "Pausel" above "y". Measured, not read from the source: the same word without the rule does
    /// break when it is given less than its width.
    @MainActor
    func testTheWordmarkIsNeverBrokenInsideTheName() {
        func size(_ view: some View, width: CGFloat) -> CGSize {
            UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 2000))
        }
        let whole = size(Wordmark(), width: 1000)
        let squeezed = size(Wordmark(), width: 40)
        XCTAssertGreaterThan(whole.width, 40, "The check means nothing unless the name is wider than the room it is given")
        XCTAssertEqual(squeezed.height, whole.height, accuracy: 0.5)
        XCTAssertEqual(squeezed.width, whole.width, accuracy: 0.5)

        let plain = Text(verbatim: "Pausely").font(.headline)
        XCTAssertGreaterThan(size(plain, width: 40).height, size(plain, width: 1000).height + 1,
                             "Without the rule the word breaks, so this measurement can tell")

        // With the year after it (the slip of "Your year in subscriptions") it still breaks, at
        // the space: held to one line it ran off the slip at the largest text size.
        let dated = Wordmark(text: "Pausely 2026")
        let oneLine = size(dated, width: 1000)
        XCTAssertEqual(oneLine.height, whole.height, accuracy: 0.5)
        let twoLines = size(dated, width: whole.width + 8)
        XCTAssertGreaterThan(twoLines.height, oneLine.height + 1)
        XCTAssertLessThanOrEqual(twoLines.width, whole.width + 8.5)
    }

    /// At the accessibility text sizes the tally keeps services on screen: they come straight
    /// after the heading, and the slip at the bottom edge holds only the way on. With "Anything
    /// missing…" on three lines above the list and the count on three lines above a two-line
    /// button, the slip met the heading and there was nothing left to tap.
    func testAtTheLargestTextTheTallyLeavesRoomForItsServices() throws {
        XCTAssertFalse(TallyStep.listComesStraightAfterTheHeading(largeText: false))
        XCTAssertTrue(TallyStep.listComesStraightAfterTheHeading(largeText: true))
        XCTAssertFalse(TallyStep.slipHoldsOnlyTheWayOn(largeText: false))
        XCTAssertTrue(TallyStep.slipHoldsOnlyTheWayOn(largeText: true))

        let url = root.appendingPathComponent("Pausely/Views/FirstRun/TallyStep.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: url, encoding: .utf8)
        // The sentence is still said once at every size: above the list, or after it.
        XCTAssertEqual(source.components(separatedBy: "Text(\"Anything missing can be added afterwards.\")").count - 1, 1)
        XCTAssertEqual(source.components(separatedBy: "addedAfterwards\n").count - 1, 2)
        XCTAssertTrue(source.contains("if !Self.listComesStraightAfterTheHeading(largeText: typeSize.isAccessibilitySize) {"))
        XCTAssertTrue(source.contains("if Self.listComesStraightAfterTheHeading(largeText: typeSize.isAccessibilitySize) {"))
        // Both the last line printed and the count are left out there; the button is not.
        let slip = try XCTUnwrap(source.range(of: "private var slipBar: some View"))
        let bar = String(source[slip.lowerBound...].prefix(1500))
        let guarded = try XCTUnwrap(bar.range(of: "if !onlyTheWayOn {"))
        let button = try XCTUnwrap(bar.range(of: "Button(action: onReveal)"))
        let count = try XCTUnwrap(bar.range(of: "L10n.string(\"On your slip\")"))
        XCTAssertTrue(guarded.upperBound < count.lowerBound && count.upperBound < button.lowerBound)
    }

    /// Facts joined by " · " sit one to a line at the accessibility text sizes, with no dot: where
    /// "Wed, Nov 18 ·" was a character too wide, the dot began the next line ("· in 5 days").
    func testFactsSitOneToALineAtTheLargestText() throws {
        let nb = "\u{00A0}"
        let date = "Wed,\(nb)Nov\(nb)18", away = "in\(nb)5\(nb)days"
        XCTAssertEqual(L10n.facts("\(date) · \(away)", oneToALine: false), "\(date)\(nb)· \(away)", "side by side: breaks after the dot")
        XCTAssertEqual(L10n.facts("\(date) · \(away)", oneToALine: true), "\(date)\n\(away)")
        // A line that was already made to break after its dots comes out the same.
        XCTAssertEqual(L10n.facts(L10n.breakingAfterDots("\(date) · \(away)"), oneToALine: true), "\(date)\n\(away)")
        XCTAssertEqual(L10n.facts(L10n.breakingAfterDots("\(date) · \(away)"), oneToALine: false), "\(date)\(nb)· \(away)")
        XCTAssertEqual(L10n.facts("Emails checked: 412 · read in full: 37 · all on your phone", oneToALine: true),
                       "Emails checked: 412\nread in full: 37\nall on your phone")
        XCTAssertEqual(L10n.facts("Cancelled", oneToALine: true), "Cancelled")
        XCTAssertEqual(L10n.facts("Cancelled", oneToALine: false), "Cancelled")

        // Each place that shows such a line draws it through `Facts`, which reads the text size.
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let drawn: [(file: String, with: String)] = [
            ("Views/SubscriptionsView.swift", "Facts(detail)"),
            ("Views/DashboardView.swift", "Facts(detail)"),
            ("Views/DashboardView.swift", "Facts(when)"),
            ("Views/Verdict/RenewalVerdictView.swift", "Facts(whenText(charge))"),
            ("Views/Verdict/RenewalVerdictView.swift", "Facts(text)"),
            ("Views/SubscriptionManagementView.swift", "Facts(line.text)"),
            ("Views/Verdict/PausePlanView.swift", "Facts(price)"),
            ("Views/InboxImportView.swift", "Facts(accountDetail(account))"),
            ("Views/InboxImportView.swift", "Facts(L10n.string(\"Emails checked: ")
        ]
        for place in drawn {
            let source = try String(contentsOf: sources.appendingPathComponent(place.file), encoding: .utf8)
            XCTAssertTrue(source.contains(place.with), "\(place.file) no longer draws \(place.with)")
        }
        // The Savings Receipt had such a line ("Cancelled Nov 2 · 1 of 12 charges avoided so far").
        // Its two facts are two lines of the roll now, at every size: joined, they were too long
        // for the roll and broke wherever the line ran out.
        let receipt = try String(contentsOf: sources.appendingPathComponent("Views/Verdict/SavingsReceiptView.swift"), encoding: .utf8)
        XCTAssertFalse(receipt.contains("Facts("))
        XCTAssertTrue(receipt.contains("Text(L10n.string(\"Cancelled on \\(line.cancelledOn."))
        let design = try String(contentsOf: sources.appendingPathComponent("DesignSystem/InkLayout.swift"), encoding: .utf8)
        XCTAssertTrue(design.contains("Text(verbatim: L10n.facts(line, oneToALine: typeSize.isAccessibilitySize))"))
    }

    /// The empty name field on "Add your own" shows a hint that fits. A field shows its hint on
    /// one line: at the accessibility text sizes "Netflix, Spotify…" was cut to "Netflix, Spo…",
    /// so there it says "Name", in every language.
    func testTheNameHintFitsAtTheLargestText() throws {
        XCTAssertEqual(AddSubscriptionView.nameHint(largeText: false), L10n.string("Netflix, Spotify…"))
        XCTAssertEqual(AddSubscriptionView.nameHint(largeText: true), L10n.string("Name"))

        // Measured in the face the field uses, at the largest size, on the narrowest iPhone.
        let largest = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let size = UIFont.preferredFont(forTextStyle: .title1, compatibleWith: largest).pointSize
        let system = UIFont.systemFont(ofSize: size, weight: .semibold)
        let serif = system.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? system
        func width(_ text: String) -> CGFloat { (text as NSString).size(withAttributes: [.font: serif]).width }
        let room: CGFloat = 375 - 2 * Layout.margin
        XCTAssertGreaterThan(width("Netflix, Spotify…"), room, "The examples do not fit there, which is why the rule exists")

        let url = root.appendingPathComponent("Pausely/Localizable.xcstrings")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: [String: Any]])
        let name = try XCTUnwrap(strings["Name"]?["localizations"] as? [String: [String: Any]])
        var hints = ["en": "Name"]
        for language in ["ar", "de", "es", "fr", "ja"] {
            hints[language] = try XCTUnwrap((name[language]?["stringUnit"] as? [String: Any])?["value"] as? String, language)
        }
        for (language, hint) in hints {
            XCTAssertLessThanOrEqual(width(hint), room, "\(language): \(hint)")
        }
    }

    /// On the results of a search, at the accessibility text sizes, the bar at the bottom edge
    /// holds only "Add to my list". The free-limit note is still said before the tap: under the
    /// heading. In the bar, with a button of two lines, it left one line of what was found.
    func testAtTheLargestTextTheResultsBarHoldsOnlyItsButton() throws {
        XCTAssertFalse(InboxImportView.barHoldsOnlyTheButton(largeText: false))
        XCTAssertTrue(InboxImportView.barHoldsOnlyTheButton(largeText: true))

        let url = root.appendingPathComponent("Pausely/Views/InboxImportView.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: url, encoding: .utf8)
        // Written once, shown in one of two places.
        XCTAssertEqual(source.components(separatedBy: ".accessibilityIdentifier(\"freeLimitNote\")").count - 1, 1)
        XCTAssertTrue(source.contains("if Self.barHoldsOnlyTheButton(largeText: typeSize.isAccessibilitySize) { freeLimitNote }"))
        XCTAssertTrue(source.contains("if !Self.barHoldsOnlyTheButton(largeText: typeSize.isAccessibilitySize) { freeLimitNote }"))
        // Under the heading, above the slip.
        let heading = try XCTUnwrap(source.range(of: "Text(\"We found \\(count) subscriptions\")"))
        let under = try XCTUnwrap(source.range(of: "if Self.barHoldsOnlyTheButton(largeText: typeSize.isAccessibilitySize) { freeLimitNote }"))
        let slip = try XCTUnwrap(source.range(of: "PaperSlip(tornTop: true, tornBottom: true) {", range: heading.upperBound..<source.endIndex))
        XCTAssertTrue(heading.upperBound < under.lowerBound && under.upperBound < slip.lowerBound)
    }

    /// A figure is never broken in the middle. Where the longest part a line cannot break is wider
    /// than the line, the line is drawn smaller until that part fits: a year of rupiah on a slip
    /// at the largest text size was "114,881,88" with "0" on the line below.
    func testAFigureIsDrawnSmallerBeforeItIsBroken() {
        let largest = WordFit.font(.subheadline, weight: .bold, monospaced: true, at: .accessibility5)
        let ordinary = WordFit.font(.subheadline, weight: .bold, monospaced: true, at: .large)
        XCTAssertGreaterThan(largest.pointSize, ordinary.pointSize * 2, "The measuring face follows the text size")

        // What cannot break: a no-break space joins, a space or a zero-width space parts.
        let figure = WordFit.widestWord(of: "114,881,880", in: largest)
        XCTAssertEqual(WordFit.widestWord(of: "IDR 114,881,880", in: largest), figure)
        XCTAssertEqual(WordFit.widestWord(of: "a\u{200B}114,881,880\nb", in: largest), figure)
        XCTAssertGreaterThan(WordFit.widestWord(of: "IDR\u{00A0}114,881,880", in: largest), figure)
        XCTAssertEqual(WordFit.widestWord(of: "", in: largest), 0)

        // A slip on an iPhone 17: the screen less its margins and the slip's own.
        let slip: CGFloat = 402 - 2 * Layout.margin - 2 * 18
        XCTAssertGreaterThan(figure, slip, "At full size the figure is wider than the slip, which is how it was broken")
        let scale = WordFit.scale(for: "IDR 114,881,880", in: largest, width: slip)
        XCTAssertLessThan(scale, 1)
        XCTAssertGreaterThanOrEqual(scale, WordFit.smallest)
        XCTAssertLessThanOrEqual(WordFit.widestWord(of: "114,881,880", in: largest.withSize((largest.pointSize * scale).rounded(.down))), slip,
                                 "Drawn at that scale, all of it is on one line")

        // Under its label a currency and its figure may part, so the figure is as large as the
        // line allows: the amount as money is written (a space that cannot break) was one
        // part, and took half the size to fit.
        let written = "IDR\u{00A0}114,881,880"
        XCTAssertEqual(ProofLine.partsThatMayPart(written), "IDR 114,881,880")
        XCTAssertEqual(ProofLine.partsThatMayPart("12\u{202F}345,67\u{00A0}€"), "12 345,67 €")
        XCTAssertLessThan(WordFit.scale(for: written, in: largest, width: slip), scale)
        XCTAssertEqual(WordFit.scale(for: ProofLine.partsThatMayPart(written), in: largest, width: slip), scale)

        // Nothing changes where it fits, or before the line has been measured.
        XCTAssertEqual(WordFit.scale(for: "IDR 114,881,880", in: ordinary, width: slip), 1)
        XCTAssertEqual(WordFit.scale(for: "$18.99", in: largest, width: slip), 1)
        XCTAssertEqual(WordFit.scale(for: "IDR 114,881,880", in: largest, width: 0), 1)
        // And never so small that it is no longer large text.
        XCTAssertEqual(WordFit.scale(for: "1,000,000,000,000,000,000,000", in: largest, width: 100), WordFit.smallest)
    }

    /// A receipt line at the accessibility text sizes starts at the leading edge and takes the
    /// width it is given. Given a row as wide as the slip it used to sit centred, each pair of
    /// name and price on its own centre ("Netflix" indented, "YouTube Premium" less so).
    @MainActor
    func testAReceiptLineStartsAtTheLeadingEdgeAtTheLargestText() throws {
        func width(_ size: DynamicTypeSize) -> CGFloat {
            let line = ProofLine(label: "Netflix", value: "$18.99").environment(\.dynamicTypeSize, size)
            return UIHostingController(rootView: line).sizeThatFits(in: CGSize(width: 326, height: 4000)).width
        }
        XCTAssertEqual(width(.accessibility5), 326, accuracy: 0.5)
        XCTAssertEqual(width(.accessibility1), 326, accuracy: 0.5)
        XCTAssertEqual(width(.large), 326, accuracy: 0.5, "Side by side it always did")

        let url = root.appendingPathComponent("Pausely/DesignSystem/InkPaper.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("VStack(alignment: .leading, spacing: 2) { labelText; valueUnderItsLabel }"))
        let under = try XCTUnwrap(source.range(of: "private var valueUnderItsLabel: some View"))
        XCTAssertTrue(source[under.lowerBound...].prefix(400).contains(".wholeWords(parts, font: .proof(.subheadline"))
    }

    /// A state's mark or a service's logo sits above its words at the accessibility text sizes,
    /// so the words have the whole line. Beside the logo "IDR 102,000,000 a year" lost its last
    /// digit to the next line; beside a mark "Spotify" was hyphenated and its price broken.
    func testAMarkSitsAboveItsWordsAtTheLargestText() throws {
        XCTAssertFalse(MarkPlacement.sitsAbove(largeText: false))
        XCTAssertTrue(MarkPlacement.sitsAbove(largeText: true))

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let design = try String(contentsOf: sources.appendingPathComponent("DesignSystem/InkLayout.swift"), encoding: .utf8)
        XCTAssertTrue(design.contains("if MarkPlacement.sitsAbove(largeText: typeSize.isAccessibilitySize) {"))
        let places: [(file: String, after: String)] = [
            ("Views/Verdict/RenewalVerdictView.swift", "private func header("),
            ("Views/Components/CancelSubscriptionFlow.swift", "PaperSlip(tornTop: true, tornBottom: true) {"),
            ("Views/AnalysisView.swift", "L10n.string(\"What went up\")"),
            ("Views/Settings/NotificationsSettingsView.swift", "let status = notifications.status"),
            ("Views/Components/PriceHistoryView.swift", "private func summary("),
            // Profile's rows and a subscription's tools (2026-11-17): beside their symbols,
            // "Usage and value" and "What's new" were a word to a line.
            ("Views/ProfileView.swift", "private func row("),
            ("Views/SubscriptionManagementView.swift", "private func toolRow(")
        ]
        for place in places {
            let source = try String(contentsOf: sources.appendingPathComponent(place.file), encoding: .utf8)
            let start = try XCTUnwrap(source.range(of: place.after), place.file)
            XCTAssertTrue(source[start.upperBound...].prefix(900).contains("MarkedWords"), "\(place.file): the mark is beside its words at every size")
        }
        // A connected inbox: its mark shares a line with its options there, and the address
        // has the row (the envelope lay over the address's first letters).
        let inbox = try String(contentsOf: sources.appendingPathComponent("Views/InboxImportView.swift"), encoding: .utf8)
        let row = try XCTUnwrap(inbox.range(of: "private func accountRow("))
        let body = String(inbox[row.upperBound...].prefix(2600))
        let above = try XCTUnwrap(body.range(of: "if MarkPlacement.sitsAbove(largeText: typeSize.isAccessibilitySize) {"))
        let beside = try XCTUnwrap(body.range(of: "} else {", range: above.upperBound..<body.endIndex))
        let stacked = body[above.upperBound..<beside.lowerBound]
        XCTAssertTrue(stacked.contains("mark\n                        Spacer(minLength: 8)\n                        options"))
        XCTAssertTrue(stacked.contains("words"))
        XCTAssertFalse(stacked.contains(".frame(width: 28)"), "the mark is as wide as its glyph there")

        // The kinds of inbox to connect: the same rule, and a symbol's box grows with its glyph.
        // In a box held to 36 points the envelope at the largest text size was wider than its
        // box, out of the row on one side and into "WEB.DE," on the other.
        let kinds = try String(contentsOf: sources.appendingPathComponent("Views/Inbox/InboxProviderList.swift"), encoding: .utf8)
        let kind = try XCTUnwrap(kinds.range(of: "private func row("))
        let kindRow = String(kinds[kind.upperBound...])
        XCTAssertTrue(kindRow.contains("MarkedWords(alignment: .center, spacing: 12) {"))
        XCTAssertTrue(kindRow.contains(".frame(minWidth: 36, minHeight: 36)"))
        XCTAssertFalse(kindRow.contains(".frame(width: 36, height: 36)"))
    }

    /// Home's total is never cut off. At the accessibility text sizes it has the whole width
    /// (it sat beside "+") and may take two lines, the currency above the figure: on one line
    /// beside "+", already at half its size, a total in the millions ended "IDR 9,573,4…".
    func testHomesTotalIsNeverCutOff() throws {
        XCTAssertEqual(DashboardView.totalLines(largeText: false), 1)
        XCTAssertEqual(DashboardView.totalLines(largeText: true), 2)
        XCTAssertFalse(DashboardView.totalHasTheWholeWidth(largeText: false))
        XCTAssertTrue(DashboardView.totalHasTheWholeWidth(largeText: true))

        // Measured in the face the total uses, at the largest size, on the narrowest iPhone.
        let largest = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let size = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 52, compatibleWith: largest)
        let page: CGFloat = 375 - 2 * Layout.margin
        let besideAdd = page - 12 - Layout.tapTarget
        XCTAssertGreaterThan(AmountFit.width(of: "IDR 114,881,880", size: size * 0.5), besideAdd,
                             "Beside the button it does not fit on one line even at half size, which is how it was cut off")
        XCTAssertLessThanOrEqual(AmountFit.width(of: "114,881,880", size: size * 0.5), page,
                                 "On a line of its own, across the page, the figure fits")

        let url = root.appendingPathComponent("Pausely/Views/DashboardView.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: url, encoding: .utf8)
        let total = try XCTUnwrap(source.range(of: ".accessibilityIdentifier(\"spendTotal\")"))
        let drawn = String(source[..<total.lowerBound].suffix(500))
        XCTAssertTrue(drawn.contains(".lineLimit(Self.totalLines(largeText: typeSize.isAccessibilitySize))"))
        XCTAssertTrue(drawn.contains(".minimumScaleFactor(0.5)"))
        // With the whole width, the row that holds "+" ends before the total begins.
        let wide = try XCTUnwrap(source.range(of: "if Self.totalHasTheWholeWidth(largeText: typeSize.isAccessibilitySize) {"))
        let arrangement = String(source[wide.upperBound...].prefix(420))
        let button = try XCTUnwrap(arrangement.range(of: "addButton"))
        let figure = try XCTUnwrap(arrangement.range(of: "totalFigure"))
        XCTAssertTrue(button.upperBound < figure.lowerBound)
        XCTAssertTrue(arrangement[button.upperBound..<figure.lowerBound].contains("}"))
    }

    /// In the list, "/mo" goes under the amount before the amount is broken, and a value that
    /// has gone under its title in a settings row reads from the leading edge.
    func testAnAmountIsNotBrokenToMakeRoomForItsUnit() throws {
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let list = try String(contentsOf: sources.appendingPathComponent("Views/SubscriptionsView.swift"), encoding: .utf8)
        let price = try XCTUnwrap(list.range(of: "private var price: some View {"))
        XCTAssertTrue(list[price.upperBound...].prefix(120).contains("LineOrStack(spacing: 2, lineSpacing: 0, alignment: .firstTextBaseline) {"),
                      "Side by side in an HStack the unit took its width first and the amount broke after its currency")

        // Two parts that do not fit a line: the second goes under, and the first keeps its width.
        XCTAssertEqual(LineOrStack.arrangement(widths: [330, 75], spacing: 2, in: 362, besideShare: 0), .stack)
        XCTAssertEqual(LineOrStack.arrangement(widths: [200, 75], spacing: 2, in: 362, besideShare: 0), .line)

        let rows = try String(contentsOf: sources.appendingPathComponent("DesignSystem/SettingsParts.swift"), encoding: .utf8)
        let stacked = try XCTUnwrap(rows.range(of: "// Large text gets the full width; what was at the end goes underneath."))
        let sideBySide = try XCTUnwrap(rows.range(of: "HStack(alignment: .center, spacing: 12) {", range: stacked.upperBound..<rows.endIndex))
        XCTAssertTrue(rows[stacked.upperBound..<sideBySide.lowerBound].contains("trailing\n                            .multilineTextAlignment(.leading)"))
        XCTAssertTrue(rows[sideBySide.upperBound...].prefix(600).contains(".multilineTextAlignment(.trailing)"))
        let history = try String(contentsOf: sources.appendingPathComponent("Views/Components/PriceHistoryView.swift"), encoding: .utf8)
        XCTAssertFalse(history.contains(".multilineTextAlignment(.trailing)"), "The row decides, by where the value sits")
    }

    /// A group's title on the Subscriptions list scrolls with its rows. As a pinned section header
    /// it was right on iOS 26, which pushes a pinned header away as the next one arrives. iOS 18
    /// does not: the next title slides under the pinned one, and where the list came to rest in
    /// between, "Needs a decision" lay over half of "This week" (seen 2026-11-17, the first time
    /// the app was run on the oldest iOS it allows; measured by dragging the list 14 points at a
    /// time on both). No list in the app pins a header now.
    func testNoListPinsAHeader() throws {
        // The gap above a group's title is larger than the gap inside the group.
        XCTAssertEqual(SubscriptionsView.titleTopPadding(first: true), 12)
        XCTAssertGreaterThan(SubscriptionsView.titleTopPadding(first: false), 24)

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        var pinned: [String] = []
        for file in try FileManager.default.subpathsOfDirectory(atPath: sources.path) where file.hasSuffix(".swift") {
            let text = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            if text.contains("} header: {") || text.contains("Section(header:") || text.contains("pinnedViews:") { pinned.append(file) }
        }
        XCTAssertEqual(pinned, [], "a section header in a plain list is pinned, and so is a pinned view in a lazy stack")
        let list = try String(contentsOf: sources.appendingPathComponent("Views/SubscriptionsView.swift"), encoding: .utf8)
        XCTAssertTrue(list.contains("sectionTitle(section, first: section.id == sections.first?.id)"))
        XCTAssertTrue(list.contains(".accessibilityAddTraits(.isHeader)"), "it is still a heading to VoiceOver")
    }

    /// Profile is titled by the name the person gave, and by nothing made up. An account made with
    /// an address has no name: the page made one out of the address ("Jane.Doe"; for an address
    /// Apple hides, a run of letters) and set it above the address itself. No capture had shown it:
    /// a demo launch has nobody signed in (seen 2026-11-17, on a simulator that had someone).
    func testProfileIsTitledByTheNameThePersonGave() throws {
        XCTAssertEqual(ProfileView.title(for: nil), L10n.string("Profile"))
        XCTAssertEqual(ProfileView.title(for: User(id: "1", email: "jane.doe@example.com")), L10n.string("Profile"))
        XCTAssertEqual(ProfileView.title(for: User(id: "1", email: "x7k2p9qw4m@privaterelay.appleid.com")), L10n.string("Profile"))
        XCTAssertEqual(ProfileView.title(for: User(id: "1", email: "jane.doe@example.com", firstName: "Jane", lastName: "Doe")), "Jane Doe")
        XCTAssertEqual(ProfileView.title(for: User(id: "1", email: nil, firstName: " ", lastName: "")), L10n.string("Profile"), "blanks are not a name")
        // What the tour shows: an address only, and a name with one.
        XCTAssertNil(ProfileView.demoAccount("").fullName)
        XCTAssertEqual(ProfileView.demoAccount("named").fullName, "Jane Doe")

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let profile = try String(contentsOf: sources.appendingPathComponent("Views/ProfileView.swift"), encoding: .utf8)
        // The address under the title is whole and takes no hyphen, like every other address.
        XCTAssertTrue(profile.contains("Text(verbatim: AddressText.breakable(email))"))
        XCTAssertTrue(profile.contains(".accessibilityLabel(Text(verbatim: email))"))
        let user = try String(contentsOf: sources.appendingPathComponent("Models/User.swift"), encoding: .utf8)
        XCTAssertFalse(user.contains(".capitalized"), "no name is made out of an address")
    }

    /// A service's name is not hyphenated in its first-run tile. At the largest text size the
    /// name has the tile less the tick's place, and "Crunchyroll" and "PlayStation" are wider
    /// than that: iOS drew "Crunchy-roll" and "PlaySta-tion Plus" (seen 2026-11-17). The name is
    /// drawn smaller until its longest word fits.
    func testAServiceNameIsNotHyphenatedInItsTile() throws {
        let font = WordFit.font(.body, weight: .medium, monospaced: false, at: .accessibility5)
        // The screen's width, less its margins, the tile's padding and the tick's place.
        let room: CGFloat = 250
        for name in ["Crunchyroll", "PlayStation Plus"] {
            let widest = WordFit.widestWord(of: name, in: font)
            XCTAssertGreaterThan(widest, room, "\(name): the case this is for")
            let scale = WordFit.scale(for: name, in: font, width: room)
            XCTAssertLessThan(scale, 1)
            XCTAssertGreaterThan(scale, WordFit.smallest, "\(name) is still read at a size near the one asked for")
            XCTAssertLessThanOrEqual(widest * scale, room + 0.5, "\(name) fits whole")
        }
        XCTAssertEqual(WordFit.scale(for: "Netflix", in: font, width: room), 1, "a name that fits is left alone")

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let tally = try String(contentsOf: sources.appendingPathComponent("Views/FirstRun/TallyStep.swift"), encoding: .utf8)
        XCTAssertTrue(tally.contains(".wholeWords(service.name, font: .body.weight(.medium), measuredIn: .body, weight: .medium)"))
    }

    /// In the reasons a found subscription gives, a charge is never broken to fit beside its
    /// day. Side by side at the largest text size the day took three lines ("Nov", "14,", "2026")
    /// and the amount a line and a digit ("$34.9", "9"): the page nobody had reached at that size
    /// until the tour followed what a tap opens (2026-11-17).
    func testAChargeInTheReasonsIsNeverBrokenToFitBesideItsDay() throws {
        // The reasons start where the name does: past the box, or at the row's edge.
        XCTAssertEqual(FoundRow.reasonsInset(largeText: false), 46)
        XCTAssertEqual(FoundRow.reasonsInset(largeText: true), 0)
        XCTAssertTrue(FoundRow.wordsHaveTheWholeRow(largeText: true))
        // "Nov 14, 2026" and "$34.99" at the largest size, in the row's width: one under the other.
        XCTAssertEqual(LineOrStack.arrangement(widths: [318, 160], spacing: 8, in: 362, besideShare: 0), .stack)
        // At the default size: on a line, the amount at the far end.
        XCTAssertEqual(LineOrStack.arrangement(widths: [92, 46], spacing: 8, in: 316, besideShare: 0), .line)

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let found = try String(contentsOf: sources.appendingPathComponent("Views/Inbox/FoundRow.swift"), encoding: .utf8)
        let charges = try XCTUnwrap(found.range(of: "ForEach(proven.evidence.suffix(5).reversed()) { charge in"))
        let row = String(found[charges.upperBound...].prefix(900))
        XCTAssertTrue(row.contains("LineOrStack(spacing: 8, lineSpacing: 0, spread: true, alignment: .firstTextBaseline) {"))
        XCTAssertFalse(row.contains("HStack {"), "an HStack shares the width out and breaks both")
        XCTAssertTrue(found.contains(".padding(.leading, Self.reasonsInset(largeText: typeSize.isAccessibilitySize))"))
    }

    /// A price is never drawn smaller than the "/mo" beside it. The two were two texts on a line
    /// and only the amount gave way: at the largest text size "IDR 8,500,000" stood at six tenths
    /// of its size beside a full-size "/mo", on the subscription's page and on the verdict (seen
    /// 2026-11-17). They are one text now, so whatever the line does it does to both.
    func testAPriceIsNeverDrawnSmallerThanItsPeriod() throws {
        // No line can break between an amount and its period, or inside the period.
        XCTAssertEqual(PricePerPeriod.joined("/mo"), "\u{202F}/\u{2060}mo")
        XCTAssertEqual(PricePerPeriod.joined("/2wk"), "\u{202F}/\u{2060}2wk")
        let line = PricePerPeriod.line(amount: "IDR 8,500,000", period: "/mo", amountFont: .largeTitle, periodFont: .title3, periodColor: .inkTextMuted)
        XCTAssertEqual(String(line.characters), "IDR 8,500,000\u{202F}/\u{2060}mo")
        XCTAssertEqual(line.runs.count, 2, "the amount in its face, the period in its own")
        // One line, and at the accessibility sizes two: the figure goes under its currency before
        // the line is drawn smaller, as Home's total does.
        XCTAssertEqual(PricePerPeriod.lines(largeText: false), 1)
        XCTAssertEqual(PricePerPeriod.lines(largeText: true), DashboardView.totalLines(largeText: true))
        XCTAssertGreaterThanOrEqual(PricePerPeriod.smallest, 0.5)

        // No screen sets a period as a text of its own beside an amount that can shrink.
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let views = sources.appendingPathComponent("Views")
        var periods: [String] = []
        for file in try FileManager.default.subpathsOfDirectory(atPath: views.path) where file.hasSuffix(".swift") {
            let text = try String(contentsOf: views.appendingPathComponent(file), encoding: .utf8)
            if text.contains(".shortDisplay") { periods.append(file) }
        }
        // The list's row puts "/mo" under an amount that does not fit beside it and shrinks neither.
        XCTAssertEqual(periods, ["SubscriptionsView.swift"])
        for file in ["SubscriptionManagementView.swift", "Verdict/RenewalVerdictView.swift"] {
            let text = try String(contentsOf: views.appendingPathComponent(file), encoding: .utf8)
            XCTAssertTrue(text.contains("PricePerPeriod(amount: MoneyFormat.string("), file)
        }
    }

    /// What a search finds can be seen while typing. At the accessibility text sizes the field
    /// moves to the top of its page when it is typed in: under a heading and its explanation it
    /// sat just above the keyboard, with the results behind the keys.
    func testASearchFieldMovesToTheTopWhenTypedInAtTheLargestText() throws {
        XCTAssertFalse(SearchField.movesToTheTopWhenTypedIn(largeText: false))
        XCTAssertTrue(SearchField.movesToTheTopWhenTypedIn(largeText: true))

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let controls = try String(contentsOf: sources.appendingPathComponent("DesignSystem/InkControls.swift"), encoding: .utf8)
        XCTAssertTrue(controls.contains("if isTyping, Self.movesToTheTopWhenTypedIn(largeText: typeSize.isAccessibilitySize) { bringToTop?(identifier) }"))
        XCTAssertTrue(controls.contains("page.scrollTo(id, anchor: .top)"))
        // The two pages whose field sits under a heading can be asked to move it.
        let settings = try String(contentsOf: sources.appendingPathComponent("DesignSystem/SettingsParts.swift"), encoding: .utf8)
        XCTAssertTrue(settings.contains("SearchableScroll {"))
        let catalog = try String(contentsOf: sources.appendingPathComponent("Views/SubscriptionBrowserView.swift"), encoding: .utf8)
        XCTAssertTrue(catalog.contains("SearchableScroll {\n                if typeSize.isAccessibilitySize { top }"))
    }

    /// "Pro" sits under a row's words at the accessibility text sizes. At the end of the row,
    /// with the chevron, it left the words a fifth of the width: "Paus", "e", "Plan".
    func testProSitsUnderTheWordsAtTheLargestText() throws {
        XCTAssertFalse(SubscriptionManagementView.proSitsUnderTheWords(largeText: false))
        XCTAssertTrue(SubscriptionManagementView.proSitsUnderTheWords(largeText: true))

        let url = root.appendingPathComponent("Pausely/Views/SubscriptionManagementView.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: url, encoding: .utf8)
        // Drawn in exactly one of the two places.
        XCTAssertTrue(source.contains("if isPro, Self.proSitsUnderTheWords(largeText: typeSize.isAccessibilitySize) {"))
        XCTAssertTrue(source.contains("if isPro, !Self.proSitsUnderTheWords(largeText: typeSize.isAccessibilitySize) { ProPill() }"))
        XCTAssertEqual(source.components(separatedBy: "ProPill()").count - 1, 2)
    }

    /// The way into "Create your account" shows one thing at a time: the age check, then the
    /// form. The form used to put the age check over itself as it opened, and on iPad neither
    /// stayed: "Keep my list" ended back on the total. The screen underneath opens both now.
    func testTheAccountFormOpensAfterTheAgeCheckNotUnderIt() throws {
        XCTAssertEqual(SignUpDoor.first(agePassed: false, capturingTheForm: false), .ageCheck)
        XCTAssertEqual(SignUpDoor.first(agePassed: true, capturingTheForm: false), .form)
        XCTAssertEqual(SignUpDoor.first(agePassed: false, capturingTheForm: true), .form, "a capture of the form itself (debug builds)")
        XCTAssertTrue(SignUpDoor.formFollowsTheAgeCheck(agePassed: true))
        XCTAssertFalse(SignUpDoor.formFollowsTheAgeCheck(agePassed: false), "under age, or the check was closed: no form")

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        // The form opens when the age check has closed, not while it is opening.
        let door = try String(contentsOf: sources.appendingPathComponent("Views/Auth/SignUpDoor.swift"), encoding: .utf8)
        let closed = try XCTUnwrap(door.range(of: ".fullScreenCover(isPresented: $showAgeCheck, onDismiss: {"))
        XCTAssertTrue(door[closed.upperBound...].prefix(200).contains("showForm = true"))
        // The form no longer opens the age check as it appears; it still refuses to create an
        // account without one.
        let forms = try String(contentsOf: sources.appendingPathComponent("Views/Auth/AccountForms.swift"), encoding: .utf8)
        XCTAssertFalse(forms.contains(".onAppear {\n                // Age is confirmed"))
        XCTAssertFalse(forms.contains("if !ageConsent.hasPassedDeviceGate, LaunchFlag"))
        XCTAssertTrue(forms.contains("guard ageConsent.hasPassedDeviceGate else {\n            showAgeGate = true\n            return\n        }"))
        // Every way into the form goes through the door, and the first run opens it from the
        // root, over the total, without changing the screen underneath.
        let app = try String(contentsOf: sources.appendingPathComponent("ContentView.swift"), encoding: .utf8)
        var presentations = 0
        for file in try FileManager.default.subpathsOfDirectory(atPath: sources.path) where file.hasSuffix(".swift") {
            let text = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            presentations += text.components(separatedBy: "SignUpView()").count - 1
        }
        XCTAssertEqual(presentations, 1, "SignUpView is opened in one place, the door")
        XCTAssertEqual(app.components(separatedBy: ".signUpDoor(isOpen:").count - 1, 2, "the root and the welcome screen")
        let keep = try XCTUnwrap(app.range(of: "onKeepList: {\n"))   // not the demo screen's empty one
        let keeping = String(app[keep.upperBound...].prefix(700))
        let signIn = try XCTUnwrap(keeping.range(of: "onSignIn: {"))
        XCTAssertTrue(keeping[..<signIn.lowerBound].contains("signingUp = true"))
        XCTAssertFalse(keeping[..<signIn.lowerBound].contains("showAuth = true"), "the total stays underneath")
    }

    /// Words are not broken inside themselves to make room for what sits beside them. At the
    /// accessibility text sizes a found subscription's words run the width of the row, the cost
    /// of an hour's use goes under the words it belongs to, and "Pro" goes under the name it
    /// marks: beside their neighbours these read "Spoti-fy", "Last charge" over "d Nov 8",
    /// "$6.85" over "an" over "hour", and "Pause" over "Plan".
    func testWordsAreNotBrokenToMakeRoomForTheirNeighbours() throws {
        XCTAssertFalse(FoundRow.wordsHaveTheWholeRow(largeText: false))
        XCTAssertTrue(FoundRow.wordsHaveTheWholeRow(largeText: true))

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let found = try String(contentsOf: sources.appendingPathComponent("Views/Inbox/FoundRow.swift"), encoding: .utf8)
        let wide = try XCTUnwrap(found.range(of: "if Self.wordsHaveTheWholeRow(largeText: typeSize.isAccessibilitySize) {"))
        let narrow = try XCTUnwrap(found.range(of: "} else {", range: wide.upperBound..<found.endIndex))
        let stacked = String(found[wide.upperBound..<narrow.lowerBound])
        // The box and the way to "why" share the first line; the words follow, as wide as the row,
        // with no logo beside them.
        let controls = try XCTUnwrap(stacked.range(of: "whyButton"))
        let words = try XCTUnwrap(stacked.range(of: "nameAndEvidence; price"))
        XCTAssertTrue(controls.upperBound < words.lowerBound)
        XCTAssertTrue(stacked.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        XCTAssertFalse(stacked.contains("ServiceLogoView"))

        // Where the words do sit beside the price (the ordinary sizes), a date in them is not
        // split: "Last charged Nov 10" broke as "Last", "charged Nov", "10" one text size up.
        XCTAssertTrue(found.contains("let day: (Date) -> String = { L10n.whole($0.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))) }"))
        XCTAssertEqual(L10n.whole("Nov 10"), "Nov\u{00A0}10")
        // And the price goes under the words before it squeezes them: at the largest ordinary
        // size it took 78 points of the 204 left between the logo and the chevron, and the words
        // (185 points on a line) were set in what remained, a word to a line.
        XCTAssertEqual(FoundRow.priceShare, 0.35)
        XCTAssertEqual(LineOrStack.arrangement(widths: [185, 78], spacing: 8, in: 204, besideShare: FoundRow.priceShare), .stack)
        XCTAssertEqual(LineOrStack.arrangement(widths: [185, 78], spacing: 8, in: 204, besideShare: 0.5), .labelWraps,
                       "which is how it was laid out before")
        XCTAssertEqual(LineOrStack.arrangement(widths: [150, 70], spacing: 8, in: 228, besideShare: FoundRow.priceShare), .line,
                       "at the default size they share a line as before")
        XCTAssertTrue(found.contains("LineOrStack(spacing: 8, lineSpacing: 4, spread: true, besideShare: Self.priceShare, stacksWideValue: true) {"))
        // The amount and its period start at one edge, wherever the column ends up.
        let price = try XCTUnwrap(found.range(of: "private func priceColumn(_ price: Price) -> some View {"))
        XCTAssertTrue(found[price.upperBound...].prefix(160).contains("VStack(alignment: .leading, spacing: 2) {"))

        let insights = try String(contentsOf: sources.appendingPathComponent("Views/AnalysisView.swift"), encoding: .utf8)
        let usage = try XCTUnwrap(insights.range(of: "private func usageRow("))
        XCTAssertTrue(insights[usage.upperBound...].prefix(900).contains("AdaptiveRow {"))

        let plan = try String(contentsOf: sources.appendingPathComponent("Views/Verdict/PausePlanView.swift"), encoding: .utf8)
        let name = try XCTUnwrap(plan.range(of: "Text(\"Pause Plan\")\n                            .font(.body.weight(.medium))"))
        XCTAssertTrue(plan[..<name.lowerBound].suffix(80).contains("LineOrStack(spacing: 8, lineSpacing: 4) {"))
        // The pill is as wide as it is; the name beside it is not: they share a line only when
        // both fit.
        XCTAssertEqual(LineOrStack.arrangement(widths: [270, 75], spacing: 8, in: 330, besideShare: 0), .stack)
        XCTAssertEqual(LineOrStack.arrangement(widths: [90, 40], spacing: 8, in: 330, besideShare: 0), .line)
    }

    /// In a mailbox's results each row chose by the width of its own price whether the price
    /// sat beside the words or under them, so in German and Arabic "34,99 CA$" went under and
    /// "9,99 CA$" stayed beside, row by row, and the prices formed no column (tours of
    /// 2026-11-16). Every row now has the page's widest price as its column and makes the
    /// same choice.
    func testEveryFoundRowKeepsTheSamePriceColumn() throws {
        let prices = [FoundRow.Price(amount: "34,99 CA$", period: "pro Monat"),
                      FoundRow.Price(amount: "9,99 CA$", period: "pro Monat"),
                      FoundRow.Price(amount: "779,88 CA$", period: "pro Jahr")]
        XCTAssertEqual(FoundRow.widestPrice(among: prices), FoundRow.Price(amount: "779,88 CA$", period: "pro Monat"))
        XCTAssertNil(FoundRow.widestPrice(among: []))

        // What the row has for its words and its price, and the three widths German prices took.
        let room: CGFloat = 228
        let own: [CGFloat] = [84, 70, 96]
        let before = own.map { LineOrStack.arrangement(widths: [190, $0], spacing: 8, in: room, besideShare: FoundRow.priceShare) }
        XCTAssertEqual(before, [.stack, .labelWraps, .stack], "by its own width, each row chose for itself")
        let after = [190, 120, 60].map { (words: CGFloat) in
            LineOrStack.arrangement(widths: [words, 96], spacing: 8, in: room, besideShare: FoundRow.priceShare, stacksWideValue: true)
        }
        XCTAssertEqual(after, [.stack, .stack, .stack], "with one column, every row chooses alike, a short name included")
        // A column that keeps to its share stays beside the words in every row.
        let narrow = [190, 120, 60].map { (words: CGFloat) in
            LineOrStack.arrangement(widths: [words, 68], spacing: 8, in: room, besideShare: FoundRow.priceShare, stacksWideValue: true)
        }
        XCTAssertEqual(narrow, [.labelWraps, .line, .line])

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let row = try String(contentsOf: sources.appendingPathComponent("Views/Inbox/FoundRow.swift"), encoding: .utf8)
        XCTAssertTrue(row.contains("priceColumn(widestPrice).hidden().accessibilityHidden(true)"))
        XCTAssertTrue(row.contains("besideShare: Self.priceShare, stacksWideValue: true) {"))
        let page = try String(contentsOf: sources.appendingPathComponent("Views/InboxImportView.swift"), encoding: .utf8)
        XCTAssertTrue(page.contains("widestPrice: widestPrice,"))
        XCTAssertTrue(page.contains("FoundRow.widestPrice(among: scanner.foundSubscriptions.filter { !$0.priceUnknown }.map {"))
    }

    /// A found subscription that was cancelled is shown, not offered: it has no box, and its
    /// words are words. As a button switched off, iOS dimmed its last charge, "Cancelled" and
    /// "per month" to between 2.6 and 3.2 to 1 (measured on the iPad tour of 2026-11-16).
    func testAFoundSubscriptionThatWasCancelledIsWordsNotADimmedButton() throws {
        XCTAssertTrue(FoundRow.isAChoice(cancelled: false))
        XCTAssertFalse(FoundRow.isAChoice(cancelled: true))

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let found = try String(contentsOf: sources.appendingPathComponent("Views/Inbox/FoundRow.swift"), encoding: .utf8)
        XCTAssertFalse(found.contains(".disabled("), "iOS dims a switched-off control to below what can be read")
        // One rule decides the box (in both layouts), the button, and whether VoiceOver says
        // "selected" or "not selected".
        XCTAssertEqual(found.components(separatedBy: "Self.isAChoice(cancelled: found.isCancelled)").count - 1, 4)
        let choose = try XCTUnwrap(found.range(of: "private func choose("))
        let body = String(found[choose.upperBound...].prefix(700))
        XCTAssertTrue(body.contains("} else {\n            label()\n                .accessibilityElement(children: .ignore)\n                .accessibilityLabel(accessibilitySummary)"),
                      "the cancelled row is its words, read as one sentence, with no button trait")
    }

    /// The app asks first in one way: choices from the place that was tapped, or an alert at
    /// the accessibility text sizes, where iOS drew those choices in a narrow bubble and broke
    /// the words to fit ("Re-move", "Sign out of Pause-ly?").
    func testAskingFirstIsAnAlertAtTheLargestText() throws {
        XCTAssertFalse(Asking.isAnAlert(largeText: false))
        XCTAssertTrue(Asking.isAnAlert(largeText: true))

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        var asked = 0
        for file in try FileManager.default.subpathsOfDirectory(atPath: sources.path) where file.hasSuffix(".swift") {
            let text = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            asked += text.components(separatedBy: ".asksFirst(").count - 1
            if !file.hasPrefix("DesignSystem/") {
                XCTAssertFalse(text.contains(".confirmationDialog("), "\(file) asks in its own way")
            }
        }
        XCTAssertEqual(asked, 5, "sign out, remove (twice), discard changes, end Pause Plan")
        // Both shapes are attached and one is shown, so the screen underneath is not rebuilt
        // when the text size changes.
        let controls = try String(contentsOf: sources.appendingPathComponent("DesignSystem/InkControls.swift"), encoding: .utf8)
        let asking = try XCTUnwrap(controls.range(of: "private struct AsksFirst"))
        let body = String(controls[asking.upperBound...].prefix(1600))
        XCTAssertTrue(body.contains(".confirmationDialog(title, isPresented: asking(asAlert: false)"))
        XCTAssertTrue(body.contains(".alert(title, isPresented: asking(asAlert: true)"))
        XCTAssertFalse(body.contains("if Asking.isAnAlert"))
    }

    /// iOS brings a question's choices up from whatever the question is attached to. Hung on a
    /// whole screen, that was the middle of the page: over "Sign out" itself on the iPhone and
    /// beside the column on iPad (seen on the tours of 11-16). Each question is attached to the
    /// button that asks it, or to the row it is about, on the line after that control's name.
    func testAQuestionComesUpFromTheControlThatAsked() throws {
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let hungOn = [
            "Views/ProfileView.swift": ".accessibilityIdentifier(\"signOutButton\")",
            "Views/SubscriptionManagementView.swift": ".accessibilityIdentifier(\"removeSubscriptionButton\")",
            "Views/Verdict/PausePlanView.swift": ".accessibilityIdentifier(\"endPausePlanButton\")",
            "Views/Subscriptions/SubscriptionEditView.swift": ".accessibilityIdentifier(\"editCancelButton\")",
            // The list's question is about a row, and the swipe action that asks it is gone by
            // the time the answer is given: the row is the place.
            "Views/SubscriptionsView.swift": ".listRowSeparatorTint(Color.line)",
        ]
        var seen: [String] = []
        for file in try FileManager.default.subpathsOfDirectory(atPath: sources.path).sorted() where file.hasSuffix(".swift") {
            guard !file.hasPrefix("DesignSystem/") else { continue }
            let lines = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
                .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            for (index, line) in lines.enumerated() where line.hasPrefix(".asksFirst(") {
                seen.append(file)
                let control = try XCTUnwrap(hungOn[file], "\(file) asks a question this test does not know: say here what it hangs on")
                XCTAssertEqual(lines[index - 1], control, "\(file): the question is not on the control that asks it")
            }
        }
        XCTAssertEqual(seen, hungOn.keys.sorted())

        // The button that asks is as wide as its words where they start a row, so the choices
        // point at the words and not at the middle of an empty row.
        let profile = try String(contentsOf: sources.appendingPathComponent("Views/ProfileView.swift"), encoding: .utf8)
        let signOut = try XCTUnwrap(profile.range(of: "Button { confirmSignOut = true } label: {"))
        let button = String(profile[signOut.upperBound...].prefix(260))
        XCTAssertTrue(button.contains(".tapArea(.leading)"))
        XCTAssertFalse(button.contains("maxWidth: .infinity"))

        // A navigation bar tells its buttons a text size no larger than it draws them at. The
        // edit screen's question is asked from the bar, so it is told the reader's size by the
        // screen: without that it was the narrow bubble again at the largest text (seen
        // 2026-11-16, the evening the question moved onto its button).
        let edit = try String(contentsOf: sources.appendingPathComponent("Views/Subscriptions/SubscriptionEditView.swift"), encoding: .utf8)
        XCTAssertTrue(edit.contains("@Environment(\\.dynamicTypeSize) private var typeSize"))
        XCTAssertTrue(edit.contains(".asksFirst(Text(\"Discard your changes?\"), isPresented: $showDiscardConfirm,\n                               largeText: typeSize.isAccessibilitySize) {"))
        let controls = try String(contentsOf: sources.appendingPathComponent("DesignSystem/InkControls.swift"), encoding: .utf8)
        XCTAssertTrue(controls.contains("Asking.isAnAlert(largeText: largeText ?? typeSize.isAccessibilitySize)"))
    }

    /// The page with inboxes connected and nothing found has a way in for the tour. No search
    /// of a made-up mailbox ends there, and for eleven tours the state named "inbox-add" was a
    /// capture of the results list: "Add another inbox" is not on that page.
    func testTheConnectedInboxPageCanBeOpenedInEachOfItsStates() throws {
        let now = Date()
        let connected = InboxScanner.demoInboxes("connected", now: now)
        XCTAssertEqual(connected.accounts.map(\.address), ["jane.doe@icloud.com", "jane.doe@longer-company-name.example.co.uk"])
        XCTAssertNil(connected.outcome, "not searched yet: nothing to report")
        XCTAssertTrue(connected.accounts.allSatisfy { $0.lastScan == nil })
        XCTAssertTrue(connected.refused.isEmpty)

        let nothing = InboxScanner.demoInboxes("nothing", now: now)
        XCTAssertEqual(nothing.outcome, L10n.string("No subscriptions found"))
        XCTAssertTrue(nothing.refused.isEmpty)
        XCTAssertEqual(nothing.checked, 312)
        XCTAssertEqual(nothing.accounts.map(\.lastScan), [now.addingTimeInterval(-7200), now.addingTimeInterval(-7200)])

        let failed = InboxScanner.demoInboxes("failed", now: now)
        XCTAssertEqual(failed.outcome, L10n.string("The search couldn't be finished."))
        XCTAssertEqual(failed.refused, ["demo-work": L10n.string("Your sign-in expired. Reconnect this inbox.")])
        XCTAssertTrue(failed.accounts.contains { $0.id == "demo-work" }, "the inbox that refused is one of those listed")

        // The tour opens each, and looks for "Add another inbox" on a page that has it.
        let url = root.appendingPathComponent("PauselyUITests/ScreenTourTests.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let tour = try String(contentsOf: url, encoding: .utf8)
        for state in ["connected", "nothing", "failed"] {
            XCTAssertTrue(tour.contains("state(\"inbox-\(state)\", [\"--demo-inbox=\(state)\"])"), state)
        }
        XCTAssertTrue(tour.contains("state(\"inbox-add\", [\"--demo-inbox=nothing\"]) { app in self.tap(app, \"addInboxButton\") }"))
    }

    /// A service under "Popular" is listed again under "All services". The two rows have different
    /// names in the list: with one name, the second row was blank ("All services" on iPad had holes
    /// where Netflix, Disney+ and Hulu belong).
    func testAServiceListedTwiceIsTwoRows() throws {
        let netflix = CatalogEntry("Netflix", .entertainment, nil)
        XCTAssertNotEqual(netflix.popularRowID, netflix.id)
        let all = CatalogData.entries
        XCTAssertFalse(all.isEmpty)
        XCTAssertTrue(Set(all.map(\.popularRowID)).isDisjoint(with: Set(all.map(\.id))))
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "And within one section every service is listed once")

        let url = root.appendingPathComponent("Pausely/Views/SubscriptionBrowserView.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("ForEach(popularEntries, id: \\.popularRowID)"))
        XCTAssertFalse(source.contains("ForEach(popularEntries) {"))
    }

    /// Where the paywall's button stays at the bottom edge, its bar holds the button and the sentence
    /// about the charge and nothing else. The three links were there too, and took three more rows
    /// at the edge whenever they did not fit on one line (German at any size, English one size up).
    func testThePaywallsPinnedBarHoldsOnlyTheButtonAndItsTerms() throws {
        let url = root.appendingPathComponent("Pausely/Views/StoreKitUpgradeView.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: url, encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "private var actionBar: some View {"))
        let end = try XCTUnwrap(source.range(of: "private var linksEndThePage: Bool {"))
        let bar = String(source[start.upperBound..<end.lowerBound])
        XCTAssertEqual(bar.components(separatedBy: "footerLinks(").count - 1, 1)
        let guardLine = try XCTUnwrap(bar.range(of: "if !linksEndThePage {"))
        let links = try XCTUnwrap(bar.range(of: "footerLinks("))
        XCTAssertLessThan(guardLine.lowerBound, links.lowerBound, "The links are in the bar only where the bar follows the content")
        XCTAssertTrue(source.contains("ActionScreen<EmptyView, EmptyView>.pinsActions(at: typeSize, onPad:"))
    }

    /// Parts share a line only when all of them fit on it; one point too many and they stack. No
    /// width at all means the line can be as long as it likes.
    func testPartsShareALineOnlyWhenTheyFit() {
        XCTAssertTrue(LineOrStack.sharesALine(widths: [100, 60], spacing: 12, in: 172))
        XCTAssertFalse(LineOrStack.sharesALine(widths: [100, 60], spacing: 12, in: 171))
        XCTAssertFalse(LineOrStack.sharesALine(widths: [100, 60, 40], spacing: 12, in: 220))
        XCTAssertTrue(LineOrStack.sharesALine(widths: [100, 60, 40], spacing: 12, in: 224))
        XCTAssertTrue(LineOrStack.sharesALine(widths: [100, 60], spacing: 12, in: nil))
        XCTAssertTrue(LineOrStack.sharesALine(widths: [100, 60], spacing: 12, in: .infinity))
        XCTAssertTrue(LineOrStack.sharesALine(widths: [300], spacing: 12, in: 300))
    }

    /// A label and its value: on one line when both fit; a value that takes no more than its share
    /// of the width (an amount) keeps its place and the label wraps beside it; a wider value goes
    /// under the label. The value is never squeezed: side by side, two long halves each broke in
    /// the middle ("Most / goes to" beside "Health / & fitness"), and a price in a list row broke
    /// between its currency and its figure ("IDR" above "8,500,000").
    func testAValueKeepsItsPlaceOrGoesUnderItsLabelAndIsNeverSqueezed() {
        typealias Row = LineOrStack
        // Receipt lines (three fifths of the slip for the value).
        XCTAssertEqual(Row.arrangement(widths: [100, 60], spacing: 20, in: 314, besideShare: 0.6), .line)
        XCTAssertEqual(Row.arrangement(widths: [260, 70], spacing: 20, in: 314, besideShare: 0.6), .labelWraps, "\"Kept since you cancelled\" beside \"$112.93\"")
        XCTAssertEqual(Row.arrangement(widths: [171, 180], spacing: 20, in: 314, besideShare: 0.6), .labelWraps, "\"Back in your pocket\" beside \"About $271.76 a year\"")
        XCTAssertEqual(Row.arrangement(widths: [151, 202], spacing: 20, in: 314, besideShare: 0.6), .stack, "\"Most goes to\" above \"Health & fitness\"")
        XCTAssertEqual(Row.arrangement(widths: [113, 195], spacing: 20, in: 314, besideShare: 0.6), .stack, "\"Each year\" above \"IDR 114,881,880\": the figure is not wrapped beside a short label")
        // List rows (half the row for the price).
        XCTAssertEqual(Row.arrangement(widths: [150, 90], spacing: 8, in: 306, besideShare: 0.5), .line)
        XCTAssertEqual(Row.arrangement(widths: [240, 150], spacing: 8, in: 306, besideShare: 0.5), .labelWraps)
        XCTAssertEqual(Row.arrangement(widths: [240, 175], spacing: 8, in: 306, besideShare: 0.5), .stack, "\"IDR 8,500,000/mo\" one text size up")
        // Parts that are not a label and a value.
        XCTAssertEqual(Row.arrangement(widths: [260, 70], spacing: 20, in: 314, besideShare: 0), .stack)
        XCTAssertEqual(Row.arrangement(widths: [200, 70, 70], spacing: 20, in: 314, besideShare: 0.6), .stack)
        XCTAssertEqual(Row.arrangement(widths: [900, 900], spacing: 20, in: nil, besideShare: 0.6), .line)
    }

    /// No screen chooses between two copies of itself with `ViewThatFits`: Apple's accessibility
    /// audit reports the text in the copy that was not chosen at a larger size as text that cannot
    /// grow (the Profile rows, the subscription's status line and both outcome slips were reported).
    /// `LineOrStack` and a scroll view as tall as the screen do the same work with one copy.
    func testNoScreenIsBuiltTwiceToSeeWhichFits() throws {
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        var offenders: [String] = []
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        for file in files where file.pathExtension == "swift" {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let code = line.components(separatedBy: "//").first ?? ""
                if code.contains("ViewThatFits") { offenders.append("\(file.lastPathComponent):\(index + 1)") }
            }
        }
        XCTAssertEqual(offenders, [])
    }

    /// A screen is drawn again when something it watches changes, so it has to watch everything its
    /// rows are worked out from. What is waiting for a decision comes from the list, the history and
    /// the Pause Plan (a service the plan rotates asks nothing), and a subscription's page says
    /// whether it is in the plan. The list and that page did not watch the plan: after a plan was
    /// started from Insights the list's "Needs a decision" stayed as it was, and on the tour the page
    /// still offered "Pause Plan" with the plan already running.
    func testAScreenWatchesEveryStoreItsRowsAreWorkedOutFrom() throws {
        let views = root.appendingPathComponent("Pausely/Views")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: views.path), "Sources aren't readable from this test run")
        func watches(_ store: String, in source: String) -> Bool {
            source.contains("@ObservedObject private var ") && source.range(of: "@ObservedObject private var \\w+ = \(store)\\.shared", options: .regularExpression) != nil
        }
        var workOutWhatIsWaiting: [String] = []
        let files = FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        for file in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            let name = file.lastPathComponent
            if source.contains("pendingDecisions(") {
                workOutWhatIsWaiting.append(name)
                for store in ["SubscriptionStore", "LifecycleEventLog", "PausePlanStore"] {
                    XCTAssertTrue(watches(store, in: source), "\(name) works out what is waiting without watching \(store)")
                }
                XCTAssertEqual(source.components(separatedBy: "pendingDecisions(").count,
                               source.components(separatedBy: "pendingDecisions(rotating: pausePlanStore.activePlan").count,
                               "\(name) hands in a plan that is not the one it watches")
            }
            // The plan is asked through the store the screen watches, never straight from the shared one.
            XCTAssertNil(source.range(of: "PausePlanStore\\.shared\\.(contains|activePlan|plan)\\b", options: .regularExpression),
                         "\(name) asks the Pause Plan without watching it")
        }
        XCTAssertEqual(workOutWhatIsWaiting.sorted(), ["DashboardView.swift", "SubscriptionsView.swift"])
    }

    /// An amount sits beside its currency in every language. In Arabic the row starts at the right
    /// and the amount was at the far left of its field, a row's width from "US$".
    func testAnAmountSitsAtTheEdgeItsRowStartsFrom() throws {
        XCTAssertEqual(AmountFit.alignment(inRightToLeftRow: false), .leading)
        XCTAssertEqual(AmountFit.alignment(inRightToLeftRow: true), .trailing)

        let url = root.appendingPathComponent("Pausely/DesignSystem/InkControls.swift")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path), "Sources aren't readable from this test run")
        let source = try String(contentsOf: url, encoding: .utf8)
        // The two go together: trailing means "right" only inside a left-to-right field.
        XCTAssertTrue(source.contains(".multilineTextAlignment(AmountFit.alignment(inRightToLeftRow: direction == .rightToLeft))\n            .environment(\\.layoutDirection, .leftToRight)"))
    }

    /// An amount field shows all of the amount. A short one keeps the size the form gives it; a long
    /// one (a yearly price in rupiah at the largest text size) is drawn in the largest size that
    /// still fits the field, and never below the smallest.
    func testALongAmountIsDrawnSmallerSoAllOfItShows() {
        XCTAssertEqual(AmountFit.size(for: "9.99", base: 52, width: 290), 52)
        XCTAssertEqual(AmountFit.size(for: "", base: 52, width: 290), 52)
        XCTAssertEqual(AmountFit.size(for: "9990000", base: 52, width: 0), 52, "Not measured yet: the form's size")

        let fitted = AmountFit.size(for: "9990000", base: 92, width: 290)
        XCTAssertLessThan(fitted, 92)
        XCTAssertGreaterThan(fitted, AmountFit.smallest)
        XCTAssertLessThanOrEqual(AmountFit.width(of: "9990000", size: fitted), 290)
        XCTAssertGreaterThan(AmountFit.width(of: "9990000", size: fitted + 2), 290, "The largest size that fits, not merely a small one")

        XCTAssertEqual(AmountFit.size(for: String(repeating: "9", count: 60), base: 92, width: 290), AmountFit.smallest)
    }

    /// A field is named above its box, never inside it: a name written inside is gone at the first
    /// letter typed, and iOS draws it smaller (not larger) at the largest text sizes. Three boxes
    /// keep an example inside, because it is what is used when the box is left empty: the mail
    /// server, its port, and zero hours.
    func testAFieldIsNamedAboveItsBoxNotInsideIt() throws {
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        var inside: [String] = []
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        for file in files where file.pathExtension == "swift" {
            for line in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n") {
                guard let start = line.range(of: "InkTextField(placeholder: "), let end = line.range(of: ", text:") else { continue }
                let placeholder = String(line[start.upperBound..<end.lowerBound])
                if placeholder != "\"\"" { inside.append(placeholder) }
            }
        }
        XCTAssertEqual(inside.sorted(), ["\"993\"", "L10n.number(0)", "suggestedHost ?? \"imap.example.com\""])
    }

    /// The short sheet that asks for a price is as tall as its form, whatever the language and
    /// text size make that: no taller (344 points left a band of nothing under Save) and no shorter
    /// (300 cut the question's first line).
    func testThePriceSheetIsAsTallAsItsForm() {
        XCTAssertEqual(PriceSheet.sheetHeight(forForm: 0), 280, "Not measured yet")
        XCTAssertEqual(PriceSheet.sheetHeight(forForm: 277), 277)
        XCTAssertEqual(PriceSheet.sheetHeight(forForm: 412.3), 413)
    }

    /// Text is as large as the person asked for. One place holds it lower: the six code boxes, where
    /// six digits share a row. A notice held to a smaller size (it was, for a day) cannot be read by
    /// the people who chose the largest.
    func testOnlyTheCodeBoxesHoldTheirTextSize() throws {
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        var holders: [String] = []
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        for file in files where file.pathExtension == "swift" {
            if try String(contentsOf: file, encoding: .utf8).contains(".dynamicTypeSize(") { holders.append(file.lastPathComponent) }
        }
        XCTAssertEqual(holders, ["EmailCodeViews.swift"])
    }

    /// What the three tabs show where the list would be. A fetch that failed with nothing on the
    /// phone is not an empty list: it said "Nothing on your list yet." to people who have one. And
    /// before the list has arrived no monthly total is drawn ("$0.00" was, until it did).
    func testAListThatCouldNotLoadIsNotCalledEmpty() {
        typealias Store = SubscriptionStore
        XCTAssertEqual(Store.listState(isEmpty: true, isLoading: true, lastFetchFailed: false), .loading)
        XCTAssertEqual(Store.listState(isEmpty: true, isLoading: true, lastFetchFailed: true), .loading, "trying again")
        XCTAssertEqual(Store.listState(isEmpty: true, isLoading: false, lastFetchFailed: true), .couldNotLoad)
        XCTAssertEqual(Store.listState(isEmpty: true, isLoading: false, lastFetchFailed: false), .empty)
        XCTAssertEqual(Store.listState(isEmpty: false, isLoading: true, lastFetchFailed: true), .shown,
                       "whatever is on the phone is shown while it refreshes")

        XCTAssertFalse(Store.ListState.loading.totalIsKnown)
        XCTAssertFalse(Store.ListState.couldNotLoad.totalIsKnown)
        XCTAssertTrue(Store.ListState.empty.totalIsKnown, "an empty list is $0, truly")
        XCTAssertTrue(Store.ListState.shown.totalIsKnown)
    }

    /// The catalog offers a category only when it holds a service, so choosing one never lands on
    /// an empty page that reads "nothing matches" with nothing typed.
    func testTheCatalogOffersOnlyCategoriesThatHoldAService() {
        let two = [CatalogEntry("Netflix", .entertainment, nil), CatalogEntry("Spotify", .music, nil)]
        XCTAssertEqual(Set(SubscriptionBrowserView.offeredCategories(in: two)), [.entertainment, .music])
        XCTAssertEqual(SubscriptionBrowserView.offeredCategories(in: []), [])
        // In the usual order, whatever order the catalog is in.
        let order = SubscriptionCategory.allCases.filter { [.entertainment, .music].contains($0) }
        XCTAssertEqual(SubscriptionBrowserView.offeredCategories(in: two.reversed()), order)
    }

    /// A picture made to be shared is drawn outside the app's screens, so it does not inherit their
    /// language or direction: each one asks for them. An Arabic year slip came out left to right.
    func testASharedPictureIsDrawnInTheAppsLanguage() throws {
        let views = root.appendingPathComponent("Pausely/Views")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: views.path), "Sources aren't readable from this test run")
        var pictures = 0
        let files = FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        for file in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for range in source.ranges(of: "ImageRenderer(content:") {
                pictures += 1
                // The function that makes the picture: from its `static func` to the renderer.
                let before = source[..<range.lowerBound]
                let start = before.range(of: "static func", options: .backwards)?.lowerBound ?? before.startIndex
                let end = source.index(range.upperBound, offsetBy: 200, limitedBy: source.endIndex) ?? source.endIndex
                XCTAssertTrue(source[start..<end].contains(".inTheAppsLanguage()"), file.lastPathComponent)
            }
        }
        XCTAssertEqual(pictures, 2, "the year slip and the Savings Receipt")
    }

    /// "Rate Pausely" opens the review form on Pausely's App Store page. It used to ask iOS for its
    /// rating prompt, which iOS shows a few times a year at most: a row that often did nothing.
    func testRatePauselyOpensTheReviewForm() throws {
        let url = try XCTUnwrap(URL(string: AppConfig.writeReviewURL))
        XCTAssertEqual(url.host, "apps.apple.com")
        XCTAssertEqual(url.path, "/app/id6759973158")
        XCTAssertEqual(url.query, "action=write-review")
        let help = try String(contentsOf: root.appendingPathComponent("Pausely/Views/Settings/HelpSupportView.swift"), encoding: .utf8)
        XCTAssertTrue(help.contains("AppConfig.writeReviewURL"))
        XCTAssertFalse(help.contains("requestReview"))
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

    /// What a field shows before anything is typed is drawn by `Hint`, in a colour that can be
    /// read. Left to the system it was 2.5 to 1 on ink (measured from every empty field in the
    /// English tour of 2026-11-16: search, the amount, the service name, the minutes).
    func testEveryFieldsHintIsDrawnInTheHintColour() throws {
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let controls = try String(contentsOf: sources.appendingPathComponent("DesignSystem/InkControls.swift"), encoding: .utf8)
        let hint = try XCTUnwrap(controls.range(of: "enum Hint {"))
        let hintEnd = try XCTUnwrap(controls.range(of: "\n}\n", range: hint.upperBound..<controls.endIndex))
        XCTAssertTrue(controls[hint.upperBound..<hintEnd.lowerBound].contains("Text(verbatim: words).foregroundStyle(Color.inkTextFaint)"))

        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        var fields = 0
        var unhinted: [String] = []
        for file in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for opening in ["TextField(", "SecureField("] {
                var from = text.startIndex
                while let found = text.range(of: opening, range: from..<text.endIndex) {
                    from = found.upperBound
                    // Not `InkTextField(`, which is the app's own and hands its hint on.
                    if found.lowerBound > text.startIndex, text[text.index(before: found.lowerBound)].isLetter { continue }
                    // The call's own arguments, to its closing bracket.
                    var depth = 1
                    var end = found.upperBound
                    while end < text.endIndex, depth > 0 {
                        if text[end] == "(" { depth += 1 } else if text[end] == ")" { depth -= 1 }
                        end = text.index(after: end)
                    }
                    let arguments = String(text[found.upperBound..<end])
                    fields += 1
                    // A hint is made by `Hint`. A field with none starts with an empty title and has no prompt.
                    let hinted = arguments.contains("Hint.text(")
                    let bare = arguments.hasPrefix("\"\", text:") && !arguments.contains("prompt:")
                    if !hinted && !bare { unhinted.append("\(file.lastPathComponent): \(opening)\(arguments.prefix(60))") }
                }
            }
        }
        XCTAssertEqual(unhinted, [])
        XCTAssertGreaterThanOrEqual(fields, 10, "the design system's two, search, the three amounts, the two names, the first run's price and the code")
    }

    /// A field's edge is the field edge colour, and the text colour while it is typed in: the
    /// design system's field and the six boxes of a code. Neither is drawn with a hairline.
    func testAFieldsEdgeCanBeSeen() throws {
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let controls = try String(contentsOf: sources.appendingPathComponent("DesignSystem/InkControls.swift"), encoding: .utf8)
        let field = try XCTUnwrap(controls.range(of: "struct InkTextField: View {"))
        let fieldEnd = try XCTUnwrap(controls.range(of: "\n}\n", range: field.upperBound..<controls.endIndex))
        let fieldBody = String(controls[field.upperBound..<fieldEnd.lowerBound])
        XCTAssertTrue(fieldBody.contains(".stroke(isFocused ? Color.inkText : Color.fieldEdge, lineWidth: isFocused ? 1.5 : 1)"))
        XCTAssertFalse(fieldBody.contains("Color.line"))

        let code = try String(contentsOf: sources.appendingPathComponent("Views/Auth/EmailCodeViews.swift"), encoding: .utf8)
        XCTAssertTrue(code.contains(".stroke(isNext ? Color.inkText : Color.fieldEdge, lineWidth: isNext ? 1.5 : 1)"))
        XCTAssertFalse(code.contains("Color.line"))

        let palette = try String(contentsOf: sources.appendingPathComponent("DesignSystem/InkPaper.swift"), encoding: .utf8)
        XCTAssertTrue(palette.contains("static let fieldEdge = Color(hex: Palette.fieldEdge)"))
    }

    /// The catalog's plan sheet with "I'm on a free trial" on. The button is off until the trial's
    /// last day is set, and the sheet says so: before, the button went dim and nothing said why.
    /// (Nobody had seen it: the tour's capture of this state was of the switch still off.)
    func testThePlanSheetSaysWhyItsButtonIsOffWhileATrialHasNoEndDay() throws {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(CatalogAddSheet.needsTrialDay(onTrial: true, trialEnds: nil))
        XCTAssertFalse(CatalogAddSheet.needsTrialDay(onTrial: true, trialEnds: day))
        XCTAssertFalse(CatalogAddSheet.needsTrialDay(onTrial: false, trialEnds: nil))
        // The button follows the same rule, and still needs a price.
        XCTAssertFalse(CatalogAddSheet.canAdd(amount: 18, onTrial: true, trialEnds: nil))
        XCTAssertTrue(CatalogAddSheet.canAdd(amount: 18, onTrial: true, trialEnds: day))
        XCTAssertTrue(CatalogAddSheet.canAdd(amount: 18, onTrial: false, trialEnds: nil))
        XCTAssertFalse(CatalogAddSheet.canAdd(amount: nil, onTrial: false, trialEnds: nil))
        XCTAssertFalse(CatalogAddSheet.canAdd(amount: 0, onTrial: true, trialEnds: day))

        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let sheet = try String(contentsOf: sources.appendingPathComponent("Views/CatalogAddSheet.swift"), encoding: .utf8)
        let shown = try XCTUnwrap(sheet.range(of: "if Self.needsTrialDay(onTrial: hasFreeTrial, trialEnds: trialEndsAt) {"))
        let line = try XCTUnwrap(sheet.range(of: #"Text("Add the day the trial ends, so Pausely can ask you before it charges.")"#, range: shown.upperBound..<sheet.endIndex))
        XCTAssertLessThan(sheet.distance(from: shown.upperBound, to: line.lowerBound), 80, "the sentence is what that condition shows")
        XCTAssertTrue(sheet.contains(".disabled(!canAdd)"))
    }

    /// A hint that is a figure is in the reader's own digits, like the figures around it: the
    /// hours sheet showed a Latin "0" in Arabic (seen 2026-11-16).
    func testAFigureUsedAsAHintIsInTheReadersDigits() throws {
        XCTAssertEqual(L10n.number(0, locale: Locale(identifier: "ar_SA")), "٠")
        XCTAssertEqual(L10n.number(0, locale: Locale(identifier: "en_CA")), "0")
        let sources = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path), "Sources aren't readable from this test run")
        let hours = try String(contentsOf: sources.appendingPathComponent("Views/SubscriptionManagement/UsageInputSheet.swift"), encoding: .utf8)
        XCTAssertTrue(hours.contains("InkTextField(placeholder: L10n.number(0), text: text, keyboardType: .numberPad)"))
        XCTAssertFalse(hours.contains(#"placeholder: "0""#))
    }
}
