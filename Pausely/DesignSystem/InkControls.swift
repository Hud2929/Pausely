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

/// Says whether a usage figure was measured or typed in by the person.
struct EstimateBadge: View {
    let isEstimated: Bool

    var body: some View {
        Label {
            Text(isEstimated ? "Estimated" : "Tracked")
        } icon: {
            Image(systemName: isEstimated ? "questionmark.circle" : "checkmark.circle")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.inkTextMuted)
        .accessibilityElement(children: .combine)
    }
}

/// What Screen Time can and can't see.
struct ScreenTimeDisclaimer: View {
    var body: some View {
        Text("iOS app only — Screen Time tracks time spent in the iPhone app, not web or desktop usage. This subscription must have an iOS app installed on your device.")
            .font(.footnote)
            .foregroundStyle(Color.inkTextFaint)
            .fixedSize(horizontal: false, vertical: true)
    }
}
