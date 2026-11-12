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
    /// Whether the selected plan starts with a free trial for this Apple Account. Nil until the App
    /// Store has said: the slip and the button wait for it, so nobody eligible for a trial is shown
    /// "Subscribe" and today's price for a moment first.
    @State private var trialAvailable: Bool?
    private var isTrialEnabled: Bool { trialAvailable == true }
    /// The plan has loaded and whether it starts free is not known yet.
    private var isCheckingOffer: Bool { selectedProduct != nil && trialAvailable == nil }
    @State private var notice: PaywallNotice?
    /// What "Try again" on a notice repeats.
    @State private var lastAttempt: Attempt = .purchase
    @State private var showSuccessAlert = false
    @AccessibilityFocusState private var focusedElement: FocusElement?

    private enum Attempt { case purchase, restore }

    enum FocusElement {
        case title
        case success
    }

    enum PlanOption {
        case monthly, annual

        var tier: SubscriptionTier {
            switch self {
            case .monthly: return .pro
            case .annual: return .proAnnual
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

        /// The store's price with its period ("$4.99/month"), the one place the two meet.
        func priced(_ amount: String) -> String {
            "\(amount)\(period)"
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
        // Another plan was picked, or the plans have just loaded: what was known is for the other one.
        trialAvailable = nil
        guard let product = storeManager.products.first(where: { $0.id == selectedPlan.productID }) else { return }
        guard let subscription = product.subscription,
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

    private var activeSubscriptions: [Subscription] { store.activeSubscriptions }

    private var selectedProduct: Product? { storeManager.product(for: selectedPlan.tier) }

    /// What the selected plan costs over a year, in the App Store's currency for this customer.
    private var proYearly: (amount: Decimal, currency: String)? {
        guard let product = selectedProduct else { return nil }
        let currency = product.priceFormatStyle.currencyCode
        return (selectedPlan == .annual ? product.price : product.price * 12, currency)
    }

    /// True when the person got here by trying to add one more than the free plan watches.
    private var atFreeLimit: Bool {
        !paymentManager.hasRoom(in: store.subscriptions)
    }

    private var headline: String {
        if waitingCount > 0 {
            return L10n.string("You pay for \(activeSubscriptions.count + waitingCount) subscriptions.") + " "
                + L10n.string("Free tracks \(FreeTier.subscriptionLimit).")
        }
        if atFreeLimit { return L10n.string("Free tracks \(FreeTier.subscriptionLimit). Pausely Pro tracks all of them.") }
        guard !activeSubscriptions.isEmpty else { return L10n.string("Pausely Pro tracks every subscription you have.") }
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

    private var firstChargeDate: String { shortDate(daysFromToday: 7) }

    /// The last day a cancellation is certain to be in time: Apple needs it at least 24 hours before
    /// the trial ends, so the day before the first charge, not the day of it.
    private var lastDayToCancel: String { shortDate(daysFromToday: 6) }

    private func shortDate(daysFromToday days: Int) -> String {
        let date = Calendar.billing.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
    }

    private var chargeText: String {
        selectedPlan.priced(priceText(selectedPlan.tier))
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
                        .accessibilityIdentifier(atFreeLimit ? "freeLimitNotice" : "paywallHeadline")

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
        .onAppear { focusedElement = .title }
        .task {
            // Prices are the App Store's. If they can't be fetched, keep asking while this screen is open.
            var wait: UInt64 = 2
            while !Task.isCancelled {
                await storeManager.loadProducts()
                if !storeManager.products.isEmpty { break }
                try? await Task.sleep(nanoseconds: wait * 1_000_000_000)
                wait = min(wait * 2, 16)
            }
        }
        .task(id: trialCheckID) { await refreshTrialEligibility() }
        .alert(Text("You have Pausely Pro"), isPresented: $showSuccessAlert) {
            Button("Continue", role: .cancel) { dismiss() }
        } message: {
            Text("Every subscription you add is tracked from now on.")
        }
        .alert(Text(verbatim: notice?.title ?? ""), isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } }),
               presenting: notice) { shown in
            Button("OK", role: .cancel) {}
            if shown.offersRetry {
                Button("Try again") {
                    Task { lastAttempt == .purchase ? await attemptPurchase() : await restorePurchases() }
                }
            }
        } message: { shown in
            Text(verbatim: shown.message)
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

                if isCheckingOffer {
                    ProofLine(label: L10n.string("Today"), value: "…", emphasised: true)
                } else if isTrialEnabled {
                    ProofLine(label: L10n.string("Today"), value: L10n.string("Free"))
                    ProofLine(label: firstChargeDate, value: chargeText, emphasised: true)
                    Text(L10n.string("Cancel by \(lastDayToCancel) in Settings and you pay nothing."))
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
                        Text(verbatim: plan.priced(priceText(plan.tier)))
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
                if (storeManager.isLoading && selectedProduct != nil) || isCheckingOffer {
                    ProgressView().tint(Color.paperInk)
                } else {
                    Text(isTrialEnabled ? L10n.string("Start free trial") : L10n.string("Subscribe"))
                }
            }
            .buttonStyle(.ink)
            .disabled(selectedProduct == nil || storeManager.isLoading || isCheckingOffer)
            .accessibilityIdentifier("paywallPurchase")

            Group {
                if selectedProduct == nil && !storeManager.isLoading {
                    Button {
                        Task { await storeManager.loadProducts() }
                    } label: {
                        Text("Couldn't reach the App Store. Tap to try again.").underline()
                    }
                } else if isCheckingOffer {
                    Text(verbatim: " ")
                } else if isTrialEnabled {
                    Text("After your free trial, you'll be charged \(chargeText) unless you cancel at least 24 hours before the trial ends.")
                } else {
                    Text("Renews automatically. To cancel, open Settings, tap your name, then Subscriptions.")
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
        Button("Restore purchases") { Task { await restorePurchases() } }
        Button("Terms of Service") { open(AppConfig.termsOfServiceURL) }
        Button("Privacy Policy") { open(AppConfig.privacyPolicyURL) }
    }

    private func open(_ address: String) {
        if let url = URL(string: address) { UIApplication.shared.open(url) }
    }

    // MARK: - Actions
    private func attemptPurchase() async {
        guard let product = storeManager.product(for: selectedPlan.tier) else { return }
        lastAttempt = .purchase
        let outcome = await storeManager.purchase(product)
        if outcome == .purchased {
            await welcomeToPro()
        } else {
            notice = PaywallNotice.after(outcome)
        }
    }

    private func restorePurchases() async {
        lastAttempt = .restore
        let outcome = await storeManager.restorePurchases()
        if outcome == .restored {
            await welcomeToPro()
        } else {
            notice = PaywallNotice.after(outcome)
        }
    }

    private func welcomeToPro() async {
        Feel.landed()
        // Pro tracks everything: the lines that didn't fit under the free limit join the list.
        await TallyImporter.importWaiting(into: SubscriptionStore.shared)
        showSuccessAlert = true
    }
}

// MARK: - Preview
#Preview {
    StoreKitUpgradeView()
}
