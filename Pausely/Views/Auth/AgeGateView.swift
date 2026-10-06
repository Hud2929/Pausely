import SwiftUI

/// Neutral age gate shown before account creation and to signed-in users who have not yet
/// confirmed their age. The birth date is only used in memory and is never stored.
struct AgeGateView: View {
    /// Called once the user is confirmed to meet the minimum age.
    let onPassed: () -> Void
    /// Optional escape hatch (e.g. cancel sign-up, or sign out for an existing user).
    var onCancel: (() -> Void)?
    var cancelTitle: String = "Cancel"

    @ObservedObject private var consent = AgeConsentManager.shared
    @State private var birthDate = AgeGateView.neutralDefaultDate
    @State private var outcome: AgeConsentManager.Outcome?
    @State private var lockoutText: String?

    /// A neutral starting date so the picker doesn't hint at the "right" answer.
    private static var neutralDefaultDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    private var isBlocked: Bool { outcome == .underAge || outcome == .lockedOut }

    var body: some View {
        ZStack {
            Color.obsidianBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: isBlocked ? "hand.raised.fill" : "calendar.badge.checkmark")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentMint)
                        .padding(.top, 48)
                        .accessibilityHidden(true)

                    if isBlocked {
                        blockedContent
                    } else {
                        formContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear(perform: refreshLockout)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Confirm your age")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                Text("Pausely is for people \(AgeConsentManager.minimumAge) and older. Enter your date of birth to continue.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            DatePicker("Date of birth",
                       selection: $birthDate,
                       in: Date.distantPast...Date(),
                       displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .accessibilityLabel("Date of birth")
                .accessibilityHint("Select the year, month and day you were born")

            if outcome == .invalidDate {
                Text("That date is in the future. Please check your date of birth.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: submit) {
                Text("Continue")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("ageGateContinueButton")
            .accessibilityHint("Confirms your age and continues")

            Text("We only use this to check eligibility. Your date of birth is not saved. We keep a record that you confirmed you are \(AgeConsentManager.minimumAge)+.")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)

            if let onCancel {
                Button(cancelTitle, action: onCancel)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .accessibilityIdentifier("ageGateCancelButton")
            }
        }
    }

    // MARK: - Blocked

    private var blockedContent: some View {
        VStack(spacing: 16) {
            Text("You can't use Pausely yet")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Pausely is only available to people \(AgeConsentManager.minimumAge) and older, so we can't create an account for you right now.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            if let lockoutText {
                Text(lockoutText)
                    .font(.footnote)
                    .foregroundStyle(Color.textTertiary)
            }
            if let onCancel {
                Button(cancelTitle, action: onCancel)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("ageGateBlockedCloseButton")
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private func submit() {
        HapticStyle.medium.trigger()
        let result = consent.evaluate(birthDate: birthDate)
        outcome = result
        switch result {
        case .allowed:
            onPassed()
        case .underAge, .lockedOut:
            HapticStyle.error.trigger()
            refreshLockout()
        case .invalidDate:
            HapticStyle.error.trigger()
        }
    }

    private func refreshLockout() {
        if let remaining = consent.lockoutRemaining() {
            outcome = .lockedOut
            let hours = max(1, Int((remaining / 3600).rounded(.up)))
            lockoutText = "You can try again in about \(hours) hour\(hours == 1 ? "" : "s")."
        } else if outcome == .lockedOut {
            outcome = nil
            lockoutText = nil
        }
    }
}

#Preview {
    AgeGateView(onPassed: {}, onCancel: {})
}
