import SwiftUI

struct UsageInputSheet: View {
    let subscriptionName: String
    let currentMinutes: Int
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hours: String = ""
    @State private var minutes: String = ""

    init(subscriptionName: String, currentMinutes: Int, onSave: @escaping (Int) -> Void) {
        self.subscriptionName = subscriptionName
        self.currentMinutes = currentMinutes
        self.onSave = onSave
        _hours = State(initialValue: String(currentMinutes / 60))
        _minutes = State(initialValue: String(currentMinutes % 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Enter Usage for \(subscriptionName)")) {
                    HStack {
                        TextField("Hours", text: $hours)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                            .frame(width: 80)
                            .accessibilityIdentifier("hoursTextField")

                        Text("hours")
                            .foregroundColor(.secondary)

                        Spacer()
                    }

                    HStack {
                        TextField("Minutes", text: $minutes)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                            .frame(width: 80)
                            .accessibilityIdentifier("minutesTextField")

                        Text("minutes")
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }

                Section(footer: Text("This helps Pausely calculate your cost per hour and suggest when to pause subscriptions to save money.")) {
                    Button(action: save) {
                        HStack {
                            Spacer()
                            Text("Save Usage")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(hours.isEmpty && minutes.isEmpty)
                    .accessibilityIdentifier("saveUsageButton")
                    .accessibilityHint(hours.isEmpty && minutes.isEmpty ? "Please enter hours or minutes" : "")
                }

                Section(header: Text("Quick Set")) {
                    Button("Haven't used it this month (0 minutes)") {
                        hours = "0"
                        minutes = "0"
                        save()
                    }
                    .foregroundColor(.red)

                    Button("Light usage (30 minutes)") {
                        hours = "0"
                        minutes = "30"
                    }

                    Button("Moderate usage (5 hours)") {
                        hours = "5"
                        minutes = "0"
                    }

                    Button("Heavy usage (20 hours)") {
                        hours = "20"
                        minutes = "0"
                    }
                }
            }
            .navigationTitle("Update Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        let h = Int(hours) ?? 0
        let m = Int(minutes) ?? 0
        let totalMinutes = h * 60 + m
        onSave(totalMinutes)
        dismiss()
    }
}
