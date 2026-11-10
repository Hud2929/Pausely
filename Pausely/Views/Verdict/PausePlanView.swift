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
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
        .sheet(item: $cancelTarget) { sub in
            CancelSubscriptionFlow(subscription: sub)
        }
        .confirmationDialog("End your Pause Plan?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Pause Plan", role: .destructive) { Task { await planStore.end() } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Your subscriptions stay as they are. Pausely goes back to its usual renewal reminders.")
        }
        .onAppear(perform: setDefaults)
    }

    private func money(_ amount: Decimal, from currency: String) -> String {
        currencyManager.format(currencyManager.convertToSelected(amount, from: currency))
    }

    private func short(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
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
            VStack(spacing: 8) {
                Text("Add two or more streaming services")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                Text("Netflix, Max, Disney+, Hulu, Prime Video and the like. Pause Plan rotates monthly video services; music and storage stay on.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("ROTATE THESE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkTextFaint)
                VStack(spacing: 0) {
                    ForEach(Array(eligible.enumerated()), id: \.element.id) { index, sub in
                        if index > 0 { Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 64) }
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
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(chosen.count >= 2 ? Color.inkText : Color.inkTextMuted))
            }
            .buttonStyle(PlainButtonStyle())
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
            Text("Most people pay for several streaming services and watch one. Pause Plan keeps one on, pauses the rest, and rotates every month, so you still see everything.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectableRow(_ sub: Subscription) -> some View {
        let isSelected = selected.contains(sub.id)
        let isFirst = isSelected && firstId == sub.id
        return Button {
            if isSelected {
                selected.remove(sub.id)
                if firstId == sub.id { firstId = PausePlanSchedule.suggestedOrder(chosen, now: Date()).first }
            } else {
                selected.insert(sub.id)
                if firstId == nil { firstId = sub.id }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.inkText : Color.inkTextFaint)
                    .accessibilityHidden(true)
                ServiceLogoView(name: sub.name, category: sub.category, size: 34)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                    Text(sub.status == .cancelled ? L10n.string("Paused now") : L10n.string("\(money(sub.amount, from: sub.currency)) a month"))
                        .font(.caption)
                        .foregroundStyle(Color.inkTextMuted)
                }
                Spacer(minLength: 8)
                if isFirst {
                    Text("On first")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.paper))
                } else if isSelected {
                    Button("Put first") {
                        firstId = sub.id
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The sum, printed: what all of them cost together, what one at a time costs, and the difference.
    private var estimateCard: some View {
        let costs = chosen.map { currencyManager.convertToSelected($0.monthlyCost, from: $0.currency) }
        let now = costs.reduce(0, +)
        let rotating = PausePlanSchedule.monthlyCostWhileRotating(monthlyCosts: costs)
        let yearly = PausePlanSchedule.yearlySavings(monthlyCosts: costs)
        return PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 10) {
                ProofLine(label: L10n.string("All at once"), value: currencyManager.format(now) + " " + L10n.string("a month"))
                ProofLine(label: L10n.string("One at a time"), value: currencyManager.format(rotating) + " " + L10n.string("a month on average"))
                Perforation()
                ProofLine(label: L10n.string("Back in your pocket"), value: L10n.string("\(currencyManager.format(yearly)) a year"),
                          emphasised: true)
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
                    .foregroundStyle(Color.inkTextFaint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func nowCard(_ sub: Subscription, until end: Date, next: Subscription?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ON NOW")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkTextMuted)
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
        let calendar = Calendar.current
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
                              text: L10n.string("Cancel \(sub.name) before it renews \(short(renewal))."),
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
                    HStack(alignment: .center, spacing: 12) {
                        ServiceLogoView(name: item.sub.name, category: item.sub.category, size: 32)
                            .accessibilityHidden(true)
                        Text(item.text)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button {
                            switch item.action {
                            case .cancel: cancelTarget = item.sub
                            case .start: Task { await planStore.markStarted(item.sub) }
                            }
                        } label: {
                            Text(item.action == .cancel ? L10n.string("How") : L10n.string("I started it"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(Capsule().fill(item.action == .cancel ? Color.decide : Color.paper))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scheduleCard(_ upcoming: [PausePlanSchedule.Turn]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coming up")
                .font(.headline)
                .foregroundStyle(Color.inkText)
            ForEach(upcoming, id: \.index) { turn in
                if let sub = byId[turn.subscriptionId], let start = turn.start {
                    HStack(spacing: 12) {
                        ServiceLogoView(name: sub.name, category: sub.category, size: 28)
                            .accessibilityHidden(true)
                        Text(sub.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                        Spacer()
                        Text("\(short(start)) – \(short(turn.end))")
                            .font(.caption)
                            .foregroundStyle(Color.inkTextMuted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func savedCard(_ plan: PausePlan) -> some View {
        let members = Set(plan.subscriptionIds)
        let lines = SavingsSummary.current().lines.filter { members.contains($0.subscriptionId) && $0.cancelledOn >= Calendar.current.startOfDay(for: plan.startedOn) }
        let saved = lines.reduce(Decimal(0)) { $0 + currencyManager.convertToSelected($1.savedSoFar, from: $1.currency) }
        return HStack {
            Text("Saved by rotating so far")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
            Spacer()
            Text(currencyManager.format(saved))
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.inkText)
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

    /// Worth showing: a plan is running, or there are at least two services to rotate.
    static func isRelevant() -> Bool {
        PausePlanStore.shared.activePlan != nil
            || SubscriptionStore.shared.subscriptions.filter(PausePlanSchedule.isEligible).count >= 2
    }

    var body: some View {
        Button {
            showPlan = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Pause Plan")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                        if !paymentManager.isUnlocked(.pausePlan) && planStore.activePlan == nil {
                            Text("Pro")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.inkText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.06)))
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkTextFaint)
                    .accessibilityHidden(true)
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("pausePlanCard")
        .sheet(isPresented: $showPlan) { PausePlanView() }
    }

    private var subtitle: String {
        let byId = Dictionary(store.subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        if let plan = planStore.activePlan,
           let current = PausePlanSchedule.currentTurn(plan, subscriptions: byId, now: Date()),
           let sub = byId[current.subscriptionId] {
            return L10n.string("\(sub.name) is on until \(current.end.formatted(.dateTime.month(.abbreviated).day())).")
        }
        let eligible = store.subscriptions.filter { PausePlanSchedule.isEligible($0) && $0.status != .cancelled }
        let costs = eligible.map { currencyManager.convertToSelected($0.monthlyCost, from: $0.currency) }
        let savings = PausePlanSchedule.yearlySavings(monthlyCosts: costs)
        guard savings > 0 else {
            return L10n.string("Rotate your streaming services and watch one at a time.")
        }
        return L10n.string("Watch one streaming service at a time and get about \(currencyManager.format(savings)) a year back.")
    }
}
