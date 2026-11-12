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

/// A date the person may not know yet: "Set date" until they choose one.
///
/// Nothing is filled in for them. A renewal date drives reminders, Home and the Savings Receipt, so
/// one is only ever saved because someone picked it.
struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?
    /// The earliest day that can be chosen, if there is one.
    var earliest: Date?

    var body: some View {
        if let chosen = date {
            DatePicker(title, selection: Binding(get: { chosen }, set: { date = $0 }),
                       in: (earliest ?? .distantPast)..., displayedComponents: .date)
                .labelsHidden()
                .tint(Color.inkText)
        } else {
            Button {
                date = max(Date(), earliest ?? .distantPast)
            } label: {
                Text("Set date")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
        }
    }
}
