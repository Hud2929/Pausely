import SwiftUI

// MARK: - Legacy Support

struct ReferredFriend: Identifiable {
    let id = UUID()
    let name: String
    let status: FriendStatus
    let date: Date?
    let avatar: String
}

enum FriendStatus {
    case completed, pending, empty
}

struct FriendRow: View {
    let friend: ReferredFriend

    var body: some View {
        HStack(spacing: 12) {
            Text(friend.avatar)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)

                    Text(statusText)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(statusColor)
                }
            }

            Spacer()

            if let date = friend.date {
                Text(timeAgo(date))
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding()
        .glass(intensity: friend.status == .empty ? 0.04 : 0.08, tint: .white)
    }

    private var statusColor: Color {
        switch friend.status {
        case .completed:
            return .green
        case .pending:
            return .orange
        case .empty:
            return .white.opacity(0.3)
        }
    }

    private var statusText: String {
        switch friend.status {
        case .completed:
            return "Completed"
        case .pending:
            return "Pending"
        case .empty:
            return "Available slot"
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
