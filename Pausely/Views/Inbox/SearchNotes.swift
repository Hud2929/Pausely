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
        UndoNote(message: Text("\(name) won't be shown again."), undoLabel: Text("Undo: show \(name) again"),
                 identifier: "undoHide", onUndo: onUndo)
    }
}

/// What a tap just changed, with "Undo" beside it, or under it at the accessibility text sizes (beside, the
/// words had a column a third wide and broke inside themselves).
struct UndoNote: View {
    let message: Text
    let undoLabel: Text
    let identifier: String
    let onUndo: () -> Void

    var body: some View {
        AdaptiveRow {
            message
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } value: {
            Button(action: onUndo) {
                Text("Undo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(undoLabel)
            .accessibilityIdentifier(identifier)
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
                // The first eight senders, in the order they were read: a new line fades in at the end and no
                // line ever moves. Put in at the top, the others moved down with each receipt and were drawn over
                // each other in eight of nine frames caught (the ratings of 2026-11-22 and 11-23).
                ForEach(shown) { receipt in
                    ProofLine(label: receipt.name, value: InboxImportView.money(receipt.amount, receipt.currency))
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
                    // The tap area inside the link: outside it, the link was its words, 100 by 18 points (2026-11-23).
                    Link(destination: policy) { Text("Privacy Policy").tapArea(.leading) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
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

/// Said once, with the way to change it: which dollar receipts that say only "$" are taken as. Shown on
/// each row, it repeated thirteen times and could not be changed (the rating of 2026-11-22).
struct DollarNote: View {
    let code: String
    let onChoose: (String) -> Void

    static let choices = ["USD", "CAD", "AUD", "NZD", "SGD", "HKD"]

    static func sentence(code: String, locale: Locale = L10n.locale) -> String {
        let name = locale.localizedString(forCurrencyCode: code) ?? code
        return L10n.string("Receipts that say only “$” are counted as \(name).")
    }

    var body: some View {
        // Under its sentence at the accessibility text sizes: beside it, "Receipts" broke as "Re-ceipts" (2026-11-23).
        AdaptiveRow {
            Text(verbatim: Self.sentence(code: code))
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } value: {
            Menu {
                ForEach(Self.choices, id: \.self) { choice in
                    Button { onChoose(choice) } label: {
                        if choice == code {
                            Label(L10n.locale.localizedString(forCurrencyCode: choice) ?? choice, systemImage: "checkmark")
                        } else {
                            Text(verbatim: L10n.locale.localizedString(forCurrencyCode: choice) ?? choice)
                        }
                    }
                }
            } label: {
                Text("Change")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Change which dollar"))
            .accessibilityIdentifier("dollarChoice")
        }
    }
}

/// Senders whose charges didn't look like subscriptions, by name on request: as a bare count it was a
/// number nobody could check (the rating of 2026-11-22).
struct OtherSenders: View {
    let count: Int
    let names: [String]
    /// Opens the form to add one by hand, with its name filled in: the names opened nothing, and "add it from
    /// the list by hand" pointed at no list (the rating of 2026-11-23).
    let onAdd: (String) -> Void
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(Motion.unlessReduced(Motion.touch)) { open.toggle() } } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Other senders with charges that didn't look like subscriptions: \(count)")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkTextMuted)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: Layout.tapTarget, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? Text("Shown") : Text("Hidden"))
            .accessibilityIdentifier("otherSenders")
            if open {
                Text("Their charges vary or say they're one-time. If one is a subscription, add it here.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(names, id: \.self) { name in
                        Button { onAdd(name) } label: {
                            HStack(spacing: 8) {
                                Text(verbatim: name)
                                    .font(.body)
                                    .foregroundStyle(Color.inkText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "plus")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.inkTextMuted)
                                    .accessibilityHidden(true)
                            }
                            .tapArea(.leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Add \(name) by hand"))
                        .accessibilityIdentifier("otherSender")
                    }
                }
            }
        }
    }
}

/// "Worth knowing": what the receipts say beyond the list (a price rise, a trial ending, a charge after a
/// cancellation), at most four, each with its state's colour and symbol.
struct FoundInsights: View {
    let insights: [IntelligenceInsight]

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Worth knowing")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    .padding(.bottom, 4)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    if index > 0 { Hairline() }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        StateMark(state: Self.state(for: insight.kind), symbol: Self.symbol(for: insight.kind))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(insight.detail)
                                .font(.subheadline)
                                .foregroundStyle(Color.inkTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// What each kind is, drawn: a renewal is a date, a rise goes up, a trial runs out. Each was a question mark,
    /// which read as doubt over facts the receipts state (the rating of 2026-11-23).
    static func symbol(for kind: IntelligenceInsight.Kind) -> String {
        switch kind {
        case .chargedAfterCancel, .paymentFailed: return "exclamationmark"
        case .priceIncrease, .priceChangeNotice: return "arrow.up"
        case .trialEnding: return "hourglass"
        case .renewalSoon: return "calendar"
        case .likelyEnded: return "pause.fill"
        }
    }

    static func state(for kind: IntelligenceInsight.Kind) -> MoneyState {
        switch kind {
        case .chargedAfterCancel, .paymentFailed: return .due
        case .priceIncrease, .priceChangeNotice, .trialEnding, .renewalSoon: return .decide
        case .likelyEnded: return .paused
        }
    }
}
