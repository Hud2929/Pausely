//
//  Typography.swift
//  Pausely
//
//  SF Pro Typography Scale
//

import SwiftUI

// MARK: - Typography Scale
enum STFont {
    // Display — used for hero numbers (total spend, savings)
    static let displayLarge  = Font.system(size: 48, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 36, weight: .bold, design: .rounded)
    static let displaySmall  = Font.system(size: 28, weight: .bold, design: .rounded)
    
    // Headlines — section headers
    static let headlineLarge = Font.system(size: 22, weight: .semibold, design: .default)
    static let headlineMedium = Font.system(size: 20, weight: .semibold, design: .default)
    static let headlineSmall = Font.system(size: 17, weight: .semibold, design: .default)
    
    // Body
    static let bodyLarge     = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium    = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall     = Font.system(size: 13, weight: .regular, design: .default)
    
    // Labels — metadata, captions
    static let labelLarge    = Font.system(size: 15, weight: .medium, design: .default)
    static let labelMedium   = Font.system(size: 13, weight: .medium, design: .default)
    static let labelSmall    = Font.system(size: 11, weight: .medium, design: .default)
    
    // Mono — for currency values
    static let monoLarge     = Font.system(size: 36, weight: .bold, design: .monospaced)
    static let monoMedium    = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let monoSmall     = Font.system(size: 15, weight: .medium, design: .monospaced)
}

// MARK: - Text Style Extensions
extension Text {
    func displayLarge() -> some View {
        self.font(STFont.displayLarge)
    }
    
    func displayMedium() -> some View {
        self.font(STFont.displayMedium)
    }
    
    func displaySmall() -> some View {
        self.font(STFont.displaySmall)
    }
    
    func headlineLarge() -> some View {
        self.font(STFont.headlineLarge)
    }
    
    func headlineMedium() -> some View {
        self.font(STFont.headlineMedium)
    }
    
    func headlineSmall() -> some View {
        self.font(STFont.headlineSmall)
    }
    
    func bodyLarge() -> some View {
        self.font(STFont.bodyLarge)
    }
    
    func bodyMedium() -> some View {
        self.font(STFont.bodyMedium)
    }
    
    func bodySmall() -> some View {
        self.font(STFont.bodySmall)
    }
    
    func labelLarge() -> some View {
        self.font(STFont.labelLarge)
    }
    
    func labelMedium() -> some View {
        self.font(STFont.labelMedium)
    }
    
    func labelSmall() -> some View {
        self.font(STFont.labelSmall)
    }
    
    func monoLarge() -> some View {
        self.font(STFont.monoLarge)
    }
    
    func monoMedium() -> some View {
        self.font(STFont.monoMedium)
    }
    
    func monoSmall() -> some View {
        self.font(STFont.monoSmall)
    }
}
