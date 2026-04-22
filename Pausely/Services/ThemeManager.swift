import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("is_dark_mode") var isDarkMode: Bool = true {
        didSet {
            applyTheme()
        }
    }
    
    @AppStorage("system_theme") var useSystemTheme: Bool = true {
        didSet {
            applyTheme()
        }
    }
    
    private init() {
        applyTheme()
    }
    
    func applyTheme() {
        // Theme is applied via environment in ContentView
        objectWillChange.send()
    }
    
    var colorScheme: ColorScheme? {
        if useSystemTheme {
            return nil // Let system decide
        }
        return isDarkMode ? .dark : .light
    }
    
    func toggleDarkMode() {
        useSystemTheme = false
        isDarkMode.toggle()
    }
    
    func useSystem() {
        useSystemTheme = true
    }
}

// MARK: - Theme Colors
extension Color {
    // Background colors that adapt
    static var appBackground: Color {
        Color(UIColor.systemBackground)
    }
    
    static var appSecondaryBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
}
