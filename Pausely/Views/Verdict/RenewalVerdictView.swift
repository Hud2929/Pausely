import SwiftUI

/// Keep it or cancel it. One renewal, only the facts that help decide, three answers.
/// Opened from a reminder, the dashboard's "Decide" card or the subscription screen.
struct RenewalVerdictView: View {
    let subscriptionId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var screenTime = UsageLog.shared
    @ObservedObject private var difficulty = CancelDifficultyService.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var showCancelFlow = false
    @State private var showRetention = false
    @State private var showReceipt = false
    @State private var isKeeping = false
    @State private var enteringUsage = false
    @State private var addingDate = false
    @State private var outcome: Outcome?

    private enum Outcome: Equatable {
        case kept(askAgain: Date?)
        case cancelled
    }

    private var subscription: Subscription? { store.subscriptions.first { $0.id == subscriptionId } }

    var body: some View {
        ZStack {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inkScreen()
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCancelFlow) {
            if let sub = subscription { CancelSubscriptionFlow(subscription: sub, showsOutcome: false) }
        }
        .sheet(isPresented: $showRetention) {
            if let sub = subscription { PauselyRetentionSheet(isTrial: sub.status == .trial) }
        }
        .sheet(isPresented: $showReceipt) {
            SavingsReceiptView()
        }
        .sheet(isPresented: $enteringUsage) {
            if let sub = subscription {
                UsageInputSheet(subscriptionName: sub.name, currentMinutes: screenTime.getCurrentMonthUsage(for: sub)) { minutes in
                    screenTime.setMonthlyUsage(minutes: minutes, for: sub)
                }
            }
        }
        .sheet(isPresented: $addingDate) {
            if let sub = subscription { RenewalDatesSheet(subscriptions: [sub]) }
        }
        .onChange(of: subscription?.status) { _, status in
            if status == .cancelled, outcome == nil {
                withAnimation(Motion.unlessReduced(Motion.arrive)) { outcome = .cancelled }
            }
        }
        .onAppear {
            // An old reminder tapped after the subscription was cancelled: there is no question left
            // to ask, so it opens on what the cancellation keeps.
            if let sub = subscription, outcome == nil, VerdictFacts.noCharge(for: sub, now: Date()) == .notRenewing {
                outcome = .cancelled
            }
        }
        .task { await difficulty.loadIfNeeded() }
    }

    private var closeRow: some View {
        HStack {
            LeaveButton("Close") { dismiss() }
            .accessibilityIdentifier("verdictCloseButton")
            Spacer()
        }
    }

    // MARK: - The slip

    private func verdict(_ sub: Subscription) -> some View {
        let charge = RenewalDecisions.upcomingCharge(for: sub, now: Date())
        return ActionScreen {
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

                // The one figure Pausely can't know. Entered here, it turns the price into a cost
                // per hour on the slip above.
                Button { enteringUsage = true } label: {
                    Text(screenTime.getUsage(for: sub) == nil
                         ? L10n.string("How much did you use it this month?")
                         : L10n.string("Change this month's hours"))
                        .underline()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(minHeight: Layout.tapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .accessibilityIdentifier("verdictUsageButton")
            }
            .padding(.horizontal, Layout.margin)
            .padding(.bottom, 16)
        } actions: {
            decisionButtons(sub, hasCharge: charge != nil)
                .padding(.horizontal, Layout.margin)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
    }

    private func header(_ sub: Subscription, charge: (date: Date, isTrialEnd: Bool)?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MarkedWords(alignment: .center) {
                ServiceLogoView(name: sub.name, category: sub.category, size: 36)
            } words: {
                if let charge {
                    Facts(whenText(charge))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(daysUntil(charge.date) <= 1 ? Color.paperDue : Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No renewal date")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Drawn smaller before a name is broken: at the largest size Arabic split "Paramoun" from "t+؟"
            // and English hyphenated "Para-mount+?" (the reach rating of 2026-11-23).
            Text("Keep \(sub.name)?")
                .wholeWords(L10n.string("Keep \(sub.name)?"), font: .question(.largeTitle, weight: .bold),
                            measuredIn: .largeTitle, weight: .bold, serif: true)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            PricePerPeriod(amount: MoneyFormat.string(sub.amount, sub.currency), frequency: sub.billingFrequency,
                           amountFont: .question(.title, weight: .semibold), periodFont: .subheadline, periodColor: .paperMuted)
        }
    }

    private func whenText(_ charge: (date: Date, isTrialEnd: Bool)) -> String {
        let day = L10n.day(charge.date, weekday: true)
        let days = daysUntil(charge.date)
        let relative = L10n.whole(L10n.relativeDay(days))
        return L10n.breakingAfterDots(charge.isTrialEnd
            ? L10n.string("Free trial ends \(day) · \(relative)")
            : L10n.string("Renews \(day) · \(relative)"))
    }

    private func daysUntil(_ date: Date) -> Int {
        Calendar.billing.calendarDays(from: Date(), to: date)
    }

    // MARK: - Facts

    /// What is true about this subscription, printed like lines on a receipt. No icons, no colour
    /// except where money went up or was kept.
    private func facts(_ sub: Subscription, charge: (date: Date, isTrialEnd: Bool)?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let method = sub.paymentMethod, !method.isEmpty {
                factLine(L10n.string("Billed to \(method)"))
            }
            if let notes = sub.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                factLine(notes, color: .paperMuted)
            }
            if let yearly = yearlyText(sub) { factLine(yearly) }

            if let change = PriceHistory.latestChange(for: sub, events: eventLog.events) {
                let up = change.isIncrease
                factLine(up ? L10n.string("Up from \(MoneyFormat.string(change.from, sub.currency)) since \(DayText.date(change.since, locale: L10n.locale))")
                            : L10n.string("Down from \(MoneyFormat.string(change.from, sub.currency)) since \(DayText.date(change.since, locale: L10n.locale))"),
                         // Mint is for money kept by cancelling. A price that went down is said in ink.
                         color: up ? .paperDue : .paperInk)
            }

            if let renewed = VerdictFacts.renewedSoFar(for: sub, events: eventLog.events) {
                let since = renewed.since.formatted(.dateTime.month(.abbreviated).year().locale(L10n.locale))
                factLine(L10n.string("Renewals since \(since): \(MoneyFormat.string(renewed.total, sub.currency, locale: L10n.locale))"))
            }

            if let usage = usageText(sub) { factLine(usage) }

            if let charge {
                // The same promise for a renewal as for a trial's end, and one Pausely can make of any
                // service: cancelled before the day, the charge doesn't happen.
                factLine(L10n.string("Cancel before \(DayText.date(charge.date, locale: L10n.locale)) and you won't be charged."))
            } else {
                factLine(L10n.string("Add the date and Pausely will ask you before it charges."))
            }

            if let kept = VerdictFacts.lastKept(for: sub.id, events: eventLog.events) {
                factLine(L10n.string("You kept it on \(DayText.date(kept, locale: L10n.locale))."))
            }

            if let score = difficulty.score(for: sub.name),
               let line = CancelDifficultyService.summaryLine(for: score) {
                factLine(line, color: score.avgDifficulty >= 3.5 ? .paperDue : .paperMuted)
            }

            if sub.isPausely {
                Perforation().padding(.vertical, 2)
                PauselyPromiseCard(isTrial: sub.status == .trial)
            }
        }
    }

    private func factLine(_ text: String, color: Color = .paperInk) -> some View {
        Facts(text)
            .font(.proof(.footnote))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func yearlyText(_ sub: Subscription) -> String? {
        switch VerdictFacts.yearLine(for: sub, displayCurrency: currencyManager.selectedCurrency, rates: currencyManager.rates) {
        case nil:
            return nil
        case .yearly(let yearly):
            return L10n.string("That's \(MoneyFormat.string(yearly, sub.currency)) a year")
        case .yearlyAndConverted(let yearly, let inDisplay):
            return L10n.string("That's \(MoneyFormat.string(yearly, sub.currency)) a year (about \(currencyManager.format(inDisplay)))")
        case .convertedOnly(let inDisplay):
            return L10n.string("About \(currencyManager.format(inDisplay)) in your currency")
        }
    }

    private func usageText(_ sub: Subscription) -> String? {
        guard let usage = screenTime.getUsage(for: sub) else { return nil }
        let minutes = usage.minutesUsed
        guard minutes > 0 else { return L10n.string("Not used this month") }
        let duration = Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(L10n.locale))
        let used = L10n.string("Used \(duration) this month")
        guard let perHour = screenTime.calculateCostPerHour(for: sub) else { return used }
        return Self.usageLine(used: used, hourly: L10n.string("\(MoneyFormat.string(perHour, sub.currency)) an hour"),
                              largeText: typeSize.isAccessibilitySize)
    }

    /// The hours and what an hour of them cost, as one line of the slip. Beside the hours, the
    /// price of an hour is one piece: the line ended "· $6.85" with "an hour" under it. At the
    /// accessibility sizes each fact has a line of its own and wraps where it must.
    nonisolated static func usageLine(used: String, hourly: String, largeText: Bool) -> String {
        used + " · " + (largeText ? hourly : L10n.whole(hourly))
    }

    // MARK: - The two answers

    private func decisionButtons(_ sub: Subscription, hasCharge: Bool) -> some View {
        VStack(spacing: 10) {
            if hasCharge {
                Button {
                    Task { await keep(sub) }
                } label: {
                    Text(isKeeping ? L10n.string("Keeping…") : L10n.string("Keep it"))
                }
                .buttonStyle(.ink(.keep))
                .disabled(isKeeping)
                .accessibilityIdentifier("verdictKeepButton")
            } else {
                // Keeping is about one charge. With no date there is none to keep, so the main button
                // is the way to give Pausely the date (it was "Keep it", greyed out, with no reason).
                Button { addingDate = true } label: { Text("Add its renewal date") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("verdictAddDateButton")
            }

            Button {
                if sub.isPausely {
                    showRetention = true
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
        OutcomeScreen {
            switch outcome {
            case .kept(let askAgain):
                OutcomeSlip(name: sub.name, category: sub.category, stamp: L10n.string("Kept"), torn: false) {
                    Text(askAgain.map { L10n.string("No more reminders about this charge. We'll ask again before \(DayText.date($0, locale: L10n.locale)).") }
                         ?? L10n.string("No more reminders about this charge."))
                        .font(.proof(.footnote))
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .cancelled:
                VStack(alignment: .leading, spacing: 20) {
                    CancelledSlip(subscription: sub)
                    if !authManager.isGuest {
                        CancelDifficultyPrompt(serviceName: sub.name)
                    }
                }
            }
        } actions: {
            VStack(spacing: 10) {
                if outcome == .cancelled {
                    Button { showReceipt = true } label: { Text("See your Savings Receipt") }
                        .buttonStyle(.ink)
                    ShareCancelledButton(subscriptionId: sub.id, identifier: "verdictShareCancelledButton")
                    Button { dismiss() } label: { Text("Done") }
                        .buttonStyle(.ink(.quiet))
                } else {
                    Button { dismiss() } label: { Text("Done") }
                        .buttonStyle(.ink)
                }
            }
        }
    }
}

/// A decided slip in the middle of the screen, its buttons at the foot. When slip and buttons are
/// taller than the screen (the largest text sizes) they scroll: laid out in a fixed column, the
/// cancelled slip's stamp sat under the clock and its first button over the slip's last line.
struct OutcomeScreen<Slip: View, Actions: View>: View {
    @ViewBuilder var slip: Slip
    @ViewBuilder var actions: Actions

    var body: some View {
        // On iPad the buttons sit under the slip, the two of them in the middle of the screen: at
        // its bottom edge they were half a screen away from what they are about.
        let onPad = UIDevice.current.userInterfaceIdiom == .pad
        // One scroll view at least as tall as the screen: the slip sits in the middle when there is
        // room and the page scrolls when there is not, and it is the same slip either way. (Two
        // copies, one of them chosen by `ViewThatFits`, made Apple's audit report text that could
        // not grow.)
        return GeometryReader { screen in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    slip
                    if onPad { Color.clear.frame(height: 24) } else { Spacer(minLength: 24) }
                    actions
                    if onPad { Spacer(minLength: 24) }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.bottom, 12)
                .frame(minHeight: screen.size.height)
            }
            .readableScroll()
            .scrollBounceBehavior(.basedOnSize)
        }
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
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ServiceLogoView(name: name, category: category, size: 36)
                    Text(verbatim: name).font(.question(.title2))
                        .fixedSize(horizontal: false, vertical: true)
                }
                // One word, on one line, whole: a stamp that ends in "…" at the largest text
                // size ("CANCELL…") says nothing, so it shrinks to the slip's width instead.
                Text(verbatim: stamp)
                    .font(.proof(.title3, weight: .bold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(torn ? Color.paperInk : Color.paperKept)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous).stroke(torn ? Color.paperInk : Color.paperKept, lineWidth: 2))
                    .rotationEffect(.degrees(-4))
                    .scaleEffect(landed ? 1 : 1.5)
                    .opacity(landed ? 1 : 0)
                Perforation()
                detail
            }
        }
        // The half that tears off hangs from the slip's own bottom edge, however tall the slip is,
        // and drops away from there. (It was placed 150 points down from the top, which at a large
        // text size is somewhere behind the middle of the slip.)
        .background(alignment: .bottom) {
            if torn {
                PaperSlip(tornTop: true, tornBottom: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous).fill(Color.paperShade).frame(height: 10)
                        }
                    }
                }
                .offset(y: landed ? 420 : 44)
                .rotationEffect(.degrees(landed ? 9 : 0), anchor: .topLeading)
                .opacity(landed ? 0 : 1)
                .accessibilityHidden(true)
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
        // A line with no charges to count (no renewal day was known) says so: "$0.00 you won't pay" was
        // celebrated for a $14.95 subscription (the rating of 2026-11-23).
        let line = SavingsSummary.current().lines.last { $0.subscriptionId == subscription.id && !$0.avoidedCharges.isEmpty }
        OutcomeSlip(name: subscription.name, category: subscription.category, stamp: L10n.string("Cancelled"), torn: true) {
            VStack(alignment: .leading, spacing: 10) {
                if let line {
                    ProofLine(label: L10n.string("On track over 12 months"),
                              value: MoneyFormat.string(line.onTrack, line.currency), emphasised: true)
                        .foregroundStyle(Color.paperKept)
                }
                Text(line.map { L10n.string("That's \(MoneyFormat.string($0.onTrack, $0.currency)) you won't pay over the next 12 months. It's on your Savings Receipt.") }
                     ?? L10n.string("Pausely counts what you avoid from its renewal day, which it didn't have, so nothing is counted for it."))
                    .font(.proof(.footnote))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}


struct PauselyPromiseCard: View {
    var isTrial: Bool = false
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    /// Printed on Pausely's own slip: what it has kept (and during a free trial, what it is actively
    /// watching before renewals arrive) against what it costs.
    var body: some View {
        let summary = SavingsSummary.current()
        let protection = isTrial && summary.isEmpty
            ? ProtectionSummary.current(subscriptions: store.subscriptions,
                                        displayCurrency: currencyManager.selectedCurrency,
                                        rates: currencyManager.rates)
            : nil
        VStack(alignment: .leading, spacing: 6) {
            Text("The Pausely Promise")
                .font(.footnote.weight(.semibold))
            if let protection, let guardLine = activeGuardLine(protection) {
                Text(verbatim: guardLine)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: message(summary))
                .font(.footnote)
                .foregroundStyle(isTrial && summary.isEmpty ? Color.paperMuted : Color.paperInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func activeGuardLine(_ protection: ProtectionSummary) -> String? {
        guard protection.watchedCount > 0 else { return nil }
        var sentences: [String] = []
        if let yearly = protection.yearlySpend, yearly > 0 {
            let formatted = MoneyFormat.total(yearly, protection.displayCurrency,
                                              converted: protection.isConverted, locale: L10n.locale, wholeUnits: true)
            sentences.append(protection.watchedCount == 1
                             ? L10n.string("Watching 1 subscription (about \(formatted) a year).")
                             : L10n.string("Watching \(protection.watchedCount) subscriptions (about \(formatted) a year)."))
        } else {
            sentences.append(protection.watchedCount == 1
                             ? L10n.string("Watching 1 subscription.")
                             : L10n.string("Watching \(protection.watchedCount) subscriptions."))
        }
        if protection.overFreeLimitCount > 0 {
            sentences.append(protection.overFreeLimitCount == 1
                             ? L10n.string("1 of them wouldn't fit on the free plan.")
                             : L10n.string("\(protection.overFreeLimitCount) of them wouldn't fit on the free plan."))
        }
        if let next = protection.nextCharge {
            sentences.append(L10n.string("Next reminder: \(next.name) on \(DayText.date(next.date, locale: L10n.locale))."))
        }
        if let pause = PausePlanCard.yearlySavingsInfo(in: store.subscriptions, currency: currencyManager) {
            let formatted = MoneyFormat.total(pause.amount, pause.currency,
                                              converted: pause.isConverted, locale: L10n.locale, wholeUnits: true)
            sentences.append(L10n.string("Pause Plan can save about \(formatted) a year."))
        }
        return L10n.sentences(sentences)
    }

    private func message(_ summary: SavingsSummary) -> String {
        guard let cost = summary.pauselyCostText else {
            // Free customers: nothing to weigh yet, but the promise holds if they ever pay.
            return summary.isEmpty
                ? L10n.string("If you ever pay for Pausely and it doesn't save you more than it costs, it will tell you to cancel it.")
                : L10n.string("Pausely is free for you, and your cancellations are on track to keep you \(summary.total(summary.onTrack)) over 12 months. If you ever pay for it, it has to save you more than it costs.")
        }
        if summary.isEmpty {
            return isTrial
                ? L10n.string("No renewals have come due yet. Over the year, if Pausely doesn't save you more than its \(cost), it will tell you to cancel it.")
                : L10n.string("Nothing is on your Savings Receipt yet. If Pausely doesn't save you more than its \(cost), we'd rather you cancel it.")
        }
        if summary.paysForItself, let multiple = summary.returnMultiple {
            let times = multiple.formatted(.number.precision(.fractionLength(1)).locale(L10n.locale))
            return L10n.string("Your cancellations are on track to keep you \(summary.total(summary.onTrack)) over 12 months, \(times)× what Pausely costs. Keeping it pays.")
        }
        return L10n.string("So far your cancellations are on track to keep you \(summary.total(summary.onTrack)) over 12 months, less than Pausely's \(cost). We'd rather you cancel than pay for nothing.")
    }
}
