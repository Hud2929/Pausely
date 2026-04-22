import SwiftUI

@MainActor
struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_language") private var selectedLanguage = "en"
    @State private var searchText = ""
    
    let languages: [AppLanguage] = [
        AppLanguage(code: "en", name: "English", flag: "🇺🇸", isRTL: false),
        AppLanguage(code: "es", name: "Spanish", flag: "🇪🇸", isRTL: false),
        AppLanguage(code: "fr", name: "French", flag: "🇫🇷", isRTL: false),
        AppLanguage(code: "de", name: "German", flag: "🇩🇪", isRTL: false),
        AppLanguage(code: "it", name: "Italian", flag: "🇮🇹", isRTL: false),
        AppLanguage(code: "pt", name: "Portuguese", flag: "🇧🇷", isRTL: false),
        AppLanguage(code: "ru", name: "Russian", flag: "🇷🇺", isRTL: false),
        AppLanguage(code: "zh", name: "Chinese (Simplified)", flag: "🇨🇳", isRTL: false),
        AppLanguage(code: "ja", name: "Japanese", flag: "🇯🇵", isRTL: false),
        AppLanguage(code: "ko", name: "Korean", flag: "🇰🇷", isRTL: false),
        AppLanguage(code: "ar", name: "Arabic", flag: "🇸🇦", isRTL: true),
        AppLanguage(code: "hi", name: "Hindi", flag: "🇮🇳", isRTL: false),
        AppLanguage(code: "nl", name: "Dutch", flag: "🇳🇱", isRTL: false),
        AppLanguage(code: "pl", name: "Polish", flag: "🇵🇱", isRTL: false),
        AppLanguage(code: "tr", name: "Turkish", flag: "🇹🇷", isRTL: false),
        AppLanguage(code: "sv", name: "Swedish", flag: "🇸🇪", isRTL: false),
    ]
    
    var filteredLanguages: [AppLanguage] {
        if searchText.isEmpty {
            return languages
        }
        return languages.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.luxuryGold)
                    
                    Text("Language")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Choose your preferred language")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 20)
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.5))
                    
                    TextField("Search languages...", text: $searchText)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .keyboardType(.default)
                        .submitLabel(.search)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.1))
                )
                .padding(.horizontal, 20)
                
                // Suggested Section
                if searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggested")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        
                        let suggested = languages.prefix(3)
                        ForEach(suggested) { language in
                            LanguageRow(
                                language: language,
                                isSelected: selectedLanguage == language.code,
                                action: { selectedLanguage = language.code }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // All Languages
                VStack(alignment: .leading, spacing: 12) {
                    Text(searchText.isEmpty ? "All Languages" : "Results")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    
                    ForEach(filteredLanguages) { language in
                        LanguageRow(
                            language: language,
                            isSelected: selectedLanguage == language.code,
                            action: { selectedLanguage = language.code }
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                // Info Note
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.luxuryGold)
                    
                    Text("Some features may not be available in all languages. The app will restart to apply changes.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .glass(intensity: 0.05, tint: .white)
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
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text(language.code.uppercased())
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.luxuryGold)
                }
            }
            .padding()
            .glass(intensity: isSelected ? 0.15 : 0.08, tint: isSelected ? Color.luxuryGold : .white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.luxuryGold.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LanguageSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSettingsView()
            .background(Color.black)
    }
}
