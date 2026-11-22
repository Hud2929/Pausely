import Foundation
import Combine
import os

/// The display currency and the live exchange rates.
///
/// Everything published here changes on the main thread only: the screens read it there. The rates
/// table every conversion uses can also be read from anywhere, so it sits behind a lock.
///
/// That is the whole of its thread-safety, and the compiler cannot see it: hence `@unchecked`.
final class CurrencyManager: ObservableObject, @unchecked Sendable {
    static let shared = CurrencyManager()

    @Published var selectedCurrency: String
    /// Live rates per USD as loaded from the API. Conversions use `rates`, which fills any gaps
    /// from `CurrencyRates.fallback` so every currency in the picker always converts.
    @Published var exchangeRates: [String: Double] = [:] {
        didSet {
            let filled = CurrencyRates(apiRates: exchangeRates).fillingGaps()
            table.withLock { $0 = filled }
        }
    }
    private let table = OSAllocatedUnfairLock(initialState: CurrencyRates.fallback)
    var ratesTable: CurrencyRates { table.withLock { $0 } }

    /// When the rates held were loaded. Nil until live rates have been loaded once on this iPhone.
    var lastUpdated: Date?

    /// The day the rates in use are from: the last live load, or the day of the built-in table.
    var ratesDate: Date {
        if let lastUpdated { return lastUpdated }
        let day = ISO8601DateFormatter()
        day.formatOptions = [.withFullDate]
        return day.date(from: CurrencyRates.fallbackDate) ?? .distantPast
    }
    private var isRefreshing = false

    /// Where live rates come from. The app asks exchangerate-api.com; tests put their own answer here.
    var loadLiveRates: () async throws -> ExchangeRateResponse = {
        guard let url = URL(string: AppConfig.exchangeRatesURL) else { throw URLError(.badURL) }
        let (data, _) = try await CurrencyManager.session.data(from: url)
        return try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    let currencies: [Currency] = [
        // Major Global Currencies
        Currency(code: "USD", name: "US Dollar"),
        Currency(code: "EUR", name: "Euro"),
        Currency(code: "GBP", name: "British Pound"),
        Currency(code: "JPY", name: "Japanese Yen"),
        Currency(code: "CNY", name: "Chinese Yuan"),
        
        // Americas
        Currency(code: "CAD", name: "Canadian Dollar"),
        Currency(code: "MXN", name: "Mexican Peso"),
        Currency(code: "BRL", name: "Brazilian Real"),
        Currency(code: "ARS", name: "Argentine Peso"),
        Currency(code: "CLP", name: "Chilean Peso"),
        Currency(code: "COP", name: "Colombian Peso"),
        Currency(code: "PEN", name: "Peruvian Sol"),
        Currency(code: "UYU", name: "Uruguayan Peso"),
        Currency(code: "DOP", name: "Dominican Peso"),
        Currency(code: "CRC", name: "Costa Rican Colón"),
        Currency(code: "GTQ", name: "Guatemalan Quetzal"),
        Currency(code: "HNL", name: "Honduran Lempira"),
        Currency(code: "NIO", name: "Nicaraguan Córdoba"),
        Currency(code: "PAB", name: "Panamanian Balboa"),
        Currency(code: "BOB", name: "Bolivian Boliviano"),
        Currency(code: "PYG", name: "Paraguayan Guaraní"),
        Currency(code: "VES", name: "Venezuelan Bolívar"),
        Currency(code: "XCD", name: "Eastern Caribbean Dollar"),
        Currency(code: "TTD", name: "Trinidad & Tobago Dollar"),
        Currency(code: "JMD", name: "Jamaican Dollar"),
        Currency(code: "BBD", name: "Barbadian Dollar"),
        Currency(code: "BSD", name: "Bahamian Dollar"),
        Currency(code: "BZD", name: "Belize Dollar"),
        Currency(code: "KYD", name: "Cayman Islands Dollar"),
        Currency(code: "BMD", name: "Bermudian Dollar"),
        Currency(code: "GYD", name: "Guyanese Dollar"),
        Currency(code: "SRD", name: "Surinamese Dollar"),
        
        // Europe
        Currency(code: "CHF", name: "Swiss Franc"),
        Currency(code: "SEK", name: "Swedish Krona"),
        Currency(code: "NOK", name: "Norwegian Krone"),
        Currency(code: "DKK", name: "Danish Krone"),
        Currency(code: "PLN", name: "Polish Złoty"),
        Currency(code: "CZK", name: "Czech Koruna"),
        Currency(code: "HUF", name: "Hungarian Forint"),
        Currency(code: "RON", name: "Romanian Leu"),
        Currency(code: "RSD", name: "Serbian Dinar"),
        Currency(code: "ISK", name: "Icelandic Króna"),
        Currency(code: "UAH", name: "Ukrainian Hryvnia"),
        Currency(code: "RUB", name: "Russian Ruble"),
        Currency(code: "BYN", name: "Belarusian Ruble"),
        Currency(code: "MDL", name: "Moldovan Leu"),
        Currency(code: "GIP", name: "Gibraltar Pound"),
        Currency(code: "ALL", name: "Albanian Lek"),
        Currency(code: "BAM", name: "Bosnia Mark"),
        Currency(code: "MKD", name: "Macedonian Denar"),
        Currency(code: "GEL", name: "Georgian Lari"),
        Currency(code: "AZN", name: "Azerbaijani Manat"),
        Currency(code: "AMD", name: "Armenian Dram"),
        
        // Asia Pacific
        Currency(code: "AUD", name: "Australian Dollar"),
        Currency(code: "NZD", name: "New Zealand Dollar"),
        Currency(code: "SGD", name: "Singapore Dollar"),
        Currency(code: "HKD", name: "Hong Kong Dollar"),
        Currency(code: "KRW", name: "South Korean Won"),
        Currency(code: "INR", name: "Indian Rupee"),
        Currency(code: "IDR", name: "Indonesian Rupiah"),
        Currency(code: "MYR", name: "Malaysian Ringgit"),
        Currency(code: "THB", name: "Thai Baht"),
        Currency(code: "PHP", name: "Philippine Peso"),
        Currency(code: "VND", name: "Vietnamese Dong"),
        Currency(code: "TWD", name: "Taiwan Dollar"),
        Currency(code: "PKR", name: "Pakistani Rupee"),
        Currency(code: "BDT", name: "Bangladeshi Taka"),
        Currency(code: "LKR", name: "Sri Lankan Rupee"),
        Currency(code: "NPR", name: "Nepalese Rupee"),
        Currency(code: "MMK", name: "Myanmar Kyat"),
        Currency(code: "KHR", name: "Cambodian Riel"),
        Currency(code: "LAK", name: "Lao Kip"),
        Currency(code: "MOP", name: "Macanese Pataca"),
        Currency(code: "BND", name: "Brunei Dollar"),
        Currency(code: "PGK", name: "Papua New Guinean Kina"),
        Currency(code: "FJD", name: "Fijian Dollar"),
        Currency(code: "WST", name: "Samoan Tala"),
        Currency(code: "TOP", name: "Tongan Paʻanga"),
        Currency(code: "VUV", name: "Vanuatu Vatu"),
        Currency(code: "SBD", name: "Solomon Islands Dollar"),
        Currency(code: "MVR", name: "Maldivian Rufiyaa"),
        Currency(code: "BTN", name: "Bhutanese Ngultrum"),
        Currency(code: "MNT", name: "Mongolian Tugrik"),
        Currency(code: "KZT", name: "Kazakhstani Tenge"),
        Currency(code: "KGS", name: "Kyrgyzstani Som"),
        Currency(code: "TJS", name: "Tajikistani Somoni"),
        Currency(code: "UZS", name: "Uzbekistani Som"),
        Currency(code: "AFN", name: "Afghan Afghani"),
        
        // Middle East & Africa
        Currency(code: "AED", name: "UAE Dirham"),
        Currency(code: "SAR", name: "Saudi Riyal"),
        Currency(code: "QAR", name: "Qatari Riyal"),
        Currency(code: "KWD", name: "Kuwaiti Dinar"),
        Currency(code: "BHD", name: "Bahraini Dinar"),
        Currency(code: "OMR", name: "Omani Rial"),
        Currency(code: "ILS", name: "Israeli Shekel"),
        Currency(code: "JOD", name: "Jordanian Dinar"),
        Currency(code: "LBP", name: "Lebanese Pound"),
        Currency(code: "EGP", name: "Egyptian Pound"),
        Currency(code: "ZAR", name: "South African Rand"),
        Currency(code: "NGN", name: "Nigerian Naira"),
        Currency(code: "KES", name: "Kenyan Shilling"),
        Currency(code: "GHS", name: "Ghanaian Cedi"),
        Currency(code: "MAD", name: "Moroccan Dirham"),
        Currency(code: "TND", name: "Tunisian Dinar"),
        Currency(code: "DZD", name: "Algerian Dinar"),
        Currency(code: "ETB", name: "Ethiopian Birr"),
        Currency(code: "TZS", name: "Tanzanian Shilling"),
        Currency(code: "UGX", name: "Ugandan Shilling"),
        Currency(code: "ZMW", name: "Zambian Kwacha"),
        Currency(code: "BWP", name: "Botswana Pula"),
        Currency(code: "MUR", name: "Mauritian Rupee"),
        Currency(code: "SCR", name: "Seychellois Rupee"),
        Currency(code: "XOF", name: "West African CFA Franc"),
        Currency(code: "XAF", name: "Central African CFA Franc"),
        Currency(code: "ERN", name: "Eritrean Nakfa"),
        Currency(code: "SZL", name: "Eswatini Lilangeni"),
        Currency(code: "LSL", name: "Lesotho Loti"),
        Currency(code: "NAD", name: "Namibian Dollar"),
        Currency(code: "MZN", name: "Mozambican Metical"),
        Currency(code: "MWK", name: "Malawian Kwacha"),
        Currency(code: "RWF", name: "Rwandan Franc"),
        Currency(code: "SLE", name: "Sierra Leonean Leone"),
        Currency(code: "SOS", name: "Somali Shilling"),
        Currency(code: "SDG", name: "Sudanese Pound"),
        Currency(code: "TMT", name: "Turkmenistani Manat"),
        Currency(code: "IRR", name: "Iranian Rial"),
        Currency(code: "IQD", name: "Iraqi Dinar"),
        Currency(code: "YER", name: "Yemeni Rial"),
        Currency(code: "SYP", name: "Syrian Pound"),
        Currency(code: "TRY", name: "Turkish Lira"),
    ]

    private let userDefaultsKey = "selected_currency"
    private let ratesCacheKey = "cached_exchange_rates"
    private let ratesDateKey = "exchange_rates_date"

    private init() {
        let deviceCurrency = Self.current(Locale.current.currency?.identifier ?? "USD")
        let offered = Set(currencies.map(\.code))
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey).map(Self.current), offered.contains(saved) {
            selectedCurrency = saved
        } else {
            selectedCurrency = offered.contains(deviceCurrency) ? deviceCurrency : "USD"
        }
        #if DEBUG
        // `--demo-currency=IDR`: this launch shows its totals in that currency, so long amounts can
        // be looked at. Nothing is saved (property observers don't run during init).
        if let shown = LaunchFlag.value(of: "--demo-currency").map(Self.current), offered.contains(shown) {
            selectedCurrency = shown
        }
        #endif

        // The rates saved last time, until fresh ones arrive. Property observers don't run during
        // init, so the table is filled here.
        if let saved = UserDefaults.standard.dictionary(forKey: ratesCacheKey) as? [String: Double] {
            exchangeRates = saved
            lastUpdated = UserDefaults.standard.object(forKey: ratesDateKey) as? Date
        }
        let filled = CurrencyRates(apiRates: exchangeRates).fillingGaps()
        table.withLock { $0 = filled }

        Task { @MainActor [weak self] in await self?.refreshRatesWhenDue() }
    }

    /// The app's own refresh: at launch and each time it returns to the foreground. Unit tests set
    /// their own rates and call `refreshRates` themselves; a live load started by the app under them
    /// would replace those rates, or be in the way when a test asks for a refresh.
    @MainActor
    func refreshRatesWhenDue() async {
        guard NSClassFromString("XCTestCase") == nil else { return }
        await refreshRates()
    }

    /// Loads live rates when the ones held are more than an hour old. If they can't be loaded, the
    /// rates already held stay: the last ones saved, or the built-in table.
    @MainActor
    func refreshRates(now: Date = Date(), tries: Int = 3) async {
        if let lastUpdated, now.timeIntervalSince(lastUpdated) < 3600 { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        for attempt in 0..<tries {
            if let answer = try? await loadLiveRates(), let rates = Self.usable(answer) {
                exchangeRates = rates
                lastUpdated = now
                UserDefaults.standard.set(rates, forKey: ratesCacheKey)
                UserDefaults.standard.set(now, forKey: ratesDateKey)
                return
            }
            if attempt < tries - 1 {
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        }
    }

    /// An answer is used whole or not at all. It has to be priced in US dollars and cover the world's
    /// currencies: anything else (another base, a partial list) would quietly misprice every total.
    static func usable(_ answer: ExchangeRateResponse) -> [String: Double]? {
        guard answer.base == "USD", answer.rates["USD"] == 1 else { return nil }
        let rates = answer.rates.filter { $0.value.isFinite && $0.value > 0 }
        return rates.count >= 100 ? rates : nil
    }

    /// `amount` in the user's display currency, or nil when there is no rate for `sourceCurrency` (a
    /// code Pausely doesn't know; every currency in the picker converts). Never the unconverted
    /// number: a caller leaves the amount out of a sum, or shows it in its own currency.
    func convertToSelected(_ amount: Decimal, from sourceCurrency: String) -> Decimal? {
        rates.convert(amount, from: sourceCurrency, to: selectedCurrency)
    }

    /// `amount` in `currencyCode` (the display currency when nil). Goes through `MoneyFormat`.
    func format(_ amount: Decimal, currencyCode: String? = nil) -> String {
        MoneyFormat.string(amount, currencyCode ?? selectedCurrency)
    }

    func setCurrency(_ code: String) {
        selectedCurrency = code
        UserDefaults.standard.set(code, forKey: userDefaultsKey)
    }

    /// Every currency someone can choose: what people are charged in today. A retired one
    /// (`CurrencyRates.retired`) is not offered; what was saved in it still converts.
    var allCurrencies: [Currency] {
        currencies
    }

    /// What a currency is today: itself, or what replaced it. Totals chosen in the lev are shown in
    /// euros from 2026, and an iPhone whose system still names the lev for Bulgaria starts in euros.
    nonisolated static func current(_ code: String) -> String {
        CurrencyRates.retired.first { $0.code == code }?.replacedBy ?? code
    }
}

/// A currency someone can choose. Its symbol isn't stored: it depends on who reads it, so it comes
/// from `MoneyFormat.symbol(for:)`.
struct Currency: Identifiable, Hashable {
    let code: String
    /// The English name: what is shown if the system has no name for the code, and searched as well.
    let name: String

    var id: String { code }

    /// The name in the reader's language, from the system ("米ドル", "US-Dollar"), starting with a
    /// capital where the language has them: French and Spanish write currency names in lower case,
    /// which is right inside a sentence and wrong at the head of a row.
    func localizedName(in locale: Locale = L10n.locale) -> String {
        guard let system = locale.localizedString(forCurrencyCode: code), !system.isEmpty else { return name }
        return system.prefix(1).capitalized(with: locale) + system.dropFirst()
    }

    /// Whether typing `query` should find this currency: by its code, by its name in the reader's
    /// language, or by its English name, without minding case or accents ("dolar" finds "Dólar").
    func matches(_ query: String, in locale: Locale = L10n.locale) -> Bool {
        let wanted = query.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return true }
        return [code, localizedName(in: locale), name].contains {
            $0.range(of: wanted, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale) != nil
        }
    }
}

struct ExchangeRateResponse: Decodable {
    let rates: [String: Double]
    let base: String
}
