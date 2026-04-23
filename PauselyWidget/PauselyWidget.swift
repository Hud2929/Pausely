//  PauselyWidget.swift
//  PauselyWidget
//
//  Cataclysmic Widget Extension - Home Screen Intelligence

import WidgetKit
import SwiftUI

// MARK: - Widget Provider
struct PauselyWidgetProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> PauselyWidgetEntry {
        // Widget placeholder - shows loading state without fake data
        PauselyWidgetEntry(
            date: Date(),
            monthlySpend: 0,
            activeSubscriptions: 0,
            upcomingRenewals: 0,
            currencySymbol: "$",
            topInsight: "Loading..."
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PauselyWidgetEntry) -> Void) {
        let summary = WidgetDataStore.shared.readSummary()
        let entry = PauselyWidgetEntry(
            date: Date(),
            monthlySpend: summary.monthlySpend,
            activeSubscriptions: summary.activeCount,
            upcomingRenewals: summary.upcomingCount,
            currencySymbol: summary.currencySymbol,
            topInsight: summary.topInsight
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
        let summary = WidgetDataStore.shared.readSummary()
        return PauselyWidgetEntry(
            date: Date(),
            monthlySpend: summary.monthlySpend,
            activeSubscriptions: summary.activeCount,
            upcomingRenewals: summary.upcomingCount,
            currencySymbol: summary.currencySymbol,
            topInsight: summary.topInsight
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

// MARK: - Small Widget
struct SmallWidgetView: View {
    let entry: PauselyWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.indigo)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.currencySymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary) +
                Text(String(format: "%.0f", entry.monthlySpend))
                    .font(.title2.bold())
                
                Text("monthly")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack {
                Image(systemName: "app.fill")
                    .font(.caption)
                Text("\(entry.activeSubscriptions)")
                    .font(.caption.bold())
            }
            .foregroundStyle(.indigo)
        }
        .padding()
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
                
                HStack {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                    Text("12% from last month")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
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
                    prefix: entry.currencySymbol,
                    trend: "+12%"
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
                    icon: "checkmark.circle.fill",
                    color: .green,
                    text: "You saved $89 this month!"
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

// MARK: - Widget Configuration
@main
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
    PauselyWidgetEntryView(
        entry: PauselyWidgetEntry(
            date: Date(),
            monthlySpend: 142.99,
            activeSubscriptions: 12,
            upcomingRenewals: 2,
            currencySymbol: "$",
            topInsight: "Save $45 by pausing unused subscriptions"
        )
    )
}

#Preview(as: .systemMedium) {
    PauselyWidgetEntryView(
        entry: PauselyWidgetEntry(
            date: Date(),
            monthlySpend: 142.99,
            activeSubscriptions: 12,
            upcomingRenewals: 2,
            currencySymbol: "$",
            topInsight: "Save $45 by pausing unused subscriptions"
        )
    )
}
