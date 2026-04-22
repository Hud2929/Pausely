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