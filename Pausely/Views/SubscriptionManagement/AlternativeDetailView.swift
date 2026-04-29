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
                            .foregroundColor(.primary)

                        Text(alternative.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", alternative.rating))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }

                    // Pricing comparison
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(current.displayAmountInUserCurrency + "/mo")
                                    .font(.title3)
                                    .strikethrough()
                                    .foregroundStyle(.red)
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .foregroundStyle(.green)

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text(alternative.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(CurrencyManager.shared.format(Decimal(alternative.monthlyPrice)))/mo")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                        }

                        if savings > 0 {
                            Text("You save \(CurrencyManager.shared.format(Decimal(savings))) per year!")
                                .font(.headline)
                                .foregroundStyle(.green)
                                .padding()
                                .background(Color.green.opacity(0.2))
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
                            .foregroundColor(.primary)

                        ForEach(alternative.features, id: \.self) { feature in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(feature)
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    // Pros
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pros")
                            .font(.title3.bold())
                            .foregroundStyle(.green)

                        ForEach(alternative.pros, id: \.self) { pro in
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                                Text(pro)
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    // Cons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cons")
                            .font(.title3.bold())
                            .foregroundStyle(.orange)

                        ForEach(alternative.cons, id: \.self) { con in
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.orange)
                                Text(con)
                                    .foregroundColor(.primary)
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
                                LinearGradient(
                                    colors: [.luxuryGold, .luxuryPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
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
