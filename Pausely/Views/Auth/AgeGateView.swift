import SwiftUI

/// Neutral age gate shown before account creation and to signed-in users who have not yet
/// confirmed their age. The birth date is only used in memory and is never stored.
struct AgeGateView: View {
    /// Called once the user is confirmed to meet the minimum age.
    let onPassed: () -> Void
    /// Optional escape hatch (e.g. cancel sign-up, or sign out for an existing user).
    var onCancel: (() -> Void)?
    var cancelTitle: LocalizedStringKey = "Cancel"

    @ObservedObject private var consent = AgeConsentManager.shared
    @State private var birthDate = Date()
    @State private var hasPickedDate = false
    @State private var outcome: AgeConsentManager.Outcome?
    @State private var lockoutText: String?

    private var isBlocked: Bool { outcome == .underAge || outcome == .lockedOut }

    var body: some View {
        ZStack {
            ScrollView {
                // Words and one question, like every other screen: no picture standing in for them.
                Group {
                    if isBlocked {
                        blockedContent
                    } else {
                        formContent
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 48)
                .padding(.bottom, 32)
            }
            .readableScroll()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inkScreen()
        .onAppear(perform: refreshLockout)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm your age")
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Pausely is for people \(AgeConsentManager.minimumAge) and older. Enter your date of birth to continue.")
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DatePicker("Date of birth",
                       selection: $birthDate,
                       in: Date.distantPast...Date(),
                       displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .accessibilityLabel("Date of birth")
                .accessibilityHint("Select the year, month and day you were born")
                .onChange(of: birthDate) { _, _ in hasPickedDate = true }

            if outcome == .invalidDate {
                ProblemLine(message: L10n.string("That date is in the future. Please check your date of birth."))
            }

            Button(action: submit) {
                Text("Continue")
            }
            .buttonStyle(.ink)
            .disabled(!hasPickedDate)
            .accessibilityIdentifier("ageGateContinueButton")
            .accessibilityHint("Confirms your age and continues")

            Text("We only use this to check eligibility. Your date of birth is not saved. We keep a record that you confirmed you are \(AgeConsentManager.minimumAge)+.")
                .font(.footnote)
                .foregroundStyle(Color.inkTextFaint)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onCancel {
                Button(action: onCancel) {
                    Text(cancelTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkTextMuted)
                        .tapArea()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ageGateCancelButton")
            }
        }
    }

    // MARK: - Blocked

    private var blockedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You can't use Pausely yet")
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(AuthManager.shared.isAuthenticated
                 ? L10n.string("Pausely is only available to people \(AgeConsentManager.minimumAge) and older.")
                 : L10n.string("Pausely is only available to people \(AgeConsentManager.minimumAge) and older, so we can't create an account for you right now."))
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let lockoutText {
                Text(verbatim: lockoutText)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let onCancel {
                Button(cancelTitle, action: onCancel)
                    .buttonStyle(.ink)
                    .padding(.top, 12)
                    .accessibilityIdentifier("ageGateBlockedCloseButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func submit() {
        let result = consent.evaluate(birthDate: birthDate)
        outcome = result
        switch result {
        case .allowed:
            onPassed()
        case .underAge, .lockedOut:
            refreshLockout()
        case .invalidDate:
            break
        }
    }

    /// "You can try again in about 3 hours.", in the reader's language. It was built by hand in
    /// English ("hour" plus an "s"), so it stayed English everywhere.
    static func lockoutLine(remaining: TimeInterval) -> String {
        let hours = max(1, Int((remaining / 3600).rounded(.up)))
        return L10n.string("You can try again in about \(hours) hours.")
    }

    private func refreshLockout() {
        #if DEBUG
        // `--demo-age-gate=underage` and `=locked` show the two refusals without leaving a lockout
        // behind on the simulator.
        if let shown = LaunchFlag.value(of: "--demo-age-gate"), !shown.isEmpty {
            outcome = shown == "locked" ? .lockedOut : .underAge
            lockoutText = shown == "locked" ? Self.lockoutLine(remaining: 23 * 3600) : nil
            return
        }
        #endif
        if let remaining = consent.lockoutRemaining() {
            outcome = .lockedOut
            lockoutText = Self.lockoutLine(remaining: remaining)
        } else if outcome == .lockedOut {
            outcome = nil
            lockoutText = nil
        }
    }
}

#Preview {
    AgeGateView(onPassed: {}, onCancel: {})
}
