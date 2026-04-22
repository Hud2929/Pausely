import Foundation
import LocalAuthentication
import SwiftUI
import Supabase
import Auth
import PostgREST

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    private(set) var isConfigured = false
    private(set) var isDemoMode = false

    /// Returns true if the app is running in demo mode (no real Supabase credentials configured)
    var isUsingDemoMode: Bool {
        return isDemoMode
    }

    private init() {
        // Use EnvironmentConfig for secure credential management
        // Credentials MUST be set via environment variables or XCConfig files
        guard let supabaseURL = URL(string: EnvironmentConfig.supabaseURL) else {
            print("⚠️ Invalid Supabase URL. Running in offline mode.")
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
            print("⚠️ Supabase Anon Key not configured. Running in offline mode.")
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

// MARK: - Notifications
extension Notification.Name {
    static let biometricAuthSuccess = Notification.Name("biometricAuthSuccess")
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
    @Published var exchangeRates: [String: Double] = [:]
    @Published var lastUpdated: Date?
    @Published var isLoadingRates = false
    @Published var error: Error?

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    // MARK: - Compatibility Properties
    var lastUpdateTime: Date? { lastUpdated }
    var isOffline: Bool { error != nil }
    var isRateStale: Bool {
        guard let lastUpdated = lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > 3600 * 24 // 24 hours
    }
    
    /// Get currently selected currency object
    var selectedCurrencyObject: Currency {
        currencies.first { $0.code == selectedCurrency } ?? Currency(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸", locale: "en_US")
    }
    
    let currencies: [Currency] = [
        // Major Global Currencies
        Currency(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸", locale: "en_US"),
        Currency(code: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺", locale: "de_DE"),
        Currency(code: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧", locale: "en_GB"),
        Currency(code: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵", locale: "ja_JP"),
        Currency(code: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳", locale: "zh_CN"),
        
        // Americas
        Currency(code: "CAD", name: "Canadian Dollar", symbol: "C$", flag: "🇨🇦", locale: "en_CA"),
        Currency(code: "MXN", name: "Mexican Peso", symbol: "$", flag: "🇲🇽", locale: "es_MX"),
        Currency(code: "BRL", name: "Brazilian Real", symbol: "R$", flag: "🇧🇷", locale: "pt_BR"),
        Currency(code: "ARS", name: "Argentine Peso", symbol: "$", flag: "🇦🇷", locale: "es_AR"),
        Currency(code: "CLP", name: "Chilean Peso", symbol: "$", flag: "🇨🇱", locale: "es_CL"),
        Currency(code: "COP", name: "Colombian Peso", symbol: "$", flag: "🇨🇴", locale: "es_CO"),
        Currency(code: "PEN", name: "Peruvian Sol", symbol: "S/", flag: "🇵🇪", locale: "es_PE"),
        Currency(code: "UYU", name: "Uruguayan Peso", symbol: "$", flag: "🇺🇾", locale: "es_UY"),
        Currency(code: "DOP", name: "Dominican Peso", symbol: "RD$", flag: "🇩🇴", locale: "es_DO"),
        Currency(code: "CRC", name: "Costa Rican Colón", symbol: "₡", flag: "🇨🇷", locale: "es_CR"),
        Currency(code: "GTQ", name: "Guatemalan Quetzal", symbol: "Q", flag: "🇬🇹", locale: "es_GT"),
        Currency(code: "HNL", name: "Honduran Lempira", symbol: "L", flag: "🇭🇳", locale: "es_HN"),
        Currency(code: "NIO", name: "Nicaraguan Córdoba", symbol: "C$", flag: "🇳🇮", locale: "es_NI"),
        Currency(code: "PAB", name: "Panamanian Balboa", symbol: "B/.", flag: "🇵🇦", locale: "es_PA"),
        Currency(code: "BOB", name: "Bolivian Boliviano", symbol: "Bs", flag: "🇧🇴", locale: "es_BO"),
        Currency(code: "PYG", name: "Paraguayan Guaraní", symbol: "₲", flag: "🇵🇾", locale: "es_PY"),
        Currency(code: "VES", name: "Venezuelan Bolívar", symbol: "Bs", flag: "🇻🇪", locale: "es_VE"),
        Currency(code: "XCD", name: "Eastern Caribbean Dollar", symbol: "EC$", flag: "🇦🇬", locale: "en_AG"),
        Currency(code: "TTD", name: "Trinidad & Tobago Dollar", symbol: "TT$", flag: "🇹🇹", locale: "en_TT"),
        Currency(code: "JMD", name: "Jamaican Dollar", symbol: "J$", flag: "🇯🇲", locale: "en_JM"),
        Currency(code: "BBD", name: "Barbadian Dollar", symbol: "Bds$", flag: "🇧🇧", locale: "en_BB"),
        Currency(code: "BSD", name: "Bahamian Dollar", symbol: "B$", flag: "🇧🇸", locale: "en_BS"),
        Currency(code: "BZD", name: "Belize Dollar", symbol: "BZ$", flag: "🇧🇿", locale: "en_BZ"),
        Currency(code: "KYD", name: "Cayman Islands Dollar", symbol: "CI$", flag: "🇰🇾", locale: "en_KY"),
        Currency(code: "BMD", name: "Bermudian Dollar", symbol: "BD$", flag: "🇧🇲", locale: "en_BM"),
        Currency(code: "GYD", name: "Guyanese Dollar", symbol: "G$", flag: "🇬🇾", locale: "en_GY"),
        Currency(code: "SRD", name: "Surinamese Dollar", symbol: "SRD", flag: "🇸🇷", locale: "nl_SR"),
        
        // Europe
        Currency(code: "CHF", name: "Swiss Franc", symbol: "Fr", flag: "🇨🇭", locale: "de_CH"),
        Currency(code: "SEK", name: "Swedish Krona", symbol: "kr", flag: "🇸🇪", locale: "sv_SE"),
        Currency(code: "NOK", name: "Norwegian Krone", symbol: "kr", flag: "🇳🇴", locale: "nb_NO"),
        Currency(code: "DKK", name: "Danish Krone", symbol: "kr", flag: "🇩🇰", locale: "da_DK"),
        Currency(code: "PLN", name: "Polish Złoty", symbol: "zł", flag: "🇵🇱", locale: "pl_PL"),
        Currency(code: "CZK", name: "Czech Koruna", symbol: "Kč", flag: "🇨🇿", locale: "cs_CZ"),
        Currency(code: "HUF", name: "Hungarian Forint", symbol: "Ft", flag: "🇭🇺", locale: "hu_HU"),
        Currency(code: "RON", name: "Romanian Leu", symbol: "lei", flag: "🇷🇴", locale: "ro_RO"),
        Currency(code: "BGN", name: "Bulgarian Lev", symbol: "лв", flag: "🇧🇬", locale: "bg_BG"),
        Currency(code: "HRK", name: "Croatian Kuna", symbol: "kn", flag: "🇭🇷", locale: "hr_HR"),
        Currency(code: "RSD", name: "Serbian Dinar", symbol: "дин", flag: "🇷🇸", locale: "sr_RS"),
        Currency(code: "ISK", name: "Icelandic Króna", symbol: "kr", flag: "🇮🇸", locale: "is_IS"),
        Currency(code: "UAH", name: "Ukrainian Hryvnia", symbol: "₴", flag: "🇺🇦", locale: "uk_UA"),
        Currency(code: "RUB", name: "Russian Ruble", symbol: "₽", flag: "🇷🇺", locale: "ru_RU"),
        Currency(code: "BYN", name: "Belarusian Ruble", symbol: "Br", flag: "🇧🇾", locale: "be_BY"),
        Currency(code: "MDL", name: "Moldovan Leu", symbol: "L", flag: "🇲🇩", locale: "ro_MD"),
        Currency(code: "GIP", name: "Gibraltar Pound", symbol: "£", flag: "🇬🇮", locale: "en_GI"),
        Currency(code: "ALL", name: "Albanian Lek", symbol: "L", flag: "🇦🇱", locale: "sq_AL"),
        Currency(code: "BAM", name: "Bosnia Mark", symbol: "KM", flag: "🇧🇦", locale: "bs_BA"),
        Currency(code: "MKD", name: "Macedonian Denar", symbol: "ден", flag: "🇲🇰", locale: "mk_MK"),
        Currency(code: "GEL", name: "Georgian Lari", symbol: "₾", flag: "🇬🇪", locale: "ka_GE"),
        Currency(code: "AZN", name: "Azerbaijani Manat", symbol: "₼", flag: "🇦🇿", locale: "az_AZ"),
        Currency(code: "AMD", name: "Armenian Dram", symbol: "֏", flag: "🇦🇲", locale: "hy_AM"),
        
        // Asia Pacific
        Currency(code: "AUD", name: "Australian Dollar", symbol: "A$", flag: "🇦🇺", locale: "en_AU"),
        Currency(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$", flag: "🇳🇿", locale: "en_NZ"),
        Currency(code: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "🇸🇬", locale: "en_SG"),
        Currency(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$", flag: "🇭🇰", locale: "zh_HK"),
        Currency(code: "KRW", name: "South Korean Won", symbol: "₩", flag: "🇰🇷", locale: "ko_KR"),
        Currency(code: "INR", name: "Indian Rupee", symbol: "₹", flag: "🇮🇳", locale: "hi_IN"),
        Currency(code: "IDR", name: "Indonesian Rupiah", symbol: "Rp", flag: "🇮🇩", locale: "id_ID"),
        Currency(code: "MYR", name: "Malaysian Ringgit", symbol: "RM", flag: "🇲🇾", locale: "ms_MY"),
        Currency(code: "THB", name: "Thai Baht", symbol: "฿", flag: "🇹🇭", locale: "th_TH"),
        Currency(code: "PHP", name: "Philippine Peso", symbol: "₱", flag: "🇵🇭", locale: "fil_PH"),
        Currency(code: "VND", name: "Vietnamese Dong", symbol: "₫", flag: "🇻🇳", locale: "vi_VN"),
        Currency(code: "TWD", name: "Taiwan Dollar", symbol: "NT$", flag: "🇹🇼", locale: "zh_TW"),
        Currency(code: "PKR", name: "Pakistani Rupee", symbol: "₨", flag: "🇵🇰", locale: "ur_PK"),
        Currency(code: "BDT", name: "Bangladeshi Taka", symbol: "৳", flag: "🇧🇩", locale: "bn_BD"),
        Currency(code: "LKR", name: "Sri Lankan Rupee", symbol: "Rs", flag: "🇱🇰", locale: "si_LK"),
        Currency(code: "NPR", name: "Nepalese Rupee", symbol: "₨", flag: "🇳🇵", locale: "ne_NP"),
        Currency(code: "MMK", name: "Myanmar Kyat", symbol: "K", flag: "🇲🇲", locale: "my_MM"),
        Currency(code: "KHR", name: "Cambodian Riel", symbol: "៛", flag: "🇰🇭", locale: "km_KH"),
        Currency(code: "LAK", name: "Lao Kip", symbol: "₭", flag: "🇱🇦", locale: "lo_LA"),
        Currency(code: "MOP", name: "Macanese Pataca", symbol: "MOP$", flag: "🇲🇴", locale: "zh_MO"),
        Currency(code: "BND", name: "Brunei Dollar", symbol: "B$", flag: "🇧🇳", locale: "ms_BN"),
        Currency(code: "PGK", name: "Papua New Guinean Kina", symbol: "K", flag: "🇵🇬", locale: "en_PG"),
        Currency(code: "FJD", name: "Fijian Dollar", symbol: "FJ$", flag: "🇫🇯", locale: "en_FJ"),
        Currency(code: "WST", name: "Samoan Tala", symbol: "T", flag: "🇼🇸", locale: "en_WS"),
        Currency(code: "TOP", name: "Tongan Paʻanga", symbol: "T$", flag: "🇹🇴", locale: "to_TO"),
        Currency(code: "VUV", name: "Vanuatu Vatu", symbol: "VT", flag: "🇻🇺", locale: "bi_VU"),
        Currency(code: "SBD", name: "Solomon Islands Dollar", symbol: "SI$", flag: "🇸🇧", locale: "en_SB"),
        Currency(code: "KID", name: "Kiribati Dollar", symbol: "$", flag: "🇰🇮", locale: "en_KI"),
        Currency(code: "MVR", name: "Maldivian Rufiyaa", symbol: "Rf", flag: "🇲🇻", locale: "dv_MV"),
        Currency(code: "BTN", name: "Bhutanese Ngultrum", symbol: "Nu.", flag: "🇧🇹", locale: "dz_BT"),
        Currency(code: "MNT", name: "Mongolian Tugrik", symbol: "₮", flag: "🇲🇳", locale: "mn_MN"),
        Currency(code: "KZT", name: "Kazakhstani Tenge", symbol: "₸", flag: "🇰🇿", locale: "kk_KZ"),
        Currency(code: "KGS", name: "Kyrgyzstani Som", symbol: "с", flag: "🇰🇬", locale: "ky_KG"),
        Currency(code: "TJS", name: "Tajikistani Somoni", symbol: "ЅМ", flag: "🇹🇯", locale: "tg_TJ"),
        Currency(code: "UZS", name: "Uzbekistani Som", symbol: "so'm", flag: "🇺🇿", locale: "uz_UZ"),
        Currency(code: "AFN", name: "Afghan Afghani", symbol: "؋", flag: "🇦🇫", locale: "ps_AF"),
        
        // Middle East & Africa
        Currency(code: "AED", name: "UAE Dirham", symbol: "د.إ", flag: "🇦🇪", locale: "ar_AE"),
        Currency(code: "SAR", name: "Saudi Riyal", symbol: "﷼", flag: "🇸🇦", locale: "ar_SA"),
        Currency(code: "QAR", name: "Qatari Riyal", symbol: "﷼", flag: "🇶🇦", locale: "ar_QA"),
        Currency(code: "KWD", name: "Kuwaiti Dinar", symbol: "د.ك", flag: "🇰🇼", locale: "ar_KW"),
        Currency(code: "BHD", name: "Bahraini Dinar", symbol: "د.ب", flag: "🇧🇭", locale: "ar_BH"),
        Currency(code: "OMR", name: "Omani Rial", symbol: "﷼", flag: "🇴🇲", locale: "ar_OM"),
        Currency(code: "ILS", name: "Israeli Shekel", symbol: "₪", flag: "🇮🇱", locale: "he_IL"),
        Currency(code: "JOD", name: "Jordanian Dinar", symbol: "د.ا", flag: "🇯🇴", locale: "ar_JO"),
        Currency(code: "LBP", name: "Lebanese Pound", symbol: "ل.ل", flag: "🇱🇧", locale: "ar_LB"),
        Currency(code: "EGP", name: "Egyptian Pound", symbol: "£", flag: "🇪🇬", locale: "ar_EG"),
        Currency(code: "ZAR", name: "South African Rand", symbol: "R", flag: "🇿🇦", locale: "en_ZA"),
        Currency(code: "NGN", name: "Nigerian Naira", symbol: "₦", flag: "🇳🇬", locale: "en_NG"),
        Currency(code: "KES", name: "Kenyan Shilling", symbol: "KSh", flag: "🇰🇪", locale: "en_KE"),
        Currency(code: "GHS", name: "Ghanaian Cedi", symbol: "₵", flag: "🇬🇭", locale: "en_GH"),
        Currency(code: "MAD", name: "Moroccan Dirham", symbol: "د.م.", flag: "🇲🇦", locale: "ar_MA"),
        Currency(code: "TND", name: "Tunisian Dinar", symbol: "د.ت", flag: "🇹🇳", locale: "ar_TN"),
        Currency(code: "DZD", name: "Algerian Dinar", symbol: "د.ج", flag: "🇩🇿", locale: "ar_DZ"),
        Currency(code: "ETB", name: "Ethiopian Birr", symbol: "Br", flag: "🇪🇹", locale: "am_ET"),
        Currency(code: "TZS", name: "Tanzanian Shilling", symbol: "TSh", flag: "🇹🇿", locale: "sw_TZ"),
        Currency(code: "UGX", name: "Ugandan Shilling", symbol: "USh", flag: "🇺🇬", locale: "en_UG"),
        Currency(code: "ZMW", name: "Zambian Kwacha", symbol: "K", flag: "🇿🇲", locale: "en_ZM"),
        Currency(code: "BWP", name: "Botswana Pula", symbol: "P", flag: "🇧🇼", locale: "en_BW"),
        Currency(code: "MUR", name: "Mauritian Rupee", symbol: "₨", flag: "🇲🇺", locale: "en_MU"),
        Currency(code: "SCR", name: "Seychellois Rupee", symbol: "₨", flag: "🇸🇨", locale: "en_SC"),
        Currency(code: "XOF", name: "West African CFA Franc", symbol: "Fr", flag: "🇸🇳", locale: "fr_SN"),
        Currency(code: "XAF", name: "Central African CFA Franc", symbol: "Fr", flag: "🇨🇲", locale: "fr_CM"),
        Currency(code: "ERN", name: "Eritrean Nakfa", symbol: "Nfk", flag: "🇪🇷", locale: "ti_ER"),
        Currency(code: "SZL", name: "Eswatini Lilangeni", symbol: "L", flag: "🇸🇿", locale: "en_SZ"),
        Currency(code: "LSL", name: "Lesotho Loti", symbol: "L", flag: "🇱🇸", locale: "en_LS"),
        Currency(code: "NAD", name: "Namibian Dollar", symbol: "N$", flag: "🇳🇦", locale: "en_NA"),
        Currency(code: "MZN", name: "Mozambican Metical", symbol: "MT", flag: "🇲🇿", locale: "pt_MZ"),
        Currency(code: "MWK", name: "Malawian Kwacha", symbol: "MK", flag: "🇲🇼", locale: "en_MW"),
        Currency(code: "RWF", name: "Rwandan Franc", symbol: "Fr", flag: "🇷🇼", locale: "rw_RW"),
        Currency(code: "SLL", name: "Sierra Leonean Leone", symbol: "Le", flag: "🇸🇱", locale: "en_SL"),
        Currency(code: "SOS", name: "Somali Shilling", symbol: "Sh", flag: "🇸🇴", locale: "so_SO"),
        Currency(code: "SDG", name: "Sudanese Pound", symbol: "ج.س.", flag: "🇸🇩", locale: "ar_SD"),
        Currency(code: "TMT", name: "Turkmenistani Manat", symbol: "m", flag: "🇹🇲", locale: "tk_TM"),
        Currency(code: "IRR", name: "Iranian Rial", symbol: "﷼", flag: "🇮🇷", locale: "fa_IR"),
        Currency(code: "IQD", name: "Iraqi Dinar", symbol: "د.ع", flag: "🇮🇶", locale: "ar_IQ"),
        Currency(code: "YER", name: "Yemeni Rial", symbol: "﷼", flag: "🇾🇪", locale: "ar_YE"),
        Currency(code: "SYP", name: "Syrian Pound", symbol: "£", flag: "🇸🇾", locale: "ar_SY"),
        
        // Cryptocurrencies & Special
        Currency(code: "BTC", name: "Bitcoin", symbol: "₿", flag: "🪙", locale: "en_US"),
        Currency(code: "ETH", name: "Ethereum", symbol: "Ξ", flag: "💎", locale: "en_US"),
        Currency(code: "XAU", name: "Gold", symbol: "Au", flag: "🥇", locale: "en_US"),
        Currency(code: "XAG", name: "Silver", symbol: "Ag", flag: "🥈", locale: "en_US"),
    ]
    
    private let userDefaultsKey = "selected_currency"
    private let ratesCacheKey = "cached_exchange_rates"
    private let ratesDateKey = "exchange_rates_date"
    
    var currentCurrency: Currency {
        currencies.first { $0.code == selectedCurrency } ?? Currency(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸", locale: "en_US")
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey) {
            selectedCurrency = saved
        } else {
            let locale = Locale.current
            let currencyCode = locale.currency?.identifier ?? "USD"
            selectedCurrency = currencies.contains { $0.code == currencyCode } ? currencyCode : "USD"
        }
        
        _ = loadCachedRates()

        Task {
            try? await fetchExchangeRates()
        }
    }
    
    func fetchExchangeRates() async throws -> [String: Double] {
        if let lastUpdated = lastUpdated,
           Date().timeIntervalSince(lastUpdated) < 3600 {
            return exchangeRates
        }

        await MainActor.run { isLoadingRates = true }
        defer { Task { @MainActor in isLoadingRates = false } }

        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let rates = try await performFetch()
                await MainActor.run {
                    self.exchangeRates = rates
                    self.lastUpdated = Date()
                    self.error = nil
                    self.cacheRates()
                }
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
        throw CurrencyError.fetchFailed(lastError)
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
        if let cached = UserDefaults.standard.dictionary(forKey: ratesCacheKey) as? [String: Double] {
            lastUpdated = UserDefaults.standard.object(forKey: ratesDateKey) as? Date
            return cached
        }
        return nil
    }
    
    private func cacheRates() {
        UserDefaults.standard.set(exchangeRates, forKey: ratesCacheKey)
        UserDefaults.standard.set(lastUpdated, forKey: ratesDateKey)
    }

    func convert(_ amount: Decimal, from sourceCurrency: String, to targetCurrency: String) throws -> Decimal {
        guard sourceCurrency != targetCurrency else { return amount }

        guard let sourceRate = exchangeRates[sourceCurrency] else {
            throw CurrencyError.rateNotAvailable
        }
        guard let targetRate = exchangeRates[targetCurrency] else {
            throw CurrencyError.rateNotAvailable
        }

        let amountInUSD = Double(truncating: amount as NSNumber) / sourceRate
        let converted = amountInUSD * targetRate

        return Decimal(converted)
    }
    
    func convertToSelected(_ amount: Decimal, from sourceCurrency: String) -> Decimal {
        (try? convert(amount, from: sourceCurrency, to: selectedCurrency)) ?? amount
    }

    // MARK: - Catalog Price Helpers (Revolutionary Database)

    /// Convert a USD catalog price to the user's selected currency
    func convertFromUSD(_ priceUSD: Double) -> Double {
        let rate = exchangeRates[selectedCurrency] ?? 1.0
        return priceUSD * rate
    }

    /// Format a USD catalog price in the user's selected currency
    func formatCatalogPrice(_ priceUSD: Double) -> String {
        let converted = convertFromUSD(priceUSD)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency
        return formatter.string(from: NSNumber(value: converted)) ?? "\(selectedCurrency) \(converted)"
    }

    /// Indicator prefix for non-USD prices (shows ≈ when converting)
    var priceIndicator: String {
        selectedCurrency == "USD" ? "" : "≈"
    }

    func format(_ amount: Decimal, currencyCode: String? = nil, psychologicalPricing: Bool = false) -> String {
        let code = currencyCode ?? selectedCurrency
        let currency = currencies.first { $0.code == code } ?? Currency(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸", locale: "en_US")

        // NOTE: Psychological pricing rounds to .99 — disabled by default as it manipulates displayed prices
        // Only enable explicitly for marketing display purposes
        let finalAmount = psychologicalPricing ? roundToPsychologicalPricing(amount) : amount

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.currencySymbol = currency.symbol
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: finalAmount as NSDecimalNumber) ?? "\(currency.symbol)\(finalAmount)"
    }
    
    /// Rounds price to psychological pricing (X.99)
    /// Example: $6.84 CAD → $6.99 CAD
    private func roundToPsychologicalPricing(_ amount: Decimal) -> Decimal {
        let doubleValue = Double(truncating: amount as NSNumber)
        let integerPart = floor(doubleValue)
        return Decimal(integerPart + 0.99)
    }
    
    func currencySymbol(for code: String) -> String {
        currencies.first { $0.code == code }?.symbol ?? "$"
    }
    
    func currencyFlag(for code: String) -> String {
        currencies.first { $0.code == code }?.flag ?? "🏳️"
    }
    
    func setCurrency(_ code: String) {
        selectedCurrency = code
        UserDefaults.standard.set(code, forKey: userDefaultsKey)
        NotificationCenter.default.post(name: .currencyChanged, object: code)
    }
    
    /// Detect currency from device locale
    static func detectCurrencyFromLocale() -> Currency {
        let locale = Locale.current
        let currencyCode = locale.currency?.identifier ?? "USD"
        return CurrencyManager.shared.currencies.first { $0.code == currencyCode }
            ?? Currency(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸", locale: "en_US")
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
        guard sourceCurrency != targetCurrency else { return amount }
        guard let sourceRate = exchangeRates[sourceCurrency] else {
            throw CurrencyError.rateNotAvailable
        }
        guard let targetRate = exchangeRates[targetCurrency] else {
            throw CurrencyError.rateNotAvailable
        }
        let amountInUSD = amount / sourceRate
        return amountInUSD * targetRate
    }
    
    /// Format with showing original
    func formatConverted(_ amount: Double, from sourceCurrency: Currency, showOriginal: Bool) -> String {
        let converted = (try? convert(amount, from: sourceCurrency.code, to: selectedCurrency)) ?? amount
        let roundedConverted = roundToMarketingPrice(converted)
        let convertedStr = format(Decimal(roundedConverted))
        if showOriginal && sourceCurrency.code != selectedCurrency {
            let originalStr = sourceCurrency.format(amount)
            return "\(convertedStr) (\(originalStr))"
        }
        return convertedStr
    }
    
    /// Rounds prices to marketing-friendly amounts (.99, .00, etc.)
    func roundToMarketingPrice(_ amount: Double) -> Double {
        // Round to nearest dollar, then subtract 1 cent for .99 pricing
        // Examples: $6.84 → $6.99, $4.99 → $4.99, $7.01 → $6.99
        let roundedUp = ceil(amount)
        let marketingPrice = roundedUp - 0.01
        
        // Ensure we don't go below the original amount (don't undercut too much)
        if marketingPrice < amount * 0.9 {
            // If rounding would discount more than 10%, use different logic
            return (floor(amount) + 0.99)
        }
        
        return max(marketingPrice, 0.99) // Minimum price $0.99
    }
    
    /// Convert with marketing rounding
    func convertWithRounding(_ amount: Double, from sourceCurrency: String, to targetCurrency: String) throws -> Double {
        guard sourceCurrency != targetCurrency else { return amount }
        guard let sourceRate = exchangeRates[sourceCurrency] else {
            throw CurrencyError.rateNotAvailable
        }
        guard let targetRate = exchangeRates[targetCurrency] else {
            throw CurrencyError.rateNotAvailable
        }
        let amountInUSD = amount / sourceRate
        let converted = amountInUSD * targetRate
        return roundToMarketingPrice(converted)
    }

    /// Get exchange rate between two currencies
    func getRate(from sourceCode: String, to targetCode: String) throws -> Double {
        guard sourceCode != targetCode else { return 1.0 }
        guard let sourceRate = exchangeRates[sourceCode] else {
            throw CurrencyError.rateNotAvailable
        }
        guard let targetRate = exchangeRates[targetCode] else {
            throw CurrencyError.rateNotAvailable
        }
        guard sourceRate > 0 else { throw CurrencyError.rateNotAvailable }
        return targetRate / sourceRate
    }
}

// MARK: - Supporting Types
struct Currency: Identifiable, Codable, Hashable {
    var id = UUID()
    let code: String
    let name: String
    let symbol: String
    let flag: String
    let locale: String
    
    var displayName: String {
        "\(flag) \(code) - \(name)"
    }
    
    func format(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.currencySymbol = symbol
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(symbol)\(amount)"
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

// MARK: - UI Components
struct CurrencySelectorToolbarButton: View {
    @ObservedObject private var manager = CurrencyManager.shared
    @State private var showPicker = false
    
    var body: some View {
        Button(action: { showPicker = true }) {
            HStack(spacing: 4) {
                Text(manager.currentCurrency.flag)
                Text(manager.selectedCurrency)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.luxuryGold)
        }
        .sheet(isPresented: $showPicker) {
            SimpleCurrencyPickerView(selectedCurrency: $manager.selectedCurrency)
        }
    }
}



// MARK: - Additional Database Models

struct UsageSnapshot: Codable, Identifiable {
    let id: UUID
    let subscriptionId: UUID
    let userId: UUID
    let date: Date
    let weekNumber: Int?
    let month: Int?
    let year: Int?
    let minutesUsed: Int
    let appLaunches: Int?
    let screenTimeCategory: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case subscriptionId = "subscription_id"
        case userId = "user_id"
        case date
        case weekNumber = "week_number"
        case month
        case year
        case minutesUsed = "minutes_used"
        case appLaunches = "app_launches"
        case screenTimeCategory = "screen_time_category"
        case createdAt = "created_at"
    }
}

struct AIInsightLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let subscriptionId: UUID?
    let insightType: String
    let insightText: String
    let confidenceScore: Int?
    let actionTaken: String?
    let userFeedback: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case subscriptionId = "subscription_id"
        case insightType = "insight_type"
        case insightText = "insight_text"
        case confidenceScore = "confidence_score"
        case actionTaken = "action_taken"
        case userFeedback = "user_feedback"
        case createdAt = "created_at"
    }
}

struct Alternative: Codable, Identifiable {
    let id: UUID
    let sourceSubscriptionName: String
    let sourceCategory: String
    let alternativeName: String
    let alternativeUrl: String?
    let alternativeCost: Decimal?
    let alternativeBillingCycle: String?
    let alternativeLogoUrl: String?
    let isFree: Bool
    let isCheaper: Bool
    let savingsAmount: Decimal?
    let description: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case sourceSubscriptionName = "source_subscription_name"
        case sourceCategory = "source_category"
        case alternativeName = "alternative_name"
        case alternativeUrl = "alternative_url"
        case alternativeCost = "alternative_cost"
        case alternativeBillingCycle = "alternative_billing_cycle"
        case alternativeLogoUrl = "alternative_logo_url"
        case isFree = "is_free"
        case isCheaper = "is_cheaper"
        case savingsAmount = "savings_amount"
        case description
        case createdAt = "created_at"
    }
}

struct UserDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceName: String?
    let deviceModel: String?
    let osVersion: String?
    let lastSyncAt: Date?
    let screenTimeEnabled: Bool
    let screenTimeToken: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceName = "device_name"
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case lastSyncAt = "last_sync_at"
        case screenTimeEnabled = "screen_time_enabled"
        case screenTimeToken = "screen_time_token"
        case createdAt = "created_at"
    }
}

struct ReferralCodeRecord: Codable, Identifiable {
    let code: String
    let referrerUserId: UUID
    let conversions: Int
    let pendingConversions: Int
    let totalEarnings: Decimal
    let createdAt: Date
    let isEligibleForFreePro: Bool
    
    var id: String { code }
    
    enum CodingKeys: String, CodingKey {
        case code
        case referrerUserId = "referrer_user_id"
        case conversions
        case pendingConversions = "pending_conversions"
        case totalEarnings = "total_earnings"
        case createdAt = "created_at"
        case isEligibleForFreePro = "is_eligible_for_free_pro"
    }
}

