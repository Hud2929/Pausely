//
//  Typography.swift
//  Pausely
//
//  SF Pro Typography Scale
//

import SwiftUI

// MARK: - Typography Scale
enum STFont {
    static let displayMedium = Font.system(.title, design: .rounded).weight(.bold)

    // Headlines — section headers
    static let headlineLarge = Font.title3.weight(.semibold)
    static let headlineMedium = Font.headline.weight(.semibold)

    static let bodyMedium    = Font.subheadline
    static let bodySmall     = Font.footnote

    // Labels — metadata, captions
    static let labelLarge    = Font.subheadline.weight(.medium)
    static let labelMedium   = Font.footnote.weight(.medium)
    static let labelSmall    = Font.caption2.weight(.medium)

}

