import SwiftUI

/// Post-onboarding curation flow: 3 crisp, 1-tap choices where every single answer directly rewires
/// live app behavior (Home & Insights priorities, default reminder lead time across all subscriptions,
/// and rank-3 avoided-charge milestone alerts), followed immediately by the personalized trial plan.
/// Always skippable in one tap, and cleanly dismisses to Home if the App Store is unreachable offline.
struct FirstRunPlanFlow: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var step = 0
    @State private var profile = OnboardingProfile.load()
    @State private var initialReminderDays = OnboardingProfile.load().validReminderDays
    @State private var savingsMilestones: Bool = UserDefaults.standard.object(forKey: ReminderScheduler.savingsMilestonesKey) as? Bool ?? true
    @State private var showingPlan = false
    @State private var isFinishing = false

    private let totalSteps = 3

    var body: some View {
        Group {
            if showingPlan {
                let waiting = TallyImporter.waitingLines().count
                let hasPause = PausePlanCard.yearlySavingsInfo(in: store.subscriptions, currency: currencyManager) != nil
                StoreKitUpgradeView(context: PaywallContext(
                    trigger: profile.curatedTrigger(waitingCount: waiting, hasPauseEligible: hasPause),
                    fromFirstRunReveal: true
                ))
            } else {
                questionScreen
            }
        }
        .task {
            await StoreKitManager.shared.loadProducts()
        }
    }

    private var questionScreen: some View {
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                progressBar.padding(.top, 14)

                Text(verbatim: questionTitle)
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: questionSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                optionsList
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
        } actions: {
            EmptyView()
        }
        .inkScreen()
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            if step > 0 {
                FirstRunBackButton {
                    Feel.selection()
                    withAnimation(Motion.unlessReduced(Motion.arrive)) { step -= 1 }
                }
                Spacer()
                LeaveButton("Not now") { dismissSavingProgress() }
                    .accessibilityIdentifier("curateCloseButton")
            } else {
                LeaveButton("Not now") { dismissSavingProgress() }
                    .accessibilityIdentifier("curateCloseButton")
                Spacer()
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: Layout.markRadius, style: .continuous)
                    .fill(index <= step ? Color.inkText : Color.line)
                    .frame(height: 3)
            }
        }
        .accessibilityHidden(true)
    }

    private var questionTitle: String {
        switch step {
        case 0: return L10n.string("What do you want Pausely to catch first?")
        case 1: return L10n.string("How early should Pausely ask before a charge?")
        default: return L10n.string("Celebrate charges you avoid?")
        }
    }

    private var questionSubtitle: String {
        switch step {
        case 0: return L10n.string("Shapes your Home screen, Insights, and plan. Change anytime in Settings.")
        case 1: return L10n.string("Sets your default reminder window across all subscriptions.")
        default: return L10n.string("One last pick — then your plan is ready.")
        }
    }

    @ViewBuilder private var optionsList: some View {
        VStack(spacing: 10) {
            switch step {
            case 0:
                ForEach(OnboardingProfile.Goal.allCases) { option in
                    choiceButton(title: option.title, detail: option.detail, selected: profile.goal == option) {
                        profile.goal = option
                        advance()
                    }
                }
            case 1:
                ForEach([7, 3, 1], id: \.self) { days in
                    choiceButton(title: SubscriptionEditDraft.reminderLabel(days),
                                 detail: leadDetail(days),
                                 selected: profile.reminderDays == days) {
                        profile.reminderDays = days
                        advance()
                    }
                }
            default:
                choiceButton(
                    title: L10n.string("Yes, send savings milestones"),
                    detail: L10n.string("A quiet note when a cancelled subscription's charge day passes without billing you."),
                    selected: savingsMilestones
                ) {
                    savingsMilestones = true
                    Task { await finishCuration() }
                }
                choiceButton(
                    title: L10n.string("Keep alerts to renewals only"),
                    detail: L10n.string("Only renewal and free-trial alerts — change anytime in Settings."),
                    selected: !savingsMilestones
                ) {
                    savingsMilestones = false
                    Task { await finishCuration() }
                }
            }
        }
        .disabled(isFinishing)
    }

    private func leadDetail(_ days: Int) -> String {
        switch days {
        case 7: return L10n.string("Extra time for email cancellations or hard-to-cancel services")
        case 1: return L10n.string("A quiet heads-up right before it bills")
        default: return L10n.string("Balanced notice before each renewal")
        }
    }

    private func choiceButton(title: String, detail: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Feel.tick()
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(verbatim: detail)
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                            .multilineTextAlignment(.leading)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                RowChevron()
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: Layout.tapTarget, alignment: .leading)
            .background(selected ? Color.inkLifted : Color.inkRaised,
                        in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                    .stroke(selected ? Color.inkText : Color.line, lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func advance() {
        withAnimation(Motion.unlessReduced(Motion.arrive)) {
            step += 1
        }
    }

    private func dismissSavingProgress() {
        if step > 0 {
            profile.save()
            let saved = profile
            let previousLead = initialReminderDays
            if saved.validReminderDays != previousLead {
                Task { await saved.applyReminderDays(to: store, from: previousLead) }
            }
        }
        dismiss()
    }

    private func finishCuration() async {
        guard !isFinishing else { return }
        isFinishing = true
        profile.completedAt = Date()
        profile.save()
        UserDefaults.standard.set(savingsMilestones, forKey: ReminderScheduler.savingsMilestonesKey)
        let saved = profile
        let previousLead = initialReminderDays
        // Await applying reminder lead time BEFORE revealing the paywall so waiting lines cannot race
        // with an immediate Pro purchase, and avoid redundant scheduling if applyReminderDays rescheduled.
        await saved.applyReminderDays(to: store, from: previousLead)
        if saved.validReminderDays == previousLead {
            await ReminderScheduler.shared.reschedule(store.subscriptions)
        }
        if PaymentManager.shared.isPremium {
            dismiss()
            return
        }
        if StoreKitManager.shared.products.isEmpty {
            await StoreKitManager.shared.loadProducts()
        }
        // Offline with no App Store prices loaded: let the user straight into their configured Home
        // instead of stalling them on a no-prices error screen right after onboarding.
        if StoreKitManager.shared.products.isEmpty {
            dismiss()
            return
        }
        withAnimation(Motion.unlessReduced(Motion.arrive)) {
            showingPlan = true
        }
    }
}
