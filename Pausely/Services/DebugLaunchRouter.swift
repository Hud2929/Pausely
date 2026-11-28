#if DEBUG
import SwiftUI

/// Routes `--demo-*` launch flags to isolated screens for UI tests, visual tours, and screenshots.
/// Compiled only in DEBUG builds so release code never carries preview harnesses.
@MainActor
enum DebugLaunchRouter {
    /// Returns the view requested by a `--demo-*` flag, or nil when launching the real app flow.
    @ViewBuilder
    static func screen() -> some View {
        if let destination = currentDestination() {
            render(destination)
        }
    }

    static var hasDestination: Bool { currentDestination() != nil }

    private enum Destination {
        case gmailResults
        case inboxReset
        case inboxState(String)
        case imapPreset(String)
        case auth(String)
        case ageGate
        case settings(String)
        case whatsNew
        case subscription(String)
        case subscriptionEdit(String)
        case firstRun(FirstRunView.Phase, useDemoTally: Bool)
        case cancel(String)
        case cancelEmail(String)
        case outcome(kept: Bool)
        case customAdd
        case tier
        case priceHistory(String)
        case design
        case paywall
        case wrapped(String)
        case verdict(String)
        case pausePlan
        case dates
        case receipt
        case browser
        case screenshotImport(demoResults: Bool)
    }

    private static func currentDestination() -> Destination? {
        if LaunchFlag.isSet("--demo-gmail-results") { return .gmailResults }
        if LaunchFlag.isSet("--demo-inbox") { return .inboxReset }
        if let state = LaunchFlag.value(of: "--demo-inbox"), !state.isEmpty { return .inboxState(state) }
        if let preset = LaunchFlag.value(of: "--demo-imap-connect") {
            return .imapPreset(preset.isEmpty ? "icloud" : preset)
        }
        if let screen = LaunchFlag.value(of: "--demo-auth") { return .auth(screen) }
        if LaunchFlag.value(of: "--demo-age-gate") != nil { return .ageGate }
        if let screen = LaunchFlag.value(of: "--demo-settings") { return .settings(screen) }
        if LaunchFlag.isSet("--demo-whats-new") { return .whatsNew }
        if let name = LaunchFlag.value(of: "--demo-subscription") { return .subscription(name) }
        if let name = LaunchFlag.value(of: "--demo-subscription-edit") { return .subscriptionEdit(name) }
        if LaunchFlag.isSet("--demo-first-run=reveal") { return .firstRun(.reveal, useDemoTally: true) }
        if LaunchFlag.isSet("--demo-first-run=tally") { return .firstRun(.tally, useDemoTally: true) }
        if LaunchFlag.isSet("--demo-first-run") { return .firstRun(.guess, useDemoTally: false) }
        if let name = LaunchFlag.value(of: "--demo-cancel") { return .cancel(name) }
        if let name = LaunchFlag.value(of: "--demo-cancel-email") { return .cancelEmail(name) }
        if LaunchFlag.isSet("--demo-kept") { return .outcome(kept: true) }
        if LaunchFlag.isSet("--demo-cancelled") { return .outcome(kept: false) }
        if LaunchFlag.isSet("--demo-custom-add") { return .customAdd }
        if LaunchFlag.isSet("--demo-tier") { return .tier }
        if let name = LaunchFlag.value(of: "--demo-price-history") { return .priceHistory(name) }
        if LaunchFlag.isSet("--demo-design") { return .design }
        if LaunchFlag.isSet("--demo-paywall") { return .paywall }
        if let list = LaunchFlag.value(of: "--demo-wrapped") { return .wrapped(list) }
        if let name = LaunchFlag.value(of: "--demo-verdict") { return .verdict(name) }
        if LaunchFlag.isSet("--demo-pause-plan") { return .pausePlan }
        if LaunchFlag.isSet("--demo-dates") { return .dates }
        if LaunchFlag.value(of: "--demo-receipt") != nil { return .receipt }
        if LaunchFlag.isSet("--demo-browser") { return .browser }
        if let mode = LaunchFlag.value(of: "--demo-screenshot-import") {
            return .screenshotImport(demoResults: mode == "results")
        }
        return nil
    }

    @ViewBuilder
    private static func render(_ destination: Destination) -> some View {
        switch destination {
        case .gmailResults:
            InboxImportView()
                .onAppear { InboxScanner.shared.loadDemoResults() }
        case .inboxReset:
            InboxImportView()
                .task { if LaunchFlag.isSet("--reset-inbox") { await InboxScanner.shared.disconnectAll() } }
        case .inboxState(let state):
            InboxImportView()
                .onAppear { InboxScanner.shared.loadDemoConnected(state) }
        case .imapPreset(let presetID):
            IMAPConnectView(preset: IMAPPreset.find(presetID))
        case .auth(let screen):
            switch screen {
            case "verify": EmailConfirmationView(email: "jane@example.com")
            case "reset": PasswordResetView(email: "")
            case "newpassword": NewPasswordView()
            case "signup": WelcomeFlow(start: .signUp)
            case "signin": WelcomeFlow(start: .signIn)
            default: WelcomeFlow(start: .welcome)
            }
        case .ageGate:
            AgeGateView(onPassed: {}, onCancel: {}, cancelTitle: "Sign out")
        case .settings(let screen):
            switch screen {
            case "privacy": PrivacySecurityView()
            case "help": HelpSupportView()
            case "currency": CurrencySettingsView()
            case "export": ExportDataView()
            case "language": LanguageSettingsView()
            default: NotificationsSettingsView()
            }
        case .whatsNew:
            WhatsNewSheet()
        case .subscription(let name):
            SubscriptionManagementView(subscription: demoSubscription(name))
        case .subscriptionEdit(let name):
            SubscriptionEditView(subscription: name.isEmpty ? DemoSubscriptions.netflix : demoSubscription(name))
        case .firstRun(let phase, let useDemoTally):
            FirstRunView(startAt: phase, tally: useDemoTally ? DemoTally.make() : nil,
                         onKeepList: {}, onSignIn: {}, onContinueWithoutAccount: {})
        case .cancel(let name):
            CancelSubscriptionFlow(subscription: name.isEmpty ? DemoSubscriptions.netflix : demoSubscription(name))
        case .cancelEmail(let name):
            EmailDraftSheet(draft: CancelConcierge.cancellationDraft(
                for: name.isEmpty ? DemoSubscriptions.netflix : demoSubscription(name),
                accountEmail: "alex@example.com"
            ))
        case .outcome(let kept):
            ZStack {
                Group {
                    if kept {
                        OutcomeSlip(name: "Netflix", category: "entertainment", stamp: L10n.string("Kept"), torn: false) {
                            Text(L10n.string("No more reminders about this charge.")).font(.proof(.footnote))
                        }
                    } else {
                        CancelledSlip(subscription: DemoSubscriptions.netflix)
                    }
                }
                .padding(Layout.margin)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .inkScreen()
        case .customAdd:
            AddSubscriptionView()
        case .tier:
            DemoTierSheet()
        case .priceHistory(let name):
            PriceHistoryView(subscription: name.isEmpty ? DemoSubscriptions.netflix : demoSubscription(name))
        case .design:
            DesignGalleryView()
        case .paywall:
            StoreKitUpgradeView()
        case .wrapped(let list):
            SubscriptionWrappedView(subscriptions: list == "list" ? SubscriptionStore.shared.subscriptions
                                                                  : SubscriptionStore.makeDemoSubscriptions())
        case .verdict(let name):
            RenewalVerdictView(subscriptionId: name.isEmpty ? SubscriptionStore.shared.subscriptions.first?.id ?? UUID()
                                                            : demoSubscription(name).id)
        case .pausePlan:
            PausePlanView()
        case .dates:
            RenewalDatesSheet(subscriptions: SubscriptionStore.makeDemoSubscriptions().prefix(3).map { subscription in
                var undated = subscription
                undated.nextBillingDate = nil
                return undated
            })
        case .receipt:
            SavingsReceiptView()
        case .browser:
            SubscriptionBrowserView()
        case .screenshotImport(let demoResults):
            ScreenshotImportView(startWithDemoResults: demoResults)
        }
    }

    /// The subscription a `--demo-…=Name` argument names, from the list in use ("--demo-subscription=Hulu"
    /// with `--varied-demo-data` opens the cancelled one). Netflix when it names none.
    private static func demoSubscription(_ name: String) -> Subscription {
        let list = SubscriptionStore.shared.subscriptions
        if !name.isEmpty, let named = list.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return named }
        return list.first { $0.name == "Netflix" } ?? DemoSubscriptions.netflix
    }

    /// Seeds state flags that ride along on whichever demo screen is opened.
    static func applyDemoModifiers(authManager: AuthManager) {
        if LaunchFlag.isSet("--demo-guest") { authManager.enterGuestMode(persist: false) }
        if LaunchFlag.isSet("--demo-savings") || LaunchFlag.isSet("--demo-receipt") { DemoSavings.seed() }
        // Not in a capture for the App Store: the sample scores are made up, and a picture on the
        // listing would be saying of a real service that eighteen people found it hard to cancel.
        let wantsScores = LaunchFlag.value(of: "--demo-cancel") != nil || LaunchFlag.value(of: "--demo-verdict") != nil || LaunchFlag.isSet("--demo-difficulty")
        if wantsScores, !LaunchFlag.screenshots.isSet {
            CancelDifficultyService.shared.seedDemoScores()
        }
        if LaunchFlag.isSet("--demo-link-problem") {
            authManager.linkProblem = L10n.string("That link has expired or was already used. Ask for a new one.")
        }
        if LaunchFlag.isSet("--demo-plan-active") {
            Task {
                guard PausePlanStore.shared.activePlan == nil else { return }
                let rotating = SubscriptionStore.shared.subscriptions.filter { PausePlanSchedule.isEligible($0) && $0.status != .cancelled }
                await PausePlanStore.shared.start(order: PausePlanSchedule.suggestedOrder(rotating, now: Date()))
            }
        }
        if LaunchFlag.isSet("--demo-waiting") { TallyImporter.keepWaitingForDemo() }
        if LaunchFlag.isSet("--demo-notice") {
            Task {
                try? await Task.sleep(for: .seconds(2))
                SubscriptionStore.shared.lastErrorMessage = L10n.string("Saved on this iPhone. It hasn't reached your account yet. Pausely will keep trying.")
            }
        }
    }
}

/// `--demo-tier`: the plan sheet for Netflix.
private struct DemoTierSheet: View {
    var body: some View {
        if let entry = SubscriptionCatalogService.shared.entry(named: "Netflix") {
            CatalogAddSheet(entry: entry) { _, _, _, _, _ in }
        }
    }
}
#endif
