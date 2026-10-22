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


