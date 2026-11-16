import Foundation

/// Hex values for every colour in the system. `InkPaperContrastTests` checks each text/background
/// pair against WCAG AA, so a change here that makes text unreadable fails the tests.
enum Palette {
    static let ink = "#0A0B0D"
    static let inkRaised = "#15171A"
    static let inkLifted = "#1F2226"
    static let paper = "#ECE7DC"
    static let paperShade = "#DDD7C9"
    static let paperInk = "#1A1A17"
    static let paperMuted = "#5A574E"
    static let paperKept = "#0B6245"
    static let paperDue = "#A3271C"
    static let text = "#F5F4F0"
    static let textMuted = "#B4B6BC"
    static let textFaint = "#9C9EA5"
    /// The edge of a field waiting to be typed in: 3 to 1 or more on every ink surface.
    static let fieldEdge = "#6B6E75"
    static let kept = "#34D399"
    static let decide = "#F2B24B"
    static let due = "#F26B5E"
    static let paused = "#7CB7F0"
}
