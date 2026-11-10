import SwiftUI

/// Keep it or cancel it. One renewal, only the facts that help decide, three answers.
/// Opened from a reminder, the dashboard's "Decide" card or the subscription screen.
struct RenewalVerdictView: View {
    let subscriptionId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var screenTime = ScreenTimeManager.shared

    @State private var showCancelFlow = false
    @State private var showPaywall = false
    @State private var showReceipt = false
    @State private var isKeeping = false
    @State private var outcome: Outcome?

    private enum Outcome: Equatable {
        case kept(askAgain: Date?)
        case cancelled
    }

    private var subscription: Subscription? { store.subscriptions.first { $0.id == subscriptionId } }

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            if let sub = subscription {
                if let outcome {
                    outcomeView(outcome, sub)
                        .transition(.opacity)
                } else {
                    verdict(sub)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    closeRow
                    Text("This subscription is gone")
                        .font(.question(.title2))
                        .foregroundStyle(Color.inkText)
                    Text("It may have been removed from Pausely.")
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                    Spacer()
                }
                .padding(.horizontal, Layout.margin)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCancelFlow) {
            if let sub = subscription { CancelSubscriptionFlow(subscription: sub, showsOutcome: false) }
        }
        .sheet(isPresented: $showPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
        .sheet(isPresented: $showReceipt) {
            SavingsReceiptView()
        }
        .onChange(of: subscription?.status) { _, status in
            if status == .cancelled, outcome == nil {
                withAnimation(Motion.unlessReduced(Motion.arrive)) { outcome = .cancelled }
            }
        }
    }

    private var closeRow: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Close")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("verdictCloseButton")
            Spacer()
        }
    }

    // MARK: - The slip

    private func verdict(_ sub: Subscription) -> some View {
        let charge = RenewalDecisions.upcomingCharge(for: sub, now: Date())
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    closeRow
                    PaperSlip(tornTop: true, tornBottom: true) {
                        VStack(alignment: .leading, spacing: 14) {
                            header(sub, charge: charge)
                            Perforation()
                            facts(sub, charge: charge)
                        }
                    }
                    .padding(.top, 4)

                    if !sub.isPausely, let cheaper = cheaperOption(sub) {
                        cheaperLine(cheaper).padding(.top, 16)
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.bottom, 16)
            }
            decisionButtons(sub, hasCharge: charge != nil)
                .padding(.horizontal, Layout.margin)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.ink)
        }
    }

    private func header(_ sub: Subscription, charge: (date: Date, isTrialEnd: Bool)?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ServiceLogoView(name: sub.name, category: sub.category, size: 36)
                if let charge {
                    Text(whenText(charge))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(daysUntil(charge.date) <= 1 ? Color.paperDue : Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Keep \(sub.name)?")
                .font(.question(.largeTitle, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(MoneyFormat.string(sub.amount, sub.currency))
                    .font(.question(.title, weight: .semibold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(sub.billingFrequency.shortDisplay)
                    .font(.subheadline)
                    .foregroundStyle(Color.paperMuted)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func whenText(_ charge: (date: Date, isTrialEnd: Bool)) -> String {
        let day = charge.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let days = daysUntil(charge.date)
        let relative = days == 0 ? L10n.string("today") : days == 1 ? L10n.string("tomorrow") : L10n.string("in \(days) days")
        return charge.isTrialEnd
            ? L10n.string("Free trial ends \(day) · \(relative)")
            : L10n.string("Renews \(day) · \(relative)")
    }

    private func daysUntil(_ date: Date) -> Int {
        Calendar.current.calendarDays(from: Date(), to: date)
    }

    // MARK: - Facts

    /// What is true about this subscription, printed like lines on a receipt. No icons, no colour
    /// except where money went up or was kept.
    private func facts(_ sub: Subscription, charge: (date: Date, isTrialEnd: Bool)?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            factLine(yearlyText(sub))

            if let change = VerdictFacts.priceChange(for: sub.id, currentAmount: sub.amount, events: eventLog.events) {
                let up = sub.amount > change.from
                factLine(up ? L10n.string("Up from \(MoneyFormat.string(change.from, sub.currency)) since \(change.since.formatted(.dateTime.month(.abbreviated).day()))")
                            : L10n.string("Down from \(MoneyFormat.string(change.from, sub.currency)) since \(change.since.formatted(.dateTime.month(.abbreviated).day()))"),
                         color: up ? .paperDue : .paperKept)
            }

            if let usage = usageText(sub) { factLine(usage) }

            if let charge {
                factLine(charge.isTrialEnd
                    ? L10n.string("Cancel before \(charge.date.formatted(.dateTime.month(.abbreviated).day())) and you won't be charged.")
                    : L10n.string("Cancel now and you usually keep it until \(charge.date.formatted(.dateTime.month(.abbreviated).day()))."))
            }

            if let kept = VerdictFacts.lastKept(for: sub.id, events: eventLog.events) {
                factLine(L10n.string("You kept it on \(kept.formatted(.dateTime.month(.abbreviated).day()))."))
            }

            if sub.isPausely {
                Perforation().padding(.vertical, 2)
                PauselyPromiseCard()
            }
        }
    }

    private func factLine(_ text: String, color: Color = .paperInk) -> some View {
        Text(text)
            .font(.proof(.footnote))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A cheaper option sits quietly below the slip: it is a suggestion, not one of the facts.
    private func cheaperLine(_ cheaper: (name: String, monthly: Decimal)) -> some View {
        Group {
            if paymentManager.isUnlocked(.cheaperAlternatives) {
                Text(cheaper.monthly == 0
                     ? L10n.string("Free alternative: \(cheaper.name)")
                     : L10n.string("Cheaper: \(cheaper.name) at \(currencyManager.format(cheaper.monthly)) a month"))
                    .foregroundStyle(Color.inkTextMuted)
            } else {
                Button { showPaywall = true } label: {
                    Text(L10n.string("Pro shows a cheaper option for this")).underline()
                        .foregroundStyle(Color.inkTextMuted)
                        .frame(minHeight: Layout.tapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func yearlyText(_ sub: Subscription) -> String {
        let yearly = MoneyFormat.string(sub.annualCost, sub.currency)
        guard sub.currency != currencyManager.selectedCurrency else {
            return L10n.string("That's \(yearly) a year")
        }
        let converted = currencyManager.format(currencyManager.convertToSelected(sub.annualCost, from: sub.currency))
        return L10n.string("That's \(yearly) a year (about \(converted))")
    }

    private func usageText(_ sub: Subscription) -> String? {
        let minutes = screenTime.getCurrentMonthUsage(for: sub.name)
        guard minutes > 0 else { return nil }
        let duration = Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        if let perHour = screenTime.calculateCostPerHour(monthlyCost: sub.monthlyCost, subscriptionName: sub.name) {
            return L10n.string("Used \(duration) this month · \(MoneyFormat.string(perHour, sub.currency)) an hour")
        }
        return L10n.string("Used \(duration) this month")
    }

    private func cheaperOption(_ sub: Subscription) -> (name: String, monthly: Decimal)? {
        let current = currencyManager.convertToSelected(sub.monthlyCost, from: sub.currency)
        return SubscriptionActionManager.shared.findAlternatives(for: sub)
            .map { (name: $0.name, monthly: currencyManager.convertToSelected(Decimal($0.monthlyPrice), from: "USD")) }
            .filter { $0.monthly < current && $0.name.caseInsensitiveCompare(sub.name) != .orderedSame }
            .min { $0.monthly < $1.monthly }
    }

    // MARK: - The two answers

    private func decisionButtons(_ sub: Subscription, hasCharge: Bool) -> some View {
        VStack(spacing: 10) {
            Button {
                Task { await keep(sub) }
            } label: {
                Text(isKeeping ? L10n.string("Keeping…") : L10n.string("Keep it"))
            }
            .buttonStyle(.ink(.keep))
            .disabled(isKeeping || !hasCharge)
            .accessibilityIdentifier("verdictKeepButton")

            Button {
                if sub.isPausely, let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    openURL(url)
                } else {
                    showCancelFlow = true
                }
            } label: {
                Text("Cancel it")
            }
            .buttonStyle(.ink(.quiet))
            .accessibilityIdentifier("verdictCancelButton")

            Button { dismiss() } label: {
                Text("Decide later")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(maxWidth: .infinity, minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func keep(_ sub: Subscription) async {
        isKeeping = true
        defer { isKeeping = false }
        let charge = RenewalDecisions.upcomingCharge(for: sub, now: Date())
        await VerdictCenter.shared.keep(subscriptionId: sub.id)
        Feel.keep()
        withAnimation(Motion.unlessReduced(Motion.arrive)) {
            outcome = .kept(askAgain: charge.flatMap { VerdictFacts.renewal(after: $0.date, for: sub) })
        }
    }

    // MARK: - Outcome

    // MARK: - After the answer

    private func outcomeView(_ outcome: Outcome, _ sub: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)
            switch outcome {
            case .kept(let askAgain):
                OutcomeSlip(name: sub.name, category: sub.category, stamp: L10n.string("Kept"), torn: false) {
                    Text(askAgain.map { L10n.string("No more reminders about this charge. We'll ask again before \($0.formatted(.dateTime.month(.abbreviated).day())).") }
                         ?? L10n.string("No more reminders about this charge."))
                        .font(.proof(.footnote))
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .cancelled:
                CancelledSlip(subscription: sub)
            }
            Spacer(minLength: 24)

            VStack(spacing: 10) {
                if outcome == .cancelled {
                    Button { showReceipt = true } label: { Text("See your Savings Receipt") }
                        .buttonStyle(.ink)
                    Button { dismiss() } label: { Text("Done") }
                        .buttonStyle(.ink(.quiet))
                } else {
                    Button { dismiss() } label: { Text("Done") }
                        .buttonStyle(.ink)
                }
            }
        }
        .padding(.horizontal, Layout.margin)
        .padding(.bottom, 12)
    }
}

/// The slip after a decision: stamped when kept, torn along the perforation when cancelled.
struct OutcomeSlip<Detail: View>: View {
    let name: String
    let category: String?
    let stamp: String
    /// Cancelled: the lower half of the slip tears off and falls away.
    let torn: Bool
    @ViewBuilder var detail: Detail

    @State private var landed = false

    var body: some View {
        ZStack(alignment: .top) {
            if torn {
                // The half that tears off. It starts where the slip continues and drops away.
                PaperSlip(tornTop: true, tornBottom: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2).fill(Color.paperShade).frame(height: 10)
                        }
                    }
                }
                .padding(.top, 150)
                .offset(y: landed ? 420 : 0)
                .rotationEffect(.degrees(landed ? 9 : 0), anchor: .topLeading)
                .opacity(landed ? 0 : 1)
                .accessibilityHidden(true)
            }

            PaperSlip(tornTop: true, tornBottom: true) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ServiceLogoView(name: name, category: category, size: 36)
                        Text(verbatim: name).font(.question(.title2))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(verbatim: stamp)
                        .font(.proof(.title3, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(torn ? Color.paperInk : Color.paperKept)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(torn ? Color.paperInk : Color.paperKept, lineWidth: 2))
                        .rotationEffect(.degrees(-4))
                        .scaleEffect(landed ? 1 : 1.5)
                        .opacity(landed ? 1 : 0)
                    Perforation()
                    detail
                }
            }
        }
        .accessibilityElement(children: .combine)
        .task {
            guard !landed else { return }
            if UIAccessibility.isReduceMotionEnabled {
                landed = true
                return
            }
            if torn { Feel.tearStart() }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(torn ? Motion.leave : Motion.arrive) { landed = true }
            if torn { Feel.tearEnd() }
        }
    }
}


/// The torn slip for a cancelled subscription, with what the cancellation keeps over 12 months.
struct CancelledSlip: View {
    let subscription: Subscription

    var body: some View {
        let line = SavingsSummary.current().lines.last { $0.subscriptionId == subscription.id }
        OutcomeSlip(name: subscription.name, category: subscription.category, stamp: L10n.string("Cancelled"), torn: true) {
            VStack(alignment: .leading, spacing: 10) {
                if let line {
                    ProofLine(label: L10n.string("On track over 12 months"),
                              value: MoneyFormat.string(line.onTrack, line.currency), emphasised: true)
                        .foregroundStyle(Color.paperKept)
                }
                Text(line.map { L10n.string("That's \(MoneyFormat.string($0.onTrack, $0.currency)) you won't pay over the next 12 months. It's on your Savings Receipt.") }
                     ?? L10n.string("It's on your Savings Receipt."))
                    .font(.proof(.footnote))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}


struct PauselyPromiseCard: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared

    /// Printed on Pausely's own slip: what it has kept against what it costs.
    var body: some View {
        let summary = SavingsSummary.current()
        VStack(alignment: .leading, spacing: 6) {
            Text("The Pausely Promise")
                .font(.footnote.weight(.semibold))
            Text(message(summary))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func message(_ summary: SavingsSummary) -> String {
        guard let cost = summary.pauselyYearlyCost.map(summary.formatted) else {
            // Free customers: nothing to weigh yet, but the promise holds if they ever pay.
            return summary.isEmpty
                ? L10n.string("If you ever pay for Pausely and it doesn't save you more than it costs, it will tell you to cancel it.")
                : L10n.string("Pausely is free for you and on track to save you \(summary.formatted(summary.onTrack)) this year. If you ever pay for it, it has to save you more than it costs.")
        }
        if summary.isEmpty {
            return L10n.string("Pausely hasn't saved you anything yet. If it doesn't save you more than its \(cost), we'd rather you cancel it.")
        }
        if summary.paysForItself, let multiple = summary.returnMultiple {
            let times = multiple.formatted(.number.precision(.fractionLength(1)))
            return L10n.string("Pausely is on track to save you \(summary.formatted(summary.onTrack)) this year, \(times)× what it costs. Keeping it pays.")
        }
        return L10n.string("So far Pausely is on track to save you \(summary.formatted(summary.onTrack)), less than its \(cost). We'd rather you cancel than pay for nothing.")
    }
}
