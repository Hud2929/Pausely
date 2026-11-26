import SwiftUI

/// Personalized Day 1 / Day 3 / Day 5 / Day 7 trial timeline printed on Pausely's own Paper Slip,
/// followed by the compact `ProFeature` disclosure and the Pausely Promise.
struct PaywallPlanTimeline: View {
    let isCheckingOffer: Bool
    let isTrialEnabled: Bool
    let isWinBackFreeOffer: Bool
    let trialDays: Int
    let chargeText: String
    let steps: [OnboardingProfile.TrialPlanStep]
    let features: [ProFeature]
    let trigger: ProFeature?

    var body: some View {
        PaperSlip(tornTop: true, tornBottom: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: slipTitle)
                    .font(.question(.title3))

                if isCheckingOffer {
                    ProofLine(label: L10n.string("Today"), value: "…", emphasised: true)
                } else if isTrialEnabled || isWinBackFreeOffer {
                    timelineRows
                } else {
                    ProofLine(label: L10n.string("Today"), value: chargeText, emphasised: true)
                }

                Perforation().padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Included in Pro")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.paperMuted)
                    ForEach(features) { feature in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                                .accessibilityHidden(true)
                            Text(verbatim: feature.title)
                                .font(.footnote.weight(feature == trigger ? .semibold : .regular))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Perforation().padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("The Pausely Promise"))
                        .font(.footnote.weight(.semibold))
                    Text(LocalizedStringKey("Pausely keeps a receipt of what it saves you. If it doesn't save you more than it costs, it will tell you to cancel it."))
                        .font(.footnote)
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var slipTitle: String {
        if isWinBackFreeOffer {
            return L10n.string("Your \(trialDays)-day return plan")
        }
        if isTrialEnabled {
            return L10n.string("Your \(trialDays)-day plan")
        }
        return "Pausely Pro"
    }

    private var timelineRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                let isLast = index == steps.count - 1
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(step.isKeptAccent ? Color.paperKept : Color.paperInk)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        if !isLast {
                            Rectangle()
                                .fill(Color.paperShade)
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                                .padding(.vertical, 4)
                        }
                    }
                    .frame(width: 10)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        ProofLine(label: step.whenLabel, value: step.badge, emphasised: isLast || step.isKeptAccent)
                            .foregroundStyle(step.isKeptAccent ? Color.paperKept : Color.paperInk)
                        Text(verbatim: step.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.paperInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: step.detail)
                            .font(.footnote)
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, isLast ? 0 : 10)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
