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
    private let receiptMilestoneKey = "review_receipt_milestone_last"
    private let maxRequestsPerYear = 3

    /// Pausely asks for a rating only after it has visibly saved money, never before.
    enum ReviewTrigger {
        /// A cancellation is on the Savings Receipt. Asks at the 1st, 3rd and 10th cancellation.
        case moneyKept(receiptLines: Int)
    }

    static let receiptMilestones = [1, 3, 10]

    /// The highest milestone a receipt with this many cancellations has reached (0 when none).
    nonisolated static func milestone(forReceiptLines lines: Int) -> Int {
        receiptMilestones.last { lines >= $0 } ?? 0
    }

    private init() {}

    /// Asks once the Savings Receipt reaches the next milestone. Safe to call often.
    func askAfterMoneyKept() {
        requestReviewIfAppropriate(after: .moneyKept(receiptLines: SavingsSummary.current().lines.count))
    }

    func requestReviewIfAppropriate(after trigger: ReviewTrigger) {
        guard !ProcessInfo.processInfo.arguments.contains("--uitesting"), !DemoSavings.isScreenshotRun,
              canRequestReview() else { return }

        // A trigger only counts as "used" once the system prompt has really been shown, so a request that
        // is skipped because a sheet is open can fire again on the next opportunity.
        switch trigger {
        case .moneyKept(let receiptLines):
            let reached = Self.milestone(forReceiptLines: receiptLines)
            let lastAsked = UserDefaults.standard.integer(forKey: receiptMilestoneKey)
            guard reached > lastAsked else { return }
            presentReviewRequest { UserDefaults.standard.set(reached, forKey: self.receiptMilestoneKey) }
        }
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

