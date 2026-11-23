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
        let yearlyInDisplay: Decimal

        var id: String { name.lowercased() }
    }

    let candidates: [Candidate]
    let maxSelection: Int
    let onSave: (Set<String>) -> Void
    var onSeePro: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>

    init(candidates: [Candidate], initialSelection: Set<String>, maxSelection: Int,
         onSave: @escaping (Set<String>) -> Void, onSeePro: (() -> Void)? = nil) {
        self.candidates = candidates
        let limit = max(1, maxSelection)
        self.maxSelection = limit
        self.onSave = onSave
        self.onSeePro = onSeePro
        let ranked = candidates.sorted { $0.yearlyInDisplay > $1.yearlyInDisplay }
        if initialSelection.isEmpty {
            _selected = State(initialValue: Set(ranked.prefix(limit).map(\.name)))
        } else {
            let validOrdered = ranked.map(\.name).filter { initialSelection.contains($0) }
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
                amount: sub.effectiveAmount,
                currency: sub.currency,
                frequency: sub.billingFrequency,
                yearlyInDisplay: rates.convert(sub.annualCost, from: sub.currency, to: display) ?? 0
            )
        }
        let activeNames = Set(activeCandidates.map { $0.name.lowercased() })
        let waitingCandidates = TallyImporter.waitingLines().filter { !activeNames.contains($0.name.lowercased()) }.map { line in
            let people = max(1, line.splitCount)
            let share = people > 1 ? AmountText.rounded(line.amount / Decimal(people), currency: line.currency) : line.amount
            return Candidate(
                name: line.name,
                category: line.category,
                amount: share,
                currency: line.currency,
                frequency: line.frequency ?? .monthly,
                yearlyInDisplay: rates.convert(line.yearlyCost, from: line.currency, to: display) ?? 0
            )
        }
        self.init(
            candidates: activeCandidates + waitingCandidates,
            initialSelection: Set(store.subscriptions.charging.map(\.name)),
            maxSelection: FreeTier.room(in: []),
            onSave: { chosen in
                Task { await TallyImporter.applyChoice(selectedNames: chosen, into: store) }
            },
            onSeePro: onSeePro
        )
    }

    private var sortedCandidates: [Candidate] {
        candidates.sorted { $0.yearlyInDisplay > $1.yearlyInDisplay }
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

                Text(L10n.string("\(selected.count) of \(maxSelection) selected. The rest wait safely until you swap or go Pro."))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

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
                        Text("Track all with Pro")
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
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.paper : (atCap ? Color.inkTextFaint : Color.inkTextMuted))
                    .accessibilityHidden(true)

                ServiceLogoView(name: item.name, category: item.category, size: 36)

                LineOrStack(spacing: 8, lineSpacing: 2, spread: true, besideShare: 0.45) {
                    Text(verbatim: item.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(atCap ? Color.inkTextMuted : Color.inkText)
                        .multilineTextAlignment(.leading)
                    Text(verbatim: item.frequency.pricedShort(MoneyFormat.string(item.amount, item.currency, locale: L10n.locale)))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(Color.inkTextMuted)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
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
            Feel.selection()
        }
    }
}
