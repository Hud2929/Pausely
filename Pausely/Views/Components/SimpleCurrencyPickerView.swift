import SwiftUI

struct SimpleCurrencyPickerView: View {
    @Binding var selectedCurrency: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var searchText = ""

    var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return currencyManager.currencies
        }
        return currencyManager.currencies.filter {
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCurrencies) { currency in
                    Button(action: {
                        selectedCurrency = currency.code
                        currencyManager.setCurrency(currency.code)
                        dismiss()
                    }) {
                        HStack {
                            Text(currency.flag)
                                .font(.title3)
                            Text(currency.code)
                                .font(AppTypography.headlineMedium)
                            Text(currency.name)
                                .font(AppTypography.bodySmall)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if selectedCurrency == currency.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.luxuryGold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Currency")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
