import SwiftUI

struct StatusBadge: View {
    let status: SubscriptionStatus

    var body: some View {
        Text(status.displayName)
            .font(AppTypography.labelSmall)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.2))
            )
            .foregroundStyle(statusColor)
    }

    var statusColor: Color {
        switch status {
        case .active: return Color.luxuryTeal
        case .paused: return .orange
        case .cancelled: return .red
        case .trial: return .blue
        case .expired: return .gray
        }
    }
}
