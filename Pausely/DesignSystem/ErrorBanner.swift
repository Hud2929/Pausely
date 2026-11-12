import SwiftUI

/// A problem that has to be read (an account link that has expired), across the top of the screen
/// until it is closed. It takes its own room: nothing underneath is covered.
struct ErrorBanner: ViewModifier {
    @Binding var error: String?

    func body(content: Content) -> some View {
        // Stacked above the screen, not laid over it: a navigation stack underneath does not move its
        // content for an inset, and the welcome screen's mark was cut in half by the bar.
        VStack(spacing: 0) {
            if let error {
                HStack(alignment: .top, spacing: 10) {
                    StateMark(state: .due)
                        .padding(.top, 13)
                    Text(verbatim: error)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 12)
                    Spacer(minLength: 8)
                    Button { self.error = nil } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.inkTextMuted)
                            .tapArea(.trailing)
                    }
                    .accessibilityLabel(Text("Close"))
                    .accessibilityIdentifier("errorBannerClose")
                }
                .padding(.horizontal, Layout.margin)
                .background(Color.inkRaised.ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Hairline() }
                .transition(.opacity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("errorBanner")
            }
            content
        }
        .animation(Motion.unlessReduced(Motion.arrive), value: error != nil)
    }
}

extension View {
    func errorBanner(_ error: Binding<String?>) -> some View {
        modifier(ErrorBanner(error: error))
    }
}

// MARK: - Notice

/// A notice that needs no answer ("Saved on this iPhone. It will sync when you're back online."):
/// shown above the tab bar for as long as it takes to read, and read out by VoiceOver. It used to
/// slide over the top of the screen, where every tab keeps its one big number, and it was gone in
/// four seconds whatever its length.
struct NoticeModifier: ViewModifier {
    @Binding var message: String?
    @State private var shown: String?
    @State private var dismissal: Task<Void, Never>?
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let shown {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .accessibilityHidden(true)
                        Text(verbatim: shown)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.inkLifted, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous).stroke(Color.outline, lineWidth: 1))
                    .frame(maxWidth: ReadableWidth.maxWidth)
                    .padding(.horizontal, Layout.margin)
                    // Clear of the tab bar, which is at the bottom on iPhone and at the top on iPad.
                    .padding(.bottom, sizeClass == .regular ? 24 : 64)
                    .transition(.opacity)
                    .accessibilityIdentifier("notice")
                }
            }
            .animation(Motion.unlessReduced(Motion.arrive), value: shown)
            .onChange(of: message) { _, new in show(new) }
    }

    private func show(_ new: String?) {
        dismissal?.cancel()
        guard let new else {
            shown = nil
            return
        }
        shown = new
        AccessibilityNotification.Announcement(new).post()
        dismissal = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.seconds(toRead: new)))
            guard !Task.isCancelled else { return }
            shown = nil
            message = nil
        }
    }

    /// Long enough to read: four seconds at least, more for a longer sentence, nine at most.
    nonisolated static func seconds(toRead text: String) -> Double {
        min(9, max(4, 2 + Double(text.count) * 0.06))
    }
}

extension View {
    func notice(_ message: Binding<String?>) -> some View {
        modifier(NoticeModifier(message: message))
    }
}
