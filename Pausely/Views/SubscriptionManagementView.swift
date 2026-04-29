import SwiftUI

enum ManagementSheet: Identifiable {
    case paywall
    case alternative(AlternativeService)
    case smartPause(PauseSuggestion, () -> Void)
    case usageInput(String, Int, (Int) -> Void)
    case usageHistory(String)
    case sharing(Subscription)
    case priceHistory(Subscription)
    case annualSavings(Subscription)
    case cancellationRequest(Subscription)

    var id: String {
        switch self {
        case .paywall: return "paywall"
        case .alternative(let alt): return "alt-\(alt.id)"
        case .smartPause(let s, _): return "smartPause-\(s.id)"
        case .usageInput(let name, _, _): return "usageInput-\(name)"
        case .usageHistory(let name): return "history-\(name)"
        case .sharing(let sub): return "sharing-\(sub.id)"
        case .priceHistory(let sub): return "priceHistory-\(sub.id)"
        case .annualSavings(let sub): return "annualSavings-\(sub.id)"
        case .cancellationRequest(let sub): return "cancelReq-\(sub.id)"
        }
    }
}

enum ManagementAlert: Identifiable {
    case cancel(String, () -> Void)
    case pause(String, () -> Void)

    var id: String {
        switch self {
        case .cancel: return "cancel"
        case .pause: return "pause"
        }
    }
}

struct SubscriptionManagementView: View {
    let subscription: Subscription
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var actionManager = SubscriptionActionManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var activeSheet: ManagementSheet?
    @State private var activeAlert: ManagementAlert?

    var alternatives: [AlternativeService] {
        SubscriptionActionManager.shared.findAlternatives(for: subscription)
    }

    var currentUsageMinutes: Int {
        screenTimeManager.getCurrentMonthUsage(for: subscription.name)
    }

    var costPerHour: Decimal? {
        screenTimeManager.calculateCostPerHour(monthlyCost: subscription.monthlyCost, subscriptionName: subscription.name)
    }

    var smartSuggestion: PauseSuggestion? {
        screenTimeManager.shouldSuggestPause(for: subscription, thresholdMinutes: 60)
    }

    var usageStats: AppUsageStats? {
        screenTimeManager.getUsageStats(for: subscription.name)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ManagementHeaderSection(
                    subscription: subscription,
                    currentUsageMinutes: currentUsageMinutes,
                    usageStats: usageStats,
                    costPerHour: costPerHour,
                    difficulty: actionManager.getCancellationDifficulty(for: subscription),
                    screenTimeManager: screenTimeManager
                )

                BillingDateSection(subscription: subscription)

                if let suggestion = smartSuggestion, subscription.isActive {
                    SmartPauseSection(
                        subscription: subscription,
                        suggestion: suggestion,
                        onInfoTap: {
                            activeSheet = .smartPause(suggestion, {
                                activeAlert = .pause(subscription.name, { openPauseURL() })
                            })
                        }
                    )
                }

                CostPerUseDetailSection(subscription: subscription)

                UsageTrackingSection(
                    subscription: subscription,
                    screenTimeManager: screenTimeManager,
                    currentUsageMinutes: currentUsageMinutes,
                    costPerHour: costPerHour,
                    usageStats: usageStats,
                    onEditUsage: {
                        activeSheet = .usageInput(
                            subscription.name,
                            currentUsageMinutes,
                            { minutes in screenTimeManager.setMonthlyUsage(minutes: minutes, for: subscription.name) }
                        )
                    },
                    onViewInsights: {
                        // Navigation handled by caller if needed
                    }
                )

                ActionsSection(
                    subscription: subscription,
                    alternatives: alternatives,
                    paymentManager: paymentManager,
                    actionManager: actionManager,
                    onPaywall: { activeSheet = .paywall },
                    onUsageHistory: { activeSheet = .usageHistory(subscription.name) },
                    onSharing: { activeSheet = .sharing(subscription) },
                    onPriceHistory: { activeSheet = .priceHistory(subscription) },
                    onAnnualSavings: { activeSheet = .annualSavings(subscription) },
                    onCancellationRequest: { activeSheet = .cancellationRequest(subscription) }
                )

                if !alternatives.isEmpty {
                    AlternativesSection(
                        subscription: subscription,
                        alternatives: alternatives,
                        paymentManager: paymentManager,
                        actionManager: actionManager,
                        onSelectAlternative: { activeSheet = .alternative($0) },
                        onPaywall: { activeSheet = .paywall }
                    )
                }

                SupportSection(subscription: subscription, actionManager: actionManager)
            }
            .padding()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .paywall:
                StoreKitUpgradeView(currentSubscriptionCount: 0)
            case .alternative(let alt):
                AlternativeDetailView(alternative: alt, current: subscription)
            case .smartPause(let suggestion, let onPause):
                SmartPauseDetailSheet(suggestion: suggestion, onPause: onPause)
            case .usageInput(let name, let minutes, let onSave):
                UsageInputSheet(subscriptionName: name, currentMinutes: minutes, onSave: onSave)
            case .usageHistory(let name):
                UsageHistorySheet(subscriptionName: name)
            case .sharing(let sub):
                SubscriptionSharingView(subscription: sub)
            case .priceHistory(let sub):
                PriceHistoryView(subscription: sub)
            case .annualSavings(let sub):
                AnnualSavingsCalculatorView(subscription: sub)
            case .cancellationRequest(let sub):
                CancellationRequestView(subscription: sub)
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .cancel(let name, let action):
                return Alert(
                    title: Text("Cancel Subscription"),
                    message: Text("We'll open the cancellation page for \(name). Would you like to proceed?"),
                    primaryButton: .destructive(Text("Open Cancel Page"), action: action),
                    secondaryButton: .cancel(Text("Cancel"))
                )
            case .pause(let name, let action):
                return Alert(
                    title: Text("Pause Subscription"),
                    message: Text("We'll open the pause settings for \(name)."),
                    primaryButton: .default(Text("Open Pause Page"), action: action),
                    secondaryButton: .cancel(Text("Cancel"))
                )
            }
        }
        .onAppear {
            Task {
                await screenTimeManager.syncUsageData()
            }
        }
    }

    private func openCancelURL() {
        if let url = actionManager.generateCancelURL(for: subscription) {
            UIApplication.shared.open(url)
        }
    }

    private func openPauseURL() {
        if let url = actionManager.generatePauseURL(for: subscription) {
            UIApplication.shared.open(url)
        }
    }
}
