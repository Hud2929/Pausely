import SwiftUI

private struct DayBill: Identifiable {
    let id = UUID()
    let dayLabel: String
    let dayNumber: String
    let daysAway: Int
    let subscriptions: [Subscription]
    let convertedTotal: Decimal  // already converted to user's selected currency
    var isEmpty: Bool { subscriptions.isEmpty }
}

/// Horizontal 7-day timeline showing every subscription billing in the next week.
/// Color-coded urgency: red (today/tomorrow), orange (2-4 days), mint (5-7 days).
struct BillsThisWeekCard: View {
    let subscriptions: [Subscription]
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var pressedDayId: UUID?

    private var billsByDay: [DayBill] {
        let calendar = Calendar.current
        let today = Date()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let numFormatter = DateFormatter()
        numFormatter.dateFormat = "d"

        return (0..<7).compactMap { offset -> DayBill? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let subs = subscriptions.filter { ($0.daysUntilRenewal ?? -1) == offset }
            let total = subs.reduce(Decimal(0)) { sum, sub in
                sum + currencyManager.convertToSelected(sub.amount, from: sub.currency)
            }

            let label: String
            switch offset {
            case 0: label = "TODAY"
            case 1: label = "TMR"
            default: label = dayFormatter.string(from: date).uppercased()
            }

            return DayBill(
                dayLabel: label,
                dayNumber: numFormatter.string(from: date),
                daysAway: offset,
                subscriptions: subs,
                convertedTotal: total
            )
        }
    }

    private func urgencyColor(_ daysAway: Int) -> Color {
        if daysAway <= 1 { return Color.semanticDestructive }
        if daysAway <= 4 { return Color.semanticWarning }
        return Color.accentMint
    }

    var body: some View {
        let days = billsByDay
        let weekTotal = days.reduce(Decimal(0)) { $0 + $1.convertedTotal }

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Bills This Week")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if weekTotal > 0 {
                    Text(currencyManager.format(weekTotal))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentMint)
                } else {
                    Text("Nothing due")
                        .font(.subheadline)
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days) { day in
                        let color = urgencyColor(day.daysAway)
                        let isPressed = pressedDayId == day.id
                        Button(action: {
                            guard !day.isEmpty else { return }
                            HapticStyle.light.trigger()
                        }) {
                            VStack(spacing: 8) {
                                // Day header
                                VStack(spacing: 2) {
                                    Text(day.dayLabel)
                                        .font(.system(.caption2, design: .rounded).weight(.bold))
                                        .foregroundStyle(day.isEmpty ? Color.obsidianTextTertiary : color)
                                        .tracking(0.3)
                                    Text(day.dayNumber)
                                        .font(.system(.callout, design: .rounded).weight(.bold))
                                        .foregroundStyle(day.isEmpty ? Color.obsidianTextTertiary : .white)
                                }
                                .frame(minWidth: 58, minHeight: 44)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(day.isEmpty ? Color.obsidianElevated.opacity(0.4) : color.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(day.isEmpty ? Color.clear : color.opacity(0.3), lineWidth: 1)
                                        )
                                )

                                // Bills on this day
                                if day.isEmpty {
                                    Circle()
                                        .fill(Color.obsidianElevated.opacity(0.4))
                                        .frame(width: 6, height: 6)
                                        .padding(.vertical, 4)
                                } else {
                                    VStack(spacing: 4) {
                                        // Show logo for first subscription, or count badge for multiples
                                        if day.subscriptions.count == 1, let sub = day.subscriptions.first {
                                            ServiceLogoView(name: sub.name, category: sub.category, size: 26)
                                        } else {
                                            ZStack {
                                                Circle()
                                                    .fill(color.opacity(0.18))
                                                    .frame(width: 26, height: 26)
                                                Text("\(day.subscriptions.count)")
                                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                                    .foregroundStyle(color)
                                            }
                                        }
                                        Text(currencyManager.format(day.convertedTotal))
                                            .font(.system(.caption2, design: .rounded).weight(.bold))
                                            .foregroundStyle(color)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        // Urgency label for all days with bills
                                        if day.daysAway == 0 {
                                            Text("TODAY")
                                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                                .foregroundStyle(color)
                                        } else {
                                            Text("in \(day.daysAway)d")
                                                .font(.system(.caption2, design: .rounded).weight(.semibold))
                                                .foregroundStyle(color.opacity(0.8))
                                        }
                                    }
                                }
                            }
                            .frame(width: 58)
                            .scaleEffect(isPressed ? 0.96 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(day.isEmpty)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !day.isEmpty { pressedDayId = day.id }
                                }
                                .onEnded { _ in pressedDayId = nil }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
