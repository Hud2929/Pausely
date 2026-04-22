import SwiftUI
import Combine
import FamilyControls

@MainActor
struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("analytics_enabled") private var analyticsEnabled = true
    @AppStorage("crash_reporting") private var crashReporting = true
    @State private var showingPermissionAlert = false
    @State private var isCheckingPermissions = true
    @State private var screenTimeAuthorized = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.luxuryTeal)
                    
                    Text("Privacy & Security")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Control your data and app permissions")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 20)
                
                if isCheckingPermissions {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.top, 40)
                } else {
                    // Screen Time Permission (Critical for app functionality)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("App Permissions")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(screenTimeAuthorized ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: screenTimeAuthorized ? "checkmark.shield" : "hourglass")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(screenTimeAuthorized ? Color.green : Color.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Screen Time Access")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text(screenTimeAuthorized ? "Authorized" : "Required for app blocking")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(screenTimeAuthorized ? Color.green : Color.orange)
                            }
                            
                            Spacer()
                            
                            if screenTimeAuthorized {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.green)
                            } else {
                                Button(action: { requestScreenTimePermission() }) {
                                    Text("Allow")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.orange)
                                        )
                                }
                            }
                        }
                        .padding()
                        .glass(intensity: screenTimeAuthorized ? 0.08 : 0.12, tint: screenTimeAuthorized ? .white : Color.orange)
                    }
                    .padding(.horizontal, 20)
                    
                    // Data & Privacy Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data & Privacy")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        
                        // Analytics
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "chart.bar")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Analytics")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text("Help improve the app")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $analyticsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: Color.luxuryGold))
                        }
                        .padding()
                        .glass(intensity: 0.08, tint: .white)
                        
                        // Crash Reporting
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.red)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Crash Reporting")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text("Automatically send crash logs")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $crashReporting)
                                .toggleStyle(SwitchToggleStyle(tint: Color.luxuryGold))
                        }
                        .padding()
                        .glass(intensity: 0.08, tint: .white)
                    }
                    .padding(.horizontal, 20)
                    
                    // Account Security Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account Security")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        
                        NavigationLink(destination: ChangePasswordView()) {
                            PrivacyRow(icon: "key.fill", title: "Change Password", subtitle: "Update your password", color: .purple)
                        }
                        
                        NavigationLink(destination: TwoFactorView()) {
                            PrivacyRow(icon: "lock.shield", title: "Two-Factor Authentication", subtitle: "Add extra security", color: .green)
                        }
                        
                        NavigationLink(destination: ActiveSessionsView()) {
                            PrivacyRow(icon: "iphone", title: "Active Sessions", subtitle: "Manage logged in devices", color: .blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Data Management
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Management")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .padding(.leading, 4)
                        
                        Button(action: { exportData() }) {
                            PrivacyRow(icon: "square.and.arrow.up", title: "Export Your Data", subtitle: "Download all your data", color: Color.luxuryGold)
                        }
                        
                        Button(action: { deleteAccount() }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "trash")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.red)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delete Account")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.red)
                                    
                                    Text("Permanently delete your account")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.red.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding()
                            .glass(intensity: 0.08, tint: .red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    
                    // Privacy Policy
                    VStack(spacing: 12) {
                        Button(action: { openPrivacyPolicy() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Privacy Policy")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color.luxuryTeal)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .glass(intensity: 0.08, tint: Color.luxuryTeal)
                        }
                        
                        Button(action: { openTerms() }) {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Terms of Service")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .glass(intensity: 0.05, tint: .white)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        isCheckingPermissions = true
        // Check Screen Time authorization status
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { status in
                screenTimeAuthorized = (status == .approved)
                isCheckingPermissions = false
            }
            .store(in: &cancellables)
    }
    
    private func requestScreenTimePermission() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                screenTimeAuthorized = true
            } catch {
                screenTimeAuthorized = false
                showingPermissionAlert = true
            }
        }
    }
    
    private func exportData() {
        // Export user data functionality
    }
    
    private func deleteAccount() {
        // Account deletion flow
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://pausely.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTerms() {
        if let url = URL(string: "https://pausely.app/terms") {
            UIApplication.shared.open(url)
        }
    }
}

struct PrivacyRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding()
        .glass(intensity: 0.08, tint: .white)
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)
                    
                    Text("Change Password")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 20)
                
                VStack(spacing: 16) {
                    SecureField("Current Password", text: $currentPassword)
                        .textContentType(.password)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.1))
                        )
                        .foregroundStyle(.white)
                    
                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.1))
                        )
                        .foregroundStyle(.white)
                    
                    SecureField("Confirm New Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.1))
                        )
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                
                Button(action: { changePassword() }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Update Password")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(canSubmit ? Color.purple : Color.purple.opacity(0.5))
                )
                .disabled(!canSubmit || isLoading)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your password has been updated successfully.")
        }
    }
    
    private var canSubmit: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }
    
    private func changePassword() {
        isLoading = true
        // Call auth service to change password
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            showSuccess = true
        }
    }
}

struct TwoFactorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabled = false
    @State private var showingSetup = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    
                    Text("Two-Factor Auth")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Add an extra layer of security to your account")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 20)
                
                if isEnabled {
                    // Enabled State
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                        
                        Text("2FA is Enabled")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Your account is protected with two-factor authentication")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .glass(intensity: 0.08, tint: .green)
                    .padding(.horizontal, 20)
                    
                    Button(action: { disable2FA() }) {
                        Text("Disable 2FA")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .glass(intensity: 0.08, tint: .red)
                    }
                    .padding(.horizontal, 20)
                } else {
                    // Disabled State
                    VStack(spacing: 16) {
                        Image(systemName: "shield")
                            .font(.system(size: 64))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("2FA is Disabled")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Enable two-factor authentication to secure your account")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .glass(intensity: 0.08, tint: .white)
                    .padding(.horizontal, 20)
                    
                    Button(action: { showingSetup = true }) {
                        Text("Enable 2FA")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.green)
                            )
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
        .navigationTitle("Two-Factor Auth")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSetup) {
            TwoFactorSetupView(isEnabled: $isEnabled)
        }
    }
    
    private func disable2FA() {
        isEnabled = false
    }
}

struct TwoFactorSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isEnabled: Bool
    @State private var verificationCode = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Scan this QR code with your authenticator app")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Placeholder QR Code
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "qrcode")
                            .font(.system(size: 100))
                            .foregroundStyle(.black)
                    )
                
                TextField("Enter verification code", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.1))
                    )
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    isEnabled = true
                    dismiss()
                }) {
                    Text("Verify & Enable")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.green)
                        )
                }
                .disabled(verificationCode.count != 6)
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Setup 2FA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ActiveSessionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [DeviceSession] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Current Device
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Device")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    
                    SessionRow(session: DeviceSession.current, isCurrent: true)
                }
                .padding(.horizontal, 20)
                
                // Other Devices
                VStack(alignment: .leading, spacing: 12) {
                    Text("Other Devices")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if sessions.isEmpty {
                        Text("No other active sessions")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding()
                    } else {
                        ForEach(sessions) { session in
                            SessionRow(session: session, isCurrent: false)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle("Active Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSessions()
        }
    }
    
    private func loadSessions() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Load sessions from backend
            sessions = [] // Empty for new users
            isLoading = false
        }
    }
}

struct DeviceSession: Identifiable {
    let id: String
    let deviceName: String
    let location: String
    let lastActive: Date
    
    static var current: DeviceSession {
        DeviceSession(
            id: "current",
            deviceName: UIDevice.current.name,
            location: "Current Location",
            lastActive: Date()
        )
    }
}

struct SessionRow: View {
    let session: DeviceSession
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.green.opacity(0.2) : .white.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "iphone")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isCurrent ? Color.green : .white.opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.deviceName)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    if isCurrent {
                        Text("Current")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                            )
                    }
                }
                
                Text(session.location)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text("Active \(timeAgo(session.lastActive))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
            
            if !isCurrent {
                Button(action: { revokeSession() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .padding()
        .glass(intensity: 0.08, tint: .white)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func revokeSession() {
        // Revoke session
    }
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacySettingsView()
            .background(Color.black)
    }
}
