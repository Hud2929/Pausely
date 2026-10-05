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
    static let accentMintSubtle    = Color(hex: "#34D399").opacity(0.15)
    static let accentMintGlow      = Color(hex: "#34D399").opacity(0.40)

    // === SEMANTIC ===
    static let semanticDestructive = Color(hex: "#EF4444")      // Red-500
    static let semanticWarning     = Color(hex: "#F59E0B")      // Amber-500
    static let semanticSuccess     = Color(hex: "#22C55E")      // Green-500
    static let semanticInfo        = Color(hex: "#3B82F6")      // Blue-500

    // === CATEGORY COLORS ===
    static let catEntertainment    = Color(hex: "#8B5CF6")      // Violet
    static let catProductivity     = Color(hex: "#3B82F6")      // Blue
    static let catHealth           = Color(hex: "#22C55E")      // Green
    static let catNews             = Color(hex: "#F59E0B")      // Amber
    static let catSocial           = Color(hex: "#EC4899")      // Pink
    static let catCloud            = Color(hex: "#06B6D4")      // Cyan
    static let catFinance          = Color(hex: "#10B981")      // Emerald
    static let catEducation        = Color(hex: "#F97316")      // Orange
    static let catShopping         = Color(hex: "#EF4444")      // Red
    static let catOther            = Color(hex: "#6B7280")      // Gray

    // === LIGHT MODE OVERRIDES ===
    static let lightBG             = Color(hex: "#FFFFFF")
    static let lightSurface        = Color(hex: "#F4F4F5")      // zinc-100
    static let lightElevated       = Color(hex: "#E4E4E7")      // zinc-200
    static let lightText           = Color(hex: "#18181B")      // zinc-900
}

// MARK: - Design Tokens (single source of truth)
// All spacing, radius, and animation values live here.

struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

struct Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 999
}

struct PremiumAnimations {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let smooth = Animation.easeInOut(duration: 0.3)
    static let fast = Animation.easeOut(duration: 0.2)
    static let slow = Animation.easeInOut(duration: 0.5)
}

// MARK: - App Background
struct AppBackground: View {
    var body: some View {
        Color.obsidianBlack.ignoresSafeArea()
    }
}

struct PremiumBackground: View {
    var body: some View {
        Color.obsidianBlack.ignoresSafeArea()
    }
}

// MARK: - Card Component
struct Card<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.lg

    init(padding: CGFloat = Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Button Components
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline.weight(.semibold))
                }
            }
            .foregroundColor(isDisabled ? Color.obsidianTextSecondary : Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isDisabled ? AnyShapeStyle(Color.obsidianElevated) : AnyShapeStyle(Color.accentMint))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: isDisabled ? .clear : Color.accentMint.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .disabled(isDisabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(Color.obsidianText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color.obsidianElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
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

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(Color.obsidianText)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.obsidianElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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

// MARK: - Text Field
struct AppTextField: View {
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
                        .stroke(isFocused ? Color.accentMint.opacity(0.5) : Color.white.opacity(0.08), lineWidth: isFocused ? 2 : 1)
                )
        )
        .focused($isFocused)
        .keyboardType(keyboardType)
        .textInputAutocapitalization(autocapitalization)
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

// MARK: - Card Modifiers
extension View {
    func card() -> some View {
        modifier(CardModifier())
    }

    func premiumCard(
        backgroundColor: Color = .obsidianSurface,
        cornerRadius: CGFloat = Radius.lg,
        strokeColor: Color = .white.opacity(0.08)
    ) -> some View {
        modifier(PremiumCard(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            strokeColor: strokeColor
        ))
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

struct PremiumCard: ViewModifier {
    var backgroundColor: Color = .obsidianSurface
    var cornerRadius: CGFloat = Radius.lg
    var strokeColor: Color = .white.opacity(0.08)

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(strokeColor, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            )
    }
}

// MARK: - Reusable UI Components

struct Badge: View {
    let text: String
    var color: Color = .accentMint

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
    }
}

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

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(Color.obsidianText)
            Spacer()
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .foregroundColor(Color.accentMint)
                }
            }
        }
    }
}

struct PremiumSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(Color.obsidianText)
            Spacer()
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .foregroundColor(.accentMint)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
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
    @State private var isAnimating = false

    var body: some View {
        LoadingDots()
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(Color.obsidianTextTertiary)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(Color.obsidianText)
            Text(message)
                .font(.body)
                .foregroundColor(Color.obsidianTextSecondary)
                .multilineTextAlignment(.center)
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle).font(.headline.weight(.semibold))
                }
                .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xxl)
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
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
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
    static var primary: Color { .obsidianBlack }
    static var secondary: Color { .obsidianSurface }
    static var tertiary: Color { .obsidianElevated }
}

struct SemanticColors {
    static var success: Color { .semanticSuccess }
    static var warning: Color { .semanticWarning }
    static var error: Color { .semanticDestructive }
    static var info: Color { .semanticInfo }
}

struct TextColors {
    static var primary: Color { .obsidianText }
    static var secondary: Color { .obsidianTextSecondary }
    static var tertiary: Color { .obsidianTextTertiary }
}

struct Colors {
    static var primary: Color { .accentMint }
    static var background: Color { .obsidianBlack }
    static var backgroundSecondary: Color { .obsidianSurface }
    static var backgroundTertiary: Color { .obsidianElevated }
    static var success: Color { .semanticSuccess }
    static var warning: Color { .semanticWarning }
    static var error: Color { .semanticDestructive }
    static var info: Color { .semanticInfo }
    static var textPrimary: Color { .obsidianText }
    static var textSecondary: Color { .obsidianTextSecondary }
    static var textTertiary: Color { .obsidianTextTertiary }
    static var gold: Color { Color(hex: "#F5C94D") }
}

struct Typography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title1 = Font.system(.title, design: .rounded).weight(.bold)
    static let title2 = Font.system(.title2, design: .rounded).weight(.bold)
    static let title3 = Font.system(.title3, design: .rounded).weight(.semibold)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let number = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let numberSmall = Font.system(.title, design: .rounded).weight(.bold)
}

typealias PremiumTypography = Typography
typealias PremiumSpacing = Spacing
typealias PremiumRadius = Radius

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct PremiumShadows {
    static let sm = ShadowStyle(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
    static let md = ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    static let lg = ShadowStyle(color: .black.opacity(0.20), radius: 16, x: 0, y: 8)
    static let glow = ShadowStyle(color: .accentMint.opacity(0.4), radius: 20, x: 0, y: 0)
}

extension Color {
    static var brandPrimary: Color { .accentMint }
    static var brandSecondary: Color { .accentMint }
    static var brandAccent: Color { .accentMint }
    static var backgroundPrimary: Color { .obsidianBlack }
    static var backgroundSecondary: Color { .obsidianSurface }
    static var backgroundTertiary: Color { .obsidianElevated }
    static var textPrimary: Color { .obsidianText }
    static var textSecondary: Color { .obsidianTextSecondary }
    static var textTertiary: Color { .obsidianTextTertiary }
    static var success: Color { .semanticSuccess }
    static var warning: Color { .semanticWarning }
    static var error: Color { .semanticDestructive }
    static var info: Color { .semanticInfo }
}
