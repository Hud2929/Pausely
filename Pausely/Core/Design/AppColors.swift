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
    static let obsidianTextTertiary = Color(hex: "#71717A")     // Tertiary/disabled (zinc-500)

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

// MARK: - Pausely Design System (Legacy)
struct Colors {
    static let primary = Color(hex: "6366F1")
    static let secondary = Color(hex: "8B5CF6")
    static let accent = Color(hex: "A855F7")
    static let background = Color(hex: "0F0F1A")
    static let backgroundSecondary = Color(hex: "1A1A2E")
    static let backgroundTertiary = Color(hex: "252540")
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    static let info = Color(hex: "3B82F6")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    static let gold = Color(hex: "F5C94D")
}

struct Typography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let callout = Font.system(size: 16, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)
    static let footnote = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let number = Font.system(size: 48, weight: .bold, design: .rounded)
    static let numberSmall = Font.system(size: 32, weight: .bold, design: .rounded)
}

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

struct Shadows {
    static let sm = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let md = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    static let lg = Shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Premium Design System (Legacy)
struct BrandColors {
    static let primary = Color(hex: "6366F1")
    static let secondary = Color(hex: "8B5CF6")
    static let accent = Color(hex: "A855F7")
}

struct BackgroundColors {
    static let primary = Color(hex: "0F0F1A")
    static let secondary = Color(hex: "1A1A2E")
    static let tertiary = Color(hex: "252540")
}

struct SemanticColors {
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    static let info = Color(hex: "3B82F6")
}

struct TextColors {
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.7)
    static let tertiary = Color.white.opacity(0.5)
}

extension Color {
    static var brandPrimary: Color { BrandColors.primary }
    static var brandSecondary: Color { BrandColors.secondary }
    static var brandAccent: Color { BrandColors.accent }
    static var backgroundPrimary: Color { BackgroundColors.primary }
    static var backgroundSecondary: Color { BackgroundColors.secondary }
    static var backgroundTertiary: Color { BackgroundColors.tertiary }
    static var success: Color { SemanticColors.success }
    static var warning: Color { SemanticColors.warning }
    static var error: Color { SemanticColors.error }
    static var info: Color { SemanticColors.info }
    static var textPrimary: Color { TextColors.primary }
    static var textSecondary: Color { TextColors.secondary }
    static var textTertiary: Color { TextColors.tertiary }

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [BrandColors.primary, BrandColors.secondary], startPoint: .leading, endPoint: .trailing)
    }

    static var premiumGradient: LinearGradient {
        LinearGradient(colors: [BrandColors.primary, BrandColors.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct PremiumTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let monoTitle = Font.system(size: 32, weight: .bold, design: .monospaced)
    static let monoHeadline = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let monoBody = Font.system(size: 16, weight: .regular, design: .monospaced)
}

struct PremiumSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

struct PremiumRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 999
}

struct PremiumShadows {
    static let sm = ShadowStyle(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    static let md = ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    static let lg = ShadowStyle(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    static let glow = ShadowStyle(color: .brandPrimary.opacity(0.4), radius: 20, x: 0, y: 0)
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
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
        ZStack {
            Colors.background
                .ignoresSafeArea()
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Colors.primary.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: 800, height: 800)
                .offset(x: -200, y: -300)
                .blur(radius: 60)
        }
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
                    .fill(Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(Typography.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isDisabled ? AnyShapeStyle(Color.gray) : AnyShapeStyle(LinearGradient(colors: [Colors.primary, Colors.secondary], startPoint: .leading, endPoint: .trailing)))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: isDisabled ? .clear : Colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.headline)
                .foregroundColor(Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Colors.backgroundTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
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
        .font(Typography.body)
        .foregroundColor(Colors.textPrimary)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Colors.backgroundTertiary)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(isFocused ? Colors.primary.opacity(0.5) : Color.white.opacity(0.08), lineWidth: isFocused ? 2 : 1)
                )
        )
        .focused($isFocused)
        .keyboardType(keyboardType)
        .textInputAutocapitalization(autocapitalization)
    }
}

// MARK: - Badge
struct Badge: View {
    let text: String
    var color: Color = Colors.primary

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(Typography.title3)
                .foregroundColor(Colors.textPrimary)
            Spacer()
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.subheadline)
                        .foregroundColor(Colors.primary)
                }
            }
        }
    }
}

// MARK: - Loading Dots
struct LoadingDots: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Colors.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .opacity(isAnimating ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
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

// MARK: - Empty State
struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Colors.textTertiary)
            Text(title)
                .font(Typography.headline)
                .foregroundColor(Colors.textPrimary)
            Text(message)
                .font(Typography.body)
                .foregroundColor(Colors.textSecondary)
                .multilineTextAlignment(.center)
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.headline)
                }
                .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xxl)
    }
}

// MARK: - Haptic Feedback
enum Haptic {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - View Extensions
extension View {
    func card() -> some View {
        modifier(CardModifier())
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Premium Card Style
struct PremiumCard: ViewModifier {
    var backgroundColor: Color = .backgroundSecondary
    var cornerRadius: CGFloat = PremiumRadius.lg
    var strokeColor: Color = .white.opacity(0.08)
    var shadow: ShadowStyle = PremiumShadows.md

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(strokeColor, lineWidth: 1)
                    )
                    .shadow(
                        color: shadow.color,
                        radius: shadow.radius,
                        x: shadow.x,
                        y: shadow.y
                    )
            )
    }
}

extension View {
    func premiumCard(
        backgroundColor: Color = .backgroundSecondary,
        cornerRadius: CGFloat = PremiumRadius.lg,
        strokeColor: Color = .white.opacity(0.08)
    ) -> some View {
        modifier(PremiumCard(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            strokeColor: strokeColor
        ))
    }
}

// MARK: - Premium Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PremiumTypography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isDisabled {
                        RoundedRectangle(cornerRadius: PremiumRadius.md)
                            .fill(Color.gray.opacity(0.4))
                    } else {
                        RoundedRectangle(cornerRadius: PremiumRadius.md)
                            .fill(Color.brandGradient)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: PremiumRadius.md)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            )
            .shadow(
                color: isDisabled ? Color.clear : BrandColors.primary.opacity(0.3),
                radius: 12,
                x: 0,
                y: 6
            )
            .scaleEffect(configuration.isPressed && !isDisabled ? 0.98 : 1)
            .opacity(isDisabled ? 0.6 : 1)
            .animation(PremiumAnimations.fast, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PremiumTypography.headline)
            .foregroundColor(TextColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: PremiumRadius.md)
                    .fill(BackgroundColors.tertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: PremiumRadius.md)
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
            .font(PremiumTypography.subheadline)
            .foregroundColor(.textSecondary)
            .padding(.vertical, PremiumSpacing.sm)
            .padding(.horizontal, PremiumSpacing.md)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(PremiumAnimations.fast, value: configuration.isPressed)
    }
}

// MARK: - Premium Background
struct PremiumBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.brandPrimary.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.6
                            )
                        )
                        .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                        .blur(radius: 60)
                        .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.brandSecondary.opacity(0.1), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.5
                            )
                        )
                        .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                        .blur(radius: 80)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.3)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Premium Input Field
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
        .font(PremiumTypography.body)
        .foregroundColor(TextColors.primary)
        .padding(PremiumSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: PremiumRadius.md)
                .fill(BackgroundColors.tertiary)
                .overlay(
                    RoundedRectangle(cornerRadius: PremiumRadius.md)
                        .stroke(
                            isFocused ? BrandColors.primary.opacity(0.5) : Color.white.opacity(0.08),
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

// MARK: - Premium Loading Indicator
struct PremiumLoadingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(BrandColors.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .opacity(isAnimating ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
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

// MARK: - Premium Section Header
struct PremiumSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(PremiumTypography.title3)
                .foregroundColor(.textPrimary)
            Spacer()
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(PremiumTypography.subheadline)
                        .foregroundColor(.brandPrimary)
                }
            }
        }
        .padding(.horizontal, PremiumSpacing.lg)
    }
}

// MARK: - Premium Badge
struct PremiumBadge: View {
    let text: String
    var badgeColor: Color = BrandColors.primary

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(badgeColor)
            )
    }
}

// MARK: - Premium Divider
struct PremiumDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
    }
}
