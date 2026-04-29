import SwiftUI

struct SubscriptionStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(AppTypography.headlineLarge)
                .foregroundStyle(color)

            Text(value)
                .font(AppTypography.displaySmall)
                .foregroundStyle(.white)

            Text(label)
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glass(intensity: 0.1, tint: color)
    }
}
