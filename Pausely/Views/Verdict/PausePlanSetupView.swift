import SwiftUI

/// Setup & live queue editor for Pause Plan.
/// Supports full queue ordering (up/down move controls), optional opt-in for non-streaming monthly
/// subscriptions (such as AI or creative tools), and a strict Paper Slip estimate that always shows
/// `≈` for converted figures and never silently drops unknown currencies.
struct PausePlanSetupView: View {
    /// Non-nil when editing an already-running plan (preserves cumulative savings on save).
    let existingPlan: PausePlan?
    let isUnlocked: Bool
    let isWorking: Bool
    let onCommit: ([UUID]) -> Void
    let onRequestPro: (PaywallContext, [UUID]) -> Void

    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var orderedIds: [UUID] = []
    @State private var showOtherMonthly = false
    @State private var didInitialize = false

    private var isEditing: Bool { existingPlan != nil }

    private var byId: [UUID: Subscription] {
        Dictionary(store.subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private var eligibleStreaming: [Subscription] {
        store.subscriptions.filter(PausePlanSchedule.isEligible).sorted { $0.name < $1.name }
    }

    private var optInMonthly: [Subscription] {
        store.subscriptions.filter(PausePlanSchedule.isOptInEligible).sorted { $0.name < $1.name }
    }

    private var totalCandidateCount: Int {
        eligibleStreaming.count + optInMonthly.count
    }

    private var chosen: [Subscription] {
        orderedIds.compactMap { byId[$0] }
    }

    private var unselectedStreaming: [Subscription] {
        let picked = Set(orderedIds)
        return eligibleStreaming.filter { !picked.contains($0.id) }
    }

    private var unselectedOptIn: [Subscription] {
        let picked = Set(orderedIds)
        return optInMonthly.filter { !picked.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 20) {
            if !isEditing {
                intro
            }

            if totalCandidateCount < 2 {
                tooFewView
            } else {
                queueSection

                if !unselectedStreaming.isEmpty {
                    availableSection(title: L10n.string("More streaming services"), items: unselectedStreaming)
                }

                if !unselectedOptIn.isEmpty {
                    optInDrawer
                }

                if chosen.count >= 2 {
                    estimateCard
                }

                primaryButton

                if !isEditing {
                    Text("Pausely can't cancel for you. It tells you when to cancel and when to start again, and your Savings Receipt counts what rotating saves.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear(perform: initializeIfNeeded)
    }

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true
        if let existingPlan {
            let valid = Set(store.subscriptions.map(\.id))
            let subs = byId
            let base = existingPlan.subscriptionIds.filter(valid.contains)
            if let current = PausePlanSchedule.currentTurn(existingPlan, subscriptions: subs, now: Date()) {
                orderedIds = PausePlanSchedule.rotatedOrderStartingAt(current.subscriptionId, in: base)
            } else {
                orderedIds = base
            }
            if orderedIds.contains(where: { subs[$0].map(PausePlanSchedule.isOptInEligible) == true }) {
                showOtherMonthly = true
            }
        } else {
            let active = eligibleStreaming.filter { $0.status != .cancelled }
            let seed = active.count >= 2 ? active : eligibleStreaming
            orderedIds = PausePlanSchedule.suggestedOrder(seed, now: Date())
            if eligibleStreaming.count < 2 && !optInMonthly.isEmpty {
                showOtherMonthly = true
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watch one at a time")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Pause Plan keeps one streaming service on at a time: you cancel the rest, and it tells you when to switch each month, so you still see everything.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tooFewView: some View {
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
            let video = store.subscriptions.charging.filter {
                OverlapDetector.cluster(for: $0) == .videoStreaming && !PausePlanSchedule.isEligible($0)
            }
            if !video.isEmpty {
                let named = video.map {
                    $0.billingFrequency == .monthly ? $0.name : L10n.string("\($0.name) (not billed monthly)")
                }
                Text("Not in the plan: \(named.formatted(.list(type: .and).locale(L10n.locale))).")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SideBySide(spacing: 12) {
                Text(isEditing ? L10n.string("Rotation order") : L10n.string("Rotate these"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkTextMuted)
                    .accessibilityAddTraits(.isHeader)
            } trailing: {
                if chosen.count >= 2 {
                    Text("Top plays first")
                        .font(.caption)
                        .foregroundStyle(Color.inkTextFaint)
                }
            }

            if chosen.isEmpty {
                Text("Pick at least two monthly subscriptions below to build your rotation.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(chosen.enumerated()), id: \.element.id) { index, sub in
                        if index > 0 { Hairline() }
                        selectedRow(sub, position: index, total: chosen.count)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func availableSection(title: String, items: [Subscription]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkTextMuted)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, sub in
                    if index > 0 { Hairline() }
                    unselectedRow(sub)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var optInDrawer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Feel.selection()
                withAnimation(Motion.unlessReduced(Motion.touch)) { showOtherMonthly.toggle() }
            } label: {
                SideBySide(spacing: 12) {
                    Text("Include other monthly subscriptions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                } trailing: {
                    Image(systemName: showOtherMonthly ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkTextMuted)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: Layout.tapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pausePlanOptInDrawer")

            if showOtherMonthly {
                Text("You can also rotate monthly AI, creative, or gaming subscriptions.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(Array(unselectedOptIn.enumerated()), id: \.element.id) { index, sub in
                        if index > 0 { Hairline() }
                        unselectedRow(sub)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectedRow(_ sub: Subscription, position: Int, total: Int) -> some View {
        let price = priceLine(for: sub)
        let toggle = {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) {
                orderedIds.removeAll { $0 == sub.id }
            }
        }
        let check = Image(systemName: "checkmark.circle.fill")
            .font(.title3)
            .foregroundStyle(Color.inkText)
            .accessibilityHidden(true)
        let words = VStack(alignment: .leading, spacing: 2) {
            LineOrStack(spacing: 6, lineSpacing: 4) {
                Text(verbatim: sub.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                if position == 0 {
                    Text("On first")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.paperInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.paper))
                }
            }
            Facts(price)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }

        let controls = HStack(spacing: 4) {
            if total >= 2 {
                Button {
                    move(from: position, delta: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(position > 0 ? Color.inkText : Color.inkTextFaint.opacity(0.35))
                        .tapArea()
                }
                .buttonStyle(.plain)
                .disabled(position == 0)
                .accessibilityLabel(Text(L10n.string("Move \(sub.name) earlier")))
                .accessibilityIdentifier("pauseMoveUp_\(sub.name)")

                Button {
                    move(from: position, delta: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(position < total - 1 ? Color.inkText : Color.inkTextFaint.opacity(0.35))
                        .tapArea()
                }
                .buttonStyle(.plain)
                .disabled(position == total - 1)
                .accessibilityLabel(Text(L10n.string("Move \(sub.name) later")))
                .accessibilityIdentifier("pauseMoveDown_\(sub.name)")
            }
        }

        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: toggle) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) { check; words }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isSelected)
                    controls
                }
            } else {
                HStack(spacing: 8) {
                    Button(action: toggle) {
                        HStack(spacing: 12) {
                            check
                            ServiceLogoView(name: sub.name, category: sub.category, size: 34)
                                .accessibilityHidden(true)
                            words
                            Spacer(minLength: 4)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isSelected)
                    controls
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func unselectedRow(_ sub: Subscription) -> some View {
        let price = priceLine(for: sub)
        return Button {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) {
                orderedIds.append(sub.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(Color.inkTextFaint)
                    .accessibilityHidden(true)
                if !typeSize.isAccessibilitySize {
                    ServiceLogoView(name: sub.name, category: sub.category, size: 34)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: sub.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                    Facts(price)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: Layout.tapTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func move(from index: Int, delta: Int) {
        let target = index + delta
        guard orderedIds.indices.contains(index), orderedIds.indices.contains(target) else { return }
        Feel.selection()
        withAnimation(Motion.unlessReduced(Motion.touch)) {
            orderedIds.swapAt(index, target)
        }
    }

    private func priceLine(for sub: Subscription) -> String {
        let monthlyText = money(sub.amount, from: sub.currency)
        return sub.status == .cancelled
            ? L10n.string("Cancelled") + " · " + L10n.string("\(monthlyText) a month")
            : L10n.string("\(monthlyText) a month")
    }

    private func money(_ amount: Decimal, from currency: String) -> String {
        guard let converted = currencyManager.convertToSelected(amount, from: currency) else {
            return MoneyFormat.string(amount, currency)
        }
        return MoneyFormat.total(converted, currencyManager.selectedCurrency,
                                 converted: MoneyFormat.normalizedCode(currency) != MoneyFormat.normalizedCode(currencyManager.selectedCurrency))
    }

    /// Strict Paper Slip estimate: exact `≈` on all converted lines and an explicit warning if any
    /// chosen subscription lacks a conversion rate.
    @ViewBuilder
    private var estimateCard: some View {
        let display = currencyManager.selectedCurrency
        if let est = PausePlanSchedule.estimate(for: chosen, currency: display, rates: currencyManager.rates) {
            let allText = BillingFrequency.monthly.priced(MoneyFormat.total(est.monthlyAll, display, converted: est.isConverted))
            let rotText = BillingFrequency.monthly.priced(MoneyFormat.total(est.monthlyRotating, display, converted: est.isConverted))
            let yearlyText = MoneyFormat.total(est.yearlySavings, display, converted: est.isConverted, locale: L10n.locale)
            PaperSlip(tornTop: true, tornBottom: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ProofLine(label: L10n.string("All at once"), value: allText)
                    ProofLine(label: L10n.string("One at a time, on average"), value: rotText)
                    Perforation()
                    ProofLine(label: L10n.string("Back in your pocket"),
                              value: L10n.string("About \(yearlyText) a year"),
                              emphasised: true)
                    Text("If you rotate every month, at today's prices.")
                        .font(.proof(.footnote))
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if est.excludedUnconvertibleCount > 0 {
                        Text(est.excludedUnconvertibleCount == 1
                             ? L10n.string("1 service uses a currency without a conversion rate and isn't in this estimate.")
                             : L10n.string("\(est.excludedUnconvertibleCount) services use currencies without conversion rates and aren't in this estimate."))
                            .font(.proof(.footnote))
                            .foregroundStyle(Color.paperDue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("We couldn't convert these currencies to estimate yearly savings, so your rotation will still run without a combined total.")
                .font(.footnote)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var primaryButton: some View {
        Button {
            guard chosen.count >= 2 else { return }
            if isEditing || isUnlocked {
                onCommit(orderedIds)
            } else {
                let display = currencyManager.selectedCurrency
                let est = PausePlanSchedule.estimate(for: chosen, currency: display, rates: currencyManager.rates)
                let ctx = PaywallContext(
                    trigger: .pausePlan,
                    pausePlanYearlySavings: est?.yearlySavings,
                    pausePlanCurrency: est != nil ? display : nil,
                    pausePlanIsConverted: est?.isConverted ?? false,
                    pausePlanServices: chosen.map(\.name)
                )
                onRequestPro(ctx, orderedIds)
            }
        } label: {
            if isEditing {
                Text("Save changes")
            } else {
                Label(isUnlocked ? L10n.string("Start Pause Plan") : L10n.string("Start Pause Plan with Pro"),
                      systemImage: isUnlocked ? "arrow.triangle.2.circlepath" : "lock.fill")
            }
        }
        .buttonStyle(.ink)
        .disabled(chosen.count < 2 || isWorking)
        .accessibilityIdentifier(isEditing ? "savePausePlanEditsButton" : "startPausePlanButton")
    }
}
