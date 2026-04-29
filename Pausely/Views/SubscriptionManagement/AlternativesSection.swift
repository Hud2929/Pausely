import SwiftUI

struct AlternativesSection: View {
    let subscription: Subscription
    let alternatives: [AlternativeService]
    @ObservedObject var paymentManager: PaymentManager
    @ObservedObject var actionManager: SubscriptionActionManager
    let onSelectAlternative: (AlternativeService) -> Void
    let onPaywall: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Cheaper Alternatives")
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Spacer()

                if !paymentManager.isPremium {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.yellow)
                }
            }

            if paymentManager.isPremium {
                LazyVStack(spacing: 12) {
                    ForEach(alternatives.prefix(3)) { alternative in
                        AlternativeCard(
                            alternative: alternative,
                            savings: actionManager.calculateSavings(
                                current: subscription,
                                alternative: alternative
                            )
                        )
                        .onTapGesture {
                            onSelectAlternative(alternative)
                        }
                    }
                }
            } else {
                ZStack {
                    AlternativePreviewBlurred(alternatives: alternatives)

                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)

                        Text("Upgrade to Premium to see alternatives")
                            .font(.headline)

                        Button("Upgrade Now") {
                            onPaywall()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                    }
                }
                .frame(height: 200)
            }
        }
    }
}
