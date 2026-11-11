import SwiftUI
import AuthenticationServices

// MARK: - Shared pieces

/// Why creating an account or signing in failed, in words the person can act on. Server messages are in
/// English and written for developers, so they are never shown as they come.
enum AccountProblem {
    static func signingIn(_ error: Error) -> String {
        if isOffline(error) { return L10n.string("Couldn't reach Pausely. Check your connection and try again.") }
        let text = String(describing: error).lowercased()
        if text.contains("not confirmed") || text.contains("email_not_confirmed") {
            return L10n.string("This email hasn't been confirmed yet. Create the account again to get a new code.")
        }
        return L10n.string("That email and password don't match an account. Check them, or reset your password.")
    }

    static func signingUp(_ error: Error) -> String {
        if case .ageConsentRequired = error as? PauselyAuthError {
            return L10n.string("Confirm your age before creating an account.")
        }
        return CodeProblem.sending(error)
    }

    static func apple(_ error: Error) -> String {
        isOffline(error)
            ? L10n.string("Couldn't reach Pausely. Check your connection and try again.")
            : L10n.string("Sign in with Apple didn't finish. Try again.")
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

private struct FormHeader: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.question(.title, weight: .bold))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LabelledField<Field: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.inkTextMuted)
                .accessibilityHidden(true)
            field
        }
    }
}

private struct FormProblem: View {
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
        .accessibilityIdentifier("formProblem")
    }
}

private struct OrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Hairline()
            Text("or").font(.footnote).foregroundStyle(Color.inkTextFaint)
            Hairline()
        }
        .accessibilityHidden(true)
    }
}

/// Apple's own button, sized and cornered like the app's buttons.
private struct AppleButton: View {
    let kind: SignInWithAppleButton.Label
    let identifier: String
    let onResult: (Result<(idToken: String, nonce: String, name: PersonNameComponents?), Error>) -> Void

    @State private var nonce: String?

    var body: some View {
        SignInWithAppleButton(kind, onRequest: { request in
            let fresh = AppleSignInCoordinator.generateNonce()
            nonce = fresh
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInCoordinator.sha256(fresh)
        }, onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let idToken = String(data: tokenData, encoding: .utf8),
                      let nonce else { return }
                onResult(.success((idToken, nonce, credential.fullName)))
            case .failure(let error):
                // Closing Apple's sheet is not an error.
                if (error as NSError).code != ASAuthorizationError.canceled.rawValue { onResult(.failure(error)) }
            }
        })
        .signInWithAppleButtonStyle(.white)
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Create an account

struct PremiumSignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @ObservedObject private var ageConsent = AgeConsentManager.shared
    @State private var showAgeGate = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var problem: String?
    @State private var showEmailConfirmation = false
    @State private var pendingEmail = ""
    @State private var legal: Legal?
    @FocusState private var focus: Field?

    private enum Field { case email, password }
    private enum Legal: String, Identifiable { case terms, privacy; var id: String { rawValue } }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool {
        trimmedEmail.contains("@") && trimmedEmail.contains(".") && PasswordStrength.rulesMet(password) == 4
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    FormHeader(title: "Create your account",
                               detail: "Your list is saved to your account, so it's still there if you change phones.")

                    VStack(alignment: .leading, spacing: 16) {
                        LabelledField(label: "Email") {
                            InkTextField(placeholder: "you@example.com", text: $email, keyboardType: .emailAddress, autocapitalization: .never)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .focused($focus, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focus = .password }
                                .accessibilityLabel(Text("Email"))
                                .accessibilityIdentifier("emailTextField")
                        }
                        LabelledField(label: "Password") {
                            InkTextField(placeholder: L10n.string("At least 8 characters"), text: $password, isSecure: true)
                                .textContentType(.newPassword)
                                .focused($focus, equals: .password)
                                .submitLabel(.go)
                                .onSubmit(createAccount)
                                .accessibilityLabel(Text("Password"))
                                .accessibilityIdentifier("passwordTextField")
                            if !password.isEmpty { PasswordStrengthMeter(password: password) }
                        }
                        if let problem { FormProblem(message: problem) }
                    }

                    VStack(spacing: 16) {
                        Button(action: createAccount) {
                            if isLoading { ProgressView().tint(Color.paperInk) } else { Text("Create account") }
                        }
                        .buttonStyle(.ink)
                        .disabled(!isValid || isLoading)
                        .accessibilityIdentifier("createAccountButton")

                        OrDivider()

                        AppleButton(kind: .signUp, identifier: "appleSignUpButton", onResult: finishApple)
                    }

                    Text("By creating an account you agree to the [Terms of Service](pausely-legal:terms) and the [Privacy Policy](pausely-legal:privacy).")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextFaint)
                        .tint(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .environment(\.openURL, OpenURLAction { url in
                            legal = url.absoluteString.hasSuffix("privacy") ? .privacy : .terms
                            return .handled
                        })
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
            .sheet(isPresented: $showEmailConfirmation) {
                EmailConfirmationView(email: pendingEmail)
            }
            .sheet(item: $legal) { page in
                switch page {
                case .terms: TermsOfServiceView()
                case .privacy: PrivacyPolicyView()
                }
            }
            .fullScreenCover(isPresented: $showAgeGate) {
                AgeGateView(
                    onPassed: { showAgeGate = false },
                    onCancel: {
                        showAgeGate = false
                        dismiss()
                    }
                )
                .readableWidth()
            }
            .onAppear {
                // Age is confirmed BEFORE any account can be created.
                if !ageConsent.hasPassedDeviceGate { showAgeGate = true }
            }
            .onChange(of: authManager.isAuthenticated) { _, signedIn in
                if signedIn { dismiss() }
            }
        }
    }

    private func createAccount() {
        guard isValid, !isLoading else { return }
        isLoading = true
        problem = nil
        let address = trimmedEmail
        Task {
            do {
                try await authManager.signUpWithOTP(email: address, password: password)
                if !authManager.isAuthenticated {
                    pendingEmail = address
                    showEmailConfirmation = true
                }
            } catch {
                problem = AccountProblem.signingUp(error)
            }
            isLoading = false
        }
    }

    private func finishApple(_ result: Result<(idToken: String, nonce: String, name: PersonNameComponents?), Error>) {
        switch result {
        case .success(let apple):
            isLoading = true
            problem = nil
            Task {
                do {
                    try await authManager.signInWithApple(idToken: apple.idToken, rawNonce: apple.nonce, fullName: apple.name)
                } catch {
                    problem = AccountProblem.apple(error)
                }
                isLoading = false
            }
        case .failure(let error):
            problem = AccountProblem.apple(error)
        }
    }
}

// MARK: - Sign in

struct PremiumSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var problem: String?
    @State private var showPasswordReset = false
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { trimmedEmail.contains("@") && !password.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    FormHeader(title: "Sign in")

                    VStack(alignment: .leading, spacing: 16) {
                        LabelledField(label: "Email") {
                            InkTextField(placeholder: "you@example.com", text: $email, keyboardType: .emailAddress, autocapitalization: .never)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .focused($focus, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focus = .password }
                                .accessibilityLabel(Text("Email"))
                                .accessibilityIdentifier("signInEmailTextField")
                        }
                        LabelledField(label: "Password") {
                            InkTextField(placeholder: L10n.string("Your password"), text: $password, isSecure: true)
                                .textContentType(.password)
                                .focused($focus, equals: .password)
                                .submitLabel(.go)
                                .onSubmit(signIn)
                                .accessibilityLabel(Text("Password"))
                                .accessibilityIdentifier("signInPasswordTextField")
                        }
                        if let problem { FormProblem(message: problem) }
                    }

                    VStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Button(action: signIn) {
                                if isLoading { ProgressView().tint(Color.paperInk) } else { Text("Sign in") }
                            }
                            .buttonStyle(.ink)
                            .disabled(!isValid || isLoading)
                            .accessibilityIdentifier("signInButton")

                            Button(action: { showPasswordReset = true }) {
                                Text("Forgot password?")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.inkTextMuted)
                                    .frame(maxWidth: .infinity, minHeight: Layout.tapTarget)
                            }
                            .accessibilityIdentifier("forgotPasswordButton")
                        }

                        OrDivider()

                        AppleButton(kind: .signIn, identifier: "appleSignInButton", onResult: finishApple)
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
                        .accessibilityIdentifier("signInCancelButton")
                }
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView(email: trimmedEmail)
            }
            .onChange(of: authManager.isAuthenticated) { _, signedIn in
                if signedIn { dismiss() }
            }
        }
    }

    private func signIn() {
        guard isValid, !isLoading else { return }
        isLoading = true
        problem = nil
        Task {
            do {
                try await authManager.signIn(email: trimmedEmail, password: password)
            } catch {
                problem = AccountProblem.signingIn(error)
            }
            isLoading = false
        }
    }

    private func finishApple(_ result: Result<(idToken: String, nonce: String, name: PersonNameComponents?), Error>) {
        switch result {
        case .success(let apple):
            isLoading = true
            problem = nil
            Task {
                do {
                    try await authManager.signInWithApple(idToken: apple.idToken, rawNonce: apple.nonce, fullName: apple.name)
                } catch {
                    problem = AccountProblem.apple(error)
                }
                isLoading = false
            }
        case .failure(let error):
            problem = AccountProblem.apple(error)
        }
    }
}
