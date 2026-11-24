import SwiftUI

/// The way into "Create your account": the age check first, then the form, one at a time.
///
/// The form used to open and, as it appeared, put the age check over itself. Two presentations
/// begun in the same moment can end with neither: on iPad "Keep my list" opened the form, the age
/// check failed to open over it, the form closed, and the person was back on their total with
/// nothing to show that the button had done anything. Here the age check is shown by the screen
/// underneath, and the form opens only once the check has gone.
struct SignUpDoor: ViewModifier {
    /// Set to true to start. False again when the person has left, by either way out.
    @Binding var isOpen: Bool

    @ObservedObject private var ageConsent = AgeConsentManager.shared
    @State private var showAgeCheck = false
    @State private var showForm = false

    /// What opens first. The form, when this device has already passed the age check (and for a
    /// capture of the form itself, `--demo-auth`, which exists in debug builds only: creating an
    /// account from there still asks first). Otherwise the age check.
    enum First: Equatable { case ageCheck, form }

    nonisolated static func first(agePassed: Bool, capturingTheForm: Bool) -> First {
        agePassed || capturingTheForm ? .form : .ageCheck
    }

    /// What follows the age check once it has closed: the form if the person may have an account,
    /// and nothing if they may not or chose to leave.
    nonisolated static func formFollowsTheAgeCheck(agePassed: Bool) -> Bool { agePassed }

    init(isOpen: Binding<Bool>) {
        _isOpen = isOpen
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isOpen, initial: true) { _, open in
                guard open, !showAgeCheck, !showForm else { return }
                switch Self.first(agePassed: ageConsent.hasPassedDeviceGate,
                                  capturingTheForm: LaunchFlag.value(of: "--demo-auth") != nil) {
                case .ageCheck: showAgeCheck = true
                case .form: showForm = true
                }
            }
            .fullScreenCover(isPresented: $showAgeCheck, onDismiss: {
                if Self.formFollowsTheAgeCheck(agePassed: ageConsent.hasPassedDeviceGate) {
                    showForm = true
                } else {
                    isOpen = false
                }
            }) {
                AgeGateView(onPassed: { showAgeCheck = false }, onCancel: { showAgeCheck = false })
                    .readableWidth()
            }
            .sheet(isPresented: $showForm, onDismiss: { isOpen = false }) {
                SignUpView()
            }
    }
}

extension View {
    /// Opens "Create your account" from this screen when `isOpen` becomes true (`SignUpDoor`).
    func signUpDoor(isOpen: Binding<Bool>) -> some View {
        modifier(SignUpDoor(isOpen: isOpen))
    }
}
