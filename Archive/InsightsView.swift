import SwiftUI

// MARK: - Insights Color Palette
// Two accent colors only: gold (value/positive) and slate-blue (neutral/analytic)
private extension Color {
    static let insightGold   = Color(red: 0.788, green: 0.659, blue: 0.298)
    static let insightBlue   = Color(red: 0.33, green: 0.55, blue: 0.88)
    static let insightRed    = Color(red: 0.93, green: 0.35, blue: 0.35)
    static let insightCard   = Color(red: 0.082, green: 0.082, blue: 0.129)
    static let insightBorder = Color.white.opacity(0.07)
}

// MARK: - Premium Insights View
struct PremiumInsightsView: View {
    @StateObject private var store = SubscriptionStore.shared
    @State private var selectedTimeRange: TimeRange = .month
    @State private var appeared = false

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    insightsHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                    // Time Range
                    TimeRangeSelector(selected: $selectedTimeRange)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)

                    // 1. Subscription DNA
                    SubscriptionDNACard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 2. Temporal Value Engine
                    TemporalValueCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 3. Financial Forecast Nexus
                    ForecastNexusCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 4. Addiction Index
                    AddictionIndexCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 5. Smart Waste Detector
                    WasteDetectorCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 6. Peak Spending Timeline
                    PeakSpendingCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 7. Personality Type
                    PersonalityCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 8. Annual Regret Calculator
                    RegretCalculatorCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 9. Wealth Compounding Engine
                    WealthCompoundingCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 10. Lifetime Bill Reality Check
                    LifetimeBillCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 11. Subscription Overlap X-Ray
                    OverlapXRayCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    // 12. Negotiation Playbook
                    NegotiationPlaybookCard(store: store)
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    Spacer(minLength: 100)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(0.05)) {
                appeared = true
            }
        }
    }

    private var insightsHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Insights")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Understand your spending patterns")
                .font(.system(size: 16))
                .foregroundColor(TextColors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Time Range Selector (clean minimalist format)
struct TimeRangeSelector: View {
    @Binding var selected: PremiumInsightsView.TimeRange

    // Clean, minimalist labels without spaces
    private var rangeLabels: [(range: PremiumInsightsView.TimeRange, label: String)] {
        [
            (.week, "1W"),
            (.month, "1M"),
            (.year, "1Y"),
            (.all, "All")
        ]
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(rangeLabels, id: \.range) { item in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) { selected = item.range }
                }) {
                    Text(item.label)
                        .font(.system(size: 13, weight: selected == item.range ? .bold : .medium, design: .monospaced))
                        .foregroundColor(selected == item.range ? .black : TextColors.secondary)
                        .frame(width: 44, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected == item.range ? Color.insightGold : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(BackgroundColors.secondary)
        )
    }
}

// MARK: - Insight Card Container
struct InsightsCardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.insightCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.insightBorder, lineWidth: 1)
                    )
            )
    }
}

// MARK: - 1. Subscription DNA Helix Card
struct SubscriptionDNACard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var animated = false

    private var healthScore: Int {
        guard !store.subscriptions.isEmpty else { return 100 }
        let count = store.subscriptions.count
        let monthly = Double(truncating: store.totalMonthlySpend as NSDecimalNumber)
        // Score based on average cost per subscription and count
        // Lower average cost and moderate count = healthier
        let avgCost = monthly / Double(count)
        let costScore = max(0.0, min(50.0, 50.0 - (avgCost - 10.0) * 1.5))
        let countScore = max(0.0, min(30.0, 30.0 - Double(max(0, count - 5)) * 3.0))
        let baseScore = 70.0
        return min(98, max(25, Int(baseScore + costScore + countScore)))
    }

    private var healthColor: Color {
        if healthScore >= 80 { return .insightGold }
        if healthScore >= 55 { return .insightBlue }
        return .insightRed
    }

    private var healthLabel: String {
        if healthScore >= 80 { return "Healthy" }
        if healthScore >= 55 { return "Moderate" }
        return "Overspending"
    }

    private var dnaSegmentColors: [Color] {
        let palette: [Color] = [.insightGold, .insightBlue, .insightRed, Color.white.opacity(0.4), .insightGold.opacity(0.6)]
        return store.subscriptions.enumerated().map { palette[$0.offset % palette.count] }
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Subscription DNA")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            EstimatedBadge()
                        }
                        Text("Your financial genetic code")
                            .font(.system(size: 13))
                            .foregroundColor(TextColors.secondary)
                    }
                    Spacer()
                    // Health score ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 5)
                            .frame(width: 52, height: 52)
                        Circle()
                            .trim(from: 0, to: animated ? CGFloat(healthScore) / 100.0 : 0)
                            .stroke(healthColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(-90))
                        Text("\(healthScore)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(healthColor)
                    }
                }

                // DNA helix bar
                if store.subscriptions.isEmpty {
                    Text("Add subscriptions to see your DNA")
                        .font(.system(size: 14))
                        .foregroundColor(TextColors.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            ForEach(Array(store.subscriptions.enumerated()), id: \.element.id) { idx, sub in
                                let fraction = totalFraction(for: sub)
                                let barH = max(20, (geo.size.height - 20) * CGFloat(fraction) * 4)
                                VStack(spacing: 0) {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(dnaSegmentColors[idx % dnaSegmentColors.count])
                                        .frame(
                                            width: (geo.size.width - CGFloat((store.subscriptions.count - 1) * 3)) / CGFloat(max(1, store.subscriptions.count)),
                                            height: animated ? barH : 0
                                        )
                                }
                                .frame(maxHeight: .infinity, alignment: .bottom)
                            }
                        }
                    }
                    .frame(height: 80)
                    .animation(.easeOut(duration: 0.9).delay(0.15), value: animated)
                }

                HStack {
                    Circle()
                        .fill(healthColor)
                        .frame(width: 8, height: 8)
                    Text(healthLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(healthColor)
                    Spacer()
                    Text("\(store.subscriptions.count) active subscriptions")
                        .font(.system(size: 13))
                        .foregroundColor(TextColors.secondary)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) { animated = true }
        }
    }

    private func totalFraction(for sub: Subscription) -> Double {
        let monthly = Double(truncating: store.totalMonthlySpend as NSDecimalNumber)
        guard monthly > 0 else { return 0.1 }
        let amount = Double(truncating: sub.amount as NSDecimalNumber)
        return min(1.0, amount / monthly)
    }
}

// MARK: - 2. Temporal Value Engine
struct TemporalValueCard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var animated = false

    private struct ServiceTimeValue {
        let name: String
        let hoursPerDay: Double
        let monthlyAmount: Double
    }

    private var timeValues: [ServiceTimeValue] {
        // Rank subscriptions by monthly cost — shows where your money goes
        let subs = store.subscriptions.prefix(6)
        return subs.compactMap { sub in
            let amt = Double(truncating: sub.normalizedMonthlyCost as NSDecimalNumber)
            return ServiceTimeValue(name: sub.name, hoursPerDay: 0, monthlyAmount: amt)
        }.sorted { $0.monthlyAmount > $1.monthlyAmount }
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Spending Rank")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Your subscriptions by monthly cost")
                        .font(.system(size: 13))
                        .foregroundColor(TextColors.secondary)
                }

                if timeValues.isEmpty {
                    Text("Add subscriptions to see your spending rank")
                        .font(.system(size: 14))
                        .foregroundColor(TextColors.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    let maxMonthly = timeValues.map { $0.monthlyAmount }.max() ?? 1
                    VStack(spacing: 12) {
                        ForEach(Array(timeValues.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 12) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 90, alignment: .leading)
                                    .lineLimit(1)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.07))
                                            .frame(height: 10)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(idx == 0 ? Color.insightGold : Color.insightBlue.opacity(0.7))
                                            .frame(
                                                width: animated ? geo.size.width * CGFloat(item.monthlyAmount / maxMonthly) : 0,
                                                height: 10
                                            )
                                    }
                                }
                                .frame(height: 10)
                                .animation(.easeOut(duration: 0.8).delay(Double(idx) * 0.1), value: animated)

                                Text(String(format: "$%.0f/mo", item.monthlyAmount))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(idx == 0 ? .insightGold : TextColors.secondary)
                                    .frame(width: 72, alignment: .trailing)
                            }
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.insightGold)
                    Text(timeValues.first.map { "\($0.name) is your biggest subscription" } ?? "Add subscriptions to track spending")
                        .font(.system(size: 13))
                        .foregroundColor(.insightGold)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.insightGold.opacity(0.1))
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.3)) { animated = true }
        }
    }
}

// MARK: - 3. Financial Forecast Nexus
struct ForecastNexusCard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var displayAmount: Double = 0
    @State private var selectedScenario = 1

    private var monthlyDouble: Double {
        Double(truncating: store.totalMonthlySpend as NSDecimalNumber)
    }

    private var annualBase: Double { monthlyDouble * 12 }

    private struct Scenario {
        let label: String
        let multiplier: Double
        let icon: String
        let color: Color
        let description: String
    }

    private let scenarios: [Scenario] = [
        Scenario(label: "Current", multiplier: 1.0, icon: "arrow.right.circle.fill",
                 color: .insightBlue, description: "Status quo — spending continues"),
        Scenario(label: "Optimized", multiplier: 0.80, icon: "checkmark.circle.fill",
                 color: .insightGold, description: "Cancel low-value, switch to annual"),
        Scenario(label: "Nuclear", multiplier: 0.40, icon: "xmark.circle.fill",
                 color: .insightRed, description: "Cancel all but 2 essentials")
    ]

    private var selectedAmount: Double { annualBase * scenarios[selectedScenario].multiplier }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Financial Forecast")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Your spending trajectory over 12 months")
                        .font(.system(size: 13))
                        .foregroundColor(TextColors.secondary)
                }

                // Big animated number
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("$")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(scenarios[selectedScenario].color)
                    Text(String(format: "%.0f", displayAmount))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText(countsDown: selectedScenario > 0))
                    Text("/yr")
                        .font(.system(size: 18))
                        .foregroundColor(TextColors.secondary)
                }

                // Scenario selector
                HStack(spacing: 8) {
                    ForEach(0..<scenarios.count, id: \.self) { idx in
                        Button(action: {
                            withAnimation(.spring(response: 0.4)) {
                                selectedScenario = idx
                                displayAmount = annualBase * scenarios[idx].multiplier
                            }
                        }) {
                            VStack(spacing: 5) {
                                Image(systemName: scenarios[idx].icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(selectedScenario == idx ? scenarios[idx].color : TextColors.tertiary)
                                Text(scenarios[idx].label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(selectedScenario == idx ? scenarios[idx].color : TextColors.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedScenario == idx ? scenarios[idx].color.opacity(0.12) : Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedScenario == idx ? scenarios[idx].color.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Text(scenarios[selectedScenario].description)
                    .font(.system(size: 13))
                    .foregroundColor(TextColors.secondary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                displayAmount = selectedAmount
            }
        }
        .onChange(of: selectedScenario) { _, _ in
            withAnimation(.easeOut(duration: 0.5)) {
                displayAmount = selectedAmount
            }
        }
    }
}

// MARK: - 4. Subscription Addiction Index
struct AddictionIndexCard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var animated = false

    private struct AddictionItem {
        let name: String
        let score: Int        // 1–10
        let quitProbability: Int  // %
    }

    // Calculate churn risk based on actual subscription characteristics
    // Higher cost + longer tenure + annual billing = harder to cancel
    private func churnRisk(for sub: Subscription) -> Int {
        let normalizedCost = NSDecimalNumber(decimal: sub.normalizedMonthlyCost).doubleValue
        let isAnnual = sub.billingFrequency == .yearly

        // Cost factor: higher cost = more motivated to evaluate (higher risk to keep)
        let costRisk = min(10, Int(normalizedCost / 3))

        // Billing frequency factor: annual = commitment = lower churn risk
        let billingRisk = isAnnual ? 2 : 5

        // Combined score (higher = more at risk of regret)
        return min(10, costRisk + billingRisk)
    }

    private var addictionItems: [AddictionItem] {
        store.subscriptions.prefix(5).map { sub in
            let score = churnRisk(for: sub)
            // Higher score = more at risk of being a regret subscription
            let quitProbability = max(10, min(90, 100 - score * 8))
            return AddictionItem(name: sub.name, score: score, quitProbability: quitProbability)
        }.sorted { $0.score > $1.score }
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Addiction Index")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        EstimatedBadge()
                    }
                    Text("How dependent are you, really?")
                        .font(.system(size: 13))
                        .foregroundColor(TextColors.secondary)
                }

                if addictionItems.isEmpty {
                    Text("Add subscriptions to see your addiction profile")
                        .font(.system(size: 14))
                        .foregroundColor(TextColors.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 14) {
                        ForEach(Array(addictionItems.enumerated()), id: \.offset) { idx, item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Quit chance: \(item.quitProbability)%")
                                        .font(.system(size: 12))
                                        .foregroundColor(item.quitProbability > 50 ? .insightGold : TextColors.tertiary)
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.07))
                                            .frame(height: 8)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(addictionBarColor(score: item.score))
                                            .frame(
                                                width: animated ? geo.size.width * CGFloat(item.score) / 10.0 : 0,
                                                height: 8
                                            )
                                    }
                                }
                                .frame(height: 8)
                                .animation(.easeOut(duration: 0.7).delay(Double(idx) * 0.1), value: animated)

                                HStack {
                                    ForEach(1...10, id: \.self) { i in
                                        Circle()
                                            .fill(i <= item.score ? addictionBarColor(score: item.score) : Color.white.opacity(0.12))
                                            .frame(width: 6, height: 6)
                                    }
                                    Spacer()
                                    Text("Score: \(item.score)/10")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(addictionBarColor(score: item.score))
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) { animated = true }
        }
    }

    private func addictionBarColor(score: Int) -> Color {
        if score >= 8 { return .insightRed }
        if score >= 6 { return .insightGold }
        return .insightBlue
    }
}

// MARK: - 5. Smart Waste Detector
struct WasteDetectorCard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var pulseGlow = false

    // Flag subscriptions with highest cost as potential waste candidates
    // This is based on actual cost data, not an assumed percentage
    private var wastedMonthly: Decimal {
        guard !store.subscriptions.isEmpty else { return 0 }
        // Sum the cost of subscriptions beyond the top 3 most expensive
        let sorted = store.subscriptions.sorted { $0.normalizedMonthlyCost > $1.normalizedMonthlyCost }
        let top3 = Array(sorted.prefix(3))
        let top3Total = top3.reduce(Decimal(0)) { $0 + $1.normalizedMonthlyCost }
        let excess = store.totalMonthlySpend - top3Total
        return max(0, excess)
    }

    private var worstOffenders: [Subscription] {
        // Heuristic: subscriptions with the highest cost that we'd flag as risky
        Array(store.subscriptions
            .sorted { $0.normalizedMonthlyCost > $1.normalizedMonthlyCost }
            .prefix(3))
    }

    // Score based on how much above average this subscription costs
    private func wasteScore(for sub: Subscription) -> Int {
        guard !store.subscriptions.isEmpty else { return 0 }
        let avgCost = store.totalMonthlySpend / Decimal(store.subscriptions.count)
        let amount = sub.normalizedMonthlyCost
        let ratio = amount / avgCost
        // If it's more than 2x the average, it's a high waste risk
        let ratioDouble = Double(truncating: ratio as NSDecimalNumber)
        return min(95, Int(ratioDouble * 40))
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Waste Detector")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            EstimatedBadge()
                        }
                        Text("Money potentially unused each month")
                            .font(.system(size: 13))
                            .foregroundColor(TextColors.secondary)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.insightRed.opacity(pulseGlow ? 0.2 : 0.05))
                            .frame(width: 44, height: 44)
                            .blur(radius: pulseGlow ? 8 : 4)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.insightRed)
                    }
                }

                // Waste amount highlight
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatCurrency(wastedMonthly))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.insightRed)
                    Text("/ month in subscriptions beyond top 3")
                        .font(.system(size: 14))
                        .foregroundColor(TextColors.secondary)
                }

                if !worstOffenders.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(worstOffenders) { sub in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.insightRed.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Text(String(sub.name.prefix(1)))
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.insightRed)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Waste Score: \(wasteScore(for: sub))%")
                                        .font(.system(size: 12))
                                        .foregroundColor(.insightRed.opacity(0.8))
                                }

                                Spacer()

                                Text(formatCurrency(sub.normalizedMonthlyCost))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(TextColors.secondary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.04))
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - 6. Peak Spending Timeline (Radial Clock)
struct PeakSpendingCard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var animated = false

    // Show subscription distribution by relative cost weight
    // In a real implementation, this would use actual renewal dates from subscription data
    private var dayBuckets: [CGFloat] {
        guard !store.subscriptions.isEmpty else { return Array(repeating: 0, count: 12) }
        let sorted = store.subscriptions.sorted { $0.normalizedMonthlyCost > $1.normalizedMonthlyCost }
        var buckets = Array(repeating: CGFloat(0.0), count: 12)
        for (idx, sub) in sorted.enumerated() {
            let bucket = idx % 12
            let amt = Double(truncating: sub.normalizedMonthlyCost as NSDecimalNumber)
            buckets[bucket] += CGFloat(amt)
        }
        let mx = buckets.max() ?? 1
        return mx > 0 ? buckets.map { $0 / mx } : buckets
    }

    private var dangerIndex: Int {
        dayBuckets.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Subscription Distribution")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Your subscription cost breakdown by relative weight")
                        .font(.system(size: 13))
                        .foregroundColor(TextColors.secondary)
                }

                ZStack {
                    // Clock face
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(width: 200, height: 200)

                    // Radial bars for each segment
                    ForEach(0..<12, id: \.self) { i in
                        let angle = Double(i) / 12.0 * 360.0 - 90
                        let intensity = dayBuckets[i]
                        let barLen = 20 + (animated ? 55 * intensity : 0)

                        Rectangle()
                            .fill(intensity > 0.7 ? Color.insightRed : intensity > 0.4 ? Color.insightGold : Color.insightBlue.opacity(0.5))
                            .frame(width: 8, height: barLen)
                            .cornerRadius(4)
                            .offset(y: -(70 + barLen / 2))
                            .rotationEffect(.degrees(angle))
                            .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.05), value: animated)
                    }

                    // Center label
                    VStack(spacing: 3) {
                        Text("\(store.subscriptions.count)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.insightRed)
                        Text("Subs")
                            .font(.system(size: 11))
                            .foregroundColor(TextColors.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 16) {
                    LegendDot(color: .insightRed, label: "Heavy charge day")
                    LegendDot(color: .insightGold, label: "Moderate")
                    LegendDot(color: .insightBlue.opacity(0.5), label: "Light")
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) { animated = true }
        }
    }
}

// MARK: - 7. Subscription Personality
struct PersonalityCard: View {
    @ObservedObject var store: SubscriptionStore

    private enum PersonalityType: String {
        case entertainer = "The Entertainer"
        case powerUser = "The Power User"
        case collector = "The Collector"
        case minimalist = "The Minimalist"

        var icon: String {
            switch self {
            case .entertainer: return "tv.fill"
            case .powerUser: return "bolt.fill"
            case .collector: return "square.grid.3x3.fill"
            case .minimalist: return "leaf.fill"
            }
        }

        var roast: String {
            switch self {
            case .entertainer:
                return "You've subscribed to enough streaming services to fill a year without repeating a single show. And yet, somehow, you're still watching the same 3 things."
            case .powerUser:
                return "Every tool, every app, every addon. You spend more on productivity software than most people spend on rent. Impressive — now actually use it."
            case .collector:
                return "You collect subscriptions the way others collect regrets. Half of these apps haven't been opened since the free trial ended."
            case .minimalist:
                return "Clean. Intentional. Either you've mastered subscription hygiene, or you're just cheap. Either way — respect."
            }
        }

        var accentColor: Color {
            switch self {
            case .entertainer: return .insightBlue
            case .powerUser: return .insightGold
            case .collector: return .insightRed
            case .minimalist: return Color(red: 0.3, green: 0.75, blue: 0.45)
            }
        }
    }

    private var personality: PersonalityType {
        let count = store.subscriptions.count
        let subs = store.subscriptions
        let streamingCount = subs.filter { s in
            ["Netflix", "Hulu", "Disney", "HBO", "Apple TV", "YouTube", "Peacock", "Paramount"].contains(where: { s.name.localizedCaseInsensitiveContains($0) })
        }.count
        let productivityCount = subs.filter { s in
            ["Adobe", "Notion", "Slack", "Microsoft", "Dropbox", "Google", "Figma"].contains(where: { s.name.localizedCaseInsensitiveContains($0) })
        }.count

        if count <= 2 { return .minimalist }
        if count >= 7 { return .collector }
        if streamingCount >= 3 { return .entertainer }
        if productivityCount >= 2 { return .powerUser }
        return .collector
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Subscription Personality")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Based on your subscription mix")
                        .font(.system(size: 13))
                        .foregroundColor(TextColors.secondary)
                }

                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(personality.accentColor.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: personality.icon)
                            .font(.system(size: 28))
                            .foregroundColor(personality.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(personality.rawValue)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(personality.accentColor)
                        Text("\(store.subscriptions.count) subscriptions define you")
                            .font(.system(size: 13))
                            .foregroundColor(TextColors.secondary)
                    }
                }

                Text(personality.roast)
                    .font(.system(size: 14))
                    .foregroundColor(TextColors.secondary)
                    .lineSpacing(4)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(personality.accentColor.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - 8. Annual Regret Calculator
struct RegretCalculatorCard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var displaySavings: Double = 0
    @State private var display5yr: Double = 0

    private var worstValueSub: Subscription? {
        store.subscriptions.max(by: { $0.normalizedMonthlyCost < $1.normalizedMonthlyCost })
    }

    private var annualSavings: Double {
        guard let sub = worstValueSub else { return 0 }
        return Double(truncating: sub.normalizedMonthlyCost as NSDecimalNumber) * 12
    }

    // FV = PV * (1 + r)^n with annual contributions
    private var fiveYearValue: Double {
        let r = 0.07 / 12.0
        let n = 60.0  // 5 years in months
        let monthly = annualSavings / 12.0
        return monthly * ((pow(1 + r, n) - 1) / r)
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Annual Regret Calculator")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("The real cost of your worst-value sub")
                        .font(.system(size: 13))
                        .foregroundColor(TextColors.secondary)
                }

                if let sub = worstValueSub {
                    // Worst sub highlight
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.insightRed.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Text(String(sub.name.prefix(1)))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.insightRed)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sub.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Your worst-value subscription")
                                .font(.system(size: 12))
                                .foregroundColor(.insightRed)
                        }
                    }

                    // Financial breakdown
                    VStack(spacing: 12) {
                        RegretRow(
                            label: "Cancel today, save per year",
                            value: String(format: "$%.0f", displaySavings),
                            color: .insightGold
                        )
                        RegretRow(
                            label: "Invested at 7% over 5 years",
                            value: String(format: "$%.0f", display5yr),
                            color: .insightBlue
                        )
                        RegretRow(
                            label: "Over 10 years",
                            value: String(format: "$%.0f", fiveYearValue * 2.1),
                            color: Color(red: 0.3, green: 0.75, blue: 0.45)
                        )
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                    )

                    Text("That's not a subscription — that's a vacation.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TextColors.secondary)
                        .italic()
                } else {
                    Text("Add subscriptions to calculate your regret score")
                        .font(.system(size: 14))
                        .foregroundColor(TextColors.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4)) {
                displaySavings = annualSavings
                display5yr = fiveYearValue
            }
        }
    }
}

// MARK: - Small Helpers

struct RegretRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(TextColors.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(TextColors.tertiary)
        }
    }
}

// MARK: - 9. Wealth Compounding Engine
// Shows compound growth projections if you invested cancelled subscription money.
struct WealthCompoundingCard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var selectedIndex: Int = 0
    @State private var animated = false

    private struct CompoundResult {
        let years: Int
        let value: Double
    }

    private var targetSub: Subscription? {
        guard store.subscriptions.indices.contains(selectedIndex) else {
            return store.subscriptions.first
        }
        return store.subscriptions[selectedIndex]
    }

    private var monthlyInvestment: Double {
        guard let sub = targetSub else { return 0 }
        return Double(truncating: sub.normalizedMonthlyCost as NSDecimalNumber)
    }

    // Future value of monthly annuity: PMT × ((1+r)^n - 1) / r
    private func futureValue(years: Int) -> Double {
        let r = 0.07 / 12.0
        let n = Double(years * 12)
        return monthlyInvestment * ((pow(1 + r, n) - 1) / r)
    }

    private var milestones: [CompoundResult] {
        [1, 5, 10, 20].map { CompoundResult(years: $0, value: futureValue(years: $0)) }
    }

    private var maxValue: Double { milestones.map(\.value).max() ?? 1 }

    private func formatK(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "$%.0fK", v / 1_000) }
        return String(format: "$%.0f", v)
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Wealth Compounding Engine")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Cancel one sub. Invest the money. Watch it grow.")
                        .font(.system(size: 13))
                        .foregroundColor(TextColors.secondary)
                }

                if store.subscriptions.isEmpty {
                    Text("Add subscriptions to unlock the compounding engine")
                        .font(.system(size: 14))
                        .foregroundColor(TextColors.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    // Subscription picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(store.subscriptions.prefix(6).enumerated()), id: \.offset) { idx, sub in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedIndex = idx
                                        animated = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        withAnimation(.easeOut(duration: 0.8)) { animated = true }
                                    }
                                }) {
                                    Text(sub.name)
                                        .font(.system(size: 13, weight: selectedIndex == idx ? .semibold : .medium))
                                        .foregroundColor(selectedIndex == idx ? .white : TextColors.tertiary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(selectedIndex == idx ? Color.insightGold.opacity(0.25) : Color.white.opacity(0.05))
                                                .overlay(
                                                    Capsule().stroke(selectedIndex == idx ? Color.insightGold.opacity(0.5) : Color.clear, lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Monthly investment amount
                    if let sub = targetSub {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .foregroundColor(.insightGold)
                                .font(.system(size: 14))
                            Text("Investing \(String(format: "$%.2f", monthlyInvestment))/month from cancelling \(sub.name)")
                                .font(.system(size: 13))
                                .foregroundColor(TextColors.secondary)
                        }
                    }

                    // Compound growth bars
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(milestones, id: \.years) { milestone in
                            VStack(spacing: 8) {
                                Text(formatK(milestone.value))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.insightGold)

                                GeometryReader { geo in
                                    VStack {
                                        Spacer()
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.insightGold.opacity(0.4), .insightGold],
                                                    startPoint: .bottom,
                                                    endPoint: .top
                                                )
                                            )
                                            .frame(height: animated ? geo.size.height * CGFloat(milestone.value / maxValue) : 4)
                                            .animation(.easeOut(duration: 0.8).delay(Double(milestones.firstIndex(where: { $0.years == milestone.years }) ?? 0) * 0.12), value: animated)
                                    }
                                }

                                Text("\(milestone.years)yr")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(TextColors.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 120)

                    Text("At 7% avg annual return (S&P 500 historical average)")
                        .font(.system(size: 11))
                        .foregroundColor(TextColors.tertiary)
                        .italic()
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.3)) { animated = true }
        }
    }
}

// MARK: - 10. Lifetime Bill Reality Check
// Shows estimated total subscription cost over remaining years.
// Uses a standard life expectancy figure for illustration purposes.
struct LifetimeBillCard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var displayTotal: Double = 0
    @State private var userAge: Double = 28

    private var monthlyDouble: Double {
        Double(truncating: store.totalMonthlySpend as NSDecimalNumber)
    }

    // US average life expectancy at birth: 76.1 years (CDC, 2022).
    // This is a statistical average — actual life expectancy varies by individual.
    // The slider allows users to adjust for their own situation.
    private static let lifeExpectancy: Double = 76.1
    private var yearsRemaining: Double { max(0, Self.lifeExpectancy - userAge) }
    private var lifetimeTotal: Double { monthlyDouble * 12 * yearsRemaining }

    private var lifetimeContext: String {
        let t = lifetimeTotal
        if t > 500_000 { return "That's a luxury penthouse. Your subscriptions would buy one." }
        if t > 100_000 { return "That's a brand-new car every 5 years, forever." }
        if t > 50_000 { return "That's a college degree. Spent on subscriptions." }
        if t > 20_000 { return "That's 10+ international round-trips you'll never take." }
        return "Small now. Compounded over a lifetime? A different story."
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("The Lifetime Bill")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("What you'll spend on subscriptions before you die")
                            .font(.system(size: 13))
                            .foregroundColor(TextColors.secondary)
                    }
                    Spacer()
                    Image(systemName: "hourglass")
                        .font(.system(size: 22))
                        .foregroundColor(TextColors.tertiary)
                }

                // Age slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Your age")
                            .font(.system(size: 13))
                            .foregroundColor(TextColors.tertiary)
                        Spacer()
                        Text("\(Int(userAge)) yrs • \(Int(yearsRemaining)) remaining")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(TextColors.secondary)
                    }
                    Slider(value: $userAge, in: 18...70, step: 1)
                        .tint(.insightGold)
                        .onChange(of: userAge) { _, _ in
                            withAnimation(.easeOut(duration: 0.4)) {
                                displayTotal = lifetimeTotal
                            }
                        }
                    Text("Life expectancy: US CDC average (76.1 yrs, 2022 estimate). Adjust slider to match your situation.")
                        .font(.system(size: 11))
                        .foregroundColor(TextColors.tertiary)
                        .italic()
                }

                // The big number
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total lifetime subscription cost")
                        .font(.system(size: 12))
                        .foregroundColor(TextColors.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.insightRed)
                        Text(String(format: "%.0f", displayTotal))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                    }
                }

                // Visual lifetime bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.insightBlue, .insightRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(yearsRemaining / 60), height: 10)
                    }
                }
                .frame(height: 10)

                Text(lifetimeContext)
                    .font(.system(size: 13))
                    .foregroundColor(TextColors.secondary)
                    .lineSpacing(3)
                    .italic()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                displayTotal = lifetimeTotal
            }
        }
    }
}

// MARK: - 11. Subscription Overlap X-Ray
// Detects when you're paying for multiple services in the same category.
struct OverlapXRayCard: View {
    @ObservedObject var store: SubscriptionStore

    private struct CategoryGroup {
        let category: String
        let subs: [Subscription]
        let color: Color
        var isRedundant: Bool { subs.count > 1 }
        var wasteMonthly: Decimal {
            guard subs.count > 1 else { return 0 }
            // Waste = everything except the cheapest service
            let sorted = subs.sorted { $0.normalizedMonthlyCost < $1.normalizedMonthlyCost }
            return sorted.dropFirst().reduce(Decimal(0)) { $0 + $1.normalizedMonthlyCost }
        }
    }

    private let categoryKeywords: [(name: String, keywords: [String], color: Color)] = [
        ("Video Streaming", ["Netflix","Hulu","Disney","HBO","Apple TV","YouTube","Peacock","Paramount","AMC","Discovery"], .insightBlue),
        ("Music", ["Spotify","Apple Music","Tidal","Deezer","Amazon Music","Pandora","YouTube Music"], Color(red: 0.4, green: 0.7, blue: 0.4)),
        ("Cloud Storage", ["iCloud","Dropbox","Google One","OneDrive","Box"], .insightGold),
        ("Productivity", ["Notion","Slack","Asana","Monday","Trello","ClickUp","Linear"], Color(red: 0.6, green: 0.4, blue: 0.9)),
        ("Creative", ["Adobe","Canva","Figma","Sketch","Procreate"], .insightRed),
    ]

    private var groups: [CategoryGroup] {
        categoryKeywords.compactMap { cat in
            let matches = store.subscriptions.filter { sub in
                cat.keywords.contains(where: { sub.name.localizedCaseInsensitiveContains($0) })
            }
            guard !matches.isEmpty else { return nil }
            return CategoryGroup(category: cat.name, subs: matches, color: cat.color)
        }
    }

    private var totalWaste: Decimal {
        groups.reduce(Decimal(0)) { $0 + $1.wasteMonthly }
    }

    private func formatDecimal(_ d: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: d as NSDecimalNumber) ?? "$0"
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Overlap X-Ray")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Detecting redundant subscriptions in your stack")
                            .font(.system(size: 13))
                            .foregroundColor(TextColors.secondary)
                    }
                    Spacer()
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.insightBlue)
                }

                if groups.isEmpty {
                    Text("Add more subscriptions to detect overlaps")
                        .font(.system(size: 14))
                        .foregroundColor(TextColors.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 10) {
                        ForEach(groups, id: \.category) { group in
                            HStack(spacing: 12) {
                                // Category indicator
                                Circle()
                                    .fill(group.color)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(group.category)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        if group.isRedundant {
                                            Text("OVERLAP")
                                                .font(.system(size: 11, weight: .black))
                                                .foregroundColor(.insightRed)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.insightRed.opacity(0.15)))
                                        }
                                    }
                                    Text(group.subs.map(\.name).joined(separator: " + "))
                                        .font(.system(size: 12))
                                        .foregroundColor(TextColors.tertiary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if group.isRedundant {
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(formatDecimal(group.wasteMonthly))
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.insightRed)
                                        Text("wasted/mo")
                                            .font(.system(size: 11))
                                            .foregroundColor(TextColors.tertiary)
                                    }
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(group.color.opacity(0.6))
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(group.isRedundant ? Color.insightRed.opacity(0.06) : Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(group.isRedundant ? Color.insightRed.opacity(0.2) : Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                    }

                    if totalWaste > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.insightRed)
                            Text("You're wasting \(formatDecimal(totalWaste))/month on overlapping services")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.insightRed)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.insightRed.opacity(0.08))
                        )
                    } else {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.insightGold)
                            Text("No overlapping subscriptions detected. Clean stack.")
                                .font(.system(size: 13))
                                .foregroundColor(.insightGold)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 12. Negotiation Playbook
// Provides suggested timing and talking points for requesting provider discounts.
struct NegotiationPlaybookCard: View {
    @ObservedObject var store: SubscriptionStore
    @State private var expandedIndex: Int? = nil

    private struct NegotiationPlay {
        let service: String
        let timing: String
        let script: String
        let successLabel: String
        let avgSaving: String
        let color: Color
    }

    private let knownPlays: [NegotiationPlay] = [
        NegotiationPlay(
            service: "Netflix",
            timing: "Month 3 after any price increase",
            script: "\"I've been a customer for [X] years and I'm considering switching to Max. Is there anything you can offer to keep me?\"",
            successLabel: "Often successful",
            avgSaving: "$3–5/mo",
            color: Color(red: 0.9, green: 0.2, blue: 0.2)
        ),
        NegotiationPlay(
            service: "Spotify",
            timing: "After your first 12 months",
            script: "\"I'm evaluating Apple Music. I love Spotify but the price is hard to justify. What can you do for me?\"",
            successLabel: "Sometimes works",
            avgSaving: "$1–3/mo",
            color: Color(red: 0.12, green: 0.73, blue: 0.34)
        ),
        NegotiationPlay(
            service: "Adobe",
            timing: "Any time (they want to keep you)",
            script: "\"I'm reviewing my creative tools budget. I need to cut costs — what loyalty options do you have?\"",
            successLabel: "Often successful",
            avgSaving: "$10–20/mo",
            color: Color(red: 0.98, green: 0.35, blue: 0.15)
        ),
        NegotiationPlay(
            service: "Hulu",
            timing: "Before annual renewal",
            script: "\"I'm about to cancel since I barely use it. Is there a pause or discount option before I go?\"",
            successLabel: "Often successful",
            avgSaving: "$2–4/mo",
            color: Color(red: 0.35, green: 0.8, blue: 0.45)
        ),
        NegotiationPlay(
            service: "Disney+",
            timing: "Bundle period (any time)",
            script: "\"I'm thinking of the Hulu bundle — can you confirm the best current rate you'd give an existing subscriber?\"",
            successLabel: "Sometimes works",
            avgSaving: "$3–6/mo",
            color: Color(red: 0.1, green: 0.3, blue: 0.9)
        )
    ]

    // Only show plays for subscriptions the user actually has
    private var relevantPlays: [NegotiationPlay] {
        let subs = store.subscriptions
        if subs.isEmpty { return Array(knownPlays.prefix(3)) }
        let matched = knownPlays.filter { play in
            subs.contains(where: { $0.name.localizedCaseInsensitiveContains(play.service) })
        }
        return matched.isEmpty ? Array(knownPlays.prefix(3)) : matched
    }

    var body: some View {
        InsightsCardContainer {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Negotiation Playbook")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Suggested scripts for requesting discounts")
                            .font(.system(size: 13))
                            .foregroundColor(TextColors.secondary)
                    }
                    Spacer()
                    EstimatedBadge()
                }

                VStack(spacing: 10) {
                    ForEach(Array(relevantPlays.enumerated()), id: \.offset) { idx, play in
                        VStack(spacing: 0) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedIndex = expandedIndex == idx ? nil : idx
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(play.color.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Text(String(play.service.prefix(1)))
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(play.color)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(play.service)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("\(play.successLabel) · Save \(play.avgSaving)")
                                            .font(.system(size: 12))
                                            .foregroundColor(TextColors.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: expandedIndex == idx ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(TextColors.tertiary)
                                }
                                .padding(12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())

                            if expandedIndex == idx {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.insightGold)
                                        Text("When: \(play.timing)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.insightGold)
                                    }

                                    Text("What to say:")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(TextColors.tertiary)

                                    Text(play.script)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .lineSpacing(3)
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(play.color.opacity(0.08))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(play.color.opacity(0.2), lineWidth: 1)
                                                )
                                        )

                                    // Success likelihood indicator
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Success likelihood")
                                            .font(.system(size: 11))
                                            .foregroundColor(TextColors.tertiary)
                                        Text(play.successLabel)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(play.color)
                                        Text("Results vary based on timing, provider, and individual circumstances.")
                                            .font(.system(size: 11))
                                            .foregroundColor(TextColors.tertiary)
                                            .italic()
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.bottom, 14)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(expandedIndex == idx ? play.color.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                }

                Text("Scripts are suggestions only. Results vary and are not guaranteed.")
                    .font(.system(size: 11))
                    .foregroundColor(TextColors.tertiary)
                    .italic()
            }
        }
    }
}

// normalizedMonthlyCost is an alias for the model's existing monthlyCost property.
// Used throughout this file for clarity.
private extension Subscription {
    var normalizedMonthlyCost: Decimal { monthlyCost }
}

// MARK: - Estimated Badge for Heuristic Cards
/// A badge indicating that a metric is algorithmically estimated, not factually verified.
struct EstimatedBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 9))
            Text("Estimated")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(4)
    }
}

#Preview {
    PremiumInsightsView()
}
