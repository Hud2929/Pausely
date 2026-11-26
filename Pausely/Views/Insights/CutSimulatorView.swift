import SwiftUI

/// Entry card on Insights inviting the person to test cutting subscriptions and see exact 1-year
/// and 5-year savings before cancelling anything.
struct CutSimulatorCard: View {
    let topCandidate: InsightsEngine.CutCandidate
    let currency: String
    let isUnlocked: Bool
    let canCombineMultiple: Bool
    let onOpen: () -> Void

    var body: some View {
        let yearly = MoneyFormat.total(topCandidate.yearlyInDisplay, currency,
                                       converted: topCandidate.isConverted, locale: L10n.locale, wholeUnits: true)
        let fiveYear = MoneyFormat.total(topCandidate.yearlyInDisplay * Decimal(5), currency,
                                         converted: topCandidate.isConverted, locale: L10n.locale, wholeUnits: true)
        Button {
            Feel.selection()
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                SideBySide(spacing: 12) {
                    Text("Cut simulator")
                        .font(.headline)
                        .foregroundStyle(Color.inkText)
                } trailing: {
                    if !isUnlocked && canCombineMultiple {
                        ProPill()
                    } else {
                        RowChevron()
                    }
                }

                Text(L10n.string("Cutting \(topCandidate.subscription.name) alone keeps \(yearly) a year — \(fiveYear) over 5 years."))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Test different cuts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous).stroke(Color.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insightsCutSimulatorCard")
    }
}

/// Interactive "What if I cut…" lab: toggle subscriptions on or off to watch exact 1-year and
/// 5-year savings update live on a torn Paper Slip. Free users can test 1 cut live; Pro unlocks
/// multi-subscription cut scenarios and preserves the user's pending selection on unlock.
struct CutSimulatorSheet: View {
    let subscriptions: [Subscription]
    let candidates: [InsightsEngine.CutCandidate]
    let currency: String
    let rates: CurrencyRates
    let onReviewSubscription: (UUID) -> Void

    private struct SimulatorPaywall: Identifiable {
        let id = UUID()
        let context: PaywallContext
        let pendingCandidateID: UUID
    }

    @ObservedObject private var paymentManager = PaymentManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedIDs: Set<UUID> = []
    @State private var paywall: SimulatorPaywall?

    private var isUnlocked: Bool { paymentManager.isUnlocked(.spendForecast) }

    private var simulation: InsightsEngine.CutSimulation {
        InsightsEngine.simulateCuts(selectedIDs: selectedIDs, in: subscriptions, currency: currency, rates: rates)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("What if you cut…")
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text("Tap subscriptions below to see what cutting them keeps over 1 year and 5 years. Nothing is cancelled here.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    resultSlip
                        .padding(.top, 16)

                    if !isUnlocked && candidates.count >= 2 {
                        Text("Try 1 subscription free. Pro lets you combine multiple cuts at once.")
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                            if index > 0 { Hairline() }
                            candidateRow(candidate)
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .readableScroll()
            .background(Color.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.inkText)
                        .accessibilityIdentifier("cutSimulatorDone")
                }
                if !selectedIDs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            Feel.selection()
                            withAnimation(Motion.unlessReduced(Motion.touch)) { selectedIDs.removeAll() }
                        }
                        .foregroundStyle(Color.inkTextMuted)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $paywall) { item in
            StoreKitUpgradeView(context: item.context) {
                Feel.tick()
                withAnimation(Motion.unlessReduced(Motion.touch)) {
                    _ = selectedIDs.insert(item.pendingCandidateID)
                }
            }
        }
    }

    private var resultSlip: some View {
        let yearly = MoneyFormat.total(simulation.yearlySaved, currency,
                                       converted: simulation.savedIsConverted, locale: L10n.locale, wholeUnits: true)
        let fiveYear = MoneyFormat.total(simulation.fiveYearSaved, currency,
                                         converted: simulation.savedIsConverted, locale: L10n.locale, wholeUnits: true)
        let remaining = MoneyFormat.total(simulation.remainingMonthly, currency,
                                          converted: simulation.remainingIsConverted, locale: L10n.locale)

        return PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 10) {
                ProofLine(label: L10n.string("Kept each year"), value: yearly, emphasised: true)
                    .foregroundStyle(simulation.selectedCount > 0 ? Color.paperKept : Color.paperInk)
                ProofLine(label: L10n.string("Kept over 5 years"), value: fiveYear, emphasised: true)
                Perforation().padding(.vertical, 2)
                ProofLine(label: L10n.string("New monthly total"), value: remaining)
                    .foregroundStyle(Color.paperMuted)
            }
            .contentTransition(.numericText())
            .animation(Motion.unlessReduced(Motion.touch), value: simulation)
        }
    }

    private func candidateRow(_ candidate: InsightsEngine.CutCandidate) -> some View {
        let isOn = selectedIDs.contains(candidate.id)
        let yearly = MoneyFormat.total(candidate.yearlyInDisplay, currency,
                                       converted: candidate.isConverted, locale: L10n.locale, wholeUnits: true)
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    toggleButton(candidate: candidate, isOn: isOn, yearly: yearly)
                    if isOn {
                        reviewButton(for: candidate)
                            .padding(.bottom, 6)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    toggleButton(candidate: candidate, isOn: isOn, yearly: yearly)
                    if isOn {
                        reviewButton(for: candidate)
                    }
                }
            }
        }
    }

    private func toggleButton(candidate: InsightsEngine.CutCandidate, isOn: Bool, yearly: String) -> some View {
        Button {
            toggle(candidate)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.kept : Color.inkTextFaint)
                    .accessibilityHidden(true)

                AdaptiveRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: candidate.subscription.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        if let reason = candidate.reason {
                            Text(verbatim: reason.label)
                                .font(.footnote)
                                .foregroundStyle(reason == .priceIncreased ? Color.due : Color.decide)
                        }
                    }
                } value: {
                    Text(L10n.string("\(yearly) a year"))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.inkTextMuted)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: Layout.tapTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func reviewButton(for candidate: InsightsEngine.CutCandidate) -> some View {
        Button {
            Feel.selection()
            dismiss()
            onReviewSubscription(candidate.id)
        } label: {
            Text("Review")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inkText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
                .tapArea(typeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cutSimulatorReview_\(candidate.subscription.name)")
    }

    private func toggle(_ candidate: InsightsEngine.CutCandidate) {
        if selectedIDs.contains(candidate.id) {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) { _ = selectedIDs.remove(candidate.id) }
            return
        }
        if !isUnlocked && selectedIDs.count >= 1 {
            // Free users tried cut #1 themselves and tapped a second cut — open Pro over the
            // simulator so closing keeps their state and unlocking toggles both cuts live.
            var combined = selectedIDs
            combined.insert(candidate.id)
            let combinedSim = InsightsEngine.simulateCuts(selectedIDs: combined, in: subscriptions,
                                                          currency: currency, rates: rates)
            Feel.selection()
            paywall = SimulatorPaywall(
                context: PaywallContext(
                    trigger: .spendForecast,
                    forecastCurrency: currency,
                    forecastIsConverted: combinedSim.savedIsConverted,
                    simulatorYearlySavings: combinedSim.yearlySaved
                ),
                pendingCandidateID: candidate.id
            )
            return
        }
        Feel.tick()
        withAnimation(Motion.unlessReduced(Motion.touch)) { _ = selectedIDs.insert(candidate.id) }
    }
}
