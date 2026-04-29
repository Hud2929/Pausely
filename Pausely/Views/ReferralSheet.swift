import SwiftUI

// MARK: - Referral Sheet
/// Full-screen/bottom sheet view for the referral program
struct ReferralSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var referralManager = ReferralManager.shared
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @State private var showCopiedToast = false
    @State private var appear = false
    @State private var selectedTab = 0
    @State private var isLoadingCode = true

    private var progressCount: Int {
        referralManager.referralData?.conversions ?? 0
    }

    private var isEligibleForFreePro: Bool {
        referralManager.referralData?.isEligibleForFreePro ?? false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        ReferralHeroSection(
                            isEligibleForFreePro: isEligibleForFreePro,
                            isLoadingCode: isLoadingCode,
                            displayCode: referralManager.displayCode(),
                            progressCount: progressCount,
                            isPremium: paymentManager.isPremium,
                            appear: appear,
                            onGenerateCode: generateAndSaveLocalCode,
                            onCopy: copyToClipboard,
                            onClaimFreePro: claimFreePro
                        )
                        .padding(.horizontal, 20)

                        tabSelector
                            .padding(.horizontal, 20)

                        if selectedTab == 0 {
                            ReferralFriendsSection(conversions: referralManager.conversions)
                                .padding(.horizontal, 20)
                        } else {
                            ReferralHowItWorksSection()
                                .padding(.horizontal, 20)
                        }

                        ReferralShareSection(
                            onShareMessages: { referralManager.shareViaMessages() },
                            onShareEmail: { referralManager.shareViaEmail() },
                            onShareSystem: shareViaSystem,
                            onCopyLink: copyToClipboard
                        )
                        .padding(.horizontal, 20)

                        ReferralTermsSection()

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }

                if showCopiedToast {
                    CopiedToast()
                }
            }
            .navigationTitle("Refer Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.luxuryGold)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appear = true
            }

            if let existingCode = referralManager.currentUserReferralCode, !existingCode.isEmpty {
                isLoadingCode = false
            } else {
                loadReferralCode()
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ReferralTabButton(
                title: "Friends",
                icon: "person.2",
                isSelected: selectedTab == 0
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 0
                    HapticStyle.light.trigger()
                }
            }

            ReferralTabButton(
                title: "How It Works",
                icon: "info.circle",
                isSelected: selectedTab == 1
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                    HapticStyle.light.trigger()
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.1))
        )
    }

    // MARK: - Load Referral Code

    private func loadReferralCode() {
        if let existingCode = referralManager.currentUserReferralCode, !existingCode.isEmpty {
            isLoadingCode = false
            return
        }

        if !AppSettings.shared.localReferralCode.isEmpty {
            referralManager.currentUserReferralCode = AppSettings.shared.localReferralCode
            isLoadingCode = false
            return
        }

        generateAndSaveLocalCode()

        if let userId = authManager.currentUser?.id {
            Task {
                do {
                    let serverCode = try await referralManager.getOrCreateReferralCode(for: userId)
                    await MainActor.run {
                        AppSettings.shared.localReferralCode = serverCode
                        referralManager.currentUserReferralCode = serverCode
                    }
                } catch {
                    // Keep the local code we already generated
                }
            }
        }
    }

    private func generateAndSaveLocalCode() {
        let deviceId = String(UIDevice.current.identifierForVendor?.uuidString.prefix(8) ?? "USER")
        let randomSuffix = String(format: "%04d", Int.random(in: 1000...9999))
        let localCode = "PAUSELY-\(deviceId)-\(randomSuffix)"
        referralManager.currentUserReferralCode = localCode
        AppSettings.shared.localReferralCode = localCode
        isLoadingCode = false
    }

    // MARK: - Actions

    private func copyToClipboard() {
        referralManager.copyToClipboard()
        showCopiedToast = true
        HapticStyle.success.trigger()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }

    private func claimFreePro() {
        HapticStyle.success.trigger()
        paymentManager.grantFreeProForReferrals()

        withAnimation {
            showCopiedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            dismiss()
        }
    }

    private func shareViaSystem() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        referralManager.shareViaSystem(presentingFrom: rootVC)
    }
}
