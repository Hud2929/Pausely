import Foundation

/// Manages locale-based currency detection and formatting for global markets.
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    /// The currency code auto-detected from the device locale on first launch.
    @Published var detectedCurrencyCode: String

    private let defaultsKey = "detectedCurrencyCode"

    private init() {
        if let saved = UserDefaults.standard.string(forKey: defaultsKey) {
            self.detectedCurrencyCode = saved
        } else {
            let code = LocalizationManager.currencyCodeFromLocale()
            self.detectedCurrencyCode = code
            UserDefaults.standard.set(code, forKey: defaultsKey)
        }
    }

    /// Maps common locales to their primary currency.
    static func currencyCodeFromLocale(_ locale: Locale = Locale.current) -> String {
        let identifier = locale.identifier
        let region = locale.region?.identifier ?? Locale.current.region?.identifier ?? "US"

        // Map specific locale identifiers first
        let localeMap: [String: String] = [
            "en_US": "USD",
            "en_GB": "GBP",
            "en_CA": "CAD",
            "en_AU": "AUD",
            "de_DE": "EUR",
            "de_AT": "EUR",
            "de_CH": "CHF",
            "fr_FR": "EUR",
            "fr_CA": "CAD",
            "fr_CH": "CHF",
            "es_ES": "EUR",
            "es_MX": "MXN",
            "es_AR": "ARS",
            "ja_JP": "JPY",
            "ar_SA": "SAR",
            "ar_AE": "AED",
            "ar_EG": "EGP",
            "zh_CN": "CNY",
            "zh_TW": "TWD",
            "zh_HK": "HKD",
            "ko_KR": "KRW",
            "pt_BR": "BRL",
            "pt_PT": "EUR",
            "it_IT": "EUR",
            "nl_NL": "EUR",
            "nl_BE": "EUR",
            "ru_RU": "RUB",
            "pl_PL": "PLN",
            "tr_TR": "TRY",
            "sv_SE": "SEK",
            "da_DK": "DKK",
            "no_NO": "NOK",
            "fi_FI": "EUR",
            "id_ID": "IDR",
            "th_TH": "THB",
            "vi_VN": "VND",
            "hi_IN": "INR",
            "ms_MY": "MYR",
            "he_IL": "ILS",
        ]

        if let code = localeMap[identifier] {
            return code
        }

        // Fall back to region-based mapping
        let regionMap: [String: String] = [
            "US": "USD",
            "GB": "GBP",
            "CA": "CAD",
            "AU": "AUD",
            "DE": "EUR",
            "FR": "EUR",
            "ES": "EUR",
            "IT": "EUR",
            "NL": "EUR",
            "BE": "EUR",
            "AT": "EUR",
            "PT": "EUR",
            "FI": "EUR",
            "IE": "EUR",
            "GR": "EUR",
            "JP": "JPY",
            "CN": "CNY",
            "TW": "TWD",
            "HK": "HKD",
            "KR": "KRW",
            "BR": "BRL",
            "MX": "MXN",
            "AR": "ARS",
            "RU": "RUB",
            "PL": "PLN",
            "TR": "TRY",
            "SE": "SEK",
            "DK": "DKK",
            "NO": "NOK",
            "CH": "CHF",
            "SA": "SAR",
            "AE": "AED",
            "EG": "EGP",
            "ID": "IDR",
            "TH": "THB",
            "VN": "VND",
            "IN": "INR",
            "MY": "MYR",
            "IL": "ILS",
            "ZA": "ZAR",
            "NG": "NGN",
            "PH": "PHP",
            "SG": "SGD",
            "NZ": "NZD",
        ]

        return regionMap[region] ?? "USD"
    }

    /// Formats a Decimal amount into a localized currency string.
    /// - Parameters:
    ///   - amount: The monetary value.
    ///   - currencyCode: ISO 4217 currency code (e.g. "USD", "EUR", "JPY").
    /// - Returns: A localized currency string.
    func formattedCurrency(_ amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale.current
        // JPY and KRW typically have no decimal places
        if currencyCode == "JPY" || currencyCode == "KRW" || currencyCode == "VND" || currencyCode == "IDR" {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
        }
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
