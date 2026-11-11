import SwiftUI

/// A text field on ink: a raised tile, a hairline that brightens with focus.
struct InkTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(.body)
        .foregroundStyle(Color.inkText)
        .tint(Color.inkText)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous)
                .stroke(isFocused ? Color.white.opacity(0.45) : Color.line, lineWidth: 1)
        )
        .focused($isFocused)
        .keyboardType(keyboardType)
        .textInputAutocapitalization(autocapitalization)
        .animation(Motion.unlessReduced(Motion.touch), value: isFocused)
    }
}
