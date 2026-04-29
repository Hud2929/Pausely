import SwiftUI

struct SmartPauseSection: View {
    let subscription: Subscription
    let suggestion: PauseSuggestion
    let onInfoTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Suggestion")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.yellow)

                    Text("Consider Pausing This Subscription")
                        .font(.body.weight(.bold))
                }

                Spacer()

                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.luxuryPurple)
                }
                .accessibilityLabel("Smart pause info")
            }

            SmartPauseBanner(
                suggestion: suggestion,
                onTap: onInfoTap,
                onDismiss: { }
            )
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}
