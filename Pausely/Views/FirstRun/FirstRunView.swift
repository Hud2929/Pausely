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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inkScreen()
        .readableWidth()
    }

    private var stepTransition: AnyTransition {
        .arriving(.offset(y: 12))
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
        .accessibilityIdentifier("firstRunBack")
    }
}

// MARK: - 1. The guess

struct GuessStep: View {
    @Binding var guess: Double
    let currency: String
    let onNext: () -> Void
    let onSignIn: () -> Void

    /// Currencies without cents (yen, won) count in hundreds.
    private var unit: Double { MoneyFormat.fractionDigits(for: currency) == 0 ? 100 : 1 }
    private var step: Double { 5 * unit }
    private var top: Double { 400 * unit }
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 76
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if Self.answerSitsLow(onPad: onPad, largeText: typeSize.isAccessibilitySize) {
                // The question takes the room above the number and its control, which sit low,
                // where a thumb reaches them.
                VStack(alignment: .leading, spacing: 0) {
                    header
                    ScrollView { question }
                        .scrollBounceBehavior(.basedOnSize)
                    answer
                        .padding(.bottom, 28)
                    nextButton
                }
                .padding(.horizontal, Layout.margin)
            } else {
                // One page, read from the top. On iPad the bottom edge is not where a thumb rests,
                // and there the number was a thousand points below the question it answers. At
                // the accessibility text sizes the number, the slider and the button took the
                // screen and the question was cut after its third line.
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        question
                        answer
                            .padding(.top, 48)
                            .padding(.bottom, 28)
                        nextButton
                    }
                    .padding(.horizontal, Layout.margin)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(.top, 8)
    }

    /// The name and the way in for someone who has an account. Side by side, or the way in under
    /// the name where the two no longer fit on a line.
    private var header: some View {
        LineOrStack(spacing: 12, lineSpacing: 0, spread: true) {
            Wordmark().foregroundStyle(Color.inkText)
            Button(action: onSignIn) {
                Text("Sign in")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkTextMuted)
                    .tapArea(.trailing)
            }
            .accessibilityIdentifier("firstRunSignIn")
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What do you think you pay for subscriptions each month?")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 36)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("firstRunQuestion")

            Text("Just guess. Don't look anything up.")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: amountText)
                .font(.total(numberSize))
                .foregroundStyle(Color.inkText)
                .contentTransition(.numericText(value: guess))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityHidden(true)

            Group {
                if Self.endsSitUnderTheTrack(largeText: typeSize.isAccessibilitySize) {
                    VStack(spacing: 4) {
                        guessSlider(Slider(value: snapped, in: 0...top) { Text("Your guess") })
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: lowest)
                            Spacer(minLength: 8)
                            Text(verbatim: highest)
                        }
                    }
                } else {
                    guessSlider(Slider(value: snapped, in: 0...top) {
                        Text("Your guess")
                    } minimumValueLabel: {
                        Text(verbatim: lowest)
                    } maximumValueLabel: {
                        Text(verbatim: highest)
                    })
                }
            }
            .font(.caption)
            .foregroundStyle(Color.inkTextFaint)
        }
        .animation(Motion.unlessReduced(Motion.touch), value: guess)
    }

    private func guessSlider(_ slider: some View) -> some View {
        slider
            .tint(Color.inkText)
            .accessibilityValue(Text(verbatim: amountText))
            .accessibilityIdentifier("guessSlider")
            .onChange(of: guess) { _, _ in Feel.selection() }
    }

    private var nextButton: some View {
        Button(action: onNext) { Text("That's my guess") }
            .buttonStyle(.ink)
            .accessibilityIdentifier("getStartedButton")
            .padding(.bottom, 12)
    }

    private var lowest: String { MoneyFormat.string(Decimal(0), currency, locale: L10n.locale, wholeUnits: true) }
    private var highest: String { MoneyFormat.string(Decimal(Int(top)), currency, locale: L10n.locale, wholeUnits: true) + "+" }

    private var onPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Whether the number, its slider and the button sit at the bottom edge, under whatever room
    /// the question leaves. On an iPhone at the ordinary text sizes, yes. On iPad and at the
    /// accessibility sizes they follow the question on one page.
    nonisolated static func answerSitsLow(onPad: Bool, largeText: Bool) -> Bool { !onPad && !largeText }

    /// Whether the lowest and highest amounts go under the slider. Beside it, at the accessibility
    /// text sizes, they left the track a third of the width: two points of travel for each step.
    nonisolated static func endsSitUnderTheTrack(largeText: Bool) -> Bool { largeText }

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

struct TallyStep: View {
    @Binding var tally: Tally
    let rates: CurrencyRates
    let onBack: () -> Void
    let onReveal: () -> Void
    let onSkip: () -> Void

    @State private var asking: TallyService?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var services: [TallyService] { TallyCatalog.services(payingIn: tally.currency) }
    /// Tiles three or four across; one service to a row at accessibility text sizes, where a name
    /// no longer fits in a third of the screen.
    private var columns: [GridItem] {
        typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: 10)]
    }

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

                    if !Self.listComesStraightAfterTheHeading(largeText: typeSize.isAccessibilitySize) {
                        addedAfterwards
                            .padding(.top, 8)
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(services) { service in
                            ServiceTile(service: service, isOn: tally.contains(service),
                                        price: tally.lines.first { $0.name == service.name }
                                            .map { MoneyFormat.string($0.amount, $0.currency, locale: L10n.locale) }) {
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
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // Said where the question comes up: at the end of the list, by someone who did
                    // not find theirs.
                    if Self.listComesStraightAfterTheHeading(largeText: typeSize.isAccessibilitySize) {
                        addedAfterwards
                            .padding(.bottom, 24)
                    }
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
        }
    }

    private var addedAfterwards: some View {
        Text("Anything missing can be added afterwards.")
            .font(.subheadline)
            .foregroundStyle(Color.inkTextMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Whether the services come straight after the heading, with "Anything missing can be added
    /// afterwards." at the end of the list. At the accessibility text sizes, yes: that sentence
    /// took three lines between the heading and the first service.
    nonisolated static func listComesStraightAfterTheHeading(largeText: Bool) -> Bool { largeText }

    /// Whether the slip at the bottom edge holds only the way on. At the accessibility text sizes,
    /// yes: with its count ("On your slip", then the number, on three lines) and a button of two
    /// lines it met the heading, and no service was left on screen to tap. Each service tapped
    /// shows its own tick and its price (`ServiceTile`).
    nonisolated static func slipHoldsOnlyTheWayOn(largeText: Bool) -> Bool { largeText }

    /// The slip, feeding out of the bottom of the screen: the last line printed, and the way on.
    private var slipBar: some View {
        let onlyTheWayOn = Self.slipHoldsOnlyTheWayOn(largeText: typeSize.isAccessibilitySize)
        return VStack(alignment: .leading, spacing: 12) {
            if let last = tally.lines.last {
                if !onlyTheWayOn {
                    ProofLine(label: last.name, value: MoneyFormat.string(last.amount, last.currency, locale: L10n.locale))
                        .id(last.name)
                        .transition(.asymmetric(insertion: .arriving(.offset(y: 8)), removal: .opacity))
                    ProofLine(label: L10n.string("On your slip"), value: L10n.number(tally.lines.count), emphasised: true)
                }
                Button(action: onReveal) { Text("Show me the total") }
                    .buttonStyle(.ink(.onPaper))
                    .accessibilityIdentifier("showTotalButton")
            } else {
                if !onlyTheWayOn {
                    Text("Your slip is empty. Tap the first thing you pay for.")
                        .font(.proof(.subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: onSkip) {
                    Text("None of these")
                        .font(.subheadline.weight(.semibold))
                        .underline()
                        .tapArea()
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
    /// What it stands at on the slip, once tapped.
    var price: String?
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    /// The tick's disc grows with its glyph: at the largest text size the glyph was twice the
    /// width of a fixed disc and hung over the tile's corner.
    @ScaledMetric(relativeTo: .caption2) private var tickSize: CGFloat = 20

    var body: some View {
        Button(action: action) {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: service.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        // What the tap put on the slip. The slip at the foot of the screen shows
                        // only the way on at these sizes, so the price is said here.
                        if isOn, let price {
                            Text(verbatim: price)
                                .font(.proof(.subheadline))
                                .foregroundStyle(Color.inkTextMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, tickSize + 8)
                } else {
                    VStack(spacing: 8) {
                        ServiceLogoView(name: service.name, category: service.category.rawValue, size: 40)
                        Text(verbatim: service.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, typeSize.isAccessibilitySize ? 14 : 6)
            .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? Layout.tapTarget : 104)
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
                        .frame(width: tickSize, height: tickSize)
                        .background(Color.paper, in: Circle())
                        .padding(8)
                        .transition(.arriving(.scale))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: service.name))
        // The price a tap puts on the slip is drawn at the foot of the screen; VoiceOver hears it here.
        .accessibilityValue(Text(verbatim: price ?? ""))
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
        ActionScreen {
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
        } actions: {
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
        }
        .task { await printSlip() }
        .sheet(item: $editing) { line in
            PriceSheet(name: line.name, placeholder: line.amount, currency: tally.currency) { amount in
                tally.setAmount(amount, for: line.name)
            }
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
                                ProofLine(label: line.name,
                                          value: MoneyFormat.string(line.amount, line.currency, locale: L10n.locale))
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

/// Correct one price on the slip.
struct PriceSheet: View {
    let name: String
    /// The price already on the slip, shown until the person types.
    let placeholder: Decimal?
    let currency: String
    let onSave: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var text = ""
    @State private var formHeight: CGFloat = 0
    @FocusState private var focused: Bool

    private var amount: Decimal? { AmountText.parse(text, currency: currency) }

    /// How tall the short sheet is: as tall as its form, once that has been measured. Until then
    /// (the first frame) it is about as tall as the form is in English at the ordinary text size.
    nonisolated static func sheetHeight(forForm measured: CGFloat) -> CGFloat {
        measured > 0 ? measured.rounded(.up) : 280
    }

    var body: some View {
        // A short sheet, as tall as what it holds: a height written as a number fitted one text
        // size and one language (300 points cut the question's first line, and 344 left a band of
        // nothing under Save). At the accessibility
        // sizes the question alone is most of a screen, so the sheet is full height and scrolls.
        ScrollView {
            form
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { formHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(Self.sheetHeight(forForm: formHeight))])
        .presentationBackground(Color.inkRaised)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            // A way out that is not a swipe: the sheet had "Save" and nothing else.
            LeaveButton("Cancel") { dismiss() }
                .accessibilityIdentifier("priceCancelButton")
            Text(L10n.string("What do you pay for \(name) each month?"))
                .font(.question(.title3))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TextField(text: $text, prompt: placeholder.map { Hint.text(MoneyFormat.string($0, currency, locale: L10n.locale)) }) { EmptyView() }
                    .keyboardType(.decimalPad)
                    .font(.proof(.title2, weight: .medium))
                    .foregroundStyle(Color.inkText)
                    .focused($focused)
                    .accessibilityLabel(Text("Price each month"))
                    .accessibilityIdentifier("priceField")
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
                .accessibilityIdentifier("priceSaveButton")
        }
        .padding(.horizontal, Layout.margin)
        .padding(.bottom, Layout.margin)
        .padding(.top, 8)
        .onAppear { focused = true }
    }
}
