import SwiftUI

/// What was added from a mailbox: exactly what happened to each one, whether it was added, is waiting
/// for a place, or was already on the list. Nothing is dropped unsaid.
struct InboxOutcome: View {
    let outcome: TallyImporter.Outcome
    /// The person's list after the add, for the slip: three lines on an empty page didn't say what the
    /// add came to (the rating of 2026-11-23).
    let list: [Subscription]
    let onDone: () -> Void
    let onSeePro: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("importOutcomeTitle")

            if !outcome.added.isEmpty || !outcome.waiting.isEmpty { slip }

            VStack(alignment: .leading, spacing: 0) {
                if !outcome.added.isEmpty {
                    line(L10n.string("Each one now shows its next charge on Home."), names: outcome.added)
                }
                if !outcome.waiting.isEmpty {
                    if !outcome.added.isEmpty { Hairline() }
                    // Where they are said too: they could only be found again inside Find in Email (2026-11-23).
                    line(L10n.string("Waiting for room: \(outcome.waiting.count). Free tracks \(FreeTier.subscriptionLimit); Pausely Pro tracks all of them. Home shows them until then."),
                                names: outcome.waiting)
                        .accessibilityIdentifier("importWaitingLine")
                }
                if !outcome.alreadyListed.isEmpty {
                    if !outcome.added.isEmpty || !outcome.waiting.isEmpty { Hairline() }
                    line(outcome.datesFilled.isEmpty
                                ? L10n.string("Already on your list: \(outcome.alreadyListed.count).")
                                : L10n.string("Already on your list: \(outcome.alreadyListed.count). Missing renewal dates were filled in from your emails."),
                                names: outcome.alreadyListed)
                }
            }

            VStack(spacing: 10) {
                Button(action: onDone) { Text("Done") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("importDoneButton")
                if !outcome.waiting.isEmpty {
                    Button(action: onSeePro) { Text("See Pausely Pro") }
                        .buttonStyle(.ink(.quiet))
                        .accessibilityIdentifier("importSeeProButton")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One subscription is named; several are counted.
    private var title: String {
        switch outcome.added.count {
        // Everything waits when the free list is full: said as that, not as nothing having happened. The count
        // is the line's under it: said in both, it was read twice (2026-11-23).
        case 0 where !outcome.waiting.isEmpty: return L10n.string("Your list is full")
        case 0: return L10n.string("Nothing new was added")
        case 1: return L10n.string("\(outcome.added[0]) is on your list")
        default: return L10n.string("\(outcome.added.count) added to your list")
        }
    }

    /// What was added comes to, what waits for room, and the list with them, in the display currency.
    private var slip: some View {
        let currency = CurrencyManager.shared.selectedCurrency
        let rates = CurrencyManager.shared.rates
        let charging = list.charging
        let added = charging.filter { sub in outcome.added.contains { ServiceName.same($0, sub.name) } }
        let waiting = TallyImporter.waitingLines().filter { line in outcome.waiting.contains { ServiceName.same($0, line.name) } }
        let waitingMonthly = MoneyMath.total(waiting, in: currency, rates: rates, amount: { $0.yearlyCost / 12 }, currencyOf: \.currency)
        let foreign: (Subscription) -> Bool = { MoneyFormat.normalizedCode($0.currency) != MoneyFormat.normalizedCode(currency) }
        let converted = charging.contains(where: foreign)
        let listMonthly = charging.monthlyTotal(in: currency, rates: rates)
        return PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 10) {
                if !added.isEmpty {
                    ProofLine(label: L10n.string("Just added, each month"),
                              value: MoneyFormat.total(added.monthlyTotal(in: currency, rates: rates), currency, converted: added.contains(where: foreign)))
                }
                // What the full list leaves out, from the person's own receipts: what Pro would watch.
                if !waiting.isEmpty {
                    ProofLine(label: L10n.string("Waiting for room, each month"),
                              value: MoneyFormat.total(waitingMonthly, currency,
                                                       converted: waiting.contains { MoneyFormat.normalizedCode($0.currency) != MoneyFormat.normalizedCode(currency) }))
                }
                Perforation()
                ProofLine(label: L10n.string("Your list, each month"), value: MoneyFormat.total(listMonthly, currency, converted: converted),
                          emphasised: true)
                ProofLine(label: L10n.string("Your list, each year"), value: MoneyFormat.total(listMonthly * 12, currency, converted: converted))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("importOutcomeSlip")
    }

    private func line(_ sentence: String, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: sentence)
                .font(.body)
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: names.formatted(.list(type: .and).locale(L10n.locale)))
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
