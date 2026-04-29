import SwiftUI

struct ConfidenceBadge: View {
    let level: ParsedSubscription.ConfidenceLevel

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            Text(level.rawValue)
                .font(AppTypography.labelMedium)
        }
        .foregroundStyle(level.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(level.color.opacity(0.15))
        )
    }
}
