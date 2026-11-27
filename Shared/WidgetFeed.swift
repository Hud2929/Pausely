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

    /// One scheduled Pause Plan turn published ahead so widgets roll over cleanly at midnight without opening the app.
    struct PauseTurn: Codable, Equatable {
        let name: String
        /// First day of this turn ("YYYY-MM-DD"), or empty for the currently running turn.
        let startStamp: String
        /// Handoff day ("YYYY-MM-DD") when the next turn starts at midnight.
        let endStamp: String
        let endText: String
        let nextName: String
    }

    /// One midnight-aware Savings Receipt snapshot so "Kept so far" ticks up automatically as avoided charge days pass.
    struct SavingsSnapshot: Codable, Equatable {
        let stamp: String
        let savedSoFarText: String
        let savedSoFarIsZero: Bool
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
    /// True when at least one active or trial subscription is still charging.
    var hasChargingSubscriptions = false
    /// Formatted Savings Receipt totals for the Savings Receipt widget (empty until first cancellation).
    var savedSoFarText = ""
    var savedSoFarIsZero = true
    var onTrackText = ""
    var cancelledCount = 0
    /// Ordered snapshots (`stamp` ascending) so Savings Receipt updates at midnight on avoided charge days.
    var savingsSnapshots: [SavingsSnapshot] = []
    /// Current active Pause Plan streaming turn, if a Pro plan is running, with its end day-stamp ("YYYY-MM-DD")
    /// so widgets automatically stop showing an expired turn at midnight.
    var pauseTurnName = ""
    var pauseTurnEndText = ""
    var pauseTurnEndStamp = ""
    var pauseTurnNextName = ""
    /// Upcoming Pause Plan turns (current + future) so widgets advance to the next service at midnight.
    var pauseTurns: [PauseTurn] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case charges, monthlyText, yearlyText, language, hasSubscriptions, hasChargingSubscriptions
        case savedSoFarText, savedSoFarIsZero, onTrackText, cancelledCount, savingsSnapshots
        case pauseTurnName, pauseTurnEndText, pauseTurnEndStamp, pauseTurnNextName, pauseTurns
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        charges = try c.decodeIfPresent([Charge].self, forKey: .charges) ?? []
        monthlyText = try c.decodeIfPresent(String.self, forKey: .monthlyText) ?? ""
        yearlyText = try c.decodeIfPresent(String.self, forKey: .yearlyText) ?? ""
        language = try c.decodeIfPresent(String.self, forKey: .language)
        hasSubscriptions = try c.decodeIfPresent(Bool.self, forKey: .hasSubscriptions) ?? false
        hasChargingSubscriptions = try c.decodeIfPresent(Bool.self, forKey: .hasChargingSubscriptions)
            ?? (hasSubscriptions && (!charges.isEmpty || !monthlyText.isEmpty))
        savedSoFarText = try c.decodeIfPresent(String.self, forKey: .savedSoFarText) ?? ""
        savedSoFarIsZero = try c.decodeIfPresent(Bool.self, forKey: .savedSoFarIsZero) ?? true
        onTrackText = try c.decodeIfPresent(String.self, forKey: .onTrackText) ?? ""
        cancelledCount = try c.decodeIfPresent(Int.self, forKey: .cancelledCount) ?? 0
        savingsSnapshots = try c.decodeIfPresent([SavingsSnapshot].self, forKey: .savingsSnapshots) ?? []
        pauseTurnName = try c.decodeIfPresent(String.self, forKey: .pauseTurnName) ?? ""
        pauseTurnEndText = try c.decodeIfPresent(String.self, forKey: .pauseTurnEndText) ?? ""
        pauseTurnEndStamp = try c.decodeIfPresent(String.self, forKey: .pauseTurnEndStamp) ?? ""
        pauseTurnNextName = try c.decodeIfPresent(String.self, forKey: .pauseTurnNextName) ?? ""
        pauseTurns = try c.decodeIfPresent([PauseTurn].self, forKey: .pauseTurns) ?? []
    }

    /// Returns the Savings Receipt totals valid on `today`, rolling forward across published avoided-charge snapshots.
    func savings(on today: Date, calendar: Calendar = .billing) -> (savedSoFarText: String, savedSoFarIsZero: Bool, onTrackText: String) {
        let todayStamp = calendar.dayStamp(today)
        if let snapshot = savingsSnapshots.last(where: { $0.stamp <= todayStamp }) {
            return (snapshot.savedSoFarText, snapshot.savedSoFarIsZero, onTrackText)
        }
        return (savedSoFarText, savedSoFarIsZero, onTrackText)
    }

    /// Returns the active Pause Plan turn on `today`, advancing across published turns at midnight.
    func activePauseTurn(on today: Date, calendar: Calendar = .billing) -> (name: String, endText: String, endStamp: String, nextName: String)? {
        let todayStamp = calendar.dayStamp(today)
        if !pauseTurns.isEmpty {
            guard let turn = pauseTurns.first(where: {
                ($0.startStamp.isEmpty || todayStamp >= $0.startStamp) && todayStamp < $0.endStamp
            }) else { return nil }
            return (turn.name, turn.endText, turn.endStamp, turn.nextName)
        }
        guard !pauseTurnName.isEmpty else { return nil }
        if !pauseTurnEndStamp.isEmpty, todayStamp > pauseTurnEndStamp {
            return nil
        }
        return (pauseTurnName, pauseTurnEndText, pauseTurnEndStamp, pauseTurnNextName)
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
