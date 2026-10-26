import Foundation

/// Exchange rates against the US dollar (1 USD = `perUSD[code]` units), and the one way Pausely
/// converts money between currencies. Pure and `Decimal` throughout, so it is easy to test.
///
/// A conversion returns `nil` when either currency is unknown. Callers decide what to do; they never
/// get the original number back dressed up as another currency.
struct CurrencyRates: Equatable {
    let perUSD: [String: Decimal]

    init(perUSD: [String: Decimal]) {
        var normalized: [String: Decimal] = [:]
        for (code, rate) in perUSD where rate > 0 {
            normalized[MoneyFormat.normalizedCode(code)] = rate
        }
        normalized["USD"] = 1
        self.perUSD = normalized
    }

    /// Rates from an API (`Double` per USD). Goes through text so 1.38 stays 1.38, not 1.3799999.
    init(apiRates: [String: Double]) {
        self.init(perUSD: apiRates.compactMapValues { Decimal(string: String($0)) })
    }

    func rate(_ code: String) -> Decimal? {
        perUSD[MoneyFormat.normalizedCode(code)]
    }

    /// `amount` in `from`, expressed in `to`, or `nil` when either rate is unknown.
    func convert(_ amount: Decimal, from: String, to: String) -> Decimal? {
        let source = MoneyFormat.normalizedCode(from)
        let target = MoneyFormat.normalizedCode(to)
        if source == target { return amount }
        guard let sourceRate = perUSD[source], let targetRate = perUSD[target] else { return nil }
        return amount / sourceRate * targetRate
    }

    /// These rates, with `fallback` filling any currency they don't cover.
    func fillingGaps(from fallback: CurrencyRates = .fallback) -> CurrencyRates {
        CurrencyRates(perUSD: fallback.perUSD.merging(perUSD) { _, live in live })
    }

    /// Rates on 2026-10-26 (exchangerate-api.com) for every currency the currency picker offers.
    /// Used until live rates load, and whenever they can't. Refresh with the pausely-currency skill.
    static let fallbackDate = "2026-10-26"
    static let fallback = CurrencyRates(perUSD: fallbackTable.compactMapValues { Decimal(string: $0) })

    private static let fallbackTable: [String: String] = [
        "USD": "1", "EUR": "0.892", "GBP": "0.748", "JPY": "156.87", "CNY": "6.68", "CAD": "1.4",
        "MXN": "18.72", "BRL": "5", "ARS": "1528.26", "CLP": "989.53", "COP": "3170.49", "PEN": "3.44",
        "UYU": "40.11", "DOP": "61.33", "CRC": "455.89", "GTQ": "7.65", "HNL": "26.86", "NIO": "36.8",
        "PAB": "1", "BOB": "11.79", "PYG": "5765.48", "VES": "887.3", "XCD": "2.7", "TTD": "6.79",
        "JMD": "158.84", "BBD": "2", "BSD": "1", "BZD": "2", "KYD": "0.833", "BMD": "1",
        "GYD": "209.52", "SRD": "37.6", "CHF": "0.825", "SEK": "9.93", "NOK": "9.32", "DKK": "6.68",
        "PLN": "3.93", "CZK": "21.71", "HUF": "326.99", "RON": "4.78", "BGN": "1.74", "RSD": "104.95",
        "ISK": "121.71", "UAH": "45.27", "RUB": "80.67", "BYN": "2.94", "MDL": "17.95", "GIP": "0.748",
        "ALL": "81.04", "BAM": "1.74", "MKD": "54.98", "GEL": "2.6", "AZN": "1.7", "AMD": "361.13",
        "AUD": "1.42", "NZD": "1.75", "SGD": "1.28", "HKD": "7.84", "KRW": "1323.9", "INR": "95.16",
        "IDR": "18090.29", "MYR": "4.09", "THB": "33.76", "PHP": "63.68", "VND": "25829.65", "TWD": "32.6",
        "PKR": "276.94", "BDT": "123.5", "LKR": "332.17", "NPR": "152.24", "MMK": "2098.94", "KHR": "4103.95",
        "LAK": "22334.49", "MOP": "8.08", "BND": "1.28", "PGK": "4.47", "FJD": "2.23", "WST": "2.73",
        "TOP": "2.38", "VUV": "118.8", "SBD": "7.96", "MVR": "15.44", "BTN": "95.15", "MNT": "3578.92",
        "KZT": "452.62", "KGS": "87.49", "TJS": "9.22", "UZS": "11858.35", "AFN": "64.83", "AED": "3.67",
        "SAR": "3.75", "QAR": "3.64", "KWD": "0.31", "BHD": "0.376", "OMR": "0.384", "ILS": "3.11",
        "JOD": "0.709", "LBP": "89500", "EGP": "55.68", "ZAR": "16.6", "NGN": "1334.3", "KES": "129.87",
        "GHS": "11.62", "MAD": "9.82", "TND": "3", "DZD": "134.92", "ETB": "161.78", "TZS": "2649.57",
        "UGX": "4336.26", "ZMW": "20.27", "BWP": "13.76", "MUR": "47.16", "SCR": "14.44", "XOF": "585.24",
        "XAF": "585.24", "ERN": "15", "SZL": "16.6", "LSL": "16.6", "NAD": "16.6", "MZN": "63.65",
        "MWK": "1733.69", "RWF": "1475.49", "SLL": "22971.44", "SOS": "571.48", "SDG": "458.56", "TMT": "3.5",
        "IRR": "1667724.81", "IQD": "1517.28", "YER": "236.23", "SYP": "121.75", "TRY": "49.79",
    ]
}
