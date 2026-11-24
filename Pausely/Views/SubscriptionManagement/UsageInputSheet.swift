import SwiftUI

/// The hours someone used a subscription this month, typed by them. It is the one figure Pausely can't
/// know, and it turns a price into a cost per hour.
struct UsageInputSheet: View {
    let subscriptionName: String
    let currentMinutes: Int
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hours: String
    @State private var minutes: String
    @FocusState private var focus: Field?

    private enum Field { case hours, minutes }

    /// Common monthly durations so logging takes one tap instead of typing.
    private static let quickPresets = [1, 4, 10, 20]

    init(subscriptionName: String, currentMinutes: Int, onSave: @escaping (Int) -> Void) {
        self.subscriptionName = subscriptionName
        self.currentMinutes = currentMinutes
        self.onSave = onSave
        _hours = State(initialValue: currentMinutes >= 60 ? String(currentMinutes / 60) : "")
        _minutes = State(initialValue: currentMinutes % 60 > 0 ? String(currentMinutes % 60) : "")
    }

    /// Nil until something sensible is typed: hours up to a month's worth, minutes under sixty.
    static func totalMinutes(hours: String, minutes: String) -> Int? {
        let h = hours.trimmingCharacters(in: .whitespaces)
        let m = minutes.trimmingCharacters(in: .whitespaces)
        guard !(h.isEmpty && m.isEmpty) else { return nil }
        guard let hourCount = h.isEmpty ? 0 : wholeNumber(h), let minuteCount = m.isEmpty ? 0 : wholeNumber(m),
              (0...744).contains(hourCount), (0..<60).contains(minuteCount) else { return nil }
        return hourCount * 60 + minuteCount
    }

    /// A whole number typed with any keyboard's digits ("٣" and "３" are three).
    private static func wholeNumber(_ text: String) -> Int? {
        var value = 0
        for character in text {
            guard let digit = character.wholeNumberValue, value < 100_000 else { return nil }
            value = value * 10 + digit
        }
        return text.isEmpty ? nil : value
    }

    private var total: Int? { Self.totalMinutes(hours: hours, minutes: minutes) }

    var body: some View {
        // "Cancel", not "Done": this page saves with its own button, and leaving it keeps nothing.
        SettingsPage(title: "How long did you use \(subscriptionName) this month?",
                     detail: "You enter this yourself. Pausely doesn't read your Screen Time.",
                     leaveTitle: "Cancel") {
            presetRow

            HStack(alignment: .top, spacing: 12) {
                field(L10n.string("Hours"), text: $hours, id: "hoursTextField", focus: .hours)
                field(L10n.string("Minutes"), text: $minutes, id: "minutesTextField", focus: .minutes)
            }

            VStack(spacing: 10) {
                Button(action: save) { Text("Save") }
                    .buttonStyle(.ink)
                    .disabled(total == nil)
                    .accessibilityIdentifier("saveUsageButton")
                Button {
                    focus = nil
                    onSave(0)
                    dismiss()
                } label: {
                    Text("I haven't used it this month")
                }
                .buttonStyle(.ink(.quiet))
                .accessibilityIdentifier("notUsedButton")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
                    .foregroundStyle(Color.inkText)
            }
        }
    }

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.quickPresets, id: \.self) { presetHours in
                    let isChosen = total == presetHours * 60
                    let label = Duration.seconds(presetHours * 3600)
                        .formatted(.units(allowed: [.hours], width: .abbreviated).locale(L10n.locale))
                    Button {
                        Feel.selection()
                        focus = nil
                        hours = String(presetHours)
                        minutes = ""
                    } label: {
                        Text(verbatim: label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isChosen ? Color.paperInk : Color.inkText)
                            .padding(.horizontal, 14)
                            .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget)
                            .background(isChosen ? Color.paper : Color.inkRaised, in: Capsule())
                            .overlay(Capsule().stroke(isChosen ? Color.paper : Color.outline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isChosen ? [.isSelected] : [])
                    .accessibilityIdentifier("usagePreset_\(presetHours)")
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, id: String, focus field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.inkTextMuted)
                .accessibilityHidden(true)
            // In the reader's own digits, like every other figure on the sheet.
            InkTextField(placeholder: L10n.number(0), text: text, keyboardType: .numberPad)
                .focused($focus, equals: field)
                .accessibilityLabel(Text(verbatim: label))
                .accessibilityIdentifier(id)
        }
    }

    private func save() {
        guard let total else { return }
        onSave(total)
        Feel.landed()
        dismiss()
    }
}
