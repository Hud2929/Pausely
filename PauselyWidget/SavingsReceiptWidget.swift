import SwiftUI
import WidgetKit

// Proof of money kept on the Home Screen and Lock Screen: shows what cancelled subscriptions have
// saved so far (leading with the 12-month trajectory on Day 0), and the current Pause Plan turn
// when active (automatically expiring at midnight via `activePauseTurn(on:)`).

struct SavingsReceiptWidget: Widget {
    let kind = "PauselySavingsReceipt"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargesProvider(hasNothingToShow: { feed, today in
            let s = feed.savings(on: today)
            return s.savedSoFarText.isEmpty && s.onTrackText.isEmpty && feed.activePauseTurn(on: today) == nil
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

    private var currentSavings: (savedSoFarText: String, savedSoFarIsZero: Bool, onTrackText: String)? {
        entry.feed?.savings(on: entry.date)
    }

    private var hasSavings: Bool {
        guard let savings = currentSavings else { return false }
        return !savings.onTrackText.isEmpty || !savings.savedSoFarText.isEmpty
    }

    private var activePauseTurn: (name: String, endText: String, endStamp: String, nextName: String)? {
        entry.feed?.activePauseTurn(on: entry.date)
    }

    private var keptStyle: AnyShapeStyle {
        renderingMode == .fullColor ? AnyShapeStyle(Color.widgetKept) : AnyShapeStyle(.primary)
    }

    /// Leads with 12-month trajectory on Day 0 (before the first avoided charge passes) instead of "$0.00".
    private func leadsWithOnTrack(_ savings: (savedSoFarText: String, savedSoFarIsZero: Bool, onTrackText: String)) -> Bool {
        (savings.savedSoFarText.isEmpty || savings.savedSoFarIsZero) && !savings.onTrackText.isEmpty
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
        .widgetURL(!hasSavings && activePauseTurn != nil ? WidgetLink.pausePlan : WidgetLink.receipt)
        .inkGround()
    }

    @ViewBuilder private var small: some View {
        if let feed = entry.feed, let savings = currentSavings, hasSavings {
            savingsColumn(savings, cancelledCount: feed.cancelledCount, showFooter: true)
        } else if let turn = activePauseTurn {
            pauseTurnColumn(turn)
        } else {
            emptyState
        }
    }

    @ViewBuilder private var medium: some View {
        if let feed = entry.feed, let savings = currentSavings, hasSavings {
            let showRightPause = activePauseTurn != nil
            let leadOnTrack = leadsWithOnTrack(savings)
            HStack(alignment: .top, spacing: 14) {
                savingsColumn(savings, cancelledCount: feed.cancelledCount, showFooter: showRightPause)
                Rectangle().fill(Color.widgetLine).frame(width: 1)
                if let turn = activePauseTurn {
                    Link(destination: WidgetLink.pausePlan ?? URL(string: "pausely://pause-plan")!) {
                        pauseTurnColumn(turn)
                    }
                } else if leadOnTrack {
                    cancelledCountColumn(feed.cancelledCount)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("On track over 12 months")
                            .font(.caption.weight(.semibold))
                            .ink(.muted)
                            .lineLimit(2)
                        Text(verbatim: savings.onTrackText)
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
        if let savings = currentSavings, hasSavings {
            let leadOnTrack = leadsWithOnTrack(savings)
            VStack(alignment: .leading, spacing: 2) {
                Text(leadOnTrack ? "On track over 12 months" : "Savings Receipt")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(verbatim: leadOnTrack ? savings.onTrackText : savings.savedSoFarText)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .privacySensitive()
                    .widgetAccentable()
                if !leadOnTrack, !savings.onTrackText.isEmpty {
                    Text("On track: \(savings.onTrackText)")
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
                let endText = pauseEndText(for: turn)
                if !endText.isEmpty {
                    Text("On until \(endText)")
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .privacySensitive()
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

    private func savingsColumn(_ savings: (savedSoFarText: String, savedSoFarIsZero: Bool, onTrackText: String),
                               cancelledCount: Int, showFooter: Bool) -> some View {
        let leadOnTrack = leadsWithOnTrack(savings)
        return VStack(alignment: .leading, spacing: 0) {
            Text(leadOnTrack ? "On track over 12 months" : "Kept so far")
                .font(.caption.weight(.semibold))
                .ink(.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            Text(verbatim: leadOnTrack ? savings.onTrackText : savings.savedSoFarText)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(keptStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .privacySensitive()
                .widgetAccentable()
            Spacer(minLength: 6)
            if !leadOnTrack, showFooter, !savings.onTrackText.isEmpty {
                Text("On track: \(savings.onTrackText)")
                    .font(.caption.weight(.medium))
                    .ink(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
            } else if leadOnTrack, showFooter, cancelledCount > 0 {
                let cancelledText = cancelledCount.formatted(.number.locale(entry.locale))
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

    private func pauseEndText(for turn: (name: String, endText: String, endStamp: String, nextName: String)) -> String {
        if !turn.endStamp.isEmpty, let endDay = Calendar.billing.noon(onDayStamped: turn.endStamp) {
            return DayText.date(endDay, locale: entry.locale, now: entry.date)
        }
        return turn.endText
    }

    private func pauseTurnColumn(_ turn: (name: String, endText: String, endStamp: String, nextName: String)) -> some View {
        let endText = pauseEndText(for: turn)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Pause Plan")
                .font(.caption.weight(.semibold))
                .ink(.muted)
            Text(verbatim: turn.name)
                .font(.subheadline.weight(.semibold))
                .ink()
                .lineLimit(1)
                .privacySensitive()
                .widgetAccentable()
            if !endText.isEmpty {
                Text("On until \(endText)")
                    .font(.caption.weight(.medium))
                    .ink(.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
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
