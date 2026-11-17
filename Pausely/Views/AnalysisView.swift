//
//  AnalysisView.swift
//  Pausely
//
//  Insights: one sentence about the whole list, then what costs most, where it goes, what went up,
//  and what the hours the person typed say.
//

import SwiftUI

struct AnalysisView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var pausePlanStore = PausePlanStore.shared
    @ObservedObject private var usageLog = UsageLog.shared
    @Environment(\.dynamicTypeSize) private var typeSize

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

                    section(L10n.string("What costs most")) {
                        let top = ranked.first?.monthly ?? 1
                        ForEach(Array(ranked.prefix(6).enumerated()), id: \.element.subscription.id) { index, item in
                            if index > 0 { Hairline() }
                            BarRow(title: item.subscription.name,
                                   value: MoneyFormat.total(item.monthly, currencyManager.selectedCurrency,
                                                            converted: [item.subscription].isConverted()),
                                   share: fraction(item.monthly, of: top))
                        }
                    }

                    let categories = store.subscriptions.categoryTotals(in: currencyManager.selectedCurrency)
                    if categories.count > 1 {
                        section(L10n.string("Where it goes")) {
                            let top = categories.map(\.amount).max() ?? 1
                            ForEach(Array(categories.fitted(to: 5).enumerated()), id: \.element.id) { index, category in
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

                    if !increases.isEmpty {
                        section(L10n.string("What went up")) {
                            ForEach(Array(increases.enumerated()), id: \.element.subscription.id) { index, item in
                                if index > 0 { Hairline() }
                                // Mark, name and price side by side; at the accessibility
                                // text sizes one under the other. Side by side there the name
                                // was hyphenated ("Spoti-fy") and the price broke at its point.
                                MarkedWords(spacing: 12) {
                                    StateMark(state: .due)
                                } words: {
                                    AdaptiveRow {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(verbatim: item.subscription.name)
                                                .font(.body)
                                                .foregroundStyle(Color.inkText)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(L10n.string("Up from \(MoneyFormat.string(item.from, item.subscription.currency)) since \(item.since.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale)))"))
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
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }

                    if PausePlanCard.isRelevant(plan: pausePlanStore.activePlan, subscriptions: store.subscriptions) {
                        Hairline().padding(.top, 28)
                        PausePlanCard()
                        Hairline()
                    }

                    usageSection
                }
            }
            // A scroll view is only as wide as what it holds: with two short lines (the empty state)
            // it shrank, sat in the middle and left the navigation stack's black on either side.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Layout.margin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .inkScreen()
    }

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

    // MARK: - What the hours say

    /// What an hour of use cost, and what wasn't used, from the hours the person typed this month
    /// (`UsageFacts`). Until they have typed any, one line says where to.
    @ViewBuilder private var usageSection: some View {
        let facts = UsageFacts.lines(for: store.subscriptions,
                                     minutesThisMonth: { usageLog.getUsage(for: $0.name)?.minutesUsed },
                                     currency: currencyManager.selectedCurrency, rates: currencyManager.rates)
        if facts.used.isEmpty && facts.unused.isEmpty {
            section(L10n.string("What an hour of use costs")) {
                Text("Enter how long you use a subscription on its page, and this page shows what an hour of it costs.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
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
            // Side by side; at the accessibility text sizes the cost goes under the words. Beside
            // them it took a third of the row ("$6.85", "an", "hour" on three lines) and the
            // words took what was left ("This", "month:", "2 hrs,", "20 mins").
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

/// A ranked row: a name, an amount, and a bar showing its size against the largest.
private struct BarRow: View {
    let title: String
    let value: String
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SideBySide(spacing: 12) {
                Text(verbatim: title)
                    .font(.body)
                    .foregroundStyle(Color.inkText)
            } trailing: {
                Text(verbatim: value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Color.inkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.track).frame(height: 3)
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
