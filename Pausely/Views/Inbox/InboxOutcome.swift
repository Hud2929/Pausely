import SwiftUI

/// What was added from a mailbox: exactly what happened to each one, whether it was added, is waiting
/// for a place, or was already on the list. Nothing is dropped unsaid.
struct InboxOutcome: View {
    let outcome: TallyImporter.Outcome
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

            VStack(alignment: .leading, spacing: 0) {
                if !outcome.added.isEmpty {
                    line(L10n.string("Each one now shows its next charge on Home."), names: outcome.added)
                }
                if !outcome.waiting.isEmpty {
                    if !outcome.added.isEmpty { Hairline() }
                    line(L10n.string("Waiting: \(outcome.waiting.count). Free tracks \(FreeTier.subscriptionLimit); Pausely Pro tracks all of them."),
                                names: outcome.waiting)
                        .accessibilityIdentifier("importWaitingLine")
                }
                if !outcome.alreadyListed.isEmpty {
                    if !outcome.added.isEmpty || !outcome.waiting.isEmpty { Hairline() }
                    line(outcome.datesFilled.isEmpty
                                ? L10n.string("Already on your list: \(outcome.alreadyListed.count).")
                                : L10n.string("Already on your list: \(outcome.alreadyListed.count). Missing renewal dates were filled in from your receipts."),
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
        case 0: return L10n.string("Nothing new was added")
        case 1: return L10n.string("\(outcome.added[0]) is on your list")
        default: return L10n.string("\(outcome.added.count) added to your list")
        }
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
