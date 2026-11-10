import SwiftUI
import StoreKit

// MARK: - StoreKit Upgrade View
/// Trial-first paywall optimized for conversion.
/// Leads with the free trial, states the Pausely Promise, and makes annual savings prominent.
struct StoreKitUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var storeManager = StoreKitManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var selectedPlan: PlanOption = .annual
    /// True only when StoreKit offers THIS customer a 7-day free trial on the selected plan. It is never
    /// assumed: the offer must exist in App Store Connect and the Apple Account must still be eligible
    /// (Apple allows one trial per subscription group).
    @State private var trialAvailable = false
    private var isTrialEnabled: Bool { trialAvailable }
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @AccessibilityFocusState private var focusedElement: FocusElement?

    let currentSubscriptionCount: Int

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
            case .monthly: return L10n.string("Monthly")
            case .annual: return L10n.string("Annual")
            }
        }

        var period: String {
            switch self {
            case .monthly: return L10n.string("/month")
            case .annual: return L10n.string("/year")
            }
        }

        /// "Save N%" computed from the real App Store prices; nil until StoreKit has loaded them.
        @MainActor var savings: String? {
            switch self {
            case .monthly: return nil
            case .annual:
                guard let percent = StoreKitManager.shared.annualSavingsPercent else { return nil }
                return L10n.string("Save \(percent)%")
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

    /// The App Store's own price for this storefront. Until it loads, "…": Pausely never shows a
    /// price it worked out itself, because Apple sets each country's price.
    private func priceText(_ tier: SubscriptionTier) -> String {
        storeManager.product(for: tier)?.displayPrice ?? "…"
    }

    // MARK: - The person's own numbers

    private var store: SubscriptionStore { SubscriptionStore.shared }
    private var waitingCount: Int { TallyImporter.waitingLines().count }

    private var activeSubscriptions: [Subscription] {
        store.subscriptions.filter { $0.status == .active || $0.status == .trial }
    }

    private var selectedProduct: Product? { storeManager.product(for: selectedPlan.tier) }

    /// What the selected plan costs over a year, in the App Store's currency for this customer.
    private var proYearly: (amount: Decimal, currency: String)? {
        guard let product = selectedProduct else { return nil }
        let currency = product.priceFormatStyle.currencyCode
        return (selectedPlan == .annual ? product.price : product.price * 12, currency)
    }

    private var headline: String {
        if waitingCount > 0 {
            return L10n.string("You pay for \(activeSubscriptions.count + waitingCount) subscriptions. Free watches \(FreeTier.subscriptionLimit).")
        }
        guard !activeSubscriptions.isEmpty else { return L10n.string("Pro watches every subscription you have.") }
        let yearly = MoneyFormat.string(activeSubscriptions.annualTotal(), currencyManager.selectedCurrency,
                                        locale: L10n.locale, wholeUnits: true)
        return L10n.string("Your subscriptions cost about \(yearly) a year.")
    }

    private var valueLine: String {
        let price = selectedPlan == .annual
            ? L10n.string("Pausely Pro is \(priceText(.proAnnual)) a year.")
            : L10n.string("Pausely Pro is \(priceText(.pro)) a month.")
        guard let pro = proYearly,
              let comparison = PaywallCase.comparison(proYearly: pro.amount, proCurrency: pro.currency,
                                                      subscriptions: activeSubscriptions, rates: currencyManager.rates)
        else { return price }
        let against = comparison.months == 1
            ? L10n.string("A year of it costs less than one month of \(comparison.name).")
            : L10n.string("A year of it costs less than \(comparison.months) months of \(comparison.name).")
        return price + " " + against
    }

    private var firstChargeDate: String {
        let date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
    }

    private var chargeText: String {
        priceText(selectedPlan.tier) + selectedPlan.period
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    closeRow

                    Text(verbatim: headline)
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focusedElement, equals: .title)

                    Text(verbatim: valueLine)
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    planPicker.padding(.top, 16)

                    slip.padding(.top, 20)

                    promise.padding(.top, 24).padding(.bottom, 24)
                }
                .padding(.horizontal, Layout.margin)

                // At the largest text sizes a pinned bar would cover the screen, so it scrolls.
                if typeSize.isAccessibilitySize { actionBar }
            }

            if !typeSize.isAccessibilitySize { actionBar }
        }
        .background(Color.ink.ignoresSafeArea())
        .onAppear {
            focusedElement = .title
            Task { await storeManager.loadProducts() }
        }
        .task(id: trialCheckID) { await refreshTrialEligibility() }
        .alert(Text("You have Pausely Pro"), isPresented: $showSuccessAlert) {
            Button("Continue", role: .cancel) { dismiss() }
        } message: {
            Text("Every subscription you add is watched from now on.")
        }
        .alert("Purchase Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
            if storeManager.errorMessage != nil {
                Button("Try Again") { Task { await attemptPurchase() } }
            }
            Button("Contact Support") {
                if let url = URL(string: "mailto:\(AppConfig.supportEmail)") { UIApplication.shared.open(url) }
            }
        } message: {
            Text(errorMessage)
        }
    }

    /// Always visible, never delayed.
    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(width: Layout.tapTarget, height: Layout.tapTarget, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("paywallClose")
        }
        .padding(.top, 8)
    }

    // MARK: - Pausely on its own slip

    /// Pausely's own subscription, printed the way it prints everyone else's: what is charged, and when.
    private var slip: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: "Pausely Pro")
                    .font(.question(.title3))

                if isTrialEnabled {
                    ProofLine(label: L10n.string("Today"), value: L10n.string("Free"))
                    ProofLine(label: firstChargeDate, value: chargeText, emphasised: true)
                    Text(L10n.string("Cancel before \(firstChargeDate) in Settings and you pay nothing."))
                        .font(.footnote)
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ProofLine(label: L10n.string("Today"), value: chargeText, emphasised: true)
                    if selectedPlan == .annual, let perMonth = storeManager.annualPricePerMonth {
                        Text("\(perMonth)/mo equivalent")
                            .font(.footnote)
                            .foregroundStyle(Color.paperMuted)
                    }
                }

                Perforation().padding(.vertical, 2)

                ForEach(ProFeature.allCases) { feature in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "plus")
                            .font(.footnote.weight(.bold))
                            .accessibilityHidden(true)
                        Text(verbatim: feature.title)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Plans

    private var planPicker: some View {
        VStack(spacing: 0) {
            planRow(.annual)
            Hairline()
            planRow(.monthly)
        }
    }

    private func planRow(_ plan: PlanOption) -> some View {
        let isOn = selectedPlan == plan
        return Button {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) { selectedPlan = plan }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.paper : Color.inkTextFaint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: plan.title)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                    // A price is never split across lines: it shrinks first, and at the largest
                    // text sizes the period and the saving move to their own lines.
                    if typeSize.isAccessibilitySize {
                        Text(verbatim: priceText(plan.tier))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(verbatim: plan.period)
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                        if let badge = plan.badge { badgeView(badge) }
                    } else {
                        Text(verbatim: priceText(plan.tier) + plan.period)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Spacer(minLength: 8)

                if !typeSize.isAccessibilitySize, let badge = plan.badge { badgeView(badge) }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier(plan == .annual ? "planAnnual" : "planMonthly")
    }

    private func badgeView(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.inkText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }

    // MARK: - The Promise

    private var promise: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("The Pausely Promise"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(LocalizedStringKey("Pausely keeps a receipt of what it saves you. If it doesn't save you more than it costs, it will tell you to cancel it."))
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - The action, and the terms beside it

    private var actionBar: some View {
        VStack(spacing: 10) {
            Button {
                Task { await attemptPurchase() }
            } label: {
                if storeManager.isLoading && selectedProduct != nil {
                    ProgressView().tint(Color.paperInk)
                } else {
                    Text(isTrialEnabled ? L10n.string("Start Free Trial") : L10n.string("Subscribe"))
                }
            }
            .buttonStyle(.ink)
            .disabled(selectedProduct == nil || storeManager.isLoading)
            .accessibilityIdentifier("paywallPurchase")

            Group {
                if selectedProduct == nil && !storeManager.isLoading {
                    Button {
                        Task { await storeManager.loadProducts() }
                    } label: {
                        Text("Couldn't reach the App Store. Tap to try again.").underline()
                    }
                } else if isTrialEnabled {
                    Text("After your free trial, you'll be charged \(chargeText) unless you cancel at least 24 hours before the trial ends.")
                } else {
                    Text("Subscription auto-renews. Cancel anytime in Settings → Apple ID → Subscriptions.")
                }
            }
            .font(.caption)
            .foregroundStyle(Color.inkTextMuted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            ViewThatFits {
                HStack(spacing: 16) { footerLinks }
                VStack(spacing: 4) { footerLinks }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.inkTextMuted)
        }
        .padding(.horizontal, Layout.margin)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.ink)
        .overlay(alignment: .top) { Hairline() }
    }

    @ViewBuilder private var footerLinks: some View {
        Button("Restore Purchases") { Task { await restorePurchases() } }
        Button("Terms of Service") { open(AppConfig.termsOfServiceURL) }
        Button("Privacy Policy") { open(AppConfig.privacyPolicyURL) }
    }

    private func open(_ address: String) {
        if let url = URL(string: address) { UIApplication.shared.open(url) }
    }

    // MARK: - Actions
    private func attemptPurchase() async {
        guard let product = storeManager.product(for: selectedPlan.tier) else {
            errorMessage = "Subscription not available. Please try again."
            showErrorAlert = true
            return
        }

        let success = await storeManager.purchase(product)

        if success {
            Feel.landed()
            // Pro watches everything: the lines that didn't fit under the free limit join the list.
            await TallyImporter.importWaiting(into: SubscriptionStore.shared)
            showSuccessAlert = true
        } else if let errorMsg = storeManager.errorMessage {
            errorMessage = mapStoreKitError(errorMsg)
            showErrorAlert = true
        }
    }

    private func restorePurchases() async {
        let success = await storeManager.restorePurchases()

        if success {
            Feel.landed()
            await TallyImporter.importWaiting(into: SubscriptionStore.shared)
            showSuccessAlert = true
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

// MARK: - Preview
#Preview {
    StoreKitUpgradeView(currentSubscriptionCount: 3)
}
