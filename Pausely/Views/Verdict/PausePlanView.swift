import SwiftUI

/// Pause Plan: keep one streaming (or opted-in monthly) service on at a time and rotate monthly.
/// Supports full queue editing, 1-month extensions, early switches, interactive "Up next" ordering,
/// undated-service prompts (never showing a false "You're all set"), direct resubscribe links, and
/// cumulative saved + 12-month on-track progress.
struct PausePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var planStore = PausePlanStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared

    @State private var paywallRequest: PaywallRequest?
    @State private var cancelTarget: Subscription?
    @State private var addDateTarget: Subscription?
    @State private var openLinkURL: URL?
    @State private var showingEditor = false
    @State private var confirmEnd = false
    @State private var isWorking = false
    @State private var undoSnapshot: UndoSnapshot?
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct PaywallRequest: Identifiable {
        let id = UUID()
        let context: PaywallContext
        let pendingStartSub: Subscription?
        let pendingOrder: [UUID]?
    }

    private struct UndoSnapshot: Equatable {
        let plan: PausePlan
        let message: String
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
                        PausePlanSetupView(
                            existingPlan: nil,
                            isUnlocked: paymentManager.isUnlocked(.pausePlan),
                            isWorking: isWorking,
                            onCommit: { order in startPlan(order: order) },
                            onRequestPro: { ctx, order in
                                paywallRequest = PaywallRequest(context: ctx, pendingStartSub: nil, pendingOrder: order)
                            }
                        )
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
                if planStore.activePlan != nil && paymentManager.isUnlocked(.pausePlan) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            Feel.selection()
                            showingEditor = true
                        }
                        .foregroundStyle(Color.inkText)
                        .accessibilityIdentifier("editPausePlanButton")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $paywallRequest) { request in
            StoreKitUpgradeView(context: request.context) {
                if let order = request.pendingOrder {
                    startPlan(order: order)
                } else if let sub = request.pendingStartSub {
                    Task { _ = await planStore.markStarted(sub) }
                }
            }
        }
        .sheet(item: $cancelTarget) { sub in
            CancelSubscriptionFlow(subscription: sub)
        }
        .sheet(item: $addDateTarget) { sub in
            RenewalDatesSheet(subscriptions: [sub])
        }
        .sheet(isPresented: Binding(get: { openLinkURL != nil }, set: { if !$0 { openLinkURL = nil } })) {
            if let url = openLinkURL { SafariView(url: url).ignoresSafeArea() }
        }
        .sheet(isPresented: $showingEditor) {
            if let plan = planStore.activePlan {
                NavigationStack {
                    ScrollView {
                        PausePlanSetupView(
                            existingPlan: plan,
                            isUnlocked: true,
                            isWorking: isWorking,
                            onCommit: { newOrder in
                                showingEditor = false
                                undoSnapshot = nil
                                runPlanMutation {
                                    await planStore.updateOrder(newOrder)
                                    Feel.tick()
                                }
                            },
                            onRequestPro: { _, _ in }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                    .readableScroll()
                    .background(Color.ink.ignoresSafeArea())
                    .navigationTitle("Edit Pause Plan")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showingEditor = false }
                                .foregroundStyle(Color.inkText)
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
    }

    private func short(_ date: Date) -> String {
        DayText.date(date, locale: L10n.locale)
    }

    private func startPlan(order: [UUID]) {
        guard order.count >= 2 else { return }
        runPlanMutation {
            await planStore.start(order: order)
            Feel.landed()
        }
    }

    private func runPlanMutation(_ work: @escaping () async -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await work()
            isWorking = false
        }
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
            let unlocked = paymentManager.isUnlocked(.pausePlan)

            if !unlocked {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Pausely Pro plan ended")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                    Text("Your schedule stays here. Renew Pro to keep rotating with Pause Plan.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        paywallRequest = PaywallRequest(
                            context: PaywallContext(trigger: .pausePlan),
                            pendingStartSub: nil,
                            pendingOrder: nil
                        )
                    } label: { Text("Renew Pausely Pro") }
                        .buttonStyle(.ink(.quiet))
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                Hairline()
            }

            nowCard(plan, currentSub: currentSub, until: current.end, next: nextSub, unlocked: unlocked)

            if let snapshot = undoSnapshot {
                undoBar(snapshot)
            }

            if unlocked {
                todoCard(plan, next: upcoming.first, today: today)
            }
            scheduleCard(plan, upcoming: upcoming, unlocked: unlocked)
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
                Button("End Pause Plan", role: .destructive) {
                    undoSnapshot = nil
                    Task { await planStore.end() }
                }
                Button("Keep it", role: .cancel) {}
            }
        }
    }

    private func nowCard(_ plan: PausePlan, currentSub: Subscription, until end: Date,
                         next: Subscription?, unlocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("On now")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkTextMuted)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                ServiceLogoView(name: currentSub.name, category: currentSub.category, size: 48)
                Text(verbatim: currentSub.name)
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(next.map { L10n.string("Until \(short(end)). Then \($0.name).") } ?? L10n.string("Until \(short(end))."))
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)

            if unlocked, let next {
                LineOrStack(spacing: 10, lineSpacing: 8) {
                    Button {
                        let previous = plan
                        runPlanMutation {
                            await planStore.extendCurrentTurn()
                            Feel.tick()
                            withAnimation(Motion.unlessReduced(Motion.touch)) {
                                undoSnapshot = UndoSnapshot(
                                    plan: previous,
                                    message: L10n.string("Kept \(currentSub.name) for 1 more month.")
                                )
                            }
                        }
                    } label: {
                        Text("Stay 1 more month")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
                            .tapArea(.leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                    .accessibilityIdentifier("extendPausePlanButton")

                    Button {
                        let previous = plan
                        runPlanMutation {
                            await planStore.switchToNext()
                            Feel.tick()
                            withAnimation(Motion.unlessReduced(Motion.touch)) {
                                undoSnapshot = UndoSnapshot(
                                    plan: previous,
                                    message: L10n.string("Switched to \(next.name).")
                                )
                            }
                        }
                    } label: {
                        Text("Switch to \(next.name) now")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
                            .tapArea(.leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                    .accessibilityIdentifier("switchPausePlanButton")
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func undoBar(_ snapshot: UndoSnapshot) -> some View {
        SideBySide(alignment: .center, spacing: 12) {
            Text(verbatim: snapshot.message)
                .font(.footnote)
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
        } trailing: {
            Button {
                Feel.selection()
                let restorePlan = snapshot.plan
                withAnimation(Motion.unlessReduced(Motion.touch)) { undoSnapshot = nil }
                runPlanMutation { await planStore.restore(restorePlan) }
            } label: {
                Text("Undo")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.paperInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.paper))
                    .tapArea(.trailing)
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
            .accessibilityIdentifier("undoPausePlanActionButton")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous).stroke(Color.line, lineWidth: 1))
    }

    // MARK: - To do

    private func todoCard(_ plan: PausePlan, next: PausePlanSchedule.Turn?, today: Date) -> some View {
        let items = PausePlanSchedule.actionItems(for: plan, subscriptions: store.subscriptions, now: today)
        let subs = byId
        return VStack(alignment: .leading, spacing: 12) {
            Text("To do")
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .accessibilityAddTraits(.isHeader)
            if items.isEmpty {
                Label {
                    Text(next.flatMap { subs[$0.subscriptionId] }.map { L10n.string("You're all set. We'll remind you before \($0.name) starts.") }
                         ?? L10n.string("You're all set."))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.inkText)
                }
            } else {
                ForEach(items) { item in
                    if let sub = subs[item.subscriptionId] {
                        todoRow(item, sub: sub, subs: subs, today: today)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todoRow(_ item: PausePlanSchedule.ActionItem, sub: Subscription,
                         subs: [UUID: Subscription], today: Date) -> some View {
        let message = todoText(item, sub: sub, subs: subs, today: today)
        return SideBySide(alignment: .center, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    ServiceLogoView(name: sub.name, category: sub.category, size: 32)
                        .accessibilityHidden(true)
                }
                Text(verbatim: message)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } trailing: {
            todoControls(item, sub: sub)
        }
    }

    private func todoText(_ item: PausePlanSchedule.ActionItem, sub: Subscription,
                          subs: [UUID: Subscription], today: Date) -> String {
        switch item.kind {
        case .addDate:
            return L10n.string("Add a renewal date for \(sub.name) so Pausely can remind you before it charges.")
        case .start:
            return L10n.string("Start \(sub.name). Its month began \(short(item.dueDate ?? today)).")
        case .cancel:
            let due = item.dueDate ?? today
            if let nextId = item.nextSubscriptionId, let nextSub = subs[nextId] {
                let dayBefore = Calendar.billing.date(byAdding: .day, value: -1, to: due) ?? due
                return L10n.string("Cancel \(sub.name) by \(short(dayBefore)). \(nextSub.name) starts \(short(due)).")
            }
            return item.isTrialEnd
                ? L10n.string("Cancel \(sub.name) before its free trial ends \(short(due)).")
                : L10n.string("Cancel \(sub.name) before it renews \(short(due)).")
        }
    }

    @ViewBuilder
    private func todoControls(_ item: PausePlanSchedule.ActionItem, sub: Subscription) -> some View {
        switch item.kind {
        case .addDate:
            Button {
                Feel.selection()
                addDateTarget = sub
            } label: {
                Text("Add date")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.decide))
                    .tapArea()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pausePlanAddDate_\(sub.name)")

        case .cancel:
            Button {
                Feel.selection()
                cancelTarget = sub
            } label: {
                Text("How")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.decide))
                    .tapArea()
            }
            .buttonStyle(.plain)

        case .start:
            let destination = CancelHelp.resubscribeLink(for: sub)
            LineOrStack(spacing: 6, lineSpacing: 4) {
                if let destination {
                    Button {
                        Feel.selection()
                        if destination.openInSystem {
                            openURL(destination.url)
                        } else {
                            openLinkURL = destination.url
                        }
                    } label: {
                        Text("Open")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
                            .tapArea()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(L10n.string("Open \(sub.name)")))
                }

                Button {
                    Task {
                        if await planStore.markStarted(sub) {
                            Feel.landed()
                        } else {
                            paywallRequest = PaywallRequest(
                                context: PaywallContext(
                                    trigger: .unlimitedSubscriptions,
                                    serviceName: sub.name,
                                    serviceChargeAmount: sub.amount,
                                    serviceChargeCurrency: sub.currency
                                ),
                                pendingStartSub: sub,
                                pendingOrder: nil
                            )
                        }
                    }
                } label: {
                    Text("I started it")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.paperInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.paper))
                        .tapArea()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Coming up & savings

    private func scheduleCard(_ plan: PausePlan, upcoming: [PausePlanSchedule.Turn], unlocked: Bool) -> some View {
        let nextId = upcoming.first?.subscriptionId
        return VStack(alignment: .leading, spacing: 10) {
            Text("Coming up")
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(upcoming.enumerated()), id: \.element.index) { offset, turn in
                if let sub = byId[turn.subscriptionId], let start = turn.start {
                    let canPromote = unlocked && offset > 0 && plan.subscriptionIds.count >= 3 && turn.subscriptionId != nextId
                    SideBySide(alignment: .center, spacing: 8) {
                        HStack(spacing: 12) {
                            if !typeSize.isAccessibilitySize {
                                ServiceLogoView(name: sub.name, category: sub.category, size: 28)
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: sub.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.inkText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(short(start)) – \(short(turn.end))")
                                    .font(.footnote)
                                    .foregroundStyle(Color.inkTextMuted)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    } trailing: {
                        if canPromote {
                            Button {
                                let previous = plan
                                runPlanMutation {
                                    await planStore.bringUpNext(sub.id)
                                    Feel.tick()
                                    withAnimation(Motion.unlessReduced(Motion.touch)) {
                                        undoSnapshot = UndoSnapshot(
                                            plan: previous,
                                            message: L10n.string("Moved \(sub.name) up next.")
                                        )
                                    }
                                }
                            } label: {
                                Text("Up next")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.inkText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
                                    .tapArea(.trailing)
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking)
                            .accessibilityLabel(Text(L10n.string("Move \(sub.name) up next")))
                            .accessibilityIdentifier("pauseUpNext_\(sub.name)")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func savedCard(_ plan: PausePlan) -> some View {
        let display = currencyManager.selectedCurrency
        let progress = PausePlanSchedule.savingsProgress(
            for: plan,
            lines: SavingsSummary.current().lines,
            currency: display,
            rates: currencyManager.rates
        )
        let unconvertibleOnly = progress.savedSoFar == 0 && progress.onTrack == 0 && progress.excludedUnconvertibleCount > 0
        let savedText = unconvertibleOnly
            ? "—"
            : MoneyFormat.total(progress.savedSoFar, display, converted: progress.savedIsConverted, locale: L10n.locale)
        let onTrackText = MoneyFormat.total(progress.onTrack, display, converted: progress.onTrackIsConverted, locale: L10n.locale)

        return VStack(alignment: .leading, spacing: 8) {
            SideBySide {
                Text("Saved by rotating so far")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
            } trailing: {
                Text(verbatim: savedText)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(progress.savedSoFar > 0 ? Color.kept : Color.inkText)
            }
            .accessibilityElement(children: .combine)

            if progress.onTrack > progress.savedSoFar {
                SideBySide {
                    Text("On track over 12 months")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextMuted)
                } trailing: {
                    Text(verbatim: onTrackText)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.kept)
                }
                .accessibilityElement(children: .combine)
            }

            if progress.excludedUnconvertibleCount > 0 {
                Text(progress.excludedUnconvertibleCount == 1
                     ? L10n.string("1 cancelled service uses a currency without a conversion rate and isn't in this total.")
                     : L10n.string("\(progress.excludedUnconvertibleCount) cancelled services use currencies without conversion rates and aren't in this total."))
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Worth showing: a plan is running, or there are at least two streaming services to rotate.
    static func isRelevant(plan: PausePlan?, subscriptions: [Subscription]) -> Bool {
        plan != nil || subscriptions.filter(PausePlanSchedule.isEligible).count >= 2
    }

    /// Strict yearly savings across eligible active streaming subscriptions; nil if any eligible
    /// subscription cannot be converted (no silent zero-drops).
    @MainActor static func yearlySavingsInfo(in subscriptions: [Subscription], currency: CurrencyManager)
        -> (amount: Decimal, currency: String, isConverted: Bool, names: [String])? {
        let eligible = subscriptions.filter { PausePlanSchedule.isEligible($0) && $0.status != .cancelled }
        guard eligible.count >= 2 else { return nil }
        let display = currency.selectedCurrency
        var costs: [Decimal] = []
        for sub in eligible {
            guard let converted = currency.convertToSelected(sub.monthlyCost, from: sub.currency) else { return nil }
            costs.append(converted)
        }
        let savings = PausePlanSchedule.yearlySavings(monthlyCosts: costs)
        guard savings > 0 else { return nil }
        return (savings, display, eligible.isConverted(to: display), eligible.map(\.name))
    }

    var body: some View {
        Button {
            Feel.selection()
            showPlan = true
        } label: {
            HStack(spacing: 12) {
                if planStore.activePlan != nil { StateMark(state: .paused) }
                VStack(alignment: .leading, spacing: 4) {
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
        if let plan = planStore.activePlan {
            if !paymentManager.isUnlocked(.pausePlan) {
                return L10n.string("Pausely Pro ended. Renew to keep rotating.")
            }
            if let current = PausePlanSchedule.currentTurn(plan, subscriptions: byId, now: Date()),
               let sub = byId[current.subscriptionId] {
                return L10n.string("\(sub.name) is on until \(DayText.date(current.end, locale: L10n.locale)).")
            }
        }
        guard let info = Self.yearlySavingsInfo(in: store.subscriptions, currency: currencyManager) else {
            return L10n.string("Rotate your streaming services and watch one at a time.")
        }
        let formatted = MoneyFormat.total(info.amount, info.currency, converted: info.isConverted, locale: L10n.locale)
        return L10n.string("Watch one streaming service at a time and get about \(formatted) a year back.")
    }
}
