import SwiftUI
import UserNotifications

/// One thing on Home that wants a decision or an answer: a mark, a sentence, and the action.
struct AttentionRow: View {
    var state: MoneyState?
    var symbol: String?
    let title: String
    let detail: String
    let action: String
    let perform: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The room a symbol is given grows with it.
    @ScaledMetric(relativeTo: .footnote) private var symbolSide: CGFloat = 18

    var body: some View {
        Button {
            Feel.selection()
            perform()
        } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) { mark; text; actionLabel }
                } else {
                    HStack(alignment: .center, spacing: 12) { mark; text; Spacer(minLength: 8); actionLabel }
                }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var mark: some View {
        if let state, symbol == nil {
            StateMark(state: state)
        } else {
            Image(systemName: symbol ?? "circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(state?.color ?? Color.inkTextMuted)
                .frame(width: symbolSide, height: symbolSide)
                .accessibilityHidden(true)
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.leading)
            Facts(detail)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .multilineTextAlignment(.leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var actionLabel: some View {
        Text(verbatim: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.inkText)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
    }
}

/// Asks for notifications in context, naming the charge the first reminder would be about.
struct ReminderAskRow: View {
    let nextCharge: Horizon.Charge?
    private var notifications = NotificationManager.shared
    @State private var isAsking = false

    init(nextCharge: Horizon.Charge?) { self.nextCharge = nextCharge }

    var body: some View {
        let denied = notifications.status == .denied
        let hidden = notifications.isAuthorized && notifications.delivery == .hidden
        let late = notifications.isAuthorized && notifications.delivery == .late
        let needsSettings = denied || hidden || late
        let symbol = (denied || hidden) ? "bell.slash" : (late ? "clock.badge.exclamationmark" : "bell")
        let title: String = {
            if denied { return L10n.string("Reminders are off") }
            if hidden { return L10n.string("Reminders are hidden") }
            if late { return L10n.string("Reminders may arrive late") }
            return L10n.string("Get a heads-up before you're charged")
        }()
        let subtitle: String = {
            if denied { return L10n.string("Turn on notifications for Pausely in Settings so renewals don't surprise you.") }
            if hidden { return L10n.string("Notifications are allowed, but banners, Lock Screen and Notification Center are all off in Settings.") }
            if late { return L10n.string("Pausely is in Scheduled Summary. Switch it to Immediate Delivery in Settings so renewals arrive on time.") }
            return detail
        }()
        AttentionRow(state: nil, symbol: symbol,
                     title: title,
                     detail: subtitle,
                     action: needsSettings ? L10n.string("Open Settings") : L10n.string("Turn on")) {
            if needsSettings {
                notifications.openSystemSettings()
            } else if !isAsking {
                isAsking = true
                Task {
                    await notifications.requestPermission()
                    isAsking = false
                }
            }
        }
        .accessibilityIdentifier("turnOnRemindersButton")
    }

    /// Names the charge the first reminder would be about, so the request is concrete.
    private var detail: String {
        guard let charge = nextCharge else {
            return L10n.string("Pausely reminds you before each renewal so you can keep it or cancel it.")
        }
        let price = MoneyFormat.string(charge.amount, charge.currency, locale: L10n.locale)
        let day = DayText.date(charge.date, locale: L10n.locale)
        return L10n.string("First up: \(charge.name), \(price) on \(day).")
    }
}

// MARK: - The 30-day horizon

/// The coming month as one line: a dot per charge, placed by day and sized by amount. Dragging along
/// it shows what leaves by that day. The rows below say the same thing in words.
struct HorizonSection: View {
    let charges: [Horizon.Charge]
    /// What the total leaves out (subscriptions with no renewal date), or nil.
    let notInTotal: String?
    let currency: String
    let rates: CurrencyRates
    let pendingKeys: Set<String>
    var onSelectCharge: ((UUID) -> Void)? = nil

    @GestureState private var selectedDay: Int?
    @State private var spokenDay: Int?

    private var pickedDay: Int? { selectedDay ?? spokenDay }
    private var throughDay: Int { pickedDay ?? Horizon.days - 1 }
    private var total: Decimal { Horizon.total(of: charges, through: throughDay, in: currency, rates: rates) }
    private var unconvertibleCount: Int {
        Horizon.unconvertibleCount(charges, through: throughDay, to: currency, rates: rates)
    }
    /// Exact charges awaiting a decision above aren't repeated row-for-row below the timeline.
    private var listedCharges: [Horizon.Charge] {
        charges.filter { !pendingKeys.contains(RenewalDecisions.key($0.subscriptionId, $0.date)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SideBySide {
                Text(pickedDay == nil ? L10n.string("Coming up") : L10n.string("By \(dayText(throughDay))"))
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
            } trailing: {
                Text(verbatim: MoneyFormat.total(total, currency, converted: Horizon.isConverted(charges, through: throughDay, to: currency, rates: rates),
                                                 locale: L10n.locale))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.inkText)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if let notInTotal {
                Text(verbatim: notInTotal)
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .accessibilityIdentifier("notInTotal")
            }

            if unconvertibleCount > 0 {
                Text(unconvertibleCount == 1
                     ? L10n.string("1 charge is in a currency without an exchange rate and isn't in this total.")
                     : L10n.string("\(unconvertibleCount) charges are in currencies without an exchange rate and aren't in this total."))
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            if charges.isEmpty {
                Text("Nothing is due in the next month.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .padding(.top, 10)
            } else {
                line.padding(.top, 10)
                HStack {
                    Text("Today")
                    Spacer()
                    Text(verbatim: dayText(Horizon.days - 1))
                }
                .font(.caption)
                .foregroundStyle(Color.inkTextFaint)
                .padding(.bottom, 10)
                .accessibilityHidden(true)

                let awaiting = charges.count - listedCharges.count
                if awaiting > 0 && !listedCharges.isEmpty {
                    Text(awaiting == 1
                         ? L10n.string("Includes 1 awaiting a decision above.")
                         : L10n.string("Includes \(awaiting) awaiting a decision above."))
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 6)
                }

                ForEach(Array(listedCharges.prefix(6).enumerated()), id: \.element.id) { index, charge in
                    if index > 0 { Hairline() }
                    ChargeRow(charge: charge, state: state(for: charge),
                              dimmed: charge.dayOffset > throughDay,
                              onSelect: onSelectCharge)
                }
                if listedCharges.count > 6 {
                    Hairline()
                    Button {
                        Feel.selection()
                        NotificationCenter.default.post(name: .switchToSubscriptionsTab, object: nil)
                    } label: {
                        HStack {
                            Text(L10n.string("And \(listedCharges.count - 6) more in Subscriptions."))
                                .font(.subheadline)
                                .foregroundStyle(Color.inkTextMuted)
                            Spacer()
                            RowChevron()
                        }
                        .tapArea(.leading)
                    }
                    .buttonStyle(.plain)
                } else if listedCharges.isEmpty {
                    Text("Everything due in the next month is waiting for a decision above.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 8)
                }
            }
        }
        .animation(Motion.unlessReduced(Motion.touch), value: pickedDay)
    }

    private func state(for charge: Horizon.Charge) -> MoneyState? {
        if pendingKeys.contains(RenewalDecisions.key(charge.subscriptionId, charge.date)) { return .decide }
        return charge.dayOffset <= 1 ? .due : nil
    }

    private func dayText(_ offset: Int) -> String {
        let date = Calendar.billing.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return DayText.date(date, locale: L10n.locale)
    }

    private var line: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let largest = charges.compactMap { rates.convert($0.amount, from: $0.currency, to: currency) }.max() ?? 1
            // Draw largest dots first so smaller charges on the same day remain visible on top.
            let orderedDots = charges.sorted { lhs, rhs in
                (rates.convert(lhs.amount, from: lhs.currency, to: currency) ?? 0)
                    > (rates.convert(rhs.amount, from: rhs.currency, to: currency) ?? 0)
            }
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.track).frame(height: 1)
                if let pickedDay {
                    Rectangle().fill(Color.inkText).frame(width: x(pickedDay, width), height: 1)
                }
                ForEach(orderedDots) { charge in
                    let amount = rates.convert(charge.amount, from: charge.currency, to: currency) ?? 0
                    let share = largest > 0 ? NSDecimalNumber(decimal: amount / largest).doubleValue : 0
                    let size = 7 + 15 * share.squareRoot()
                    Circle()
                        .fill(state(for: charge)?.color ?? Color.inkText)
                        .opacity(charge.dayOffset > throughDay ? 0.3 : 1)
                        .frame(width: size, height: size)
                        .overlay(Circle().stroke(Color.ink, lineWidth: 1.5))
                        .position(x: x(charge.dayOffset, width), y: geo.size.height / 2)
                }
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($selectedDay) { value, day, _ in
                        guard abs(value.translation.width) >= abs(value.translation.height) else { return }
                        let usable = max(width - 22, 1)
                        let fraction = min(max((value.location.x - 11) / usable, 0), 1)
                        day = Int((fraction * Double(Horizon.days - 1)).rounded())
                    }
            )
            .onChange(of: selectedDay) { _, day in
                if day != nil { Feel.selection() }
            }
        }
        .frame(height: Layout.tapTarget)
        .accessibilityElement()
        .accessibilityLabel(Text("Total by day"))
        .accessibilityValue(Text(verbatim: {
            let formatted = MoneyFormat.string(total, currency, locale: L10n.locale)
            let isConv = Horizon.isConverted(charges, through: throughDay, to: currency, rates: rates)
            let amountText = isConv ? L10n.string("about \(formatted)") : formatted
            return L10n.string("By \(dayText(throughDay))") + ", " + amountText
        }()))
        .accessibilityAdjustableAction { direction in
            let day = Horizon.stepDay(from: throughDay, forward: direction == .increment, charges: charges)
            spokenDay = day == Horizon.days - 1 ? nil : day
        }
    }

    /// Where a day sits, from the leading edge. SwiftUI mirrors positions, leading-aligned widths and
    /// gesture locations in a right-to-left layout itself.
    nonisolated static func x(_ day: Int, _ width: CGFloat) -> CGFloat {
        let inset: CGFloat = 11
        let fraction = CGFloat(day) / CGFloat(Horizon.days - 1)
        return inset + fraction * (width - inset * 2)
    }

    private func x(_ day: Int, _ width: CGFloat) -> CGFloat { Self.x(day, width) }
}

private struct ChargeRow: View {
    let charge: Horizon.Charge
    let state: MoneyState?
    let dimmed: Bool
    var onSelect: ((UUID) -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button {
            Feel.selection()
            if let onSelect {
                onSelect(charge.subscriptionId)
            } else {
                VerdictCenter.shared.showSubscription(charge.subscriptionId)
            }
        } label: {
            HStack(spacing: 12) {
                if typeSize.isAccessibilitySize {
                    words
                    Spacer(minLength: 8)
                } else {
                    ServiceLogoView(name: charge.name, category: charge.category, size: 36)
                    LineOrStack(spacing: 8, lineSpacing: 2, spread: true, besideShare: 0.5) {
                        words
                        price
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 12)
            .opacity(dimmed ? 0.5 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: charge.name)
                .font(.body)
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                if let state { StateMark(state: state) }
                Facts(when)
                    .font(.subheadline)
                    .foregroundStyle(state?.color ?? Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if typeSize.isAccessibilitySize { price }
        }
    }

    private var price: some View {
        Text(verbatim: MoneyFormat.string(charge.amount, charge.currency, locale: L10n.locale))
            .font(.body.monospacedDigit())
            .foregroundStyle(Color.inkText)
    }

    private var when: String {
        let day = L10n.day(charge.date)
        let relative = L10n.whole(L10n.relativeDay(charge.dayOffset, capitalized: true))
        return L10n.breakingAfterDots(charge.isTrialEnd ? L10n.string("Trial ends \(day) · \(relative)") : "\(day) · \(relative)")
    }
}
