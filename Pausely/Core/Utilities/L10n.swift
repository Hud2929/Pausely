import Foundation

/// Text built in code, in the app's language.
///
/// SwiftUI views follow Settings → Language through the `\.locale` environment, but `String(localized:)`
/// always uses the iPhone's language. Anything built outside a `Text` (engine explanations, errors, scan
/// progress, notifications, frequency names) goes through here so it matches the screen around it.
enum L10n {
    static let languageKey = "app_language"

    /// The locale of the language chosen in Settings → Language, or nil to follow the iPhone.
    static var chosenLocale: Locale? {
        chosenLanguage.map { locale(language: $0, onDevice: .current) }
    }

    /// A language chosen in the app, with the iPhone's own region: a Canadian who picks English still
    /// reads "$15.49" for Canadian dollars (a bare "en" would print "CA$15.49"), and dates keep the
    /// order their region uses.
    static func locale(language code: String, onDevice device: Locale) -> Locale {
        var components = Locale.Components(locale: device)
        // The region belongs to the language part of a locale: it is carried over, not dropped.
        let language = Locale.Language.Components(identifier: code)
        components.languageComponents = Locale.Language.Components(languageCode: language.languageCode, script: language.script,
                                                                   region: device.region)
        return Locale(components: components)
    }

    /// True when the chosen language is written right to left. Nil when the app follows the iPhone,
    /// which then sets the direction itself.
    static var isRightToLeft: Bool? {
        chosenLanguage.map { Locale.Language(identifier: $0).characterDirection == .rightToLeft }
    }

    /// "today", "tomorrow", "in 3 days", "3 days ago": a day counted from today, in the app's language,
    /// with the system's own plural forms.
    static func relativeDay(_ daysAway: Int, capitalized: Bool = false) -> String {
        DayText.relative(daysAway: daysAway, locale: locale, capitalized: capitalized)
    }

    /// A few words that stay on one line together: a date ("Nov 24"), how far off it is
    /// ("In 12 days"). For short phrases only; a long one that cannot break is cut instead.
    static func whole(_ words: String) -> String {
        words.replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    /// A line of parts joined by " · " breaks after a dot, never before one. With `whole` parts it
    /// reads "Nov 24 ·" above "In 12 days"; it used to end "Nov 24 · In" with "12 days" under it.
    static func breakingAfterDots(_ line: String) -> String {
        line.replacingOccurrences(of: " · ", with: "\u{00A0}· ")
    }

    /// The language chosen in Settings → Language ("ar", "de"…), or nil to follow the iPhone.
    static var chosenLanguage: String? {
        guard let code = UserDefaults.standard.string(forKey: languageKey), code != "system" else { return nil }
        return code
    }

    /// The locale for everything the code builds: sentences, money, dates, numbers.
    static var locale: Locale { chosenLocale ?? .current }

    /// A whole number as the reader writes it: "5" in English, "٥" where Arabic digits are used. A
    /// count put on screen as a bare `"\(n)"` stayed in Latin digits beside Arabic ones.
    /// Whole sentences, one after the other. Most languages put a space between two sentences;
    /// Japanese does not ("…です。 次の文" with a space reads as a typing slip).
    static func sentences(_ parts: [String], locale: Locale = L10n.locale) -> String {
        let unspaced: Set<String> = ["ja", "zh"]
        return parts.joined(separator: unspaced.contains(locale.language.languageCode?.identifier ?? "") ? "" : " ")
    }

    static func number(_ value: Int, locale: Locale = L10n.locale) -> String {
        value.formatted(.number.locale(locale))
    }

    static func string(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        if let chosen = chosenLocale { resource.locale = chosen }
        return String(localized: resource)
    }
}
