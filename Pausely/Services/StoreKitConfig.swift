import Foundation
import UIKit
import StoreKit


// MARK: - Review Prompt Manager
/// Manages strategic review prompts at positive user moments.
/// Limits to 3 requests per year to avoid App Store rejection.
@MainActor
final class ReviewPromptManager: ObservableObject {
    static let shared = ReviewPromptManager()

    private let requestsThisYearKey = "review_requests_this_year"
    private let lastRequestDateKey = "review_last_request_date"
    private let currentYearKey = "review_current_year"
    private let hasPromptedAfterOnboardingKey = "review_prompted_after_onboarding"
    private let hasPromptedAfterFirstSubKey = "review_prompted_after_first_sub"
    private let savingsMilestoneKey = "review_savings_milestone_last"
    private let maxRequestsPerYear = 3

    enum ReviewTrigger {
        case onboardingCompleted
        case firstSubscriptionAdded
        case savingsMilestone(amount: Decimal)
    }

    private init() {}

    func requestReviewIfAppropriate(after trigger: ReviewTrigger) {
        guard canRequestReview() else { return }

        // A trigger only counts as "used" once the system prompt has really been shown, so a request that
        // is skipped because a sheet is open can fire again on the next opportunity.
        switch trigger {
        case .onboardingCompleted:
            guard !UserDefaults.standard.bool(forKey: hasPromptedAfterOnboardingKey) else { return }
            presentReviewRequest { UserDefaults.standard.set(true, forKey: self.hasPromptedAfterOnboardingKey) }

        case .firstSubscriptionAdded:
            guard !UserDefaults.standard.bool(forKey: hasPromptedAfterFirstSubKey) else { return }
            presentReviewRequest { UserDefaults.standard.set(true, forKey: self.hasPromptedAfterFirstSubKey) }

        case .savingsMilestone(let amount):
            let milestone = Int(truncating: amount as NSNumber) / 50
            let lastMilestone = UserDefaults.standard.integer(forKey: savingsMilestoneKey)
            guard milestone > lastMilestone, milestone >= 1 else { return }
            presentReviewRequest { UserDefaults.standard.set(milestone, forKey: self.savingsMilestoneKey) }
        }
    }

    func resetState() {
        UserDefaults.standard.removeObject(forKey: requestsThisYearKey)
        UserDefaults.standard.removeObject(forKey: lastRequestDateKey)
        UserDefaults.standard.removeObject(forKey: currentYearKey)
        UserDefaults.standard.removeObject(forKey: hasPromptedAfterOnboardingKey)
        UserDefaults.standard.removeObject(forKey: hasPromptedAfterFirstSubKey)
        UserDefaults.standard.removeObject(forKey: savingsMilestoneKey)
    }

    private func canRequestReview() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let storedYear = UserDefaults.standard.integer(forKey: currentYearKey)

        if storedYear != currentYear {
            UserDefaults.standard.set(currentYear, forKey: currentYearKey)
            UserDefaults.standard.set(0, forKey: requestsThisYearKey)
            return true
        }

        let requestsThisYear = UserDefaults.standard.integer(forKey: requestsThisYearKey)
        guard requestsThisYear < maxRequestsPerYear else { return false }

        if let lastDate = UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date {
            let daysSinceLast = calendar.dateComponents([.day], from: lastDate, to: now).day ?? 0
            guard daysSinceLast >= 7 else { return false }
        }

        return true
    }

    /// Shows the system rating prompt after a short pause, but only if the customer is on a main screen:
    /// never on top of the paywall, the add-subscription sheet or any other modal.
    private func presentReviewRequest(markUsed: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self,
                  let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController,
                  root.presentedViewController == nil else { return }

            markUsed()
            let currentYear = Calendar.current.component(.year, from: Date())
            let storedYear = UserDefaults.standard.integer(forKey: self.currentYearKey)
            let requestsThisYear = (storedYear == currentYear)
                ? UserDefaults.standard.integer(forKey: self.requestsThisYearKey)
                : 0
            UserDefaults.standard.set(currentYear, forKey: self.currentYearKey)
            UserDefaults.standard.set(requestsThisYear + 1, forKey: self.requestsThisYearKey)
            UserDefaults.standard.set(Date(), forKey: self.lastRequestDateKey)

            AppStore.requestReview(in: windowScene)
        }
    }
}

