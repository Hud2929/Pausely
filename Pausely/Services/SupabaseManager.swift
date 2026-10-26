import Foundation
import LocalAuthentication
import SwiftUI
import Supabase
import Auth
import PostgREST
import os.log

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    @Published var isConfigured: Bool = false
    private(set) var isDemoMode = false

    /// Returns true if the app is running in demo mode (no real Supabase credentials configured)
    var isUsingDemoMode: Bool {
        return isDemoMode
    }


    private init() {
        // Use EnvironmentConfig for secure credential management
        // Credentials MUST be set via environment variables or XCConfig files
        guard let supabaseURL = URL(string: EnvironmentConfig.supabaseURL) else {
            os_log("⚠️ Invalid Supabase URL. Running in offline mode.", log: .default, type: .error)
            guard let demoURL = URL(string: "https://demo.supabase.co") else {
                // Ultimate fallback: create a dummy URL that won't crash
                var components = URLComponents()
                components.scheme = "https"
                components.host = "demo.supabase.co"
                let fallbackURL = components.url ?? URL(fileURLWithPath: "/dev/null")
                client = SupabaseClient(supabaseURL: fallbackURL, supabaseKey: "INVALID_DEMO_KEY_NOT_REAL")
                isConfigured = false
                isDemoMode = true
                return
            }
            client = SupabaseClient(supabaseURL: demoURL, supabaseKey: "INVALID_DEMO_KEY_NOT_REAL")
            isConfigured = false
            isDemoMode = true
            return
        }

        let supabaseKey = EnvironmentConfig.supabaseAnonKey

        // Validate credentials are not using placeholders
        if supabaseKey.isEmpty || supabaseKey == "YOUR_SUPABASE_ANON_KEY" {
            os_log("⚠️ Supabase Anon Key not configured. Running in offline mode.", log: .default, type: .error)
            client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: "INVALID_DEMO_KEY_NOT_REAL")
            isConfigured = false
            isDemoMode = true
            return
        }

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        isConfigured = true
        isDemoMode = false

        // Log configuration status (debug only)
        #if DEBUG
        _ = EnvironmentConfig.validate()
        #endif
    }
}

// MARK: - Subscription Record

struct SubscriptionRecord: Codable {
    var id: UUID?
    var user_id: UUID?
    var name: String
    var description: String?
    var logo_url: String?
    var category: String?
    var amount: Decimal
    var currency: String
    var billing_frequency: String
    var next_billing_date: String?
    var monthly_usage_minutes: Int
    var cost_per_hour: Decimal?
    var roi_score: Decimal?
    var waste_score: Decimal?
    var notify_before_days: Int?
    var trial_ends_at: String?
    var status: String
    var is_detected: Bool
    var can_pause: Bool
    var pause_url: String?
    var paused_until: String?
    var created_at: String?
    var updated_at: String?
    
    init(from subscription: Subscription) {
        self.id = subscription.id
        self.name = subscription.name
        self.description = subscription.description
        self.logo_url = subscription.logoUrl
        self.category = subscription.category
        self.amount = subscription.amount
        self.currency = subscription.currency
        self.billing_frequency = subscription.billingFrequency.rawValue
        self.monthly_usage_minutes = subscription.monthlyUsageMinutes
        self.cost_per_hour = subscription.costPerHour
        self.roi_score = subscription.roiScore
        self.waste_score = subscription.wasteScore
        self.notify_before_days = subscription.notifyBeforeDays
        self.trial_ends_at = subscription.trialEndsAt?.iso8601String
        self.status = subscription.status.rawValue
        self.is_detected = subscription.isDetected
        self.can_pause = subscription.canPause
        self.pause_url = subscription.pauseUrl
    }
    
    func toSubscription() -> Subscription {
        var sub = Subscription(
            name: name,
            price: Double(truncating: amount as NSNumber),
            category: category ?? "Other",
            billingFrequency: BillingFrequency(rawValue: billing_frequency) ?? .monthly
        )
        sub.id = id ?? UUID()
        sub.description = description
        sub.logoUrl = logo_url
        sub.amount = amount
        sub.currency = currency
        sub.monthlyUsageMinutes = monthly_usage_minutes
        sub.costPerHour = cost_per_hour
        sub.roiScore = roi_score
        sub.wasteScore = waste_score
        sub.notifyBeforeDays = notify_before_days ?? 3
        sub.trialEndsAt = trial_ends_at?.iso8601Date
        sub.status = SubscriptionStatus(rawValue: status) ?? .active
        sub.isDetected = is_detected
        sub.canPause = can_pause
        sub.pauseUrl = pause_url
        sub.createdAt = created_at?.iso8601Date ?? Date()
        sub.updatedAt = updated_at?.iso8601Date ?? Date()
        return sub
    }
}

// MARK: - Date Extensions

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

extension String {
    var iso8601Date: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: self)
    }
}

// MARK: - Auth Errors
/// Pausely-specific authentication errors
/// Renamed from AuthError to avoid conflict with Supabase library
enum PauselyAuthError: LocalizedError {
    case emailNotConfirmed
    case invalidCredentials
    case sessionExpired
    case networkError
    case biometricFailed
    case invalidResponse
    case ageConsentRequired
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .emailNotConfirmed:
            return "Please verify your email before signing in. Check your inbox for the confirmation link."
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .biometricFailed:
            return "Biometric authentication failed. Please use your password."
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .ageConsentRequired:
            return "Please confirm your age before creating an account."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Auth State
/// Pausely-specific authentication state
/// Renamed from AuthState to avoid conflict with Supabase library
enum PauselyAuthState {
    case initial
    case loading
    case authenticated(User)
    case emailConfirmationRequired(String)
    case unauthenticated
    case error(PauselyAuthError)
}


// MARK: - Currency Error
enum CurrencyError: Error {
    case fetchFailed(Error?)
    case rateNotAvailable
    case parseError
}

// MARK: - Currency Manager
class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()

    @Published var selectedCurrency: String
    /// Live rates per USD as loaded from the API. Conversions use `rates`, which fills any gaps
    /// from `CurrencyRates.fallback` so every currency in the picker always converts.
    @Published var exchangeRates: [String: Double] = [:] {
        didSet { ratesTable = CurrencyRates(apiRates: exchangeRates).fillingGaps() }
    }
    private(set) var ratesTable: CurrencyRates = .fallback
    @Published var lastUpdated: Date?
    @Published var isLoadingRates = false
    @Published var error: Error?

    /// Built-in rates (see `CurrencyRates.fallback`) as the API's `Double`s.
    private var fallbackRates: [String: Double] {
        CurrencyRates.fallback.perUSD.mapValues { NSDecimalNumber(decimal: $0).doubleValue }
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    // MARK: - Compatibility Properties
    
    
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
    
    var currentCurrency: Currency {
        currencies.first { $0.code == selectedCurrency } ?? Currency(code: "USD", name: "US Dollar", flag: "🇺🇸", locale: "en_US")
    }
    
    private init() {
        let deviceCurrency = Locale.current.currency?.identifier ?? "USD"
        let offered = Set(currencies.map(\.code))
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey), offered.contains(saved) {
            selectedCurrency = saved
        } else {
            selectedCurrency = offered.contains(deviceCurrency) ? deviceCurrency : "USD"
        }

        self.exchangeRates = loadCachedRates() ?? fallbackRates
        self.ratesTable = CurrencyRates(apiRates: exchangeRates).fillingGaps()

        Task {
            try? await fetchExchangeRates()
        }
    }
    
    func fetchExchangeRates() async throws -> [String: Double] {
        if let lastUpdated = lastUpdated,
           Date().timeIntervalSince(lastUpdated) < 3600 {
            return exchangeRates
        }

        isLoadingRates = true
        defer { isLoadingRates = false }

        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let rates = try await performFetch()
                exchangeRates = rates
                lastUpdated = Date()
                error = nil
                cacheRates()
                return rates
            } catch {
                lastError = error
                if attempt < 2 {
                    let delay = pow(2.0, Double(attempt)) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: UInt64(delay))
                }
            }
        }

        if let cached = loadCachedRates() {
            return cached
        }
        // Use hardcoded fallback rates so prices are never wrong
        exchangeRates = fallbackRates
        lastUpdated = Date(timeIntervalSince1970: 0) // Mark as fallback
        return fallbackRates
    }

    private func performFetch() async throws -> [String: Double] {
        let urlString = "https://api.exchangerate-api.com/v4/latest/USD"

        guard let url = URL(string: urlString) else {
            throw CurrencyError.fetchFailed(nil)
        }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
        return response.rates
    }

    private func loadCachedRates() -> [String: Double]? {
        var result = fallbackRates
        if let cached = UserDefaults.standard.dictionary(forKey: ratesCacheKey) as? [String: Double] {
            lastUpdated = UserDefaults.standard.object(forKey: ratesDateKey) as? Date
            for (code, rate) in cached {
                result[code] = rate
            }
        }
        return result
    }
    
    private func cacheRates() {
        UserDefaults.standard.set(exchangeRates, forKey: ratesCacheKey)
        UserDefaults.standard.set(lastUpdated, forKey: ratesDateKey)
    }

    func convert(_ amount: Decimal, from sourceCurrency: String, to targetCurrency: String) throws -> Decimal {
        guard let converted = rates.convert(amount, from: sourceCurrency, to: targetCurrency) else {
            throw CurrencyError.rateNotAvailable
        }
        return converted
    }

    /// `amount` in the user's display currency. A currency Pausely can't convert (not an ISO code it
    /// knows) comes back unchanged and is logged; every currency in the picker always converts.
    func convertToSelected(_ amount: Decimal, from sourceCurrency: String) -> Decimal {
        if let converted = rates.convert(amount, from: sourceCurrency, to: selectedCurrency) { return converted }
        os_log("CurrencyManager: no rate for %{public}@", log: .default, type: .error, sourceCurrency)
        return amount
    }

    // MARK: - Catalog Price Helpers

    /// A catalog price (catalog prices are in US dollars) in the user's display currency.
    func convertFromUSD(_ priceUSD: Double) -> Double {
        convertCrossCurrency(priceUSD, from: "USD", to: selectedCurrency)
    }

    /// A catalog price in the user's display currency, converted when it is in another currency.
    func formatCatalogPrice(_ price: Double, sourceCurrency: String = "USD") -> String {
        let converted = convertCrossCurrency(price, from: sourceCurrency, to: selectedCurrency)
        return MoneyFormat.string(converted, selectedCurrency)
    }

    /// Converts between two currencies; an amount Pausely can't convert comes back unchanged.
    func convertCrossCurrency(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) -> Double {
        guard let converted = rates.convert(MoneyFormat.decimal(amount), from: sourceCurrency, to: targetCurrency) else {
            return amount
        }
        return NSDecimalNumber(decimal: converted).doubleValue
    }

    /// "≈" in front of catalog prices shown in a currency other than the catalog's US dollars.
    var priceIndicator: String {
        selectedCurrency == "USD" ? "" : "≈"
    }

    /// `amount` in `currencyCode` (the display currency when nil). Goes through `MoneyFormat`.
    func format(_ amount: Decimal, currencyCode: String? = nil) -> String {
        MoneyFormat.string(amount, currencyCode ?? selectedCurrency)
    }
    
    /// The symbol the user's locale shows for `code` ("$", "US$", "€"). Unknown codes show as the code.
    func currencySymbol(for code: String) -> String {
        MoneyFormat.symbol(for: code)
    }
    
    func currencyFlag(for code: String) -> String {
        currencies.first { $0.code == code }?.flag ?? "🏳️"
    }
    
    func setCurrency(_ code: String) {
        selectedCurrency = code
        UserDefaults.standard.set(code, forKey: userDefaultsKey)
        NotificationCenter.default.post(name: .currencyChanged, object: code)
    }
    
    
    /// Get currency by code
    func currency(for code: String) -> Currency? {
        currencies.first { $0.code == code }
    }
    
    /// All available currencies
    var allCurrencies: [Currency] {
        currencies
    }
    
    /// Convert Double amount (overload for convenience)
    func convert(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) throws -> Double {
        let converted = try convert(MoneyFormat.decimal(amount), from: sourceCurrency, to: targetCurrency)
        return NSDecimalNumber(decimal: converted).doubleValue
    }

    /// Get exchange rate between two currencies
    func getRate(from sourceCode: String, to targetCode: String) throws -> Double {
        try convert(1.0, from: sourceCode, to: targetCode)
    }
}

// MARK: - Supporting Types
/// A currency someone can choose. Its symbol isn't stored: it depends on who reads it, so it comes
/// from `MoneyFormat.symbol(for:)`.
struct Currency: Identifiable, Codable, Hashable {
    var id = UUID()
    let code: String
    let name: String
    let flag: String
    let locale: String
    
    var displayName: String {
        "\(flag) \(code) - \(name)"
    }
    
    func format(_ amount: Double) -> String {
        MoneyFormat.string(amount, code)
    }
}

struct ExchangeRateResponse: Codable {
    let rates: [String: Double]
    let base: String
    let date: String
}

extension Notification.Name {
    static let currencyChanged = Notification.Name("currencyChanged")
}


// MARK: - Additional Database Models


// MARK: - Waitlist Model


