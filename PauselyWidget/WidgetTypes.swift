//
//  WidgetTypes.swift
//  PauselyWidget
//
//  Standalone type definitions for the widget extension.
//  These mirror the main app's data types but have no app-target dependencies.
//

import Foundation

// MARK: - Widget Summary

struct WidgetSummaryData: Codable {
    let activeCount: Int
    let upcomingCount: Int
    let topInsight: String
    /// Amounts arrive formatted by the app (MoneyFormat): the widget never formats money itself,
    /// so it always matches the app's currency, symbol and decimals.
    let monthlyText: String
    let monthlyWholeText: String
    let yearlyWholeText: String

    init(activeCount: Int = 0, upcomingCount: Int = 0, topInsight: String = "Loading...",
         monthlyText: String = "–", monthlyWholeText: String = "–", yearlyWholeText: String = "–") {
        self.activeCount = activeCount
        self.upcomingCount = upcomingCount
        self.topInsight = topInsight
        self.monthlyText = monthlyText
        self.monthlyWholeText = monthlyWholeText
        self.yearlyWholeText = yearlyWholeText
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
    /// The first charge after the trial, formatted by the app in the subscription's currency.
    let amountText: String?

    var daysRemaining: Int {
        max(0, Calendar.billing.dateComponents([.day], from: Date(), to: trialEndsAt).day ?? 0)
    }
}

extension Calendar {
    /// Gregorian, in the phone's time zone: the calendar the app works out days in (see the app's
    /// `Calendar.billing`). The widgets count days the same way.
    static let billing: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()
}
