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
            .background(Color.obsidianBlack.ignoresSafeArea())
            .navigationTitle("Pause Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.accentMint)
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
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                Text("Netflix, Max, Disney+, Hulu, Prime Video and the like. Pause Plan rotates monthly video services; music and storage stay on.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("ROTATE THESE")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.obsidianTextTertiary)
                VStack(spacing: 0) {
                    ForEach(Array(eligible.enumerated()), id: \.element.id) { index, sub in
                        if index > 0 { Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 64) }
                        selectableRow(sub)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
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
                        HapticStyle.success.trigger()
                        isWorking = false
                    }
                } else {
                    HapticStyle.medium.trigger()
                    showPaywall = true
                }
            } label: {
                Label(paymentManager.isUnlocked(.pausePlan) ? String(localized: "Start Pause Plan") : String(localized: "Start Pause Plan with Pro"),
                      systemImage: paymentManager.isUnlocked(.pausePlan) ? "arrow.triangle.2.circlepath" : "lock.fill")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(chosen.count >= 2 ? Color.accentMint : Color.accentMint.opacity(0.35)))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(chosen.count < 2 || isWorking)
            .accessibilityIdentifier("startPausePlanButton")

            Text("Pausely can't cancel for you. It tells you when to cancel and when to start again, and your Savings Receipt counts what rotating saves.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.obsidianTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var intro: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.accentMint)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.accentMint.opacity(0.15)))
                .accessibilityHidden(true)
            Text("Watch one at a time")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text("Most people pay for several streaming services and watch one. Pause Plan keeps one on, pauses the rest, and rotates every month, so you still see everything.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func selectableRow(_ sub: Subscription) -> some View {
        let isSelected = selected.contains(sub.id)
        let isFirst = isSelected && firstId == sub.id
        return Button {
            HapticStyle.light.trigger()
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
                    .foregroundStyle(isSelected ? Color.accentMint : Color.obsidianTextTertiary)
                    .accessibilityHidden(true)
                ServiceLogoView(name: sub.name, category: sub.category, size: 34)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(sub.status == .cancelled ? String(localized: "Paused now") : String(localized: "\(money(sub.amount, from: sub.currency)) a month"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }
                Spacer(minLength: 8)
                if isFirst {
                    Text("On first")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentMint))
                } else if isSelected {
                    Button("Put first") {
                        HapticStyle.light.trigger()
                        firstId = sub.id
                    }
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.accentMint)
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

    private var estimateCard: some View {
        let costs = chosen.map { currencyManager.convertToSelected($0.monthlyCost, from: $0.currency) }
        let now = costs.reduce(0, +)
        let rotating = PausePlanSchedule.monthlyCostWhileRotating(monthlyCosts: costs)
        let yearly = PausePlanSchedule.yearlySavings(monthlyCosts: costs)
        return VStack(spacing: 12) {
            HStack {
                estimateColumn(String(localized: "All at once"), currencyManager.format(now), String(localized: "a month"))
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .accessibilityHidden(true)
                estimateColumn(String(localized: "One at a time"), currencyManager.format(rotating), String(localized: "a month on average"))
            }
            Divider().overlay(Color.white.opacity(0.08))
            HStack {
                Text("Back in your pocket")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                Spacer()
                Text("\(currencyManager.format(yearly)) a year")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.accentMint)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.accentMint.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func estimateColumn(_ title: String, _ amount: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.obsidianTextTertiary)
            Text(amount)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(caption)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.obsidianTextTertiary)
        }
        .frame(maxWidth: .infinity)
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
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func nowCard(_ sub: Subscription, until end: Date, next: Subscription?) -> some View {
        VStack(spacing: 10) {
            Text("ON NOW")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .tracking(2)
                .foregroundStyle(Color.obsidianTextTertiary)
            ServiceLogoView(name: sub.name, category: sub.category, size: 60)
                .accessibilityHidden(true)
            Text(sub.name)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text(next.map { String(localized: "Until \(short(end)). Then \($0.name).") } ?? String(localized: "Until \(short(end))."))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.obsidianSurface))
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
                              text: String(localized: "Start \(currentSub.name). Its month began \(short(current.start ?? today))."),
                              action: .start))
        }
        for id in plan.subscriptionIds where id != current.subscriptionId {
            guard let sub = subs[id], sub.renewsAutomatically, let renewal = sub.nextRenewal(onOrAfter: today),
                  PausePlanSchedule.shouldPause(id, renewingOn: renewal, plan: plan, current: current) else { continue }
            items.append(Todo(id: "cancel-\(id)", sub: sub,
                              text: String(localized: "Cancel \(sub.name) before it renews \(short(renewal))."),
                              action: .cancel))
        }
        // The handoff is close: cancel the current one before its month ends.
        if let next, currentSub.renewsAutomatically, calendar.calendarDays(from: today, to: current.end) <= 3,
           let nextSub = subs[next.subscriptionId] {
            items.append(Todo(id: "handoff-\(currentSub.id)", sub: currentSub,
                              text: String(localized: "Cancel \(currentSub.name) by \(short(calendar.date(byAdding: .day, value: -1, to: current.end) ?? current.end)). \(nextSub.name) starts \(short(current.end))."),
                              action: .cancel))
        }
        return items
    }

    private func todoCard(_ plan: PausePlan, current: PausePlanSchedule.Turn, currentSub: Subscription,
                          next: PausePlanSchedule.Turn?, today: Date) -> some View {
        let items = todos(plan, current: current, currentSub: currentSub, next: next, today: today)
        return VStack(alignment: .leading, spacing: 12) {
            Text("To do")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            if items.isEmpty {
                Label {
                    Text(next.flatMap { byId[$0.subscriptionId] }.map { String(localized: "You're all set. We'll remind you before \($0.name) starts.") }
                         ?? String(localized: "You're all set."))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentMint)
                }
            } else {
                ForEach(items) { item in
                    HStack(alignment: .center, spacing: 12) {
                        ServiceLogoView(name: item.sub.name, category: item.sub.category, size: 32)
                            .accessibilityHidden(true)
                        Text(item.text)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button {
                            HapticStyle.light.trigger()
                            switch item.action {
                            case .cancel: cancelTarget = item.sub
                            case .start: Task { await planStore.markStarted(item.sub) }
                            }
                        } label: {
                            Text(item.action == .cancel ? String(localized: "How") : String(localized: "I started it"))
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(Capsule().fill(item.action == .cancel ? Color.orange : Color.accentMint))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
    }

    private func scheduleCard(_ upcoming: [PausePlanSchedule.Turn]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coming up")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            ForEach(upcoming, id: \.index) { turn in
                if let sub = byId[turn.subscriptionId], let start = turn.start {
                    HStack(spacing: 12) {
                        ServiceLogoView(name: sub.name, category: sub.category, size: 28)
                            .accessibilityHidden(true)
                        Text(sub.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(short(start)) – \(short(turn.end))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color.obsidianTextSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
    }

    private func savedCard(_ plan: PausePlan) -> some View {
        let members = Set(plan.subscriptionIds)
        let lines = SavingsSummary.current().lines.filter { members.contains($0.subscriptionId) && $0.cancelledOn >= Calendar.current.startOfDay(for: plan.startedOn) }
        let saved = lines.reduce(Decimal(0)) { $0 + currencyManager.convertToSelected($1.savedSoFar, from: $1.currency) }
        return HStack {
            Text("Saved by rotating so far")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
            Spacer()
            Text(currencyManager.format(saved))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.accentMint)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.obsidianSurface))
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
            HapticStyle.light.trigger()
            showPlan = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentMint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.accentMint.opacity(0.15)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Pause Plan")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                        if !paymentManager.isUnlocked(.pausePlan) && planStore.activePlan == nil {
                            Text("Pro")
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .foregroundStyle(Color.accentMint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentMint.opacity(0.15)))
                        }
                    }
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.obsidianSurface))
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
            return String(localized: "\(sub.name) is on until \(current.end.formatted(.dateTime.month(.abbreviated).day())).")
        }
        let eligible = store.subscriptions.filter { PausePlanSchedule.isEligible($0) && $0.status != .cancelled }
        let costs = eligible.map { currencyManager.convertToSelected($0.monthlyCost, from: $0.currency) }
        let savings = PausePlanSchedule.yearlySavings(monthlyCosts: costs)
        guard savings > 0 else {
            return String(localized: "Rotate your streaming services and watch one at a time.")
        }
        return String(localized: "Watch one streaming service at a time and get about \(currencyManager.format(savings)) a year back.")
    }
}
