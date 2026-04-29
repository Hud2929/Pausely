import SwiftUI

struct AmountStepView: View {
    @Binding var amount: String
    @Binding var selectedFrequency: BillingFrequency
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("How much does it cost?")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)

                    Text("Enter the amount you pay for this subscription")
                        .font(.body)
                        .foregroundColor(TextColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Amount display
                HStack(spacing: 4) {
                    Text(currencyManager.currencySymbol(for: currencyManager.selectedCurrency))
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(BrandColors.primary)

                    Text(amount.isEmpty ? "0.00" : amount)
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 20)

                // Amount input
                PremiumTextField(
                    placeholder: "0.00",
                    text: $amount,
                    keyboardType: .decimalPad
                )
                .padding(.horizontal, 20)
                .accessibilityIdentifier("amountTextField")

                // Frequency selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Billing Frequency")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        ForEach(BillingFrequency.allCases, id: \.self) { frequency in
                            FrequencyButton(
                                title: frequency.displayName,
                                isSelected: selectedFrequency == frequency
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedFrequency = frequency
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
        }
    }
}
