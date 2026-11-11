import SwiftUI

/// The app's language. Each language is written the way its speakers write it, so it can be found
/// by someone who can't read the current one.
@MainActor
struct LanguageSettingsView: View {
    @AppStorage("app_language") private var selectedLanguage = "system"

    /// The languages Pausely is translated into (`Localizable.xcstrings`).
    static let languages: [(code: String, name: String)] = [
        ("en", "English"), ("es", "Español"), ("fr", "Français"), ("de", "Deutsch"), ("ja", "日本語"), ("ar", "العربية")
    ]

    /// What the Profile row shows for the chosen language.
    static func displayName(for code: String) -> String {
        if code == "system" { return L10n.string("Same as iPhone") }
        return languages.first { $0.code == code }?.name ?? code.uppercased()
    }

    var body: some View {
        SettingsPage(title: "Language") {
            SettingsSection {
                ChoiceRow(title: L10n.string("Same as iPhone"), isChosen: selectedLanguage == "system") { selectedLanguage = "system" }
                    .accessibilityIdentifier("language-system")
                ForEach(Self.languages, id: \.code) { language in
                    ChoiceRow(title: language.name, isChosen: selectedLanguage == language.code) { selectedLanguage = language.code }
                        .accessibilityIdentifier("language-\(language.code)")
                }
            }
        }
    }
}
