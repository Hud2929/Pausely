//  PauselyWidget.swift
//  PauselyWidget
//
//  Cataclysmic Widget Extension - Home Screen Intelligence

import WidgetKit
import SwiftUI

// MARK: - Widget Provider
struct PauselyWidgetProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> PauselyWidgetEntry {
        PauselyWidgetEntry(
            date: Date(),
            monthlySpend: 0,
            activeSubscriptions: 0,
            upcomingRenewals: 0,
            currencySymbol: "$",
            topInsight: "Loading...",
            nextChargeName: "–",
            nextChargeDate: nil,
            nextChargeAmount: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PauselyWidgetEntry) -> Void) {
        let summary = WidgetReader.readSummary()
        let entry = PauselyWidgetEntry(
            date: Date(),
            monthlySpend: summary.monthlySpend,
            activeSubscriptions: summary.activeCount,
            upcomingRenewals: summary.upcomingCount,
            currencySymbol: summary.currencySymbol,
            topInsight: summary.topInsight,
            nextChargeName: WidgetReader.readLiveActivityName(),
            nextChargeDate: WidgetReader.readLiveActivityDate(),
            nextChargeAmount: WidgetReader.readLiveActivityAmount()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PauselyWidgetEntry>) -> Void) {
        Task {
            // Fetch real data from shared UserDefaults or App Group
            let entry = await fetchCurrentEntry()
            
            // Update every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }
    
    private func fetchCurrentEntry() async -> PauselyWidgetEntry {
        let summary = WidgetReader.readSummary()
        return PauselyWidgetEntry(
            date: Date(),
            monthlySpend: summary.monthlySpend,
            activeSubscriptions: summary.activeCount,
            upcomingRenewals: summary.upcomingCount,
            currencySymbol: summary.currencySymbol,
            topInsight: summary.topInsight,
            nextChargeName: WidgetReader.readLiveActivityName(),
            nextChargeDate: WidgetReader.readLiveActivityDate(),
            nextChargeAmount: WidgetReader.readLiveActivityAmount()
        )
    }
}

// MARK: - Widget Entry
struct PauselyWidgetEntry: TimelineEntry {
    let date: Date
    let monthlySpend: Double
    let activeSubscriptions: Int
    let upcomingRenewals: Int
    let currencySymbol: String
    let topInsight: String
    // Next charge details (for small widget)
    let nextChargeName: String
    let nextChargeDate: Date?
    let nextChargeAmount: Double

    var nextChargeDays: Int {
        guard let d = nextChargeDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0)
    }
}

// MARK: - Widget Views
struct PauselyWidgetEntryView: View {
    var entry: PauselyWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (Next Charge)
struct SmallWidgetView: View {
    let entry: PauselyWidgetEntry

    private var urgencyColor: Color {
        switch entry.nextChargeDays {
        case 0...1: return .red
        case 2...3: return .orange
        case 4...7: return .yellow
        default:    return .green
        }
    }

    private var daysLabel: String {
        switch entry.nextChargeDays {
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(entry.nextChargeDays) days"
        }
    }

    private var hasData: Bool {
        entry.nextChargeAmount > 0 && entry.nextChargeName != "–" && entry.nextChargeName != "Subscription"
    }

    var body: some View {
        Group {
            if hasData {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(urgencyColor)
                            .frame(width: 6, height: 6)
                        Text("NEXT CHARGE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                    }

                    Spacer()

                    Text(entry.nextChargeName)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(entry.currencySymbol)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f", entry.nextChargeAmount))
                            .font(.system(.title2, design: .rounded).weight(.black))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Text(daysLabel)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(urgencyColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(urgencyColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(14)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Add subscriptions to track")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let entry: PauselyWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Main stat
            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly Spend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(entry.currencySymbol)
                        .font(.title3)
                    Text(String(format: "%.2f", entry.monthlySpend))
                        .font(.title.bold())
                }
                
                Text("\(entry.upcomingRenewals) renewing soon")
                    .font(.caption2)
                    .foregroundStyle(entry.upcomingRenewals > 0 ? .orange : .secondary)
            }
            
            Divider()
            
            // Right side - Details
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatItem(
                        icon: "app.badge.fill",
                        value: "\(entry.activeSubscriptions)",
                        label: "Active"
                    )
                    
                    StatItem(
                        icon: "calendar.badge.clock",
                        value: "\(entry.upcomingRenewals)",
                        label: "Renewing"
                    )
                }
                
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text(entry.topInsight)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let entry: PauselyWidgetEntry
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Pausely")
                        .font(.headline)
                    Text("Subscription Overview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.indigo)
            }
            
            // Main stats
            HStack(spacing: 20) {
                LargeStatCard(
                    title: "Monthly",
                    value: String(format: "%.2f", entry.monthlySpend),
                    prefix: entry.currencySymbol
                )
                
                LargeStatCard(
                    title: "Active",
                    value: "\(entry.activeSubscriptions)",
                    suffix: "subs"
                )
                
                LargeStatCard(
                    title: "Yearly",
                    value: String(format: "%.0f", entry.monthlySpend * 12),
                    prefix: entry.currencySymbol
                )
            }
            
            Divider()
            
            // Insights
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Insights")
                    .font(.caption.bold())
                
                InsightRow(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    text: entry.topInsight
                )
                
                InsightRow(
                    icon: "calendar.badge.clock",
                    color: .blue,
                    text: "\(entry.upcomingRenewals) renewal\(entry.upcomingRenewals == 1 ? "" : "s") in the next 7 days"
                )
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Accessory Widgets
struct AccessoryCircularView: View {
    let entry: PauselyWidgetEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack {
                Text(entry.currencySymbol)
                    .font(.caption)
                Text(String(format: "%.0f", entry.monthlySpend))
                    .font(.headline)
            }
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: PauselyWidgetEntry
    
    var body: some View {
        HStack {
            Image(systemName: "creditcard.fill")
            Text(entry.currencySymbol)
                .font(.caption) +
            Text(String(format: "%.2f", entry.monthlySpend))
                .font(.headline)
            Spacer()
            Text("\(entry.activeSubscriptions) subs")
                .font(.caption)
        }
    }
}

struct AccessoryInlineView: View {
    let entry: PauselyWidgetEntry
    
    var body: some View {
        Text(entry.currencySymbol)
            .font(.caption) +
        Text(String(format: "%.2f", entry.monthlySpend))
            .font(.headline)
    }
}

// MARK: - Supporting Views
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.indigo)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LargeStatCard: View {
    let title: String
    let value: String
    var prefix: String = ""
    var suffix: String = ""
    var trend: String? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(prefix)
                    .font(.caption)
                Text(value)
                    .font(.title3.bold())
                Text(suffix)
                    .font(.caption)
            }
            
            if let trend = trend {
                Text(trend)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
            Spacer()
        }
    }
}

// MARK: - Live Activity Widget
struct PauselyLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PauselyLiveActivityAttributes.self) { context in
            PauselyLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(context.state.isUrgent ? .red : .indigo)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.daysUntilRenewal) days")
                        .font(.headline)
                        .foregroundStyle(context.state.isUrgent ? .red : .primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.subscriptionName)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(context.state.isUrgent ? .red : .indigo)
            } compactTrailing: {
                Text("\(context.state.daysUntilRenewal)")
                    .foregroundStyle(context.state.isUrgent ? .red : .primary)
            } minimal: {
                Text("\(context.state.daysUntilRenewal)")
                    .foregroundStyle(context.state.isUrgent ? .red : .primary)
            }
        }
    }
}

// MARK: - Widget Bundle
@main
struct PauselyWidgetBundle: WidgetBundle {
    var body: some Widget {
        PauselyWidget()
        TrialCountdownWidget()
        PauselyLiveActivityWidget()
    }
}

// MARK: - Home Screen Widget
struct PauselyWidget: Widget {
    let kind: String = "PauselyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PauselyWidgetProvider()) { entry in
            PauselyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pausely")
        .description("Track your subscriptions at a glance")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    PauselyWidget()
} timeline: {
    PauselyWidgetEntry(date: Date(), monthlySpend: 142.99, activeSubscriptions: 12, upcomingRenewals: 2, currencySymbol: "$", topInsight: "Save $45 by pausing", nextChargeName: "Netflix", nextChargeDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()), nextChargeAmount: 15.99)
}

#Preview(as: .systemMedium) {
    PauselyWidget()
} timeline: {
    PauselyWidgetEntry(date: Date(), monthlySpend: 142.99, activeSubscriptions: 12, upcomingRenewals: 2, currencySymbol: "$", topInsight: "Save $45 by pausing unused subscriptions", nextChargeName: "Netflix", nextChargeDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()), nextChargeAmount: 15.99)
}
