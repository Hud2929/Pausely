import SwiftUI

/// The first thing a new person sees: a guess, a tally, and the gap between them. The account
/// comes after, so the app has shown something true about their money before asking for anything.
struct FirstRunView: View {
    let onKeepList: () -> Void
    let onSignIn: () -> Void

    enum Phase: Int { case guess, tally, reveal }

    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var phase: Phase
    @State private var tally: Tally
    @State private var guess: Double

    init(startAt phase: Phase = .guess, tally: Tally? = nil,
         onKeepList: @escaping () -> Void, onSignIn: @escaping () -> Void) {
        let start = tally ?? Tally(currency: CurrencyManager.shared.selectedCurrency)
        _phase = State(initialValue: phase)
        _tally = State(initialValue: start)
        _guess = State(initialValue: NSDecimalNumber(decimal: start.guess).doubleValue)
        self.onKeepList = onKeepList
        self.onSignIn = onSignIn
    }

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            switch phase {
            case .guess:
                GuessStep(guess: $guess, currency: tally.currency, onNext: {
                    tally.guess = Decimal(Int(guess))
                    go(.tally)
                }, onSignIn: onSignIn)
                .transition(stepTransition)
            case .tally:
                TallyStep(tally: $tally, rates: currencyManager.rates,
                          onBack: { go(.guess) }, onReveal: { go(.reveal) }, onSkip: keep)
                    .transition(stepTransition)
            case .reveal:
                RevealStep(tally: $tally, rates: currencyManager.rates,
                           onBack: { go(.tally) }, onKeep: keep)
                    .transition(stepTransition)
            }
        }
        .readableWidth()
    }

    private var stepTransition: AnyTransition {
        UIAccessibility.isReduceMotionEnabled ? .opacity : .opacity.combined(with: .offset(y: 12))
    }

    private func go(_ next: Phase) {
        Feel.selection()
        withAnimation(Motion.unlessReduced(Motion.arrive)) { phase = next }
    }

    private func keep() {
        if tally.lines.isEmpty { PendingTally.clear() } else { PendingTally.save(tally) }
        onKeepList()
    }
}

// MARK: - Shared pieces

/// The pause mark and the name, small, at the top of the first screen.
private struct Wordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Capsule().frame(width: 4, height: 15)
                Capsule().frame(width: 4, height: 15)
            }
            .accessibilityHidden(true)
            Text(verbatim: "Pausely").font(.headline)
        }
        .foregroundStyle(Color.inkText)
    }
}

private struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inkText)
                .frame(width: Layout.tapTarget, height: Layout.tapTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Back"))
    }
}

// MARK: - 1. The guess

private struct GuessStep: View {
    @Binding var guess: Double
    let currency: String
    let onNext: () -> Void
    let onSignIn: () -> Void

    /// Currencies without cents (yen, won) count in hundreds.
    private var unit: Double { MoneyFormat.fractionDigits(for: currency) == 0 ? 100 : 1 }
    private var step: Double { 5 * unit }
    private var top: Double { 400 * unit }
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Wordmark()
                Spacer()
                Button(action: onSignIn) {
                    Text("Sign in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkTextMuted)
                        .frame(minHeight: Layout.tapTarget)
                }
                .accessibilityIdentifier("firstRunSignIn")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("What do you think you pay for subscriptions each month?")
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 36)
                        .accessibilityAddTraits(.isHeader)

                    Text("Just guess. Don't look anything up.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            // The number and its control sit low, where a thumb reaches them.
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: amountText)
                    .font(.system(size: numberSize, weight: .bold, design: .serif))
                    .foregroundStyle(Color.inkText)
                    .contentTransition(.numericText(value: guess))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityHidden(true)

                Slider(value: snapped, in: 0...top) {
                    Text("Your guess")
                } minimumValueLabel: {
                    Text(verbatim: MoneyFormat.string(Decimal(0), currency, locale: L10n.locale, wholeUnits: true))
                } maximumValueLabel: {
                    Text(verbatim: MoneyFormat.string(Decimal(Int(top)), currency, locale: L10n.locale, wholeUnits: true) + "+")
                }
                .font(.caption)
                .foregroundStyle(Color.inkTextFaint)
                .tint(Color.inkText)
                .accessibilityValue(Text(verbatim: amountText))
                .accessibilityIdentifier("guessSlider")
                .onChange(of: guess) { _, _ in Feel.selection() }
            }
            .animation(Motion.unlessReduced(Motion.touch), value: guess)
            .padding(.bottom, 28)

            Button(action: onNext) { Text("That's my guess") }
                .buttonStyle(.ink)
                .accessibilityIdentifier("getStartedButton")
                .padding(.bottom, 12)
        }
        .padding(.horizontal, Layout.margin)
        .padding(.top, 8)
    }

    /// Snaps to steps of five without the tick marks a stepped slider draws.
    private var snapped: Binding<Double> {
        Binding(get: { guess }, set: { guess = ($0 / step).rounded() * step })
    }

    private var amountText: String {
        let text = MoneyFormat.string(Decimal(Int(guess)), currency, locale: L10n.locale, wholeUnits: true)
        return guess >= top ? text + "+" : text
    }
}

// MARK: - 2. The tally

private struct TallyStep: View {
    @Binding var tally: Tally
    let rates: CurrencyRates
    let onBack: () -> Void
    let onReveal: () -> Void
    let onSkip: () -> Void

    @State private var asking: TallyService?

    private var services: [TallyService] { TallyCatalog.services(payingIn: tally.currency) }
    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BackButton(action: onBack)

                    Text("Now tap everything you pay for.")
                        .font(.question(.title2))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)

                    Text("Anything missing can be added afterwards.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(services) { service in
                            ServiceTile(service: service, isOn: tally.contains(service)) {
                                let adding = !tally.contains(service)
                                // No honest typical price in this currency: ask what they pay.
                                if adding, Tally.typicalAmount(service, payingIn: tally.currency) == nil {
                                    asking = service
                                    return
                                }
                                withAnimation(Motion.unlessReduced(Motion.touch)) { tally.toggle(service) }
                                if adding { Feel.tick() } else { Feel.selection() }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 8)
            }

            slipBar
        }
        .sheet(item: $asking) { service in
            PriceSheet(name: service.name, placeholder: nil, currency: tally.currency) { amount in
                withAnimation(Motion.unlessReduced(Motion.touch)) {
                    tally.toggle(service, amount: amount, confirmed: true)
                }
                Feel.tick()
            }
            .presentationDetents([.height(300)])
            .presentationBackground(Color.inkRaised)
        }
    }

    /// The slip, feeding out of the bottom of the screen: the last line printed, and the way on.
    private var slipBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let last = tally.lines.last {
                ProofLine(label: last.name, value: MoneyFormat.string(last.amount, last.currency, locale: L10n.locale))
                    .id(last.name)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 8)), removal: .opacity))
                ProofLine(label: L10n.string("On your slip"), value: "\(tally.lines.count)", emphasised: true)
                Button(action: onReveal) { Text("Show me the total") }
                    .buttonStyle(.ink(.onPaper))
                    .accessibilityIdentifier("showTotalButton")
            } else {
                Text("Your slip is empty. Tap the first thing you pay for.")
                    .font(.proof(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onSkip) {
                    Text("None of these")
                        .font(.subheadline.weight(.semibold))
                        .underline()
                        .frame(minHeight: Layout.tapTarget)
                }
                .accessibilityIdentifier("noneOfTheseButton")
            }
        }
        .foregroundStyle(Color.paperInk)
        .padding(.horizontal, Layout.margin)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.paper
                .clipShape(SlipShape(tornTop: true, tornBottom: false))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct ServiceTile: View {
    let service: TallyService
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ServiceLogoView(name: service.name, category: service.category.rawValue, size: 40)
                Text(verbatim: service.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.inkText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 104)
            .background(isOn ? Color.inkLifted : Color.clear,
                        in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                    .stroke(isOn ? Color.paper : Color.line, lineWidth: isOn ? 1.5 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.paperInk)
                        .frame(width: 20, height: 20)
                        .background(Color.paper, in: Circle())
                        .padding(7)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: service.name))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

// MARK: - 3. The reveal

private struct RevealStep: View {
    @Binding var tally: Tally
    let rates: CurrencyRates
    let onBack: () -> Void
    let onKeep: () -> Void

    @State private var printed = 0
    @State private var showTotals = false
    @State private var editing: TallyLine?

    private var monthly: String { money(tally.monthlyTotal(rates: rates)) }
    private var yearly: String { money(tally.yearlyTotal(rates: rates)) }
    /// Rounded, for sentences; the slip keeps the cents.
    private var monthlyRound: String { round(tally.monthlyTotal(rates: rates)) }
    private var yearlyRound: String { round(tally.yearlyTotal(rates: rates)) }
    private var guessText: String {
        MoneyFormat.string(tally.guess, tally.currency, locale: L10n.locale, wholeUnits: true)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BackButton(action: onBack)

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
                        .padding(.bottom, 24)
                        .opacity(showTotals ? 1 : 0)

                    slip
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 8)
            }

            VStack(spacing: 10) {
                Button(action: onKeep) { Text("Keep my list") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("keepListButton")
                Text("Next: a free account, so your list is saved.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(Color.ink)
        }
        .task { await printSlip() }
        .sheet(item: $editing) { line in
            PriceSheet(name: line.name, placeholder: line.amount, currency: tally.currency) { amount in
                tally.setAmount(amount, for: line.name)
            }
            .presentationDetents([.height(300)])
            .presentationBackground(Color.inkRaised)
        }
    }

    private var slip: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(tally.lines.enumerated()), id: \.element.id) { index, line in
                    if index < printed {
                        Button { editing = line } label: {
                            ProofLine(label: line.name,
                                      value: MoneyFormat.string(line.amount, line.currency, locale: L10n.locale))
                                .frame(minHeight: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Change the price"))
                        .transition(.opacity.combined(with: .offset(y: -6)))
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
            return L10n.string("That's \(round(yearlyGap)) a year more than you thought.")
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

/// Correct one price on the slip.
private struct PriceSheet: View {
    let name: String
    /// The price already on the slip, shown until the person types.
    let placeholder: Decimal?
    let currency: String
    let onSave: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var amount: Decimal? { SubscriptionEditDraft.parseAmount(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("What do you pay for \(name) each month?"))
                .font(.question(.title3))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TextField(placeholder.map { MoneyFormat.string($0, currency, locale: L10n.locale) } ?? "", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.proof(.title2, weight: .medium))
                    .foregroundStyle(Color.inkText)
                    .focused($focused)
                    .accessibilityLabel(Text("Price each month"))
                Text(verbatim: currency)
                    .font(.proof(.subheadline))
                    .foregroundStyle(Color.inkTextMuted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(Color.inkLifted, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))

            Button {
                if let amount { onSave(amount) }
                dismiss()
            } label: { Text("Save") }
                .buttonStyle(.ink)
                .disabled(amount == nil)

            Spacer(minLength: 0)
        }
        .padding(Layout.margin)
        .padding(.top, 8)
        .onAppear { focused = true }
    }
}
