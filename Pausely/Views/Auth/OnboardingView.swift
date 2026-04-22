// This file is now merged into PauselyApp.swift
// Keeping this for reference, but the main OnboardingView is now in PauselyApp.swift

import SwiftUI
import LocalAuthentication

// Note: OnboardingView has been moved to PauselyApp.swift
// This file can be deleted after confirming the app compiles correctly

struct EmailConfirmationView: View {
    let email: String
    @StateObject private var authManager = RevolutionaryAuthManager.shared
    @State private var resendTimer = 60
    @State private var timer: Timer?
    @State private var showResendSuccess = false
    @State private var showCheckingEmail = false
    @State private var resendError: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.luxuryGold.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )

                    Image(systemName: "envelope.badge.shield.fill")
                        .font(.system(.largeTitle, design: .rounded).weight(.light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.luxuryGold, .white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Text
                VStack(spacing: 16) {
                    Text("Check Your Email")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text("We've sent a confirmation link to")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(email)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.luxuryGold)

                    Text("Look for an email from \(AppConfig.appName) (\(AppConfig.noreplyEmail)) with the subject \"Confirm Your Email - \(AppConfig.appName)\". Click the button to verify your account.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                    
                    // Helpful tips
                    VStack(alignment: .leading, spacing: 12) {
                        TipRow(icon: "mail.stack", text: "Check your spam/junk folder")
                        TipRow(icon: "clock", text: "The email may take a few minutes")
                        TipRow(icon: "arrow.down.circle", text: "Tap the button - it will open the app automatically")
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 32)
                    
                    // Support Contact
                    VStack(spacing: 8) {
                        Text("Didn't receive the email?")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))

                        Button(action: {
                            SupportEmailContact.supportRequest(userEmail: email, issue: "Did not receive confirmation email").openMail()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "headset")
                                Text("Contact Support")
                            }
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.luxuryGold)
                        }
                    }
                    .padding(.top, 16)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    // I've confirmed button
                    Button(action: checkConfirmation) {
                        HStack {
                            if showCheckingEmail {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text("I've confirmed my email")
                        }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.luxuryPurple, Color.luxuryPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .disabled(showCheckingEmail)
                    .accessibilityHint(showCheckingEmail ? "Please wait, checking confirmation status" : "")
                    
                    Button(action: resendEmail) {
                        HStack {
                            if resendTimer < 60 {
                                Text("Resend in \(resendTimer)s")
                                    .foregroundStyle(.white.opacity(0.5))
                            } else {
                                Text("Resend Email")
                                    .foregroundStyle(.white)
                            }
                        }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glass(intensity: 0.2, tint: .white)
                    }
                    .disabled(resendTimer < 60)
                    .accessibilityHint(resendTimer < 60 ? "Please wait \(resendTimer) seconds before resending" : "")
                    
                    Button(action: goBackToSignIn) {
                        Text("Back to Sign In")
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .errorBanner($resendError)
        .alert("Email Sent!", isPresented: $showResendSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A new confirmation email has been sent to \(email)")
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendTimer > 0 {
                resendTimer -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
    
    private func resendEmail() {
        Task {
            do {
                try await authManager.resendConfirmationEmail(email: email)
                await MainActor.run {
                    showResendSuccess = true
                    resendTimer = 60
                    startTimer()
                }
            } catch {
                #if DEBUG
                print("Resend confirmation email failed: \(error)")
                #endif
                await MainActor.run {
                    resendError = error.localizedDescription
                }
            }
        }
    }
    
    private func checkConfirmation() {
        showCheckingEmail = true
        Task {
            // Try to sign in - if email is confirmed, it will work
            await authManager.checkSession()
            await MainActor.run {
                showCheckingEmail = false
                // If authenticated, PauselyApp will automatically show MainTabView
                // dismiss() is only needed when presented as a sheet from EnhancedLoginView
                if authManager.isAuthenticated {
                    dismiss()
                }
            }
        }
    }
    
    private func goBackToSignIn() {
        // When shown as root view, change auth state to unauthenticated
        // When shown as sheet, use dismiss()
        // We can detect if we're a sheet by checking if dismiss works, but simpler to just set state
        Task {
            await MainActor.run {
                authManager.state = .unauthenticated
            }
        }
        dismiss()
    }
}

struct EmailConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailConfirmationView(email: "user@example.com")
    }
}

struct EnhancedLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isSignUp = false
    @State private var showEmailConfirmation = false
    @State private var showPasswordReset = false
    @State private var rememberMe = true
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = RevolutionaryAuthManager.shared
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    formSection
                    
                    if !errorMessage.isEmpty {
                        ErrorMessageView(message: errorMessage)
                    }
                    
                    actionButton
                    
                    if !isSignUp {
                        biometricSection
                    }
                    
                    toggleButton
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showEmailConfirmation) {
            EmailConfirmationView(email: email)
        }
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView(email: email)
        }
        .onReceive(NotificationCenter.default.publisher(for: .biometricAuthSuccess)) { notification in
            HapticStyle.success.trigger()
            if let email = notification.object as? String {
                self.email = email
                focusedField = .password
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .biometricAuthFailed)) { _ in
            HapticStyle.error.trigger()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.luxuryPurple, Color.luxuryPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.luxuryPurple.opacity(0.5), radius: 20)
                
                Image(systemName: "pause.circle.fill")
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            Text(isSignUp ? "Start managing your subscriptions" : "Sign in to continue")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 40)
    }
    
    private var formSection: some View {
        VStack(spacing: 20) {
            EnhancedTextField(
                title: "Email",
                icon: "envelope",
                text: $email,
                isSecure: false
            )
            .focused($focusedField, equals: .email)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }
            
            EnhancedTextField(
                title: "Password",
                icon: "lock",
                text: $password,
                isSecure: true
            )
            .focused($focusedField, equals: .password)
            .textContentType(isSignUp ? .newPassword : .password)
            .submitLabel(.go)
            .onSubmit {
                isSignUp ? signUp() : signIn()
            }
            
            if !isSignUp {
                HStack {
                    Toggle("Remember me", isOn: $rememberMe)
                        .toggleStyle(RememberMeToggleStyle())
                    
                    Spacer()
                    
                    Button("Forgot Password?") {
                        showPasswordReset = true
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.luxuryGold)
                }
            }
        }
    }
    
    private var actionButton: some View {
        Button(action: isSignUp ? signUp : signIn) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 8)
                }
                Text(isSignUp ? "Create Account" : "Sign In")
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.luxuryPurple, Color.luxuryPink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.luxuryPurple.opacity(0.4), radius: 15)
        }
        .disabled(email.isEmpty || password.isEmpty || isLoading)
        .accessibilityHint(email.isEmpty || password.isEmpty ? "Please enter your email and password" : isLoading ? "Please wait, signing in" : "")
        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
    }
    
    private var biometricSection: some View {
        VStack(spacing: 16) {
            HStack {
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: 1)
                
                Text("or")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
                
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: 1)
            }
            
            Button(action: attemptBiometricAuth) {
                HStack(spacing: 12) {
                    Image(systemName: biometricIcon)
                        .font(.system(.body, design: .rounded))
                    Text("Sign in with \(biometricType)")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .glass(intensity: 0.2, tint: .white)
            }
        }
    }
    
    private var toggleButton: some View {
        Button(action: {
            withAnimation {
                isSignUp.toggle()
                errorMessage = ""
            }
        }) {
            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 8)
    }
    
    private var biometricType: String {
        let context = LAContext()
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometrics"
        }
    }
    
    private var biometricIcon: String {
        let context = LAContext()
        switch context.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.shield"
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        HapticStyle.medium.trigger()
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password, rememberMe: rememberMe)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch let error as PauselyAuthError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticStyle.error.trigger()

                    if case .emailNotConfirmed = error {
                        showEmailConfirmation = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticStyle.error.trigger()
                }
            }
        }
    }
    
    private func signUp() {
        isLoading = true
        errorMessage = ""
        HapticStyle.medium.trigger()
        
        Task {
            do {
                try await authManager.signUp(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    // Only show email confirmation if not already authenticated
                    // (auth manager handles auto-confirm case by setting authenticated state)
                    if !authManager.isAuthenticated {
                        showEmailConfirmation = true
                    }
                    // If authenticated, the PauselyApp will automatically show MainTabView
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticStyle.error.trigger()
                }
            }
        }
    }

    private func attemptBiometricAuth() {
        Task {
            await authManager.attemptBiometricAuth()
        }
    }
}

struct EnhancedTextField: View {
    let title: String
    let icon: String
    @Binding var text: String
    let isSecure: Bool
    @State private var showPassword = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
            
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 24)
                
                if isSecure && !showPassword {
                    SecureField("", text: $text)
                        .foregroundStyle(.white)
                } else {
                    TextField("", text: $text)
                        .foregroundStyle(.white)
                }
                
                if isSecure {
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
            }
            .padding()
            .glass(intensity: 0.15, tint: .white)
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct RememberMeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isOn ? Color.luxuryGold : .white.opacity(0.5))
                .font(.system(.body, design: .rounded))

            Text("Remember me")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}

struct PasswordResetView: View {
    let email: String
    @State private var resetEmail: String = ""
    @State private var isLoading = false
    @State private var isSent = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = RevolutionaryAuthManager.shared
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 32) {
                if isSent {
                    successView
                } else {
                    formView
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var formView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "lock.rotation")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(Color.luxuryGold)

            VStack(spacing: 12) {
                Text("Reset Password")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            EnhancedTextField(
                title: "Email",
                icon: "envelope",
                text: $resetEmail,
                isSecure: false
            )
            
            if !errorMessage.isEmpty {
                ErrorMessageView(message: errorMessage)
            }
            
            Button(action: sendReset) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Send Reset Link")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.luxuryPurple, Color.luxuryPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(resetEmail.isEmpty || isLoading)
            .accessibilityHint(resetEmail.isEmpty ? "Please enter your email address" : isLoading ? "Please wait, sending reset link" : "")

            Button("Cancel") {
                dismiss()
            }
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
        }
    }
    
    private var successView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(Color.luxuryTeal)

            VStack(spacing: 12) {
                Text("Check Your Email")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("We've sent a password reset link to")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                Text(resetEmail)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.luxuryGold)
            }
            
            Button("Done") {
                dismiss()
            }
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.luxuryGold.opacity(0.3))
            .cornerRadius(16)
            
            Spacer()
        }
    }
    
    private func sendReset() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authManager.sendPasswordReset(email: resetEmail)
                await MainActor.run {
                    isLoading = false
                    isSent = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    HapticStyle.warning.trigger()
                }
            }
        }
    }
}

struct EnhancedLoginView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedLoginView()
    }
}


struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Color(hex: "00F0FF"))
                .frame(width: 24)

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}
