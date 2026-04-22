//
//  TrialProtectionView.swift
//  Pausely
//
//  Revolutionary Trial Protection - NO virtual cards needed!
//  Track trials, get reminders, one-tap cancel
//

import SwiftUI

@MainActor
struct TrialProtectionView: View {
    @ObservedObject private var store = TrialProtectionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showingAddSheet = false
    @State private var showingTemplates = false
    @State private var selectedTrial: TrackedTrial?
    @State private var selectedTab: TrialTab = .active
    
    enum TrialTab: String, CaseIterable {
        case active = "Active"
        case history = "History"
        case stats = "Stats"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [Color(.systemBackground), Color(.systemGray6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Stats header
                    statsHeader
                    
                    // Tab selector
                    tabSelector
                    
                    // Content
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            switch selectedTab {
                            case .active:
                                activeTrialsSection
                            case .history:
                                historySection
                            case .stats:
                                statsSection
                            }
                        }
                        .padding()
                    }
                }
                
                // Celebration overlay
                if store.showCelebration {
                    CelebrationView(amount: store.lastSavedAmount)
                }
            }
            .navigationTitle("Trial Protection")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Label("Add Custom Trial", systemImage: "plus.circle")
                        }
                        
                        Button {
                            showingTemplates = true
                        } label: {
                            Label("Quick Add", systemImage: "bolt.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTrialSheet()
            }
            .sheet(isPresented: $showingTemplates) {
                TrialTemplatesSheet()
            }
            .sheet(item: $selectedTrial) { trial in
                TrialDetailSheet(trial: trial)
            }
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack(spacing: 20) {
            StatBadge(
                value: "\(store.activeTrials.count)",
                label: "Active",
                icon: "clock.fill",
                color: .blue
            )
            
            StatBadge(
                value: "\(store.stats.totalTrialsCancelled)",
                label: "Cancelled",
                icon: "checkmark.shield.fill",
                color: .green
            )
            
            StatBadge(
                value: currencyManager.format(store.totalSaved),
                label: "Saved",
                icon: "dollarsign.circle.fill",
                color: .yellow
            )
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(TrialTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    // MARK: - Active Trials Section
    
    private var activeTrialsSection: some View {
        Group {
            if store.activeTrials.isEmpty {
                EmptyStateView(
                    icon: "shield.checkered",
                    title: "No Active Trials",
                    message: "Start tracking your free trials to never get charged again!"
                )
            } else {
                // Urgent section - ending soon
                let endingSoon = store.trialsEndingSoon
                if !endingSoon.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Ending Soon!", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(endingSoon) { trial in
                            TrialEndingCard(trial: trial)
                        }
                    }
                    .padding(.bottom)
                }
                
                // Regular active trials
                ForEach(store.activeTrials.filter { !$0.isEndingSoon }) { trial in
                    TrialCard(trial: trial) {
                        selectedTrial = trial
                    }
                }
            }
        }
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        Group {
            if store.pastTrials.isEmpty {
                EmptyStateView(
                    icon: "archivebox",
                    title: "No History",
                    message: "Your cancelled and converted trials will appear here"
                )
            } else {
                ForEach(store.pastTrials) { trial in
                    TrialHistoryCard(trial: trial)
                }
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            // Summary card
            VStack(spacing: 12) {
                Text("Your Trial Protection Impact")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(store.stats.totalTrialsTracked)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Trials Tracked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Text("\(store.stats.totalTrialsCancelled)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Cancelled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Text(currencyManager.format(store.totalSaved))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                        Text("Money Saved")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            
            // How it works
            VStack(alignment: .leading, spacing: 12) {
                Text("How Trial Protection Works")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HowItWorksStep(
                    number: 1,
                    title: "Add Your Trial",
                    description: "When you start a free trial, add it here with the end date"
                )
                
                HowItWorksStep(
                    number: 2,
                    title: "Get Reminders",
                    description: "We'll notify you 2 days before, 1 day before, and on the last day"
                )
                
                HowItWorksStep(
                    number: 3,
                    title: "One-Tap Cancel",
                    description: "Tap cancel and we'll take you directly to the cancellation page"
                )
                
                HowItWorksStep(
                    number: 4,
                    title: "Track Savings",
                    description: "See how much money you've saved by cancelling unwanted trials!"
                )
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - Trial Card

struct TrialCard: View {
    let trial: TrackedTrial
    let onTap: () -> Void
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: trial.status.icon)
                        .font(.title2)
                        .foregroundColor(trial.status.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trial.serviceName)
                            .font(.headline)
                        
                        Text(trial.status.displayName)
                            .font(.caption)
                            .foregroundColor(trial.status.color)
                    }
                    
                    Spacer()
                    
                    // Days remaining badge
                    if trial.daysRemaining > 0 {
                        Text("\(trial.daysRemaining)d")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(trial.isEndingSoon ? .orange : .white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(trial.isEndingSoon ? Color.orange.opacity(0.2) : Color.blue.opacity(0.3))
                            .cornerRadius(8)
                    }
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(progressColor)
                            .frame(width: geo.size.width * CGFloat(trial.progressPercentage / 100), height: 6)
                    }
                }
                .frame(height: 6)
                
                // Footer info
                HStack {
                    Label("\(currencyManager.format(trial.costAfterTrial))/mo after", systemImage: "dollarsign.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Ends \(trial.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(trial.status.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var progressColor: Color {
        if trial.progressPercentage > 80 {
            return .red
        } else if trial.progressPercentage > 60 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Trial Ending Card (Urgent)

struct TrialEndingCard: View {
    let trial: TrackedTrial
    @ObservedObject private var store = TrialProtectionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showingCancelOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(trial.serviceName) trial ends soon!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(trial.hoursRemaining) hours remaining")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
            }
            
            Text("You'll be charged \(currencyManager.format(trial.costAfterTrial))/month starting tomorrow unless you cancel.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button {
                    showingCancelOptions = true
                } label: {
                    Text("Cancel Now")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                
                Button {
                    store.convertTrial(trial)
                } label: {
                    Text("Keep It")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .confirmationDialog("Cancel \(trial.serviceName)?", isPresented: $showingCancelOptions, titleVisibility: .visible) {
            if let url = store.getCancelURL(for: trial.serviceName) {
                Link("Open Cancel Page", destination: url)
            }
            Button("I've Already Cancelled", role: .destructive) {
                store.cancelTrial(trial)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("We'll open the cancellation page for you. After cancelling, mark it here to track your savings!")
        }
    }
}

// MARK: - Trial History Card

struct TrialHistoryCard: View {
    let trial: TrackedTrial
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trial.status.icon)
                .font(.title2)
                .foregroundColor(trial.status.color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trial.serviceName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(trial.status.displayName)
                    .font(.caption)
                    .foregroundColor(trial.status.color)
            }
            
            Spacer()
            
            if trial.status == .cancelled {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Saved")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(currencyManager.format(trial.estimatedAnnualSavings))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Celebration View

struct CelebrationView: View {
    let amount: Decimal
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated circles
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(Color.green.opacity(0.3), lineWidth: 2)
                            .frame(width: 150 + CGFloat(i * 40), height: 150 + CGFloat(i * 40))
                            .scaleEffect(showContent ? 1 : 0.5)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(Double(i) * 0.1), value: showContent)
                    }
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .scaleEffect(showContent ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showContent)
                }
                
                VStack(spacing: 8) {
                    Text("Trial Cancelled!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("You just saved")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(currencyManager.format(amount))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Text("per year")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: showContent)
            }
        }
        .onAppear {
            showContent = true
        }
    }
}

// MARK: - Add Trial Sheet

struct AddTrialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TrialProtectionStore.shared
    
    @State private var serviceName = ""
    @State private var durationDays = 7
    @State private var costAfterTrial = ""
    @State private var selectedCategory = "Entertainment"
    
    let categories = ["Entertainment", "Productivity", "Music", "Health", "Education", "Shopping", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Trial Details") {
                    TextField("Service Name (e.g., Netflix)", text: $serviceName)
                        .submitLabel(.next)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section("Trial Duration") {
                    Stepper("Duration: \(durationDays) days", value: $durationDays, in: 1...90)
                    
                    HStack {
                        ForEach([7, 14, 30, 60], id: \.self) { days in
                            Button {
                                durationDays = days
                            } label: {
                                Text("\(days)d")
                                    .font(.caption)
                                    .fontWeight(durationDays == days ? .bold : .regular)
                                    .foregroundColor(durationDays == days ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(durationDays == days ? Color.blue : Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("After Trial") {
                    HStack {
                        Text(CurrencyManager.shared.currentCurrency.symbol)
                        TextField("Monthly cost", text: $costAfterTrial)
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                    }
                }
            }
            .navigationTitle("Add Trial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTrial()
                    }
                    .disabled(serviceName.isEmpty || costAfterTrial.isEmpty)
                    .accessibilityHint(serviceName.isEmpty || costAfterTrial.isEmpty ? "Please enter a service name and cost after trial" : "")
                }
            }
        }
    }
    
    private func addTrial() {
        guard let cost = Decimal(string: costAfterTrial) else { return }
        
        _ = store.addTrial(
            serviceName: serviceName,
            durationDays: durationDays,
            costAfterTrial: cost,
            category: selectedCategory
        )
        
        dismiss()
    }
}

// MARK: - Trial Templates Sheet

struct TrialTemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TrialProtectionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(TrialProtectionStore.templates) { template in
                    Button {
                        _ = store.quickAddTrial(from: template)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: template.icon)
                                .font(.title2)
                                .foregroundColor(template.color)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.serviceName)
                                    .font(.headline)
                                
                                HStack(spacing: 8) {
                                    Label("\(template.trialDays)d trial", systemImage: "clock")
                                        .font(.caption)
                                    
                                    Text("•")
                                        .font(.caption)
                                    
                                    Label("\(currencyManager.format(template.monthlyCost))/mo", systemImage: "dollarsign.circle")
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Quick Add Trial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Trial Detail Sheet

struct TrialDetailSheet: View {
    let trial: TrackedTrial
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TrialProtectionStore.shared
    @State private var showingCancelOptions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: trial.status.icon)
                            .font(.system(size: 60))
                            .foregroundColor(trial.status.color)
                        
                        Text(trial.serviceName)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(trial.status.displayName)
                            .font(.headline)
                            .foregroundColor(trial.status.color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(trial.status.color.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(icon: "calendar", title: "Started", value: trial.startDate.formatted(date: .long, time: .omitted))
                        DetailRow(icon: "clock.fill", title: "Ends", value: trial.endDate.formatted(date: .long, time: .omitted))
                        DetailRow(icon: "dollarsign.circle", title: "Monthly Cost", value: "\(trial.costAfterTrial)")
                        DetailRow(icon: "tag", title: "Category", value: trial.category)
                        
                        if trial.daysRemaining > 0 {
                            DetailRow(icon: "hourglass", title: "Days Remaining", value: "\(trial.daysRemaining)")
                        }
                        
                        if trial.status == .cancelled {
                            DetailRow(icon: "dollarsign.circle.fill", title: "Annual Savings", value: "\(trial.estimatedAnnualSavings)")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    
                    // Actions
                    if trial.status == .active || trial.status == .endingSoon {
                        VStack(spacing: 12) {
                            Button {
                                showingCancelOptions = true
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Cancel This Trial")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                            
                            Button {
                                store.convertTrial(trial)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Keep This Subscription")
                                }
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Trial Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Cancel \(trial.serviceName)?", isPresented: $showingCancelOptions, titleVisibility: .visible) {
                if let url = store.getCancelURL(for: trial.serviceName) {
                    Link("Open Cancel Page", destination: url)
                }
                Button("I've Already Cancelled", role: .destructive) {
                    store.cancelTrial(trial)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("We'll help you cancel. After cancelling, mark it here to track your savings!")
            }
        }
    }
}

// MARK: - Supporting Views

struct HowItWorksStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Previews

struct TrialProtectionView_Previews: PreviewProvider {
    static var previews: some View {
        TrialProtectionView()
    }
}
