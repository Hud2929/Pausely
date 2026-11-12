import Foundation

extension Calendar {
    /// Whole calendar days from `start` to `end`, comparing dates rather than elapsed hours.
    /// A bill at 9am nine days from now is "in 9 days" even if it is 3pm today, never "in 8".
    func calendarDays(from start: Date, to end: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: start), to: startOfDay(for: end)).day ?? 0
    }
}
