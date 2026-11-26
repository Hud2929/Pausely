import SwiftUI

/// Billing cadence options for Pausely Pro, kept alongside `PaywallPlanPicker` so `StoreKitUpgradeView` stays modular.
enum PaywallPlanOption {
    case monthly, annual

    var tier: SubscriptionTier {
        switch self {
        case .monthly: return .pro
        case .annual: return .proAnnual
        }
    }

    var productID: String {
        switch self {
        case .monthly: return StoreKitManager.ProductID.monthly.rawValue
        case .annual: return StoreKitManager.ProductID.annual.rawValue
        }
    }

    var title: String {
        switch self {
        case .monthly: return L10n.string("Monthly")
        case .annual: return L10n.string("Annual")
        }
    }

    var period: String {
        switch self {
        case .monthly: return L10n.string("/month")
        case .annual: return L10n.string("/year")
        }
    }

    /// The store's price with its period ("$4.99/month"), the one place the two meet.
    func priced(_ amount: String) -> String {
        "\(amount)\(period)"
    }

    /// "Save N%" computed from the real App Store prices; nil until StoreKit has loaded them.
    @MainActor var savings: String? {
        switch self {
        case .monthly: return nil
        case .annual:
            guard let percent = StoreKitManager.shared.annualSavingsPercent else { return nil }
            return L10n.string("Save \(percent)%")
        }
    }

    @MainActor var badge: String? { savings }
}

/// Annual and Monthly plan selector for `StoreKitUpgradeView`.
/// Sits side-by-side in two compact columns at standard text sizes so the personalized trial plan
/// sits cleanly above the fold, and stacks full-width at accessibility text sizes.
struct PaywallPlanPicker: View {
    @Binding var selectedPlan: StoreKitUpgradeView.PlanOption
    let monthlyPrice: String
    let annualPrice: String
    let annualPerMonth: String?
    let annualBadge: String?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                stackedCard(.annual, price: annualPrice, perMonth: annualPerMonth, badge: annualBadge)
                stackedCard(.monthly, price: monthlyPrice, perMonth: nil, badge: nil)
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                compactCard(.annual, price: annualPrice, perMonth: annualPerMonth, badge: annualBadge)
                compactCard(.monthly, price: monthlyPrice, perMonth: nil, badge: nil)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func compactCard(_ plan: StoreKitUpgradeView.PlanOption, price: String,
                             perMonth: String?, badge: String?) -> some View {
        let isOn = selectedPlan == plan
        return Button {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) { selectedPlan = plan }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                        .font(.body)
                        .foregroundStyle(isOn ? Color.paper : Color.inkTextFaint)
                        .accessibilityHidden(true)
                    Text(verbatim: plan.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOn ? Color.inkText : Color.inkTextMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Text(verbatim: plan.priced(price))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if let perMonth {
                    Text(verbatim: BillingFrequency.monthly.priced(perMonth))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.inkTextMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let badge {
                    badgeView(badge, highlighted: isOn)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(isOn ? Color.inkRaised : Color.clear,
                        in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous)
                    .stroke(isOn ? Color.paper : Color.outline, lineWidth: isOn ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier(plan == .annual ? "planAnnual" : "planMonthly")
    }

    private func stackedCard(_ plan: StoreKitUpgradeView.PlanOption, price: String,
                             perMonth: String?, badge: String?) -> some View {
        let isOn = selectedPlan == plan
        return Button {
            Feel.selection()
            withAnimation(Motion.unlessReduced(Motion.touch)) { selectedPlan = plan }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.paper : Color.inkTextFaint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: plan.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOn ? Color.inkText : Color.inkTextMuted)
                    Text(verbatim: price)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(verbatim: plan.period)
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                    if let perMonth {
                        Text(verbatim: BillingFrequency.monthly.priced(perMonth))
                            .font(.footnote)
                            .foregroundStyle(Color.inkTextMuted)
                    }
                    if let badge { badgeView(badge, highlighted: isOn) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? Color.inkRaised : Color.clear,
                        in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous)
                    .stroke(isOn ? Color.paper : Color.outline, lineWidth: isOn ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier(plan == .annual ? "planAnnual" : "planMonthly")
    }

    private func badgeView(_ text: String, highlighted: Bool) -> some View {
        Text(verbatim: text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(highlighted ? Color.paperInk : Color.inkText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(highlighted ? Color.paper : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(highlighted ? Color.clear : Color.outline, lineWidth: 1))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
