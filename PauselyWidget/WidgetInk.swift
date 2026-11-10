import SwiftUI

/// The app's state colours, for the widget target (which can't see the app's design system).
/// Widgets keep the system's own background and text styles so they follow the Home Screen's
/// light, dark and tinted modes; only state is coloured, and never by colour alone.
extension Color {
    /// Charged today or tomorrow.
    static let widgetDue = Color(red: 0xF2 / 255, green: 0x6B / 255, blue: 0x5E / 255)
    /// A decision is waiting.
    static let widgetDecide = Color(red: 0xF2 / 255, green: 0xB2 / 255, blue: 0x4B / 255)
}
