import SwiftUI
import WidgetKit

// Proof of money kept on the Home Screen and Lock Screen: shows what cancelled subscriptions have
// saved so far (leading with the 12-month trajectory on Day 0), and the current Pause Plan turn
// when active (automatically expiring at midnight via `activePauseTurn(on:)`).

struct SavingsReceiptWidget: Widget {
    let kind = "PauselySavingsReceipt"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargesProvider(hasNothingToShow: { feed, today in
            feed.savedSoFarText.isEmpty && feed.onTrackText.isEmpty && feed.activePauseTurn(on: today) == nil
        })) { entry in
            SavingsWidgetView(entry: entry)
        }
        .configurationDisplayName("Savings Receipt")
        .description("Money kept from cancelled subscriptions.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct SavingsWidgetView: View {
    let entry: ChargesEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var hasSavings: Bool {
        guard let feed = entry.feed else { return false }
        return !feed.onTrackText.isEmpty || !feed.savedSoFarText.isEmpty
    }

    private var activePauseTurn: (name: String, endText: String, nextName: String)? {
        entry.feed?.activePauseTurn(on: entry.date)
    }

    private var keptStyle: AnyShapeStyle {
        renderingMode == .fullColor ? AnyShapeStyle(Color.widgetKept) : AnyShapeStyle(.primary)
    }

    /// Leads with 12-month trajectory on Day 0 (before the first avoided charge passes) instead of "$0.00".
    private func leadsWithOnTrack(_ feed: WidgetFeed) -> Bool {
        (feed.savedSoFarText.isEmpty || feed.savedSoFarIsZero) && !feed.onTrackText.isEmpty
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                rectangular
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .environment(\.locale, entry.locale)
        .environment(\.layoutDirection, entry.locale.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        .widgetURL(WidgetLink.receipt)
        .inkGround()
    }

    @ViewBuilder private var small: some View {
        if let feed = entry.feed, hasSavings {
            savingsColumn(feed, showFooter: true)
        } else if let turn = activePauseTurn {
            pauseTurnColumn(turn)
        } else {
            emptyState
        }
    }

    @ViewBuilder private var medium: some View {
        if let feed = entry.feed, hasSavings {
            let showRightPause = activePauseTurn != nil
            let leadOnTrack = leadsWithOnTrack(feed)
            HStack(alignment: .top, spacing: 14) {
                savingsColumn(feed, showFooter: showRightPause)
                Rectangle().fill(Color.widgetLine).frame(width: 1)
                if let turn = activePauseTurn {
                    pauseTurnColumn(turn)
                } else if leadOnTrack {
                    cancelledCountColumn(feed.cancelledCount)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("On track over 12 months")
                            .font(.caption.weight(.semibold))
                            .ink(.muted)
                            .lineLimit(2)
                        Text(verbatim: feed.onTrackText)
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .ink()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .privacySensitive()
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        } else if let turn = activePauseTurn {
            pauseTurnColumn(turn)
        } else {
            emptyState
        }
    }

    @ViewBuilder private var rectangular: some View {
        if let feed = entry.feed, hasSavings {
            let leadOnTrack = leadsWithOnTrack(feed)
            VStack(alignment: .leading, spacing: 2) {
                Text(leadOnTrack ? "On track over 12 months" : "Savings Receipt")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(verbatim: leadOnTrack ? feed.onTrackText : feed.savedSoFarText)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .privacySensitive()
                    .widgetAccentable()
                if !leadOnTrack, !feed.onTrackText.isEmpty {
                    Text("On track: \(feed.onTrackText)")
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .privacySensitive()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else if let turn = activePauseTurn {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pause Plan")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(verbatim: turn.name)
                    .font(.headline)
                    .lineLimit(1)
                    .privacySensitive()
                    .widgetAccentable()
                if !turn.endText.isEmpty {
                    Text("On until \(turn.endText)")
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            Text(entry.feed == nil ? "Open Pausely" : "Cancel a subscription to start your receipt")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func savingsColumn(_ feed: WidgetFeed, showFooter: Bool) -> some View {
        let leadOnTrack = leadsWithOnTrack(feed)
        return VStack(alignment: .leading, spacing: 0) {
            Text(leadOnTrack ? "On track over 12 months" : "Kept so far")
                .font(.caption.weight(.semibold))
                .ink(.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            Text(verbatim: leadOnTrack ? feed.onTrackText : feed.savedSoFarText)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(keptStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .privacySensitive()
                .widgetAccentable()
            Spacer(minLength: 6)
            if !leadOnTrack, showFooter, !feed.onTrackText.isEmpty {
                Text("On track: \(feed.onTrackText)")
                    .font(.caption.weight(.medium))
                    .ink(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
            } else if leadOnTrack, showFooter, feed.cancelledCount > 0 {
                let cancelledText = feed.cancelledCount.formatted(.number.locale(entry.locale))
                Text("Cancelled: \(cancelledText)")
                    .font(.caption.weight(.medium))
                    .ink(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func pauseTurnColumn(_ turn: (name: String, endText: String, nextName: String)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pause Plan")
                .font(.caption.weight(.semibold))
                .ink(.muted)
            Text(verbatim: turn.name)
                .font(.subheadline.weight(.semibold))
                .ink()
                .lineLimit(1)
                .privacySensitive()
                .widgetAccentable()
            if !turn.endText.isEmpty {
                Text("On until \(turn.endText)")
                    .font(.caption.weight(.medium))
                    .ink(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if !turn.nextName.isEmpty {
                Text("Next: \(turn.nextName)")
                    .font(.caption2.weight(.medium))
                    .ink(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func cancelledCountColumn(_ count: Int) -> some View {
        let cancelledText = count.formatted(.number.locale(entry.locale))
        return VStack(alignment: .leading, spacing: 6) {
            Text("Savings Receipt")
                .font(.caption.weight(.semibold))
                .ink(.muted)
            Text("Cancelled: \(cancelledText)")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .ink()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Savings Receipt").font(.caption.weight(.semibold)).ink(.muted)
            Text(entry.feed == nil ? "Open Pausely" : "Cancel a subscription to start your receipt")
                .font(.footnote)
                .ink(.muted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
