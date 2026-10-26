import SwiftUI


// MARK: - Paused Subscriptions Section
struct PausedSubscriptionsSection: View {
    let subscriptions: [Subscription]

    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Paused")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(subscriptions.count) saving you money")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(subscriptions) { sub in
                        PausedCard(subscription: sub)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct PausedCard: View {
    let subscription: Subscription

    @ObservedObject private var currencyManager = CurrencyManager.shared

    var daysUntilResume: Int {
        guard let pausedUntil = subscription.pausedUntil else { return 0 }
        return Calendar.current.calendarDays(from: Date(), to: pausedUntil)
    }

    var body: some View {
        // A pause saves the monthly cost, in what the subscription is billed in.
        let monthlySaving = MoneyFormat.string(subscription.monthlyCost, subscription.currency)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(daysUntilResume)d")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }

            Spacer()

            Text(subscription.name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("Saving \(monthlySaving)/mo")
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(.orange)
        }
        .padding(14)
        .frame(width: 140, height: 120)
        .surfaceCard(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subscription.name), paused for \(daysUntilResume) more days, saving \(monthlySaving) per month")
        .accessibilityHint("Double-tap to view details and resume")
    }
}
