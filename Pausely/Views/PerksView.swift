import SwiftUI

// MARK: - Smart Perk Optimizer
@MainActor
struct PerksView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var perkEngine = PerkEngine.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var selectedTab: PerkTab = .discover
    @State private var selectedPerk: SmartPerk?
    @State private var appear = false
    
    enum PerkTab: String, CaseIterable {
        case discover = "Discover"
        case active = "Active"
        case saved = "Saved"
        
        var icon: String {
            switch self {
            case .discover: return "sparkles"
            case .active: return "checkmark.circle"
            case .saved: return "dollarsign.circle"
            }
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                savingsDashboard
                tabSelector
                contentSection
                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
            perkEngine.analyzeSubscriptions(store.subscriptions)
        }
        .sheet(item: $selectedPerk) { perk in
            PerkActionSheet(perk: perk, engine: perkEngine)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.luxuryGold.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    ))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                Image(systemName: "wand.and.stars")
                    .font(.largeTitle.weight(.light))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.luxuryGold, .white],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .accessibilityLabel("Smart perks")
            }
            
            VStack(spacing: 6) {
                Text("Smart Perks")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("AI-powered subscription optimization")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    
    private var savingsDashboard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Total Money Saved")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currencyManager.currentCurrency.symbol)
                        .font(.title2.bold())
                        .foregroundStyle(Color.luxuryGold)

                    Text("\(Int(perkEngine.totalMoneySaved))")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                }

                if perkEngine.totalMoneySaved > 0 {
                    Text("You're optimizing like a pro!")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.luxuryTeal)
                } else {
                    Text("Discover perks below to start saving")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Divider().background(.white.opacity(0.1))
            
            HStack(spacing: 0) {
                PerkStatBox(value: "\(perkEngine.discoveredPerks.count)", label: "Found", color: Color.luxuryTeal)
                Divider().background(.white.opacity(0.1))
                PerkStatBox(value: "\(perkEngine.activePerks.count)", label: "Active", color: Color.luxuryGold)
                Divider().background(.white.opacity(0.1))
                PerkStatBox(value: "\(perkEngine.completedActions.count)", label: "Actions", color: Color.luxuryPink)
            }
        }
        .padding()
        .glassCard(color: Color.luxuryGold)
        .padding(.horizontal, 20)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(PerkTab.allCases, id: \.self) { tab in
                TabButton(title: tab.rawValue, icon: tab.icon, isSelected: selectedTab == tab) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var contentSection: some View {
        switch selectedTab {
        case .discover:
            DiscoverSection(perks: perkEngine.discoveredPerks) { selectedPerk = $0 }
        case .active:
            ActiveSection(perks: perkEngine.activePerks, engine: perkEngine)
        case .saved:
            SavedSection(engine: perkEngine)
        }
    }
}

// MARK: - Perk Engine
@MainActor
class PerkEngine: ObservableObject {
    static let shared = PerkEngine()
    
    @Published var discoveredPerks: [SmartPerk] = []
    @Published var activePerks: [ActivePerk] = []
    @Published var completedActions: [PerkAction] = []
    @Published var totalMoneySaved: Double = 0
    
    private init() { loadSavedData() }
    
    func analyzeSubscriptions(_ subscriptions: [Subscription]) {
        var newPerks: [SmartPerk] = []
        for subscription in subscriptions {
            newPerks.append(contentsOf: findPerks(for: subscription))
        }
        let activeIds = Set(activePerks.map { $0.sourceSubscriptionId })
        discoveredPerks = newPerks.filter { !activeIds.contains($0.sourceSubscriptionId) }
    }
    
    private func findPerks(for subscription: Subscription) -> [SmartPerk] {
        var perks: [SmartPerk] = []
        let name = subscription.name.lowercased()
        let monthlyCost = Double(truncating: subscription.amount as NSNumber)
        
        if name.contains("netflix") || name.contains("hulu") || name.contains("disney") {
            perks.append(SmartPerk(
                id: "\(subscription.id)-amex",
                title: "Amex: Streaming Credit",
                description: "Get $20/month credit for streaming",
                sourceSubscriptionId: subscription.id,
                sourceName: subscription.name,
                estimatedSavings: 240,
                difficulty: .easy,
                steps: ["Open Amex app", "Go to Benefits", "Link subscription"],
                provider: "American Express",
                icon: "creditcard.fill",
                color: "gold"
            ))
        }
        
        if monthlyCost > 5 {
            perks.append(SmartPerk(
                id: "\(subscription.id)-student",
                title: "Switch to Student Plan",
                description: "Save 50% with student verification",
                sourceSubscriptionId: subscription.id,
                sourceName: subscription.name,
                estimatedSavings: monthlyCost * 6,
                difficulty: .medium,
                steps: ["Go to settings", "Select Student Plan", "Verify email"],
                provider: subscription.name,
                icon: "graduationcap.fill",
                color: "blue"
            ))
        }
        
        if subscription.billingFrequency == .monthly && monthlyCost > 10 {
            perks.append(SmartPerk(
                id: "\(subscription.id)-annual",
                title: "Switch to Annual",
                description: "Save ~17% paying yearly",
                sourceSubscriptionId: subscription.id,
                sourceName: subscription.name,
                estimatedSavings: monthlyCost * 2,
                difficulty: .easy,
                steps: ["Go to Billing", "Select Annual", "Confirm"],
                provider: subscription.name,
                icon: "calendar.badge.clock",
                color: "green"
            ))
        }
        
        if subscription.canPause {
            perks.append(SmartPerk(
                id: "\(subscription.id)-pause",
                title: "Smart Pause Available",
                description: "Pause during low-usage",
                sourceSubscriptionId: subscription.id,
                sourceName: subscription.name,
                estimatedSavings: monthlyCost * 3,
                difficulty: .easy,
                steps: ["Tap Pause", "Select duration", "Confirm"],
                provider: subscription.name,
                icon: "pause.circle.fill",
                color: "orange"
            ))
        }
        
        return perks
    }
    
    func activatePerk(_ perk: SmartPerk) {
        let active = ActivePerk(
            id: UUID(),
            perkId: perk.id,
            title: perk.title,
            sourceSubscriptionId: perk.sourceSubscriptionId,
            sourceName: perk.sourceName,
            estimatedAnnualSavings: perk.estimatedSavings,
            activatedDate: Date(),
            icon: perk.icon,
            color: perk.color
        )
        activePerks.append(active)
        discoveredPerks.removeAll { $0.id == perk.id }
        completeAction(title: "Activated: \(perk.title)", moneySaved: perk.estimatedSavings)
        saveData()
    }
    
    func completeAction(title: String, moneySaved: Double) {
        let action = PerkAction(id: UUID(), title: title, date: Date(), moneySaved: moneySaved)
        completedActions.insert(action, at: 0)
        totalMoneySaved += moneySaved
        saveData()
    }
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(activePerks) {
            UserDefaults.standard.set(encoded, forKey: "active_perks")
        }
        if let encoded = try? JSONEncoder().encode(completedActions) {
            UserDefaults.standard.set(encoded, forKey: "completed_actions")
        }
        UserDefaults.standard.set(totalMoneySaved, forKey: "total_money_saved")
    }
    
    private func loadSavedData() {
        if let data = UserDefaults.standard.data(forKey: "active_perks"),
           let decoded = try? JSONDecoder().decode([ActivePerk].self, from: data) {
            activePerks = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "completed_actions"),
           let decoded = try? JSONDecoder().decode([PerkAction].self, from: data) {
            completedActions = decoded
        }
        totalMoneySaved = UserDefaults.standard.double(forKey: "total_money_saved")
    }
}

// MARK: - Models
struct SmartPerk: Identifiable {
    let id: String
    let title: String
    let description: String
    let sourceSubscriptionId: UUID
    let sourceName: String
    let estimatedSavings: Double
    let difficulty: Difficulty
    let steps: [String]
    let provider: String
    let icon: String
    let color: String
    
    enum Difficulty: String { case easy = "Easy", medium = "Medium", hard = "Hard" }
}

struct ActivePerk: Identifiable, Codable {
    let id: UUID
    let perkId: String
    let title: String
    let sourceSubscriptionId: UUID
    let sourceName: String
    let estimatedAnnualSavings: Double
    let activatedDate: Date
    let icon: String
    let color: String
}

struct PerkAction: Identifiable, Codable {
    let id: UUID
    let title: String
    let date: Date
    let moneySaved: Double
}

// MARK: - Section Views
struct DiscoverSection: View {
    let perks: [SmartPerk]
    let onSelect: (SmartPerk) -> Void
    @State private var showingTrialProtection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Trial Protection Promo Banner (only show if trials exist)
            if !TrialProtectionStore.shared.trials.isEmpty {
                TrialProtectionPromoBanner {
                    showingTrialProtection = true
                }
                .padding(.horizontal, 20)
            }
            
            HStack {
                Text("Recommended for You")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(perks.count) found")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            
            if perks.isEmpty {
                ArtisticEmptyState(
                    icon: "sparkles",
                    title: "No perks found",
                    message: "Add subscriptions to discover savings and optimization opportunities.",
                    action: nil,
                    actionTitle: nil
                )
                .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(perks.enumerated()), id: \.element.id) { index, perk in
                        PerkCard(perk: perk) { onSelect(perk) }
                            .listRowEntrance(index: index)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showingTrialProtection) {
            TrialProtectionView()
        }
    }
}

// MARK: - Virtual Card Promo Banner
struct TrialProtectionPromoBanner: View {
    let action: () -> Void
    @ObservedObject private var trialStore = TrialProtectionStore.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.luxuryTeal, Color.luxuryPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "shield.checkered")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trial Protection")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Track free trials, get reminders, cancel before you get charged!")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if trialStore.activeTrials.count > 0 {
                    Text("\(trialStore.activeTrials.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.luxuryTeal)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.luxuryTeal.opacity(0.5), Color.luxuryPurple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActiveSection: View {
    let perks: [ActivePerk]
    let engine: PerkEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Optimizations")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
            
            if perks.isEmpty {
                ArtisticEmptyState(
                    icon: "checkmark.circle",
                    title: "No active perks",
                    message: "Go to Discover to activate perks and start saving money.",
                    action: nil,
                    actionTitle: nil
                )
                .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(perks.enumerated()), id: \.element.id) { index, perk in
                        ActivePerkCard(perk: perk)
                            .listRowEntrance(index: index)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct SavedSection: View {
    let engine: PerkEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Actions")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
            
            if engine.completedActions.isEmpty {
                ArtisticEmptyState(
                    icon: "dollarsign.circle",
                    title: "No savings yet",
                    message: "Complete actions to track your savings over time.",
                    action: nil,
                    actionTitle: nil
                )
                .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(engine.completedActions.prefix(5).enumerated()), id: \.element.id) { index, action in
                        ActionCard(action: action)
                            .listRowEntrance(index: index)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Card Views
struct PerkCard: View {
    let perk: SmartPerk
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticStyle.medium.trigger()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(colorFor(perk.color).opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: perk.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(colorFor(perk.color))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(perk.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(perk.description)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        DifficultyBadge(difficulty: perk.difficulty)
                        Text("Save $\(Int(perk.estimatedSavings))/year")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.luxuryGold)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding()
            .glass(intensity: 0.08, tint: .white)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1)
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = pressing }
        }, perform: {})
    }
    
    private func colorFor(_ colorName: String) -> Color {
        switch colorName {
        case "gold": return Color.luxuryGold
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "teal": return Color.luxuryTeal
        default: return Color.luxuryGold
        }
    }
}

struct ActivePerkCard: View {
    let perk: ActivePerk
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(colorFor(perk.color).opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: perk.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(colorFor(perk.color))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(perk.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Saving $\(Int(perk.estimatedAnnualSavings))/year")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.luxuryGold)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .padding()
        .glass(intensity: 0.1, tint: colorFor(perk.color))
    }
    
    private func colorFor(_ colorName: String) -> Color {
        switch colorName {
        case "gold": return Color.luxuryGold
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "teal": return Color.luxuryTeal
        default: return Color.luxuryGold
        }
    }
}

struct ActionCard: View {
    let action: PerkAction
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.luxuryGold)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(action.date, style: .date)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text("+\(Int(action.moneySaved))")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.luxuryGold)
        }
        .padding()
        .glass(intensity: 0.06, tint: .white)
    }
}

// MARK: - Detail Sheet
struct PerkActionSheet: View {
    let perk: SmartPerk
    @ObservedObject var engine: PerkEngine
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var isCompleted = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(colorFor(perk.color).opacity(0.2))
                                .frame(width: 80, height: 80)
                            Image(systemName: perk.icon)
                                .font(.system(size: 36))
                                .foregroundStyle(colorFor(perk.color))
                        }
                        
                        Text(perk.title)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(perk.description)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 12) {
                        Text("Potential Annual Savings")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))

                        Text("$\(Int(perk.estimatedSavings))")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.luxuryGold)

                        DifficultyBadge(difficulty: perk.difficulty)
                    }
                    .padding()
                    .glassCard(color: colorFor(perk.color))
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Follow these steps:")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(Array(perk.steps.enumerated()), id: \.offset) { index, step in
                                PerkStepRow(number: index + 1, text: step, isCompleted: index < currentStep)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 30)

                    VStack(spacing: 12) {
                        if currentStep < perk.steps.count {
                            Button(action: { currentStep += 1 }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle")
                                    Text("Complete Step \(currentStep + 1)")
                                }
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.luxuryGold))
                            }
                        } else if !isCompleted {
                            Button(action: completePerk) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Mark as Complete")
                                }
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.luxuryTeal))
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Completed!")
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.green))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Optimize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func completePerk() {
        isCompleted = true
        engine.activatePerk(perk)
        dismiss()
    }
    
    private func colorFor(_ colorName: String) -> Color {
        switch colorName {
        case "gold": return Color.luxuryGold
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "teal": return Color.luxuryTeal
        default: return Color.luxuryGold
        }
    }
}

struct PerkStepRow: View {
    let number: Int
    let text: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.luxuryTeal.opacity(0.2) : .white.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.luxuryTeal)
                } else {
                    Text("\(number)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isCompleted ? .white.opacity(0.6) : .white)
                .strikethrough(isCompleted)
        }
        .padding()
        .glass(intensity: isCompleted ? 0.04 : 0.08, tint: .white)
    }
}

// MARK: - Supporting Views
struct PerkStatBox: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

struct DifficultyBadge: View {
    let difficulty: SmartPerk.Difficulty
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(difficultyColor.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(difficulty.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(difficultyColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(difficultyColor.opacity(0.15)))
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.luxuryGold : Color.clear)
            )
            .scaleEffect(pressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(title) tab")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { pressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressed = false } }
        )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title.weight(.regular))
                .foregroundStyle(.white.opacity(0.3))
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(message)")
    }
}

#Preview {
    PerksView()
}
