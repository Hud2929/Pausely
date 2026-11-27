//
//  AnalysisView.swift
//  Pausely
//
//  Insights: key spend metrics, 12-month renewal cash-flow forecast, interactive cut simulator,
//  flexible-vs-committed spend mix, overlaps, price hikes, and hourly cost of use.
//

import SwiftUI

struct AnalysisView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var pausePlanStore = PausePlanStore.shared
    @ObservedObject private var usageLog = UsageLog.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct PaywallPresentation: Identifiable {
        let id = UUID()
        let context: PaywallContext
    }

    @State private var selectedOverlap: OverlapDetector.Group?
    @State private var pendingOverlapSubscription: UUID?
    @State private var pendingPausePlanFromOverlap = false
    @State private var showingPausePlan = false
    @State private var showingDates = false
    @State private var showingSimulator = false
    @State private var pendingSimulatorSubscription: UUID?
    @State private var paywallPresentation: PaywallPresentation?
    @State private var loggingUsageFor: Subscription?
    @State private var profile = OnboardingProfile.load()

    private var live: [Subscription] { store.activeSubscriptions }

    /// Each live subscription with its monthly cost in the display currency, most expensive first.
    /// One that can't be converted is left out rather than ranked at the wrong value.
    private var ranked: [(subscription: Subscription, monthly: Decimal)] {
        live.compactMap { sub in
            currencyManager.rates.convert(sub.monthlyCost, from: sub.currency, to: currencyManager.selectedCurrency)
                .map { (sub, $0) }
        }
        .sorted { $0.monthly > $1.monthly }
    }

    private var increases: [(subscription: Subscription, from: Decimal, since: Date)] {
        live.compactMap { sub in
            guard let change = PriceHistory.latestChange(for: sub, events: eventLog.events), change.isIncrease else { return nil }
            return (sub, change.from, change.since)
        }
    }

    private var overview: InsightsEngine.Overview {
        InsightsEngine.overview(for: store.subscriptions,
                                currency: currencyManager.selectedCurrency,
                                rates: currencyManager.rates)
    }

    private var forecast: InsightsEngine.ForecastSummary {
        InsightsEngine.monthlyForecast(for: store.subscriptions,
                                       now: Date(),
                                       currency: currencyManager.selectedCurrency,
                                       rates: currencyManager.rates)
    }

    private var cutCandidates: [InsightsEngine.CutCandidate] {
        InsightsEngine.cutCandidates(in: store.subscriptions,
                                     events: eventLog.events,
                                     minutesThisMonth: { usageLog.getUsage(for: $0)?.minutesUsed },
                                     currency: currencyManager.selectedCurrency,
                                     rates: currencyManager.rates)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle(text: L10n.string("Insights"))

                if store.listState == .loading {
                    ListLoading().padding(.top, 24)
                } else if store.listState == .couldNotLoad {
                    ListCouldNotLoad().padding(.top, 24)
                } else if live.isEmpty {
                    empty.padding(.top, 24)
                } else {
                    Text(verbatim: sentence)
                        .font(.question(.title3, weight: .regular))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)

                    keyFiguresStrip.padding(.top, 16)

                    if PausePlanCard.isRelevant(plan: pausePlanStore.activePlan, subscriptions: store.subscriptions) {
                        Hairline().padding(.top, 24)
                        PausePlanCard()
                        Hairline()
                    }

                    // Order Insights around the person's stated focus (editable anytime in Settings → Notifications).
                    switch profile.goal {
                    case .watchAnnualAndHikes:
                        forecastSection
                        laterLargeSection
                        increasesSection
                        commitmentSection
                        simulatorSection
                        whatCostsMostSection
                        whereItGoesSection
                        overlapsSection
                        usageSection
                    case .cutUnused:
                        simulatorSection
                        overlapsSection
                        usageSection
                        forecastSection
                        whatCostsMostSection
                        commitmentSection
                        increasesSection
                        laterLargeSection
                        whereItGoesSection
                    case .rotateStreaming:
                        simulatorSection
                        forecastSection
                        overlapsSection
                        whatCostsMostSection
                        commitmentSection
                        increasesSection
                        laterLargeSection
                        whereItGoesSection
                        usageSection
                    case .catchTrials:
                        forecastSection
                        whatCostsMostSection
                        commitmentSection
                        simulatorSection
                        whereItGoesSection
                        increasesSection
                        overlapsSection
                        laterLargeSection
                        usageSection
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Layout.margin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .readableScroll()
        .inkScreen()
        .onAppear { profile = OnboardingProfile.load() }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingProfileDidChange)) { _ in
            profile = OnboardingProfile.load()
        }
        .sheet(isPresented: $showingPausePlan) { PausePlanView() }
        .sheet(isPresented: $showingDates) { RenewalDatesSheet(subscriptions: Horizon.undated(store.subscriptions)) }
        .sheet(item: $paywallPresentation) { item in
            StoreKitUpgradeView(context: item.context)
        }
        .sheet(isPresented: $showingSimulator, onDismiss: {
            if let id = pendingSimulatorSubscription {
                pendingSimulatorSubscription = nil
                VerdictCenter.shared.showSubscription(id)
            }
        }) {
            CutSimulatorSheet(
                subscriptions: store.subscriptions,
                candidates: cutCandidates,
                currency: currencyManager.selectedCurrency,
                rates: currencyManager.rates,
                onReviewSubscription: { id in pendingSimulatorSubscription = id }
            )
        }
        .sheet(item: $selectedOverlap, onDismiss: {
            if pendingPausePlanFromOverlap {
                pendingPausePlanFromOverlap = false
                showingPausePlan = true
            } else if let id = pendingOverlapSubscription {
                pendingOverlapSubscription = nil
                VerdictCenter.shared.showSubscription(id)
            }
        }) { group in
            let monthlyCount = group.subscriptions.filter { $0.billingFrequency == .monthly && !$0.isPausely }.count
            let canRotate = monthlyCount >= 2
            OverlapDetailSheet(
                group: group,
                currency: currencyManager.selectedCurrency,
                onSelect: { id in pendingOverlapSubscription = id },
                onRotateWithPausePlan: canRotate ? { pendingPausePlanFromOverlap = true } : nil
            )
        }
        .sheet(item: $loggingUsageFor) { sub in
            UsageInputSheet(subscriptionName: sub.name, currentMinutes: usageLog.getCurrentMonthUsage(for: sub)) { minutes in
                usageLog.setMonthlyUsage(minutes: minutes, for: sub)
            }
        }
    }

    // MARK: - Key Figures

    @ViewBuilder private var keyFiguresStrip: some View {
        let info = overview
        let monthly = MoneyFormat.total(info.monthlyTotal, currencyManager.selectedCurrency, converted: info.isConverted, locale: L10n.locale)
        let daily = MoneyFormat.total(info.dailyCost, currencyManager.selectedCurrency, converted: info.isConverted, locale: L10n.locale)

        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    metricCell(label: L10n.string("Each month"), value: monthly)
                    Hairline()
                    metricCell(label: L10n.string("Each day"), value: daily)
                    if let share = info.topThreeSharePercent {
                        let pct = (Double(share) / 100).formatted(.percent.precision(.fractionLength(0)).locale(L10n.locale))
                        Hairline()
                        metricCell(label: L10n.string("Top 3 share"), value: pct)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    metricCell(label: L10n.string("Each month"), value: monthly)
                    metricCell(label: L10n.string("Each day"), value: daily)
                    if let share = info.topThreeSharePercent {
                        let pct = (Double(share) / 100).formatted(.percent.precision(.fractionLength(0)).locale(L10n.locale))
                        metricCell(label: L10n.string("Top 3 share"), value: pct)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous).stroke(Color.line, lineWidth: 1))
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: label)
                .font(.caption)
                .foregroundStyle(Color.inkTextMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.inkText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - New Insights Sections

    private var forecastSection: some View {
        InsightsForecastCard(
            summary: forecast,
            currency: currencyManager.selectedCurrency,
            isUnlocked: paymentManager.isUnlocked(.spendForecast),
            onUnlock: { ctx in paywallPresentation = PaywallPresentation(context: ctx) },
            onAddDates: { showingDates = true },
            onSelectSubscription: { id in VerdictCenter.shared.showSubscription(id) }
        )
        .padding(.top, 20)
    }

    @ViewBuilder private var simulatorSection: some View {
        if let top = cutCandidates.first {
            CutSimulatorCard(
                topCandidate: top,
                currency: currencyManager.selectedCurrency,
                isUnlocked: paymentManager.isUnlocked(.spendForecast),
                canCombineMultiple: cutCandidates.count >= 2,
                onOpen: { showingSimulator = true }
            )
            .padding(.top, 24)
        }
    }

    @ViewBuilder private var commitmentSection: some View {
        if let mix = InsightsEngine.commitmentMix(for: store.subscriptions,
                                                  currency: currencyManager.selectedCurrency,
                                                  rates: currencyManager.rates),
           mix.flexibleCount > 0 && mix.committedCount > 0 {
            let flexText = MoneyFormat.total(mix.flexibleYearly, currencyManager.selectedCurrency,
                                             converted: mix.isConverted, locale: L10n.locale, wholeUnits: true)
            let commText = MoneyFormat.total(mix.committedYearly, currencyManager.selectedCurrency,
                                             converted: mix.isConverted, locale: L10n.locale, wholeUnits: true)
            section(L10n.string("Flexible vs. locked in")) {
                VStack(alignment: .leading, spacing: 10) {
                    GeometryReader { geo in
                        let usable = max(12, geo.size.width - 4)
                        let leadWidth = min(max(6, usable * mix.flexibleShare), usable - 6)
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous)
                                .fill(Color.inkText)
                                .frame(width: leadWidth)
                            RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous)
                                .fill(Color.decide)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 6)
                    .accessibilityHidden(true)

                    SideBySide(spacing: 12) {
                        Text(L10n.string("Monthly & shorter (\(mix.flexibleCount))"))
                            .font(.subheadline)
                            .foregroundStyle(Color.inkText)
                    } trailing: {
                        Text(L10n.string("\(flexText) a year"))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Color.inkText)
                    }
                    .accessibilityElement(children: .combine)

                    SideBySide(spacing: 12) {
                        Text(L10n.string("Quarterly & annual (\(mix.committedCount))"))
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                    } trailing: {
                        Text(L10n.string("\(commText) a year"))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Color.decide)
                    }
                    .accessibilityElement(children: .combine)
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Core Sections

    private var sentence: String {
        let yearly = MoneyFormat.string(live.annualTotal(), currencyManager.selectedCurrency, locale: L10n.locale, wholeUnits: true)
        guard let top = ranked.first else {
            return L10n.string("Your subscriptions cost about \(yearly) a year.")
        }
        return L10n.sentences([
            L10n.string("Your subscriptions cost about \(yearly) a year."),
            L10n.string("\(top.subscription.name) is the biggest, at \(MoneyFormat.total(top.monthly, currencyManager.selectedCurrency, converted: [top.subscription].isConverted(), locale: L10n.locale)) a month."),
        ])
    }

    private func fraction(_ amount: Decimal, of top: Decimal) -> Double {
        guard top > 0 else { return 0 }
        return min(max(NSDecimalNumber(decimal: amount / top).doubleValue, 0), 1)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: title)
                .font(.headline)
                .foregroundStyle(Color.inkText)
                .padding(.top, 32)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing to show yet.")
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
            Text("Add what you pay for and this page shows what costs most and what went up.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var whatCostsMostSection: some View {
        if !ranked.isEmpty {
            section(L10n.string("What costs most")) {
                let top = ranked.first?.monthly ?? 1
                ForEach(Array(ranked.prefix(6).enumerated()), id: \.element.subscription.id) { index, item in
                    if index > 0 { Hairline() }
                    Button {
                        Feel.selection()
                        VerdictCenter.shared.showSubscription(item.subscription.id)
                    } label: {
                        BarRow(title: item.subscription.name,
                               value: MoneyFormat.total(item.monthly, currencyManager.selectedCurrency,
                                                        converted: [item.subscription].isConverted()),
                               share: fraction(item.monthly, of: top))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var whereItGoesSection: some View {
        let categories = store.subscriptions.categoryTotals(in: currencyManager.selectedCurrency)
        if categories.count > 1 {
            section(L10n.string("Where it goes")) {
                let fitted = categories.fitted(to: 5)
                let top = fitted.map(\.amount).max() ?? 1
                ForEach(Array(fitted.enumerated()), id: \.element.id) { index, category in
                    if index > 0 { Hairline() }
                    BarRow(title: category.category == CategoryTotal.everythingElse
                                ? L10n.string("Everything else")
                                : SubscriptionCategory.localizedLabel(for: category.category),
                           value: MoneyFormat.total(category.amount, currencyManager.selectedCurrency,
                                                    converted: category.isConverted, locale: L10n.locale),
                           share: fraction(category.amount, of: top))
                }
            }
        }
    }

    @ViewBuilder private var increasesSection: some View {
        if !increases.isEmpty {
            section(L10n.string("What went up")) {
                ForEach(Array(increases.enumerated()), id: \.element.subscription.id) { index, item in
                    if index > 0 { Hairline() }
                    Button {
                        Feel.selection()
                        VerdictCenter.shared.showSubscription(item.subscription.id)
                    } label: {
                        MarkedWords(spacing: 12) {
                            StateMark(state: .due)
                        } words: {
                            AdaptiveRow {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: item.subscription.name)
                                        .font(.body)
                                        .foregroundStyle(Color.inkText)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(L10n.string("Up from \(MoneyFormat.string(item.from, item.subscription.currency)) since \(DayText.date(item.since, locale: L10n.locale))"))
                                        .font(.subheadline)
                                        .foregroundStyle(Color.inkTextMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } value: {
                                Text(verbatim: item.subscription.chargeText)
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(Color.inkText)
                            }
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder private var overlapsSection: some View {
        let overlaps = OverlapDetector.groups(in: store.subscriptions,
                                              currency: currencyManager.selectedCurrency,
                                              rates: currencyManager.rates)
        if !overlaps.isEmpty {
            section(L10n.string("Overlapping services")) {
                ForEach(Array(overlaps.enumerated()), id: \.element.id) { index, group in
                    if index > 0 { Hairline() }
                    Button {
                        Feel.selection()
                        selectedOverlap = group
                    } label: {
                        HStack(spacing: 10) {
                            AdaptiveRow {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: group.cluster.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.inkText)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(verbatim: group.subscriptions.map(\.name).formatted(.list(type: .and).locale(L10n.locale)))
                                        .font(.subheadline)
                                        .foregroundStyle(Color.inkTextMuted)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } value: {
                                VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                                    Text(verbatim: BillingFrequency.monthly.pricedShort(
                                        MoneyFormat.total(group.monthlyTotal, currencyManager.selectedCurrency,
                                                          converted: group.isConverted, locale: L10n.locale)))
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(Color.inkText)
                                        .accessibilityLabel(Text(verbatim: BillingFrequency.monthly.priced(
                                            MoneyFormat.total(group.monthlyTotal, currencyManager.selectedCurrency,
                                                              converted: group.isConverted, locale: L10n.locale))))
                                    Text(L10n.string("\(MoneyFormat.total(group.annualTotal, currencyManager.selectedCurrency, converted: group.isConverted, locale: L10n.locale)) a year"))
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(Color.inkTextFaint)
                                }
                            }
                            RowChevron()
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("overlapRow_\(group.cluster.rawValue)")
                }
            }
        }
    }

    @ViewBuilder private var laterLargeSection: some View {
        let laterLarge = Horizon.laterLargeRenewals(for: store.subscriptions, now: Date())
        if !laterLarge.isEmpty {
            section(L10n.string("Upcoming larger renewals")) {
                ForEach(Array(laterLarge.enumerated()), id: \.element.id) { index, charge in
                    if index > 0 { Hairline() }
                    Button {
                        Feel.selection()
                        VerdictCenter.shared.showSubscription(charge.subscriptionId)
                    } label: {
                        HStack(spacing: 10) {
                            AdaptiveRow {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: charge.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.inkText)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(verbatim: L10n.breakingAfterDots(DayText.date(charge.date, locale: L10n.locale) + " · " + L10n.relativeDay(charge.dayOffset)))
                                        .font(.subheadline)
                                        .foregroundStyle(Color.inkTextMuted)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } value: {
                                Text(verbatim: MoneyFormat.string(charge.amount, charge.currency, locale: L10n.locale))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(Color.inkText)
                            }
                            RowChevron()
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: - What the hours say

    @ViewBuilder private var usageSection: some View {
        let facts = UsageFacts.lines(for: store.subscriptions,
                                     minutesThisMonth: { usageLog.getUsage(for: $0)?.minutesUsed },
                                     currency: currencyManager.selectedCurrency, rates: currencyManager.rates)
        if facts.used.isEmpty && facts.unused.isEmpty {
            section(L10n.string("What an hour of use costs")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter how long you use a subscription on its page, and this page shows what an hour of it costs.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let top = ranked.first?.subscription {
                        Button {
                            Feel.selection()
                            loggingUsageFor = top
                        } label: {
                            Text("Log hours for \(top.name)")
                        }
                        .buttonStyle(.ink(.quiet))
                        .accessibilityIdentifier("insightsLogHoursButton")
                    }
                }
                .padding(.vertical, 8)
            }
        } else {
            if !facts.used.isEmpty {
                section(L10n.string("What an hour of use costs")) {
                    ForEach(Array(facts.used.enumerated()), id: \.element.id) { index, line in
                        if index > 0 { Hairline() }
                        usageRow(line,
                                 detail: L10n.string("This month") + ": " + Duration.seconds(line.minutes * 60)
                                    .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(L10n.locale)),
                                 value: line.costPerHour.map {
                                     L10n.string("\(MoneyFormat.total($0, currencyManager.selectedCurrency, converted: line.isConverted, locale: L10n.locale)) an hour")
                                 } ?? "")
                    }
                }
            }
            if !facts.unused.isEmpty {
                section(L10n.string("Not used this month")) {
                    ForEach(Array(facts.unused.enumerated()), id: \.element.id) { index, line in
                        if index > 0 { Hairline() }
                        usageRow(line, detail: nil,
                                 value: BillingFrequency.monthly.priced(MoneyFormat.total(line.monthly, currencyManager.selectedCurrency,
                                                                                         converted: line.isConverted, locale: L10n.locale)))
                    }
                }
            }
        }
    }

    private func usageRow(_ line: UsageFacts.Line, detail: String?, value: String) -> some View {
        Button {
            Feel.selection()
            VerdictCenter.shared.showSubscription(line.subscription.id)
        } label: {
            AdaptiveRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: line.subscription.name)
                        .font(.body)
                        .foregroundStyle(Color.inkText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(verbatim: detail)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } value: {
                Text(verbatim: value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Color.inkText)
                    .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
