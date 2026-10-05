import SwiftUI

// MARK: - Surface Card (clean elevation-based card)

/// Replaces GlassCard in most contexts. Uses flat surface color + subtle border.
/// No blur, no gradient fill — just clean dark surfaces.
struct SurfaceCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(elevated ? Color.obsidianElevated : Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func surfaceCard(cornerRadius: CGFloat = 20, elevated: Bool = false) -> some View {
        modifier(SurfaceCardModifier(cornerRadius: cornerRadius, elevated: elevated))
    }
}

// MARK: - Hero Number View
/// Large animated financial total with mint gradient — used for monthly spend hero.
struct HeroNumberView: View {
    let amount: String
    let label: String
    var subtitle: String? = nil

    @State private var appear = false

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Color.obsidianTextSecondary)
                .textCase(.uppercase)
                .kerning(1.2)

            Text(amount)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentMint, Color(hex: "#6EE7B7")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(appear ? 1 : 0.92)
                .opacity(appear ? 1 : 0)

            if let subtitle {
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
                appear = true
            }
        }
    }
}

// MARK: - Mint CTA Button Style
/// Full-width mint button for primary CTAs
struct MintCTAButton: View {
    let title: String
    var subtitle: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            HapticStyle.medium.trigger()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.9)
                } else {
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.black)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.6))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: subtitle != nil ? 60 : 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentMint)
                    .shadow(color: Color.accentMint.opacity(0.3), radius: 12, x: 0, y: 6)
            )
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.08)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { pressed = false }
                }
        )
    }
}
