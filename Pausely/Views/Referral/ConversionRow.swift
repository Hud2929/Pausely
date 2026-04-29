import SwiftUI

struct ConversionRow: View {
    let conversion: ReferralConversion

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: statusIcon)
                    .font(.callout)
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(conversion.referredUserEmail ?? "Anonymous")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                Text(statusText)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(statusColor)
            }

            Spacer()

            Text(formatDate(conversion.createdAt))
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding()
        .glass(intensity: 0.08, tint: .white)
    }

    private var statusColor: Color {
        switch conversion.status {
        case .converted:
            return .green
        case .pending:
            return .orange
        case .cancelled:
            return .red
        }
    }

    private var statusIcon: String {
        switch conversion.status {
        case .converted:
            return "checkmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    private var statusText: String {
        switch conversion.status {
        case .converted:
            return "Completed"
        case .pending:
            return "Pending"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
