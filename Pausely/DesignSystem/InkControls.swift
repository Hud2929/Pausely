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
        // Room above and below the text at every size: with a height alone, the largest text
        // touched the tile's edges.
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous)
                .stroke(isFocused ? Color.outlineFocused : Color.line, lineWidth: 1)
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
                    .tapArea(.leading)
            }
        }
    }
}

/// The way out of a screen that draws its own top row: one word at the leading edge, in the same
/// place and the same quiet weight everywhere. "Done" where nothing is lost, "Cancel" where what was
/// typed is dropped, "Close" for something left undecided, "Not now" for a question put off. (Screens
/// with a navigation bar use its own button.) There were ten copies of this and an X on the paywall.
struct LeaveButton: View {
    private let title: LocalizedStringKey
    private let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkTextMuted)
                .tapArea(.leading)
        }
        .buttonStyle(.plain)
    }
}

/// A name is one line of text, but its field may need two or three lines to show it (a long name
/// at a large text size was cut to "Adobe Cr…"). A field that wraps treats Return as a line
/// break, so this takes the break back out and moves on, as Return does in a one-line field.
enum NameField {
    /// The text without line breaks, and whether there was one to take out.
    static func withoutBreaks(_ text: String) -> (text: String, hadBreak: Bool) {
        let cleaned = text.components(separatedBy: .newlines).joined()
        return (cleaned, cleaned != text)
    }
}

extension View {
    func returnMovesOn(from text: Binding<String>, to next: @escaping () -> Void) -> some View {
        onChange(of: text.wrappedValue) { _, new in
            let name = NameField.withoutBreaks(new)
            guard name.hadBreak else { return }
            text.wrappedValue = name.text
            next()
        }
    }
}

/// A screen whose content scrolls above its buttons.
///
/// At ordinary text sizes the buttons stay at the bottom edge, where a thumb expects them. At the
/// accessibility sizes they come after the content, inside the scroll. Pinned, three buttons at the
/// largest size cover more than half the screen and leave a slot to read through (the verdict showed
/// two words of its slip), and where the screen is shorter still they do not fit at all (the
/// welcome screen's second button was drawn over its own border).
struct ActionScreen<Content: View, Actions: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    private let dismissesKeyboard: Bool
    private let content: Content
    private let actions: Actions

    /// `dismissesKeyboard`: a form, where dragging the content down puts the keyboard away.
    init(dismissesKeyboard: Bool = false, @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions) {
        self.dismissesKeyboard = dismissesKeyboard
        self.content = content()
        self.actions = actions()
    }

    /// Whether the buttons stay at the bottom edge at this text size.
    nonisolated static func pinsActions(at size: DynamicTypeSize) -> Bool {
        !size.isAccessibilitySize
    }

    var body: some View {
        if Self.pinsActions(at: typeSize) {
            VStack(spacing: 0) {
                ScrollView { content }
                    .scrollDismissesKeyboard(dismissesKeyboard ? .interactively : .automatic)
                actions
                    .background(Color.ink)
            }
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    content
                    actions
                }
            }
            .scrollDismissesKeyboard(dismissesKeyboard ? .interactively : .automatic)
        }
    }
}
