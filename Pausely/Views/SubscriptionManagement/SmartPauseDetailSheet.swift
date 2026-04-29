import SwiftUI

struct SmartPauseDetailSheet: View {
    let suggestion: PauseSuggestion
    let onPause: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SmartPauseAlertView(
                suggestion: suggestion,
                onPause: {
                    dismiss()
                    onPause()
                },
                onDismiss: { dismiss() },
                onAdjustThreshold: { dismiss() }
            )
            .navigationTitle("Smart Pause")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
