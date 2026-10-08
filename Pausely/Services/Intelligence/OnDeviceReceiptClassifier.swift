import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device language model, used ONLY for receipts the rules cannot decide.
/// - Runs entirely on the phone: the excerpt never leaves the device and is discarded after the answer.
/// - Silently disabled on devices or OS versions without Apple Intelligence; the rule engine works without it.
enum OnDeviceReceiptClassifier {
    static func makeIfAvailable() -> AmbiguousReceiptClassifier? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return FoundationModelsReceiptClassifier()
            }
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)

@available(iOS 26.0, *)
@Generable
struct ReceiptJudgement {
    @Guide(description: "True only if the text clearly says this is a recurring subscription or membership charge that renews automatically. False for one-time orders, purchases, tickets, trips, bills that vary, or anything unclear.")
    var isRecurringSubscription: Bool

    @Guide(description: "How often it renews, if the text says so.", .anyOf(["weekly", "monthly", "quarterly", "yearly", "unknown"]))
    var billingPeriod: String
}

@available(iOS 26.0, *)
struct FoundationModelsReceiptClassifier: AmbiguousReceiptClassifier {
    func classify(merchantGuess: String?, subject: String, excerpt: String) async -> ReceiptVerdict {
        let instructions = """
        You decide whether one email receipt is for a recurring subscription. \
        Use only the text provided. Never guess: if the text does not clearly show recurring billing, answer false.
        """
        let session = LanguageModelSession(instructions: instructions)
        let prompt = """
        Merchant: \(merchantGuess ?? "unknown")
        Subject: \(subject)
        Email text:
        \(excerpt)
        """
        guard let response = try? await session.respond(to: prompt, generating: ReceiptJudgement.self) else { return .unsure }
        let judgement = response.content
        guard judgement.isRecurringSubscription else { return .oneTime }
        switch judgement.billingPeriod {
        case "weekly": return .recurring(.weekly)
        case "monthly": return .recurring(.monthly)
        case "quarterly": return .recurring(.quarterly)
        case "yearly": return .recurring(.yearly)
        default: return .recurring(nil)
        }
    }
}

#endif
