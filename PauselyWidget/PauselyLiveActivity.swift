//
//  PauselyLiveActivity.swift
//  PauselyWidget
//
//  Live Activity for subscription renewal countdown
//

import ActivityKit
import SwiftUI
import WidgetKit

// NOTE: This file requires PauselyLiveActivityAttributes.swift to be included in the widget extension target

struct PauselyLiveActivityView: View {
    let context: ActivityViewContext<PauselyLiveActivityAttributes>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundGradient

            HStack(spacing: 16) {
                // Icon / Brand
                VStack(spacing: 4) {
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundStyle(context.state.isUrgent ? .red : .indigo)

                    Text("Pausely")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60)

                Divider()
                    .opacity(0.3)

                // Subscription info
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.subscriptionName)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    Text("\(context.attributes.currencySymbol)\(String(format: "%.2f", context.attributes.amount)) / \(context.attributes.frequency)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Countdown
                VStack(alignment: .trailing, spacing: 4) {
                    if context.state.daysUntilRenewal > 0 {
                        Text("\(context.state.daysUntilRenewal)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(context.state.isUrgent ? .red : .primary)

                        Text(context.state.daysUntilRenewal == 1 ? "day" : "days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(context.state.hoursUntilRenewal)h")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(.red)
                    }

                    Text("until renewal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var backgroundGradient: some View {
        ContainerRelativeShape()
            .fill(context.state.isUrgent
                  ? Color.red.opacity(0.08)
                  : (colorScheme == .dark ? Color.black : Color.white))
    }
}

// MARK: - Expanded / Compact Views

struct PauselyLiveActivityCompactLeadingView: View {
    let context: ActivityViewContext<PauselyLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "creditcard.fill")
                .foregroundStyle(context.state.isUrgent ? .red : .indigo)
            Text("\(context.state.daysUntilRenewal)d")
                .font(.caption.weight(.bold))
        }
    }
}

struct PauselyLiveActivityCompactTrailingView: View {
    let context: ActivityViewContext<PauselyLiveActivityAttributes>

    var body: some View {
        Text(context.attributes.subscriptionName)
            .font(.caption)
            .lineLimit(1)
    }
}

struct PauselyLiveActivityMinimalView: View {
    let context: ActivityViewContext<PauselyLiveActivityAttributes>

    var body: some View {
        VStack {
            Image(systemName: "creditcard.fill")
                .foregroundStyle(context.state.isUrgent ? .red : .indigo)
            Text("\(context.state.daysUntilRenewal)")
                .font(.caption2.weight(.bold))
        }
    }
}

// MARK: - Widget Configuration with Live Activity
// This would be added to the @main struct in PauselyWidget.swift:
//
// @main
// struct PauselyWidgetBundle: WidgetBundle {
//     var body: some Widget {
//         PauselyWidget()
//         PauselyLiveActivityWidget()
//     }
// }
//
// struct PauselyLiveActivityWidget: Widget {
//     var body: some WidgetConfiguration {
//         ActivityConfiguration(for: PauselyLiveActivityAttributes.self) { context in
//             PauselyLiveActivityView(context: context)
//         } dynamicIsland: { context in
//             DynamicIsland {
//                 DynamicIslandExpandedRegion(.leading) {
//                     PauselyLiveActivityCompactLeadingView(context: context)
//                 }
//                 DynamicIslandExpandedRegion(.trailing) {
//                     PauselyLiveActivityCompactTrailingView(context: context)
//                 }
//                 DynamicIslandExpandedRegion(.bottom) {
//                     PauselyLiveActivityView(context: context)
//                 }
//             } compactLeading: {
//                 PauselyLiveActivityCompactLeadingView(context: context)
//             } compactTrailing: {
//                 PauselyLiveActivityCompactTrailingView(context: context)
//             } minimal: {
//                 PauselyLiveActivityMinimalView(context: context)
//             }
//         }
//     }
// }
