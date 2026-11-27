import Foundation

/// What the app hands its widgets, written whenever the list changes: the days each subscription
/// charges on, several cycles ahead, and the totals as text.
///
/// The widgets work out "what charges next" from these days at the moment they draw. So a widget is
/// right on a day the app wasn't opened: the charge that passed yesterday gives way to the next one,
/// and "tomorrow" becomes "today" at midnight. Before, the app wrote one finished sentence ("Netflix ·
/// $15.49 · in 3 days") and the widget repeated it until the app was opened again.
struct WidgetFeed: Codable, Equatable {

    struct Charge: Codable, Equatable, Identifiable {
        /// The subscription's id: a tap on the widget opens it.
        let id: UUID
        let name: String
        /// One charge, as the app formats it, in the subscription's own currency.
        let amountText: String
        /// The days it charges on, soonest first, as day stamps ("2026-11-15").
        let days: [String]
        /// The first of `days` is the day a free trial ends and the first charge is taken.
        let startsWithTrialEnd: Bool
    }

    /// A charge that is still ahead, on the day a widget draws.
    struct Upcoming: Equatable, Identifiable {
        let charge: Charge
        /// Noon on the day of the charge.
        let day: Date
        /// 0 today, 1 tomorrow.
        let daysAway: Int
        let isTrialEnd: Bool
        var id: UUID { charge.id }
    }

    var charges: [Charge] = []
    /// What everything charging costs each month and each year, as the app formats it ("≈" included
    /// when something was converted). Empty when nothing is charging.
    var monthlyText = ""
    var yearlyText = ""
    /// The language chosen in the app ("ar", "de"…), or nil to follow the iPhone.
    var language: String?
    /// False when the list is empty: the widget then says where to add something.
    var hasSubscriptions = false
    /// Formatted Savings Receipt totals for the Savings Receipt widget (empty until first cancellation).
    var savedSoFarText = ""
    var savedSoFarIsZero = true
    var onTrackText = ""
    var cancelledCount = 0
    /// Current active Pause Plan streaming turn, if a Pro plan is running, with its end day-stamp ("YYYY-MM-DD")
    /// so widgets automatically stop showing an expired turn at midnight.
    var pauseTurnName = ""
    var pauseTurnEndText = ""
    var pauseTurnEndStamp = ""
    var pauseTurnNextName = ""

    init() {}

    enum CodingKeys: String, CodingKey {
        case charges, monthlyText, yearlyText, language, hasSubscriptions
        case savedSoFarText, savedSoFarIsZero, onTrackText, cancelledCount
        case pauseTurnName, pauseTurnEndText, pauseTurnEndStamp, pauseTurnNextName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        charges = try c.decodeIfPresent([Charge].self, forKey: .charges) ?? []
        monthlyText = try c.decodeIfPresent(String.self, forKey: .monthlyText) ?? ""
        yearlyText = try c.decodeIfPresent(String.self, forKey: .yearlyText) ?? ""
        language = try c.decodeIfPresent(String.self, forKey: .language)
        hasSubscriptions = try c.decodeIfPresent(Bool.self, forKey: .hasSubscriptions) ?? false
        savedSoFarText = try c.decodeIfPresent(String.self, forKey: .savedSoFarText) ?? ""
        savedSoFarIsZero = try c.decodeIfPresent(Bool.self, forKey: .savedSoFarIsZero) ?? true
        onTrackText = try c.decodeIfPresent(String.self, forKey: .onTrackText) ?? ""
        cancelledCount = try c.decodeIfPresent(Int.self, forKey: .cancelledCount) ?? 0
        pauseTurnName = try c.decodeIfPresent(String.self, forKey: .pauseTurnName) ?? ""
        pauseTurnEndText = try c.decodeIfPresent(String.self, forKey: .pauseTurnEndText) ?? ""
        pauseTurnEndStamp = try c.decodeIfPresent(String.self, forKey: .pauseTurnEndStamp) ?? ""
        pauseTurnNextName = try c.decodeIfPresent(String.self, forKey: .pauseTurnNextName) ?? ""
    }

    /// Returns the active Pause Plan turn on `today`, or nil once its end day has passed at midnight.
    func activePauseTurn(on today: Date, calendar: Calendar = .billing) -> (name: String, endText: String, nextName: String)? {
        guard !pauseTurnName.isEmpty else { return nil }
        if !pauseTurnEndStamp.isEmpty, calendar.dayStamp(today) > pauseTurnEndStamp {
            return nil
        }
        return (pauseTurnName, pauseTurnEndText, pauseTurnNextName)
    }

    // MARK: - What charges next

    /// Each subscription's next charge on or after `today`, soonest first. A subscription whose
    /// published days have all passed is left out: nothing is shown as due on a day it isn't.
    func upcoming(on today: Date, calendar: Calendar = .billing) -> [Upcoming] {
        let todayStamp = calendar.dayStamp(today)
        return charges.compactMap { charge -> Upcoming? in
            guard let stamp = charge.days.first(where: { $0 >= todayStamp }),
                  let day = calendar.noon(onDayStamped: stamp) else { return nil }
            let daysAway = calendar.dateComponents([.day], from: calendar.startOfDay(for: today),
                                                   to: calendar.startOfDay(for: day)).day ?? 0
            return Upcoming(charge: charge, day: day, daysAway: daysAway,
                            isTrialEnd: charge.startsWithTrialEnd && stamp == charge.days.first)
        }
        .sorted { ($0.day, $0.charge.name) < ($1.day, $1.charge.name) }
    }

    /// The free trials that are about to turn into a charge, soonest first.
    func trialsEnding(on today: Date, calendar: Calendar = .billing) -> [Upcoming] {
        upcoming(on: today, calendar: calendar).filter(\.isTrialEnd)
    }

    /// The moments a widget should draw again: now, then each of the next `days` midnights, when
    /// "tomorrow" becomes "today" and a charge that has passed gives way to the next.
    static func refreshMoments(from now: Date, days: Int = 7, calendar: Calendar = .billing) -> [Date] {
        let midnight = calendar.startOfDay(for: now)
        return [now] + (1...max(days, 1)).compactMap { calendar.date(byAdding: .day, value: $0, to: midnight) }
    }

    // MARK: - Where it is kept

    /// The settings the app shares with its widgets.
    static let suiteName = "group.com.pausely.app.shared"
    static let key = "widget_feed"

    /// What an earlier version published. Removed when the feed is written, so nothing stale is left.
    static let earlierKeys = ["widget_monthlySpend", "widget_activeCount", "widget_upcomingCount", "widget_currencyCode",
                              "widget_topInsight", "widget_monthlySpendText", "widget_monthlySpendWholeText",
                              "widget_yearlySpendWholeText", "widget_trials", "liveActivity_subscriptionName",
                              "liveActivity_renewalDate", "liveActivity_amountText"]

    /// Nil when nothing has been published, or when it can't be read (a phone not yet unlocked after a
    /// restart): the widget then says to open Pausely instead of claiming there is nothing to pay for.
    static func read(from defaults: UserDefaults? = UserDefaults(suiteName: suiteName)) -> WidgetFeed? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetFeed.self, from: data)
    }

    func write(to defaults: UserDefaults? = UserDefaults(suiteName: suiteName)) {
        guard let defaults, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
        Self.earlierKeys.forEach(defaults.removeObject(forKey:))
    }
}
