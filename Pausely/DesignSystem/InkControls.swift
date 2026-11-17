import SwiftUI

/// The words a field shows before anything is typed.
///
/// Left to the system they are its placeholder grey, which on ink is 2.5 to 1 (measured from the
/// captures of 2026-11-16: #55565B on #15171A): too faint for the people who most need the
/// hint. Every field's hint is made here, in the faintest text colour the palette holds at 4.5
/// to 1 on each ink surface (`InkPaperContrastTests`).
enum Hint {
    static func text(_ words: String) -> Text {
        Text(verbatim: words).foregroundStyle(Color.inkTextFaint)
    }
}

/// A text field on ink: a raised tile with an edge that can be seen, brightest while typed in.
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
                SecureField(text: $text, prompt: placeholder.isEmpty ? nil : Hint.text(placeholder)) { EmptyView() }
            } else {
                TextField(text: $text, prompt: placeholder.isEmpty ? nil : Hint.text(placeholder)) { EmptyView() }
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
                .stroke(isFocused ? Color.inkText : Color.fieldEdge, lineWidth: isFocused ? 1.5 : 1)
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

/// How large an amount is drawn in its field. A text field holds one line and cuts off what does
/// not fit, so a long amount (a yearly price in rupiah, any price at the largest text size) takes
/// the largest size that still shows all of it.
enum AmountFit {
    /// Below this the figure is no longer the number the screen is about; it stays here and the
    /// field scrolls as any text field does.
    static let smallest: CGFloat = 20

    static func size(for text: String, base: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0, !text.isEmpty, self.width(of: text, size: base) > width else { return base }
        var size = max(smallest, (base * width / self.width(of: text, size: base)).rounded(.down))
        // The serif is cut differently at different sizes, so the first answer can be a point out.
        while size > smallest, self.width(of: text, size: size) > width { size -= 1 }
        return size
    }

    /// Inside its left-to-right field, the amount sits at the far end when the row around it
    /// runs right to left (that end is where the row begins), and at the near end otherwise.
    static func alignment(inRightToLeftRow: Bool) -> TextAlignment {
        inRightToLeftRow ? .trailing : .leading
    }

    /// The width of the text in `Font.total` at this size.
    static func width(of text: String, size: CGFloat) -> CGFloat {
        let system = UIFont.systemFont(ofSize: size, weight: .bold)
        let font = system.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? system
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

private struct AmountFont: ViewModifier {
    let text: String
    let base: CGFloat
    @State private var width: CGFloat = 0
    @Environment(\.layoutDirection) private var direction

    func body(content: Content) -> some View {
        content
            .font(.total(AmountFit.size(for: text, base: base, width: width)))
            // Beside its currency in every language. Digits have no direction of their own, so in
            // Arabic iOS set the amount at the far left of the row, away from "US$" at the right
            // (asking for the leading edge changed nothing). A number is written left to right
            // in every language: the field is, and its text sits at the edge the row starts from.
            .multilineTextAlignment(AmountFit.alignment(inRightToLeftRow: direction == .rightToLeft))
            .environment(\.layoutDirection, .leftToRight)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

extension View {
    /// The font of an amount field: `Font.total` at `base`, smaller when `text` (what the field
    /// shows: the amount typed, or the example in an empty field) would not fit at that size.
    func amountFont(for text: String, base: CGFloat) -> some View {
        modifier(AmountFont(text: text, base: base))
    }
}

/// "Pro", beside something the free plan does not include. One part: it was drawn twice, in two
/// sizes and two shapes.
struct ProPill: View {
    var body: some View {
        Text("Pro")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.inkText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
    }
}

/// The one search field: a magnifier, the word "Search", and a way to clear what was typed. There
/// were three (the list's, the catalog's and the currency page's), each a little different.
struct SearchField: View {
    @Binding var text: String
    let identifier: String
    @FocusState private var typing: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.bringToTop) private var bringToTop

    /// Whether the field moves to the top of its page when it is typed in. At the accessibility
    /// text sizes, yes: under a heading and its explanation the field sat just above the
    /// keyboard, and what the search found was behind the keys.
    nonisolated static func movesToTheTopWhenTypedIn(largeText: Bool) -> Bool { largeText }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkTextFaint)
                .accessibilityHidden(true)
            TextField(text: $text, prompt: Hint.text(L10n.string("Search"))) { Text("Search") }
                .font(.body)
                .foregroundStyle(Color.inkText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .tint(Color.inkText)
                .focused($typing)
                .accessibilityIdentifier(identifier)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkTextFaint)
                        .tapArea(.trailing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
        .id(identifier)
        .onChange(of: typing) { _, isTyping in
            if isTyping, Self.movesToTheTopWhenTypedIn(largeText: typeSize.isAccessibilitySize) { bringToTop?(identifier) }
        }
    }
}

/// How the app asks before something that is not undone.
enum Asking {
    /// As an alert at the accessibility text sizes; as choices from the place that was tapped
    /// otherwise. iOS draws those choices in a narrow bubble, and at the largest text it broke
    /// the words to fit ("Re-move", "Sign out of Pause-ly?"). An alert has the width of the
    /// screen and scrolls.
    static func isAnAlert(largeText: Bool) -> Bool { largeText }
}

private struct AsksFirst<Actions: View>: ViewModifier {
    let title: Text
    @Binding var isPresented: Bool
    let message: Text?
    @ViewBuilder let actions: () -> Actions
    @Environment(\.dynamicTypeSize) private var typeSize

    /// True while there is something to ask and this is the shape to ask in.
    private func asking(asAlert: Bool) -> Binding<Bool> {
        let shape = Asking.isAnAlert(largeText: typeSize.isAccessibilitySize)
        return Binding(get: { isPresented && shape == asAlert }, set: { if !$0 { isPresented = false } })
    }

    func body(content: Content) -> some View {
        // Both are attached and one is ever shown: choosing between them with `if` would rebuild
        // what is underneath whenever the text size crossed the line.
        content
            .confirmationDialog(title, isPresented: asking(asAlert: false), titleVisibility: .visible) {
                actions()
            } message: {
                if let message { message }
            }
            .alert(title, isPresented: asking(asAlert: true)) {
                actions()
            } message: {
                if let message { message }
            }
    }
}

extension View {
    /// Asks before doing something that is not undone (`Asking`). Hang it on the button or the
    /// row that asks, never on the screen: iOS brings the choices up from whatever this is
    /// attached to, and from a whole screen that is the middle of the page, over the button
    /// that was tapped. The buttons are the ones the system draws: give the one that goes
    /// ahead the destructive role and the other the cancel role.
    func asksFirst<Actions: View>(_ title: Text, isPresented: Binding<Bool>, message: Text? = nil,
                                  @ViewBuilder actions: @escaping () -> Actions) -> some View {
        modifier(AsksFirst(title: title, isPresented: isPresented, message: message, actions: actions))
    }
}

extension EnvironmentValues {
    /// Moves the part with this id to the top of the page it is on. Set by `SearchableScroll`.
    @Entry var bringToTop: (@MainActor (String) -> Void)?
}

/// A scroll view that a search field inside it can move itself to the top of (`SearchField`).
struct SearchableScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollViewReader { page in
            ScrollView { content }
                .environment(\.bringToTop, { id in
                    withAnimation(Motion.unlessReduced(Motion.touch)) { page.scrollTo(id, anchor: .top) }
                })
        }
    }
}

/// What went wrong, in words the person can act on: the coral mark and the sentence. Colour alone
/// never carries it. One part for every form (there were four copies of it and three lines that were
/// coral text with no mark).
struct ProblemLine: View {
    let message: String
    var identifier = "formProblem"

    var body: some View {
        Label {
            Text(verbatim: message).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle")
        }
        .font(.subheadline)
        .foregroundStyle(Color.due)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(identifier)
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
        .modifier(MeasuredAgainAtEachTextSize())
    }
}

/// A field that wraps is built again when the text size changes. SwiftUI keeps the number of lines
/// the text took at the old size: a name that ran to three lines at a large size left the field
/// three lines tall when the size came back down (seen on the edit screen, whose header jumped
/// 67 points after the text size was changed and changed back).
private struct MeasuredAgainAtEachTextSize: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        content.id(typeSize)
    }
}

/// A screen whose content scrolls above its buttons.
///
/// On an iPhone at ordinary text sizes the buttons stay at the bottom edge, where a thumb expects
/// them. At the accessibility sizes, and on iPad, they come after the content, inside the scroll. Pinned, three buttons at the
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

    /// Whether the buttons stay at the bottom edge. Not at the accessibility text sizes, and not on
    /// iPad: its bottom edge is not where a thumb rests, and pinned there the buttons sat half a
    /// screen below the slip they are about.
    nonisolated static func pinsActions(at size: DynamicTypeSize, onPad: Bool) -> Bool {
        !size.isAccessibilitySize && !onPad
    }

    var body: some View {
        if Self.pinsActions(at: typeSize, onPad: UIDevice.current.userInterfaceIdiom == .pad) {
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
