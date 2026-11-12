import Foundation
import WidgetKit

/// Publishes what the widgets show (`WidgetFeed`) to the settings the app shares with them, and asks
/// them to draw again, so a change in the app is on the Home Screen at once.
@MainActor
final class WidgetDataStore {
    static let shared = WidgetDataStore()

    private let injectedDefaults: UserDefaults?
    private let reloadWidgets: () -> Void

    private var defaults: UserDefaults? {
        injectedDefaults ?? UserDefaults(suiteName: WidgetFeed.suiteName)
    }

    private init(defaults: UserDefaults? = nil,
                 reloadWidgets: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.injectedDefaults = defaults
        self.reloadWidgets = reloadWidgets
    }

    /// A store of its own for a test, with its own settings and nothing to reload unless asked.
    static func forTesting(defaults: UserDefaults, reloadWidgets: @escaping () -> Void = {}) -> WidgetDataStore {
        WidgetDataStore(defaults: defaults, reloadWidgets: reloadWidgets)
    }

    func publish(subscriptions: [Subscription], now: Date = Date()) {
        Self.feed(for: subscriptions, now: now).write(to: defaults)
        reloadWidgets()
    }

    /// What was last published, as the widgets read it.
    func readFeed() -> WidgetFeed? {
        WidgetFeed.read(from: defaults)
    }

    // MARK: - The feed

    /// The feed for a list: every charging subscription that has a date, with the days it charges on
    /// for about a year ahead, and the totals as text in the display currency.
    static func feed(for subscriptions: [Subscription], now: Date, calendar: Calendar = .billing,
                     currency: String = CurrencyManager.shared.selectedCurrency,
                     rates: CurrencyRates = CurrencyManager.shared.rates,
                     language: String? = L10n.chosenLanguage) -> WidgetFeed {
        let charging = subscriptions.charging
        let today = calendar.startOfDay(for: now)

        let charges: [WidgetFeed.Charge] = charging.compactMap { sub in
            // A free trial's end comes first: that is the day the first charge is taken.
            let trialEnd = sub.status == .trial
                ? sub.trialEndsAt.flatMap { calendar.startOfDay(for: $0) >= today ? $0 : nil }
                : nil
            var days = trialEnd.map { [calendar.dayStamp($0)] } ?? []
            if let anchor = sub.nextBillingDate {
                // After a trial, the renewals from the day after it ends (its end is the first charge).
                let from = trialEnd.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } ?? now
                days += RenewalSchedule.upcomingRenewals(anchor: anchor, frequency: sub.billingFrequency, onOrAfter: from,
                                                         count: cyclesAhead(sub.billingFrequency), calendar: calendar)
                    .map(calendar.dayStamp)
            }
            guard !days.isEmpty else { return nil }
            return WidgetFeed.Charge(id: sub.id, name: sub.name, amountText: sub.chargeText, days: days,
                                     startsWithTrialEnd: trialEnd != nil)
        }

        var feed = WidgetFeed()
        feed.charges = charges
        feed.hasSubscriptions = !subscriptions.isEmpty
        feed.language = language
        if !charging.isEmpty {
            let monthly = charging.monthlyTotal(in: currency, rates: rates)
            let converted = charging.isConverted(to: currency)
            feed.monthlyText = MoneyFormat.total(monthly, currency, converted: converted)
            feed.yearlyText = MoneyFormat.total(monthly * 12, currency, converted: converted, wholeUnits: true)
        }
        return feed
    }

    /// How many charges ahead a widget is given: about a year's worth, so it stays right for months
    /// without the app being opened.
    private static func cyclesAhead(_ frequency: BillingFrequency) -> Int {
        switch frequency {
        case .weekly: return 52
        case .biweekly: return 26
        case .monthly: return 12
        case .quarterly: return 4
        case .semiannual: return 2
        case .yearly: return 2
        }
    }
}
