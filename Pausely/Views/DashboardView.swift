import SwiftUI
import UserNotifications

/// Home. Four things, in the order someone needs them: what it all costs, what needs a decision,
/// what leaves in the next 30 days, and what Pausely has kept.
@MainActor
struct DashboardView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var pausePlanStore = PausePlanStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared

    @State private var showingAdd = false
    @State private var showingPaywall = false
    @State private var showingReceipt = false
    @State private var showingDates = false
    @State private var showingInbox = false
    @State private var showsYear = false
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 52
    @Environment(\.dynamicTypeSize) private var typeSize

    /// How many lines the total may take. One; two at the accessibility text sizes, where a total
    /// in the millions, already at half its size, was cut off on one line ("IDR 9,573,4…"). On
    /// two, the currency sits above the figure and all of it shows.
    nonisolated static func totalLines(largeText: Bool) -> Int { largeText ? 2 : 1 }

    private var hasKept: Bool { !SavingsSummary.current().isEmpty }
    private var charges: [Horizon.Charge] { Horizon.charges(for: store.subscriptions, now: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if store.listState == .loading {
                    ListLoading().padding(.top, 32)
                } else if store.listState == .couldNotLoad {
                    ListCouldNotLoad().padding(.top, 40)
                } else if store.subscriptions.isEmpty {
                    HomeEmpty(onAdd: { showingAdd = true },
                              onFindInEmail: FeatureFlags.inboxImportEnabled ? { showingInbox = true } : nil)
                        .padding(.top, 40)
                } else {
                    attention.padding(.top, 28)
                    // Proof of money kept comes before the list of what is about to leave.
                    if hasKept { keptSection.padding(.top, 24) }
                    if Self.showsComingUp(hasCharges: !charges.isEmpty,
                                          hasUndated: !Horizon.undated(store.subscriptions).isEmpty) {
                        HorizonSection(charges: charges, currency: currencyManager.selectedCurrency,
                                       rates: currencyManager.rates,
                                       pendingIds: Set(VerdictCenter.shared.pendingDecisions(rotating: pausePlanStore.activePlan).map(\.subscriptionId)))
                            .padding(.top, 32)
                    }
                    if !hasKept { keptSection.padding(.top, 28) }
                    quietRows.padding(.top, 20)
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .inkScreen()
        .refreshable { await store.fetchSubscriptions(force: true) }
        .sheet(isPresented: $showingAdd) { SubscriptionBrowserView() }
        .sheet(isPresented: $showingPaywall) { StoreKitUpgradeView() }
        .sheet(isPresented: $showingReceipt) { SavingsReceiptView() }
        .sheet(isPresented: $showingDates) { RenewalDatesSheet(subscriptions: Horizon.undated(store.subscriptions)) }
        .sheet(isPresented: $showingInbox) { InboxImportView() }
        .onAppear {
            ReviewPromptManager.shared.askAfterMoneyKept()
        }
    }

    // MARK: - The number

    /// What VoiceOver says for the big figure: the whole sentence, because "$147.92" alone says nothing.
    private var spokenTotal: String {
        let currency = currencyManager.selectedCurrency
        if showsYear {
            return L10n.string("Your subscriptions cost about \(MoneyFormat.total(store.totalAnnualSpend, currency, converted: store.totalIsConverted)) a year.")
        }
        return L10n.string("Your subscriptions cost \(MoneyFormat.total(store.totalMonthlySpend, currency, converted: store.totalIsConverted)) a month.")
    }

    private var header: some View {
        Group {
            if Self.totalHasTheWholeWidth(largeText: typeSize.isAccessibilitySize) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 12) {
                        periodToggle
                        Spacer(minLength: 8)
                        addButton
                    }
                    totalFigure
                    countLine
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        periodToggle
                        totalFigure
                        countLine
                    }
                    Spacer(minLength: 8)
                    addButton
                }
            }
        }
    }

    /// Whether the total sits under the row that holds "+", with the whole width to itself. At
    /// the accessibility text sizes, yes: beside "+" a total in the millions had four fifths of
    /// the width and was cut off ("IDR 9,573,4…").
    nonisolated static func totalHasTheWholeWidth(largeText: Bool) -> Bool { largeText }

    /// Whether Home shows the coming month. Not when no charge is known and a subscription has no
    /// renewal date: "£0.00, nothing is due in the next month" was said of a monthly Netflix with no
    /// date, which charges within the month. The row asking for the date says what to do instead.
    nonisolated static func showsComingUp(hasCharges: Bool, hasUndated: Bool) -> Bool {
        hasCharges || !hasUndated
    }

    private var periodToggle: some View {
        Button {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) { showsYear.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(showsYear ? L10n.string("Each year") : L10n.string("Each month"))
                    // Two words that belong together: at the largest sizes they shrink a
                    // little before they part.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "arrow.up.arrow.down").font(.caption2.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .foregroundStyle(Color.inkTextMuted)
            .tapArea(.leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Switches between a month and a year"))
        .accessibilityIdentifier("spendPeriodToggle")
    }

    @ViewBuilder private var totalFigure: some View {
        // No figure before the list has arrived: "$0.00" was on screen until it did.
        if !store.listState.totalIsKnown {
            RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous)
                .fill(Color.inkRaised)
                .frame(width: 168, height: numberSize * 0.8)
                .padding(.vertical, numberSize * 0.1)
                .accessibilityHidden(true)
        } else {
            Text(verbatim: MoneyFormat.total(showsYear ? store.totalAnnualSpend : store.totalMonthlySpend,
                                             currencyManager.selectedCurrency, converted: store.totalIsConverted))
                .font(.total(numberSize))
                .foregroundStyle(Color.inkText)
                .contentTransition(.numericText())
                .lineLimit(Self.totalLines(largeText: typeSize.isAccessibilitySize))
                .minimumScaleFactor(0.5)
                .accessibilityLabel(Text(verbatim: spokenTotal))
                .accessibilityIdentifier("spendTotal")
        }
    }

    @ViewBuilder private var countLine: some View {
        if !store.subscriptions.isEmpty {
            Text(L10n.string("\(store.activeSubscriptions.count) subscriptions"))
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                // A number stays with its noun.
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var addButton: some View {
        Button { showingAdd = true } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.inkText)
                .frame(width: Layout.tapTarget, height: Layout.tapTarget)
                .overlay(Circle().stroke(Color.outline, lineWidth: 1))
                .contentShape(Circle())
        }
        .accessibilityLabel(Text("Add subscription"))
        .accessibilityIdentifier("homeAddButton")
    }

    // MARK: - What needs attention

    @ViewBuilder private var attention: some View {
        let pending = VerdictCenter.shared.pendingDecisions(rotating: pausePlanStore.activePlan)
        let waiting = TallyImporter.waitingLines()
        let undated = Horizon.undated(store.subscriptions)
        let showReminderAsk = !NotificationManager.shared.isAuthorized && !DemoSavings.isScreenshotRun

        VStack(spacing: 0) {
            if let first = undated.first {
                AttentionRow(state: nil, symbol: "calendar.badge.plus",
                             title: undated.count == 1
                                ? L10n.string("When does \(first.name) renew?")
                                : L10n.string("\(undated.count) subscriptions have no renewal date"),
                             detail: L10n.string("Add the date and Pausely will ask you before it charges."),
                             action: undated.count == 1 ? L10n.string("Add date") : L10n.string("Add dates")) {
                    showingDates = true
                }
                .accessibilityIdentifier("undatedRow")
                Hairline()
            }

            ForEach(pending) { item in
                if let sub = store.subscriptions.first(where: { $0.id == item.subscriptionId }) {
                    AttentionRow(state: .decide,
                                 title: L10n.string("Keep \(sub.name)?"),
                                 detail: whenText(item) + " · " + sub.chargeText,
                                 action: L10n.string("Decide")) {
                        VerdictCenter.shared.open(subscriptionId: sub.id)
                    }
                    .accessibilityIdentifier("decideRow")
                    Hairline()
                }
            }

            if showReminderAsk {
                ReminderAskRow(nextCharge: charges.first)
                Hairline()
            }

            if !waiting.isEmpty, !paymentManager.isUnlocked(.unlimitedSubscriptions) {
                AttentionRow(state: nil, symbol: "eye.slash",
                             title: waiting.count == 1
                                ? L10n.string("\(waiting[0].name) isn't tracked")
                                : L10n.string("\(waiting.count) of your subscriptions aren't tracked"),
                             detail: L10n.string("Free tracks \(FreeTier.subscriptionLimit). Pausely Pro tracks all of them."),
                             action: L10n.string("See Pro")) { showingPaywall = true }
                    .accessibilityIdentifier("waitingRow")
                Hairline()
            }

        }
    }

    private func whenText(_ item: RenewalDecisions.Pending) -> String {
        let days = Calendar.billing.calendarDays(from: Date(), to: item.date)
        let relative = L10n.relativeDay(days)
        return item.isTrialEnd ? L10n.string("Trial ends \(relative)") : L10n.string("Renews \(relative)")
    }

    // MARK: - Kept

    /// The receipt's stub: paper, because this is money proven kept.
    @ViewBuilder private var keptSection: some View {
        let summary = SavingsSummary.current()
        Button {
            Feel.selection()
            showingReceipt = true
        } label: {
            if summary.isEmpty {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Savings Receipt")
                            .font(.headline)
                            .foregroundStyle(Color.inkText)
                        Text("Your Savings Receipt starts with your first cancellation")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    RowChevron()
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            } else {
                PaperSlip(tornTop: true, tornBottom: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ProofLine(label: L10n.string("Kept since you cancelled"), value: summary.total(summary.savedSoFar),
                                  emphasised: true)
                            .foregroundStyle(Color.paperKept)
                        ProofLine(label: L10n.string("On track over 12 months"), value: summary.total(summary.onTrack))
                        if let multiple = summary.returnMultiple, summary.paysForItself {
                            Text(L10n.string("On track for \(multiple.formatted(.number.precision(.fractionLength(1)).locale(L10n.locale)))× what Pausely costs a year."))
                                .font(.footnote)
                                .foregroundStyle(Color.paperMuted)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens your Savings Receipt"))
        .accessibilityIdentifier("savingsReceiptCard")
    }

    // MARK: - Pause Plan

    /// The running plan, said as on Insights: which service is on and until when. It used to be the
    /// two words "Pause Plan" and nothing else.
    @ViewBuilder private var quietRows: some View {
        if pausePlanStore.activePlan != nil {
            VStack(spacing: 0) {
                Hairline()
                PausePlanCard()
            }
        }
    }
}

// MARK: - Parts

/// One thing that wants a decision or an answer: a mark, a sentence, and the action.
private struct AttentionRow: View {
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
private struct ReminderAskRow: View {
    let nextCharge: Horizon.Charge?
    private var notifications = NotificationManager.shared
    @State private var isAsking = false

    init(nextCharge: Horizon.Charge?) { self.nextCharge = nextCharge }

    var body: some View {
        let denied = notifications.status == .denied
        AttentionRow(state: nil, symbol: denied ? "bell.slash" : "bell",
                     title: denied ? L10n.string("Reminders are off") : L10n.string("Get a heads-up before you're charged"),
                     detail: denied
                        ? L10n.string("Turn on notifications for Pausely in Settings so renewals don't surprise you.")
                        : detail,
                     action: denied ? L10n.string("Open Settings") : L10n.string("Turn on")) {
            if denied {
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
        let day = charge.date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
        return L10n.string("First up: \(charge.name), \(price) on \(day).")
    }
}

// MARK: - The 30-day horizon

/// The coming month as one line: a dot per charge, placed by day and sized by amount. Dragging along
/// it shows what leaves by that day. The rows below say the same thing in words.
private struct HorizonSection: View {
    let charges: [Horizon.Charge]
    let currency: String
    let rates: CurrencyRates
    let pendingIds: Set<UUID>

    /// The day under the finger while it is on the line. Gesture state, not view state: it goes back
    /// to nothing when the touch ends and also when the scroll view takes the touch away. Kept as view
    /// state it stayed set after a scroll that began on the line, and the rows below stayed faded.
    @GestureState private var selectedDay: Int?
    /// The day chosen with VoiceOver (swipe up or down on the line). A finger's choice lasts while
    /// it is down; this one stays until it is moved back to the end of the line.
    @State private var spokenDay: Int?
    @Environment(\.layoutDirection) private var direction

    private var pickedDay: Int? { selectedDay ?? spokenDay }
    private var throughDay: Int { pickedDay ?? Horizon.days - 1 }
    private var total: Decimal { Horizon.total(of: charges, through: throughDay, in: currency, rates: rates) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SideBySide {
                Text(pickedDay == nil ? L10n.string("Coming up") : L10n.string("By \(dayText(throughDay))"))
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
            } trailing: {
                Text(verbatim: MoneyFormat.total(total, currency, converted: Horizon.isConverted(charges, through: throughDay, to: currency),
                                                 locale: L10n.locale))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.inkText)
                    .contentTransition(.numericText())
                    // An amount is one thing: it shrinks before it breaks across lines.
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

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

                ForEach(Array(charges.prefix(6).enumerated()), id: \.element.id) { index, charge in
                    if index > 0 { Hairline() }
                    ChargeRow(charge: charge, state: state(for: charge),
                              dimmed: charge.dayOffset > throughDay)
                }
                if charges.count > 6 {
                    Hairline()
                    Text(L10n.string("And \(charges.count - 6) more in Subscriptions."))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .padding(.vertical, 12)
                }
            }
        }
        .animation(Motion.unlessReduced(Motion.touch), value: pickedDay)
    }

    private func state(for charge: Horizon.Charge) -> MoneyState? {
        if pendingIds.contains(charge.subscriptionId) && charge.dayOffset <= 7 { return .decide }
        return charge.dayOffset <= 1 ? .due : nil
    }

    private func dayText(_ offset: Int) -> String {
        let date = Calendar.billing.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
    }

    private var line: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let largest = charges.compactMap { rates.convert($0.amount, from: $0.currency, to: currency) }.max() ?? 1
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.track).frame(height: 1)
                if let selectedDay {
                    Rectangle().fill(Color.inkText).frame(width: x(selectedDay, width), height: 1)
                }
                ForEach(charges) { charge in
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
                DragGesture(minimumDistance: 0)
                    .updating($selectedDay) { value, day, _ in
                        let fraction = min(max(value.location.x / max(width, 1), 0), 1)
                        day = Int(((direction == .rightToLeft ? 1 - fraction : fraction) * Double(Horizon.days - 1)).rounded())
                    }
            )
            .onChange(of: selectedDay) { _, day in
                if day != nil { Feel.selection() }
            }
        }
        // A fingertip tall, so the line can be found and held (it was 28 points).
        .frame(height: Layout.tapTarget)
        // What a drag does, VoiceOver does by swiping up and down: one charge day at a time.
        .accessibilityElement()
        .accessibilityLabel(Text("Total by day"))
        .accessibilityValue(Text(verbatim: L10n.string("By \(dayText(throughDay))") + ", "
                                 + MoneyFormat.total(total, currency, converted: Horizon.isConverted(charges, through: throughDay, to: currency),
                                                     locale: L10n.locale)))
        .accessibilityAdjustableAction { direction in
            let day = Horizon.stepDay(from: throughDay, forward: direction == .increment, charges: charges)
            spokenDay = day == Horizon.days - 1 ? nil : day
        }
    }

    private func x(_ day: Int, _ width: CGFloat) -> CGFloat {
        let inset: CGFloat = 11
        let fraction = CGFloat(day) / CGFloat(Horizon.days - 1)
        let position = inset + fraction * (width - inset * 2)
        return direction == .rightToLeft ? width - position : position
    }
}

private struct ChargeRow: View {
    let charge: Horizon.Charge
    let state: MoneyState?
    let dimmed: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button {
            Feel.selection()
            VerdictCenter.shared.showSubscription(charge.subscriptionId)
        } label: {
            HStack(spacing: 12) {
                if typeSize.isAccessibilitySize {
                    words
                    Spacer(minLength: 8)
                } else {
                    ServiceLogoView(name: charge.name, category: charge.category, size: 36)
                    // As on the Subscriptions list: the price beside the name while it takes no
                    // more than half the row, under it when it is wider, and never broken.
                    LineOrStack(spacing: 8, lineSpacing: 2, spread: true, besideShare: 0.5) {
                        words
                        price
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 12)
            // Past the picked day a row steps back, and can still be read: at this strength its
            // name stays above 4.5 to 1 on ink (at 0.35 it was under 3).
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
        let day = L10n.whole(charge.date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale)))
        let relative = L10n.whole(L10n.relativeDay(charge.dayOffset, capitalized: true))
        return L10n.breakingAfterDots(charge.isTrialEnd ? L10n.string("Trial ends \(day) · \(relative)") : "\(day) · \(relative)")
    }
}

// MARK: - Empty and loading

private struct HomeEmpty: View {
    let onAdd: () -> Void
    /// Nil while finding subscriptions in email is switched off (`FeatureFlags`).
    var onFindInEmail: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing on your list yet.")
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Add what you pay for. Pausely asks before each renewal whether it's still worth it.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                Button(action: onAdd) { Text("Add subscription") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("addSubscriptionButton")
                if let onFindInEmail {
                    Button(action: onFindInEmail) { Text("Find in Email") }
                        .buttonStyle(.ink(.quiet))
                        .accessibilityIdentifier("homeFindInEmailButton")
                }
            }
            .padding(.top, 12)
        }
    }
}

