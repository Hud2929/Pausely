//
//  TrialCountdownWidget.swift
//  PauselyWidget
//
//  Free trial countdown — small (most urgent trial) + medium (top 3 trials)
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TrialCountdownEntry: TimelineEntry {
    let date: Date
    let trials: [WidgetTrialInfo]

    var mostUrgent: WidgetTrialInfo? { trials.first }
}

// MARK: - Provider

struct TrialCountdownProvider: TimelineProvider {

    func placeholder(in context: Context) -> TrialCountdownEntry {
        TrialCountdownEntry(date: Date(), trials: [
            WidgetTrialInfo(
                id: "preview",
                name: "Netflix",
                trialEndsAt: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
                monthlyAmount: 15.99,
                currencyCode: "USD",
                billingFrequency: "Monthly"
            )
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (TrialCountdownEntry) -> Void) {
        let trials = WidgetReader.readTrials()
        completion(TrialCountdownEntry(date: Date(), trials: trials))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrialCountdownEntry>) -> Void) {
        let trials = WidgetReader.readTrials()
        let entry = TrialCountdownEntry(date: Date(), trials: trials)
        // Refresh every 6 hours — trials don't change often
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Widget Definition

struct TrialCountdownWidget: Widget {
    let kind = "PauselyTrialCountdown"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrialCountdownProvider()) { entry in
            TrialCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Trial Countdown")
        .description("See when your free trials end before you're charged.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Root View

struct TrialCountdownWidgetView: View {
    var entry: TrialCountdownEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            TrialMediumView(entry: entry)
        default:
            TrialSmallView(entry: entry)
        }
    }
}

// MARK: - Small Widget (single most-urgent trial)

struct TrialSmallView: View {
    let entry: TrialCountdownEntry

    var body: some View {
        if let trial = entry.mostUrgent {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(urgencyColor(for: trial.daysRemaining))
                    Spacer()
                    Text("TRIAL")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(trial.daysRemaining)")
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .foregroundStyle(urgencyColor(for: trial.daysRemaining))
                    Text(trial.daysRemaining == 1 ? "day left" : "days left")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(trial.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(trial.currencySymbol)\(String(format: "%.2f", trial.monthlyAmount))/\(shortFrequency(trial.billingFrequency)) after")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            TrialNoDataView()
        }
    }
}

// MARK: - Medium Widget (up to 3 trials)

struct TrialMediumView: View {
    let entry: TrialCountdownEntry

    var body: some View {
        if entry.trials.isEmpty {
            TrialNoDataView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Trial Countdowns")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                    Spacer()
                }

                ForEach(entry.trials.prefix(3)) { trial in
                    TrialRowView(trial: trial)
                }

                if entry.trials.count > 3 {
                    Text("+\(entry.trials.count - 3) more")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct TrialRowView: View {
    let trial: WidgetTrialInfo

    var body: some View {
        HStack {
            // Urgency indicator dot
            Circle()
                .fill(urgencyColor(for: trial.daysRemaining))
                .frame(width: 8, height: 8)

            Text(trial.name)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text("\(trial.daysRemaining)d")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(urgencyColor(for: trial.daysRemaining))
                .frame(minWidth: 24, alignment: .trailing)

            Text("\(trial.currencySymbol)\(String(format: "%.2f", trial.monthlyAmount))")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Empty State

private struct TrialNoDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
            Text("No active trials")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Helpers

private func urgencyColor(for daysRemaining: Int) -> Color {
    if daysRemaining <= 1 { return .red }
    if daysRemaining <= 3 { return .orange }
    return .yellow
}

private func shortFrequency(_ frequency: String) -> String {
    switch frequency.lowercased() {
    case "monthly": return "mo"
    case "annual", "yearly": return "yr"
    case "weekly": return "wk"
    case "quarterly": return "qtr"
    default: return "mo"
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    TrialCountdownWidget()
} timeline: {
    TrialCountdownEntry(date: Date(), trials: [
        WidgetTrialInfo(
            id: "1",
            name: "Spotify",
            trialEndsAt: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            monthlyAmount: 9.99,
            currencyCode: "USD",
            billingFrequency: "Monthly"
        )
    ])
    TrialCountdownEntry(date: Date(), trials: [])
}

#Preview(as: .systemMedium) {
    TrialCountdownWidget()
} timeline: {
    TrialCountdownEntry(date: Date(), trials: [
        WidgetTrialInfo(id: "1", name: "Spotify", trialEndsAt: Calendar.current.date(byAdding: .day, value: 1, to: Date())!, monthlyAmount: 9.99, currencyCode: "USD", billingFrequency: "Monthly"),
        WidgetTrialInfo(id: "2", name: "Hulu", trialEndsAt: Calendar.current.date(byAdding: .day, value: 3, to: Date())!, monthlyAmount: 17.99, currencyCode: "USD", billingFrequency: "Monthly"),
        WidgetTrialInfo(id: "3", name: "Disney+", trialEndsAt: Calendar.current.date(byAdding: .day, value: 6, to: Date())!, monthlyAmount: 13.99, currencyCode: "USD", billingFrequency: "Monthly")
    ])
}
