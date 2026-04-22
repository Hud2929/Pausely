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
    static let displayLarge  = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let displayMedium = Font.system(.title, design: .rounded).weight(.bold)
    static let displaySmall  = Font.system(.title2, design: .rounded).weight(.bold)

    // Headlines — section headers
    static let headlineLarge = Font.title3.weight(.semibold)
    static let headlineMedium = Font.headline.weight(.semibold)
    static let headlineSmall = Font.body.weight(.semibold)

    // Body
    static let bodyLarge     = Font.body
    static let bodyMedium    = Font.subheadline
    static let bodySmall     = Font.footnote

    // Labels — metadata, captions
    static let labelLarge    = Font.subheadline.weight(.medium)
    static let labelMedium   = Font.footnote.weight(.medium)
    static let labelSmall    = Font.caption2.weight(.medium)

    // Mono — for currency values
    static let monoLarge     = Font.system(.title, design: .monospaced).weight(.bold)
    static let monoMedium    = Font.system(.headline, design: .monospaced).weight(.semibold)
    static let monoSmall     = Font.system(.subheadline, design: .monospaced).weight(.medium)
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
