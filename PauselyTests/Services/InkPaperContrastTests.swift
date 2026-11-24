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

    /// A field's hint. The system's placeholder grey, as it was drawn in every empty field of the
    /// English tour of 2026-11-16, is not readable; the colour `Hint` draws is, on each surface a
    /// field sits on.
    func testAFieldsHintCanBeReadWhereTheSystemsGreyCouldNot() {
        XCTAssertLessThan(Contrast.ratio("#55565B", Palette.inkRaised), 3, "the system's grey on a raised tile, as captured")
        XCTAssertLessThan(Contrast.ratio("#4D4E52", Palette.ink), 3, "the system's grey on ink, as captured")
        for surface in [Palette.ink, Palette.inkRaised, Palette.inkLifted] {
            XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.textFaint, surface), 4.5, "a hint on \(surface)")
        }
        // And it is still plainly not what the person typed.
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.text, Palette.inkRaised) / Contrast.ratio(Palette.textFaint, Palette.inkRaised), 2)
    }

    /// An empty field is shown by its edge and nothing else, so the edge has to be seen (WCAG
    /// 1.4.11: 3 to 1 against what is beside it), and the field being typed in has to be told
    /// from the others. It was a hairline: white at 8% on a raised tile, about 1.3 to 1.
    func testAnEmptyFieldCanBeFoundAndTheOneBeingTypedInToldApart() {
        for surface in [Palette.ink, Palette.inkRaised, Palette.inkLifted] {
            XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.fieldEdge, surface), 3, "a field's edge on \(surface)")
        }
        // The hairline it replaces, as it was drawn on a raised tile over ink.
        XCTAssertLessThan(Contrast.ratio("#282A2D", Palette.ink), 1.5)
        // Typed in: the text colour, three times brighter again.
        XCTAssertGreaterThanOrEqual(Contrast.ratio(Palette.text, Palette.fieldEdge), 3)
        // And an edge stays quieter than any words on the screen.
        XCTAssertLessThan(Contrast.ratio(Palette.fieldEdge, Palette.ink), Contrast.ratio(Palette.textFaint, Palette.ink))
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

/// WCAG 2 contrast, worked out here because only these tests need it.
private enum Contrast {
    /// WCAG 2 contrast ratio between two "#RRGGBB" colours.
    static func ratio(_ a: String, _ b: String) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func luminance(_ hex: String) -> Double {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        let channels = [value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF].map { Double($0) / 255 }
        let linear = channels.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
