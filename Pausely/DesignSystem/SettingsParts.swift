import SwiftUI

/// A settings page: a sheet with a serif title, plain rows separated by hairlines, and one way out.
/// Settings are lists of facts and choices, so nothing here is a card.
struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.question(.title, weight: .bold))
                            .foregroundStyle(Color.inkText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if let detail {
                            Text(detail)
                                .font(.body)
                                .foregroundStyle(Color.inkTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Layout.margin)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.inkText)
                        .accessibilityIdentifier("settingsDone")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// A titled run of rows. Rows are separated by hairlines by whoever lists them (`SettingsRows`).
struct SettingsSection<Content: View>: View {
    var title: LocalizedStringKey?
    var footer: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .padding(.bottom, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            content
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One line of a settings list: a title, an optional sentence under it, and what sits at the end
/// (a value, a chevron, a switch, a tick).
struct SettingsRow<Trailing: View>: View {
    let title: String
    var detail: String?
    var titleColor: Color = .inkText
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: title)
                        .font(.body)
                        .foregroundStyle(titleColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(verbatim: detail)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                trailing
            }
            .frame(minHeight: Layout.tapTarget)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            Hairline()
        }
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(title: String, detail: String? = nil, titleColor: Color = .inkText) {
        self.init(title: title, detail: detail, titleColor: titleColor) { EmptyView() }
    }
}

/// A row that is one of several choices: tapping it chooses it, and the chosen one is ticked.
struct ChoiceRow: View {
    let title: String
    var detail: String?
    let isChosen: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Feel.selection()
            action()
        } label: {
            SettingsRow(title: title, detail: detail) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .opacity(isChosen ? 1 : 0)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
    }
}

/// The small chevron that says a row leads somewhere.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.inkTextFaint)
            .accessibilityHidden(true)
    }
}
