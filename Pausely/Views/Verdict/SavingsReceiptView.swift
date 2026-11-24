import SwiftUI

/// The Savings Receipt: one roll of paper. Each cancellation is a printed line with the charges it
/// avoided; the totals and the Pausely Promise are at the foot.
struct SavingsReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    /// The two pictures for sharing, drawn when the receipt opens and again when it changes. They
    /// were drawn inside the screen's body: two full-size renders on every pass.
    @State private var pictures: (whole: Image?, withoutAmounts: Image?) = (nil, nil)

    var body: some View {
        let summary = SavingsSummary.current()
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton("Done") { dismiss() }
                    Spacer()
                    if !summary.isEmpty { shareMenu }
                }

                Text("Savings Receipt")
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)

                if summary.isEmpty {
                    emptyState.padding(.top, 20)
                } else {
                    ReceiptRoll(summary: summary, hideAmounts: false).padding(.top, 20)
                }

                howWeCount.padding(.top, 20)
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .readableScroll()
        .inkScreen()
        .preferredColorScheme(.dark)
        .task(id: "\(eventLog.events.count)|\(currencyManager.selectedCurrency)") {
            let summary = SavingsSummary.current()
            pictures = summary.isEmpty ? (nil, nil)
                : (ReceiptRoll.image(summary: summary, hideAmounts: false), ReceiptRoll.image(summary: summary, hideAmounts: true))
        }
    }

    // MARK: - Sharing

    private var shareMenu: some View {
        Menu {
            if let image = pictures.whole {
                ShareLink(item: image, preview: SharePreview(L10n.string("Savings Receipt"), image: image)) {
                    Label(L10n.string("Share"), systemImage: "square.and.arrow.up")
                }
            }
            if let image = pictures.withoutAmounts {
                ShareLink(item: image, preview: SharePreview(L10n.string("Savings Receipt"), image: image)) {
                    Label(L10n.string("Share without amounts"), systemImage: "eye.slash")
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inkText)
                .frame(width: Layout.tapTarget, height: Layout.tapTarget, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Share"))
        .accessibilityIdentifier("receiptShare")
    }

    private var emptyState: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Savings Receipt starts with your first cancellation")
                    .font(.question(.title3))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Before each renewal Pausely asks: keep it or cancel it? Every subscription you cancel shows up here with the charges it avoided.")
                    .font(.subheadline)
                    .foregroundStyle(Color.paperMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Perforation().padding(.vertical, 2)
                ProofLine(label: L10n.string("Kept since you cancelled"), value: SavingsSummary.current().formatted(0), emphasised: true)
            }
        }
    }

    private var howWeCount: some View {
        Text("How we count: only charges your renewal date and price say would have happened, for 12 months after you cancel. If a subscription starts again, its savings stop that day. Pausely's own subscription never counts.")
            .font(.footnote)
            .foregroundStyle(Color.inkTextFaint)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The printed roll. Also what is shared, so it draws nothing that needs the screen around it.
struct ReceiptRoll: View {
    let summary: SavingsSummary
    /// For sharing: the names and dates stay, every amount becomes dots.
    let hideAmounts: Bool

    var body: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 14) {
                Wordmark()

                ForEach(summary.lines.reversed()) { line in
                    Perforation()
                    lineRow(line)
                }

                Perforation()
                ProofLine(label: L10n.string("Kept since you cancelled"), value: amount(summary.total(summary.savedSoFar)),
                          emphasised: true)
                    .foregroundStyle(Color.paperKept)
                ProofLine(label: L10n.string("On track over 12 months"), value: amount(summary.total(summary.onTrack)))

                if !hideAmounts, summary.pauselyYearlyCost != nil || !summary.isEmpty {
                    Perforation()
                    PauselyPromiseCard()
                }
            }
        }
    }

    private func amount(_ text: String) -> String { hideAmounts ? "•••" : text }

    private func lineRow(_ line: SavingsLedger.Line) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ProofLine(label: line.name, value: amount(summary.formatted(line.savedSoFar, from: line.currency)),
                      emphasised: true)
            // Two lines of the roll, not one sentence: joined, the pair was too long for the roll
            // in every language and broke wherever the line ran out.
            Text(L10n.string("Cancelled on \(line.cancelledOn.formatted(.dateTime.month(.abbreviated).day().year().locale(L10n.locale)))"))
                .font(.proof(.caption))
                .foregroundStyle(Color.paperMuted)
                .fixedSize(horizontal: false, vertical: true)
            // What is counted, then the count: beside a noun, two figures need a plural pair in
            // every language ("1 prélèvements évités sur 12"; "1 of 1 charges" for a yearly plan).
            Text(L10n.string("Charges avoided so far: \(line.avoidedSoFar.count) of \(line.avoidedCharges.count)"))
                .font(.proof(.caption))
                .foregroundStyle(Color.paperMuted)
                .fixedSize(horizontal: false, vertical: true)
            if !hideAmounts, let next = line.avoidedCharges.first(where: { !line.avoidedSoFar.contains($0) }) {
                Text(L10n.string("Next avoided charge: \(MoneyFormat.string(line.amountPerCharge, line.currency)) on \(DayText.date(next, locale: L10n.locale))"))
                    .font(.proof(.caption))
                    .foregroundStyle(Color.paperMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let ended = line.endedOn {
                Text(L10n.string("Started again \(DayText.date(ended, locale: L10n.locale)). Savings stop there."))
                    .font(.proof(.caption))
                    .foregroundStyle(Color.paperDue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The roll as a picture on ink, for sharing.
    @MainActor
    static func image(summary: SavingsSummary, hideAmounts: Bool) -> Image? {
        let card = ReceiptRoll(summary: summary, hideAmounts: hideAmounts)
            .frame(width: 360)
            .padding(24)
            .background(Color.ink)
            .inTheAppsLanguage()
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map(Image.init(uiImage:))
    }
}
