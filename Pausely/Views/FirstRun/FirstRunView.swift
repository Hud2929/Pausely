import SwiftUI

/// The first thing a new person sees: a guess, a tally, and the gap between them. The account
/// comes after, so the app has shown something true about their money before asking for anything.
struct FirstRunView: View {
    let onKeepList: () -> Void
    let onSignIn: () -> Void
    var onContinueWithoutAccount: (() -> Void)? = nil

    enum Phase: Int { case guess, tally, reveal }

    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var phase: Phase
    @State private var tally: Tally
    @State private var guess: Double

    init(startAt phase: Phase = .guess, tally: Tally? = nil,
         onKeepList: @escaping () -> Void, onSignIn: @escaping () -> Void,
         onContinueWithoutAccount: (() -> Void)? = nil) {
        let start = tally ?? Tally(currency: CurrencyManager.shared.selectedCurrency)
        _phase = State(initialValue: phase)
        _tally = State(initialValue: start)
        _guess = State(initialValue: NSDecimalNumber(decimal: start.guess).doubleValue)
        self.onKeepList = onKeepList
        self.onSignIn = onSignIn
        self.onContinueWithoutAccount = onContinueWithoutAccount
    }

    var body: some View {
        ZStack {
            switch phase {
            case .guess:
                GuessStep(guess: $guess, currency: tally.currency, onNext: {
                    tally.guess = Decimal(Int(guess))
                    go(.tally)
                }, onSignIn: {
                    UserDefaults.standard.removeObject(forKey: "pendingFirstRunPlan")
                    onSignIn()
                })
                .transition(stepTransition)
            case .tally:
                TallyStep(tally: $tally, onBack: { go(.guess) }, onReveal: { go(.reveal) },
                          onSkip: continueAction ?? keep)
                    .transition(stepTransition)
            case .reveal:
                RevealStep(tally: $tally, rates: currencyManager.rates,
                           onBack: { go(.tally) }, onKeep: keep,
                           onContinueWithoutAccount: continueAction)
                    .transition(stepTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inkScreen()
        .readableWidth()
        .task {
            // Pre-warm StoreKit prices on Screen 1 so the post-onboarding plan renders at 0ms.
            await StoreKitManager.shared.loadProducts()
        }
    }

    private var continueAction: (() -> Void)? {
        guard onContinueWithoutAccount != nil else { return nil }
        return { continueLocally() }
    }

    private var stepTransition: AnyTransition {
        .arriving(.offset(y: 12))
    }

    private func go(_ next: Phase) {
        Feel.selection()
        withAnimation(Motion.unlessReduced(Motion.arrive)) { phase = next }
    }

    private func keep() {
        UserDefaults.standard.set(true, forKey: "pendingFirstRunPlan")
        if tally.lines.isEmpty { PendingTally.clear() } else { PendingTally.save(tally) }
        onKeepList()
    }

    private func continueLocally() {
        UserDefaults.standard.set(true, forKey: "pendingFirstRunPlan")
        if tally.lines.isEmpty { PendingTally.clear() } else { PendingTally.save(tally) }
        onContinueWithoutAccount?()
    }
}

// MARK: - Shared by the steps

/// The way back to the step before, at the top of the tally and the reveal.
struct FirstRunBackButton: View {
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
