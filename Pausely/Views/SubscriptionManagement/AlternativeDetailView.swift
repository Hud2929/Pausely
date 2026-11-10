import SwiftUI

struct AlternativeDetailView: View {
    let alternative: AlternativeService
    let current: Subscription
    @Environment(\.dismiss) private var dismiss

    var savings: Double {
        SubscriptionActionManager.shared.calculateSavings(current: current, alternative: alternative)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text(alternative.name)
                            .font(.title.bold())
                            .foregroundStyle(Color.inkText)

                        Text(alternative.description)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(Color.decide)
                            Text(String(format: "%.1f", alternative.rating))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.inkText)
                        }
                    }

                    // Pricing comparison
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current")
                                    .font(.caption)
                                    .foregroundStyle(Color.inkTextMuted)
                                Text(current.displayAmountInUserCurrency + "/mo")
                                    .font(.title3)
                                    .strikethrough()
                                    .foregroundStyle(Color.due)
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .foregroundStyle(Color.kept)

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text(alternative.name)
                                    .font(.caption)
                                    .foregroundStyle(Color.inkTextMuted)
                                Text("\(alternative.monthlyPriceText)/mo")
                                    .font(.title3)
                                    .foregroundStyle(Color.kept)
                            }
                        }

                        if savings > 0 {
                            Text("You save \(CurrencyManager.shared.format(Decimal(savings))) per year!")
                                .font(.headline)
                                .foregroundStyle(Color.kept)
                                .padding()
                                .background(Color.kept.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)

                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.title3.bold())
                            .foregroundStyle(Color.inkText)

                        ForEach(alternative.features, id: \.self) { feature in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.kept)
                                Text(feature)
                                    .foregroundStyle(Color.inkText)
                            }
                        }
                    }

                    // Pros
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pros")
                            .font(.title3.bold())
                            .foregroundStyle(Color.kept)

                        ForEach(alternative.pros, id: \.self) { pro in
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.kept)
                                Text(pro)
                                    .foregroundStyle(Color.inkText)
                            }
                        }
                    }

                    // Cons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cons")
                            .font(.title3.bold())
                            .foregroundStyle(Color.decide)

                        ForEach(alternative.cons, id: \.self) { con in
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Color.decide)
                                Text(con)
                                    .foregroundStyle(Color.inkText)
                            }
                        }
                    }

                    // CTA
                    if let url = URL(string: alternative.websiteURL) {
                        Link(destination: url) {
                            HStack {
                                Text("Switch to \(alternative.name)")
                                    .font(.headline)
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundStyle(Color(.label))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                Color.inkText
                            )
                        }
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .navigationTitle("Alternative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
