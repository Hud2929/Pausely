import SwiftUI

// MARK: - Obsidian Color System
extension Color {
    // === BACKGROUNDS ===
    static let obsidianBlack       = Color(hex: "#09090B")      // Primary BG (zinc-950)
    static let obsidianSurface     = Color(hex: "#18181B")      // Cards, sheets (zinc-900)
    static let obsidianElevated    = Color(hex: "#27272A")      // Elevated cards (zinc-800)
    static let obsidianBorder      = Color(hex: "#3F3F46")      // Dividers, borders (zinc-700)

    // === TEXT ===
    static let obsidianText        = Color(hex: "#FAFAFA")      // Primary text (zinc-50)
    static let obsidianTextSecondary = Color(hex: "#A1A1AA")    // Secondary text (zinc-400)
    static let obsidianTextTertiary = Color(hex: "#8A8A96")     // Tertiary/disabled — lifted from zinc-500 to pass WCAG AA on surface cards

    // === ACCENT — "Electric Mint" ===
    static let accentMint          = Color(hex: "#34D399")      // Primary accent (emerald-400)

    // === SEMANTIC ===
    static let semanticDestructive = Color(hex: "#EF4444")      // Red-500
    static let semanticWarning     = Color(hex: "#F59E0B")      // Amber-500
    static let semanticSuccess     = Color(hex: "#22C55E")      // Green-500
    static let semanticInfo        = Color(hex: "#3B82F6")      // Blue-500


}

// MARK: - Design Tokens (single source of truth)
// All spacing, radius, and animation values live here.

struct Spacing {
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
}

struct Radius {
    static let md: CGFloat = 12
}

struct PremiumAnimations {
    static let smooth = Animation.easeInOut(duration: 0.3)
    static let fast = Animation.easeOut(duration: 0.2)
}


struct PremiumBackground: View {
    var body: some View {
        Color.obsidianBlack.ignoresSafeArea()
    }
}


// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isDisabled ? Color.obsidianElevated : Color.accentMint)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: isDisabled ? .clear : Color.accentMint.opacity(0.25), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed && !isDisabled ? 0.98 : 1)
            .opacity(isDisabled ? 0.5 : 1)
            .animation(PremiumAnimations.fast, value: configuration.isPressed)
    }
}


struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(Color.obsidianTextSecondary)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(PremiumAnimations.fast, value: configuration.isPressed)
    }
}


struct PremiumTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(.body)
        .foregroundColor(Color.obsidianText)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color.obsidianElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(
                            isFocused ? Color.accentMint.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .focused($isFocused)
        .keyboardType(keyboardType)
        .textInputAutocapitalization(autocapitalization)
        .animation(PremiumAnimations.smooth, value: isFocused)
    }
}


// MARK: - Reusable UI Components


struct PremiumBadge: View {
    let text: String
    var badgeColor: Color = Color.accentMint

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(badgeColor))
    }
}


struct LoadingDots: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentMint)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .opacity(isAnimating ? 1 : 0.3)
                    .animation(
                        UIAccessibility.isReduceMotionEnabled
                            ? .none
                            : .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            isAnimating = true
        }
    }
}

struct PremiumLoadingIndicator: View {

    var body: some View {
        LoadingDots()
    }
}


struct PremiumDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
    }
}

// MARK: - Haptic Feedback
enum Haptic {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - Compatibility Shims
// These map old legacy type names to the current Obsidian design system.
// New code must not use these — use Color.obsidian* and Radius/Spacing directly.

struct BrandColors {
    static var primary: Color { .accentMint }
    static var secondary: Color { Color(hex: "#10B981") }   // emerald-500
    static var accent: Color { .accentMint }
}

struct BackgroundColors {
    static var secondary: Color { .obsidianSurface }
}


extension Color {
    static var brandPrimary: Color { .accentMint }
    static var backgroundPrimary: Color { .obsidianBlack }
    static var textSecondary: Color { .obsidianTextSecondary }
    static var textTertiary: Color { .obsidianTextTertiary }
    static var error: Color { .semanticDestructive }
}
