//
//  PriceHistoryView.swift
//  Pausely
//
//  What a subscription has cost over time: each price the person recorded, newest first.
//  Read from the event log (`PriceHistory`), the same record the Renewal Verdict and Insights use.
//

import SwiftUI

struct PriceHistoryView: View {
    let subscription: Subscription
    @ObservedObject private var eventLog = LifecycleEventLog.shared

    /// Oldest first, as recorded.
    private var history: [PriceHistory.Point] {
        PriceHistory.points(for: subscription.id, events: eventLog.events)
    }

    /// The day a price was recorded; "Earlier" for one from before Pausely kept its date.
    private func day(_ point: PriceHistory.Point, _ style: Date.FormatStyle) -> String {
        point.date.map { $0.formatted(style.locale(L10n.locale)) } ?? L10n.string("Earlier")
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
    private func summary(first: PriceHistory.Point, last: PriceHistory.Point) -> some View {
        let from = MoneyFormat.string(first.amount, first.currency)
        let to = MoneyFormat.string(last.amount, last.currency)
        let rose = last.amount > first.amount && last.currency == first.currency && last.frequency == first.frequency
        let sentence = first.date.map {
            L10n.string("\(from) in \($0.formatted(.dateTime.month(.abbreviated).year().locale(L10n.locale))), \(to) now.")
        } ?? L10n.string("\(from) before, \(to) now.")
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            if rose { StateMark(state: .decide).accessibilityHidden(true) }
            Text(verbatim: sentence)
                .font(.question(.title3))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ entry: PriceHistory.Point, previous: PriceHistory.Point?) -> some View {
        let date = day(entry, .dateTime.month(.abbreviated).day().year())
        var detail: String?
        if let previous, previous.currency == entry.currency, previous.frequency == entry.frequency, previous.amount != entry.amount {
            let difference = MoneyFormat.string(abs(entry.amount - previous.amount), entry.currency)
            detail = entry.amount > previous.amount ? L10n.string("\(difference) more than before") : L10n.string("\(difference) less than before")
        }
        return SettingsRow(title: date, detail: detail) {
            Text(verbatim: entry.frequency.priced(MoneyFormat.string(entry.amount, entry.currency)))
                .font(.proof(.body))
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
