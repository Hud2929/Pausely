import XCTest
@testable import Pausely

/// Every text/background pair in the Ink and Paper system must be readable (WCAG AA: 4.5 for text,
/// 3 for symbols and large numbers). A palette change that breaks one fails here.
final class InkPaperContrastTests: XCTestCase {

    func testContrastMathMatchesKnownValues() {
        XCTAssertEqual(Contrast.ratio("#000000", "#FFFFFF"), 21, accuracy: 0.01)
        XCTAssertEqual(Contrast.ratio("#FFFFFF", "#FFFFFF"), 1, accuracy: 0.001)
        // WebAIM's reference pair.
        XCTAssertEqual(Contrast.ratio("#0000FF", "#FFFFFF"), 8.59, accuracy: 0.01)
    }

    func testTextOnInkMeetsAA() {
        for background in [Palette.ink, Palette.inkRaised, Palette.inkLifted] {
            for text in [Palette.text, Palette.textMuted, Palette.textFaint,
                         Palette.kept, Palette.decide, Palette.due, Palette.paused] {
                XCTAssertGreaterThanOrEqual(Contrast.ratio(text, background), 4.5, "\(text) on \(background)")
            }
        }
    }

    func testTextOnPaperMeetsAA() {
        for background in [Palette.paper, Palette.paperShade] {
            for text in [Palette.paperInk, Palette.paperMuted, Palette.paperKept, Palette.paperDue] {
                XCTAssertGreaterThanOrEqual(Contrast.ratio(text, background), 4.5, "\(text) on \(background)")
            }
        }
    }

    func testButtonLabelsMeetAA() {
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.paperInk, Palette.paper), 4.5)   // main
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.ink, Palette.kept), 4.5)         // keep
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.ink, Palette.due), 4.5)          // destructive
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.paper, Palette.paperInk), 4.5)   // on paper
    }

    func testStateMarksAreVisibleOnInkAndPaperIsDistinctFromInk() {
        for state in [Palette.kept, Palette.decide, Palette.due, Palette.paused] {
            XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.ink, state), 3, "symbol on \(state)")
        }
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.paper, Palette.ink), 12)
    }

    func testMintIsNotUsedForTextOnPaper() {
        // The reason `paperKept` exists: mint on paper is unreadable.
        XCTAssertLessThan(Contrast.ratio(Palette.kept, Palette.paper), 3)
    }

    func testEveryStateHasItsOwnSymbol() {
        let symbols = [MoneyState.kept, .decide, .due, .paused].map(\.symbol)
        XCTAssertEqual(Set(symbols).count, 4)
    }
}
