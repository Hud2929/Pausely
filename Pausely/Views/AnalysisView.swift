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
    @ObservedObject private var usageLog = UsageLog.shared

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
                                   value: MoneyFormat.total(item.monthly, currencyManager.selectedCurrency,
                                                            converted: [item.subscription].isConverted()),
                                   share: fraction(item.monthly, of: top))
                        }
                    }

                    let categories = store.subscriptions.categoryTotals(in: currencyManager.selectedCurrency)
                    if categories.count > 1 {
                        section(L10n.string("Where it goes")) {
                            let top = categories.map(\.amount).max() ?? 1
                            ForEach(Array(categories.prefix(5).enumerated()), id: \.element.id) { index, category in
                                if index > 0 { Hairline() }
                                BarRow(title: SubscriptionCategory.localizedLabel(for: category.category),
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

                    usageSection
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.ink.ignoresSafeArea())
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
                                 value: MoneyFormat.total(line.monthly, currencyManager.selectedCurrency,
                                                          converted: line.isConverted, locale: L10n.locale) + L10n.string("/month"))
                    }
                }
            }
        }
    }

    private func usageRow(_ line: UsageFacts.Line, detail: String?, value: String) -> some View {
        Button { VerdictCenter.shared.showSubscription(line.subscription.id) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: line.subscription.name)
                        .font(.body)
                        .foregroundStyle(Color.inkText)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(verbatim: detail)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                Text(verbatim: value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Color.inkText)
                    .multilineTextAlignment(.trailing)
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
