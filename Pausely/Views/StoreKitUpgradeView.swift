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
    @State private var appearAnimation = false
    @State private var showConfetti = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @AccessibilityFocusState private var focusedElement: FocusElement?

    let currentSubscriptionCount: Int
    let maxFreeSubscriptions = 2

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

        var savings: String? {
            switch self {
            case .monthly: return nil
            case .annual: return "Save 37%"
            }
        }

        var badge: String? {
            switch self {
            case .monthly: return nil
            case .annual: return "Save 37%"
            }
        }
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

                    // Usage indicator (subtle, not the main focus)
                    usageSection
                        .padding(.top, 20)

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
                    Task {
                        await attemptPurchase()
                    }
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
            // Trial badge
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(LocalizedStringKey("7-DAY FREE TRIAL"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.luxuryGold)
            )
            .scaleEffect(appearAnimation ? 1 : 0.8)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appearAnimation)

            // Main headline
            Text(LocalizedStringKey("Start Your 7-Day Free Trial"))
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .accessibilityFocused($focusedElement, equals: .title)

            // Subtitle with pricing
            VStack(spacing: 4) {
                Text("Then \(SubscriptionTier.pro.priceInUserCurrency())/month or \(SubscriptionTier.proAnnual.priceInUserCurrency())/year")
                    .font(AppTypography.bodyLarge)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Text(LocalizedStringKey("Cancel anytime. No charge for 7 days."))
                    .font(AppTypography.bodySmall)
                    .foregroundColor(.luxuryGold)
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
                            colors: [.luxuryGold, .luxuryPink, .luxuryPurple],
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
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.luxuryGold, .luxuryPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .luxuryGold.opacity(0.5), radius: 15)
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
                                .font(.system(size: 15, weight: .semibold, design: .rounded))

                            if let badge = plan.badge {
                                Text(badge)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.luxuryGold)
                                    .cornerRadius(4)
                            }
                        }
                        .foregroundColor(selectedPlan == plan ? .white : TextColors.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            ZStack {
                                if selectedPlan == plan {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.luxuryPurple.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.luxuryPurple.opacity(0.6), lineWidth: 1)
                                        )
                                }
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .accessibilityElement(children: .contain)

            // Selected plan details
            if let product = storeManager.product(for: selectedPlan.tier) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text(selectedPlan.period)
                            .font(AppTypography.bodySmall)
                            .foregroundStyle(TextColors.secondary)
                    }

                    Spacer()

                    if let savings = selectedPlan.savings {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(savings)
                                .font(.subheadline.bold())
                                .foregroundColor(.green)

                            if selectedPlan == .annual {
                                Text("$\(String(format: "%.2f", Double(truncating: product.price as NSNumber) / 12))/mo equivalent")
                                    .font(AppTypography.labelMedium)
                                    .foregroundStyle(TextColors.tertiary)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
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
                TrialFeatureRow(icon: "infinity", text: NSLocalizedString("Unlimited subscriptions", comment: ""))
                TrialFeatureRow(icon: "chart.bar.fill", text: NSLocalizedString("Cost-per-use analytics", comment: ""))
                TrialFeatureRow(icon: "bell.badge.fill", text: NSLocalizedString("Smart renewal alerts", comment: ""))
                TrialFeatureRow(icon: "clock.arrow.circlepath", text: NSLocalizedString("Usage tracking", comment: ""))
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
                                Color.luxuryPurple,
                                Color.luxuryPink,
                                Color.luxuryTeal
                            ][i])
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: ["person.fill", "person.fill", "person.fill"][i])
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.deepBlack, lineWidth: 2)
                            )
                    }
                }

                Text(LocalizedStringKey("Join 10,000+ users managing their subscriptions"))
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)

                Spacer()
            }

            // Money-back guarantee
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.luxuryGold)

                Text(LocalizedStringKey("30-day money-back guarantee"))
                    .font(AppTypography.bodySmall)
                    .foregroundColor(Color.luxuryGold)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.luxuryGold.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.luxuryGold.opacity(0.2), lineWidth: 1)
                    )
            )
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
                            .font(.system(size: 20, weight: .semibold))

                        Text("Start Free Trial")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.luxuryGold, .luxuryPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .shadow(color: Color.luxuryGold.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .disabled(storeManager.isLoading || storeManager.products.isEmpty)
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

            // Terms
            Text("Free for 7 days, then auto-renews. Cancel anytime in App Store Settings.")
                .font(AppTypography.labelMedium)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - Actions
    private func attemptPurchase() async {
        HapticStyle.medium.trigger()

        guard let product = storeManager.product(for: selectedPlan.tier) else {
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
            errorMessage = errorMsg
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
            errorMessage = errorMsg
            showErrorAlert = true
        }
    }
}

// MARK: - Trial Feature Row
struct TrialFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.luxuryGold)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white)

            Spacer()
        }
    }
}

// MARK: - StoreKit Plan Card (kept for backward compatibility)
struct StoreKitPlanCard: View {
    let product: Product
    let plan: StoreKitUpgradeView.PlanOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.luxuryGold : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Circle()
                            .fill(Color.luxuryGold)
                            .frame(width: 18, height: 18)

                        Image(systemName: "checkmark")
                            .font(AppTypography.labelSmall)
                            .foregroundStyle(.black)
                    }
                }

                // Plan info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(AppTypography.headlineMedium)
                            .foregroundStyle(.white)

                        if let badge = plan.badge {
                            Text(badge)
                                .font(AppTypography.labelSmall)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.luxuryGold)
                                .cornerRadius(6)
                        }
                    }

                    if let savings = plan.savings {
                        Text(savings)
                            .font(AppTypography.labelMedium)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                // Price from StoreKit
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(AppTypography.headlineLarge)
                        .foregroundStyle(.white)

                    Text(plan.period)
                        .font(AppTypography.labelMedium)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.luxuryPurple.opacity(0.3) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isSelected ? Color.luxuryGold : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Feature Row Upgrade (kept for backward compatibility)
struct FeatureRowUpgrade: View {
    let icon: String
    let title: String
    let subtitle: String
    let isPremium: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.luxuryGold.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(.luxuryGold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.headlineSmall)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(AppTypography.labelMedium)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            if isPremium {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    StoreKitUpgradeView(currentSubscriptionCount: 3)
}
