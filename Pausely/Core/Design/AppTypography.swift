import SwiftUI

// MARK: - Dynamic Type Typography
/// Accessibility-first typography using Dynamic Type with the app's rounded design.
/// All sizes scale automatically with the user's text size preferences.
enum AppTypography {
    static let displayMedium  = Font.system(.title, design: .default, weight: .bold)
    static let displaySmall   = Font.system(.title2, design: .default, weight: .bold)

    // Headings
    static let headlineLarge  = Font.system(.title3, design: .default, weight: .semibold)
    static let headlineMedium = Font.system(.headline, design: .default, weight: .semibold)
    static let headlineSmall  = Font.system(.subheadline, design: .default, weight: .semibold)

    // Body
    static let bodyLarge      = Font.system(.body, design: .default, weight: .regular)
    static let bodyMedium     = Font.system(.callout, design: .default, weight: .regular)
    static let bodySmall      = Font.system(.subheadline, design: .default, weight: .regular)

    // Labels / Captions
    static let labelLarge     = Font.system(.footnote, design: .default, weight: .medium)
    static let labelMedium    = Font.system(.caption, design: .default, weight: .medium)
    static let labelSmall     = Font.system(.caption2, design: .default, weight: .medium)

}
