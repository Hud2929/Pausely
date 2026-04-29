import SwiftUI

struct CancellationStatusView: View {
    @StateObject private var service = CancellationService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if service.requests.isEmpty {
                            emptyState
                        } else {
                            requestsList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("My Cancellations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.luxuryGold)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.luxuryPurple.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "xmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.luxuryPurple)
            }

            Text("No Cancellation Requests")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("When you use Cancel for Me, your requests will appear here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private var requestsList: some View {
        VStack(spacing: 16) {
            ForEach(service.requests.sorted(by: { $0.createdAt > $1.createdAt })) { request in
                CancellationRequestCard(request: request)
            }
        }
    }
}

struct CancellationRequestCard: View {
    let request: CancellationRequest

    var statusColor: Color {
        switch request.status {
        case .pending: return .orange
        case .paymentRequired: return .red
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    var statusIcon: String {
        switch request.status {
        case .pending: return "hourglass"
        case .paymentRequired: return "creditcard.fill"
        case .inProgress: return "gearshape.2.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(request.subscriptionName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.caption2)
                    Text(request.status.displayName)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
            }

            HStack(spacing: 4) {
                Image(systemName: "envelope.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(request.accountEmail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(request.reason.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            if !request.notes.isEmpty {
                Text(request.notes)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }

            HStack {
                Text(request.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                if request.paymentCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption2)
                        Text("Paid")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.luxuryTeal)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: PremiumRadius.md)
                .fill(BackgroundColors.tertiary)
        )
    }
}

#Preview {
    CancellationStatusView()
}
