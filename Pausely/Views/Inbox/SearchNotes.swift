import SwiftUI

/// What a search that found nothing (or was stopped, or failed) says: the outcome, then what was searched
/// and what to do next. The rating of 2026-11-22 found "nothing found" said neither over what period nor
/// that a subscription can be added by hand.
struct SearchOutcome: View {
    let message: String
    let stats: InboxScanner.ScanStats
    /// False when an inbox failed: its own row says why, and a count of what was checked would mislead.
    let explains: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: message)
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("searchOutcome")
            if explains {
                Group {
                    if stats.stopped {
                        Text("Emails checked before you stopped: \(stats.emailsChecked). Search again to read the rest.")
                    } else if stats.onlyNewMail {
                        Text("New emails checked since the last search: \(stats.emailsChecked). Receipts may go to another address: add that inbox too, or add your subscriptions by hand.")
                    } else {
                        Text("Emails checked from the last two years: \(stats.emailsChecked). Receipts may go to another address: add that inbox too, or add your subscriptions by hand.")
                    }
                }
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Says which finding "This isn't a subscription" hid, with the way back: one tap meant for the row's
/// box hid a real subscription for good (the rating of 2026-11-22).
struct HiddenNote: View {
    let name: String
    let onUndo: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(name) won't be shown again.")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Undo: show \(name) again"))
            .accessibilityIdentifier("undoHide")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The search, as it happens: each receipt read is printed on the slip, so the wait shows its work.
struct ReceiptsSeenSlip: View {
    let receipts: [ReceiptSeen]

    var body: some View {
        let shown = Array(receipts.prefix(8))
        let more = receipts.count - shown.count
        return PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Receipts read so far")
                    .font(.proof(.caption))
                    .foregroundStyle(Color.paperMuted)
                ForEach(shown) { receipt in
                    ProofLine(label: receipt.name, value: InboxImportView.money(receipt.amount, receipt.currency))
                        .transition(.arriving(.move(edge: .top)))
                }
                if more > 0 {
                    Text("and \(more) more")
                        .font(.proof(.caption))
                        .foregroundStyle(Color.paperMuted)
                }
            }
            .animation(Motion.unlessReduced(Motion.arrive), value: receipts.count)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("receiptsSlip")
    }
}
