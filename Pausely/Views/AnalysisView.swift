//
//  AnalysisView.swift
//  Pausely
//
//  Insights: one sentence about the whole list, then what costs most, where it goes, what went up,
//  and (Pro) the deep analysis.
//

import SwiftUI

struct AnalysisView: View {
    @ObservedObject private var insightsEngine = RealInsightsEngine.shared
    @ObservedObject private var geniusEngine = RealGeniusEngine.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared

    @State private var deep: DeepState = .idle
    @State private var showingPaywall = false

    private enum DeepState {
        case idle, analyzing, results(GeniusReport), nothing, failed(String)
    }

    private var canAnalyze: Bool { paymentManager.isUnlocked(.deepAnalysis) }

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
            guard let change = VerdictFacts.priceChange(for: sub.id, currentAmount: sub.amount, events: eventLog.events),
                  sub.amount > change.from else { return nil }
            return (sub, change.from, change.since)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Insights")
                    .font(.question(.largeTitle, weight: .bold))
                    .foregroundStyle(Color.inkText)
                    .accessibilityAddTraits(.isHeader)

                if live.isEmpty {
                    empty.padding(.top, 24)
                } else {
                    Text(verbatim: sentence)
                        .font(.question(.title3, weight: .regular))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)

                    section(L10n.string("What costs most")) {
                        let top = ranked.first?.monthly ?? 1
                        ForEach(Array(ranked.prefix(6).enumerated()), id: \.element.subscription.id) { index, item in
                            if index > 0 { Hairline() }
                            BarRow(title: item.subscription.name,
                                   value: currencyManager.format(item.monthly),
                                   share: fraction(item.monthly, of: top))
                        }
                    }

                    if insightsEngine.categoryBreakdown.count > 1 {
                        section(L10n.string("Where it goes")) {
                            let top = insightsEngine.categoryBreakdown.map(\.amount).max() ?? 1
                            ForEach(Array(insightsEngine.categoryBreakdown.prefix(5).enumerated()), id: \.element.id) { index, category in
                                if index > 0 { Hairline() }
                                BarRow(title: SubscriptionCategory.label(for: category.category),
                                       value: MoneyFormat.string(category.amount, currencyManager.selectedCurrency, locale: L10n.locale),  // money-guard: category totals are already in the display currency
                                       share: fraction(category.amount, of: top))
                            }
                        }
                    }

                    if !increases.isEmpty {
                        section(L10n.string("What went up")) {
                            ForEach(Array(increases.enumerated()), id: \.element.subscription.id) { index, item in
                                if index > 0 { Hairline() }
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    StateMark(state: .due)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(verbatim: item.subscription.name)
                                            .font(.body)
                                            .foregroundStyle(Color.inkText)
                                        Text(L10n.string("Up from \(MoneyFormat.string(item.from, item.subscription.currency)) since \(item.since.formatted(.dateTime.month(.abbreviated).day()))"))
                                            .font(.subheadline)
                                            .foregroundStyle(Color.inkTextMuted)
                                    }
                                    Spacer(minLength: 8)
                                    Text(verbatim: item.subscription.chargeText)
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(Color.inkText)
                                }
                                .padding(.vertical, 12)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }

                    if PausePlanCard.isRelevant() {
                        Hairline().padding(.top, 28)
                        PausePlanCard()
                        Hairline()
                    }

                    deepSection
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.ink.ignoresSafeArea())
        .task(id: store.subscriptions.count) {
            await insightsEngine.analyze(subscriptions: store.subscriptions)
            if canAnalyze, !store.subscriptions.isEmpty, case .idle = deep { await runDeepAnalysis() }
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
    }

    private var sentence: String {
        let yearly = MoneyFormat.string(live.annualTotal(), currencyManager.selectedCurrency, locale: L10n.locale, wholeUnits: true)
        guard let top = ranked.first else {
            return L10n.string("Your subscriptions cost about \(yearly) a year.")
        }
        return L10n.string("Your subscriptions cost about \(yearly) a year.") + " "
            + L10n.string("\(top.subscription.name) is the biggest, at \(currencyManager.format(top.monthly)) a month.")
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

    // MARK: - Deep analysis (Pro)

    @ViewBuilder private var deepSection: some View {
        section(L10n.string("Deep savings analysis")) {
            if !canAnalyze {
                Text("Pro looks for duplicates, unused subscriptions and trials about to charge.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
                Button { showingPaywall = true } label: { Text("See Pro") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("insightsSeePro")
            } else {
                switch deep {
                case .idle, .analyzing:
                    HStack(spacing: 10) {
                        ProgressView().tint(Color.inkTextMuted)
                        Text("Analyzing…").font(.subheadline).foregroundStyle(Color.inkTextMuted)
                    }
                    .padding(.vertical, 12)
                case .nothing:
                    Text("Nothing to cut right now. Pausely will keep asking before each renewal.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 8)
                case .failed(let message):
                    Text(verbatim: message)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 8)
                    Button { Task { await runDeepAnalysis() } } label: { Text("Try Again") }
                        .buttonStyle(.ink(.quiet))
                case .results(let report):
                    ForEach(Array(report.insights.prefix(8).enumerated()), id: \.element.id) { index, insight in
                        if index > 0 { Hairline() }
                        insightRow(insight)
                    }
                }
            }
        }
    }

    private func insightRow(_ insight: GeniusInsight) -> some View {
        Button {
            if let id = insight.subscriptionId { VerdictCenter.shared.showSubscription(id) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: insight.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .multilineTextAlignment(.leading)
                    Text(verbatim: insight.description)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .multilineTextAlignment(.leading)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if insight.potentialSavings > 0 {
                    Text(verbatim: currencyManager.format(insight.potentialSavings) + L10n.string("/month"))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.inkText)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(insight.subscriptionId == nil)
        .accessibilityElement(children: .combine)
    }

    private func runDeepAnalysis() async {
        deep = .analyzing
        guard !store.subscriptions.isEmpty else { deep = .nothing; return }
        do {
            let report = try await geniusEngine.analyze(subscriptions: store.subscriptions)
            deep = report.insights.isEmpty ? .nothing : .results(report)
        } catch is CancellationError {
            // Restarted by .task(id:): go back to idle so the next run starts.
            if case .analyzing = deep { deep = .idle }
        } catch {
            deep = .failed(error.localizedDescription)
        }
    }
}

/// A ranked row: a name, an amount, and a bar showing its size against the largest.
private struct BarRow: View {
    let title: String
    let value: String
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: title)
                    .font(.body)
                    .foregroundStyle(Color.inkText)
                Spacer(minLength: 12)
                Text(verbatim: value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Color.inkText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 3)
                    Capsule().fill(Color.inkText).frame(width: max(3, geo.size.width * share), height: 3)
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
