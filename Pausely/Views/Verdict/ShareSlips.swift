import SwiftUI

/// Subtle website host printed only at the foot of exported Paper Slip PNGs, derived from
/// `AppConfig.websiteURL` so no domain is ever hardcoded in views.
struct ShareSlipFooter: View {
    private var host: String? {
        URL(string: AppConfig.websiteURL)?.host
    }

    static var shareMessage: String {
        L10n.string("Tracked with Pausely — \(AppConfig.websiteURL)")
    }

    var body: some View {
        if let host, !host.isEmpty {
            Perforation().padding(.top, 2)
            Text(verbatim: host)
                .font(.proof(.caption))
                .foregroundStyle(Color.paperMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// Privacy-safe Paper Slip rendered from the first-run Reveal: shows guessed vs. actual total
/// and subscription count without exposing individual service names.
struct GapShareSlip: View {
    let guessText: String
    let monthlyText: String
    let yearlyText: String
    let yearlyGapText: String?
    let subscriptionCount: Int
    let isApproximate: Bool

    var body: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 12) {
                Wordmark()
                let guessMonthly = BillingFrequency.monthly.pricedShort(guessText)
                let actualMonthly = BillingFrequency.monthly.pricedShort(monthlyText)
                Text(isApproximate
                     ? L10n.string("Guessed \(guessMonthly). About \(actualMonthly).")
                     : L10n.string("Guessed \(guessMonthly). Actually \(actualMonthly)."))
                    .font(.question(.title3, weight: .bold))
                    .foregroundStyle(Color.paperInk)
                    .fixedSize(horizontal: false, vertical: true)
                Perforation()
                ProofLine(label: L10n.string("Your guess"), value: guessText)
                    .foregroundStyle(Color.paperMuted)
                ProofLine(label: isApproximate ? L10n.string("Each month, about") : L10n.string("Each month"),
                          value: monthlyText, emphasised: true)
                ProofLine(label: isApproximate ? L10n.string("Each year, about") : L10n.string("Each year"),
                          value: yearlyText, emphasised: true)
                if let yearlyGapText {
                    Perforation()
                    ProofLine(label: L10n.string("More than guessed each year"), value: yearlyGapText, emphasised: true)
                        .foregroundStyle(Color.paperDue)
                }
                Perforation()
                ProofLine(label: L10n.string("Subscriptions"), value: L10n.number(subscriptionCount))
                ShareSlipFooter()
            }
        }
    }

    @MainActor
    static func image(guessText: String,
                      monthlyText: String,
                      yearlyText: String,
                      yearlyGapText: String?,
                      subscriptionCount: Int,
                      isApproximate: Bool) -> Image? {
        let card = GapShareSlip(
            guessText: guessText,
            monthlyText: monthlyText,
            yearlyText: yearlyText,
            yearlyGapText: yearlyGapText,
            subscriptionCount: subscriptionCount,
            isApproximate: isApproximate
        )
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

/// Privacy-safe torn Paper Slip for a single cancelled subscription win: highlights the 12-month
/// savings (plus cumulative Savings Receipt total when multiple subscriptions are cancelled)
/// without exposing the merchant's name.
struct CancelledShareSlip: View {
    let onTrackText: String
    var totalOnTrackText: String? = nil
    var isTrial: Bool = false

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 14) {
                Wordmark()
                Text(L10n.string("Cancelled"))
                    .font(.proof(.title3, weight: .bold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Color.paperInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous)
                        .stroke(Color.paperInk, lineWidth: 2))
                    .rotationEffect(.degrees(layoutDirection == .rightToLeft ? 4 : -4))
                Perforation()
                ProofLine(label: L10n.string("On track over 12 months"), value: onTrackText, emphasised: true)
                    .foregroundStyle(Color.paperKept)
                if let totalOnTrackText, totalOnTrackText != onTrackText {
                    ProofLine(label: L10n.string("Total Savings Receipt"), value: totalOnTrackText)
                        .foregroundStyle(Color.paperMuted)
                }
                Text(isTrial
                     ? L10n.string("1 free trial cancelled before it charged.")
                     : L10n.string("1 subscription cancelled before its next renewal."))
                    .font(.proof(.footnote))
                    .foregroundStyle(Color.paperMuted)
                    .fixedSize(horizontal: false, vertical: true)
                ShareSlipFooter()
            }
        }
    }

    @MainActor
    static func image(onTrackText: String, totalOnTrackText: String? = nil, isTrial: Bool = false) -> Image? {
        let card = CancelledShareSlip(onTrackText: onTrackText, totalOnTrackText: totalOnTrackText, isTrial: isTrial)
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

/// Quiet 1-tap Share button rendered on `.cancelled` outcomes when the cancellation has counted
/// 12-month savings. Caches the rendered PNG via `.task` so SwiftUI body passes stay fast.
struct ShareCancelledButton: View {
    let subscriptionId: UUID
    var identifier: String = "shareCancelledSavingsButton"

    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var image: Image?

    private var shareTotals: (line: String, cumulative: String?, isTrial: Bool)? {
        let summary = SavingsSummary.current()
        guard let line = summary.lines.last(where: {
            $0.subscriptionId == subscriptionId && $0.endedOn == nil && !$0.avoidedCharges.isEmpty
        }) else { return nil }
        let lineText = MoneyFormat.string(line.onTrack, line.currency)
        let cumulative = (summary.lines.count > 1 && summary.excludedUnconvertibleCount == 0 && summary.onTrack > 0) ? summary.onTrackText : nil
        let isTrial: Bool = {
            guard let sub = store.subscriptions.first(where: { $0.id == subscriptionId }),
                  let end = sub.trialEndsAt else { return false }
            return Calendar.billing.startOfDay(for: end) >= Calendar.billing.startOfDay(for: line.cancelledOn)
        }()
        return (lineText, cumulative, isTrial)
    }

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image,
                          message: Text(verbatim: ShareSlipFooter.shareMessage),
                          preview: SharePreview(L10n.string("Savings Receipt"), image: image)) {
                    Label(L10n.string("Share savings"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.ink(.quiet))
                .accessibilityIdentifier(identifier)
            }
        }
        .task(id: "\(subscriptionId.uuidString)|\(eventLog.events.count)|\(currencyManager.selectedCurrency)|\(currencyManager.ratesDate.timeIntervalSince1970)|\(L10n.locale.identifier)") {
            image = shareTotals.flatMap {
                CancelledShareSlip.image(onTrackText: $0.line, totalOnTrackText: $0.cumulative, isTrial: $0.isTrial)
            }
        }
    }
}
