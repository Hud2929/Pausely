import SwiftUI

/// The first run, step 3: the reveal. The slip against the guess, and the way on to an account.
struct RevealStep: View {
    @Binding var tally: Tally
    let rates: CurrencyRates
    let onBack: () -> Void
    let onKeep: () -> Void
    var onContinueWithoutAccount: (() -> Void)? = nil

    @State private var printed = 0
    @State private var showTotals = false
    @State private var editing: TallyLine?
    @State private var choosingTracked = false

    private var monthly: String { money(tally.monthlyTotal(rates: rates)) }
    private var yearly: String { money(tally.yearlyTotal(rates: rates)) }
    /// Rounded, for sentences; the slip keeps the cents.
    private var monthlyRound: String { round(tally.monthlyTotal(rates: rates)) }
    private var yearlyRound: String { round(tally.yearlyTotal(rates: rates)) }
    private var guessText: String {
        MoneyFormat.string(tally.guess, tally.currency, locale: L10n.locale, wholeUnits: true)
    }

    var body: some View {
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                FirstRunBackButton(action: onBack)

                Text(verbatim: headline)
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .opacity(showTotals ? 1 : 0)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: gapLine)
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.bottom, FreeTier.isExceeded(by: tally.subscriptions()) ? 14 : 24)
                    .opacity(showTotals ? 1 : 0)

                // Placed above the slip so even with 8+ items the free limit and "Choose which 5" sit
                // cleanly above the fold before the person keeps their list.
                if FreeTier.isExceeded(by: tally.subscriptions()) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tally.preferredNames.isEmpty
                             ? L10n.string("The free plan tracks \(FreeTier.subscriptionLimit), the most expensive first. The rest wait until you make room or go Pro.")
                             : L10n.string("You chose \(tally.preferredNames.count) to track. The rest wait until you make room or go Pro."))
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("revealFreeLimit")
                        Button { choosingTracked = true } label: {
                            Text(tally.preferredNames.isEmpty
                                 ? L10n.string("Choose which \(FreeTier.subscriptionLimit)")
                                 : L10n.string("Change which \(FreeTier.subscriptionLimit)"))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .underline()
                                .tapArea(.leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("revealChooseFiveButton")
                    }
                    .padding(.bottom, 14)
                    .opacity(showTotals ? 1 : 0)
                }

                slip
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
        } actions: {
            VStack(spacing: 8) {
                Button(action: onKeep) { Text("Keep my list") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("keepListButton")
                if let onContinueWithoutAccount {
                    Button(action: onContinueWithoutAccount) { Text("Continue without an account") }
                        .buttonStyle(.ink(.quiet))
                        .accessibilityIdentifier("continueWithoutAccountButton")
                    Text("Keep my list backs up to a free account. Without one, it stays on this iPhone.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Next: a free account, so your list is saved.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextFaint)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .task { await printSlip() }
        .sheet(item: $editing) { line in
            PriceSheet(name: line.name, placeholder: line.amount, currency: line.currency, frequency: line.frequency ?? .monthly) { amount in
                tally.setAmount(amount, for: line.name)
            }
        }
        .sheet(isPresented: $choosingTracked) {
            FreeLimitPickerSheet(
                candidates: tally.lines.map { line in
                    FreeLimitPickerSheet.Candidate(
                        name: line.name,
                        category: line.category,
                        amount: line.amount,
                        currency: line.currency,
                        frequency: line.frequency ?? .monthly,
                        yearlyInDisplay: rates.convert(line.yearlyCost, from: line.currency, to: tally.currency) ?? 0
                    )
                },
                initialSelection: tally.preferredNames,
                maxSelection: FreeTier.room(in: []),
                onSave: { chosen in tally.preferredNames = chosen }
            )
        }
    }

    private var slip: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 12) {
                // The lines sit one fingertip apart, with no extra gap: each is its own place to tap.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(tally.lines.enumerated()), id: \.element.id) { index, line in
                        if index < printed {
                            Button { editing = line } label: {
                                let formatted = MoneyFormat.string(line.amount, line.currency, locale: L10n.locale)
                                let valueText: String = {
                                    if let freq = line.frequency, freq != .monthly { return freq.pricedShort(formatted) }
                                    return formatted
                                }()
                                ProofLine(label: line.name, value: valueText)
                                    // A line is a place to tap: a fingertip tall (it was 28 points).
                                    .frame(maxWidth: .infinity, minHeight: Layout.tapTarget, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("revealLine")
                            .accessibilityHint(Text("Change the price"))
                            .transition(.arriving(.offset(y: -6)))
                        }
                    }
                }

                if showTotals {
                    Group {
                        Perforation().padding(.vertical, 4)
                        ProofLine(label: L10n.string("Your guess"), value: guessText)
                            .foregroundStyle(Color.paperMuted)
                        ProofLine(label: tally.isApproximate ? L10n.string("Each month, about") : L10n.string("Each month"),
                                  value: monthly, emphasised: true)
                        ProofLine(label: tally.isApproximate ? L10n.string("Each year, about") : L10n.string("Each year"),
                                  value: yearly, emphasised: true)
                        if tally.isApproximate {
                            Text("These are typical prices. Tap a line to put in what you really pay.")
                                .font(.footnote)
                                .foregroundStyle(Color.paperMuted)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private var headline: String {
        switch tally.verdict(rates: rates) {
        case .more:
            return tally.isApproximate
                ? L10n.string("You guessed \(guessText). It's about \(monthlyRound) a month.")
                : L10n.string("You guessed \(guessText). It's \(monthlyRound) a month.")
        case .close:
            return L10n.string("Good guess. It's about \(monthlyRound) a month.")
        case .less:
            return L10n.string("Less than you guessed: about \(monthlyRound) a month.")
        }
    }

    private var gapLine: String {
        switch tally.verdict(rates: rates) {
        case .more(_, let yearlyGap):
            return L10n.string("That's about \(round(yearlyGap)) a year more than you thought.")
        case .close, .less:
            return L10n.string("That's \(yearlyRound) a year. Pausely asks before each renewal whether it's still worth it.")
        }
    }

    private func money(_ amount: Decimal) -> String {
        MoneyFormat.string(amount, tally.currency, locale: L10n.locale)
    }

    private func round(_ amount: Decimal) -> String {
        MoneyFormat.string(amount, tally.currency, locale: L10n.locale, wholeUnits: true)
    }

    /// Prints the slip a line at a time, with a tick for each. With Reduce Motion it appears whole.
    private func printSlip() async {
        guard printed == 0 else { return }
        if UIAccessibility.isReduceMotionEnabled {
            printed = tally.lines.count
            showTotals = true
            return
        }
        for index in tally.lines.indices {
            try? await Task.sleep(for: .milliseconds(index == 0 ? 250 : 90))
            withAnimation(Motion.touch) { printed = index + 1 }
            Feel.tick()
        }
        try? await Task.sleep(for: .milliseconds(350))
        withAnimation(Motion.arrive) { showTotals = true }
        Feel.landed()
    }
}
