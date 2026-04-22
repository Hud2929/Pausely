import SwiftUI

// MARK: - Dynamic Type Typography
/// Accessibility-first typography using Dynamic Type with the app's rounded design.
/// All sizes scale automatically with the user's text size preferences.
enum AppTypography {
    // Display
    static let displayLarge   = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let displayMedium  = Font.system(.title, design: .rounded, weight: .bold)
    static let displaySmall   = Font.system(.title2, design: .rounded, weight: .bold)

    // Headings
    static let headlineLarge  = Font.system(.title3, design: .rounded, weight: .semibold)
    static let headlineMedium = Font.system(.headline, design: .rounded, weight: .semibold)
    static let headlineSmall  = Font.system(.subheadline, design: .rounded, weight: .semibold)

    // Body
    static let bodyLarge      = Font.system(.body, design: .rounded, weight: .regular)
    static let bodyMedium     = Font.system(.callout, design: .rounded, weight: .regular)
    static let bodySmall      = Font.system(.subheadline, design: .rounded, weight: .regular)

    // Labels / Captions
    static let labelLarge     = Font.system(.footnote, design: .rounded, weight: .medium)
    static let labelMedium    = Font.system(.caption, design: .rounded, weight: .medium)
    static let labelSmall     = Font.system(.caption2, design: .rounded, weight: .medium)

    // Special
    static let numericLarge   = Font.system(.title, design: .rounded, weight: .bold).monospacedDigit()
    static let numericMedium  = Font.system(.headline, design: .rounded, weight: .semibold).monospacedDigit()
    static let numericSmall   = Font.system(.body, design: .rounded, weight: .regular).monospacedDigit()
}
