import SwiftUI
import UIKit

// MARK: - Ink and Paper
//
// The app is ink: near-black, quiet, typographic. Paper appears only where money is decided or
// proven (the verdict slip, the Savings Receipt, the share card). Mint means money kept and
// nothing else. Questions are set in a serif; proof is set in monospace.
// See REDESIGN_PLAN.md, section 3.

extension Color {
    /// The background of the app.
    static let ink = Color(hex: Palette.ink)
    /// The few remaining cards and grouped rows.
    static let inkRaised = Color(hex: Palette.inkRaised)
    /// Controls that sit on a raised surface.
    static let inkLifted = Color(hex: Palette.inkLifted)
    /// Hairlines, in place of card borders.
    static let line = Color.white.opacity(0.08)
    /// The unfilled part of a bar or a time line, and the faint disc behind a small symbol.
    static let track = Color.white.opacity(0.12)
    /// The edge of a control that has no fill of its own: a quiet button, a chip, a round "+".
    static let outline = Color.white.opacity(0.22)
    /// The edge of the field being typed in.
    static let outlineFocused = Color.white.opacity(0.45)

    /// Slip, receipt and share card. Warm, not white, so it doesn't glare on a dark screen.
    static let paper = Color(hex: Palette.paper)
    /// Folds, perforations and pressed states on paper.
    static let paperShade = Color(hex: Palette.paperShade)
    static let paperInk = Color(hex: Palette.paperInk)
    static let paperMuted = Color(hex: Palette.paperMuted)
    /// Money kept, printed on paper (mint is unreadable on paper).
    static let paperKept = Color(hex: Palette.paperKept)
    static let paperDue = Color(hex: Palette.paperDue)

    static let inkText = Color(hex: Palette.text)
    static let inkTextMuted = Color(hex: Palette.textMuted)
    static let inkTextFaint = Color(hex: Palette.textFaint)

    /// Money kept. Nothing else is mint.
    static let kept = Color(hex: Palette.kept)
    /// A decision is waiting.
    static let decide = Color(hex: Palette.decide)
    /// Charged today or tomorrow.
    static let due = Color(hex: Palette.due)
    static let paused = Color(hex: Palette.paused)
}

// MARK: - State (colour is never the only signal)

/// What a subscription row is telling the reader. Each state has a colour and a symbol.
enum MoneyState {
    case kept, decide, due, paused

    var color: Color {
        switch self {
        case .kept: .kept
        case .decide: .decide
        case .due: .due
        case .paused: .paused
        }
    }

    var symbol: String {
        switch self {
        case .kept: "checkmark"
        case .decide: "questionmark"
        case .due: "exclamationmark"
        case .paused: "pause.fill"
        }
    }
}

// MARK: - Type

extension Font {
    /// Pausely asking out loud, and the one number a screen is about. New York; Arabic and
    /// Japanese fall back to the system face.
    static func question(_ style: Font.TextStyle = .title, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    /// The one number a screen is about, larger than any text style goes. Hand it a size that is
    /// already scaled (`@ScaledMetric(relativeTo: .largeTitle)`), so it grows with the reader's text
    /// size; a size written as a bare number would not.
    static func total(_ scaledSize: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: scaledSize, weight: weight, design: .serif)
    }

    /// Proof: receipt lines, amounts in a column, dates on a slip.
    static func proof(_ style: Font.TextStyle = .subheadline, weight: Font.Weight = .regular) -> Font {
        // A monospaced face pulls the letters of a joined script apart, so Arabic (and other
        // joined scripts) keep the system face with fixed-width digits.
        if joinedScripts.contains(L10n.locale.language.languageCode?.identifier ?? "") {
            return .system(style, design: .default, weight: weight).monospacedDigit()
        }
        return .system(style, design: .monospaced, weight: weight)
    }

    private static let joinedScripts: Set<String> = ["ar", "fa", "ur", "ps", "ckb"]
}

// MARK: - Layout

enum Layout {
    /// Side margin of every screen.
    static let margin: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let tileRadius: CGFloat = 10
    /// Small marks: a tick box, a stamp's border, a placeholder bar.
    static let markRadius: CGFloat = 6
    /// Smallest tap target.
    static let tapTarget: CGFloat = 44
}

// MARK: - Motion

enum Motion {
    /// Things that move because the user moved them.
    static let touch = Animation.spring(duration: 0.28, bounce: 0.12)
    /// Things that arrive on screen.
    static let arrive = Animation.spring(duration: 0.5, bounce: 0.18)
    /// A slip leaving or tearing.
    static let leave = Animation.spring(duration: 0.42, bounce: 0)
    /// Something appearing in place without moving: a logo that has loaded, a screen replacing another.
    static let fade = Animation.easeOut(duration: 0.2)

    /// The animation to use, or nil when Reduce Motion is on and the change should be instant
    /// or cross-faded by the caller.
    @MainActor
    static func unlessReduced(_ animation: Animation) -> Animation? {
        UIAccessibility.isReduceMotionEnabled ? fade : animation
    }
}

extension View {
    /// The language and direction the app's screens get from the root, for a view that is drawn
    /// outside them: a picture made to be shared. Without it the year slip and the Savings Receipt
    /// were laid out left to right for an Arabic reader, with the device's formats.
    @MainActor
    func inTheAppsLanguage() -> some View {
        let rightToLeft = L10n.isRightToLeft ?? (UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft)
        return environment(\.locale, L10n.locale)
            .environment(\.layoutDirection, rightToLeft ? .rightToLeft : .leftToRight)
    }
}

extension AnyTransition {
    /// Fades in, and moves a little on the way unless Reduce Motion is on. Every transition that
    /// slides, scales or shifts goes through this: six of them moved whatever the setting said.
    @MainActor
    static func arriving(_ movement: AnyTransition) -> AnyTransition {
        UIAccessibility.isReduceMotionEnabled ? .opacity : .opacity.combined(with: movement)
    }
}

// MARK: - Haptics (nothing else in the app vibrates)

@MainActor
enum Feel {
    /// A choice changed.
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    /// One line printed on paper.
    static func tick() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5) }
    /// Keep: one firm tap.
    static func keep() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    /// The tear starts along the perforation.
    static func tearStart() { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7) }
    /// The tear completes.
    static func tearEnd() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    /// A line landed on the Savings Receipt.
    static func landed() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Paper

/// The outline of a slip: straight sides, with a torn (zigzag) edge where asked.
struct SlipShape: Shape {
    var tornTop = false
    var tornBottom = true
    var tooth: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count = max(Int((rect.width / (tooth * 2)).rounded()), 1)
        let step = rect.width / CGFloat(count)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + (tornTop ? tooth : 0)))
        if tornTop {
            for i in 0..<count {
                let x = rect.minX + CGFloat(i) * step
                path.addLine(to: CGPoint(x: x + step / 2, y: rect.minY))
                path.addLine(to: CGPoint(x: x + step, y: rect.minY + tooth))
            }
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - (tornBottom ? tooth : 0)))
        if tornBottom {
            for i in 0..<count {
                let x = rect.maxX - CGFloat(i) * step
                path.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
                path.addLine(to: CGPoint(x: x - step, y: rect.maxY - tooth))
            }
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

/// A piece of paper on the ink background. Text inside defaults to `paperInk`.
struct PaperSlip<Content: View>: View {
    var tornTop = false
    var tornBottom = true
    @ViewBuilder var content: Content

    var body: some View {
        content
            .foregroundStyle(Color.paperInk)
            .padding(.horizontal, 20)
            .padding(.top, tornTop ? 26 : 20)
            .padding(.bottom, tornBottom ? 28 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.paper, in: SlipShape(tornTop: tornTop, tornBottom: tornBottom))
            .environment(\.colorScheme, .light)
    }
}

/// The dashed line a slip tears along, or the rule between sections of a receipt.
struct Perforation: View {
    var body: some View {
        Line()
            .stroke(Color.paperInk.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// One printed line: a label on the leading side, an amount on the trailing side. Stacks
/// vertically at accessibility text sizes, and reads as one sentence to VoiceOver.
struct ProofLine: View {
    let label: String
    let value: String
    var emphasised = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) { labelText; valueText }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    labelText
                    Spacer(minLength: 8)
                    valueText
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var labelText: some View {
        Text(label).font(.proof(.subheadline, weight: emphasised ? .semibold : .regular))
            // A receipt line wraps; it is never cut short ("On your sl…") when space is tight.
            .fixedSize(horizontal: false, vertical: true)
    }

    private var valueText: some View {
        Text(value)
            .font(.proof(.subheadline, weight: emphasised ? .bold : .medium))
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
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

/// A screen's title: serif, on one line. It shrinks before it wraps, and never hyphenates.
struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.question(.largeTitle, weight: .bold))
            .foregroundStyle(Color.inkText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// The screen's ink, with the status bar's strip kept solid: on a screen without a navigation bar,
    /// scrolled text otherwise slides under the clock and is drawn through it.
    func inkScreen() -> some View {
        // Full width first: a scroll view narrower than the screen must not leave black beside it.
        frame(maxWidth: .infinity)
            .background(Color.ink.ignoresSafeArea())
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    Color.ink
                        .frame(height: proxy.safeAreaInsets.top)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: .top)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }

    /// The place to tap is a fingertip in both directions, however short the word on it: "Done" in
    /// Arabic ("تم") is 15 points wide. The words stay at the edge they were on.
    func tapArea(_ alignment: Alignment = .center) -> some View {
        frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget, alignment: alignment)
            .contentShape(Rectangle())
    }
}

/// A hairline between rows, in place of a card per row.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Color.line).frame(height: 1).accessibilityHidden(true)
    }
}

/// A small coloured mark with a symbol, so state is never shown by colour alone.
struct StateMark: View {
    let state: MoneyState
    /// The disc grows with the reader's text size, like the symbol inside it.
    @ScaledMetric(relativeTo: .caption2) private var side: CGFloat = 18

    var body: some View {
        Image(systemName: state.symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.ink)
            .frame(width: side, height: side)
            .background(state.color, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The pause mark: two bars. One drawing at every size (it was drawn five times, in three
/// different proportions).
struct PauseMark: View {
    var height: CGFloat

    var body: some View {
        HStack(spacing: height * 0.23) {
            Capsule().frame(width: height * 0.27, height: height)
            Capsule().frame(width: height * 0.27, height: height)
        }
        .accessibilityHidden(true)
    }
}

/// The pause mark and the name, small: at the head of the first screen and of each slip that leaves
/// the app as a picture. The mark grows with the text beside it.
struct Wordmark: View {
    var text = "Pausely"
    @ScaledMetric(relativeTo: .headline) private var markHeight: CGFloat = 15

    var body: some View {
        HStack(spacing: 8) {
            PauseMark(height: markHeight)
            Text(verbatim: text).font(.headline)
        }
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
struct LineOrStack: SwiftUI.Layout {
    /// Between parts that share a line.
    var spacing: CGFloat = 8
    /// Between parts that are stacked.
    var lineSpacing: CGFloat = 4
    /// The whole width is taken, and on a shared line the last part sits at its far end.
    var spread = false
    /// Where stacked parts sit across the width: at the leading edge, or in the middle.
    var centred = false

    /// Whether parts of these widths share a line of this width. No width at all means "as wide as
    /// you like", which is a line.
    static func sharesALine(widths: [CGFloat], spacing: CGFloat, in available: CGFloat?) -> Bool {
        guard let available, available.isFinite else { return true }
        let needed = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1))
        return needed <= available + 0.5
    }

    private struct Plan {
        var onOneLine: Bool
        var sizes: [CGSize]
        var size: CGSize
    }

    private func plan(_ proposal: ProposedViewSize, _ subviews: Subviews) -> Plan {
        let natural = subviews.map { $0.sizeThatFits(.unspecified) }
        let available = proposal.width
        if Self.sharesALine(widths: natural.map(\.width), spacing: spacing, in: available) {
            let width = natural.map(\.width).reduce(0, +) + spacing * CGFloat(max(0, natural.count - 1))
            let filled = spread && available?.isFinite == true ? available ?? width : width
            return Plan(onOneLine: true, sizes: natural,
                        size: CGSize(width: filled, height: natural.map(\.height).max() ?? 0))
        }
        let wrapped = subviews.map { $0.sizeThatFits(ProposedViewSize(width: available, height: nil)) }
        let height = wrapped.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, wrapped.count - 1))
        let widest = wrapped.map(\.width).max() ?? 0
        return Plan(onOneLine: false, sizes: wrapped,
                    size: CGSize(width: spread ? max(widest, available ?? widest) : widest, height: height))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        plan(proposal, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = plan(ProposedViewSize(width: bounds.width, height: nil), subviews)
        if plan.onOneLine {
            var x = bounds.minX
            for (index, subview) in subviews.enumerated() {
                let size = plan.sizes[index]
                if spread, index == subviews.count - 1, subviews.count > 1 { x = max(x, bounds.maxX - size.width) }
                subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        } else {
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

// MARK: - Buttons

/// The app's buttons. `.main` is paper on ink (the one thing to do on a screen), `.keep` is mint
/// and used only for keeping money, `.quiet` is an outline, `.onPaper` is ink on a slip.
struct InkButtonStyle: ButtonStyle {
    enum Kind { case main, keep, quiet, onPaper, destructive }

    var kind: Kind = .main
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            // A button grows to hold its words. Squeezed for height (the welcome screen under a
            // banner at the largest text size), it cut them: "I already have an acc…".
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(isEnabled ? foreground : Color.inkTextMuted)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isEnabled ? fill : (kind == .quiet ? Color.clear : Color.inkLifted),
                        in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay {
                if kind == .quiet {
                    RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                        .stroke(Color.outline, lineWidth: 1)
                }
            }
            // Not available yet reads as quiet, never as faint: its text keeps a contrast of 7 to 1.
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Motion.unlessReduced(Motion.touch), value: configuration.isPressed)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch kind {
        case .main: .paperInk
        case .keep: .ink
        case .quiet: .inkText
        case .onPaper: .paper
        case .destructive: .ink
        }
    }

    private var fill: Color {
        switch kind {
        case .main: .paper
        case .keep: .kept
        case .quiet: .clear
        case .onPaper: .paperInk
        case .destructive: .due
        }
    }
}

extension ButtonStyle where Self == InkButtonStyle {
    static var ink: InkButtonStyle { InkButtonStyle() }
    static func ink(_ kind: InkButtonStyle.Kind) -> InkButtonStyle { InkButtonStyle(kind: kind) }
}
