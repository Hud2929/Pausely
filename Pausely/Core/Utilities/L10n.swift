import Foundation

/// Text built in code, in the app's language.
///
/// SwiftUI views follow Settings → Language through the `\.locale` environment, but `String(localized:)`
/// always uses the iPhone's language. Anything built outside a `Text` (engine explanations, errors, scan
/// progress, notifications, frequency names) goes through here so it matches the screen around it.
enum L10n {
    static let languageKey = "app_language"

    /// The language chosen in Settings → Language, or nil to follow the iPhone.
    static var chosenLocale: Locale? {
        guard let code = UserDefaults.standard.string(forKey: languageKey), code != "system" else { return nil }
        return Locale(identifier: code)
    }

    /// The locale for formatting dates and numbers in code-built text.
    static var locale: Locale { chosenLocale ?? .current }

    static func string(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        if let chosen = chosenLocale { resource.locale = chosen }
        return String(localized: resource)
    }
}
