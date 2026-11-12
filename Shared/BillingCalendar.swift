import Foundation

extension Calendar {
    /// The calendar renewals, reminders and ages are worked out in: Gregorian, in the phone's time zone.
    ///
    /// Services bill by the Gregorian calendar whatever calendar an iPhone shows. With the phone's own
    /// calendar, "a month later" is a lunar month of 29 or 30 days on an iPhone set to the Islamic
    /// calendar, and the year is another number in the Buddhist and Japanese ones. Nothing that works
    /// out a day uses the phone's calendar (`BillingCalendarTests` reads the sources). Dates are still
    /// shown in the person's own calendar, by the system's formatters.
    static let billing: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    /// "2026-11-15": a calendar day as text, the same in every time zone and calendar. Sorting these
    /// sorts the days.
    func dayStamp(_ date: Date) -> String {
        let parts = dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Noon on the day a stamp names, in this calendar's time zone. Nil for text that isn't a day.
    func noon(onDayStamped stamp: String) -> Date? {
        let parts = stamp.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}
