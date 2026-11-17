import SwiftUI
import UIKit

// MARK: - How words and values share a line
//
// The layout parts of Ink and Paper: a figure that is never broken, a mark beside or above its
// words, a label with its value, facts on one line or one to a line, and the rule that decides
// whether parts sit side by side or stack. Colours, type and paper are in `InkPaper.swift`.

/// A word or a figure is never broken in the middle. Where the longest unbreakable part of a line
/// is wider than the line, the line is drawn smaller until that part fits.
enum WordFit {
    /// Below half its size the text is no longer read at the size the person asked for; it stays
    /// there and breaks as any text does.
    static let smallest: CGFloat = 0.5

    /// The widest part the line cannot break: parts end at a space, a line end or a zero-width
    /// space. A no-break space joins what is on either side of it.
    static func widestWord(of text: String, in font: UIFont) -> CGFloat {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\u{200B}" })
            .map { ceil((String($0) as NSString).size(withAttributes: [.font: font]).width) }
            .max() ?? 0
    }

    /// How much smaller the text is drawn so that its widest part fits `width`: 1 when it does.
    static func scale(for text: String, in font: UIFont, width: CGFloat) -> CGFloat {
        let widest = widestWord(of: text, in: font)
        guard width > 0, widest > width else { return 1 }
        return max(smallest, (width / widest * 100).rounded(.down) / 100)
    }

    /// The face a text style is drawn in at a text size, for measuring.
    static func font(_ style: UIFont.TextStyle, weight: UIFont.Weight, monospaced: Bool, at size: DynamicTypeSize) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        let points = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits).pointSize
        return monospaced ? .monospacedSystemFont(ofSize: points, weight: weight) : .systemFont(ofSize: points, weight: weight)
    }
}

private struct WholeWords: ViewModifier {
    let text: String
    let font: Font
    let style: UIFont.TextStyle
    let weight: UIFont.Weight
    let monospaced: Bool
    @State private var width: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        let measured = WordFit.font(style, weight: weight, monospaced: monospaced, at: typeSize)
        let scale = WordFit.scale(for: text, in: measured, width: width)
        content
            .font(scale < 1 ? Font(measured.withSize((measured.pointSize * scale).rounded(.down))) : font)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

extension View {
    /// The font of a line that holds a figure: `font`, or smaller where the longest unbreakable
    /// part of `text` would not fit the line (`WordFit`). `style`, `weight` and `monospaced`
    /// describe the same face to UIKit, which is what can measure it. Takes the whole width.
    func wholeWords(_ text: String, font: Font, measuredIn style: UIFont.TextStyle,
                    weight: UIFont.Weight = .regular, monospaced: Bool = false) -> some View {
        modifier(WholeWords(text: text, font: font, style: style, weight: weight, monospaced: monospaced))
    }
}

/// Where a mark (a state's symbol, a service's logo) sits against the words it marks.
enum MarkPlacement {
    /// Above them at the accessibility text sizes, so the words have the whole line: beside a
    /// logo "IDR 102,000,000 a year" lost its last digit to the next line, and beside a state's
    /// mark every line of an explanation was a fifth shorter.
    static func sitsAbove(largeText: Bool) -> Bool { largeText }
}

/// A mark and the words it marks: side by side, or the mark above (`MarkPlacement`).
struct MarkedWords<Mark: View, Words: View>: View {
    var alignment: VerticalAlignment = .firstTextBaseline
    var spacing: CGFloat = 10
    @ViewBuilder var mark: Mark
    @ViewBuilder var words: Words
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if MarkPlacement.sitsAbove(largeText: typeSize.isAccessibilitySize) {
            VStack(alignment: .leading, spacing: 8) { mark; words }
        } else {
            HStack(alignment: alignment, spacing: spacing) { mark; words }
        }
    }
}

/// A label on the leading side and a value or control on the trailing side. At accessibility text
/// sizes the two stack, so neither is squeezed into breaking mid-word.
struct AdaptiveRow<Label: View, Value: View>: View {
    /// Two texts share a baseline. A control (a date, a switch, a menu) has none: beside a label it
    /// is centred, or the label sits at the top of the row and the control hangs below it.
    var alignment: VerticalAlignment = .firstTextBaseline
    @ViewBuilder var label: Label
    @ViewBuilder var value: Value
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) { label; value }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: alignment, spacing: 12) {
                label
                Spacer(minLength: 12)
                value
            }
        }
    }
}

/// A line of facts joined by " · " ("Nov 24 · In 12 days"). At the accessibility text sizes each
/// fact has its own line (`L10n.facts`).
struct Facts: View {
    private let line: String
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ line: String) { self.line = line }

    var body: some View {
        Text(verbatim: L10n.facts(line, oneToALine: typeSize.isAccessibilitySize))
    }
}

/// A name and its value: side by side, or one above the other at accessibility text sizes, where
/// two columns break words in the middle and split a price across lines.
struct SideBySide<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var alignment: VerticalAlignment = .firstTextBaseline
    var spacing: CGFloat = 8
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                leading
                trailing
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: alignment) {
                leading
                Spacer(minLength: spacing)
                trailing
            }
        }
    }
}

/// Its parts on one line when they fit there, and one above the other when they don't: a long
/// value at any text size, any value at a large one. It is one layout, so each part is the same
/// view at every size. `ViewThatFits` draws a second copy instead, and Apple's accessibility audit
/// then reports that the text in the first copy cannot grow.
///
/// A label and its value have a third arrangement, between those: a value that takes no more
/// than its share of the width (an amount) keeps its place at the far end and a long label wraps
/// beside it, as on a printed receipt. A wider value goes under its label. The value itself is
/// never squeezed: side by side, two long halves each broke in the middle ("Most / goes to"
/// beside "Health / & fitness"), and a price broke between its currency and its figure
/// ("IDR" above "8,500,000").
struct LineOrStack: SwiftUI.Layout {
    /// Between parts that share a line.
    var spacing: CGFloat = 8
    /// Between parts that are stacked.
    var lineSpacing: CGFloat = 4
    /// The whole width is taken, and on a shared line the last part sits at its far end.
    var spread = false
    /// Where stacked parts sit across the width: at the leading edge, or in the middle.
    var centred = false
    /// How parts that share a line sit against each other.
    var alignment: VerticalAlignment = .center
    /// For a label and its value: the share of the width the value may take and still keep its
    /// place at the far end while the label wraps beside it. Zero means the two stack instead.
    var besideShare: CGFloat = 0
    /// A value wider than its share goes under its label even where the two would fit on a line.
    /// For rows of a list that are given one value column (the widest value's): each row then
    /// makes the same choice, and the values form one column or none.
    var stacksWideValue = false

    enum Arrangement: Equatable { case line, labelWraps, stack }

    /// Whether parts of these widths share a line of this width. No width at all means "as wide as
    /// you like", which is a line.
    static func sharesALine(widths: [CGFloat], spacing: CGFloat, in available: CGFloat?) -> Bool {
        guard let available, available.isFinite else { return true }
        let needed = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1))
        return needed <= available + 0.5
    }

    /// How parts of these widths are arranged in this width.
    static func arrangement(widths: [CGFloat], spacing: CGFloat, in available: CGFloat?, besideShare: CGFloat,
                            stacksWideValue: Bool = false) -> Arrangement {
        let valueIsWide = { (available: CGFloat) in widths.count == 2 && besideShare > 0 && widths[1] > available * besideShare }
        if stacksWideValue, let available, available.isFinite, valueIsWide(available) { return .stack }
        if sharesALine(widths: widths, spacing: spacing, in: available) { return .line }
        guard let available, widths.count == 2, besideShare > 0, !valueIsWide(available) else { return .stack }
        return .labelWraps
    }

    private struct Plan {
        var arrangement: Arrangement
        var proposals: [ProposedViewSize]
        var sizes: [CGSize]
        /// How far down each part starts, when parts share a line.
        var tops: [CGFloat]
        var size: CGSize
    }

    private func plan(_ proposal: ProposedViewSize, _ subviews: Subviews) -> Plan {
        let natural = subviews.map { $0.sizeThatFits(.unspecified) }
        let available = proposal.width
        let arrangement = Self.arrangement(widths: natural.map(\.width), spacing: spacing, in: available, besideShare: besideShare,
                                           stacksWideValue: stacksWideValue)
        switch arrangement {
        case .line, .labelWraps:
            var proposals = natural.map { ProposedViewSize($0) }
            var sizes = natural
            if arrangement == .labelWraps, let available {
                // The value keeps its width; the label has what is left and wraps in it.
                proposals[0] = ProposedViewSize(width: max(0, available - spacing - natural[1].width), height: nil)
                sizes[0] = subviews[0].sizeThatFits(proposals[0])
            }
            let guides = subviews.indices.map { subviews[$0].dimensions(in: proposals[$0])[alignment] }
            let lowest = guides.max() ?? 0
            let tops = guides.map { lowest - $0 }
            let height = zip(tops, sizes).map { $0 + $1.height }.max() ?? 0
            let width = sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(0, sizes.count - 1))
            let filled = (spread || arrangement != .line) && available?.isFinite == true ? available ?? width : width
            return Plan(arrangement: arrangement, proposals: proposals, sizes: sizes, tops: tops,
                        size: CGSize(width: filled, height: height))
        case .stack:
            let proposals = subviews.map { _ in ProposedViewSize(width: available, height: nil) }
            let wrapped = subviews.indices.map { subviews[$0].sizeThatFits(proposals[$0]) }
            let height = wrapped.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, wrapped.count - 1))
            let widest = wrapped.map(\.width).max() ?? 0
            return Plan(arrangement: .stack, proposals: proposals, sizes: wrapped, tops: [],
                        size: CGSize(width: spread ? max(widest, available ?? widest) : widest, height: height))
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        plan(proposal, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = plan(ProposedViewSize(width: bounds.width, height: nil), subviews)
        switch plan.arrangement {
        case .line, .labelWraps:
            var x = bounds.minX
            for (index, subview) in subviews.enumerated() {
                let size = plan.sizes[index]
                let last = index == subviews.count - 1 && subviews.count > 1
                if last, spread || plan.arrangement != .line { x = max(x, bounds.maxX - size.width) }
                subview.place(at: CGPoint(x: x, y: bounds.minY + plan.tops[index]), anchor: .topLeading, proposal: plan.proposals[index])
                x += size.width + spacing
            }
        case .stack:
            var y = bounds.minY
            for (index, subview) in subviews.enumerated() {
                let size = plan.sizes[index]
                subview.place(at: CGPoint(x: centred ? bounds.midX : bounds.minX, y: y),
                              anchor: centred ? .top : .topLeading,
                              proposal: ProposedViewSize(width: bounds.width, height: size.height))
                y += size.height + lineSpacing
            }
        }
    }
}

/// A price and how often it is charged, as one text: "$15.99/mo", the amount in its own face and
/// the period smaller beside it. Where the line is too narrow for both (millions of rupiah at the
/// largest text size) the two are drawn smaller together, and at the accessibility sizes the
/// figure may go under its currency first, as Home's total does. As two texts on a line only the
/// amount gave way: on a subscription's page and on the verdict "IDR 8,500,000" stood smaller
/// than its own "/mo" (seen 2026-11-17).
struct PricePerPeriod: View {
    let amount: String
    let frequency: BillingFrequency
    let amountFont: Font
    let periodFont: Font
    let periodColor: Color

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text(Self.line(amount: amount, period: frequency.shortDisplay, amountFont: amountFont,
                       periodFont: periodFont, periodColor: periodColor))
            .lineLimit(Self.lines(largeText: typeSize.isAccessibilitySize))
            .minimumScaleFactor(Self.smallest)
            .accessibilityLabel(Text(verbatim: frequency.priced(amount)))
    }

    /// The line is drawn down to half its size before any of it would be cut.
    static let smallest: CGFloat = 0.5

    nonisolated static func lines(largeText: Bool) -> Int { largeText ? 2 : 1 }

    /// The period as it follows its amount: after a narrow space no line breaks at, and with
    /// nothing a line can break at after its slash ("8,500,000/" above "mo").
    nonisolated static func joined(_ period: String) -> String {
        "\u{202F}" + period.replacingOccurrences(of: "/", with: "/\u{2060}")
    }

    static func line(amount: String, period: String, amountFont: Font, periodFont: Font, periodColor: Color) -> AttributedString {
        var price = AttributedString(amount)
        price.font = amountFont
        var per = AttributedString(joined(period))
        per.font = periodFont
        per.foregroundColor = periodColor
        return price + per
    }
}
