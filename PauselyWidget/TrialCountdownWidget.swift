import SwiftUI
import WidgetKit

// Free trials about to turn into a charge: the soonest on the small widget, the next three on the
// medium one. It reads the same feed as the charges widget and draws again at midnight.

struct TrialCountdownWidget: Widget {
    let kind = "PauselyTrialCountdown"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargesProvider(hasNothingToShow: { feed, today in
            feed.trialsEnding(on: today).isEmpty
        })) { entry in
            TrialsWidgetView(entry: entry)
        }
        .configurationDisplayName("Free trials")
        .description("Free trials about to start charging.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TrialsWidgetView: View {
    let entry: ChargesEntry
    @Environment(\.widgetFamily) private var family

    private var trials: [WidgetFeed.Upcoming] { entry.feed?.trialsEnding(on: entry.date) ?? [] }

    var body: some View {
        Group {
            if let first = trials.first {
                if family == .systemMedium, trials.count > 1 {
                    HStack(alignment: .top, spacing: 14) {
                        TrialEnding(trial: first)
                        Rectangle().fill(Color.widgetLine).frame(width: 1)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(trials.dropFirst().prefix(3).enumerated()), id: \.element.id) { index, item in
                                if index > 0 { Rectangle().fill(Color.widgetLine).frame(height: 1) }
                                ChargeRow(item: item)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    TrialEnding(trial: first)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Free trials").font(.caption.weight(.semibold)).ink(.muted)
                    Text(entry.feed == nil ? "Open Pausely" : "No free trials")
                        .font(.footnote)
                        .ink(.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .environment(\.locale, entry.locale)
        .widgetURL(trials.first.flatMap { WidgetLink.subscription($0.charge.id) })
        .inkGround()
    }
}

/// One trial: what it is, when it ends (the thing that matters), and what it costs from then on.
struct TrialEnding: View {
    let trial: WidgetFeed.Upcoming

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Free trial ends")
                .font(.caption.weight(.semibold))
                .ink(.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            Text(verbatim: trial.charge.name)
                .font(.subheadline.weight(.semibold))
                .ink()
                .lineLimit(1)
                .privacySensitive()
            Text(verbatim: DayText.text(daysAway: trial.daysAway, day: trial.day, locale: locale))
                .font(.system(.title2, design: .serif).weight(.semibold))
                .ink()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Spacer(minLength: 6)
            Text("Then \(trial.charge.amountText)")
                .font(.caption.weight(.medium))
                .ink(.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .privacySensitive()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

#Preview(as: .systemSmall) {
    TrialCountdownWidget()
} timeline: {
    ChargesEntry(date: Date(), feed: .sample())
    ChargesEntry(date: Date(), feed: WidgetFeed())
}
