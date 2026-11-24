import SwiftUI
import WidgetKit

/// Ink and Paper for the widgets, which can't see the app's design system: the same colours (from the
/// shared `Palette`), the serif for the one number, and state shown by a symbol as well as a colour.
extension Color {
    init(palette hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }

    static let widgetInk = Color(palette: Palette.ink)
    static let widgetText = Color(palette: Palette.text)
    static let widgetMuted = Color(palette: Palette.textMuted)
    static let widgetLine = Color.white.opacity(0.1)
    /// Charged today or tomorrow.
    static let widgetDue = Color(palette: Palette.due)
    /// A few days away.
    static let widgetDecide = Color(palette: Palette.decide)
}

/// How near a charge is, as the app shows it: due (today or tomorrow) and soon (within three days)
/// each have a colour and a symbol; anything further is plain.
enum Nearness {
    case due, soon, later

    init(daysAway: Int) {
        self = daysAway <= 1 ? .due : daysAway <= 3 ? .soon : .later
    }

    var symbol: String? {
        switch self {
        case .due: "exclamationmark.circle.fill"
        case .soon: "clock.fill"
        case .later: nil
        }
    }

    var color: Color {
        switch self {
        case .due: .widgetDue
        case .soon: .widgetDecide
        case .later: .widgetMuted
        }
    }
}

/// The day of a charge in words, with its mark: "tomorrow" with an exclamation mark, "in 3 days" with
/// a clock, "Nov 28" plain.
struct DayLabel: View {
    let upcoming: WidgetFeed.Upcoming
    var font: Font = .caption.weight(.semibold)

    @Environment(\.locale) private var locale
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let nearness = Nearness(daysAway: upcoming.daysAway)
        HStack(spacing: 4) {
            if let symbol = nearness.symbol {
                Image(systemName: symbol).accessibilityHidden(true)
            }
            Text(verbatim: DayText.text(daysAway: upcoming.daysAway, day: upcoming.day, locale: locale))
        }
        .font(font)
        .foregroundStyle(renderingMode == .fullColor ? AnyShapeStyle(nearness.color) : AnyShapeStyle(.primary))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// Text colours that hold up when iOS takes the widget's background away (tinted and clear Home
/// Screens, StandBy, the Lock Screen): the ink palette in full colour, the system's own styles otherwise.
struct InkText: ViewModifier {
    enum Role { case primary, muted }
    let role: Role
    @Environment(\.widgetRenderingMode) private var renderingMode

    func body(content: Content) -> some View {
        switch (role, renderingMode == .fullColor) {
        case (.primary, true): content.foregroundStyle(Color.widgetText)
        case (.muted, true): content.foregroundStyle(Color.widgetMuted)
        case (.primary, false): content.foregroundStyle(.primary)
        case (.muted, false): content.foregroundStyle(.secondary)
        }
    }
}

extension View {
    func ink(_ role: InkText.Role = .primary) -> some View { modifier(InkText(role: role)) }

    /// The widget's ground: ink, which iOS may remove where it draws its own.
    func inkGround() -> some View {
        containerBackground(for: .widget) { Color.widgetInk }
    }
}

extension WidgetFeed {
    /// The locale a widget speaks: the language chosen in the app, or the iPhone's.
    var locale: Locale {
        language.map { Locale(identifier: $0) } ?? .current
    }

    /// What the widget gallery shows before the person has a list: three made-up lines, named for
    /// kinds of subscription, not for anyone's product.
    static func sample(on today: Date = Date()) -> WidgetFeed {
        let calendar = Calendar.billing
        func days(_ offset: Int) -> [String] {
            [calendar.dayStamp(calendar.date(byAdding: .day, value: offset, to: today) ?? today)]
        }
        var feed = WidgetFeed()
        feed.hasSubscriptions = true
        feed.charges = [
            Charge(id: UUID(), name: String(localized: "Streaming"), amountText: "$15.49", days: days(1), startsWithTrialEnd: false),      // money-guard: sample
            Charge(id: UUID(), name: String(localized: "Music"), amountText: "$10.99", days: days(3), startsWithTrialEnd: true),            // money-guard: sample
            Charge(id: UUID(), name: String(localized: "Cloud storage"), amountText: "$2.99", days: days(12), startsWithTrialEnd: false),   // money-guard: sample
        ]
        feed.monthlyText = "$29.47"   // money-guard: sample
        feed.yearlyText = "$354"      // money-guard: sample
        return feed
    }
}

/// A link that opens one subscription in the app.
enum WidgetLink {
    static func subscription(_ id: UUID) -> URL? {
        URL(string: "pausely://subscription/manage?id=\(id.uuidString)")
    }
}
