import SwiftUI

@MainActor
struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_language") private var selectedLanguage = "system"
    @State private var searchText = ""

    /// Languages that have translations in Localizable.xcstrings
    let languages: [AppLanguage] = [
        AppLanguage(code: "system", name: "System Default", flag: "📱", isRTL: false),
        AppLanguage(code: "en", name: "English", flag: "🇺🇸", isRTL: false),
        AppLanguage(code: "es", name: "Spanish", flag: "🇪🇸", isRTL: false),
        AppLanguage(code: "fr", name: "French", flag: "🇫🇷", isRTL: false),
        AppLanguage(code: "de", name: "German", flag: "🇩🇪", isRTL: false),
        AppLanguage(code: "ja", name: "Japanese", flag: "🇯🇵", isRTL: false),
        AppLanguage(code: "ar", name: "Arabic", flag: "🇸🇦", isRTL: true),
    ]

    var filteredLanguages: [AppLanguage] {
        if searchText.isEmpty {
            return languages
        }
        return languages.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Display name for the currently selected language
    static func displayName(for code: String) -> String {
        if code == "system" { return "System" }
        let supported: [String: String] = [
            "en": "English", "es": "Spanish", "fr": "French",
            "de": "German", "ja": "Japanese", "ar": "Arabic"
        ]
        return supported[code] ?? code.uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.largeTitle)
                        .foregroundStyle(Color.inkText)

                    Text("Language")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.inkText)

                    Text("Choose your preferred language")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.inkTextMuted)
                }
                .padding(.top, 20)

                // Search (only show if enough languages to warrant it)
                if languages.count > 5 {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.inkTextFaint)

                        TextField("Search languages...", text: $searchText)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .keyboardType(.default)
                            .submitLabel(.search)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.inkTextFaint)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                }

                // Language List
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredLanguages) { language in
                        LanguageRow(
                            language: language,
                            isSelected: selectedLanguage == language.code,
                            action: {
                                selectedLanguage = language.code
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Info Note
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.inkText)

                    Text("Language changes apply instantly. Some features may not be fully translated yet.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inkTextMuted)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppLanguage: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let flag: String
    let isRTL: Bool
}

struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(language.flag)
                    .font(.title)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.inkText)

                    Text(language.code == "system" ? "Uses device language" : language.code.uppercased())
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inkTextFaint)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.inkText)
                }
            }
            .padding()
            .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.inkTextMuted : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

