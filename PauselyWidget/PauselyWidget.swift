import SwiftUI
import WidgetKit

// What charges next, on the Home Screen and the Lock Screen. The app publishes the days ahead
// (`WidgetFeed`); the widget works out what is next on the day it draws, and draws again at midnight.

// MARK: - Timeline

struct ChargesEntry: TimelineEntry {
    let date: Date
    /// Nil when nothing has been published yet, or it can't be read (a phone not unlocked since a restart).
    let feed: WidgetFeed?

    var upcoming: [WidgetFeed.Upcoming] { feed?.upcoming(on: date) ?? [] }
    var locale: Locale { feed?.locale ?? .current }
}

struct ChargesProvider: TimelineProvider {
    /// Whether the person's own list has nothing for this widget to show. In the widget gallery an
    /// example is shown then, so the widget can be seen before it is chosen; on the Home Screen it
    /// never is.
    var hasNothingToShow: (WidgetFeed, Date) -> Bool = { feed, today in feed.upcoming(on: today).isEmpty }

    func placeholder(in context: Context) -> ChargesEntry {
        ChargesEntry(date: Date(), feed: .sample())
    }

    func getSnapshot(in context: Context, completion: @escaping (ChargesEntry) -> Void) {
        let now = Date()
        let feed = WidgetFeed.read()
        let showExample = context.isPreview && (feed.map { hasNothingToShow($0, now) } ?? true)
        completion(ChargesEntry(date: now, feed: showExample ? .sample() : feed))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargesEntry>) -> Void) {
        let now = Date()
        guard let feed = WidgetFeed.read() else {
            // Nothing to read yet: look again soon instead of showing an empty list for hours.
            completion(Timeline(entries: [ChargesEntry(date: now, feed: nil)], policy: .after(now.addingTimeInterval(15 * 60))))
            return
        }
        let entries = WidgetFeed.refreshMoments(from: now).map { ChargesEntry(date: $0, feed: feed) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - The widget

struct PauselyWidget: Widget {
    let kind = "PauselyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargesProvider()) { entry in
            ChargesWidgetView(entry: entry)
        }
        .configurationDisplayName("Next charge")
        .description("What charges next, and when.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct ChargesWidgetView: View {
    let entry: ChargesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemMedium: MediumCharges(entry: entry)
            case .systemLarge: LargeCharges(entry: entry)
            case .accessoryCircular: CircularCharge(entry: entry)
            case .accessoryRectangular: RectangularCharge(entry: entry)
            case .accessoryInline: InlineCharge(entry: entry)
            default: SmallCharge(entry: entry)
            }
        }
        .environment(\.locale, entry.locale)
        .environment(\.layoutDirection, entry.locale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        .widgetURL(entry.upcoming.first.flatMap { WidgetLink.destination(for: $0) })
        .inkGround()
    }
}

// MARK: - When there is nothing to show

/// Why there is no charge to show, in a sentence that says what to do.
struct NothingYet: View {
    let entry: ChargesEntry
    var font: Font = .footnote

    var body: some View {
        Text(message)
            .font(font)
            .ink(.muted)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var message: LocalizedStringKey {
        guard let feed = entry.feed else { return "Open Pausely" }
        if !feed.hasSubscriptions { return "Add what you pay for in Pausely" }
        return "Add renewal dates in Pausely to see what's next"
    }
}

// MARK: - Small: the next charge

struct SmallCharge: View {
    let entry: ChargesEntry

    var body: some View {
        if let next = entry.upcoming.first {
            NextCharge(next: next)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Next charge").font(.caption.weight(.semibold)).ink(.muted)
                NothingYet(entry: entry)
            }
        }
    }
}

/// One charge: what it is, what it costs (the one big thing), and when.
struct NextCharge: View {
    let next: WidgetFeed.Upcoming

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(next.isTrialEnd ? "Free trial ends" : "Next charge")
                .font(.caption.weight(.semibold))
                .ink(.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            Text(verbatim: next.charge.name)
                .font(.subheadline.weight(.semibold))
                .ink()
                .lineLimit(1)
                .privacySensitive()
            Text(verbatim: next.charge.amountText)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .ink()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .privacySensitive()
                .widgetAccentable()
            Spacer(minLength: 6)
            DayLabel(upcoming: next)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Medium: the next charge, and the two after it

struct MediumCharges: View {
    let entry: ChargesEntry

    var body: some View {
        let upcoming = entry.upcoming
        if let next = upcoming.first {
            HStack(alignment: .top, spacing: 14) {
                NextCharge(next: next)
                if upcoming.count > 1 {
                    Rectangle().fill(Color.widgetLine).frame(width: 1)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(upcoming.dropFirst().prefix(3).enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Rectangle().fill(Color.widgetLine).frame(height: 1) }
                            ChargeRow(item: item)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            SmallCharge(entry: entry)
        }
    }
}

/// A later charge on one line pair: its name and day, its amount.
struct ChargeRow: View {
    let item: WidgetFeed.Upcoming

    var body: some View {
        Link(destination: WidgetLink.destination(for: item) ?? URL(string: "pausely://")!) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: item.charge.name)
                        .font(.footnote.weight(.semibold))
                        .ink()
                        .lineLimit(1)
                        .privacySensitive()
                    DayLabel(upcoming: item, font: .caption2.weight(.medium))
                }
                Spacer(minLength: 4)
                Text(verbatim: item.charge.amountText)
                    .font(.footnote.monospacedDigit())
                    .ink()
                    .lineLimit(1)
                    .privacySensitive()
            }
            .padding(.vertical, 6)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Large: the month, then what charges next

struct LargeCharges: View {
    let entry: ChargesEntry

    var body: some View {
        let upcoming = entry.upcoming
        VStack(alignment: .leading, spacing: 0) {
            if let feed = entry.feed, !feed.monthlyText.isEmpty {
                Text("Each month").font(.caption.weight(.semibold)).ink(.muted)
                Text(verbatim: feed.monthlyText)
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .ink()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .privacySensitive()
                    .widgetAccentable()
                    .padding(.bottom, 10)
            }
            if upcoming.isEmpty {
                NothingYet(entry: entry)
            } else {
                // As many as fit: seven at the default text size, fewer when the text is larger.
                ViewThatFits(in: .vertical) {
                    ForEach([7, 6, 5, 4, 3, 2, 1], id: \.self) { count in
                        rows(Array(upcoming.prefix(count)))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func rows(_ items: [WidgetFeed.Upcoming]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Rectangle().fill(Color.widgetLine).frame(height: 1) }
                ChargeRow(item: item)
            }
        }
    }
}

// MARK: - Lock Screen

/// The day of the next charge as a calendar leaf: the month over the day.
struct CircularCharge: View {
    let entry: ChargesEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let next = entry.upcoming.first {
                VStack(spacing: -2) {
                    Text(verbatim: next.day.formatted(.dateTime.month(.abbreviated).locale(entry.locale)))
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                    Text(verbatim: next.day.formatted(.dateTime.day().locale(entry.locale)))
                        .font(.title2.weight(.semibold))
                        .widgetAccentable()
                }
                .minimumScaleFactor(0.6)
                .privacySensitive()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(next.charge.name), \(DayText.text(daysAway: next.daysAway, day: next.day, locale: entry.locale))"))
            } else {
                Image(systemName: "calendar").font(.title3).accessibilityHidden(true)
            }
        }
    }
}

struct RectangularCharge: View {
    let entry: ChargesEntry

    var body: some View {
        if let next = entry.upcoming.first {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: next.charge.name)
                    .font(.headline)
                    .lineLimit(1)
                    .privacySensitive()
                    .widgetAccentable()
                Text(verbatim: next.charge.amountText)
                    .font(.subheadline.monospacedDigit())
                    .lineLimit(1)
                    .privacySensitive()
                DayLabel(upcoming: next, font: .caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            NothingYet(entry: entry, font: .caption)
        }
    }
}

struct InlineCharge: View {
    let entry: ChargesEntry

    var body: some View {
        if let next = entry.upcoming.first {
            Text(verbatim: "\(next.charge.name) · \(DayText.text(daysAway: next.daysAway, day: next.day, locale: entry.locale))")
                .privacySensitive()
        } else {
            Text("Pausely")
        }
    }
}

// MARK: - The bundle

@main
struct PauselyWidgetBundle: WidgetBundle {
    var body: some Widget {
        PauselyWidget()
        TrialCountdownWidget()
        SavingsReceiptWidget()
    }
}

#Preview(as: .systemSmall) {
    PauselyWidget()
} timeline: {
    ChargesEntry(date: Date(), feed: .sample())
    ChargesEntry(date: Date(), feed: nil)
}

#Preview(as: .systemMedium) {
    PauselyWidget()
} timeline: {
    ChargesEntry(date: Date(), feed: .sample())
}

#Preview(as: .systemLarge) {
    PauselyWidget()
} timeline: {
    ChargesEntry(date: Date(), feed: .sample())
}
