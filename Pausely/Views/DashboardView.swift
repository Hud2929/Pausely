import SwiftUI
import UserNotifications

/// Home. Four things, in the order someone needs them: what it all costs, what needs a decision,
/// what leaves in the next 30 days (with Pause Plan elevated when rotating streaming is the goal),
/// and what Pausely has kept.
@MainActor
struct DashboardView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var pausePlanStore = PausePlanStore.shared
    @ObservedObject private var paymentManager = PaymentManager.shared

    @State private var showingAdd = false
    @State private var showingPaywall = false
    @State private var paywallTrigger: ProFeature? = .unlimitedSubscriptions
    @State private var showingReceipt = false
    @State private var showingDates = false
    @State private var showingInbox = false
    @State private var showingScreenshotImport = false
    @State private var showingFreePicker = false
    @State private var pendingPaywallFromPicker = false
    @State private var profile = OnboardingProfile.load()
    @State private var eligibleWinBack: StoreKitManager.FreeExtensionOffer?
    @AppStorage(TallyImporter.waitingVersionKey) private var waitingVersion = 0
    @State private var showsYear = false
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 52
    @ScaledMetric(relativeTo: .title3) private var addButtonSize: CGFloat = Layout.tapTarget
    @Environment(\.dynamicTypeSize) private var typeSize

    /// How many lines the total may take. One; two at the accessibility text sizes, where a total
    /// in the millions, already at half its size, was cut off on one line ("IDR 9,573,4…").
    nonisolated static func totalLines(largeText: Bool) -> Int { largeText ? 2 : 1 }

    private var hasKept: Bool { !SavingsSummary.current().isEmpty }
    private var charges: [Horizon.Charge] { Horizon.charges(for: store.subscriptions, now: Date()) }
    private var showPausePlan: Bool {
        PausePlanCard.isRelevant(plan: pausePlanStore.activePlan, subscriptions: store.subscriptions)
    }
    private var elevatePausePlan: Bool {
        showPausePlan && profile.goal == .rotateStreaming
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if store.listState == .loading {
                    ListLoading().padding(.top, 32)
                } else if store.listState == .couldNotLoad {
                    ListCouldNotLoad().padding(.top, 40)
                } else if store.subscriptions.isEmpty {
                    HomeEmpty(onAdd: { showingAdd = true },
                              onImportScreenshots: { showingScreenshotImport = true },
                              onFindInEmail: FeatureFlags.inboxImportEnabled ? { showingInbox = true } : nil)
                        .padding(.top, 40)
                } else {
                    attention.padding(.top, 28)
                    // Proof of money kept comes before the list of what is about to leave.
                    if hasKept { keptSection.padding(.top, 24) }
                    if elevatePausePlan {
                        VStack(spacing: 0) { Hairline(); PausePlanCard() }
                            .padding(.top, 24)
                    }
                    if Self.showsComingUp(hasCharges: !charges.isEmpty,
                                          hasUndated: !Horizon.undated(store.subscriptions).isEmpty) {
                        HorizonSection(charges: charges, notInTotal: Self.notInTotal(Horizon.undated(store.subscriptions)),
                                       currency: currencyManager.selectedCurrency, rates: currencyManager.rates,
                                       pendingKeys: Set(VerdictCenter.shared.pendingDecisions(rotating: pausePlanStore.activePlan).map { RenewalDecisions.key($0.subscriptionId, $0.date) }))
                            .padding(.top, 32)
                    }
                    if !hasKept { keptSection.padding(.top, 28) }
                    if showPausePlan && !elevatePausePlan {
                        VStack(spacing: 0) { Hairline(); PausePlanCard() }
                            .padding(.top, 20)
                    }
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .readableScroll()
        .inkScreen()
        .refreshable { await store.fetchSubscriptions(force: true) }
        .sheet(isPresented: $showingAdd) { SubscriptionBrowserView() }
        .sheet(isPresented: $showingPaywall) { StoreKitUpgradeView(trigger: paywallTrigger) }
        .sheet(isPresented: $showingReceipt) { SavingsReceiptView() }
        .sheet(isPresented: $showingDates) { RenewalDatesSheet(subscriptions: Horizon.undated(store.subscriptions)) }
        .sheet(isPresented: $showingInbox) { InboxImportView() }
        .sheet(isPresented: $showingScreenshotImport) { ScreenshotImportView() }
        .sheet(isPresented: $showingFreePicker, onDismiss: {
            guard pendingPaywallFromPicker else { return }
            pendingPaywallFromPicker = false
            paywallTrigger = .unlimitedSubscriptions
            showingPaywall = true
        }) { FreeLimitPickerSheet(store: store, currencyManager: currencyManager, onSeePro: { pendingPaywallFromPicker = true }).presentationSizing(.page) }
        .onAppear {
            profile = OnboardingProfile.load()
            ReviewPromptManager.shared.askAfterMoneyKept()
            ReviewPromptManager.shared.askAfterDecisionMade()
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingProfileDidChange)) { _ in
            profile = OnboardingProfile.load()
        }
        .task(id: paymentManager.currentTier) {
            guard !paymentManager.isPremium, !DemoSavings.isScreenshotRun, !LaunchFlag.demoMode.isSet else {
                eligibleWinBack = nil
                return
            }
            await StoreKitManager.shared.loadProducts()
            eligibleWinBack = await StoreKitManager.shared.bestEligibleWinBackOffer()?.offer
        }
    }

    // MARK: - The number

    /// What VoiceOver says for the big figure: the whole sentence, because "$147.92" alone says nothing.
    private var spokenTotal: String {
        let currency = currencyManager.selectedCurrency
        if showsYear {
            return L10n.string("Your subscriptions cost about \(MoneyFormat.string(store.totalAnnualSpend, currency)) a year.")
        }
        return L10n.string("Your subscriptions cost \(MoneyFormat.total(store.totalMonthlySpend, currency, converted: store.totalIsConverted)) a month.")
    }

    private var header: some View {
        Group {
            if Self.totalHasTheWholeWidth(largeText: typeSize.isAccessibilitySize) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 12) {
                        periodToggle
                        Spacer(minLength: 8)
                        addButton
                    }
                    totalFigure
                    countLine
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        periodToggle
                        totalFigure
                        countLine
                    }
                    Spacer(minLength: 8)
                    addButton
                }
            }
        }
    }

    nonisolated static func totalHasTheWholeWidth(largeText: Bool) -> Bool { largeText }

    nonisolated static func showsComingUp(hasCharges: Bool, hasUndated: Bool) -> Bool {
        hasCharges || !hasUndated
    }

    nonisolated static func notInTotal(_ undated: [Subscription]) -> String? {
        switch undated.count {
        case 0: return nil
        case 1: return L10n.string("\(undated[0].name) isn't in this total: it has no renewal date.")
        default: return L10n.string("\(undated.count) subscriptions aren't in this total: they have no renewal date.")
        }
    }

    private var periodToggle: some View {
        Button {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) { showsYear.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(showsYear ? L10n.string("Each year") : L10n.string("Each month"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "arrow.up.arrow.down").font(.caption2.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .foregroundStyle(Color.inkTextMuted)
            .tapArea(.leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Switches between a month and a year"))
        .accessibilityIdentifier("spendPeriodToggle")
    }

    @ViewBuilder private var totalFigure: some View {
        if !store.listState.totalIsKnown {
            RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous)
                .fill(Color.inkRaised)
                .frame(width: 168, height: numberSize * 0.8)
                .padding(.vertical, numberSize * 0.1)
                .accessibilityHidden(true)
        } else {
            Text(verbatim: MoneyFormat.total(showsYear ? store.totalAnnualSpend : store.totalMonthlySpend,
                                             currencyManager.selectedCurrency, converted: store.totalIsConverted))
                .font(.total(numberSize))
                .foregroundStyle(Color.inkText)
                .contentTransition(.numericText())
                .lineLimit(Self.totalLines(largeText: typeSize.isAccessibilitySize))
                .minimumScaleFactor(0.5)
                .accessibilityLabel(Text(verbatim: spokenTotal))
                .accessibilityIdentifier("spendTotal")
        }
    }

    @ViewBuilder private var countLine: some View {
        if !store.subscriptions.isEmpty {
            Text(L10n.string("\(store.activeSubscriptions.count) subscriptions"))
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var addButton: some View {
        let size = min(addButtonSize, 68)
        return Button { showingAdd = true } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.inkText)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.outline, lineWidth: 1))
                .contentShape(Circle())
        }
        .accessibilityLabel(Text("Add subscription"))
        .accessibilityIdentifier("homeAddButton")
    }

    // MARK: - What needs attention

    @ViewBuilder private var attention: some View {
        let rawPending = VerdictCenter.shared.pendingDecisions(rotating: pausePlanStore.activePlan)
        let pending = profile.goal == .catchTrials
            ? rawPending.sorted { lhs, rhs in
                if lhs.isTrialEnd != rhs.isTrialEnd { return lhs.isTrialEnd }
                return lhs.date < rhs.date
            }
            : rawPending
        let waiting = waitingVersion >= 0 ? TallyImporter.waitingLines() : []
        let rawUndated = Horizon.undated(store.subscriptions)
        let undated = profile.goal == .catchTrials
            ? rawUndated.sorted { ($0.status == .trial) && ($1.status != .trial) }
            : rawUndated
        let showReminderAsk = !NotificationManager.shared.isAuthorized && !DemoSavings.isScreenshotRun

        VStack(spacing: 0) {
            if let first = undated.first {
                AttentionRow(state: nil, symbol: "calendar.badge.plus",
                             title: undated.count == 1
                                ? L10n.string("When does \(first.name) renew?")
                                : L10n.string("\(undated.count) subscriptions have no renewal date"),
                             detail: L10n.string("Add the date and Pausely will ask you before it charges."),
                             action: undated.count == 1 ? L10n.string("Add date") : L10n.string("Add dates")) {
                    showingDates = true
                }
                .accessibilityIdentifier("undatedRow")
                Hairline()
            }

            ForEach(pending) { item in
                if let sub = store.subscriptions.first(where: { $0.id == item.subscriptionId }) {
                    AttentionRow(state: .decide,
                                 title: L10n.string("Keep \(sub.name)?"),
                                 detail: whenText(item) + " · " + sub.chargeText,
                                 action: L10n.string("Decide")) {
                        VerdictCenter.shared.open(subscriptionId: sub.id)
                    }
                    .accessibilityIdentifier("decideRow")
                    Hairline()
                }
            }

            if showReminderAsk {
                ReminderAskRow(nextCharge: charges.first)
                Hairline()
            }

            if let winBack = eligibleWinBack, !paymentManager.isPremium {
                AttentionRow(state: .kept, symbol: "sparkles",
                             title: L10n.string("Welcome back to Pausely Pro"),
                             detail: L10n.string("Try Pausely Pro again with \(winBack.days) days free — cancel anytime."),
                             action: L10n.string("Claim free")) {
                    paywallTrigger = nil
                    showingPaywall = true
                }
                .accessibilityIdentifier("homeWinBackRow")
                Hairline()
            }

            if !waiting.isEmpty, !paymentManager.isUnlocked(.unlimitedSubscriptions) {
                let room = FreeTier.room(in: store.subscriptions)
                let one = waiting.count == 1 ? waiting[0].name : nil
                let risk = PaywallCase.waitingRisk(lines: waiting, displayCurrency: currencyManager.selectedCurrency,
                                                   proYearly: nil, proCurrency: nil, rates: currencyManager.rates)
                let noRoom = risk.map {
                    let y = MoneyFormat.total($0.yearlyAmount, $0.currency, converted: $0.isConverted, locale: L10n.locale, wholeUnits: true)
                    return L10n.string("About \(y) a year without reminders. Choose which \(FreeTier.subscriptionLimit) to watch, or go Pro for all.")
                } ?? L10n.string("The free plan tracks \(FreeTier.subscriptionLimit). Choose which ones to watch, or go Pro for all.")
                AttentionRow(state: nil, symbol: room > 0 ? "plus.circle" : "checklist",
                             title: room > 0 ? one.map { L10n.string("There's room for \($0)") }
                                                ?? L10n.string("There's room for \(min(room, waiting.count)) of the \(waiting.count) you kept for later")
                                             : one.map { L10n.string("\($0) isn't tracked") }
                                                ?? L10n.string("\(waiting.count) of your subscriptions aren't tracked"),
                             detail: room > 0 ? L10n.string("The free plan tracks \(FreeTier.subscriptionLimit). Choose which ones to track.") : noRoom,
                             action: room > 0 && waiting.count <= room ? L10n.string("Add") : L10n.string("Choose")) {
                    if room > 0 && waiting.count <= room { Task { await TallyImporter.importWaiting(into: store) } }
                    else { showingFreePicker = true }
                }
                .accessibilityIdentifier("waitingRow")
                Hairline()
            }
        }
    }

    private func whenText(_ item: RenewalDecisions.Pending) -> String {
        let days = Calendar.billing.calendarDays(from: Date(), to: item.date)
        let relative = L10n.relativeDay(days)
        return item.isTrialEnd ? L10n.string("Trial ends \(relative)") : L10n.string("Renews \(relative)")
    }

    // MARK: - Kept

    /// The receipt's stub: paper, because this is money proven kept.
    @ViewBuilder private var keptSection: some View {
        let summary = SavingsSummary.current()
        Button {
            Feel.selection()
            showingReceipt = true
        } label: {
            if summary.isEmpty {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Savings Receipt")
                            .font(.headline)
                            .foregroundStyle(Color.inkText)
                        let uncounted = SavingsLedger.uncounted(from: eventLog.events, excluding: Set(store.subscriptions.filter(\.isPausely).map(\.id)))
                        (uncounted.isEmpty ? Text("Your Savings Receipt starts with your first cancellation")
                                           : Text("Cancelled without a renewal day, so no charges could be counted: \(uncounted.formatted(.list(type: .and).locale(L10n.locale))).")).font(.subheadline)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    RowChevron()
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            } else {
                PaperSlip(tornTop: true, tornBottom: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ProofLine(label: L10n.string("Kept since you cancelled"), value: summary.total(summary.savedSoFar),
                                  emphasised: true)
                            .foregroundStyle(Color.paperKept)
                        ProofLine(label: L10n.string("On track over 12 months"), value: summary.total(summary.onTrack))
                        if let multiple = summary.returnMultiple, summary.paysForItself {
                            Text(L10n.string("On track for \(multiple.formatted(.number.precision(.fractionLength(1)).locale(L10n.locale)))× what Pausely costs a year."))
                                .font(.footnote)
                                .foregroundStyle(Color.paperMuted)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens your Savings Receipt"))
        .accessibilityIdentifier("savingsReceiptCard")
    }
}
