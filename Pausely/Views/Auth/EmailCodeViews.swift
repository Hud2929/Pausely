import SwiftUI

// MARK: - The six-digit code

/// Six cells for an emailed code, backed by one real text field, so the keyboard's "From Mail" suggestion,
/// pasting, deleting and VoiceOver all behave the way a text field does.
struct CodeField: View {
    @Binding var code: String
    var isFocused: FocusState<Bool>.Binding

    @ScaledMetric(relativeTo: .title2) private var cellHeight: CGFloat = 56

    var body: some View {
        let digits = Array(code)
        return HStack(spacing: 8) {
            ForEach(0..<EmailCode.length, id: \.self) { index in
                let isNext = index == digits.count && isFocused.wrappedValue
                Text(index < digits.count ? String(digits[index]) : " ")
                    .font(.proof(.title2, weight: .semibold))
                    .foregroundStyle(Color.inkText)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: cellHeight)
                    .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous)
                            .stroke(isNext ? Color.white.opacity(0.45) : Color.line, lineWidth: 1)
                    )
            }
        }
        // A code reads left to right in every language.
        .environment(\.layoutDirection, .leftToRight)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityHidden(true)
        .overlay(
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused(isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .accessibilityLabel(Text("6-digit code"))
                .accessibilityValue(Text(verbatim: code.map(String.init).joined(separator: " ")))
                .accessibilityIdentifier("emailCodeField")
        )
        .onChange(of: code) { _, typed in
            let digits = EmailCode.digits(from: typed)
            if digits != typed { code = digits }
        }
        .animation(Motion.unlessReduced(Motion.touch), value: code.count)
    }
}

/// "Send a new code", which waits out the minute the account service insists on between emails.
private struct ResendButton: View {
    let countdown: ResendCountdown
    let isSending: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = countdown.secondsLeft(at: context.date)
            Button(action: action) {
                if isSending {
                    ProgressView().tint(Color.inkText)
                } else if seconds > 0 {
                    Text("Send a new code in \(seconds) s")
                } else {
                    Text("Send a new code")
                }
            }
            .buttonStyle(.ink(.quiet))
            .disabled(seconds > 0 || isSending)
            .accessibilityIdentifier("resendCodeButton")
        }
    }
}

/// The header both code screens share: what to do, and where the email went.
private struct CodeHeader: View {
    let title: LocalizedStringKey
    let email: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.question(.title, weight: .bold))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // The address sits on its own line, whole: inside a sentence it gets hyphenated at large text
            // sizes ("jane@exam-ple.com"), and where it belongs in the sentence differs by language.
            VStack(alignment: .leading, spacing: 2) {
                Text("We sent a 6-digit code to:")
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: email)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.inkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .truncationMode(.middle)
                    .environment(\.layoutDirection, .leftToRight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.body)
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// What to do when the email has a link and no code: the account emails are written outside the app, and
/// a link works as well as a code as long as it's opened on this iPhone.
private struct LinkNote: View {
    var body: some View {
        Text("No code in the email? Tap the link in it on this iPhone instead.")
            .font(.footnote)
            .foregroundStyle(Color.inkTextFaint)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProblemText: View {
    let message: String

    var body: some View {
        Label {
            Text(verbatim: message).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle")
        }
        .font(.subheadline)
        .foregroundStyle(Color.due)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("codeProblem")
    }
}

/// Why a code or an email request failed, in words the person can act on.
enum CodeProblem {
    static func verifying(_ error: Error) -> String {
        isOffline(error)
            ? L10n.string("Couldn't reach Pausely. Check your connection and try again.")
            : L10n.string("That code didn't work. Check it, or send a new one.")
    }

    static func sending(_ error: Error) -> String {
        if isOffline(error) { return L10n.string("Couldn't reach Pausely. Check your connection and try again.") }
        let text = String(describing: error).lowercased()
        if text.contains("rate") || text.contains("security purposes") || text.contains("429") {
            return L10n.string("That was too soon after the last email. Wait a minute and try again.")
        }
        return L10n.string("The email couldn't be sent. Check the address and try again.")
    }

    private static func isOffline(_ error: Error) -> Bool {
        var current: Error? = error
        while let candidate = current {
            if (candidate as NSError).domain == NSURLErrorDomain { return true }
            if case .unknown(let inner) = candidate as? PauselyAuthError { current = inner } else { current = nil }
        }
        return false
    }
}

// MARK: - Confirming a new account

/// After "Create Account": the code from the email, or the link in it, finishes the sign-up.
struct EmailConfirmationView: View {
    let email: String

    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isVerifying = false
    @State private var isSending = false
    @State private var problem: String?
    @State private var countdown = ResendCountdown(lastSent: Date())
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CodeHeader(title: "Enter the code we emailed you", email: email)
                    VStack(alignment: .leading, spacing: 12) {
                        CodeField(code: $code, isFocused: $codeFocused)
                        if let problem { ProblemText(message: problem) }
                        LinkNote()
                    }
                    VStack(spacing: 10) {
                        Button(action: verify) {
                            if isVerifying { ProgressView().tint(Color.paperInk) } else { Text("Continue") }
                        }
                        .buttonStyle(.ink)
                        .disabled(code.count < EmailCode.length || isVerifying)
                        .accessibilityIdentifier("verifyCodeButton")

                        ResendButton(countdown: countdown, isSending: isSending, action: resend)
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Use a different email") {
                        authManager.state = .unauthenticated
                        dismiss()
                    }
                    .foregroundStyle(Color.inkTextMuted)
                    .accessibilityIdentifier("differentEmailButton")
                }
            }
        }
        .interactiveDismissDisabled(isVerifying)
        .onAppear { codeFocused = true }
        .onChange(of: code) { _, typed in
            problem = nil
            if typed.count == EmailCode.length { verify() }
        }
        // The link in the email does the same job as the code; when it signs the person in, this is done.
        .onChange(of: authManager.isAuthenticated) { _, signedIn in
            if signedIn { dismiss() }
        }
    }

    private func verify() {
        guard code.count == EmailCode.length, !isVerifying else { return }
        isVerifying = true
        problem = nil
        Task {
            do {
                try await authManager.verifyEmailOTP(email: email, code: code)
                Feel.landed()
                dismiss()
            } catch {
                problem = CodeProblem.verifying(error)
                code = ""
                codeFocused = true
            }
            isVerifying = false
        }
    }

    private func resend() {
        isSending = true
        problem = nil
        Task {
            do {
                try await authManager.resendOTP(email: email)
                countdown = ResendCountdown(lastSent: Date())
                code = ""
            } catch {
                problem = CodeProblem.sending(error)
            }
            isSending = false
        }
    }
}

// MARK: - Resetting a password

/// "Forgot password": ask for the email, then take the code from it. A correct code (or the link in the
/// email) leads to `NewPasswordView`, which the root of the app presents.
struct PasswordResetView: View {
    let email: String

    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var sentTo: String?
    @State private var code = ""
    @State private var isWorking = false
    @State private var problem: String?
    @State private var countdown = ResendCountdown(lastSent: Date())
    @FocusState private var codeFocused: Bool

    private var trimmedAddress: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var addressLooksValid: Bool { trimmedAddress.contains("@") && trimmedAddress.contains(".") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let sentTo {
                        codeStep(sentTo)
                    } else {
                        addressStep
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.inkTextMuted)
                        .accessibilityIdentifier("cancelButton")
                }
            }
        }
        .onAppear { if address.isEmpty { address = email } }
        // A correct code, or the link in the email, moves on to choosing the password.
        .onChange(of: authManager.needsNewPassword) { _, needed in
            if needed { dismiss() }
        }
    }

    private var addressStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reset your password")
                    .font(.question(.title, weight: .bold))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Enter the email you signed up with. We'll send a code to prove it's you.")
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 12) {
                InkTextField(placeholder: "you@example.com", text: $address, keyboardType: .emailAddress, autocapitalization: .never)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .accessibilityLabel(Text("Email"))
                    .accessibilityIdentifier("resetEmailTextField")
                if let problem { ProblemText(message: problem) }
            }
            Button(action: send) {
                if isWorking { ProgressView().tint(Color.paperInk) } else { Text("Send code") }
            }
            .buttonStyle(.ink)
            .disabled(!addressLooksValid || isWorking)
            .accessibilityIdentifier("sendResetLinkButton")
        }
    }

    private func codeStep(_ sentTo: String) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            CodeHeader(title: "Enter the code we emailed you", email: sentTo)
            VStack(alignment: .leading, spacing: 12) {
                CodeField(code: $code, isFocused: $codeFocused)
                if let problem { ProblemText(message: problem) }
                LinkNote()
            }
            VStack(spacing: 10) {
                Button(action: verify) {
                    if isWorking { ProgressView().tint(Color.paperInk) } else { Text("Continue") }
                }
                .buttonStyle(.ink)
                .disabled(code.count < EmailCode.length || isWorking)
                .accessibilityIdentifier("verifyCodeButton")

                ResendButton(countdown: countdown, isSending: isWorking && code.isEmpty, action: send)
            }
        }
        .onAppear { codeFocused = true }
        .onChange(of: code) { _, typed in
            problem = nil
            if typed.count == EmailCode.length { verify() }
        }
    }

    private func send() {
        guard addressLooksValid, !isWorking else { return }
        isWorking = true
        problem = nil
        let target = trimmedAddress
        Task {
            do {
                try await authManager.sendPasswordReset(email: target)
                countdown = ResendCountdown(lastSent: Date())
                code = ""
                sentTo = target
            } catch {
                problem = CodeProblem.sending(error)
            }
            isWorking = false
        }
    }

    private func verify() {
        guard let sentTo, code.count == EmailCode.length, !isWorking else { return }
        isWorking = true
        problem = nil
        Task {
            do {
                try await authManager.verifyRecoveryCode(email: sentTo, code: code)
            } catch {
                problem = CodeProblem.verifying(error)
                code = ""
                codeFocused = true
            }
            isWorking = false
        }
    }
}

// MARK: - Choosing the new password

/// Shown once a reset code or link has been accepted. Saving signs the person in.
struct NewPasswordView: View {
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @State private var password = ""
    @State private var isSaving = false
    @State private var problem: String?

    private var isValid: Bool { PasswordStrength.rulesMet(password) == 4 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Choose a new password")
                            .font(.question(.title, weight: .bold))
                            .foregroundStyle(Color.inkText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("At least 8 characters, with a capital letter, a small letter and a number.")
                            .font(.body)
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        InkTextField(placeholder: L10n.string("New password"), text: $password, isSecure: true)
                            .textContentType(.newPassword)
                            .accessibilityIdentifier("newPasswordField")
                        if !password.isEmpty { PasswordStrengthMeter(password: password) }
                        if let problem { ProblemText(message: problem) }
                    }
                    Button(action: save) {
                        if isSaving { ProgressView().tint(Color.paperInk) } else { Text("Save and sign in") }
                    }
                    .buttonStyle(.ink)
                    .disabled(!isValid || isSaving)
                    .accessibilityIdentifier("saveNewPasswordButton")
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { Task { await authManager.cancelNewPassword() } }
                        .foregroundStyle(Color.inkTextMuted)
                        .accessibilityIdentifier("cancelButton")
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func save() {
        guard isValid, !isSaving else { return }
        isSaving = true
        problem = nil
        Task {
            do {
                try await authManager.setNewPassword(password)
                Feel.landed()
            } catch {
                let text = String(describing: error).lowercased()
                problem = text.contains("different from the old") || text.contains("same_password")
                    ? L10n.string("That's the password this account already has. Choose a different one.")
                    : L10n.string("The password couldn't be saved. Check your connection and try again.")
            }
            isSaving = false
        }
    }
}
