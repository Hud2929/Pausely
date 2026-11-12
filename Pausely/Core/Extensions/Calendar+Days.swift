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

    /// Whole calendar days from `start` to `end`, comparing dates rather than elapsed hours.
    /// A bill at 9am nine days from now is "in 9 days" even if it is 3pm today, never "in 8".
    func calendarDays(from start: Date, to end: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: start), to: startOfDay(for: end)).day ?? 0
    }
}
