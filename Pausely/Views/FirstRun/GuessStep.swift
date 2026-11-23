import SwiftUI

/// The first run, step 1: the guess. One question, one answer on a track, before anything is asked for.
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
                        .readableScroll()
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
                .readableScroll()
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
