import SwiftUI

struct FamilyPlanSuggestionsSection: View {
    let suggestions: [FamilyPlanDetector.FamilyPlanSuggestion]
    let currencyManager: CurrencyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3")
                    .font(.title3)
                    .foregroundStyle(Color.luxuryTeal)

                Text("Family Plan Opportunities")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()
            }

            ForEach(suggestions.prefix(2)) { suggestion in
                FamilyPlanCard(suggestion: suggestion, currencyManager: currencyManager)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
}

struct FamilyPlanCard: View {
    let suggestion: FamilyPlanDetector.FamilyPlanSuggestion
    let currencyManager: CurrencyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(suggestion.subscriptionName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text("Save \(currencyManager.format(suggestion.savingsPerMonth))/mo")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.luxuryTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.luxuryTeal.opacity(0.15))
                    .clipShape(Capsule())
            }

            HStack(spacing: 4) {
                Text("Switch to \(suggestion.familyPlanName) at \(currencyManager.format(suggestion.familyPlanPrice))/mo")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()
            }

            Text("Split \(suggestion.maxUsers) ways = \(currencyManager.format(suggestion.perPersonCost))/person")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.luxuryTeal.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
