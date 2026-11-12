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
        let day: (Date) -> String = { $0.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale)) }
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
        if !found.isCancelled { parts.append(isSelected ? L10n.string("selected") : L10n.string("not selected")) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    HStack(spacing: 12) {
                        if !found.isCancelled { checkbox }
                        ServiceLogoView(name: found.name, category: nil, size: 36)
                        if typeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 3) { nameAndEvidence; price }
                            Spacer(minLength: 0)
                        } else {
                            nameAndEvidence
                            Spacer(minLength: 8)
                            price
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(found.isCancelled)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint(found.isCancelled ? Text(verbatim: "") : Text("Double tap to select or deselect"))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

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
            .padding(.vertical, 10)

            if isExpanded { evidenceDetail }
        }
    }

    private var nameAndEvidence: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: found.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.inkText)
                .multilineTextAlignment(.leading)
            Text(verbatim: evidenceLine)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .multilineTextAlignment(.leading)
                // One line beside a price at ordinary sizes; free to wrap when the text is large.
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.8)
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

    @ViewBuilder private var price: some View {
        if let priceText {
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 1) {
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
                .frame(width: 22, height: 22)
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
