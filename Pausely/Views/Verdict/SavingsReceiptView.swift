import SwiftUI

/// The Savings Receipt: one roll of paper. Each cancellation is a printed line with the charges it
/// avoided; the totals and the Pausely Promise are at the foot.
struct SavingsReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var storeManager = StoreKitManager.shared
    /// The three pictures for sharing, drawn when the receipt opens and again when it changes. They
    /// were drawn inside the screen's body: full-size renders on every pass.
    @State private var pictures: (withoutNames: Image?, whole: Image?, withoutAmounts: Image?) = (nil, nil, nil)
    @State private var showingPaywall = false

    private func proProof(for summary: SavingsSummary) -> PaywallCase.SavingsProof? {
        guard !paymentManager.isPremium, !summary.isEmpty,
              let annual = storeManager.product(for: .proAnnual) else { return nil }
        return PaywallCase.savingsProof(onTrack: summary.onTrack, summaryCurrency: summary.currency,
                                        isConverted: summary.totalsAreConverted, proYearly: annual.price,
                                        proCurrency: annual.priceFormatStyle.currencyCode,
                                        rates: currencyManager.rates)
    }

    var body: some View {
        let summary = SavingsSummary.current()
        let uncounted = SavingsLedger.uncounted(from: eventLog.events,
                                                excluding: Set(store.subscriptions.filter(\.isPausely).map(\.id)))
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
                    emptyState(uncounted: uncounted).padding(.top, 20)
                } else {
                    ReceiptRoll(summary: summary, privacy: .full).padding(.top, 20)
                    if !uncounted.isEmpty {
                        Text("Cancelled without a renewal day, so no charges could be counted: \(uncounted.formatted(.list(type: .and).locale(L10n.locale))).")
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                    }
                    if summary.excludedUnconvertibleCount > 0 {
                        Text(summary.excludedUnconvertibleCount == 1
                             ? L10n.string("1 cancellation is in a currency without an exchange rate and isn't included in the totals above.")
                             : L10n.string("\(summary.excludedUnconvertibleCount) cancellations are in currencies without an exchange rate and aren't included in the totals above."))
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }
                    if let image = pictures.withoutNames {
                        ShareLink(item: image,
                                  message: Text(verbatim: ShareSlipFooter.shareMessage),
                                  preview: SharePreview(L10n.string("Savings Receipt"), image: image)) {
                            Label(L10n.string("Share without service names"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.ink(.quiet))
                        .padding(.top, 14)
                        .accessibilityIdentifier("receiptShareBottomButton")
                    }
                    if let proof = proProof(for: summary) {
                        let multiple = proof.multiple.formatted(.number.precision(.fractionLength(1)).locale(L10n.locale))
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your cancellations already cover Pausely Pro \(multiple)× over.")
                                .font(.subheadline)
                                .foregroundStyle(Color.inkTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                            Button { showingPaywall = true } label: { Text("See Pausely Pro") }
                                .buttonStyle(.ink(.quiet))
                                .accessibilityIdentifier("receiptSeeProButton")
                        }
                        .padding(.top, 20)
                    }
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
        .sheet(isPresented: $showingPaywall) { StoreKitUpgradeView(context: PaywallContext(fromSavingsReceipt: true)) }
        .task { await storeManager.loadProducts() }
        .task(id: "\(eventLog.events.count)|\(store.subscriptions.count)|\(store.subscriptions.first(where: \.isPausely)?.amount ?? 0)|\(store.subscriptions.first(where: \.isPausely)?.status.rawValue ?? "")|\(currencyManager.selectedCurrency)|\(currencyManager.ratesDate.timeIntervalSince1970)|\(L10n.locale.identifier)|\(storeManager.products.count)") {
            let summary = SavingsSummary.current()
            pictures = summary.isEmpty ? (nil, nil, nil)
                : (ReceiptRoll.image(summary: summary, privacy: .hideNames),
                   ReceiptRoll.image(summary: summary, privacy: .full),
                   ReceiptRoll.image(summary: summary, privacy: .hideAmounts))
        }
    }

    // MARK: - Sharing

    private var shareMenu: some View {
        Menu {
            if let image = pictures.withoutNames {
                ShareLink(item: image,
                          message: Text(verbatim: ShareSlipFooter.shareMessage),
                          preview: SharePreview(L10n.string("Savings Receipt"), image: image)) {
                    Label(L10n.string("Share without service names"), systemImage: "person.fill.questionmark")
                }
            }
            if let image = pictures.whole {
                ShareLink(item: image,
                          message: Text(verbatim: ShareSlipFooter.shareMessage),
                          preview: SharePreview(L10n.string("Savings Receipt"), image: image)) {
                    Label(L10n.string("Share"), systemImage: "square.and.arrow.up")
                }
            }
            if let image = pictures.withoutAmounts {
                ShareLink(item: image,
                          message: Text(verbatim: ShareSlipFooter.shareMessage),
                          preview: SharePreview(L10n.string("Savings Receipt"), image: image)) {
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

    private func emptyState(uncounted: [String]) -> some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 10) {
                if uncounted.isEmpty {
                    Text("Your Savings Receipt starts with your first cancellation")
                        .font(.question(.title3))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Nothing counted yet")
                        .font(.question(.title3))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Cancelled without a renewal day, so no charges could be counted: \(uncounted.formatted(.list(type: .and).locale(L10n.locale))).")
                        .font(.subheadline)
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
    enum PrivacyMode: Equatable {
        case full
        /// Keeps the real dollar savings and Pausely Promise, redacting merchant names for privacy-safe sharing.
        case hideNames
        /// Keeps names and dates, hiding every amount.
        case hideAmounts
    }

    let summary: SavingsSummary
    let privacy: PrivacyMode
    var forSharing: Bool = false

    private var hideAmounts: Bool { privacy == .hideAmounts }
    private var hideNames: Bool { privacy == .hideNames }

    var body: some View {
        let reversed = Array(summary.lines.reversed().enumerated())
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 14) {
                Wordmark()

                ForEach(reversed, id: \.element.id) { index, line in
                    Perforation()
                    lineRow(line, index: index + 1)
                }

                Perforation()
                ProofLine(label: L10n.string("Kept since you cancelled"), value: amount(summary.savedSoFarText),
                          emphasised: true)
                    .foregroundStyle(Color.paperKept)
                ProofLine(label: L10n.string("On track over 12 months"), value: amount(summary.onTrackText))

                if !hideAmounts, summary.pauselyYearlyCost != nil || !summary.isEmpty {
                    Perforation()
                    PauselyPromiseCard(summary: summary)
                }
                if forSharing {
                    ShareSlipFooter()
                }
            }
        }
    }

    private func amount(_ text: String) -> String { hideAmounts ? "•••" : text }

    private func lineRow(_ line: SavingsLedger.Line, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let label = hideNames ? L10n.string("Subscription \(L10n.number(index))") : line.name
            ProofLine(label: label, value: amount(summary.formatted(line.savedSoFar, from: line.currency)),
                      emphasised: true)
            // Two lines of the roll, not one sentence: joined, the pair was too long for the roll
            // in every language and broke wherever the line ran out.
            Text(L10n.string("Cancelled on \(DayText.fullDate(line.cancelledOn, locale: L10n.locale))"))
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
    static func image(summary: SavingsSummary, privacy: PrivacyMode) -> Image? {
        let card = ReceiptRoll(summary: summary, privacy: privacy, forSharing: true)
            .frame(width: 360)
            .padding(24)
            .background(Color.ink)
            .environment(\.dynamicTypeSize, .large)
            .inTheAppsLanguage()
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map(Image.init(uiImage:))
    }
}
