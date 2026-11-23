import SwiftUI

/// One found subscription on the results list of Find in Email: its name, what proves it, its
/// price, and a box to choose it.
struct FoundRow: View {
    let found: FoundSubscription
    /// The widest price on the page. Each row sets its own price over a copy of it that is not
    /// drawn, so the price has the same column in every row and every row makes the same choice
    /// between beside the words and under them. By its own width, "34,99 CA$" went under and
    /// "9,99 CA$" stayed beside, row by row (German and Arabic tours, 2026-11-16).
    var widestPrice: Price? = nil
    /// Already a subscription in the person's list (same name): shown so they see it was found, never
    /// offered again. A second search ticked them and counted them in "Add 3 to my list", and the
    /// import then quietly left them out.
    var isOnList: Bool = false
    /// Waiting for room on the free list from an earlier add.
    var isWaiting: Bool = false
    /// The price on the list, when it differs from the receipts'.
    var listedPrice: String? = nil
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void
    let onReject: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    /// The box grows with the tick inside it (at the largest text size the tick was twice as
    /// wide as a fixed box).
    @ScaledMetric(relativeTo: .caption2) private var boxSide: CGFloat = 22

    private var proven: ProvenSubscription { found.proven }

    private var badge: (text: String, state: MoneyState?)? {
        if isWaiting, !found.isCancelled { return (L10n.string("Waiting for room on your list"), nil) }
        if isOnList, !found.isCancelled {
            return (listedPrice.map { L10n.string("On your list at \($0)") } ?? L10n.string("On your list"), nil)
        }
        switch proven.status {
        case .priceIncreased: return (L10n.string("Price went up"), .decide)
        case .trial: return (L10n.string("Free trial"), .decide)
        // These rows sit under a heading that says it ("May have ended", "Cancelled"); a tag repeated it.
        case .likelyEnded, .cancelled: return nil
        case .active: return proven.chargedAfterCancel ? (L10n.string("Charged after a cancellation email"), .due) : nil
        }
    }

    private var evidenceLine: String { Self.evidence(for: proven) }

    /// What a trial costs afterwards when its email didn't say: the usual price where the catalog has it in
    /// the reader's currency, or that the email doesn't say. A trial row with no price at all left the person
    /// to guess (A10, 2026-11-22).
    static func afterTrial(for found: FoundSubscription, currency: String = CurrencyManager.shared.selectedCurrency) -> String? {
        guard found.priceUnknown else { return nil }
        if let usual = TallyCatalog.price(forServiceNamed: found.name, payingIn: currency) {
            return L10n.string("Usually \(found.billingFrequency.priced(MoneyFormat.string(usual, currency))) after the trial")
        }
        return L10n.string("The email doesn't say what it costs after the trial")
    }

    /// The listed price, when it isn't what the receipts show: adding never changes what the person
    /// entered, so the difference is said on the row (T9).
    static func listedPrice(_ listed: Subscription?, for found: FoundSubscription) -> String? {
        guard let listed else { return nil }
        let same = MoneyFormat.normalizedCode(listed.currency) == MoneyFormat.normalizedCode(found.currency)
            && listed.amount == (found.proven.comingAmount ?? found.amount)
            && listed.billingFrequency == found.billingFrequency
        return same ? nil : listed.billingFrequency.priced(listed.chargeText)
    }

    /// Why a row is only worth a look; nothing for a confirmed one, a trial, or one that ended.
    static func doubt(for proven: ProvenSubscription) -> String? {
        guard proven.tier < .confirmed, proven.status == .active || proven.status == .priceIncreased else { return nil }
        return proven.doubt
    }

    /// The line under a found subscription's name: when its trial ends, when it was last charged
    /// (with the year when that isn't this year), or when it started if it is known from a sign-up.
    static func evidence(for proven: ProvenSubscription, now: Date = Date()) -> String {
        // A day and its month stay on one line: beside the price, one text size up, the line
        // read "Last", "charged Nov", "10".
        let day: (Date) -> String = { L10n.day($0, now: now) }
        // Worked out from the email's date, so "around", never a day stated as fact.
        if proven.status == .trial, let ends = proven.trialEndsOn { return L10n.string("Trial ends around \(day(ends))") }
        // Never a day after today: a receipt's clock can run ahead of the phone's ("last charged Nov 23" on
        // Nov 22, the rating of 2026-11-22).
        if let last = proven.lastChargeDate.map({ day(min($0, now)) }) { return L10n.string("Last charged \(last)") }
        // Known from its sign-up (a channel that emails no receipts, a trial that turned paid): when it
        // started, never "Last charged", which said a sign-up was the latest charge.
        if let started = proven.subscribedOn.map(day) {
            return proven.startedWithTrial ? L10n.string("Trial started on \(started)") : L10n.string("Subscribed on \(started)")
        }
        return L10n.string("Detected from your emails")
    }

    private var priceText: String? {
        found.priceUnknown ? nil : InboxImportView.money(found.amount, found.currency)
    }

    private var accessibilitySummary: String {
        var parts = [found.name]
        if let priceText { parts.append(found.billingFrequency.priced(priceText)) }
        parts.append(evidenceLine)
        if let doubt = Self.doubt(for: proven) { parts.append(doubt) }
        if let afterTrial = Self.afterTrial(for: found) { parts.append(afterTrial) }
        if let badge { parts.append(badge.text) }
        // Chosen or not is the button's Selected trait, which VoiceOver says; the word said it twice.
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if Self.wordsHaveTheWholeRow(largeText: typeSize.isAccessibilitySize) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            // The box is a second place to tap; the words under it say what it is.
                            if Self.isAChoice(cancelled: found.isCancelled, onList: isOnList) {
                                Button(action: onToggle) { checkbox }
                                    .buttonStyle(.plain)
                                    .accessibilityHidden(true)
                            }
                            Spacer(minLength: 8)
                            whyButton
                        }
                        choose {
                            VStack(alignment: .leading, spacing: 4) { nameAndEvidence; price }
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // The row is read before its "why", which sits above it here (2026-11-22).
                        .accessibilitySortPriority(1)
                    }
                } else {
                    HStack(spacing: 8) {
                        choose {
                            HStack(spacing: 12) {
                                // A cancelled row keeps the box's place empty: its logo and words line
                                // up with the rows above, and it has the same width for its price.
                                if Self.isAChoice(cancelled: found.isCancelled, onList: isOnList) { checkbox } else { Color.clear.frame(width: boxSide, height: boxSide).accessibilityHidden(true) }
                                ServiceLogoView(name: found.name, category: nil, size: 36)
                                // As on the Subscriptions list: the price keeps its width, 8 points
                                // from the words (a spacer between them took 32, and "Last charged
                                // Nov 9" broke in two for want of 4). This row also holds a box and
                                // a chevron, so the price goes under the words sooner: beside them
                                // only while it takes no more than a third of what is left.
                                LineOrStack(spacing: 8, lineSpacing: 4, spread: true, besideShare: Self.priceShare, stacksWideValue: true) {
                                    nameAndEvidence
                                    price
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        whyButton
                    }
                }
            }
            .padding(.vertical, 10)

            if isExpanded { evidenceDetail.id("why-\(found.id)") }
        }
    }

    /// The most of the row's width the price may take while the words wrap beside it.
    nonisolated static let priceShare: CGFloat = 0.35

    /// A price as the row draws it: the amount, and how often under it.
    struct Price: Equatable {
        var amount: String
        var period: String
    }

    /// The widest of these prices: the longest amount over the longest period. Counted in
    /// characters, which is near enough for one column (the digits of a price are of a width).
    nonisolated static func widestPrice(among prices: [Price]) -> Price? {
        guard let amount = prices.map(\.amount).max(by: { $0.count < $1.count }),
              let period = prices.map(\.period).max(by: { $0.count < $1.count }) else { return nil }
        return Price(amount: amount, period: period)
    }

    /// Whether the name, what was found and the price run the width of the row, with the box and
    /// the way to "why" on a line above them. At the accessibility text sizes, yes: between the
    /// box, the logo and the chevron the words had a third of the row, and broke inside
    /// themselves ("Spoti-fy", "Last charge" above "d Nov 8").
    nonisolated static func wordsHaveTheWholeRow(largeText: Bool) -> Bool { largeText }

    /// Whether the row is something to choose. One that was cancelled is not: it is shown so the
    /// person knows it was seen, and there is nothing to add.
    nonisolated static func isAChoice(cancelled: Bool, onList: Bool = false) -> Bool { !cancelled && !onList }

    /// The part of the row that chooses this subscription, read out as one sentence. A cancelled
    /// one is words, not a button switched off: iOS dims those, and its last charge, "Cancelled"
    /// and "per month" read 2.6 to 3.2 to 1 (measured on the iPad tour of 2026-11-16).
    @ViewBuilder private func choose(@ViewBuilder _ label: () -> some View) -> some View {
        if Self.isAChoice(cancelled: found.isCancelled, onList: isOnList) {
            Button(action: onToggle) {
                label().contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        } else {
            label()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
        }
    }

    private var whyButton: some View {
        Button(action: onExpand) {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inkTextFaint)
                .frame(width: Layout.tapTarget, height: Layout.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("foundRowWhy")
        // Names its service: nine rows said the same "Show why we think this is a subscription".
        .accessibilityLabel(isExpanded ? Text(verbatim: L10n.string("Hide why \(found.name) was found"))
                                       : Text(verbatim: L10n.string("Why \(found.name) was found")))
    }

    private var nameAndEvidence: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: found.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.leading)
            Text(verbatim: evidenceLine)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .multilineTextAlignment(.leading)
                // It wraps: held to one line beside the price, "Last charged Nov 9" became
                // "Last charge…" one text size up.
                .fixedSize(horizontal: false, vertical: true)
            if let doubt = Self.doubt(for: proven) {
                Text(verbatim: doubt)
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("foundDoubt")
            }
            if let afterTrial = Self.afterTrial(for: found) {
                Text(verbatim: afterTrial)
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let badge {
                HStack(spacing: 6) {
                    if let state = badge.state { StateMark(state: state) }
                    Text(verbatim: badge.text)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(badge.state.map { $0 == .due ? Color.due : Color.decide } ?? Color.inkTextMuted)
                }
            }
        }
    }

    /// The amount over how often: a narrow column, so that at the default size the name, what
    /// was found and the price share a line (on one line, "$34.99/mo" was 12 points too wide and
    /// every row grew by one). The two start at the same edge, so the column reads the same at
    /// the end of the row and under the words.
    @ViewBuilder private var price: some View {
        if let priceText {
            ZStack(alignment: .leading) {
                if let widestPrice {
                    priceColumn(widestPrice).hidden().accessibilityHidden(true)
                }
                priceColumn(Price(amount: priceText, period: found.billingFrequency.billingPeriodLabel))
            }
        }
    }

    private func priceColumn(_ price: Price) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: price.amount)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(verbatim: price.period)
                .font(.footnote)
                .foregroundStyle(Color.inkTextFaint)
        }
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous)
                .fill(isSelected ? Color.paper : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous)
                        .stroke(isSelected ? Color.clear : Color.inkTextFaint, lineWidth: 1.5)
                )
                .frame(width: boxSide, height: boxSide)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.paperInk)
            }
        }
        .accessibilityHidden(true)
    }

    /// Why Pausely thinks so, and the charges it read: the proof behind the line.
    private var evidenceDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(proven.reasons.enumerated()), id: \.offset) { _, reason in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "·").foregroundStyle(Color.inkTextFaint).accessibilityHidden(true)
                    Text(verbatim: reason)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !proven.evidence.isEmpty {
                VStack(alignment: .leading, spacing: typeSize.isAccessibilitySize ? 12 : 6) {
                    ForEach(proven.evidence.suffix(5).reversed()) { charge in
                        // A day and what was charged on it: on a line while both fit, the amount
                        // under its day when they do not. Side by side at the largest text size
                        // the day took three lines and the amount lost its last digit to a
                        // fourth ("$34.9" above "9", seen 2026-11-17).
                        LineOrStack(spacing: 8, lineSpacing: 0, spread: true, alignment: .firstTextBaseline) {
                            Text(charge.date, format: .dateTime.month(.abbreviated).day().year())
                            Text(verbatim: InboxImportView.money(charge.amount, charge.currency))
                        }
                        .font(.proof(.footnote))
                        .foregroundStyle(Color.inkTextMuted)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 2)
            }
            if !found.isCancelled {
                Button(action: onReject) {
                    Text("This isn't a subscription")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .tapArea(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Removes it and Pausely will remember, so it won't appear again")
                .accessibilityIdentifier("notASubscriptionButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Self.reasonsInset(largeText: typeSize.isAccessibilitySize))
        .padding(.bottom, 12)
    }

    /// How far in the reasons start: under the name, which is past the box. At the accessibility
    /// text sizes the name starts at the row's edge (`wordsHaveTheWholeRow`), and so do they.
    nonisolated static func reasonsInset(largeText: Bool) -> CGFloat { largeText ? 0 : 46 }
}
