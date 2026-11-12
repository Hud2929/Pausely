import Foundation
import Combine
import os

/// The display currency and the live exchange rates.
///
/// Everything published here changes on the main thread only: the screens read it there. The rates
/// table every conversion uses can also be read from anywhere, so it sits behind a lock.
final class CurrencyManager: ObservableObject {
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
        Currency(code: "USD", name: "US Dollar", flag: "🇺🇸", locale: "en_US"),
        Currency(code: "EUR", name: "Euro", flag: "🇪🇺", locale: "de_DE"),
        Currency(code: "GBP", name: "British Pound", flag: "🇬🇧", locale: "en_GB"),
        Currency(code: "JPY", name: "Japanese Yen", flag: "🇯🇵", locale: "ja_JP"),
        Currency(code: "CNY", name: "Chinese Yuan", flag: "🇨🇳", locale: "zh_CN"),
        
        // Americas
        Currency(code: "CAD", name: "Canadian Dollar", flag: "🇨🇦", locale: "en_CA"),
        Currency(code: "MXN", name: "Mexican Peso", flag: "🇲🇽", locale: "es_MX"),
        Currency(code: "BRL", name: "Brazilian Real", flag: "🇧🇷", locale: "pt_BR"),
        Currency(code: "ARS", name: "Argentine Peso", flag: "🇦🇷", locale: "es_AR"),
        Currency(code: "CLP", name: "Chilean Peso", flag: "🇨🇱", locale: "es_CL"),
        Currency(code: "COP", name: "Colombian Peso", flag: "🇨🇴", locale: "es_CO"),
        Currency(code: "PEN", name: "Peruvian Sol", flag: "🇵🇪", locale: "es_PE"),
        Currency(code: "UYU", name: "Uruguayan Peso", flag: "🇺🇾", locale: "es_UY"),
        Currency(code: "DOP", name: "Dominican Peso", flag: "🇩🇴", locale: "es_DO"),
        Currency(code: "CRC", name: "Costa Rican Colón", flag: "🇨🇷", locale: "es_CR"),
        Currency(code: "GTQ", name: "Guatemalan Quetzal", flag: "🇬🇹", locale: "es_GT"),
        Currency(code: "HNL", name: "Honduran Lempira", flag: "🇭🇳", locale: "es_HN"),
        Currency(code: "NIO", name: "Nicaraguan Córdoba", flag: "🇳🇮", locale: "es_NI"),
        Currency(code: "PAB", name: "Panamanian Balboa", flag: "🇵🇦", locale: "es_PA"),
        Currency(code: "BOB", name: "Bolivian Boliviano", flag: "🇧🇴", locale: "es_BO"),
        Currency(code: "PYG", name: "Paraguayan Guaraní", flag: "🇵🇾", locale: "es_PY"),
        Currency(code: "VES", name: "Venezuelan Bolívar", flag: "🇻🇪", locale: "es_VE"),
        Currency(code: "XCD", name: "Eastern Caribbean Dollar", flag: "🇦🇬", locale: "en_AG"),
        Currency(code: "TTD", name: "Trinidad & Tobago Dollar", flag: "🇹🇹", locale: "en_TT"),
        Currency(code: "JMD", name: "Jamaican Dollar", flag: "🇯🇲", locale: "en_JM"),
        Currency(code: "BBD", name: "Barbadian Dollar", flag: "🇧🇧", locale: "en_BB"),
        Currency(code: "BSD", name: "Bahamian Dollar", flag: "🇧🇸", locale: "en_BS"),
        Currency(code: "BZD", name: "Belize Dollar", flag: "🇧🇿", locale: "en_BZ"),
        Currency(code: "KYD", name: "Cayman Islands Dollar", flag: "🇰🇾", locale: "en_KY"),
        Currency(code: "BMD", name: "Bermudian Dollar", flag: "🇧🇲", locale: "en_BM"),
        Currency(code: "GYD", name: "Guyanese Dollar", flag: "🇬🇾", locale: "en_GY"),
        Currency(code: "SRD", name: "Surinamese Dollar", flag: "🇸🇷", locale: "nl_SR"),
        
        // Europe
        Currency(code: "CHF", name: "Swiss Franc", flag: "🇨🇭", locale: "de_CH"),
        Currency(code: "SEK", name: "Swedish Krona", flag: "🇸🇪", locale: "sv_SE"),
        Currency(code: "NOK", name: "Norwegian Krone", flag: "🇳🇴", locale: "nb_NO"),
        Currency(code: "DKK", name: "Danish Krone", flag: "🇩🇰", locale: "da_DK"),
        Currency(code: "PLN", name: "Polish Złoty", flag: "🇵🇱", locale: "pl_PL"),
        Currency(code: "CZK", name: "Czech Koruna", flag: "🇨🇿", locale: "cs_CZ"),
        Currency(code: "HUF", name: "Hungarian Forint", flag: "🇭🇺", locale: "hu_HU"),
        Currency(code: "RON", name: "Romanian Leu", flag: "🇷🇴", locale: "ro_RO"),
        Currency(code: "BGN", name: "Bulgarian Lev", flag: "🇧🇬", locale: "bg_BG"),
        Currency(code: "RSD", name: "Serbian Dinar", flag: "🇷🇸", locale: "sr_RS"),
        Currency(code: "ISK", name: "Icelandic Króna", flag: "🇮🇸", locale: "is_IS"),
        Currency(code: "UAH", name: "Ukrainian Hryvnia", flag: "🇺🇦", locale: "uk_UA"),
        Currency(code: "RUB", name: "Russian Ruble", flag: "🇷🇺", locale: "ru_RU"),
        Currency(code: "BYN", name: "Belarusian Ruble", flag: "🇧🇾", locale: "be_BY"),
        Currency(code: "MDL", name: "Moldovan Leu", flag: "🇲🇩", locale: "ro_MD"),
        Currency(code: "GIP", name: "Gibraltar Pound", flag: "🇬🇮", locale: "en_GI"),
        Currency(code: "ALL", name: "Albanian Lek", flag: "🇦🇱", locale: "sq_AL"),
        Currency(code: "BAM", name: "Bosnia Mark", flag: "🇧🇦", locale: "bs_BA"),
        Currency(code: "MKD", name: "Macedonian Denar", flag: "🇲🇰", locale: "mk_MK"),
        Currency(code: "GEL", name: "Georgian Lari", flag: "🇬🇪", locale: "ka_GE"),
        Currency(code: "AZN", name: "Azerbaijani Manat", flag: "🇦🇿", locale: "az_AZ"),
        Currency(code: "AMD", name: "Armenian Dram", flag: "🇦🇲", locale: "hy_AM"),
        
        // Asia Pacific
        Currency(code: "AUD", name: "Australian Dollar", flag: "🇦🇺", locale: "en_AU"),
        Currency(code: "NZD", name: "New Zealand Dollar", flag: "🇳🇿", locale: "en_NZ"),
        Currency(code: "SGD", name: "Singapore Dollar", flag: "🇸🇬", locale: "en_SG"),
        Currency(code: "HKD", name: "Hong Kong Dollar", flag: "🇭🇰", locale: "zh_HK"),
        Currency(code: "KRW", name: "South Korean Won", flag: "🇰🇷", locale: "ko_KR"),
        Currency(code: "INR", name: "Indian Rupee", flag: "🇮🇳", locale: "hi_IN"),
        Currency(code: "IDR", name: "Indonesian Rupiah", flag: "🇮🇩", locale: "id_ID"),
        Currency(code: "MYR", name: "Malaysian Ringgit", flag: "🇲🇾", locale: "ms_MY"),
        Currency(code: "THB", name: "Thai Baht", flag: "🇹🇭", locale: "th_TH"),
        Currency(code: "PHP", name: "Philippine Peso", flag: "🇵🇭", locale: "fil_PH"),
        Currency(code: "VND", name: "Vietnamese Dong", flag: "🇻🇳", locale: "vi_VN"),
        Currency(code: "TWD", name: "Taiwan Dollar", flag: "🇹🇼", locale: "zh_TW"),
        Currency(code: "PKR", name: "Pakistani Rupee", flag: "🇵🇰", locale: "ur_PK"),
        Currency(code: "BDT", name: "Bangladeshi Taka", flag: "🇧🇩", locale: "bn_BD"),
        Currency(code: "LKR", name: "Sri Lankan Rupee", flag: "🇱🇰", locale: "si_LK"),
        Currency(code: "NPR", name: "Nepalese Rupee", flag: "🇳🇵", locale: "ne_NP"),
        Currency(code: "MMK", name: "Myanmar Kyat", flag: "🇲🇲", locale: "my_MM"),
        Currency(code: "KHR", name: "Cambodian Riel", flag: "🇰🇭", locale: "km_KH"),
        Currency(code: "LAK", name: "Lao Kip", flag: "🇱🇦", locale: "lo_LA"),
        Currency(code: "MOP", name: "Macanese Pataca", flag: "🇲🇴", locale: "zh_MO"),
        Currency(code: "BND", name: "Brunei Dollar", flag: "🇧🇳", locale: "ms_BN"),
        Currency(code: "PGK", name: "Papua New Guinean Kina", flag: "🇵🇬", locale: "en_PG"),
        Currency(code: "FJD", name: "Fijian Dollar", flag: "🇫🇯", locale: "en_FJ"),
        Currency(code: "WST", name: "Samoan Tala", flag: "🇼🇸", locale: "en_WS"),
        Currency(code: "TOP", name: "Tongan Paʻanga", flag: "🇹🇴", locale: "to_TO"),
        Currency(code: "VUV", name: "Vanuatu Vatu", flag: "🇻🇺", locale: "bi_VU"),
        Currency(code: "SBD", name: "Solomon Islands Dollar", flag: "🇸🇧", locale: "en_SB"),
        Currency(code: "MVR", name: "Maldivian Rufiyaa", flag: "🇲🇻", locale: "dv_MV"),
        Currency(code: "BTN", name: "Bhutanese Ngultrum", flag: "🇧🇹", locale: "dz_BT"),
        Currency(code: "MNT", name: "Mongolian Tugrik", flag: "🇲🇳", locale: "mn_MN"),
        Currency(code: "KZT", name: "Kazakhstani Tenge", flag: "🇰🇿", locale: "kk_KZ"),
        Currency(code: "KGS", name: "Kyrgyzstani Som", flag: "🇰🇬", locale: "ky_KG"),
        Currency(code: "TJS", name: "Tajikistani Somoni", flag: "🇹🇯", locale: "tg_TJ"),
        Currency(code: "UZS", name: "Uzbekistani Som", flag: "🇺🇿", locale: "uz_UZ"),
        Currency(code: "AFN", name: "Afghan Afghani", flag: "🇦🇫", locale: "ps_AF"),
        
        // Middle East & Africa
        Currency(code: "AED", name: "UAE Dirham", flag: "🇦🇪", locale: "ar_AE"),
        Currency(code: "SAR", name: "Saudi Riyal", flag: "🇸🇦", locale: "ar_SA"),
        Currency(code: "QAR", name: "Qatari Riyal", flag: "🇶🇦", locale: "ar_QA"),
        Currency(code: "KWD", name: "Kuwaiti Dinar", flag: "🇰🇼", locale: "ar_KW"),
        Currency(code: "BHD", name: "Bahraini Dinar", flag: "🇧🇭", locale: "ar_BH"),
        Currency(code: "OMR", name: "Omani Rial", flag: "🇴🇲", locale: "ar_OM"),
        Currency(code: "ILS", name: "Israeli Shekel", flag: "🇮🇱", locale: "he_IL"),
        Currency(code: "JOD", name: "Jordanian Dinar", flag: "🇯🇴", locale: "ar_JO"),
        Currency(code: "LBP", name: "Lebanese Pound", flag: "🇱🇧", locale: "ar_LB"),
        Currency(code: "EGP", name: "Egyptian Pound", flag: "🇪🇬", locale: "ar_EG"),
        Currency(code: "ZAR", name: "South African Rand", flag: "🇿🇦", locale: "en_ZA"),
        Currency(code: "NGN", name: "Nigerian Naira", flag: "🇳🇬", locale: "en_NG"),
        Currency(code: "KES", name: "Kenyan Shilling", flag: "🇰🇪", locale: "en_KE"),
        Currency(code: "GHS", name: "Ghanaian Cedi", flag: "🇬🇭", locale: "en_GH"),
        Currency(code: "MAD", name: "Moroccan Dirham", flag: "🇲🇦", locale: "ar_MA"),
        Currency(code: "TND", name: "Tunisian Dinar", flag: "🇹🇳", locale: "ar_TN"),
        Currency(code: "DZD", name: "Algerian Dinar", flag: "🇩🇿", locale: "ar_DZ"),
        Currency(code: "ETB", name: "Ethiopian Birr", flag: "🇪🇹", locale: "am_ET"),
        Currency(code: "TZS", name: "Tanzanian Shilling", flag: "🇹🇿", locale: "sw_TZ"),
        Currency(code: "UGX", name: "Ugandan Shilling", flag: "🇺🇬", locale: "en_UG"),
        Currency(code: "ZMW", name: "Zambian Kwacha", flag: "🇿🇲", locale: "en_ZM"),
        Currency(code: "BWP", name: "Botswana Pula", flag: "🇧🇼", locale: "en_BW"),
        Currency(code: "MUR", name: "Mauritian Rupee", flag: "🇲🇺", locale: "en_MU"),
        Currency(code: "SCR", name: "Seychellois Rupee", flag: "🇸🇨", locale: "en_SC"),
        Currency(code: "XOF", name: "West African CFA Franc", flag: "🇸🇳", locale: "fr_SN"),
        Currency(code: "XAF", name: "Central African CFA Franc", flag: "🇨🇲", locale: "fr_CM"),
        Currency(code: "ERN", name: "Eritrean Nakfa", flag: "🇪🇷", locale: "ti_ER"),
        Currency(code: "SZL", name: "Eswatini Lilangeni", flag: "🇸🇿", locale: "en_SZ"),
        Currency(code: "LSL", name: "Lesotho Loti", flag: "🇱🇸", locale: "en_LS"),
        Currency(code: "NAD", name: "Namibian Dollar", flag: "🇳🇦", locale: "en_NA"),
        Currency(code: "MZN", name: "Mozambican Metical", flag: "🇲🇿", locale: "pt_MZ"),
        Currency(code: "MWK", name: "Malawian Kwacha", flag: "🇲🇼", locale: "en_MW"),
        Currency(code: "RWF", name: "Rwandan Franc", flag: "🇷🇼", locale: "rw_RW"),
        Currency(code: "SLL", name: "Sierra Leonean Leone", flag: "🇸🇱", locale: "en_SL"),
        Currency(code: "SOS", name: "Somali Shilling", flag: "🇸🇴", locale: "so_SO"),
        Currency(code: "SDG", name: "Sudanese Pound", flag: "🇸🇩", locale: "ar_SD"),
        Currency(code: "TMT", name: "Turkmenistani Manat", flag: "🇹🇲", locale: "tk_TM"),
        Currency(code: "IRR", name: "Iranian Rial", flag: "🇮🇷", locale: "fa_IR"),
        Currency(code: "IQD", name: "Iraqi Dinar", flag: "🇮🇶", locale: "ar_IQ"),
        Currency(code: "YER", name: "Yemeni Rial", flag: "🇾🇪", locale: "ar_YE"),
        Currency(code: "SYP", name: "Syrian Pound", flag: "🇸🇾", locale: "ar_SY"),
        Currency(code: "TRY", name: "Turkish Lira", flag: "🇹🇷", locale: "tr_TR"),
    ]

    private let userDefaultsKey = "selected_currency"
    private let ratesCacheKey = "cached_exchange_rates"
    private let ratesDateKey = "exchange_rates_date"

    private init() {
        let deviceCurrency = Locale.current.currency?.identifier ?? "USD"
        let offered = Set(currencies.map(\.code))
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey), offered.contains(saved) {
            selectedCurrency = saved
        } else {
            selectedCurrency = offered.contains(deviceCurrency) ? deviceCurrency : "USD"
        }

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

    /// All available currencies
    var allCurrencies: [Currency] {
        currencies
    }
}

/// A currency someone can choose. Its symbol isn't stored: it depends on who reads it, so it comes
/// from `MoneyFormat.symbol(for:)`.
struct Currency: Identifiable, Codable, Hashable {
    var id = UUID()
    let code: String
    let name: String
    let flag: String
    let locale: String
}

struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
    let base: String
    let date: String
}
