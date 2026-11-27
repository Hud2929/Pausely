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

    /// The app uses `shared`; a test passes its own settings and its own reload.
    init(defaults: UserDefaults? = nil,
         reloadWidgets: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.injectedDefaults = defaults
        self.reloadWidgets = reloadWidgets
    }

    func publish(subscriptions: [Subscription], now: Date = Date()) {
        let includePrivate = !SubscriptionStore.shared.isHidden
        Self.feed(for: subscriptions, now: now, includeAccountDetails: includePrivate).write(to: defaults)
        reloadWidgets()
    }

    // MARK: - The feed

    /// The feed for a list: every charging subscription that has a date, with the days it charges on
    /// for about a year ahead, and the totals as text in the display currency.
    /// When `includeAccountDetails` is false (signed out / hidden list), zero personal savings or
    /// Pause Plan state is ever written to the shared widget container.
    static func feed(for subscriptions: [Subscription], now: Date, calendar: Calendar = .billing,
                     currency: String = CurrencyManager.shared.selectedCurrency,
                     rates: CurrencyRates = CurrencyManager.shared.rates,
                     language: String? = L10n.chosenLanguage,
                     includeAccountDetails: Bool = true) -> WidgetFeed {
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
        guard includeAccountDetails else { return feed }
        let summary = SavingsSummary.current(now: now)
        if !summary.isEmpty {
            feed.savedSoFarText = summary.total(summary.savedSoFar)
            feed.savedSoFarIsZero = summary.savedSoFar <= 0
            feed.onTrackText = summary.total(summary.onTrack)
            feed.cancelledCount = summary.lines.count
        }
        if PaymentManager.shared.isUnlocked(.pausePlan),
           let plan = PausePlanStore.shared.activePlan {
            let byId = Dictionary(subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            if let current = PausePlanSchedule.currentTurn(plan, subscriptions: byId, now: now),
               let sub = byId[current.subscriptionId] {
                feed.pauseTurnName = sub.name
                feed.pauseTurnEndText = DayText.date(current.end, locale: L10n.locale)
                feed.pauseTurnEndStamp = calendar.dayStamp(current.end)
                let nextIndex = (current.index + 1) % plan.subscriptionIds.count
                feed.pauseTurnNextName = byId[plan.subscriptionIds[nextIndex]]?.name ?? ""
            }
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
