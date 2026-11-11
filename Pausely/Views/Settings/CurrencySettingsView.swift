import SwiftUI

/// The currency totals are shown in. Each subscription keeps the currency it is charged in.
struct CurrencySettingsView: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var searchText = ""

    /// Every currency Pausely can convert (the same list the exchange rates cover).
    private var currencies: [(code: String, name: String)] {
        let all = currencyManager.allCurrencies.map { (code: $0.code, name: $0.name) }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter { $0.code.lowercased().contains(query) || $0.name.lowercased().contains(query) }
    }

    var body: some View {
        SettingsPage(title: "Currency", detail: "Totals are shown in this currency. Each subscription keeps the currency it's charged in.") {
            InkTextField(placeholder: L10n.string("Search currencies"), text: $searchText, autocapitalization: .never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("currencySearch")

            SettingsSection {
                if currencies.isEmpty {
                    Text("No currency matches that.")
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .padding(.vertical, 12)
                }
                ForEach(currencies, id: \.code) { currency in
                    ChoiceRow(title: currency.name, detail: currency.code, isChosen: currencyManager.selectedCurrency == currency.code) {
                        currencyManager.setCurrency(currency.code)
                    }
                    .accessibilityIdentifier("currency-\(currency.code)")
                }
            }
        }
    }
}
