import SwiftUI

/// The currency totals are shown in. Each subscription keeps the currency it is charged in.
struct CurrencySettingsView: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var searchText = ""

    /// Every currency Pausely can convert (the same list the exchange rates cover).
    private var currencies: [Currency] {
        currencyManager.allCurrencies.filter { $0.matches(searchText) }
    }

    private var ratesDay: String {
        currencyManager.ratesDate.formatted(.dateTime.month(.abbreviated).day().year().locale(L10n.locale))
    }

    var body: some View {
        SettingsPage(title: "Currency", detail: "Totals are shown in this currency. Each subscription keeps the currency it's charged in.") {
            // The age of the rates, said before the long list rather than under it.
            Text(L10n.string("Totals that mix currencies are converted at rates from \(ratesDay) and marked ≈."))
                .font(.footnote)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, -14)
                .accessibilityIdentifier("ratesDate")

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
                ForEach(currencies) { currency in
                    ChoiceRow(title: currency.localizedName(), detail: currency.code, isChosen: currencyManager.selectedCurrency == currency.code) {
                        currencyManager.setCurrency(currency.code)
                    }
                    .accessibilityIdentifier("currency-\(currency.code)")
                }
            }
        }
    }
}
