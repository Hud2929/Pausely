import SwiftUI

/// On iPad, keeps a full-screen layout at phone reading width, centred on the app background.
/// Pausely's screens are designed for iPhone; stretched across an iPad they read as sparse rows.
/// The structure is the same in every size class, so resizing in Split View keeps all state.
struct ReadableWidth: ViewModifier {
    static let maxWidth: CGFloat = 680

    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        let isWide = sizeClass == .regular
        content
            .frame(maxWidth: isWide ? Self.maxWidth : .infinity)
            .frame(maxWidth: .infinity)
            .background(Color.obsidianBlack.ignoresSafeArea())
    }
}

extension View {
    func readableWidth() -> some View {
        modifier(ReadableWidth())
    }
}
