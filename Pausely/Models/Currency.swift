//
//  Currency.swift
//  Pausely
//
//  Currency model supporting 150+ world currencies
//

import Foundation
import SwiftUI

// Note: The main Currency model is in CurrencyManager.swift
// This file contains additional currency-related models and extensions

// MARK: - Currency Converter Helper
struct CurrencyConverter {
    static func format(amount: Double, currencyCode: String) -> String {
        guard let currency = CurrencyManager.shared.currency(for: currencyCode) else {
            return "\(currencyCode) \(String(format: "%.2f", amount))"
        }
        return currency.format(amount)
    }
}

// MARK: - Currency Amount

/// Represents an amount in a specific currency
struct CurrencyAmount: Codable, Identifiable, Equatable {
    let id = UUID()
    var amount: Double
    var currencyCode: String
    
    enum CodingKeys: String, CodingKey {
        case amount, currencyCode
    }
    
    /// The currency object for this amount
    var currency: Currency? {
        CurrencyManager.shared.currency(for: currencyCode)
    }
    
    /// Formatted string representation
    var formatted: String {
        CurrencyConverter.format(amount: amount, currencyCode: currencyCode)
    }
    
    /// Converts this amount to another currency
    func converted(to targetCode: String) -> CurrencyAmount? {
        guard let convertedAmount = try? CurrencyManager.shared.convert(
            amount,
            from: currencyCode,
            to: targetCode
        ) else {
            return nil
        }
        return CurrencyAmount(amount: convertedAmount, currencyCode: targetCode)
    }
    
    /// Converts to user's selected currency
    var inUserCurrency: CurrencyAmount {
        let targetCode = CurrencyManager.shared.currentCurrency.code
        return converted(to: targetCode) ?? self
    }
    
    static func == (lhs: CurrencyAmount, rhs: CurrencyAmount) -> Bool {
        lhs.amount == rhs.amount && lhs.currencyCode == rhs.currencyCode
    }
}

// MARK: - Currency Preference

/// User's currency preferences
struct CurrencyPreference: Codable {
    var selectedCurrencyCode: String
    var showOriginalCurrency: Bool
    var autoUpdateRates: Bool
    var preferredDecimalPlaces: Int?
    
    static let `default` = CurrencyPreference(
        selectedCurrencyCode: Locale.current.currency?.identifier ?? "USD",
        showOriginalCurrency: true,
        autoUpdateRates: true,
        preferredDecimalPlaces: nil
    )
}

// MARK: - Currency Region

/// Groups currencies by region for organized display
enum CurrencyRegion: String, CaseIterable, Identifiable {
    case all = "All Currencies"
    case popular = "Popular"
    case americas = "Americas"
    case europe = "Europe"
    case asiaPacific = "Asia & Pacific"
    case middleEast = "Middle East & Africa"
    case crypto = "Cryptocurrency"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "globe"
        case .popular: return "star.fill"
        case .americas: return "globe.americas.fill"
        case .europe: return "globe.europe.africa.fill"
        case .asiaPacific: return "globe.asia.australia.fill"
        case .middleEast: return "building.columns.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        }
    }
    
    var regionCodes: [String] {
        switch self {
        case .all:
            return []
        case .popular:
            return ["USD", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD", "CHF", "SGD", "HKD", "KRW", "INR", "BRL", "MXN", "ZAR", "TRY", "IDR", "THB", "MYR", "PHP"]
        case .americas:
            return ["USD", "CAD", "MXN", "BRL", "ARS", "CLP", "COP", "PEN", "UYU", "DOP", "CRC", "GTQ", "HNL", "NIO", "PAB", "BOB", "PYG", "VES", "XCD", "TTD", "JMD", "BBD", "BSD", "BZD", "KYD", "BMD", "GYD", "SRD"]
        case .europe:
            return ["EUR", "GBP", "CHF", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "RON", "BGN", "HRK", "RSD", "ISK", "UAH", "RUB", "BYN", "MDL", "GIP", "ALL", "BAM", "MKD", "GEL", "AZN", "AMD"]
        case .asiaPacific:
            return ["JPY", "CNY", "HKD", "SGD", "KRW", "INR", "IDR", "MYR", "THB", "PHP", "VND", "TWD", "PKR", "BDT", "LKR", "NPR", "MMK", "KHR", "LAK", "MOP", "BND", "PGK", "FJD", "WST", "TOP", "VUV", "SBD", "KID", "MVR", "BTN", "MNT", "KZT", "KGS", "TJS", "UZS", "AFN", "AUD", "NZD"]
        case .middleEast:
            return ["AED", "SAR", "QAR", "KWD", "BHD", "OMR", "ILS", "JOD", "LBP", "EGP", "ZAR", "NGN", "KES", "GHS", "MAD", "TND", "DZD", "ETB", "TZS", "UGX", "ZMW", "BWP", "MUR", "SCR", "XOF", "XAF", "ERN", "SZL", "LSL", "NAD", "MZN", "MWK", "RWF", "SLL", "SOS", "SDG", "TMT", "IRR", "IQD", "YER", "SYP"]
        case .crypto:
            return ["BTC", "ETH", "XAU", "XAG"]
        }
    }
    
    func currencies(in manager: CurrencyManager = .shared) -> [Currency] {
        if regionCodes.isEmpty {
            return manager.allCurrencies
        }
        return manager.allCurrencies.filter { regionCodes.contains($0.code) }
    }
}

// MARK: - Historical Rate

/// Represents a historical exchange rate data point
struct HistoricalRate: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let fromCurrency: String
    let toCurrency: String
    let rate: Double
    
    /// Calculates rate change from previous data point
    func change(from previous: HistoricalRate?) -> Double? {
        guard let previous = previous else { return nil }
        return ((rate - previous.rate) / previous.rate) * 100
    }
    
    /// Formatted change string with arrow
    func formattedChange(from previous: HistoricalRate?) -> String? {
        guard let change = change(from: previous) else { return nil }
        let arrow = change >= 0 ? "↑" : "↓"
        return String(format: "%@ %.2f%%", arrow, abs(change))
    }
}

// MARK: - Currency Trend

/// Trend direction for exchange rates
enum CurrencyTrend: String {
    case up = "up"
    case down = "down"
    case stable = "stable"
    
    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

// MARK: - Helper Extensions

extension Double {
    /// Rounds to specified decimal places for currency
    func roundedToCurrency(decimals: Int = 2) -> Double {
        let multiplier = pow(10.0, Double(decimals))
        return (self * multiplier).rounded() / multiplier
    }
}

// MARK: - Sample Data

extension Currency {
    /// Sample currencies for previews and testing
    static var samples: [Currency] {
        [
            Currency(code: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸", locale: "en_US"),
            Currency(code: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺", locale: "de_DE"),
            Currency(code: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧", locale: "en_GB"),
            Currency(code: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵", locale: "ja_JP"),
        ]
    }
}

// MARK: - Subscription Currency Extension

extension Subscription {
    /// The currency object for this subscription
    var currencyObject: Currency? {
        CurrencyManager.shared.currency(for: currency)
    }
    
    /// Amount as CurrencyAmount
    var currencyAmount: CurrencyAmount {
        CurrencyAmount(amount: Double(truncating: amount as NSNumber), currencyCode: currency)
    }
    
    /// Amount converted to user's preferred currency
    var convertedAmount: CurrencyAmount {
        currencyAmount.inUserCurrency
    }
    
    /// Monthly cost in user's preferred currency
    var monthlyCostInUserCurrency: Double {
        let manager = CurrencyManager.shared
        let monthlyAmount = Double(truncating: monthlyCost as NSNumber)
        return (try? manager.convert(monthlyAmount, from: currency, to: manager.selectedCurrency)) ?? monthlyAmount
    }
    
    /// Yearly cost in user's preferred currency
    var yearlyCostInUserCurrency: Double {
        let manager = CurrencyManager.shared
        let yearlyAmount = Double(truncating: annualCost as NSNumber)
        return (try? manager.convert(yearlyAmount, from: currency, to: manager.selectedCurrency)) ?? yearlyAmount
    }
    
    /// Formatted amount with optional conversion
    func formattedAmount(showConversion: Bool = true) -> String {
        let manager = CurrencyManager.shared
        let amountValue = Double(truncating: amount as NSNumber)
        
        guard let sourceCurrency = currencyObject else {
            return displayAmount
        }
        
        if showConversion && currency != manager.selectedCurrency {
            return manager.formatConverted(amountValue, from: sourceCurrency, showOriginal: true)
        }
        return sourceCurrency.format(amountValue)
    }
    
}
