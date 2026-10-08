import Foundation

/// One place that turns an amount + ISO currency code into text, so engine messages and the UI always agree.
/// Non-US dollars get an unambiguous prefix ("C$", "A$") because a bare "$" is easy to misread.
enum MoneyFormat {
    private static let symbols: [String: String] = [
        "USD": "$", "CAD": "C$", "AUD": "A$", "NZD": "NZ$", "MXN": "MX$", "EUR": "€", "GBP": "£", "JPY": "¥", "INR": "₹"
    ]

    static func string(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        if let symbol = symbols[currency] { formatter.currencySymbol = symbol }
        formatter.minimumFractionDigits = currency == "JPY" ? 0 : 2
        formatter.maximumFractionDigits = currency == "JPY" ? 0 : 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currency) \(amount)"
    }
}
