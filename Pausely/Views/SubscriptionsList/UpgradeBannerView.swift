import SwiftUI

struct UpgradeBannerView: View {
    let currentCount: Int
    let limit: Int
    let onUpgrade: () -> Void

    var isAtLimit: Bool {
        currentCount >= limit
    }

    var body: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isAtLimit ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: isAtLimit ? "lock.fill" : "crown.fill")
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(isAtLimit ? .red : Color.accentMint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isAtLimit ? "Subscription Limit Reached" : "Almost at Limit")
                        .font(AppTypography.headlineMedium)
                        .foregroundStyle(.white)

                    Text(isAtLimit
                         ? "You've used all \(limit) free subscriptions. Upgrade to Pro for unlimited."
                         : "You've used \(currentCount) of \(limit) free subscriptions. Upgrade for unlimited."
                    )
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppTypography.labelLarge)
                    .foregroundStyle(Color.accentMint)
            }
            .padding()
            .glass(intensity: isAtLimit ? 0.15 : 0.1, tint: isAtLimit ? .red : Color.accentMint)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isAtLimit ? Color.red.opacity(0.3) : Color.accentMint.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
