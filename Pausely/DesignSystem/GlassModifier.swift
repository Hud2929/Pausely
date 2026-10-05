import SwiftUI

// MARK: - Glass Morphism Design System

// MARK: - Estimate Badge Component

/// A badge that indicates whether usage data is estimated or actual
struct EstimateBadge: View {
    let isEstimated: Bool

    var body: some View {
        if isEstimated {
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.caption2)
                Text("Estimated")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.2))
            .cornerRadius(4)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("Tracked")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(.green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.2))
            .cornerRadius(4)
        }
    }
}

// MARK: - Screen Time Disclaimer Component

/// A disclaimer banner for Screen Time usage data
struct ScreenTimeDisclaimer: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "iphone")
                .font(.caption)
                .foregroundColor(.orange)

            Text("iOS app only — Screen Time tracks time spent in the iPhone app, not web or desktop usage. This subscription must have an iOS app installed on your device.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct GlassModifier: ViewModifier {
    let intensity: Double
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(tint.opacity(intensity * 0.3))
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    strokeColor.opacity(0.6),
                                    strokeColor.opacity(0.1),
                                    strokeColor.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }
    
    private var strokeColor: Color {
        colorScheme == .dark ? .white : Color(.systemGray3)
    }
}

struct GlassCard: ViewModifier {
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.15),
                                    color.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.7))
                    
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    strokeColor.opacity(0.5),
                                    strokeColor.opacity(0.0),
                                    strokeColor.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: color.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 20, x: 0, y: 10)
            .shadow(color: Color(.label).opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 40, x: 0, y: 20)
    }
    
    private var strokeColor: Color {
        colorScheme == .dark ? .white : Color(.systemGray3)
    }
}

struct PremiumButton: ViewModifier {
    let gradient: [Color]
    
    func body(content: Content) -> some View {
        content
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.6),
                                    .white.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .shadow(color: gradient[0].opacity(0.5), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func glass(intensity: Double = 0.5, tint: Color = .white) -> some View {
        modifier(GlassModifier(intensity: intensity, tint: tint))
    }

    func glassCard(color: Color = .purple) -> some View {
        modifier(GlassCard(color: color))
    }

    func premiumButton(gradient: [Color] = [.purple, .pink]) -> some View {
        modifier(PremiumButton(gradient: gradient))
    }

    func pressEffect(scale: CGFloat = 0.95) -> some View {
        modifier(PressEffectModifier(scale: scale))
    }
}

private struct PressEffectModifier: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Reusable Gradients

extension LinearGradient {
    /// Mint gradient for hero numbers and primary CTAs
    static var mintAccent: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#34D399"), Color(hex: "#10B981")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Compatibility aliases — new code should use .mintAccent
    static var premium: LinearGradient { .mintAccent }
    static var premiumDiagonal: LinearGradient { .mintAccent }
}

// MARK: - Flexible Glass Modifier

struct FlexibleGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let strokeColor: Color
    let strokeWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
            )
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 20, strokeColor: Color = .white.opacity(0.1), strokeWidth: CGFloat = 0.5) -> some View {
        modifier(FlexibleGlassModifier(cornerRadius: cornerRadius, strokeColor: strokeColor, strokeWidth: strokeWidth))
    }
}

// MARK: - Clean Dark Background (replaces animated gradient blobs)
struct AnimatedGradientBackground: View {
    var body: some View {
        ZStack {
            Color.obsidianBlack.ignoresSafeArea()

            // Subtle mint vignette at top-right — depth without noise
            GeometryReader { geo in
                RadialGradient(
                    colors: [Color.accentMint.opacity(0.04), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.8
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Adaptive Text Color Helper
struct AdaptiveText: View {
    let lightModeColor: Color
    let darkModeColor: Color
    let opacity: Double
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(color: Color, opacity: Double = 1.0) {
        self.lightModeColor = color
        self.darkModeColor = color
        self.opacity = opacity
    }
    
    init(light: Color, dark: Color, opacity: Double = 1.0) {
        self.lightModeColor = light
        self.darkModeColor = dark
        self.opacity = opacity
    }
    
    var body: some View {
        colorScheme == .dark ? darkModeColor.opacity(opacity) : lightModeColor.opacity(opacity)
    }
}

// MARK: - Glass Container with adaptive border
struct AdaptiveGlassContainer<Content: View>: View {
    let content: Content
    let intensity: Double
    let cornerRadius: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(intensity: Double = 0.15, cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.intensity = intensity
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .padding()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(.systemBackground).opacity(colorScheme == .dark ? 0.1 : 0.5))
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.2) : Color(.systemGray3),
                            lineWidth: 1
                        )
                }
            )
    }
}

enum HapticStyle {
    case light, medium, heavy, success, warning, error

    func trigger() {
        switch self {
        case .light:
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        case .medium:
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        case .heavy:
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - Press Events Modifier

struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onRelease()
                    }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}
