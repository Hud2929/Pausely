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
                   name != "FirstRunView.swift", name != "InboxImportView.swift" {
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
        XCTAssertEqual(inside.sorted(), ["\"0\"", "\"993\"", "suggestedHost ?? \"imap.example.com\""])
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
}
