import SwiftUI

struct CurrencySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var searchText = ""

    // Use currencyManager.selectedCurrency directly to avoid state sync issues
    private var selectedCurrency: String {
        currencyManager.selectedCurrency
    }

    // All available currencies
    let allCurrencies: [(code: String, symbol: String, name: String)] = [
        // Popular
        ("USD", "$", "US Dollar"),
        ("EUR", "€", "Euro"),
        ("GBP", "£", "British Pound"),
        ("JPY", "¥", "Japanese Yen"),
        ("CAD", "C$", "Canadian Dollar"),
        ("AUD", "A$", "Australian Dollar"),
        ("CHF", "Fr", "Swiss Franc"),
        ("CNY", "¥", "Chinese Yuan"),
        ("INR", "₹", "Indian Rupee"),
        ("BRL", "R$", "Brazilian Real"),
        ("KRW", "₩", "South Korean Won"),
        ("MXN", "$", "Mexican Peso"),
        ("SGD", "S$", "Singapore Dollar"),
        ("HKD", "HK$", "Hong Kong Dollar"),
        ("NOK", "kr", "Norwegian Krone"),
        ("SEK", "kr", "Swedish Krona"),
        ("DKK", "kr", "Danish Krone"),
        ("NZD", "NZ$", "New Zealand Dollar"),
        ("ZAR", "R", "South African Rand"),
        ("RUB", "₽", "Russian Ruble"),
        ("TRY", "₺", "Turkish Lira"),
        ("PLN", "zł", "Polish Zloty"),
        ("THB", "฿", "Thai Baht"),
        ("IDR", "Rp", "Indonesian Rupiah"),
        ("MYR", "RM", "Malaysian Ringgit"),
        ("PHP", "₱", "Philippine Peso"),
        ("CZK", "Kč", "Czech Koruna"),
        ("ILS", "₪", "Israeli Shekel"),
        ("AED", "د.إ", "UAE Dirham"),
        ("SAR", "﷼", "Saudi Riyal"),
        ("TWD", "NT$", "Taiwan Dollar"),
        ("VND", "₫", "Vietnamese Dong"),
        ("EGP", "£", "Egyptian Pound"),
        ("PKR", "₨", "Pakistani Rupee"),
        ("NGN", "₦", "Nigerian Naira"),
        ("BDT", "৳", "Bangladeshi Taka"),
        ("RON", "lei", "Romanian Leu"),
        ("HUF", "Ft", "Hungarian Forint"),
        ("UAH", "₴", "Ukrainian Hryvnia"),
        ("CLP", "$", "Chilean Peso"),
        ("COP", "$", "Colombian Peso"),
        ("PEN", "S/", "Peruvian Sol"),
        ("ARS", "$", "Argentine Peso"),
        ("MAD", "د.م.", "Moroccan Dirham"),
        ("QAR", "﷼", "Qatari Riyal"),
        ("KWD", "د.ك", "Kuwaiti Dinar"),
        ("BHD", ".د.ب", "Bahraini Dinar"),
        ("OMR", "﷼", "Omani Rial"),
        ("JOD", "د.ا", "Jordanian Dinar"),
        ("LKR", "Rs", "Sri Lankan Rupee"),
        ("NPR", "Rs", "Nepalese Rupee"),
        ("KES", "KSh", "Kenyan Shilling"),
        ("GHS", "₵", "Ghanaian Cedi"),
        ("TZS", "TSh", "Tanzanian Shilling"),
        ("UGX", "USh", "Ugandan Shilling"),
        ("ISK", "kr", "Icelandic Krona"),
        ("HRK", "kn", "Croatian Kuna"),
        ("BGN", "лв", "Bulgarian Lev"),
        ("RSD", "дин", "Serbian Dinar"),
        ("GEL", "₾", "Georgian Lari"),
        ("AMD", "֏", "Armenian Dram"),
        ("AZN", "₼", "Azerbaijani Manat"),
        ("KZT", "₸", "Kazakhstani Tenge"),
        ("UZS", "so'm", "Uzbekistan Som"),
        ("TJS", "SM", "Tajikistani Somoni"),
        ("KGS", "с", "Kyrgyzstani Som"),
        ("MNT", "₮", "Mongolian Tugrik"),
        ("MMK", "K", "Myanmar Kyat"),
        ("KHR", "៛", "Cambodian Riel"),
        ("LAK", "₭", "Lao Kip"),
        ("BND", "$", "Brunei Dollar"),
        ("BWP", "P", "Botswana Pula"),
        ("MUR", "₨", "Mauritian Rupee"),
        ("SCR", "₨", "Seychellois Rupee"),
        ("ZMW", "ZK", "Zambian Kwacha"),
        ("MWK", "MK", "Malawian Kwacha"),
        ("MZN", "MT", "Mozambican Metical"),
        ("NAD", "$", "Namibian Dollar"),
        ("SZL", "L", "Swazi Lilangeni"),
        ("LSL", "L", "Lesotho Loti"),
        ("AOA", "Kz", "Angolan Kwanza"),
        ("CDF", "FC", "Congolese Franc"),
        ("RWF", "FRw", "Rwandan Franc"),
        ("BIF", "FBu", "Burundian Franc"),
        ("DJF", "Fdj", "Djiboutian Franc"),
        ("ETB", "Br", "Ethiopian Birr"),
        ("SOS", "Sh", "Somali Shilling"),
        ("GMD", "D", "Gambian Dalasi"),
        ("GNF", "FG", "Guinean Franc"),
        ("LRD", "$", "Liberian Dollar"),
        ("SLL", "Le", "Sierra Leonean Leone"),
        ("MRU", "UM", "Mauritanian Ouguiya"),
        ("STN", "Db", "São Tomé and Príncipe Dobra"),
        ("XOF", "CFA", "West African CFA Franc"),
        ("XAF", "FCFA", "Central African CFA Franc"),
        ("XCD", "$", "East Caribbean Dollar"),
        ("AWG", "ƒ", "Aruban Florin"),
        ("ANG", "ƒ", "Netherlands Antillean Guilder"),
        ("TTD", "$", "Trinidad & Tobago Dollar"),
        ("BBD", "$", "Barbadian Dollar"),
        ("BSD", "$", "Bahamian Dollar"),
        ("BZD", "$", "Belize Dollar"),
        ("JMD", "$", "Jamaican Dollar"),
        ("HTG", "G", "Haitian Gourde"),
        ("DOP", "$", "Dominican Peso"),
        ("CUP", "$", "Cuban Peso"),
        ("GTQ", "Q", "Guatemalan Quetzal"),
        ("HNL", "L", "Honduran Lempira"),
        ("NIO", "C$", "Nicaraguan Córdoba"),
        ("CRC", "₡", "Costa Rican Colón"),
        ("PAB", "B/.", "Panamanian Balboa"),
        ("UYU", "$", "Uruguayan Peso"),
        ("PYG", "₲", "Paraguayan Guarani"),
        ("BOB", "Bs", "Bolivian Boliviano"),
        ("VES", "Bs", "Venezuelan Bolívar")
    ]

    // Filtered currencies based on search
    var filteredCurrencies: [(code: String, symbol: String, name: String)] {
        if searchText.isEmpty {
            return allCurrencies
        }
        let query = searchText.lowercased()
        return allCurrencies.filter { currency in
            currency.code.lowercased().contains(query) ||
            currency.name.lowercased().contains(query) ||
            currency.symbol.lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                            .accessibilityLabel("Close")
                    }

                    Spacer()

                    Text("Currency")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Current Selection Display
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.luxuryPurple.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Text(currentSymbol)
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.luxuryPurple)
                    }

                    Text(currentName)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)

                    Text(currentCode)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 20)

                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.callout)

                    TextField("Search currencies...", text: $searchText)
                        .foregroundColor(.white)
                        .font(.callout)
                        .keyboardType(.default)
                        .submitLabel(.search)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Results count
                HStack {
                    Text("\(filteredCurrencies.count) currencies")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // Currency List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredCurrencies, id: \.code) { currency in
                            CurrencyRow(
                                code: currency.code,
                                symbol: currency.symbol,
                                name: currency.name,
                                isSelected: selectedCurrency == currency.code,
                                isFiltered: !searchText.isEmpty
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    currencyManager.setCurrency(currency.code)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    var currentSymbol: String {
        allCurrencies.first { $0.code == selectedCurrency }?.symbol ?? "$"
    }

    var currentName: String {
        allCurrencies.first { $0.code == selectedCurrency }?.name ?? "US Dollar"
    }

    var currentCode: String {
        selectedCurrency
    }
}

struct CurrencyRow: View {
    let code: String
    let symbol: String
    let name: String
    let isSelected: Bool
    var isFiltered: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            HStack(spacing: 16) {
                // Symbol circle
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.luxuryPurple.opacity(0.3) : Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)

                    Text(symbol)
                        .font(.callout.weight(.bold))
                        .foregroundColor(isSelected ? .luxuryPurple : .white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.callout.weight(.medium))
                        .foregroundColor(.white)

                    Text(code)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.gray)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.luxuryPurple)
                        .shadow(color: .luxuryPurple.opacity(0.5), radius: 8)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.luxuryPurple.opacity(0.12) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.luxuryPurple : Color.clear, lineWidth: 1.5)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}

#Preview {
    CurrencySettingsView()
}
