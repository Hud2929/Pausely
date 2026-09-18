import SwiftUI

struct ErrorBanner: ViewModifier {
    @Binding var error: String?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                    Button {
                        self.error = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: error != nil)
    }
}

extension View {
    func errorBanner(_ error: Binding<String?>) -> some View {
        modifier(ErrorBanner(error: error))
    }
}

// MARK: - Error Toast (auto-dismissing, obsidian surface)

/// Slides in from the top of the screen and auto-dismisses after 4 seconds.
/// Apply once at the root view to cover all tabs.
struct ErrorToastModifier: ViewModifier {
    @Binding var message: String?
    @State private var isVisible = false
    @State private var dismissItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isVisible, let msg = message {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 16, weight: .semibold))
                        Text(msg)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.obsidianSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
            .onChange(of: message) { _, newMessage in
                if newMessage != nil {
                    isVisible = true
                    HapticStyle.warning.trigger()
                    dismissItem?.cancel()
                    let item = DispatchWorkItem {
                        withAnimation { isVisible = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { message = nil }
                    }
                    dismissItem = item
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: item)
                } else {
                    isVisible = false
                }
            }
    }
}

extension View {
    func errorToast(message: Binding<String?>) -> some View {
        modifier(ErrorToastModifier(message: message))
    }
}