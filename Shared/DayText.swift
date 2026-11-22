import Foundation

/// A day as a widget says it: "today", "tomorrow", "in 3 days" for the week ahead, the date after
/// that. The words and their plural forms are the system's own, in every language, so the widgets
/// need no translated sentence for them.
enum DayText {
    /// "today", "tomorrow", "in 3 days", "3 days ago", in `locale`. `capitalized` for a line of its own
    /// ("Tomorrow"), in the languages that capitalise.
    static func relative(daysAway: Int, locale: Locale, capitalized: Bool = false) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        formatter.formattingContext = capitalized ? .beginningOfSentence : .middleOfSentence
        return formatter.localizedString(from: DateComponents(day: daysAway))
    }

    /// "Nov 28", in `locale`; "Dec 26, 2025" when the day is not in this year. The one way a day is
    /// written, in the app and the widgets. Without the year, a charge from last December read as one
    /// coming next month ("Last charged Dec 26", written in November 2026 about December 2025).
    /// `weekday` puts the day of the week in front ("Thu, Nov 28").
    static func date(_ day: Date, locale: Locale, now: Date = Date(), calendar: Calendar = .billing,
                     weekday: Bool = false) -> String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        if weekday { style = style.weekday(.abbreviated) }
        if calendar.component(.year, from: day) != calendar.component(.year, from: now) { style = style.year() }
        return day.formatted(style.locale(locale))
    }

    /// Words for the week ahead, the date beyond it.
    static func text(daysAway: Int, day: Date, locale: Locale) -> String {
        daysAway <= 7 ? relative(daysAway: daysAway, locale: locale) : date(day, locale: locale)
    }
}
