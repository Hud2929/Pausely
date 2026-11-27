import SwiftUI

/// Lets a person on the free plan pick exactly which subscriptions fill their tracked slots instead
/// of silently accepting the most expensive ones.
struct FreeLimitPickerSheet: View {
    struct Candidate: Identifiable, Equatable {
        let name: String
        let category: String
        let amount: Decimal
        let currency: String
        let frequency: BillingFrequency
        /// Yearly cost converted into `displayCurrency`, or nil if that currency has no exchange rate.
        let yearlyInDisplay: Decimal?

        var id: String { name.lowercased() }
    }

    let candidates: [Candidate]
    let maxSelection: Int
    let displayCurrency: String
    let onSave: (Set<String>) -> Void
    var onSeePro: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>
    /// Set when a pick past the limit was refused, so the page says what to do.
    @State private var refusedNote = false
    @Environment(\.dynamicTypeSize) private var typeSize

    @MainActor
    init(candidates: [Candidate], initialSelection: Set<String>, maxSelection: Int,
         displayCurrency: String? = nil,
         onSave: @escaping (Set<String>) -> Void, onSeePro: (() -> Void)? = nil) {
        var unique: [Candidate] = []
        for candidate in candidates where !unique.contains(where: { ServiceName.same($0.name, candidate.name) }) {
            unique.append(candidate)
        }
        self.candidates = unique
        let limit = max(1, maxSelection)
        self.maxSelection = limit
        self.displayCurrency = displayCurrency ?? CurrencyManager.shared.selectedCurrency
        self.onSave = onSave
        self.onSeePro = onSeePro
        let ranked = unique.sorted { ($0.yearlyInDisplay ?? -1) > ($1.yearlyInDisplay ?? -1) }
        if initialSelection.isEmpty {
            _selected = State(initialValue: Set(ranked.prefix(limit).map(\.name)))
        } else {
            let validOrdered = ranked.map(\.name).filter { name in
                initialSelection.contains { ServiceName.same($0, name) }
            }
            let clamped = Array(validOrdered.prefix(limit))
            _selected = State(initialValue: clamped.isEmpty ? Set(ranked.prefix(limit).map(\.name)) : Set(clamped))
        }
    }

    /// Convenience initializer for swapping between currently active subscriptions and waiting lines.
    @MainActor
    init(store: SubscriptionStore, currencyManager: CurrencyManager, onSeePro: @escaping () -> Void) {
        let display = currencyManager.selectedCurrency
        let rates = currencyManager.rates
        let activeCandidates = store.subscriptions.charging.map { sub in
            Candidate(
                name: sub.name,
                category: sub.category ?? SubscriptionCategory.other.rawValue,
                amount: sub.amount,
                currency: sub.currency,
                frequency: sub.billingFrequency,
                yearlyInDisplay: rates.convert(sub.annualCost, from: sub.currency, to: display)
            )
        }
        let waitingCandidates = TallyImporter.waitingLines().filter { line in
            !activeCandidates.contains { ServiceName.same($0.name, line.name) }
        }.map { line in
            Candidate(
                name: line.name,
                category: line.category,
                amount: line.amount,
                currency: line.currency,
                frequency: line.frequency ?? .monthly,
                yearlyInDisplay: rates.convert(line.yearlyCost, from: line.currency, to: display)
            )
        }
        self.init(
            candidates: activeCandidates + waitingCandidates,
            initialSelection: Set(store.subscriptions.charging.map(\.name)),
            maxSelection: FreeTier.room(in: []),
            displayCurrency: display,
            onSave: { chosen in
                Task { await TallyImporter.applyChoice(selectedNames: chosen, into: store) }
            },
            onSeePro: onSeePro
        )
    }

    private var sortedCandidates: [Candidate] {
        candidates.sorted { ($0.yearlyInDisplay ?? -1) > ($1.yearlyInDisplay ?? -1) }
    }

    /// Sum of unselected yearly amounts only when EVERY unselected item converted cleanly (never silently $0).
    private var unselectedYearlyTotal: (amount: Decimal, isConverted: Bool)? {
        let unselected = sortedCandidates.filter { !selected.contains($0.name) }
        guard !unselected.isEmpty else { return nil }
        let normalized = MoneyFormat.normalizedCode(displayCurrency)
        var sum: Decimal = 0
        var convertedAny = false
        for item in unselected {
            guard let yearly = item.yearlyInDisplay else { return nil }
            sum += yearly
            if MoneyFormat.normalizedCode(item.currency) != normalized { convertedAny = true }
        }
        return sum > 0 ? (sum, convertedAny) : nil
    }

    private var unselectedCount: Int {
        max(0, candidates.count - selected.count)
    }

    var body: some View {
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton("Cancel") { dismiss() }
                    Spacer()
                }

                Text(maxSelection == 1
                     ? L10n.string("Choose 1 to track")
                     : L10n.string("Choose which \(maxSelection) to track"))
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)

                let riskText: String = {
                    if unselectedCount > 0, let total = unselectedYearlyTotal {
                        let yearlyAmount = total.amount
                        let yearly = MoneyFormat.string(yearlyAmount, displayCurrency, locale: L10n.locale, wholeUnits: true)
                        return unselectedCount == 1
                            ? L10n.string("\(selected.count) of \(maxSelection) selected. 1 left unwatched (about \(yearly) a year, no reminders).")
                            : L10n.string("\(selected.count) of \(maxSelection) selected. \(unselectedCount) left unwatched (about \(yearly) a year, no reminders).")
                    }
                    return L10n.string("\(selected.count) of \(maxSelection) selected. The rest wait safely until you swap or go Pro.")
                }()
                Text(verbatim: riskText)
                    .font(.subheadline)
                    .foregroundStyle(refusedNote && selected.count >= maxSelection ? Color.decide : Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.bottom, refusedNote && selected.count >= maxSelection ? 4 : 20)
                if refusedNote && selected.count >= maxSelection {
                    Text("Untick one to choose another.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.decide)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 20)
                }

                VStack(spacing: 0) {
                    ForEach(Array(sortedCandidates.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Hairline() }
                        row(item)
                    }
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        } actions: {
            VStack(spacing: 10) {
                Button {
                    Feel.landed()
                    onSave(selected)
                    dismiss()
                } label: {
                    Text(selected.count == 1
                         ? L10n.string("Track this 1")
                         : L10n.string("Track these \(selected.count)"))
                }
                .buttonStyle(.ink)
                .disabled(selected.isEmpty)
                .accessibilityIdentifier("saveFreePickerButton")

                if let onSeePro {
                    Button {
                        dismiss()
                        onSeePro()
                    } label: {
                        Text("Track all \(candidates.count) with Pro")
                    }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("freePickerSeeProButton")
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .inkScreen()
        .preferredColorScheme(.dark)
    }

    private func row(_ item: Candidate) -> some View {
        let isOn = selected.contains(item.name)
        let atCap = selected.count >= maxSelection && !isOn
        return Button {
            toggle(item.name)
        } label: {
            MarkedWords(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.paper : (atCap ? Color.inkTextFaint : Color.inkTextMuted))
                    .accessibilityHidden(true)
            } words: {
                HStack(spacing: 12) {
                    if !typeSize.isAccessibilitySize {
                        ServiceLogoView(name: item.name, category: item.category, size: 36)
                    }

                    LineOrStack(spacing: 8, lineSpacing: 2, spread: true, besideShare: typeSize.isAccessibilitySize ? 0 : 0.45) {
                        Text(verbatim: item.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(atCap ? Color.inkTextMuted : Color.inkText)
                            .multilineTextAlignment(.leading)
                        Text(verbatim: item.frequency.pricedShort(MoneyFormat.string(item.amount, item.currency, locale: L10n.locale)))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(Color.inkTextMuted)
                    }
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Read as words ("$17.99 a month", not "/mo"), chosen as a trait, and why a sixth can't be chosen
        // (the rating of 2026-11-23).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(item.name), \(item.frequency.priced(MoneyFormat.string(item.amount, item.currency, locale: L10n.locale)))"))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(atCap ? Text("Untick one to choose this instead") : Text(verbatim: ""))
        .accessibilityIdentifier("freePickerRow_\(item.name)")
    }

    private func toggle(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
            Feel.selection()
        } else if selected.count < maxSelection {
            selected.insert(name)
            Feel.tick()
        } else {
            // A sixth is refused out loud, not silently (the rating of 2026-11-23).
            Feel.selection()
            refusedNote = true
            AccessibilityNotification.Announcement(L10n.string("Untick one to choose this instead")).post()
        }
    }
}
