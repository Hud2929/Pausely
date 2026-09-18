import SwiftUI

struct SubscriptionDetailView: View {
    let subscription: Subscription
    @Binding var isPresented: Bool
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    @State private var showingCancelFlow = false
    @State private var showingPaywall = false
    @State private var communityScore: (score: Double, count: Int)? = nil
    @ObservedObject private var paymentManager = PaymentManager.shared

    var cardColor: Color {
        Color.accentMint
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Top Bar
                    HStack {
                        Button(action: {
                            HapticStyle.light.trigger()
                            isPresented = false
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                Text("Back")
                                    .font(.system(.body, design: .rounded).weight(.medium))
                            }
                            .foregroundStyle(Color.obsidianTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Header Card
                    VStack(spacing: 14) {
                        ServiceLogoView(name: subscription.name, category: subscription.category, size: 72)

                        Text(subscription.name)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)

                        let converted = currencyManager.convertToSelected(
                            subscription.amount,
                            from: subscription.currency
                        )
                        Text(currencyManager.format(converted))
                            .font(.system(.largeTitle, design: .rounded).weight(.black))
                            .foregroundStyle(cardColor)

                        Text(subscription.billingFrequency.billingPeriodLabel)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(Color.obsidianTextSecondary)

                        // Cost per day — makes spending concrete
                        let dailyCost = currencyManager.convertToSelected(subscription.monthlyCost, from: subscription.currency) / 30
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                            Text("\(currencyManager.format(dailyCost)) per day")
                                .font(.system(.caption, design: .rounded).weight(.medium))
                        }
                        .foregroundStyle(Color.obsidianTextTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.obsidianSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(cardColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    // Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DETAILS")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                            .tracking(2)
                            .padding(.horizontal, 20)

                        VStack(spacing: 1) {
                            SubscriptionDetailRow(icon: "calendar", title: "Next Billing", value: renewalDateText)
                            SubscriptionDetailRow(icon: "tag", title: "Category", value: subscription.category ?? "Other")
                            SubscriptionDetailRow(icon: "checkmark.circle", title: "Status", value: subscription.status.displayName)
                            SubscriptionDetailRow(icon: "dollarsign.circle", title: "Annual Equivalent", value: annualEquivalentText)
                            SubscriptionDetailRow(icon: "clock.arrow.circlepath", title: "Total Paid Since Added", value: totalPaidText)
                            if let cs = communityScore {
                                let starCount = max(1, min(5, Int(cs.score.rounded())))
                                let stars = String(repeating: "★", count: starCount)
                                SubscriptionDetailRow(
                                    icon: "person.2.fill",
                                    title: "Cancel Difficulty",
                                    value: "\(stars) \(String(format: "%.1f", cs.score)) (\(cs.count) ratings)"
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Cancel Timing Calculator
                    if subscription.nextBillingDate != nil {
                        CancelTimingCard(subscription: subscription)
                            .padding(.horizontal, 20)
                    }

                    // Lifetime Cost Reality Check
                    LifetimeCostCard(subscription: subscription)
                        .padding(.horizontal, 20)

                    // Actions — Edit (secondary) → Cancel (destructive-tinted) → Remove (destructive)
                    VStack(spacing: 10) {
                        // Edit — secondary style
                        Button(action: {
                            HapticStyle.light.trigger()
                            showingEditSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("Edit Subscription")
                                    .font(.system(.callout, design: .rounded).weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.obsidianElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Cancel Subscription — destructive-tinted style
                        Button(action: {
                            HapticStyle.medium.trigger()
                            if paymentManager.isPremium {
                                showingCancelFlow = true
                            } else {
                                showingPaywall = true
                            }
                        }) {
                            HStack {
                                Image(systemName: paymentManager.isPremium ? "xmark.circle" : "lock.fill")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("Cancel Subscription")
                                Spacer()
                                if paymentManager.isPremium, let cs = communityScore {
                                    HStack(spacing: 3) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(.caption2, design: .rounded))
                                        Text(String(format: "%.1f", cs.score))
                                            .font(.system(.caption, design: .rounded).weight(.bold))
                                        Text("(\(cs.count))")
                                            .font(.system(.caption2, design: .rounded))
                                    }
                                    .foregroundStyle(Color.red.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                                } else if !paymentManager.isPremium {
                                    Text("Pro")
                                        .font(.system(.caption, design: .rounded).weight(.bold))
                                        .foregroundStyle(Color.accentMint)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.accentMint.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                            .foregroundStyle(paymentManager.isPremium ? Color.red : Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(paymentManager.isPremium ? Color.red.opacity(0.12) : Color.obsidianElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(paymentManager.isPremium ? Color.red.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Remove — bare destructive, confirmation required
                        Button(action: {
                            HapticStyle.heavy.trigger()
                            showingDeleteConfirm = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("Remove")
                                    .font(.system(.callout, design: .rounded).weight(.semibold))
                            }
                            .foregroundStyle(Color.semanticDestructive)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.semanticDestructive.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.semanticDestructive.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer(minLength: 60)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .alert("Delete Subscription?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    _ = try? await store.deleteSubscription(id: subscription.id)
                    await MainActor.run { isPresented = false }
                }
            }
        } message: {
            Text("This will permanently remove \(subscription.name) from your subscriptions.")
        }
        .sheet(isPresented: $showingEditSheet) {
            SubscriptionManagementView(subscription: subscription)
        }
        .sheet(isPresented: $showingCancelFlow) {
            CancelSubscriptionFlow(subscription: subscription)
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
        .task {
            communityScore = await CancelDifficultyService.shared.fetchScore(for: subscription.name)
        }
    }

    var renewalDateText: String {
        guard let date = subscription.nextBillingDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var annualEquivalentText: String {
        // annualCost already handles all billing frequencies correctly
        let converted = currencyManager.convertToSelected(subscription.annualCost, from: subscription.currency)
        return currencyManager.format(converted) + "/yr"
    }

    var totalPaidText: String {
        let start = subscription.startDate ?? subscription.createdAt
        let months = Calendar.current.dateComponents([.month], from: start, to: Date()).month ?? 0
        // Use monthlyCost so billing frequency is factored in (yearly plan: amount/12, etc.)
        let converted = currencyManager.convertToSelected(subscription.monthlyCost, from: subscription.currency)
        let total = converted * Decimal(max(0, months))
        let formatted = currencyManager.format(total)
        if months <= 0 { return "\(formatted) since added" }
        return "\(formatted) over \(months) mo"
    }
}

// MARK: - Cancel Timing Card

private struct CancelTimingCard: View {
    let subscription: Subscription
    @ObservedObject private var currencyManager = CurrencyManager.shared

    private var cycleDays: Int {
        switch subscription.billingFrequency {
        case .weekly:      return 7
        case .biweekly:    return 14
        case .monthly:     return 30
        case .quarterly:   return 91
        case .semiannual:  return 182
        case .yearly:      return 365
        }
    }

    private var lastBillingDate: Date? {
        guard let next = subscription.nextBillingDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: -cycleDays, to: next)
    }

    private var daysUsed: Int {
        guard let last = lastBillingDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0)
    }

    private var daysRemaining: Int {
        guard let next = subscription.nextBillingDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 0)
    }

    private var progress: Double {
        guard cycleDays > 0 else { return 0 }
        return min(1, Double(daysUsed) / Double(cycleDays))
    }

    private var valueUsed: Decimal {
        currencyManager.convertToSelected(
            subscription.monthlyCost * Decimal(progress),
            from: subscription.currency
        )
    }

    private var valueRemaining: Decimal {
        currencyManager.convertToSelected(
            subscription.monthlyCost * Decimal(1 - progress),
            from: subscription.currency
        )
    }

    private var timingAdvice: (text: String, color: Color) {
        let daysToWait = max(0, cycleDays / 2 - daysUsed)
        switch progress {
        case 0.85...:
            return ("Great time to cancel — you've used most of this cycle.", .green)
        case 0.50..<0.85:
            return ("Decent timing — \(daysRemaining) \(daysRemaining == 1 ? "day" : "days") left in this cycle.", .yellow)
        default:
            return ("You just got billed — wait \(daysToWait) more \(daysToWait == 1 ? "day" : "days") for better timing.", .orange)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack {
                Label("Cancel Timing", systemImage: "clock.badge.checkmark.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(progress * 100))% used")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(timingAdvice.color)
                        .frame(width: max(0, geo.size.width * progress), height: 8)
                }
            }
            .frame(height: 8)

            // Value row
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(currencyManager.format(valueUsed))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("consumed")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(currencyManager.format(valueRemaining))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(timingAdvice.color)
                    Text("remaining")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.obsidianTextTertiary)
                }
            }

            // Advice pill
            HStack(spacing: 7) {
                Circle()
                    .fill(timingAdvice.color)
                    .frame(width: 7, height: 7)
                Text(timingAdvice.text)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(18)
        .surfaceCard(cornerRadius: 20, elevated: true)
    }
}

// MARK: - Lifetime Cost Card

private struct LifetimeCostCard: View {
    let subscription: Subscription
    @ObservedObject private var cm = CurrencyManager.shared

    private var monthly: Decimal {
        cm.convertToSelected(subscription.monthlyCost, from: subscription.currency)
    }

    // Conservative estimate: 30 years to retirement (used for lifetime cost projection)
    private let retirementYears: Int = 30

    private struct Projection {
        let label: String
        let years: Int
    }

    private let projections: [Projection] = [
        Projection(label: "1 year",  years: 1),
        Projection(label: "5 years", years: 5),
        Projection(label: "10 years", years: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lifetime Cost", systemImage: "infinity.circle.fill")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                ForEach(projections.indices, id: \.self) { i in
                    let p = projections[i]
                    let cost = monthly * 12 * Decimal(p.years)
                    VStack(spacing: 4) {
                        Text(p.label)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.obsidianTextTertiary)
                        Text(cm.format(cost))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(i == 0 ? .white : i == 1 ? .orange : .red)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    if i < projections.count - 1 {
                        Divider().background(Color.white.opacity(0.08)).frame(height: 30)
                    }
                }
            }

            // Retirement bomb
            let retirementCost = monthly * 12 * Decimal(retirementYears)
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.red)
                Text("Keep until retirement: ")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary) +
                Text(cm.format(retirementCost))
                    .font(.system(.caption2, design: .rounded).weight(.black))
                    .foregroundStyle(.red)
            }
            .padding(8)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(18)
        .surfaceCard(cornerRadius: 20, elevated: true)
    }
}
