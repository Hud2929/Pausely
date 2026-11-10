import SwiftUI

/// A fade behind the status bar so scrolled content never runs under the clock.
/// For full-screen layouts that ignore the top safe area (the tabs, the paywall).
struct StatusBarBackdrop: ViewModifier {
    var color: Color = .ink

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            Color.inkText
            .frame(height: Self.statusBarHeight + 14)
            .frame(maxWidth: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// From the window: inside a view that ignores the safe area (where this is used), SwiftUI
    /// reports a top inset of zero, which left a 14-point fade and the clock over scrolled content.
    private static var statusBarHeight: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        return window?.safeAreaInsets.top ?? 54
    }
}

extension View {
    func statusBarBackdrop(_ color: Color = .ink) -> some View {
        modifier(StatusBarBackdrop(color: color))
    }
}
