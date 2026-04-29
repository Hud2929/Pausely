import SwiftUI

struct BillingDateSection: View {
    let subscription: Subscription
    @State private var nextBillingDate: Date

    init(subscription: Subscription) {
        self.subscription = subscription
        _nextBillingDate = State(initialValue: subscription.nextBillingDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(Color.accentMint)
                Text("Next Billing Date")
                    .font(.headline.weight(.semibold))
                Spacer()
                if subscription.nextBillingDate == nil {
                    Text("Not set")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            DatePicker(
                "Next Billing Date",
                selection: $nextBillingDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .onChange(of: nextBillingDate) { _, newDate in
                Task {
                    await saveBillingDate(newDate)
                }
            }

            if subscription.nextBillingDate == nil {
                Text("Set your billing date to get renewal reminders and track upcoming payments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func saveBillingDate(_ date: Date) async {
        var updated = subscription
        updated.nextBillingDate = date
        updated.updatedAt = Date()
        do {
            try await SubscriptionStore.shared.updateSubscription(updated)
        } catch {
            PauselyLogger.error("Failed to save billing date: \(error)", category: "SubscriptionManagement")
        }
    }
}
