import Foundation

/// Real spending-habit preferences captured during onboarding curation and editable anytime in
/// Settings → Notifications. Every single field directly configures live app behavior:
/// - `goal`: orders Home & Insights priorities and shapes Day 3 of the personalized trial timeline.
/// - `reminderDays`: default `notifyBeforeDays` (1, 3, or 7) applied across imported, waiting, and new subscriptions.
/// (The third curation choice writes directly to `ReminderScheduler.savingsMilestonesKey`.)
struct OnboardingProfile: Codable, Equatable, Sendable {

    enum Goal: String, Codable, CaseIterable, Identifiable, Sendable {
        case catchTrials
        case cutUnused
        case rotateStreaming
        case watchAnnualAndHikes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .catchTrials: return L10n.string("Catch free trials before they charge")
            case .cutUnused: return L10n.string("Cut subscriptions I stopped using")
            case .rotateStreaming: return L10n.string("Rotate streaming one at a time")
            case .watchAnnualAndHikes: return L10n.string("Spot big annual bills and price hikes")
            }
        }

        var detail: String {
            switch self {
            case .catchTrials: return L10n.string("Alerts 2 days before trials convert")
            case .cutUnused: return L10n.string("Keep-or-cancel checks before every renewal")
            case .rotateStreaming: return L10n.string("Pause Plan scheduling across your services")
            case .watchAnnualAndHikes: return L10n.string("30-to-90 day radar and price history")
            }
        }

        var shortLabel: String {
            switch self {
            case .catchTrials: return L10n.string("Free trials")
            case .cutUnused: return L10n.string("Unused plans")
            case .rotateStreaming: return L10n.string("Streaming rotation")
            case .watchAnnualAndHikes: return L10n.string("Annual bills and hikes")
            }
        }
    }

    /// Honest notification readiness shown on the trial reminder step of the paywall timeline.
    enum TrialReminderState: Equatable, Sendable {
        /// Notifications authorized and visibly delivered (banners, Lock Screen, or Notification Center).
        case ready
        /// iOS permission hasn't been requested yet (typical first-run user).
        case notAsked
        /// Notifications denied or hidden in iOS Settings.
        case offOrHidden
    }

    /// One milestone printed on the paywall's personalized Day 1 / Day 3 / Day 5 / Day 7 slip.
    struct TrialPlanStep: Identifiable, Equatable, Sendable {
        let id: String
        let whenLabel: String
        let badge: String
        let title: String
        let detail: String
        let isKeptAccent: Bool
    }

    var goal: Goal = .cutUnused
    /// Default renewal reminder lead time applied to imported, waiting & newly added subscriptions (1, 3, or 7).
    var reminderDays: Int = 3
    var completedAt: Date? = nil

    static let storageKey = "onboarding_profile_v1"

    static func load(defaults: UserDefaults = .standard) -> OnboardingProfile {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OnboardingProfile.self, from: data) else {
            return OnboardingProfile()
        }
        return decoded
    }

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
        if defaults === UserDefaults.standard {
            NotificationCenter.default.post(name: .onboardingProfileDidChange, object: nil)
        }
    }

    /// Clamps any stored value to the real supported lead times (1, 3, or 7 days).
    var validReminderDays: Int {
        [1, 3, 7].contains(reminderDays) ? reminderDays : 3
    }

    /// Chooses a genuine contextual paywall trigger from real subscription state plus chosen goal.
    func curatedTrigger(waitingCount: Int, hasPauseEligible: Bool) -> ProFeature? {
        if waitingCount > 0 { return .unlimitedSubscriptions }
        switch goal {
        case .rotateStreaming:
            return hasPauseEligible ? .pausePlan : nil
        case .cutUnused:
            return .cancelConcierge
        case .watchAnnualAndHikes:
            return .spendForecast
        case .catchTrials:
            return nil
        }
    }

    /// Builds a truthful, personalized Day 1 → Day 3 → Day 5 → Day 7 trial or return plan from the
    /// user's real subscriptions, chosen lead time, notification readiness, and App Store offer length.
    func trialPlanSteps(trialDays: Int,
                        isWinBack: Bool = false,
                        watchedCount: Int,
                        waitingCount: Int,
                        yearlyText: String?,
                        pauseYearlyText: String?,
                        reminderState: TrialReminderState,
                        day3Date: String,
                        reminderDate: String,
                        reminderLeadDays: Int,
                        firstChargeDate: String,
                        chargeText: String,
                        lastDayToCancel: String) -> [TrialPlanStep] {
        let lead = validReminderDays
        let leadSentence = L10n.string("Reminders arrive \(lead) days before each charge.")
        let day1Detail: String = {
            if waitingCount > 0 {
                let added = waitingCount == 1
                    ? L10n.string("Adds your waiting subscription right away.")
                    : L10n.string("Adds your \(waitingCount) waiting subscriptions right away.")
                return L10n.sentences([added, leadSentence])
            }
            if let yearlyText, watchedCount > 0 {
                let tracked = watchedCount == 1
                    ? L10n.string("Watches your subscription (\(yearlyText) a year).")
                    : L10n.string("Tracks all \(watchedCount) subscriptions (\(yearlyText) a year).")
                return L10n.sentences([tracked, leadSentence])
            }
            return L10n.sentences([L10n.string("Unlimited tracking across all your subscriptions."), leadSentence])
        }()

        let day3Title: String
        let day3Detail: String
        switch goal {
        case .rotateStreaming:
            if let pauseYearlyText {
                day3Title = L10n.string("Start your streaming rotation")
                day3Detail = L10n.string("Rotate one service at a time in Pause Plan to keep about \(pauseYearlyText) a year.")
            } else {
                day3Title = L10n.string("Start your streaming rotation")
                day3Detail = L10n.string("Rotate your streaming services one at a time in Pause Plan.")
            }
        case .watchAnnualAndHikes:
            day3Title = L10n.string("Catch annual bills and hikes")
            day3Detail = L10n.string("Check your 12-month renewal forecast and scan screenshots anytime to spot price increases.")
        case .catchTrials:
            day3Title = L10n.string("Lock in your dates and trials")
            day3Detail = L10n.string("Scan a screenshot to fill renewal dates in seconds so every trial alert fires on time.")
        case .cutUnused:
            day3Title = L10n.string("Spot what isn't earning its keep")
            day3Detail = L10n.string("Review overlapping services in Insights and send pre-filled cancel emails in one tap.")
        }

        let reminderBadge: String
        let reminderTitle: String
        let reminderDetail: String
        let activeReminderTitle = isWinBack ? L10n.string("Return reminder") : L10n.string("Trial reminder")
        switch reminderState {
        case .ready:
            reminderBadge = L10n.string("Free")
            reminderTitle = activeReminderTitle
            reminderDetail = isWinBack
                ? L10n.string("Pausely watches its own return offer and reminds you \(reminderLeadDays) days before it charges.")
                : L10n.string("Pausely adds its own trial to your list and reminds you \(reminderLeadDays) days before it charges.")
        case .notAsked:
            reminderBadge = L10n.string("Free")
            reminderTitle = activeReminderTitle
            reminderDetail = L10n.string("Allow notifications when you start so Pausely reminds you \(reminderLeadDays) days before it charges.")
        case .offOrHidden:
            reminderBadge = L10n.string("Alerts off")
            reminderTitle = L10n.string("Reminder (alerts off)")
            reminderDetail = L10n.string("Turn on notifications in Settings for a reminder before it charges. Cancel by \(lastDayToCancel) in Settings and you pay nothing.")
        }

        var steps: [TrialPlanStep] = [
            TrialPlanStep(
                id: "day1",
                whenLabel: L10n.string("Today"),
                badge: L10n.string("Free"),
                title: L10n.string("Unlock your full plan"),
                detail: day1Detail,
                isKeptAccent: true
            ),
        ]

        if trialDays >= 5 {
            steps.append(TrialPlanStep(
                id: "day3",
                whenLabel: day3Date,
                badge: L10n.string("Free"),
                title: day3Title,
                detail: day3Detail,
                isKeptAccent: false
            ))
        }

        steps.append(TrialPlanStep(
            id: "reminder",
            whenLabel: reminderDate,
            badge: reminderBadge,
            title: reminderTitle,
            detail: reminderDetail,
            isKeptAccent: false
        ))

        steps.append(TrialPlanStep(
            id: "charge",
            whenLabel: firstChargeDate,
            badge: chargeText,
            title: isWinBack ? L10n.string("Free days end") : L10n.string("Trial ends"),
            detail: L10n.string("Starts only if you keep it. Cancel by \(lastDayToCancel) in Settings and you pay nothing."),
            isKeptAccent: false
        ))

        return steps
    }

    /// Applies the chosen reminder lead time in a single batch to active subscriptions and waiting lines.
    @MainActor
    func applyReminderDays(to store: SubscriptionStore, from previousDefault: Int = 3,
                           defaults: UserDefaults = .standard) async {
        let desired = validReminderDays
        await store.applyDefaultReminderDays(desired, from: previousDefault)
        TallyImporter.applyReminderDaysToWaiting(desired, from: previousDefault, defaults: defaults)
    }
}

extension Notification.Name {
    static let onboardingProfileDidChange = Notification.Name("onboardingProfileDidChange")
}
