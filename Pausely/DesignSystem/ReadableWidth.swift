import SwiftUI

/// On iPad, keeps a full-screen layout at phone reading width, centred on the app background.
/// Pausely's screens are designed for iPhone; stretched across an iPad they read as sparse rows.
/// The structure is the same in every size class, so resizing in Split View keeps all state.
///
/// A scroll view inside it is as narrow as the column, so a drag in the margins does nothing (B5). A
/// screen whose own scroll view should take the whole width uses `readableScroll()` instead.
struct ReadableWidth: ViewModifier {
    nonisolated static let maxWidth: CGFloat = 680

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Each side's margin for a window this wide.
    nonisolated static func sideInset(width: CGFloat, wide: Bool) -> CGFloat {
        wide ? max(0, (width - maxWidth) / 2) : 0
    }

    func body(content: Content) -> some View {
        let isWide = sizeClass == .regular
        content
            .frame(maxWidth: isWide ? Self.maxWidth : .infinity)
            .frame(maxWidth: .infinity)
            .background(Color.ink.ignoresSafeArea())
    }
}

/// The reading column for one scroll view, made with content margins: the scroll view keeps the whole
/// width, so the margins scroll the page. Safe-area padding was tried on 2026-11-22 and narrowed the
/// scroll view exactly as a frame does (a drag in an iPad's margin still did nothing).
struct ReadableScroll: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, ReadableWidth.sideInset(width: width, wide: sizeClass == .regular), for: .scrollContent)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { width = $0 })
    }
}

extension View {
    func readableWidth() -> some View {
        modifier(ReadableWidth())
    }

    func readableScroll() -> some View {
        modifier(ReadableScroll())
    }
}
