//
//  WidgetTypes.swift
//  PauselyWidget
//
//  Standalone type definitions for the widget extension.
//  These mirror the main app's data types but have no app-target dependencies.
//

import Foundation
import ActivityKit

// MARK: - Widget Summary

struct WidgetSummaryData: Codable {
    let monthlySpend: Double
    let activeCount: Int
    let upcomingCount: Int
    let currencyCode: String
    let topInsight: String

    init(monthlySpend: Double = 0, activeCount: Int = 0, upcomingCount: Int = 0,
         currencyCode: String = "USD", topInsight: String = "Loading...") {
        self.monthlySpend = monthlySpend
        self.activeCount = activeCount
        self.upcomingCount = upcomingCount
        self.currencyCode = currencyCode
        self.topInsight = topInsight
    }

    var currencySymbol: String {
        switch currencyCode {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY", "CNY": return "¥"
        case "CAD": return "C$"
        case "AUD": return "A$"
        case "CHF": return "Fr"
        case "INR": return "₹"
        case "KRW": return "₩"
        case "BRL": return "R$"
        case "MXN", "ARS", "CLP", "COP", "UYU", "CUP", "DOP", "NIO", "NAD", "BZD", "BSD", "BBD", "TTD", "XCD", "LRD": return "$"
        case "SGD": return "S$"
        case "HKD": return "HK$"
        case "NOK", "SEK", "DKK", "ISK": return "kr"
        case "NZD": return "NZ$"
        case "ZAR": return "R"
        case "RUB": return "₽"
        case "TRY": return "₺"
        case "PLN": return "zł"
        case "THB": return "฿"
        case "IDR": return "Rp"
        case "MYR": return "RM"
        case "PHP": return "₱"
        case "CZK": return "Kč"
        case "ILS": return "₪"
        case "AED": return "د.إ"
        case "SAR", "QAR", "OMR", "YER": return "﷼"
        case "TWD": return "NT$"
        case "VND": return "₫"
        case "EGP": return "£"
        case "PKR", "MUR", "SCR", "NPR", "LKR": return "₨"
        case "NGN": return "₦"
        case "BDT": return "৳"
        case "RON": return "lei"
        case "HUF": return "Ft"
        case "UAH": return "₴"
        case "PEN": return "S/"
        case "MAD": return "د.م."
        case "KWD": return "د.ك"
        case "BHD": return ".د.ب"
        case "JOD": return "د.ا"
        case "KES": return "KSh"
        case "GHS": return "₵"
        case "TZS": return "TSh"
        case "UGX": return "USh"
        case "HRK": return "kn"
        case "BGN": return "лв"
        case "RSD": return "дин"
        case "GEL": return "₾"
        case "AMD": return "֏"
        case "AZN": return "₼"
        case "KZT": return "₸"
        case "UZS": return "so'm"
        case "TJS": return "SM"
        case "KGS": return "с"
        case "MNT": return "₮"
        case "MMK": return "K"
        case "KHR": return "៛"
        case "LAK": return "₭"
        case "BND": return "$"
        case "BWP": return "P"
        case "ZMW": return "ZK"
        case "MWK": return "MK"
        case "MZN": return "MT"
        case "SZL", "LSL": return "L"
        case "AOA": return "Kz"
        case "CDF": return "FC"
        case "RWF": return "FRw"
        case "BIF": return "FBu"
        case "DJF": return "Fdj"
        case "ETB": return "Br"
        case "SOS": return "Sh"
        case "GMD": return "D"
        case "GNF": return "FG"
        case "SLL": return "Le"
        case "MRU": return "UM"
        case "STN": return "Db"
        case "XOF": return "CFA"
        case "XAF": return "FCFA"
        case "AWG", "ANG": return "ƒ"
        case "HTG": return "G"
        case "GTQ": return "Q"
        case "HNL": return "L"
        case "CRC": return "₡"
        case "PAB": return "B/."
        case "PYG": return "₲"
        case "BOB", "VES": return "Bs"
        default: return "$"
        }
    }
}

// MARK: - Widget Trial Info

struct WidgetTrialInfo: Codable, Identifiable {
    let id: String
    let name: String
    let trialEndsAt: Date
    let monthlyAmount: Double
    let currencyCode: String
    let billingFrequency: String

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: trialEndsAt).day ?? 0)
    }

    var currencySymbol: String {
        WidgetSummaryData(currencyCode: currencyCode).currencySymbol
    }
}

// MARK: - Live Activity Attributes
// IMPORTANT: Field names and types must match PauselyLiveActivityAttributes in the main app exactly.

struct PauselyLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var daysUntilRenewal: Int
        var hoursUntilRenewal: Int
        var isUrgent: Bool
    }

    var subscriptionName: String
    var renewalDate: Date
    var amount: Double
    var currencySymbol: String
    var frequency: String
}
