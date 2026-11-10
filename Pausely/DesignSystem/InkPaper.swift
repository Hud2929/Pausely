import SwiftUI
import UIKit

// MARK: - Ink and Paper
//
// The app is ink: near-black, quiet, typographic. Paper appears only where money is decided or
// proven (the verdict slip, the Savings Receipt, the share card). Mint means money kept and
// nothing else. Questions are set in a serif; proof is set in monospace.
// See REDESIGN_PLAN.md, section 3.

/// Hex values for every colour in the system. `InkPaperContrastTests` checks each text/background
/// pair against WCAG AA, so a change here that makes text unreadable fails the tests.
enum Palette {
    static let ink = "#0A0B0D"
    static let inkRaised = "#15171A"
    static let inkLifted = "#1F2226"
    static let paper = "#ECE7DC"
    static let paperShade = "#DDD7C9"
    static let paperInk = "#1A1A17"
    static let paperMuted = "#5A574E"
    static let paperKept = "#0B6245"
    static let paperDue = "#A3271C"
    static let text = "#F5F4F0"
    static let textMuted = "#A6A8AD"
    static let textFaint = "#8B8D93"
    static let kept = "#34D399"
    static let decide = "#F2B24B"
    static let due = "#F26B5E"
    static let paused = "#7CB7F0"
}

extension Color {
    /// The background of the app.
    static let ink = Color(hex: Palette.ink)
    /// The few remaining cards and grouped rows.
    static let inkRaised = Color(hex: Palette.inkRaised)
    /// Controls that sit on a raised surface.
    static let inkLifted = Color(hex: Palette.inkLifted)
    /// Hairlines, in place of card borders.
    static let line = Color.white.opacity(0.08)

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
    static let sheetRadius: CGFloat = 28
    static let cardRadius: CGFloat = 18
    static let tileRadius: CGFloat = 10
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
    /// Gap between printed lines on paper.
    static let printGap: Double = 0.04

    /// The animation to use, or nil when Reduce Motion is on and the change should be instant
    /// or cross-faded by the caller.
    static func unlessReduced(_ animation: Animation) -> Animation? {
        UIAccessibility.isReduceMotionEnabled ? .easeInOut(duration: 0.2) : animation
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
    }

    private var valueText: some View {
        Text(value)
            .font(.proof(.subheadline, weight: emphasised ? .bold : .medium))
            .monospacedDigit()
    }
}

/// A label on the leading side and a value or control on the trailing side. At accessibility text
/// sizes the two stack, so neither is squeezed into breaking mid-word.
struct AdaptiveRow<Label: View, Value: View>: View {
    @ViewBuilder var label: Label
    @ViewBuilder var value: Value
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) { label; value }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
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

/// A hairline between rows, in place of a card per row.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Color.line).frame(height: 1).accessibilityHidden(true)
    }
}

/// A small coloured mark with a symbol, so state is never shown by colour alone.
struct StateMark: View {
    let state: MoneyState

    var body: some View {
        Image(systemName: state.symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.ink)
            .frame(width: 18, height: 18)
            .background(state.color, in: Circle())
            .accessibilityHidden(true)
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
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(fill, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay {
                if kind == .quiet {
                    RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
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

// MARK: - Contrast (used by tests)

enum Contrast {
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
