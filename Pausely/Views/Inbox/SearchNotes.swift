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
                        // Fades in place: sliding in at the top while the others moved down, the rows were
                        // drawn over each other in every frame caught (the rating of 2026-11-22).
                        .transition(.opacity)
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

/// What Find in Email promises about the mail, before any inbox is connected: read on this iPhone, a few
/// facts kept, never the email; what reaches the account; and the policy itself.
struct InboxPrivacyNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline()
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                Text("Your email never leaves your iPhone.")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                // What is kept, said as it is: "only the name, amount and date" was narrower than the
                // facts kept (the ratings of 2026-11-22). And what reaches the account once added.
                Text("Pausely connects straight to your email provider and reads receipts on this iPhone. It keeps a few facts from each (who charged, how much, when, how often), never the email itself. It only reads: it never sends, changes or deletes email.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Subscriptions you add go to your account, like any you type in.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                }
                // The words are read as one; the link is a stop of its own. Combined with them, the
                // whole block was one 60-word button and "Privacy Policy" only an action (2026-11-22).
                .accessibilityElement(children: .combine)
                if let policy = URL(string: AppConfig.privacyPolicyURL) {
                    Link(destination: policy) { Text("Privacy Policy") }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(minHeight: Layout.tapTarget, alignment: .leading)
                        .accessibilityIdentifier("inboxPrivacyPolicy")
                }
            }
            .padding(.vertical, 16)
            Hairline()
        }
    }
}

/// What a main button says while its work runs: a spinner alone drew as a blank paper button on iOS 26,
/// whose tint it ignored (the rating of 2026-11-22).
struct Busy: View {
    let words: Text
    init(_ words: Text) { self.words = words }

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().progressViewStyle(.circular).tint(Color.paperInk)
            words
        }
    }
}

/// What the person said isn't a subscription, each with the way to show it again.
struct HiddenList: View {
    let findings: [FoundSubscription]
    let onShow: (FoundSubscription) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hidden")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .accessibilityAddTraits(.isHeader)
                Text("You said these aren't subscriptions")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(findings) { found in
                HStack(spacing: 12) {
                    Text(verbatim: found.name)
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { onShow(found) } label: {
                        Text("Show again")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Show \(found.name) again"))
                }
                Hairline()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
