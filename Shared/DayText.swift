import Foundation

/// A day as a widget says it: "today", "tomorrow", "in 3 days" for the week ahead, the date after
/// that. The words and their plural forms are the system's own, in every language, so the widgets
/// need no translated sentence for them.
enum DayText {
    /// "today", "tomorrow", "in 3 days", in `locale`.
    static func relative(daysAway: Int, locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter.localizedString(from: DateComponents(day: daysAway))
    }

    /// "Nov 28", in `locale`.
    static func date(_ day: Date, locale: Locale) -> String {
        day.formatted(.dateTime.month(.abbreviated).day().locale(locale))
    }

    /// Words for the week ahead, the date beyond it.
    static func text(daysAway: Int, day: Date, locale: Locale) -> String {
        daysAway <= 7 ? relative(daysAway: daysAway, locale: locale) : date(day, locale: locale)
    }
}
