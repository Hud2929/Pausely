import SwiftUI

// MARK: - Smart Pause Alert View
/// Displays intelligent pause suggestions based on actual usage data
struct SmartPauseAlertView: View {
    let suggestion: PauseSuggestion
    let onPause: () -> Void
    let onDismiss: () -> Void
    let onAdjustThreshold: () -> Void

    @AccessibilityFocusState private var focusedElement: FocusElement?

    enum FocusElement {
        case primaryAction
    }

    @State private var showDetails = false
    @State private var selectedDuration: PauseDuration
    
    init(suggestion: PauseSuggestion, onPause: @escaping () -> Void, onDismiss: @escaping () -> Void, onAdjustThreshold: @escaping () -> Void = {}) {
        self.suggestion = suggestion
        self.onPause = onPause
        self.onDismiss = onDismiss
        self.onAdjustThreshold = onAdjustThreshold
        _selectedDuration = State(initialValue: suggestion.suggestedDuration)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with urgency indicator
            headerSection
            
            ScrollView {
                VStack(spacing: 20) {
                    // Usage visualization
                    usageSection
                    
                    // Cost analysis
                    costAnalysisSection
                    
                    // Duration selector
                    durationSelectorSection
                    
                    // Reason
                    reasonSection
                }
                .padding()
            }
            
            // Action buttons
            actionButtonsSection
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
        .onAppear {
            focusedElement = .primaryAction
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon and title
            ZStack {
                Circle()
                    .fill(suggestion.urgencyLevel.color.opacity(0.2))
                    .frame(width: 70, height: 70)
                
                Image(systemName: suggestion.urgencyLevel.icon)
                    .font(.title)
                    .foregroundColor(suggestion.urgencyLevel.color)
            }
            
            VStack(spacing: 4) {
                Text(suggestion.urgencyLevel.title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)

                Text(suggestion.subscription.name)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            suggestion.urgencyLevel.color.opacity(0.1)
        )
    }
    
    // MARK: - Usage Section
    private var usageSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Usage This Month")
                    .font(.body.weight(.semibold))
                
                Spacer()
                
                Button(action: { showDetails.toggle() }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // Usage bar visualization
            VStack(spacing: 8) {
                HStack {
                    Text("Used")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(suggestion.formattedUsage)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(suggestion.currentUsageMinutes < 30 ? .orange : .primary)

                    // Show badge when usage is from Screen Time (estimated)
                    EstimateBadge(isEstimated: suggestion.dataSource == .screenTime)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(usageGradient)
                            .frame(width: usageBarWidth(in: geometry.size.width), height: 12)
                            .animation(.easeInOut(duration: 0.5), value: suggestion.currentUsageMinutes)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Text("0h")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Typical: 10h/month")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("30h")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    detailRow(icon: "clock", title: "Daily Average", value: dailyAverage)
                    detailRow(icon: "calendar", title: "Days Used This Month", value: "~\(estimatedDaysUsed) days")
                    detailRow(icon: "flame", title: "Last Used", value: "Recently")
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Cost Analysis Section
    private var costAnalysisSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Cost Analysis")
                    .font(.body.weight(.semibold))
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Current cost per hour
                costCard(
                    title: "Current Cost/Hour",
                    value: formattedCostPerHour,
                    subtitle: "Based on your usage",
                    color: costPerHourColor,
                    icon: "dollarsign.circle"
                )
                
                // Potential savings
                costCard(
                    title: "You Could Save",
                    value: formattedSavings,
                    subtitle: "If paused for \(selectedDuration.displayName)",
                    color: .green,
                    icon: "piggy.bank"
                )
            }
            
            // Efficiency rating
            HStack(spacing: 12) {
                Image(systemName: efficiencyIcon)
                    .font(.title2)
                    .foregroundColor(efficiencyColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Value Rating: \(efficiencyRating)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(efficiencyColor)

                    Text(efficiencyDescription)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(12)
            .background(efficiencyColor.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Duration Selector Section
    private var durationSelectorSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("How Long to Pause?")
                    .font(.body.weight(.semibold))
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PauseDuration.allCases) { duration in
                        durationButton(duration)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            Text("You can unpause anytime. We'll remind you before it resumes.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Reason Section
    private var reasonSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundColor(.yellow)
            
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            Spacer()
        }
        .padding(16)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: onPause) {
                HStack {
                    Image(systemName: "pause.circle.fill")
                    Text("Pause for \(selectedDuration.displayName)")
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [.luxuryPurple, .luxuryPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .accessibilityFocused($focusedElement, equals: .primaryAction)
            
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Not Now")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                }
                
                Button(action: onAdjustThreshold) {
                    Text("Adjust Alerts")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.luxuryPurple)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.luxuryPurple.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Views
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
    }
    
    private func costCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private func durationButton(_ duration: PauseDuration) -> some View {
        Button(action: { selectedDuration = duration }) {
            VStack(spacing: 4) {
                Text(duration.displayName)
                    .font(.subheadline.weight(selectedDuration == duration ? .semibold : .medium))

                Text(saveAmount(for: duration))
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .foregroundColor(selectedDuration == duration ? .white : .primary)
            .frame(width: 80, height: 60)
            .background(
                selectedDuration == duration ?
                AnyView(LinearGradient(colors: [.luxuryPurple, .luxuryPink], startPoint: .leading, endPoint: .trailing)) :
                AnyView(Color(.tertiarySystemBackground))
            )
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    private var usageGradient: LinearGradient {
        if suggestion.currentUsageMinutes < 30 {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        } else if suggestion.currentUsageMinutes < 60 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.green], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private func usageBarWidth(in totalWidth: CGFloat) -> CGFloat {
        let maxMinutes: CGFloat = 600 // 10 hours
        let percentage = min(CGFloat(suggestion.currentUsageMinutes) / maxMinutes, 1.0)
        return totalWidth * percentage
    }
    
    private var dailyAverage: String {
        let avg = Double(suggestion.currentUsageMinutes) / 30.0
        if avg < 1 {
            return "< 1 min/day"
        } else if avg < 60 {
            return "\(Int(avg)) min/day"
        } else {
            let hours = Int(avg) / 60
            let mins = Int(avg) % 60
            return mins > 0 ? "\(hours)h \(mins)m/day" : "\(hours)h/day"
        }
    }
    
    private var estimatedDaysUsed: Int {
        max(1, suggestion.currentUsageMinutes / 30)
    }
    
    private var formattedCostPerHour: String {
        let cph = suggestion.costPerHour
        guard cph > 0 else { return "N/A" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = suggestion.subscription.currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: cph as NSDecimalNumber) ?? "\(cph)"
    }
    
    private var formattedSavings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = suggestion.subscription.currency
        formatter.maximumFractionDigits = 0
        let savings = calculateSavings(for: selectedDuration)
        return formatter.string(from: savings as NSDecimalNumber) ?? "\(savings)"
    }
    
    private func saveAmount(for duration: PauseDuration) -> String {
        let savings = calculateSavings(for: duration)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = suggestion.subscription.currency
        formatter.maximumFractionDigits = 0
        return "Save " + (formatter.string(from: savings as NSDecimalNumber) ?? "\(savings)")
    }
    
    private func calculateSavings(for duration: PauseDuration) -> Decimal {
        let monthlyAmount = suggestion.monthlyCost
        let multiplier: Decimal
        
        switch duration {
        case .oneWeek: multiplier = 0.25
        case .twoWeeks: multiplier = 0.5
        case .oneMonth: multiplier = 1
        case .twoMonths: multiplier = 2
        case .threeMonths: multiplier = 3
        case .sixMonths: multiplier = 6
        }
        
        return monthlyAmount * multiplier
    }
    
    private var costPerHourColor: Color {
        let cph = suggestion.costPerHour
        guard cph > 0 else { return .secondary }
        let doubleCph = Double(truncating: cph as NSNumber)
        if doubleCph > 20 { return .red }
        if doubleCph > 10 { return .orange }
        if doubleCph > 5 { return .yellow }
        return .green
    }
    
    private var efficiencyRating: String {
        let cph = suggestion.costPerHour
        guard cph > 0 else { return "Unknown" }
        let doubleCph = Double(truncating: cph as NSNumber)
        if doubleCph > 20 { return "Poor" }
        if doubleCph > 10 { return "Fair" }
        if doubleCph > 5 { return "Good" }
        return "Excellent"
    }
    
    private var efficiencyColor: Color {
        let cph = suggestion.costPerHour
        guard cph > 0 else { return .secondary }
        let doubleCph = Double(truncating: cph as NSNumber)
        if doubleCph > 20 { return .red }
        if doubleCph > 10 { return .orange }
        if doubleCph > 5 { return .yellow }
        return .green
    }
    
    private var efficiencyIcon: String {
        let cph = suggestion.costPerHour
        guard cph > 0 else { return "questionmark.circle" }
        let doubleCph = Double(truncating: cph as NSNumber)
        if doubleCph > 20 { return "exclamationmark.triangle.fill" }
        if doubleCph > 10 { return "exclamationmark.circle.fill" }
        if doubleCph > 5 { return "checkmark.circle.fill" }
        return "star.fill"
    }
    
    private var efficiencyDescription: String {
        let cph = suggestion.costPerHour
        guard cph > 0 else { return "Usage data not available" }
        let doubleCph = Double(truncating: cph as NSNumber)
        if doubleCph > 20 {
            return "You're paying \(formattedCostPerHour) per hour of use. That's very expensive!"
        } else if doubleCph > 10 {
            return "At \(formattedCostPerHour)/hour, consider if this subscription is worth it."
        } else if doubleCph > 5 {
            return "You're getting reasonable value at \(formattedCostPerHour)/hour."
        } else {
            return "Great value! Only \(formattedCostPerHour) per hour of entertainment."
        }
    }
}

// MARK: - Smart Pause Banner (for inline display)
struct SmartPauseBanner: View {
    let suggestion: PauseSuggestion
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(suggestion.urgencyLevel.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: suggestion.urgencyLevel.icon)
                        .font(.headline)
                        .foregroundColor(suggestion.urgencyLevel.color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save \(suggestion.formattedSavings) on \(suggestion.subscription.name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("You've only used it for \(suggestion.formattedUsage) this month")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.luxuryPurple)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [suggestion.urgencyLevel.color.opacity(0.1), suggestion.urgencyLevel.color.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(suggestion.urgencyLevel.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Smart Pause Dashboard Card
struct SmartPauseDashboardCard: View {
    let suggestions: [PauseSuggestion]
    let onViewAll: () -> Void
    
    var totalPotentialSavings: Decimal {
        suggestions.reduce(0) { $0 + $1.potentialSavings }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Pause Suggestions")
                        .font(.headline.weight(.bold))
                    
                    Text("Based on your actual usage")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if suggestions.count > 0 {
                    Text("\(suggestions.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            LinearGradient(colors: [.luxuryPurple, .luxuryPink], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(10)
                }
            }
            
            if suggestions.isEmpty {
                // Empty state
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("You're using all your subscriptions well!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Total savings potential
                HStack(spacing: 12) {
                    Image(systemName: "piggy.bank.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Potential Monthly Savings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(formattedTotalSavings)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
                // Preview of top suggestion
                if let first = suggestions.first {
                    SmartPauseBanner(
                        suggestion: first,
                        onTap: onViewAll,
                        onDismiss: {}
                    )
                }
                
                // View all button
                Button(action: onViewAll) {
                    HStack {
                        Text("View All Suggestions")
                            .font(.subheadline.weight(.semibold))

                        Image(systemName: "arrow.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundColor(.luxuryPurple)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.luxuryPurple.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
    
    private var formattedTotalSavings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = suggestions.first?.subscription.currency ?? "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: totalPotentialSavings as NSDecimalNumber) ?? "\(totalPotentialSavings)"
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            SmartPauseDashboardCard(
                suggestions: [],
                onViewAll: {}
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
