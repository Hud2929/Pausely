import SwiftUI

/// On iPad, keeps a full-screen layout at phone reading width, centred on the app background.
/// Pausely's screens are designed for iPhone; stretched across an iPad they read as sparse rows.
/// The structure is the same in every size class, so resizing in Split View keeps all state.
///
/// The column is made with safe-area padding, not a narrower frame: a scroll view then still spans the
/// whole window and the margins scroll with it. Framed to 680 points, a drag in an iPad's margins did
/// nothing (the reach rating of 2026-11-22).
struct ReadableWidth: ViewModifier {
    static let maxWidth: CGFloat = 680

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var width: CGFloat = 0

    /// Each side's margin for a window this wide.
    nonisolated static func sideInset(width: CGFloat, wide: Bool) -> CGFloat {
        wide ? max(0, (width - maxWidth) / 2) : 0
    }

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.horizontal, Self.sideInset(width: width, wide: sizeClass == .regular))
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width = $0 })
            .background(Color.ink.ignoresSafeArea())
    }
}

extension View {
    func readableWidth() -> some View {
        modifier(ReadableWidth())
    }
}
