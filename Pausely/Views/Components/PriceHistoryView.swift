//
//  PriceHistoryView.swift
//  Pausely
//
//  What a subscription has cost over time: each price the person recorded, newest first.
//

import SwiftUI

struct PriceHistoryView: View {
    let subscription: Subscription
    @ObservedObject private var tracker = PriceHistoryTracker.shared

    /// Oldest first, as recorded.
    private var history: [PriceHistoryEntry] {
        tracker.history(for: subscription.id).sorted { $0.date < $1.date }
    }

    var body: some View {
        SettingsPage(title: "Price history") {
            if history.count >= 2, let first = history.first, let last = history.last {
                summary(first: first, last: last)
                SettingsSection(title: "Each price") {
                    ForEach(Array(history.enumerated().reversed()), id: \.element.id) { index, entry in
                        row(entry, previous: index > 0 ? history[index - 1] : nil)
                    }
                }
            } else {
                Text("No price changes yet. When you change what \(subscription.name) costs, the old price and the new one are kept here.")
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("priceHistoryEmpty")
            }
        }
    }

    /// From what to what, since when: the one sentence the list adds up to.
    private func summary(first: PriceHistoryEntry, last: PriceHistoryEntry) -> some View {
        let since = first.date.formatted(.dateTime.month(.abbreviated).year().locale(L10n.locale))
        let from = MoneyFormat.string(first.amount, first.currency)
        let to = MoneyFormat.string(last.amount, last.currency)
        let rose = last.amount > first.amount && last.currency == first.currency
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            if rose { StateMark(state: .decide).accessibilityHidden(true) }
            Text(verbatim: L10n.string("\(from) in \(since), \(to) now."))
                .font(.question(.title3))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ entry: PriceHistoryEntry, previous: PriceHistoryEntry?) -> some View {
        let date = entry.date.formatted(.dateTime.month(.abbreviated).day().year().locale(L10n.locale))
        var detail: String?
        if let previous, previous.currency == entry.currency, previous.amount != entry.amount {
            let difference = MoneyFormat.string(abs(entry.amount - previous.amount), entry.currency)
            detail = entry.amount > previous.amount ? L10n.string("\(difference) more than before") : L10n.string("\(difference) less than before")
        }
        return SettingsRow(title: date, detail: detail) {
            Text(verbatim: MoneyFormat.string(entry.amount, entry.currency) + " " + entry.billingFrequency.billingPeriodLabel)
                .font(.proof(.body))
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
