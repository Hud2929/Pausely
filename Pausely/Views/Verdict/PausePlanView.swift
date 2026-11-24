import SwiftUI

/// Pause Plan: pick the streaming services to rotate, see what it saves, then follow a short
/// to-do list (cancel this one, start that one). Pausely can't cancel for you; it tells you when,
/// and the Savings Receipt counts what rotating saved.
struct PausePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var planStore = PausePlanStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared

    @State private var selected: Set<UUID> = []
    @State private var firstId: UUID?
    @State private var didSetDefaults = false
    @State private var showPaywall = false
    @State private var cancelTarget: Subscription?
    @State private var confirmEnd = false
    @State private var isWorking = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var eligible: [Subscription] {
        store.subscriptions.filter(PausePlanSchedule.isEligible).sorted { $0.name < $1.name }
    }
    private var byId: [UUID: Subscription] {
        Dictionary(store.subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let plan = planStore.activePlan {
                        activeView(plan)
                    } else {
                        setupView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .readableScroll()
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("Pause Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.inkText)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) {
            StoreKitUpgradeView(trigger: .pausePlan)
        }
        .sheet(item: $cancelTarget) { sub in
            CancelSubscriptionFlow(subscription: sub)
        }
        .onAppear(perform: setDefaults)
    }

    /// In the display currency ("≈" when converted); in its own when there is no rate for it.
    private func money(_ amount: Decimal, from currency: String) -> String {
        guard let converted = currencyManager.convertToSelected(amount, from: currency) else {
            return MoneyFormat.string(amount, currency)
        }
        return MoneyFormat.total(converted, currencyManager.selectedCurrency,
                                 converted: MoneyFormat.normalizedCode(currency) != MoneyFormat.normalizedCode(currencyManager.selectedCurrency))
    }

    private func short(_ date: Date) -> String {
        DayText.date(date, locale: L10n.locale)
    }

    // MARK: - Setup

    private func setDefaults() {
        guard !didSetDefaults else { return }
        didSetDefaults = true
        let active = eligible.filter { $0.status != .cancelled }
        selected = Set((active.count >= 2 ? active : eligible).map(\.id))
        firstId = PausePlanSchedule.suggestedOrder(eligible.filter { selected.contains($0.id) }, now: Date()).first
    }

    private var chosen: [Subscription] { eligible.filter { selected.contains($0.id) } }

    @ViewBuilder
    private var setupView: some View {
        intro

        if eligible.count < 2 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add two or more streaming services")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Netflix, Max, Disney+, Hulu, Prime Video and the like. Pause Plan rotates monthly video services; music and storage stay on.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                // Which of theirs can't rotate, and so why this asks for more: Insights showed three video
                // services side by side while this asked for two (the rating of 2026-11-23).
                let video = store.subscriptions.charging.filter { OverlapDetector.cluster(for: $0) == .videoStreaming && !PausePlanSchedule.isEligible($0) }
                if !video.isEmpty {
                    let named = video.map { $0.billingFrequency == .monthly ? $0.name : L10n.string("\($0.name) (not billed monthly)") }
                    Text("Not in the plan: \(named.formatted(.list(type: .and).locale(L10n.locale))).")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Rotate these")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkTextMuted)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(eligible.enumerated()), id: \.element.id) { index, sub in
                        if index > 0 { Hairline() }
                        selectableRow(sub)
                    }
                }
            }

            estimateCard

            Button {
                guard chosen.count >= 2 else { return }
                if paymentManager.isUnlocked(.pausePlan) {
                    isWorking = true
                    Task {
                        var order = PausePlanSchedule.suggestedOrder(chosen, now: Date())
                        if let firstId, let index = order.firstIndex(of: firstId) {
                            order.remove(at: index)
                            order.insert(firstId, at: 0)
                        }
                        await planStore.start(order: order)
                        Feel.landed()
                        isWorking = false
                    }
                } else {
                    showPaywall = true
                }
            } label: {
                Label(paymentManager.isUnlocked(.pausePlan) ? L10n.string("Start Pause Plan") : L10n.string("Start Pause Plan with Pro"),
                      systemImage: paymentManager.isUnlocked(.pausePlan) ? "arrow.triangle.2.circlepath" : "lock.fill")
            }
            .buttonStyle(.ink)
            .disabled(chosen.count < 2 || isWorking)
            .accessibilityIdentifier("startPausePlanButton")

            Text("Pausely can't cancel for you. It tells you when to cancel and when to start again, and your Savings Receipt counts what rotating saves.")
                .font(.footnote)
                .foregroundStyle(Color.inkTextFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watch one at a time")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // What the person does, said first: "pauses the rest" read as Pausely pausing them, and the page later
            // said Pausely can't cancel for you (the rating of 2026-11-23).
            Text("Pause Plan keeps one streaming service on at a time: you cancel the rest, and it tells you when to switch each month, so you still see everything.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectableRow(_ sub: Subscription) -> some View {
        let isSelected = selected.contains(sub.id)
        let isFirst = isSelected && firstId == sub.id
        let price = sub.status == .cancelled
            ? L10n.string("Cancelled") + " · " + L10n.string("\(money(sub.effectiveAmount, from: sub.currency)) a month")
            : L10n.string("\(money(sub.effectiveAmount, from: sub.currency)) a month")
        let toggle = {
            Feel.selection()
            if isSelected {
                selected.remove(sub.id)
                if firstId == sub.id { firstId = PausePlanSchedule.suggestedOrder(chosen, now: Date()).first }
            } else {
                selected.insert(sub.id)
                if firstId == nil { firstId = sub.id }
            }
        }
        let check = Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.inkText : Color.inkTextFaint)
            .accessibilityHidden(true)
        let words = VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: sub.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            Facts(price)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        // Two things to tap, side by side and not one inside the other: the service (in or out of the
        // rotation) and which one goes first.
        return Group {
            if typeSize.isAccessibilitySize {
                // Words only, one under the other. Beside a logo and "Put first", a name had a column
                // three letters wide and "a month" broke after "mont".
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: toggle) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) { check; words }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    firstControl(sub, isSelected: isSelected, isFirst: isFirst)
                }
            } else {
                HStack(spacing: 12) {
                    Button(action: toggle) {
                        HStack(spacing: 12) {
                            check
                            ServiceLogoView(name: sub.name, category: sub.category, size: 34)
                                .accessibilityHidden(true)
                            words
                            Spacer(minLength: 8)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    firstControl(sub, isSelected: isSelected, isFirst: isFirst)
                }
            }
        }
        .padding(.vertical, 12)
    }

    /// Which service the rotation starts with: said of the one that does, offered on the others.
    @ViewBuilder
    private func firstControl(_ sub: Subscription, isSelected: Bool, isFirst: Bool) -> some View {
        if isFirst {
            Text("On first")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.paperInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.paper))
        } else if isSelected {
            Button {
                Feel.selection()
                firstId = sub.id
            } label: {
                Text("Put first")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .tapArea(typeSize.isAccessibilitySize ? .leading : .trailing)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: L10n.string("Put first") + ", " + sub.name))
        }
    }

    /// The sum, printed: what all of them cost together, what one at a time costs, and the difference.
    private var estimateCard: some View {
        let costs = chosen.compactMap { currencyManager.convertToSelected($0.monthlyCost, from: $0.currency) }
        let now = costs.reduce(0, +)
        let rotating = PausePlanSchedule.monthlyCostWhileRotating(monthlyCosts: costs)
        let yearly = PausePlanSchedule.yearlySavings(monthlyCosts: costs)
        // A service billed in another currency is added at an exchange rate, and the figures say so.
        let display = currencyManager.selectedCurrency
        let converted = chosen.isConverted(to: display)
        return PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 10) {
                ProofLine(label: L10n.string("All at once"), value: BillingFrequency.monthly.priced(MoneyFormat.total(now, display, converted: converted)))
                // "on average" is part of the name, so the figure stands alone in the amounts' column
                // (as the value it made that line the one long value on the slip).
                ProofLine(label: L10n.string("One at a time, on average"), value: BillingFrequency.monthly.priced(MoneyFormat.total(rotating, display, converted: converted)))
                Perforation()
                ProofLine(label: L10n.string("Back in your pocket"), value: L10n.string("About \(currencyManager.format(yearly)) a year"),
                          emphasised: true)
                // An estimate, and what it assumes.
                Text("If you rotate every month, at today's prices.")
                    .font(.proof(.footnote))
                    .foregroundStyle(Color.paperMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Active plan

    @ViewBuilder
    private func activeView(_ plan: PausePlan) -> some View {
        let subs = byId
        let today = Date()
        if let current = PausePlanSchedule.currentTurn(plan, subscriptions: subs, now: today),
           let currentSub = subs[current.subscriptionId] {
            let upcoming = PausePlanSchedule.turns(plan, subscriptions: subs, count: current.index + 5)
                .filter { $0.index > current.index }
            let nextSub = upcoming.first.flatMap { subs[$0.subscriptionId] }

            nowCard(currentSub, until: current.end, next: nextSub)
            todoCard(plan, current: current, currentSub: currentSub, next: upcoming.first, today: today)
            scheduleCard(upcoming)
            savedCard(plan)

            Button {
                confirmEnd = true
            } label: {
                Text("End Pause Plan")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .frame(maxWidth: .infinity, minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("endPausePlanButton")
            .asksFirst(Text("End your Pause Plan?"), isPresented: $confirmEnd,
                       message: Text("Your subscriptions stay as they are. Pausely goes back to its usual renewal reminders.")) {
                Button("End Pause Plan", role: .destructive) { Task { await planStore.end() } }
                Button("Keep it", role: .cancel) {}
            }
        }
    }

    private func nowCard(_ sub: Subscription, until end: Date, next: Subscription?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("On now")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkTextMuted)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                ServiceLogoView(name: sub.name, category: sub.category, size: 48)
                Text(sub.name)
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(next.map { L10n.string("Until \(short(end)). Then \($0.name).") } ?? L10n.string("Until \(short(end))."))
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private struct Todo: Identifiable {
        enum Action { case cancel, start }
        let id: String
        let sub: Subscription
        let text: String
        let action: Action
    }

    private func todos(_ plan: PausePlan, current: PausePlanSchedule.Turn, currentSub: Subscription,
                       next: PausePlanSchedule.Turn?, today: Date) -> [Todo] {
        let subs = byId
        let calendar = Calendar.billing
        var items: [Todo] = []
        // Its month has started: it should be on.
        if !currentSub.renewsAutomatically, current.start != nil {
            items.append(Todo(id: "start-\(currentSub.id)", sub: currentSub,
                              text: L10n.string("Start \(currentSub.name). Its month began \(short(current.start ?? today))."),
                              action: .start))
        }
        for id in plan.subscriptionIds where id != current.subscriptionId {
            guard let sub = subs[id], sub.renewsAutomatically, let renewal = sub.nextRenewal(onOrAfter: today),
                  PausePlanSchedule.shouldPause(id, renewingOn: renewal, plan: plan, current: current) else { continue }
            items.append(Todo(id: "cancel-\(id)", sub: sub,
                              // A free trial doesn't renew: it ends, and that is its first charge.
                              text: sub.status == .trial
                                ? L10n.string("Cancel \(sub.name) before its free trial ends \(short(renewal)).")
                                : L10n.string("Cancel \(sub.name) before it renews \(short(renewal))."),
                              action: .cancel))
        }
        // The handoff is close: cancel the current one before its month ends.
        if let next, currentSub.renewsAutomatically, calendar.calendarDays(from: today, to: current.end) <= 3,
           let nextSub = subs[next.subscriptionId] {
            items.append(Todo(id: "handoff-\(currentSub.id)", sub: currentSub,
                              text: L10n.string("Cancel \(currentSub.name) by \(short(calendar.date(byAdding: .day, value: -1, to: current.end) ?? current.end)). \(nextSub.name) starts \(short(current.end))."),
                              action: .cancel))
        }
        return items
    }

    private func todoCard(_ plan: PausePlan, current: PausePlanSchedule.Turn, currentSub: Subscription,
                          next: PausePlanSchedule.Turn?, today: Date) -> some View {
        let items = todos(plan, current: current, currentSub: currentSub, next: next, today: today)
        return VStack(alignment: .leading, spacing: 12) {
            Text("To do")
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .accessibilityAddTraits(.isHeader)
            if items.isEmpty {
                Label {
                    Text(next.flatMap { byId[$0.subscriptionId] }.map { L10n.string("You're all set. We'll remind you before \($0.name) starts.") }
                         ?? L10n.string("You're all set."))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.inkText)
                }
            } else {
                ForEach(items) { item in
                    // What to do, and the button for it: side by side, or the button underneath at
                    // accessibility sizes, where the sentence needs the whole width.
                    SideBySide(alignment: .center, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            if !typeSize.isAccessibilitySize {
                                ServiceLogoView(name: item.sub.name, category: item.sub.category, size: 32)
                                    .accessibilityHidden(true)
                            }
                            Text(verbatim: item.text)
                                .font(.subheadline)
                                .foregroundStyle(Color.inkText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } trailing: {
                        Button {
                            switch item.action {
                            case .cancel: cancelTarget = item.sub
                            case .start: Task { await planStore.markStarted(item.sub) }
                            }
                        } label: {
                            Text(item.action == .cancel ? L10n.string("How") : L10n.string("I started it"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(item.action == .cancel ? Color.ink : Color.paperInk)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 30)
                                .background(Capsule().fill(item.action == .cancel ? Color.decide : Color.paper))
                                // The pill is small; the place to tap is not.
                                .tapArea()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scheduleCard(_ upcoming: [PausePlanSchedule.Turn]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coming up")
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .accessibilityAddTraits(.isHeader)
            ForEach(upcoming, id: \.index) { turn in
                if let sub = byId[turn.subscriptionId], let start = turn.start {
                    SideBySide(alignment: .center) {
                        HStack(spacing: 12) {
                            if !typeSize.isAccessibilitySize {
                                ServiceLogoView(name: sub.name, category: sub.category, size: 28)
                                    .accessibilityHidden(true)
                            }
                            Text(verbatim: sub.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } trailing: {
                        Text("\(short(start)) – \(short(turn.end))")
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func savedCard(_ plan: PausePlan) -> some View {
        let members = Set(plan.subscriptionIds)
        let lines = SavingsSummary.current().lines.filter { members.contains($0.subscriptionId) && $0.cancelledOn >= Calendar.billing.startOfDay(for: plan.startedOn) }
        let saved = lines.compactMap { currencyManager.convertToSelected($0.savedSoFar, from: $0.currency) }.reduce(0, +)
        // A service billed in another currency is added at an exchange rate, and the figure says so.
        let display = MoneyFormat.normalizedCode(currencyManager.selectedCurrency)
        let converted = lines.contains { MoneyFormat.normalizedCode($0.currency) != display }
        return SideBySide {
            Text("Saved by rotating so far")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
        } trailing: {
            // Money kept is mint once there is some; nothing yet is not.
            Text(verbatim: MoneyFormat.total(saved, currencyManager.selectedCurrency, converted: converted))
                .font(.headline.weight(.bold))
                .foregroundStyle(saved > 0 ? Color.kept : Color.inkText)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Entry card

/// Shown on Analysis and the dashboard: the plan's status, or what rotating would save.
struct PausePlanCard: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var planStore = PausePlanStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showPlan = false

    /// Worth showing: a plan is running, or there are at least two services to rotate. The screen
    /// hands in the plan and the list it watches, so it asks again when either changes.
    static func isRelevant(plan: PausePlan?, subscriptions: [Subscription]) -> Bool {
        plan != nil || subscriptions.filter(PausePlanSchedule.isEligible).count >= 2
    }

    var body: some View {
        // A row like the ones around it: words on the margin, no picture, the way in at the end.
        // (It was an icon in a circle with caption-size text, set 16 points in from everything else.)
        Button {
            Feel.selection()
            showPlan = true
        } label: {
            HStack(spacing: 12) {
                // While a plan runs the row carries the paused mark, as every state does.
                if planStore.activePlan != nil { StateMark(state: .paused) }
                VStack(alignment: .leading, spacing: 4) {
                    // "Pro" beside the name, or under it where the two do not fit a line: beside
                    // it at the largest text size the name was "Pause" above "Plan".
                    LineOrStack(spacing: 8, lineSpacing: 4) {
                        Text("Pause Plan")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkText)
                        if !paymentManager.isUnlocked(.pausePlan) && planStore.activePlan == nil { ProPill() }
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                RowChevron()
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pausePlanCard")
        .sheet(isPresented: $showPlan) { PausePlanView() }
    }

    private var subtitle: String {
        let byId = Dictionary(store.subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        if let plan = planStore.activePlan,
           let current = PausePlanSchedule.currentTurn(plan, subscriptions: byId, now: Date()),
           let sub = byId[current.subscriptionId] {
            return L10n.string("\(sub.name) is on until \(DayText.date(current.end, locale: L10n.locale)).")
        }
        let eligible = store.subscriptions.filter { PausePlanSchedule.isEligible($0) && $0.status != .cancelled }
        let costs = eligible.compactMap { currencyManager.convertToSelected($0.monthlyCost, from: $0.currency) }
        let savings = PausePlanSchedule.yearlySavings(monthlyCosts: costs)
        guard savings > 0 else {
            return L10n.string("Rotate your streaming services and watch one at a time.")
        }
        return L10n.string("Watch one streaming service at a time and get about \(currencyManager.format(savings)) a year back.")
    }
}
