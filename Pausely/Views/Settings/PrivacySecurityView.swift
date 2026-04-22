import SwiftUI

struct PrivacySecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var biometricEnabled = true
    @State private var faceIDEnabled = true
    @State private var dataEncryption = true
    @State private var analyticsEnabled = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    
    var body: some View {
        ZStack {
            HolographicBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(CyberColors.hotPink)
                                .accessibilityLabel("Back")
                        }
                        
                        Spacer()
                        
                        Text("Privacy & Security")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Color.clear.frame(width: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Shield Icon
                    ZStack {
                        Circle()
                            .stroke(CyberColors.hotPink, lineWidth: 2)
                            .frame(width: 100, height: 100)
                            .shadow(color: CyberColors.hotPink.opacity(0.5), radius: 20, x: 0, y: 0)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.title)
                            .foregroundColor(CyberColors.hotPink)
                    }
                    .padding(.top, 20)
                    
                    // Security Section
                    VStack(spacing: 16) {
                        Text("SECURITY")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        FuturisticGlassCard(glowColor: CyberColors.hotPink) {
                            VStack(spacing: 0) {
                                SecurityToggleRow(
                                    icon: "touchid",
                                    title: "Biometric Authentication",
                                    subtitle: "Use Face ID or Touch ID",
                                    isOn: $biometricEnabled,
                                    glowColor: CyberColors.hotPink,
                                    onToggle: { isOn in
                                        if isOn {
                                            HapticStyle.medium.trigger()
                                        } else {
                                            HapticStyle.light.trigger()
                                        }
                                    }
                                )
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                SecurityToggleRow(
                                    icon: "faceid",
                                    title: "Face ID",
                                    subtitle: "Enable Face ID for app access",
                                    isOn: $faceIDEnabled,
                                    glowColor: CyberColors.cyan,
                                    onToggle: { isOn in
                                        if isOn {
                                            HapticStyle.medium.trigger()
                                        } else {
                                            HapticStyle.light.trigger()
                                        }
                                    }
                                )
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                SecurityToggleRow(
                                    icon: "lock.fill",
                                    title: "End-to-End Encryption",
                                    subtitle: "Your data is always encrypted",
                                    isOn: $dataEncryption,
                                    glowColor: CyberColors.lime
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Privacy Section
                    VStack(spacing: 16) {
                        Text("PRIVACY")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        FuturisticGlassCard(glowColor: CyberColors.electric) {
                            VStack(spacing: 0) {
                                SecurityToggleRow(
                                    icon: "chart.bar.fill",
                                    title: "Analytics",
                                    subtitle: "Help improve the app with usage data",
                                    isOn: $analyticsEnabled,
                                    glowColor: CyberColors.electric
                                )
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                NavigationButton(
                                    icon: "doc.text.fill",
                                    title: "Privacy Policy",
                                    glowColor: CyberColors.cyan
                                ) {
                                    showingPrivacyPolicy = true
                                }

                                Divider().background(Color.white.opacity(0.1))

                                NavigationButton(
                                    icon: "doc.fill",
                                    title: "Terms of Service",
                                    glowColor: CyberColors.magenta
                                ) {
                                    showingTermsOfService = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Danger Zone
                    VStack(spacing: 16) {
                        Text("DANGER ZONE")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.red.opacity(0.7))
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        FuturisticGlassCard(glowColor: .red) {
                            VStack(spacing: 16) {
                                Text("Delete Account")
                                    .font(.callout.weight(.bold))
                                    .foregroundColor(.red)
                                
                                Text("This will permanently delete all your data. This action cannot be undone.")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                
                                Button(action: { showingDeleteAccountConfirmation = true }) {
                                    Text("DELETE ACCOUNT")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.red, lineWidth: 2)
                                                .background(.red.opacity(0.1))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .alert("Delete Account?", isPresented: $showingDeleteAccountConfirmation) {
                                    Button("Cancel", role: .cancel) { }
                                    Button("Delete", role: .destructive) {
                                        // Account deletion logic would go here
                                    }
                                } message: {
                                    Text("This will permanently delete all your data. This action cannot be undone.")
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
    }
}

struct SecurityToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let glowColor: Color
    var onToggle: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(glowColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(glowColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            CyberToggle(isOn: $isOn, glowColor: glowColor, onToggle: onToggle)
        }
        .padding(.vertical, 12)
    }
}

struct NavigationButton: View {
    let icon: String
    let title: String
    let glowColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(glowColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundColor(glowColor)
                }
                
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PrivacySecurityView()
}
