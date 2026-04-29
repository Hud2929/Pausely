import SwiftUI

struct ParsedResultCard: View {
    let result: ParsedSubscription

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Logo placeholder
                ZStack {
                    Circle()
                        .fill(result.category.color.opacity(0.3))
                        .frame(width: 60, height: 60)

                    Image(systemName: result.category.icon)
                        .font(AppTypography.displaySmall)
                        .foregroundStyle(result.category.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.white)

                    Text(result.category.rawValue)
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(result.category.color)
                }

                Spacer()

                // Confidence badge
                ConfidenceBadge(level: result.confidenceLevel)
            }

            if let description = result.description {
                Text(description)
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(.white.opacity(0.7))
            }

            if let price = result.price {
                HStack {
                    Text("Detected Price:")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white.opacity(0.6))

                    Text("\(result.currency) \(String(format: "%.2f", price))")
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(Color.luxuryGold)

                    Text("/\(result.billingFrequency.rawValue)")
                        .font(AppTypography.labelLarge)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Action URLs
            HStack(spacing: 12) {
                if result.directCancelURL != nil {
                    ActionChip(icon: "xmark.circle", text: "Cancel", color: .red)
                }
                if result.directPauseURL != nil {
                    ActionChip(icon: "pause.circle", text: "Pause", color: .orange)
                }
                if result.supportURL != nil {
                    ActionChip(icon: "questionmark.circle", text: "Support", color: .blue)
                }
            }
        }
        .padding()
        .glass(intensity: 0.15, tint: result.category.color)
    }
}
