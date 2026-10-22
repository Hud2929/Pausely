import SwiftUI
import StoreKit

// MARK: - StoreKit Upgrade View
/// Trial-first paywall optimized for conversion.
/// Leads with free trial, shows social proof, and makes annual savings prominent.
struct StoreKitUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeManager = StoreKitManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @ObservedObject private var referralManager = ReferralManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var selectedPlan: PlanOption = .annual
    /// True only when StoreKit offers THIS customer a 7-day free trial on the selected plan. It is never
    /// assumed: the offer must exist in App Store Connect and the Apple Account must still be eligible
    /// (Apple allows one trial per subscription group).
    @State private var trialAvailable = false
    private var isTrialEnabled: Bool { trialAvailable }
    @State private var appearAnimation = false
    @State private var showConfetti = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @AccessibilityFocusState private var focusedElement: FocusElement?

    let currentSubscriptionCount: Int
    let maxFreeSubscriptions = FreeTier.subscriptionLimit

    enum FocusElement {
        case title
        case success
    }

    enum PlanOption {
        case monthly, annual

        var tier: SubscriptionTier {
            switch self {
            case .monthly: return .premium
            case .annual: return .premiumAnnual
            }
        }

        var productID: String {
            switch self {
            case .monthly: return StoreKitManager.ProductID.monthly.rawValue
            case .annual: return StoreKitManager.ProductID.annual.rawValue
            }
        }

        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .annual: return "Annual"
            }
        }

        var period: String {
            switch self {
            case .monthly: return "/month"
            case .annual: return "/year"
            }
        }

        /// "Save N%" computed from the real App Store prices; nil until StoreKit has loaded them.
        @MainActor var savings: String? {
            switch self {
            case .monthly: return nil
            case .annual:
                guard let percent = StoreKitManager.shared.annualSavingsPercent else { return nil }
                return "Save \(percent)%"
            }
        }

        @MainActor var badge: String? { savings }
    }

    /// The price Apple will actually charge in this storefront. Until StoreKit has loaded the products
    /// (the purchase button stays disabled meanwhile) it falls back to an estimate.
    private var trialCheckID: String {
        "\(storeManager.products.map(\.id).sorted().joined(separator: ","))|\(selectedPlan == .monthly)"
    }

    /// Decides whether to advertise the free trial: the selected plan must carry a 7-day free-trial
    /// introductory offer in App Store Connect and this Apple Account must still be eligible for it.
    private func refreshTrialEligibility() async {
        guard let subscription = storeManager.products.first(where: { $0.id == selectedPlan.productID })?.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            trialAvailable = false
            return
        }
        let sevenDays = (offer.period.unit == .day && offer.period.value == 7)
            || (offer.period.unit == .week && offer.period.value == 1)
        trialAvailable = sevenDays ? await subscription.isEligibleForIntroOffer : false
    }

    private func priceText(_ tier: SubscriptionTier) -> String {
        storeManager.product(for: tier)?.displayPrice ?? tier.priceInUserCurrency()
    }

    var body: some View {
        ZStack {
            // Background
            AnimatedGradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header with close button
                    headerSection

                    // Trial-first hero
                    trialHeroSection
                        .padding(.top, 16)

                    // Plan selection
                    planSelectionSection
                        .padding(.top, 24)

                    // Feature checklist
                    featureChecklistSection
                        .padding(.top, 28)

                    // Social proof & guarantee
                    socialProofSection
                        .padding(.top, 24)

                    // CTA Buttons
                    ctaSection
                        .padding(.top, 32)

                    // Legal disclosure — required by Apple and GDPR
                    legalDisclosureSection
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            focusedElement = .title

            // Load StoreKit products
            Task {
                await storeManager.loadProducts()
            }
        }
        .task(id: trialCheckID) { await refreshTrialEligibility() }
        .alert("Purchase Successful!", isPresented: $showSuccessAlert) {
            Button("Continue", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Welcome to Pausely Pro! You now have unlimited subscriptions and all premium features.")
        }
        .alert("Purchase Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
            if storeManager.errorMessage != nil {
                Button("Try Again") {
                    Task { await attemptPurchase() }
                }
            }
            Button("Contact Support") {
                if let url = URL(string: "mailto:\(AppConfig.supportEmail)") {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Spacer()

            Button(action: {
                HapticStyle.light.trigger()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(AppTypography.headlineLarge)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, 16)
    }

    // MARK: - Trial Hero Section
    private var trialHeroSection: some View {
        VStack(spacing: 12) {
            // Trial badge (only when a real trial is on offer)
            if isTrialEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                    Text(LocalizedStringKey("7-DAY FREE TRIAL"))
                        .font(.system(.caption, design: .rounded).weight(.bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.accentMint)
                )
                .scaleEffect(appearAnimation ? 1 : 0.8)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appearAnimation)
            }

            // Main headline
            Text(LocalizedStringKey(isTrialEnabled ? "Start Your 7-Day Free Trial" : "Unlock Pausely Pro"))
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .accessibilityFocused($focusedElement, equals: .title)

            // Subtitle with pricing (always uses our pricing — StoreKit sandbox prices differ from production)
            VStack(spacing: 4) {
                if isTrialEnabled {
                    Text("Then \(priceText(.pro))/month or \(priceText(.proAnnual))/year")
                        .font(AppTypography.bodyLarge)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Text(LocalizedStringKey("Cancel anytime. No charge for 7 days."))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(.accentMint)
                } else {
                    Text("\(priceText(.pro))/month or \(priceText(.proAnnual))/year")
                        .font(AppTypography.bodyLarge)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Text(LocalizedStringKey("Cancel anytime."))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(.accentMint)
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - Usage Section
    private var usageSection: some View {
        VStack(spacing: 10) {
            // Circular progress indicator
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                    .frame(width: 120, height: 120)

                // Progress arc
                Circle()
                    .trim(from: 0, to: CGFloat(min(currentSubscriptionCount, maxFreeSubscriptions)) / CGFloat(maxFreeSubscriptions))
                    .stroke(
                        AngularGradient(
                            colors: [.accentMint, .accentMint, .accentMint],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: appearAnimation)

                // Crown icon
                Image(systemName: "crown.fill")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentMint, .accentMint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .accentMint.opacity(0.5), radius: 15)
            }

            // Usage text
            Text("\(currentSubscriptionCount)/\(maxFreeSubscriptions) subscriptions used")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(.white.opacity(0.7))
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - Plan Selection Section
    private var planSelectionSection: some View {
        VStack(spacing: 12) {
            // Segmented control style toggle
            HStack(spacing: 0) {
                ForEach([PlanOption.monthly, PlanOption.annual], id: \.self) { plan in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedPlan = plan
                            HapticStyle.medium.trigger()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(plan.title)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))

                            if let badge = plan.badge {
                                Text(badge)
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentMint)
                                    .cornerRadius(4)
                            }
                        }
                        .foregroundColor(selectedPlan == plan ? .white : Color.obsidianTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            ZStack {
                                if selectedPlan == plan {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.accentMint.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.accentMint.opacity(0.6), lineWidth: 1)
                                        )
                                }
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityValue(selectedPlan == plan ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selectedPlan == plan ? .isSelected : [])
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .accessibilityElement(children: .contain)

            // Selected plan details (uses our pricing, not StoreKit sandbox prices)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if isTrialEnabled {
                        Text("Free")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("for 7 days")
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(Color.accentMint)
                    } else {
                        Text(selectedPlan == .monthly ? priceText(.pro) : priceText(.proAnnual))
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text(selectedPlan.period)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(Color.obsidianTextSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if isTrialEnabled {
                        Text("7 days free")
                            .font(.subheadline.bold())
                            .foregroundColor(.accentMint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentMint.opacity(0.15))
                            .cornerRadius(8)
                    }

                    if let savings = selectedPlan.savings {
                        Text(savings)
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }

                    if selectedPlan == .annual, let perMonth = storeManager.annualPricePerMonth {
                        Text("\(perMonth)/mo equivalent")
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(Color.obsidianTextTertiary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isTrialEnabled ? Color.accentMint.opacity(0.06) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isTrialEnabled ? Color.accentMint.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - Feature Checklist Section
    private var featureChecklistSection: some View {
        VStack(spacing: 16) {
            Text(LocalizedStringKey("What you get with Pro"))
                .font(AppTypography.headlineLarge)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(ProFeature.allCases) { feature in
                    TrialFeatureRow(icon: feature.icon, text: feature.title)
                }
                TrialFeatureRow(icon: "xmark.circle.fill", text: NSLocalizedString("Cancel anytime", comment: ""))
            }
        }
        .padding(20)
        .glass(intensity: 0.1, tint: .white)
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - Social Proof Section
    private var socialProofSection: some View {
        VStack(spacing: 12) {
            // Social proof
            HStack(spacing: 8) {
                // Avatar stack
                HStack(spacing: -8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill([
                                Color.accentMint,
                                Color.accentMint,
                                Color.accentMint
                            ][i])
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: ["person.fill", "person.fill", "person.fill"][i])
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.obsidianBlack, lineWidth: 2)
                            )
                    }
                }

                Text(LocalizedStringKey("Take control of your subscription spending"))
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)

                Spacer()
            }

        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - CTA Section
    private var ctaSection: some View {
        VStack(spacing: 16) {
            // Main CTA button
            Button(action: {
                Task {
                    await attemptPurchase()
                }
            }) {
                HStack(spacing: 10) {
                    if storeManager.isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(.title3, design: .rounded).weight(.semibold))

                        Text(isTrialEnabled ? "Start Free Trial" : "Subscribe")
                            .font(.system(.body, design: .rounded).weight(.bold))
                    }
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.accentMint)
                        .shadow(color: Color.accentMint.opacity(0.35), radius: 20, x: 0, y: 10)
                )
            }
            .disabled(storeManager.isLoading || storeManager.products.isEmpty)
            .accessibilityHint(storeManager.isLoading ? "Please wait, purchase in progress" : storeManager.products.isEmpty ? "Products are loading, please wait" : "")
            .pressEffect(scale: 0.97)

            // Restore purchases button
            Button(action: {
                Task {
                    await restorePurchases()
                }
            }) {
                Text("Restore Purchases")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.white.opacity(0.7))
                    .underline()
            }
            .disabled(storeManager.isLoading)
            .accessibilityHint(storeManager.isLoading ? "Please wait, purchase in progress" : "")

            // Terms
            Text(isTrialEnabled
                ? "Free for 7 days, then auto-renews. Cancel anytime in App Store Settings."
                : "Auto-renews. Cancel anytime in App Store Settings.")
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - Legal Disclosure
    private var legalDisclosureSection: some View {
        VStack(spacing: 8) {
            if isTrialEnabled {
                Text("After your free trial, you'll be charged \(selectedPlan == .monthly ? priceText(.pro) + "/month" : priceText(.proAnnual) + "/year") unless you cancel at least 24 hours before the trial ends.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .multilineTextAlignment(.center)
            }
            Text("Subscription auto-renews. Cancel anytime in Settings → Apple ID → Subscriptions.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.obsidianTextTertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("Terms of Service") {
                    if let url = URL(string: AppConfig.termsOfServiceURL) { UIApplication.shared.open(url) }
                }
                Text("·").foregroundStyle(Color.obsidianTextTertiary)
                Button("Privacy Policy") {
                    if let url = URL(string: AppConfig.privacyPolicyURL) { UIApplication.shared.open(url) }
                }
                Text("·").foregroundStyle(Color.obsidianTextTertiary)
                Button("Refund Policy") {
                    if let url = URL(string: AppConfig.refundPolicyURL) { UIApplication.shared.open(url) }
                }
            }
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(Color.accentMint.opacity(0.7))
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Actions
    private func attemptPurchase() async {
        HapticStyle.medium.trigger()

        guard let product = storeManager.product(for: selectedPlan.tier) else {
            HapticStyle.warning.trigger()
            errorMessage = "Subscription not available. Please try again."
            showErrorAlert = true
            return
        }

        let success = await storeManager.purchase(product)

        if success {
            showConfetti = true
            showSuccessAlert = true
            UIAccessibility.post(notification: .announcement, argument: "Purchase successful. Welcome to Pausely Pro!")

            // Dismiss after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else if let errorMsg = storeManager.errorMessage {
            errorMessage = mapStoreKitError(errorMsg)
            showErrorAlert = true
        }
    }

    private func restorePurchases() async {
        HapticStyle.medium.trigger()

        let success = await storeManager.restorePurchases()

        if success {
            showConfetti = true
            showSuccessAlert = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else if let errorMsg = storeManager.errorMessage {
            errorMessage = mapStoreKitError(errorMsg)
            showErrorAlert = true
        }
    }

    private func mapStoreKitError(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("cancel") { return "Purchase cancelled." }
        if lower.contains("network") || lower.contains("internet") { return "No internet connection. Try again." }
        if lower.contains("not allowed") || lower.contains("restricted") { return "Purchases are restricted on this device." }
        return "Purchase failed. Please try again."
    }
}

// MARK: - Trial Feature Row
struct TrialFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(Color.accentMint)

            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(.white)

            Spacer()
        }
    }
}


// MARK: - Preview
#Preview {
    StoreKitUpgradeView(currentSubscriptionCount: 3)
}
