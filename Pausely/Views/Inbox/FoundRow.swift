import SwiftUI

/// One found subscription on the results list of Find in Email: its name, what proves it, its
/// price, and a box to choose it.
struct FoundRow: View {
    let found: FoundSubscription
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
        switch proven.status {
        case .priceIncreased: return (L10n.string("Price went up"), .decide)
        case .trial: return (L10n.string("Free trial"), .decide)
        case .likelyEnded: return (L10n.string("May have ended"), nil)
        case .cancelled: return (L10n.string("Cancelled"), nil)
        case .active: return proven.chargedAfterCancel ? (L10n.string("Charged after cancelling"), .due) : nil
        }
    }

    private var evidenceLine: String {
        // A day and its month stay on one line: beside the price, one text size up, the line
        // read "Last", "charged Nov", "10".
        let day: (Date) -> String = { L10n.whole($0.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))) }
        if proven.status == .trial, let ends = proven.trialEndsOn { return L10n.string("Trial ends \(day(ends))") }
        if let last = proven.lastChargeDate.map(day) { return L10n.string("Last charged \(last)") }
        return L10n.string("Detected from your emails")
    }

    private var priceText: String? {
        found.priceUnknown ? nil : InboxImportView.money(found.amount, found.currency)
    }

    private var accessibilitySummary: String {
        var parts = [found.name]
        if let priceText { parts.append(found.billingFrequency.priced(priceText)) }
        parts.append(evidenceLine)
        if let badge { parts.append(badge.text) }
        if Self.isAChoice(cancelled: found.isCancelled) { parts.append(isSelected ? L10n.string("selected") : L10n.string("not selected")) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if Self.wordsHaveTheWholeRow(largeText: typeSize.isAccessibilitySize) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            // The box is a second place to tap; the words under it say what it is.
                            if Self.isAChoice(cancelled: found.isCancelled) {
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
                    }
                } else {
                    HStack(spacing: 8) {
                        choose {
                            HStack(spacing: 12) {
                                if Self.isAChoice(cancelled: found.isCancelled) { checkbox }
                                ServiceLogoView(name: found.name, category: nil, size: 36)
                                // As on the Subscriptions list: the price keeps its width, 8 points
                                // from the words (a spacer between them took 32, and "Last charged
                                // Nov 9" broke in two for want of 4). This row also holds a box and
                                // a chevron, so the price goes under the words sooner: beside them
                                // only while it takes no more than a third of what is left.
                                LineOrStack(spacing: 8, lineSpacing: 4, spread: true, besideShare: Self.priceShare) {
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

            if isExpanded { evidenceDetail }
        }
    }

    /// The most of the row's width the price may take while the words wrap beside it.
    nonisolated static let priceShare: CGFloat = 0.35

    /// Whether the name, what was found and the price run the width of the row, with the box and
    /// the way to "why" on a line above them. At the accessibility text sizes, yes: between the
    /// box, the logo and the chevron the words had a third of the row, and broke inside
    /// themselves ("Spoti-fy", "Last charge" above "d Nov 8").
    nonisolated static func wordsHaveTheWholeRow(largeText: Bool) -> Bool { largeText }

    /// Whether the row is something to choose. One that was cancelled is not: it is shown so the
    /// person knows it was seen, and there is nothing to add.
    nonisolated static func isAChoice(cancelled: Bool) -> Bool { !cancelled }

    /// The part of the row that chooses this subscription, read out as one sentence. A cancelled
    /// one is words, not a button switched off: iOS dims those, and its last charge, "Cancelled"
    /// and "per month" read 2.6 to 3.2 to 1 (measured on the iPad tour of 2026-11-16).
    @ViewBuilder private func choose(@ViewBuilder _ label: () -> some View) -> some View {
        if Self.isAChoice(cancelled: found.isCancelled) {
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
        .accessibilityLabel(isExpanded ? Text("Hide why") : Text("Show why we think this is a subscription"))
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
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: priceText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                Text(verbatim: found.billingFrequency.billingPeriodLabel)
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
            }
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
                VStack(spacing: 6) {
                    ForEach(proven.evidence.suffix(5).reversed()) { charge in
                        HStack {
                            Text(charge.date, format: .dateTime.month(.abbreviated).day().year())
                            Spacer(minLength: 8)
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
        .padding(.leading, 46)
        .padding(.bottom, 12)
    }
}
