import SwiftUI

/// A fade behind the status bar so scrolled content never runs under the clock.
/// For full-screen layouts that ignore the top safe area (the tabs, the paywall).
struct StatusBarBackdrop: ViewModifier {
    var color: Color = .obsidianBlack

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            GeometryReader { proxy in
                LinearGradient(
                    stops: [
                        .init(color: color, location: 0),
                        .init(color: color.opacity(0.94), location: 0.7),
                        .init(color: color.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: proxy.safeAreaInsets.top + 14)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

extension View {
    func statusBarBackdrop(_ color: Color = .obsidianBlack) -> some View {
        modifier(StatusBarBackdrop(color: color))
    }
}
