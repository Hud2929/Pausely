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
        guard let hourCount = h.isEmpty ? 0 : Int(h), let minuteCount = m.isEmpty ? 0 : Int(m),
              (0...744).contains(hourCount), (0..<60).contains(minuteCount) else { return nil }
        return hourCount * 60 + minuteCount
    }

    private var total: Int? { Self.totalMinutes(hours: hours, minutes: minutes) }

    var body: some View {
        SettingsPage(title: "How long did you use \(subscriptionName) this month?",
                     detail: "You enter this yourself. Pausely doesn't read your Screen Time.") {
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
                    onSave(0)
                    dismiss()
                } label: {
                    Text("I haven't used it this month")
                }
                .buttonStyle(.ink(.quiet))
                .accessibilityIdentifier("notUsedButton")
            }
        }
        .onAppear { focus = .hours }
    }

    private func field(_ label: String, text: Binding<String>, id: String, focus field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.inkTextMuted)
                .accessibilityHidden(true)
            InkTextField(placeholder: "0", text: text, keyboardType: .numberPad)
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
