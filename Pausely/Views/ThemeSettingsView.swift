import SwiftUI

@MainActor
struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var systemColorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.luxuryPink)
                        
                        Text("Appearance")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Choose your preferred theme")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 20)
                    
                    // Theme Options
                    VStack(spacing: 12) {
                        // System Default
                        ThemeOptionRow(
                            icon: "iphone",
                            title: "System",
                            subtitle: "Follows your device settings",
                            isSelected: themeManager.useSystemTheme,
                            action: { 
                                themeManager.useSystemTheme = true
                            }
                        )
                        
                        // Light Mode
                        ThemeOptionRow(
                            icon: "sun.max.fill",
                            title: "Light",
                            subtitle: "Always use light mode",
                            isSelected: !themeManager.useSystemTheme && !themeManager.isDarkMode,
                            action: { 
                                themeManager.useSystemTheme = false
                                themeManager.isDarkMode = false
                            }
                        )
                        
                        // Dark Mode
                        ThemeOptionRow(
                            icon: "moon.fill",
                            title: "Dark",
                            subtitle: "Always use dark mode",
                            isSelected: !themeManager.useSystemTheme && themeManager.isDarkMode,
                            action: { 
                                themeManager.useSystemTheme = false
                                themeManager.isDarkMode = true
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 16) {
                            // Light Preview
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .frame(height: 80)
                                    .overlay(
                                        VStack {
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 30, height: 30)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 60, height: 8)
                                        }
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 4)
                                
                                Text("Light")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(!themeManager.isDarkMode ? Color.luxuryGold : .white.opacity(0.5))
                            }
                            
                            // Dark Preview
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black)
                                    .frame(height: 80)
                                    .overlay(
                                        VStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.3))
                                                .frame(width: 30, height: 30)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.white.opacity(0.3))
                                                .frame(width: 60, height: 8)
                                        }
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 4)
                                
                                Text("Dark")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(themeManager.isDarkMode ? Color.luxuryGold : .white.opacity(0.5))
                            }
                        }
                        .padding()
                        .glass(intensity: 0.08, tint: .white)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ThemeOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.luxuryPink.opacity(0.3) : .white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.luxuryPink : .white.opacity(0.7))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
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
            .glass(intensity: isSelected ? 0.15 : 0.08, tint: isSelected ? Color.luxuryPink : .white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.luxuryPink.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ThemeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ThemeSettingsView()
            .background(Color.black)
    }
}
