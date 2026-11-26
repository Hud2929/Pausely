import SwiftUI
import StoreKit

// MARK: - StoreKit Upgrade View
/// Trial-first, evidence-backed paywall built on the user's own numbers and real App Store prices.
/// Leads with contextual ROI, places the Plan Picker and Pausely's transparent trial slip above the
/// fold, promises only reminders that actually fire, and completes interrupted user actions on unlock.
struct StoreKitUpgradeView: View {
    let context: PaywallContext
    var onUnlocked: (() -> Void)? = nil

    init(trigger: ProFeature? = nil, context: PaywallContext? = nil, onUnlocked: (() -> Void)? = nil) {
        self.context = context ?? PaywallContext(trigger: trigger)
        self.onUnlocked = onUnlocked
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var storeManager = StoreKitManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    private var notifications = NotificationManager.shared

    private struct PlanEligibility: Equatable {
        let trialDays: Int?
        let winBack: StoreKitManager.FreeExtensionOffer?
    }

    @State private var selectedPlan: PlanOption = .annual
    /// Cached StoreKit intro-trial and Win-Back eligibility per product ID so toggling Annual ↔ Monthly
    /// is instantaneous without collapsing the trial timeline.
    @State private var eligibilityCache: [String: PlanEligibility] = [:]
    @State private var profile = OnboardingProfile.load()
    private var currentEligibility: PlanEligibility? { eligibilityCache[selectedPlan.productID] }
    private var trialDays: Int? { currentEligibility?.trialDays }
    private var winBackOffer: StoreKitManager.FreeExtensionOffer? { currentEligibility?.winBack }
    private var isTrialEnabled: Bool { currentEligibility != nil && (trialDays ?? 0) > 0 }
    private var isWinBackFreeOffer: Bool { currentEligibility != nil && !isTrialEnabled && winBackOffer != nil }
    private var startsFree: Bool { isTrialEnabled || isWinBackFreeOffer }
    /// The plan has loaded and whether it starts free is not known yet.
    private var isCheckingOffer: Bool { selectedProduct != nil && currentEligibility == nil }
    @State private var notice: PaywallNotice?
    /// What "Try again" on a notice repeats.
    @State private var lastAttempt: Attempt = .purchase
    @State private var showSuccessAlert = false
    @State private var importedWaitingNames: [String] = []
    @State private var shouldOfferTrialReminder = false
    @AccessibilityFocusState private var focusedElement: FocusElement?

    private enum Attempt { case purchase, restore }

    enum FocusElement {
        case title
    }

    typealias PlanOption = PaywallPlanOption

    private var productIDsKey: String {
        storeManager.products.map(\.id).sorted().joined(separator: ",")
    }

    /// Pure helper: if the currently selected plan has neither an intro trial nor a Win-Back free offer
    /// while the other plan DOES, auto-select the plan that holds the free offer (e.g., a lapsed Monthly
    /// subscriber tapping "Claim free" lands directly on Monthly instead of a paid Annual plan).
    nonisolated static func preferredPlan(current: PlanOption,
                                          annualHasFreeOffer: Bool,
                                          monthlyHasFreeOffer: Bool) -> PlanOption {
        switch current {
        case .annual:
            return (!annualHasFreeOffer && monthlyHasFreeOffer) ? .monthly : .annual
        case .monthly:
            return (!monthlyHasFreeOffer && annualHasFreeOffer) ? .annual : .monthly
        }
    }

    /// Confirms free-trial eligibility and any Apple StoreKit 2 Win-Back free extension for all loaded
    /// plans at once and caches per product ID so switching Annual ↔ Monthly never collapses the slip.
    private func refreshTrialEligibility() async {
        guard !storeManager.products.isEmpty else { return }
        if LaunchFlag.isSet("--demo-no-trial") {
            var next = eligibilityCache
            for product in storeManager.products {
                next[product.id] = PlanEligibility(trialDays: nil, winBack: nil)
            }
            eligibilityCache = next
            return
        }
        var next = eligibilityCache
        for product in storeManager.products {
            if next[product.id] != nil { continue }
            var foundTrial: Int?
            if let subscription = product.subscription,
               let offer = subscription.introductoryOffer,
               offer.paymentMode == .freeTrial,
               let days = PaywallCase.trialDays(value: offer.period.value, unit: offer.period.unit) {
                if await subscription.isEligibleForIntroOffer {
                    foundTrial = days
                }
            }
            let foundWinBack: StoreKitManager.FreeExtensionOffer? = foundTrial == nil
                ? await storeManager.freeWinBackOffer(for: product)
                : nil
            next[product.id] = PlanEligibility(trialDays: foundTrial, winBack: foundWinBack)
        }
        eligibilityCache = next
        let annualHasFree = (next[PlanOption.annual.productID]?.trialDays ?? 0) > 0
            || next[PlanOption.annual.productID]?.winBack != nil
        let monthlyHasFree = (next[PlanOption.monthly.productID]?.trialDays ?? 0) > 0
            || next[PlanOption.monthly.productID]?.winBack != nil
        let target = Self.preferredPlan(current: selectedPlan,
                                        annualHasFreeOffer: annualHasFree,
                                        monthlyHasFreeOffer: monthlyHasFree)
        if target != selectedPlan {
            selectedPlan = target
        }
    }

    /// The App Store's own price for this storefront. Until it loads, "…": Pausely never shows a
    /// price it worked out itself, because Apple sets each country's price.
    private func priceText(_ tier: SubscriptionTier) -> String {
        storeManager.product(for: tier)?.displayPrice ?? "…"
    }

    // MARK: - The person's own numbers

    private var store: SubscriptionStore { SubscriptionStore.shared }
    private var activeSubscriptions: [Subscription] { store.activeSubscriptions }
    private var selectedProduct: Product? { storeManager.product(for: selectedPlan.tier) }

    /// Saved waiting lines combined with any pre-commit overflow lines passed from RevealStep or ScreenshotImportView.
    private var effectiveWaitingLines: [TallyLine] {
        var combined = TallyImporter.waitingLines()
        let seen = Set(combined.map { $0.name.lowercased() })
        for line in context.pendingWaitingLines where !seen.contains(line.name.lowercased()) {
            combined.append(line)
        }
        return combined
    }

    private var waitingCount: Int { effectiveWaitingLines.count }

    private var totalCountForWaiting: Int {
        PaywallCase.totalSubscriptions(pendingTotalCount: context.pendingTotalCount,
                                       activeCount: activeSubscriptions.count,
                                       waitingCount: waitingCount)
    }

    /// What the selected plan costs over a year, in the App Store's currency for this customer.
    private var proYearly: (amount: Decimal, currency: String)? {
        guard let product = selectedProduct else { return nil }
        let currency = product.priceFormatStyle.currencyCode
        return (selectedPlan == .annual ? product.price : product.price * 12, currency)
    }

    /// What the annual plan itself costs in StoreKit's currency (for consistent Savings Receipt comparisons).
    private var annualProductCost: (amount: Decimal, currency: String)? {
        guard let product = storeManager.product(for: .proAnnual) else { return nil }
        return (product.price, product.priceFormatStyle.currencyCode)
    }

    private var atFreeLimit: Bool {
        !paymentManager.hasRoom(in: store.subscriptions) || !context.pendingWaitingLines.isEmpty
    }

    /// Pause Plan rotation savings either passed by `PausePlanView` or computed strictly from eligible streaming services.
    private var eligiblePauseSavings: (amount: Decimal, currency: String, isConverted: Bool, names: [String])? {
        if let amount = context.pausePlanYearlySavings, let currency = context.pausePlanCurrency, amount > 0 {
            return (amount, currency, context.pausePlanIsConverted, context.pausePlanServices)
        }
        return PausePlanCard.yearlySavingsInfo(in: store.subscriptions, currency: currencyManager)
    }

    private var pauseROI: PaywallCase.PausePlanROI? {
        guard let savings = eligiblePauseSavings, let pro = proYearly else { return nil }
        return PaywallCase.pausePlanROI(yearlySavings: savings.amount, savingsCurrency: savings.currency,
                                        serviceNames: savings.names, proYearly: pro.amount,
                                        proCurrency: pro.currency, rates: currencyManager.rates)
    }

    private var waitingRisk: PaywallCase.WaitingRisk? {
        PaywallCase.waitingRisk(lines: effectiveWaitingLines,
                                displayCurrency: context.pendingCurrency ?? currencyManager.selectedCurrency,
                                proYearly: proYearly?.amount, proCurrency: proYearly?.currency,
                                rates: currencyManager.rates)
    }

    /// Always computed against the annual plan so the multiple stays consistent when toggling plans.
    private var savingsProof: PaywallCase.SavingsProof? {
        let summary = SavingsSummary.current()
        guard !summary.isEmpty, let annual = annualProductCost else { return nil }
        return PaywallCase.savingsProof(onTrack: summary.onTrack, summaryCurrency: summary.currency,
                                        isConverted: summary.totalsAreConverted, proYearly: annual.amount,
                                        proCurrency: annual.currency, rates: currencyManager.rates)
    }

    private var headline: String {
        if context.fromSavingsReceipt, let proof = savingsProof {
            let saved = MoneyFormat.total(proof.onTrack, proof.currency, converted: proof.isConverted,
                                          locale: L10n.locale, wholeUnits: true)
            return L10n.string("Your Savings Receipt is already on track to keep \(saved).")
        }
        switch context.trigger {
        case .pausePlan:
            if let savings = eligiblePauseSavings {
                let formatted = MoneyFormat.total(savings.amount, savings.currency, converted: savings.isConverted,
                                                  locale: L10n.locale, wholeUnits: true)
                return L10n.string("Keep about \(formatted) a year by rotating your streaming.")
            }
            return L10n.string("Rotate streaming with Pause Plan.")
        case .spendForecast:
            if let saved = context.simulatorYearlySavings, let currency = context.forecastCurrency, saved > 0 {
                let formatted = MoneyFormat.total(saved, currency, converted: context.forecastIsConverted,
                                                  locale: L10n.locale, wholeUnits: true)
                return L10n.string("Test cuts worth about \(formatted) a year before your next charge.")
            }
            if let month = context.forecastPeakMonth, let peak = context.forecastPeakAmount,
               let currency = context.forecastCurrency, peak > 0 {
                let formatted = MoneyFormat.total(peak, currency, converted: context.forecastIsConverted,
                                                  locale: L10n.locale, wholeUnits: true)
                return L10n.string("Your heaviest month is \(month) (\(formatted)). See all 12 months ahead.")
            }
            return L10n.string("See every renewal spike across the next 12 months.")
        case .batchScreenshotImport:
            return L10n.string("Import up to \(ScreenshotImportReadyView.proBatch) screenshots at once.")
        case .cancelConcierge:
            if let name = context.serviceName, !name.isEmpty {
                return L10n.string("Send a ready-to-go email for \(name).")
            }
            return L10n.string("Draft cancellation and refund emails in seconds.")
        case .unlimitedSubscriptions, .none:
            break
        }
        if waitingCount > 0 {
            if let risk = waitingRisk {
                let formatted = MoneyFormat.total(risk.yearlyAmount, risk.currency, converted: risk.isConverted,
                                                  locale: L10n.locale, wholeUnits: true)
                return L10n.string("Track all \(totalCountForWaiting) subscriptions — \(formatted) a year is unwatched.")
            }
            return L10n.sentences([L10n.string("You pay for \(totalCountForWaiting) subscriptions."),
                                   L10n.string("The free plan tracks \(FreeTier.subscriptionLimit).")])
        }
        if atFreeLimit {
            if let name = context.serviceName, !name.isEmpty {
                return L10n.string("Track \(name) and every other subscription you pay for.")
            }
            return L10n.string("The free plan tracks \(FreeTier.subscriptionLimit). Pausely Pro tracks all of them.")
        }
        if let proof = savingsProof {
            let saved = MoneyFormat.total(proof.onTrack, proof.currency, converted: proof.isConverted,
                                          locale: L10n.locale, wholeUnits: true)
            return L10n.string("Your Savings Receipt is already on track to keep \(saved).")
        }
        if context.fromFirstRunReveal, let savings = eligiblePauseSavings {
            let formatted = MoneyFormat.total(savings.amount, savings.currency, converted: savings.isConverted,
                                              locale: L10n.locale, wholeUnits: true)
            return L10n.string("Keep about \(formatted) a year by rotating your streaming.")
        }
        guard !activeSubscriptions.isEmpty else { return L10n.string("Pausely Pro tracks every subscription you have.") }
        let yearly = MoneyFormat.total(activeSubscriptions.annualTotal(), currencyManager.selectedCurrency,
                                       converted: activeSubscriptions.isConverted(to: currencyManager.selectedCurrency),
                                       locale: L10n.locale, wholeUnits: true)
        return L10n.string("Your subscriptions cost about \(yearly) a year.")
    }

    private var valueLine: String {
        let price = selectedPlan == .annual
            ? L10n.string("Pausely Pro is \(priceText(.proAnnual)) a year.")
            : L10n.string("Pausely Pro is \(priceText(.pro)) a month.")
        guard let pro = proYearly else { return price }

        if context.fromSavingsReceipt, let proof = savingsProof {
            let multiple = proof.multiple.formatted(.number.precision(.fractionLength(1)).locale(L10n.locale))
            return L10n.sentences([price, L10n.string("That's already \(multiple)× what an annual Pausely Pro plan costs.")])
        }
        if context.trigger == .pausePlan, let roi = pauseROI {
            if let multiple = roi.wholeMultiple {
                return L10n.sentences([price, L10n.string("Pause Plan can return about \(multiple)× what Pro costs.")])
            }
            if roi.coversPro {
                return L10n.sentences([price, L10n.string("Pause Plan can return more than a full year of Pro.")])
            }
        }
        if context.trigger == .spendForecast,
           let saved = context.simulatorYearlySavings, let currency = context.forecastCurrency,
           let roi = PaywallCase.pausePlanROI(yearlySavings: saved, savingsCurrency: currency, serviceNames: [],
                                              proYearly: pro.amount, proCurrency: pro.currency,
                                              rates: currencyManager.rates) {
            if let multiple = roi.wholeMultiple {
                return L10n.sentences([price, L10n.string("Those cuts keep about \(multiple)× what Pro costs a year.")])
            }
            if roi.coversPro {
                return L10n.sentences([price, L10n.string("Those cuts keep more than a full year of Pro.")])
            }
        }
        if context.trigger == .cancelConcierge,
           let name = context.serviceName, !name.isEmpty,
           let amount = context.serviceChargeAmount, let currency = context.serviceChargeCurrency,
           PaywallCase.singleChargeCoversPro(amount: amount, currency: currency,
                                             proYearly: pro.amount, proCurrency: pro.currency,
                                             rates: currencyManager.rates) {
            let charge = MoneyFormat.string(amount, currency, locale: L10n.locale)
            return L10n.sentences([price, L10n.string("One \(name) charge (\(charge)) is more than a full year of Pro.")])
        }
        if let risk = waitingRisk {
            let names = Array(risk.names.prefix(3)).formatted(.list(type: .and).locale(L10n.locale))
            let tail = risk.exceedsPro
                ? L10n.string("Unwatched right now: \(names) — more than a full year of Pro.")
                : L10n.string("Unwatched right now: \(names).")
            return L10n.sentences([price, tail])
        }
        if let proof = savingsProof {
            let multiple = proof.multiple.formatted(.number.precision(.fractionLength(1)).locale(L10n.locale))
            return L10n.sentences([price, L10n.string("That's already \(multiple)× what an annual Pausely Pro plan costs.")])
        }
        guard let comparison = PaywallCase.comparison(proYearly: pro.amount, proCurrency: pro.currency,
                                                      subscriptions: activeSubscriptions, rates: currencyManager.rates)
        else { return price }
        let against = comparison.months == 1
            ? L10n.string("A year of it costs less than one month of \(comparison.name).")
            : L10n.string("A year of it costs less than \(comparison.months) months of \(comparison.name).")
        return L10n.sentences([price, against])
    }

    private var activeTrialDays: Int { trialDays ?? winBackOffer?.days ?? 7 }
    /// Today is Day 1, so Day 3 is 2 calendar days from today (clamped safely for shorter trials).
    private var day3Date: String { shortDate(daysFromToday: min(2, max(1, activeTrialDays - 3))) }
    private var firstChargeDate: String { shortDate(daysFromToday: activeTrialDays) }
    /// Matches `ReminderPlanner.Kind.trialHeadsUp` (two days before trial end — safely ahead of Apple's 24h cutoff).
    private var reminderDayOffset: Int { max(1, activeTrialDays - 2) }
    private var trialReminderDate: String { shortDate(daysFromToday: reminderDayOffset) }
    private var reminderLeadDays: Int { max(1, activeTrialDays - reminderDayOffset) }
    /// The last day a cancellation is certain to be in time: Apple needs it at least 24 hours before renewal.
    private var lastDayToCancel: String { shortDate(daysFromToday: max(1, activeTrialDays - 1)) }

    private func shortDate(daysFromToday days: Int) -> String {
        let date = Calendar.billing.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return DayText.date(date, locale: L10n.locale)
    }

    private var chargeText: String {
        selectedPlan.priced(priceText(selectedPlan.tier))
    }

    var body: some View {
        ActionScreen {
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

                if prices == .known {
                    Text(verbatim: valueLine)
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    // Plan picker sits right under the ROI argument so both Annual/Monthly pricing and the
                    // top of Pausely's transparent trial receipt slip are visible above the fold on standard iPhones.
                    PaywallPlanPicker(
                        selectedPlan: $selectedPlan,
                        monthlyPrice: priceText(.pro),
                        annualPrice: priceText(.proAnnual),
                        annualPerMonth: storeManager.annualPricePerMonth,
                        annualBadge: PlanOption.annual.badge
                    )
                    .padding(.top, 12)

                    slip
                        .padding(.top, 12)
                        .padding(.bottom, linksEndThePage ? 12 : 20)
                } else {
                    pricesMissing.padding(.top, 16)
                    promiseFallback.padding(.top, 18).padding(.bottom, linksEndThePage ? 12 : 20)
                }

                if linksEndThePage {
                    LineOrStack(spacing: 16, lineSpacing: 0) { footerLinks(alignment: .leading) }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inkTextMuted)
                        .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, Layout.margin)
        } actions: {
            actionBar
        }
        .inkScreen()
        .onAppear {
            focusedElement = .title
            profile = OnboardingProfile.load()
        }
        .task {
            await notifications.refreshStatus()
            // Prices are the App Store's. If they can't be fetched, keep asking while this screen is open.
            var wait: UInt64 = 2
            while !Task.isCancelled {
                await storeManager.loadProducts()
                if !storeManager.products.isEmpty { break }
                try? await Task.sleep(nanoseconds: wait * 1_000_000_000)
                wait = min(wait * 2, 16)
            }
        }
        .task(id: productIDsKey) { await refreshTrialEligibility() }
        .alert(Text("You have Pausely Pro"), isPresented: $showSuccessAlert) {
            if shouldOfferTrialReminder {
                Button("Turn on trial reminder") {
                    Task {
                        _ = await notifications.requestPermission()
                        await ReminderScheduler.shared.reschedule(SubscriptionStore.shared.subscriptions)
                        finishUnlock()
                    }
                }
            }
            Button("Continue", role: .cancel) { finishUnlock() }
        } message: {
            if shouldOfferTrialReminder {
                if importedWaitingNames.isEmpty {
                    Text("Turn on notifications so Pausely can remind you before your free trial charges.")
                } else {
                    Text("Added \(importedWaitingNames.formatted(.list(type: .and).locale(L10n.locale))) to your list. Turn on notifications for your trial reminder.")
                }
            } else if importedWaitingNames.isEmpty {
                Text("Unlimited tracking, Pause Plan, 12-month forecast & cut simulator, batch screenshot import, and email drafts are now unlocked.")
            } else {
                Text("Added \(importedWaitingNames.formatted(.list(type: .and).locale(L10n.locale))) to your list. All Pausely Pro features are now unlocked.")
            }
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

    private func finishUnlock() {
        let callback = onUnlocked
        dismiss()
        callback?()
    }

    /// Always visible, never delayed.
    private var closeRow: some View {
        HStack {
            LeaveButton(context.fromFirstRunReveal ? "Not now" : "Close") { dismiss() }
                .accessibilityIdentifier("paywallClose")
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Pausely on its own slip

    private var trialReminderState: OnboardingProfile.TrialReminderState {
        if notifications.isAuthorized && notifications.delivery == .shown { return .ready }
        if notifications.status == .notDetermined { return .notAsked }
        return .offOrHidden
    }

    /// Pausely's own personalized Day 1 / Day 3 / Day 5 / Day 7 trial plan printed on Paper Slip,
    /// followed by transparent `ProFeature` disclosure and the Pausely Promise.
    private var slip: some View {
        let yearlySpendText: String? = activeSubscriptions.isEmpty ? nil : MoneyFormat.total(
            activeSubscriptions.annualTotal(), currencyManager.selectedCurrency,
            converted: activeSubscriptions.isConverted(to: currencyManager.selectedCurrency),
            locale: L10n.locale, wholeUnits: true
        )
        let pauseText: String? = eligiblePauseSavings.map {
            MoneyFormat.total($0.amount, $0.currency, converted: $0.isConverted, locale: L10n.locale, wholeUnits: true)
        }
        let steps = profile.trialPlanSteps(
            trialDays: activeTrialDays,
            isWinBack: isWinBackFreeOffer,
            watchedCount: max(activeSubscriptions.count, totalCountForWaiting),
            waitingCount: waitingCount,
            yearlyText: yearlySpendText,
            pauseYearlyText: pauseText,
            reminderState: trialReminderState,
            day3Date: day3Date,
            reminderDate: trialReminderDate,
            reminderLeadDays: reminderLeadDays,
            firstChargeDate: firstChargeDate,
            chargeText: chargeText,
            lastDayToCancel: lastDayToCancel
        )
        return PaywallPlanTimeline(
            isCheckingOffer: isCheckingOffer,
            isTrialEnabled: isTrialEnabled,
            isWinBackFreeOffer: isWinBackFreeOffer,
            trialDays: activeTrialDays,
            chargeText: chargeText,
            steps: steps,
            features: PaywallCase.orderedFeatures(prioritizing: context.trigger),
            trigger: context.trigger
        )
    }

    private var promiseFallback: some View {
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

    // MARK: - Before the App Store has answered

    private var prices: PaywallCase.Prices {
        PaywallCase.prices(loaded: storeManager.product(for: .pro) != nil && storeManager.product(for: .proAnnual) != nil,
                           isLoading: storeManager.isLoading)
    }

    @ViewBuilder private var pricesMissing: some View {
        if prices == .loading {
            HStack(spacing: 10) {
                ProgressView().tint(Color.inkTextMuted)
                Text("Getting the prices from the App Store…")
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        } else {
            ProblemLine(message: L10n.string("Couldn't reach the App Store, so there are no prices to show. Check your connection."),
                        identifier: "paywallNoPrices")
        }
    }

    // MARK: - The action, and the terms beside it

    private var actionBar: some View {
        VStack(spacing: 10) {
            if prices == .known {
                Button {
                    Task { await attemptPurchase() }
                } label: {
                    if (storeManager.isLoading && selectedProduct != nil) || isCheckingOffer {
                        ProgressView().tint(Color.paperInk)
                    } else if isWinBackFreeOffer, let offer = winBackOffer {
                        Text("Claim \(offer.days) more days free")
                    } else {
                        Text(isTrialEnabled ? L10n.string("Start \(activeTrialDays)-day free trial") : L10n.string("Subscribe"))
                    }
                }
                .buttonStyle(.ink)
                .disabled(selectedProduct == nil || storeManager.isLoading || isCheckingOffer)
                .accessibilityIdentifier("paywallPurchase")

                Group {
                    if isCheckingOffer {
                        Text(verbatim: " ")
                    } else if startsFree {
                        Text("After your free trial, you'll be charged \(chargeText) unless you cancel at least 24 hours before the trial ends.")
                    } else {
                        Text("You'll be charged \(chargeText). Renews automatically unless you cancel at least 24 hours before the end of the current period in Settings › Subscriptions.")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.inkTextMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    Task { await storeManager.loadProducts() }
                } label: {
                    if prices == .loading { ProgressView().tint(Color.paperInk) } else { Text("Try again") }
                }
                .buttonStyle(.ink)
                .disabled(prices == .loading)
                .accessibilityIdentifier("paywallTryAgain")
            }

            if !linksEndThePage {
                LineOrStack(spacing: 16, lineSpacing: 0, centred: true) { footerLinks(alignment: .center) }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.inkTextMuted)
            }
        }
        .padding(.horizontal, Layout.margin)
        .padding(.top, 12)
        .padding(.bottom, linksEndThePage ? 12 : 8)
        .background(Color.ink)
        .overlay(alignment: .top) { Hairline() }
    }

    /// Where the button stays at the bottom edge, the three links end the page instead of sitting
    /// under it. Where the button follows the content (accessibility sizes, iPad) they come after it.
    private var linksEndThePage: Bool {
        ActionScreen<EmptyView, EmptyView>.pinsActions(at: typeSize, onPad: UIDevice.current.userInterfaceIdiom == .pad)
    }

    /// Small words, full-size places to tap.
    @ViewBuilder private func footerLinks(alignment: Alignment) -> some View {
        Group {
            Button("Restore purchases") { Task { await restorePurchases() } }
                .disabled(storeManager.isLoading)
            Button("Terms of Service") { open(AppConfig.termsOfServiceURL) }
            Button("Privacy Policy") { open(AppConfig.privacyPolicyURL) }
        }
        .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget, alignment: alignment)
        .contentShape(Rectangle())
    }

    private func open(_ address: String) {
        if let url = URL(string: address) { UIApplication.shared.open(url) }
    }

    // MARK: - Actions

    private func attemptPurchase() async {
        guard let product = storeManager.product(for: selectedPlan.tier) else { return }
        lastAttempt = .purchase
        let outcome = await storeManager.purchase(product, winBackOffer: isWinBackFreeOffer ? winBackOffer?.offer : nil)
        if outcome == .purchased {
            await welcomeToPro(startedTrial: startsFree, isWinBack: isWinBackFreeOffer)
        } else {
            notice = PaywallNotice.after(outcome)
        }
    }

    private func restorePurchases() async {
        lastAttempt = .restore
        let outcome = await storeManager.restorePurchases()
        if outcome == .restored {
            await welcomeToPro(startedTrial: false, isWinBack: false)
        } else {
            notice = PaywallNotice.after(outcome)
        }
    }

    private func welcomeToPro(startedTrial: Bool, isWinBack: Bool) async {
        Feel.landed()
        let waiting = TallyImporter.waitingLines().map(\.name)
        // Pro tracks everything: the lines that didn't fit under the free limit join the list.
        await TallyImporter.importWaiting(into: SubscriptionStore.shared)
        // Ensure Pausely's own trial/return line is in the store before offering the reminder toggle.
        await PaymentManager.shared.autoAddPauselyProIfNeeded(readdIfRemoved: isWinBack)
        await notifications.refreshStatus()
        importedWaitingNames = waiting
        shouldOfferTrialReminder = startedTrial && notifications.status == .notDetermined
        showSuccessAlert = true
    }
}

// MARK: - Preview
#Preview {
    StoreKitUpgradeView()
}
