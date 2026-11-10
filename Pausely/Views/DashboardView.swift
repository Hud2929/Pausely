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
    @State private var showsYear = false
    @State private var dismissedAlerts: Set<UUID> = []
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 52

    private var hasKept: Bool { !SavingsSummary.current().isEmpty }
    private var charges: [Horizon.Charge] { Horizon.charges(for: store.subscriptions, now: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if store.isLoading && store.subscriptions.isEmpty {
                    HomeLoading().padding(.top, 32)
                } else if store.subscriptions.isEmpty {
                    HomeEmpty(onAdd: { showingAdd = true }).padding(.top, 40)
                } else {
                    attention.padding(.top, 28)
                    // Proof of money kept comes before the list of what is about to leave.
                    if hasKept { keptSection.padding(.top, 24) }
                    HorizonSection(charges: charges, currency: currencyManager.selectedCurrency,
                                   rates: currencyManager.rates,
                                   pendingIds: Set(VerdictCenter.shared.pendingDecisions().map(\.subscriptionId)))
                        .padding(.top, 32)
                    if !hasKept { keptSection.padding(.top, 28) }
                    quietRows.padding(.top, 20)
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.ink.ignoresSafeArea())
        .refreshable { await store.fetchSubscriptions(force: true) }
        .sheet(isPresented: $showingAdd) { SubscriptionBrowserView() }
        .sheet(isPresented: $showingPaywall) { StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count) }
        .sheet(isPresented: $showingReceipt) { SavingsReceiptView() }
        .sheet(isPresented: $showingDates) { RenewalDatesSheet(subscriptions: Horizon.undated(store.subscriptions)) }
        .onAppear {
            Task { await ScreenTimeManager.shared.syncUsageData() }
            ReviewPromptManager.shared.askAfterMoneyKept()
        }
    }

    // MARK: - The number

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    Feel.selection()
                    withAnimation(Motion.unlessReduced(Motion.touch)) { showsYear.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text(showsYear ? L10n.string("Each year") : L10n.string("Each month"))
                        Image(systemName: "arrow.up.arrow.down").font(.caption2.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Switches between a month and a year"))
                .accessibilityIdentifier("spendPeriodToggle")

                Text(verbatim: currencyManager.format(showsYear ? store.totalAnnualSpend : store.totalMonthlySpend))
                    .font(.system(size: numberSize, weight: .bold, design: .serif))
                    .foregroundStyle(Color.inkText)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityIdentifier("spendTotal")

                if !store.subscriptions.isEmpty {
                    Text(L10n.string("\(store.activeSubscriptions.count) subscriptions"))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                }
            }
            Spacer(minLength: 8)
            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(width: Layout.tapTarget, height: Layout.tapTarget)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .contentShape(Circle())
            }
            .accessibilityLabel(Text("Add Subscription"))
            .accessibilityIdentifier("homeAddButton")
        }
    }

    // MARK: - What needs attention

    @ViewBuilder private var attention: some View {
        let pending = VerdictCenter.shared.pendingDecisions()
        let waiting = TallyImporter.waitingLines()
        let undated = Horizon.undated(store.subscriptions)
        let alerts = PriceIncreaseMonitor.shared.alerts.filter { !dismissedAlerts.contains($0.id) }
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
                                ? L10n.string("\(waiting[0].name) isn't watched")
                                : L10n.string("\(waiting.count) of your subscriptions aren't watched"),
                             detail: L10n.string("Free watches \(FreeTier.subscriptionLimit). Pro watches all of them."),
                             action: L10n.string("See Pro")) { showingPaywall = true }
                    .accessibilityIdentifier("waitingRow")
                Hairline()
            }

            ForEach(alerts) { alert in
                AttentionRow(state: .due, symbol: "arrow.up.right",
                             title: L10n.string("\(alert.subscriptionName) went up"),
                             detail: L10n.string("\(alert.formattedIncrease) more each time it charges."),
                             action: L10n.string("OK")) {
                    dismissedAlerts.insert(alert.id)
                    PriceIncreaseMonitor.shared.dismissAlert(id: alert.id)
                }
                Hairline()
            }
        }
    }

    private func whenText(_ item: RenewalDecisions.Pending) -> String {
        let days = Calendar.current.calendarDays(from: Date(), to: item.date)
        let relative = days == 0 ? L10n.string("today") : days == 1 ? L10n.string("tomorrow") : L10n.string("in \(days) days")
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
                        Text("Your Savings Receipt starts with your first cancel")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Chevron()
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            } else {
                PaperSlip(tornTop: true, tornBottom: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ProofLine(label: L10n.string("Kept with Pausely"), value: summary.formatted(summary.savedSoFar),
                                  emphasised: true)
                            .foregroundStyle(Color.paperKept)
                        ProofLine(label: L10n.string("On track over 12 months"), value: summary.formatted(summary.onTrack))
                        if let multiple = summary.returnMultiple, summary.paysForItself {
                            Text(L10n.string("Pausely has paid for itself \(multiple.formatted(.number.precision(.fractionLength(1)).locale(L10n.locale)))× over."))
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

    // MARK: - Pause Plan and paused

    @ViewBuilder private var quietRows: some View {
        VStack(spacing: 0) {
            if pausePlanStore.activePlan != nil {
                Hairline()
                Button { VerdictCenter.shared.openPausePlan() } label: {
                    HStack(spacing: 12) {
                        StateMark(state: .paused)
                        Text("Pause Plan").font(.body).foregroundStyle(Color.inkText)
                        Spacer(minLength: 8)
                        Chevron()
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if !store.pausedSubscriptions.isEmpty {
                Hairline()
                HStack(spacing: 12) {
                    StateMark(state: .paused)
                    Text(L10n.string("\(store.pausedSubscriptions.count) paused"))
                        .font(.body).foregroundStyle(Color.inkText)
                    Spacer(minLength: 8)
                    Text(verbatim: currencyManager.format(store.pausedSubscriptions.monthlyTotal()))
                        .font(.body.monospacedDigit()).foregroundStyle(Color.inkTextMuted)
                }
                .padding(.vertical, 14)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Parts

private struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.inkTextFaint)
            .accessibilityHidden(true)
    }
}

/// One thing that wants a decision or an answer: a mark, a sentence, and the action.
private struct AttentionRow: View {
    var state: MoneyState?
    var symbol: String?
    let title: String
    let detail: String
    let action: String
    let perform: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

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
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.leading)
            Text(verbatim: detail)
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
            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
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
                     action: denied ? L10n.string("Settings") : L10n.string("Turn on")) {
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

    @State private var selectedDay: Int?
    @Environment(\.layoutDirection) private var direction

    private var throughDay: Int { selectedDay ?? Horizon.days - 1 }
    private var total: Decimal { Horizon.total(of: charges, through: throughDay, in: currency, rates: rates) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedDay == nil ? L10n.string("Coming up") : L10n.string("By \(dayText(throughDay))"))
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                Spacer(minLength: 8)
                Text(verbatim: MoneyFormat.string(total, currency, locale: L10n.locale))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.inkText)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)

            if charges.isEmpty {
                Text("Nothing is due in the next month.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .padding(.top, 10)
            } else {
                line.padding(.top, 18)
                HStack {
                    Text("Today")
                    Spacer()
                    Text(verbatim: dayText(Horizon.days - 1))
                }
                .font(.caption)
                .foregroundStyle(Color.inkTextFaint)
                .padding(.top, 6)
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
    }

    private func state(for charge: Horizon.Charge) -> MoneyState? {
        if pendingIds.contains(charge.subscriptionId) && charge.dayOffset <= 7 { return .decide }
        return charge.dayOffset <= 1 ? .due : nil
    }

    private func dayText(_ offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
    }

    private var line: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let largest = charges.compactMap { rates.convert($0.amount, from: $0.currency, to: currency) }.max() ?? 1
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1)
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
                    .onChanged { value in
                        let fraction = min(max(value.location.x / max(width, 1), 0), 1)
                        let day = Int(((direction == .rightToLeft ? 1 - fraction : fraction) * Double(Horizon.days - 1)).rounded())
                        if day != selectedDay {
                            Feel.selection()
                            withAnimation(Motion.unlessReduced(Motion.touch)) { selectedDay = day }
                        }
                    }
                    .onEnded { _ in withAnimation(Motion.unlessReduced(Motion.touch)) { selectedDay = nil } }
            )
        }
        .frame(height: 28)
        .accessibilityHidden(true)
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
                if !typeSize.isAccessibilitySize {
                    ServiceLogoView(name: charge.name, category: charge.category, size: 36)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: charge.name)
                        .font(.body)
                        .foregroundStyle(Color.inkText)
                    HStack(spacing: 6) {
                        if let state { StateMark(state: state) }
                        Text(verbatim: when)
                            .font(.subheadline)
                            .foregroundStyle(state?.color ?? Color.inkTextMuted)
                    }
                    if typeSize.isAccessibilitySize { price }
                }
                Spacer(minLength: 8)
                if !typeSize.isAccessibilitySize { price }
            }
            .padding(.vertical, 12)
            .opacity(dimmed ? 0.35 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var price: some View {
        Text(verbatim: MoneyFormat.string(charge.amount, charge.currency, locale: L10n.locale))
            .font(.body.monospacedDigit())
            .foregroundStyle(Color.inkText)
    }

    private var when: String {
        let day = charge.date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
        let relative = charge.dayOffset == 0 ? L10n.string("Today")
            : charge.dayOffset == 1 ? L10n.string("Tomorrow") : L10n.string("in \(charge.dayOffset) days")
        return charge.isTrialEnd ? L10n.string("Trial ends \(day) · \(relative)") : "\(day) · \(relative)"
    }
}

// MARK: - Empty and loading

private struct HomeEmpty: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing on your list yet.")
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
            Text("Add what you pay for. Pausely asks before each renewal whether it's still worth it.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onAdd) { Text("Add Subscription") }
                .buttonStyle(.ink)
                .padding(.top, 12)
                .accessibilityIdentifier("addSubscriptionButton")
        }
    }
}

private struct HomeLoading: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                if index > 0 { Hairline() }
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.inkRaised).frame(width: 36, height: 36)
                    RoundedRectangle(cornerRadius: 4).fill(Color.inkRaised).frame(width: 140, height: 14)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4).fill(Color.inkRaised).frame(width: 56, height: 14)
                }
                .padding(.vertical, 12)
            }
        }
        .accessibilityLabel(Text("Loading"))
    }
}
