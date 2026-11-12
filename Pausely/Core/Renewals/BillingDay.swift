import Foundation

/// A day that is a day, not a moment: a renewal day, the last day of a trial.
///
/// The app works with such a day as noon on that day in the phone's time zone, which is what the
/// renewal engine expects. Saved (on the server, in the copy kept on the iPhone, in the history) it is
/// noon UTC on that day, so it names the same calendar day wherever it is read. Before, a day was saved
/// as noon in the time zone it was typed in: 15 November typed in Toronto was 16 November, two in the
/// morning, in Tokyo, and every renewal and reminder moved a day for someone who flew there.
enum BillingDay {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// The saved form of a day the app holds: noon UTC on the same calendar day.
    static func stored(_ local: Date, calendar: Calendar = .billing) -> Date {
        let day = calendar.dateComponents([.year, .month, .day], from: local)
        return utc.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)) ?? local
    }

    /// The day a saved value names, as noon in the phone's time zone.
    ///
    /// A value that is exactly noon UTC was saved by this version and names its UTC day. Anything else
    /// was saved by an earlier version as noon in whatever time zone it was typed in; it is read as the
    /// day it falls on here, as it always was, and takes the new form the next time it is saved.
    static func local(fromStored saved: Date, calendar: Calendar = .billing) -> Date {
        guard isStoredForm(saved) else { return calendar.noon(of: saved) }
        let day = utc.dateComponents([.year, .month, .day], from: saved)
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)) ?? saved
    }

    /// True for a value in the saved form: exactly noon UTC.
    static func isStoredForm(_ date: Date) -> Bool {
        let time = utc.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return time.hour == 12 && time.minute == 0 && time.second == 0 && (time.nanosecond ?? 0) < 1_000_000
    }
}

/// A day inside something that is saved (see `BillingDay`): the app sees noon in the phone's time
/// zone, the saved copy holds noon UTC.
@propertyWrapper
struct SavedDay: Codable, Equatable, Hashable {
    var wrappedValue: Date?

    init(wrappedValue: Date?) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = container.decodeNil() ? nil : BillingDay.local(fromStored: try container.decode(Date.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let day = wrappedValue {
            try container.encode(BillingDay.stored(day))
        } else {
            try container.encodeNil()
        }
    }
}

extension KeyedDecodingContainer {
    /// A day that was never saved is no day, not an error.
    func decode(_ type: SavedDay.Type, forKey key: Key) throws -> SavedDay {
        try decodeIfPresent(type, forKey: key) ?? SavedDay(wrappedValue: nil)
    }
}

extension KeyedEncodingContainer {
    /// No day, no key: the saved copy looks as it did before days had a saved form.
    mutating func encode(_ value: SavedDay, forKey key: Key) throws {
        guard let day = value.wrappedValue else { return }
        try encode(BillingDay.stored(day), forKey: key)
    }
}
