import StoreKit
import SwiftUI

/// Calm, honest retention & plan-management sheet shown when a paying or trial customer taps
/// "Cancel it" on Pausely Pro's slip or "Manage subscription" in Profile. Surfaces what Pausely is
/// currently guarding, offers real Apple StoreKit 2 options (switching Annual → Monthly or Monthly →
/// Annual with full Guideline 3.1.2 billing disclosure, or redeeming an offer code), and always keeps
/// a one-tap native Apple subscription sheet with zero obstruction.
struct PauselyRetentionSheet: View {
    let isTrial: Bool
    var isManaging: Bool = false

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var storeManager = StoreKitManager.shared
    @ObservedObject private var pausePlanStore = PausePlanStore.shared

    @State private var isWorking = false
    @State private var notice: String?
    @State private var managingInApple = false
    @State private var redeemingOfferCode = false
    @State private var ownSubscription: StoreKitManager.OwnSubscription?

    private var protection: ProtectionSummary {
        ProtectionSummary.current(subscriptions: store.subscriptions,
                                  displayCurrency: currencyManager.selectedCurrency,
                                  rates: currencyManager.rates)
    }

    private var monthlyProduct: Product? { storeManager.product(for: .pro) }
    private var annualProduct: Product? { storeManager.product(for: .proAnnual) }
    private var canSwitchToMonthly: Bool {
        ownSubscription != nil && paymentManager.currentTier == .proAnnual && monthlyProduct != nil
    }
    private var canSwitchToAnnual: Bool {
        ownSubscription != nil && paymentManager.currentTier == .pro && annualProduct != nil
    }

    private var headlineText: String {
        if isManaging { return L10n.string("Your Pausely Pro plan") }
        return isTrial ? L10n.string("Before you end your trial") : L10n.string("Before you cancel Pausely Pro")
    }

    private var subtitleText: String {
        if isManaging {
            return L10n.string("Change your plan, redeem an offer code, or manage billing in Apple Subscriptions.")
        }
        return L10n.string("Your list and Savings Receipt stay on this iPhone either way. Here is what changes if you return to the free plan:")
    }

    var body: some View {
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton(isManaging ? "Done" : "Keep Pausely Pro") { dismiss() }
                        .accessibilityIdentifier("retentionKeepProButton")
                    Spacer()
                }

                Text(verbatim: headlineText)
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: subtitleText)
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                impactSlip
                    .padding(.top, 18)

                if let notice {
                    ProblemLine(message: notice, identifier: "retentionNotice")
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 20)
        } actions: {
            VStack(spacing: 10) {
                if canSwitchToMonthly, let monthly = monthlyProduct {
                    let monthlyPriced = StoreKitUpgradeView.PlanOption.monthly.priced(monthly.displayPrice)
                    Button {
                        Task { await switchPlan(to: monthly) }
                    } label: {
                        if isWorking {
                            ProgressView().tint(Color.paperInk)
                        } else {
                            Text("Switch to monthly (\(monthlyPriced))")
                        }
                    }
                    .buttonStyle(.ink)
                    .disabled(isWorking)
                    .accessibilityIdentifier("retentionSwitchMonthlyButton")

                    Text("Renews at \(monthlyPriced) unless you cancel at least 24 hours before renewal in Settings › Subscriptions.")
                        .font(.caption)
                        .foregroundStyle(Color.inkTextMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else if canSwitchToAnnual, let annual = annualProduct {
                    let annualPriced = StoreKitUpgradeView.PlanOption.annual.priced(annual.displayPrice)
                    Button {
                        Task { await switchPlan(to: annual) }
                    } label: {
                        if isWorking {
                            ProgressView().tint(Color.paperInk)
                        } else if let savings = StoreKitUpgradeView.PlanOption.annual.savings {
                            Text("Switch to annual (\(annualPriced) · \(savings))")
                        } else {
                            Text("Switch to annual (\(annualPriced))")
                        }
                    }
                    .buttonStyle(.ink)
                    .disabled(isWorking)
                    .accessibilityIdentifier("retentionSwitchAnnualButton")

                    Text("Renews at \(annualPriced) unless you cancel at least 24 hours before renewal in Settings › Subscriptions.")
                        .font(.caption)
                        .foregroundStyle(Color.inkTextMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Feel.selection()
                    managingInApple = true
                } label: {
                    Text("Manage in Apple Subscriptions")
                }
                .buttonStyle(.ink(.quiet))
                .accessibilityIdentifier("retentionContinueToAppleButton")

                if !isManaging, store.subscriptions.contains(where: { $0.isPausely && $0.status != .cancelled }) {
                    Button {
                        Task {
                            isWorking = true
                            defer { isWorking = false }
                            await PaymentManager.shared.endPauselyLine()
                            dismiss()
                        }
                    } label: {
                        Text("I turned off renewal")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.inkTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                    .accessibilityIdentifier("retentionMarkedCancelledButton")
                }

                Button {
                    Feel.selection()
                    redeemingOfferCode = true
                } label: {
                    Text("Have an offer code?")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: Layout.tapTarget, minHeight: Layout.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("retentionOfferCodeButton")
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .inkScreen()
        .preferredColorScheme(.dark)
        .manageSubscriptionsSheet(isPresented: $managingInApple)
        .offerCodeRedemption(isPresented: $redeemingOfferCode)
        .onChange(of: managingInApple) { _, presented in
            if !presented {
                Task {
                    await PaymentManager.shared.updateCurrentEntitlements()
                    ownSubscription = await storeManager.ownSubscription(for: paymentManager.currentTier)
                    if !isManaging, ownSubscription?.willRenew == false || !PaymentManager.shared.isPremium {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: redeemingOfferCode) { _, presented in
            if !presented {
                Task {
                    await PaymentManager.shared.updateCurrentEntitlements()
                    ownSubscription = await storeManager.ownSubscription(for: paymentManager.currentTier)
                }
            }
        }
        .task {
            await storeManager.loadProducts()
            ownSubscription = await storeManager.ownSubscription(for: paymentManager.currentTier)
        }
    }

    private var impactSlip: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("What Pausely Pro is guarding")
                    .font(.question(.title3))

                if protection.watchedCount > 0 {
                    ProofLine(label: L10n.string("Subscriptions watched"),
                              value: L10n.number(protection.watchedCount))
                    if let yearly = protection.yearlySpend {
                        let spend = MoneyFormat.total(yearly, protection.displayCurrency,
                                                      converted: protection.isConverted,
                                                      locale: L10n.locale, wholeUnits: true)
                        ProofLine(label: L10n.string("Yearly spend watched"),
                                  value: spend,
                                  emphasised: true)
                    }
                } else {
                    Text("Your account stays ready for unlimited tracking, Pause Plan, 12-month forecast & cut simulator, batch screenshot imports, and email drafts whenever you add subscriptions.")
                        .font(.footnote)
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !isManaging, protection.overFreeLimitCount > 0 {
                    Text("Your current subscriptions stay tracked and keep getting reminders. You'll only need Pro to add new ones above \(FreeTier.subscriptionLimit).")
                        .font(.footnote)
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !isManaging, pausePlanStore.activePlan != nil {
                    Text("Your Pause Plan rotation reminders stop until Pro returns.")
                        .font(.footnote)
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else if pausePlanStore.activePlan == nil,
                          let pause = PausePlanCard.yearlySavingsInfo(in: store.subscriptions, currency: currencyManager) {
                    let formatted = MoneyFormat.string(pause.amount, pause.currency,
                                                       locale: L10n.locale, wholeUnits: true)
                    Text(L10n.string("Pause Plan can save about \(formatted) a year."))
                        .font(.footnote)
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let next = protection.nextCharge {
                    Perforation().padding(.vertical, 2)
                    ProofLine(label: L10n.string("Next reminder"),
                              value: "\(next.name) · \(DayText.date(next.date, locale: L10n.locale))")
                }
            }
        }
    }

    private func switchPlan(to product: Product) async {
        isWorking = true
        defer { isWorking = false }
        let outcome = await storeManager.purchase(product)
        if outcome == .purchased {
            await PaymentManager.shared.autoAddPauselyProIfNeeded()
            Feel.landed()
            dismiss()
        } else if outcome != .cancelled {
            notice = PaywallNotice.after(outcome)?.message
        }
    }
}
