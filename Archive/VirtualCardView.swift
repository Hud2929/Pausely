//
//  VirtualCardView.swift
//  Pausely
//
//  Virtual credit cards for safe free trials
//

import SwiftUI

@MainActor
struct VirtualCardView: View {
    @ObservedObject private var store = VirtualCardStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var selectedTab: CardTab = .active
    @State private var showingCreateSheet = false
    @State private var showingTemplates = false
    @State private var selectedCard: VirtualCard?
    @State private var showingCardDetail = false
    @State private var showingAuthSheet = false
    @State private var isAuthenticating = false
    @State private var authError: String?
    
    enum CardTab: String, CaseIterable {
        case active = "Active"
        case trials = "Trials"
        case closed = "Closed"
        case stats = "Stats"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [Color(.systemBackground), Color(.systemGray6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if store.isAuthenticated {
                        // Header stats
                        headerStats
                        
                        // Tab selector
                        tabSelector
                        
                        // Content
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                switch selectedTab {
                                case .active:
                                    activeCardsSection
                                case .trials:
                                    trialsSection
                                case .closed:
                                    closedCardsSection
                                case .stats:
                                    statsSection
                                }
                            }
                            .padding()
                        }
                    } else {
                        // Auth required view
                        authRequiredView
                    }
                }
            }
            .navigationTitle("Virtual Cards")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if store.isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showingCreateSheet = true
                            } label: {
                                Label("Create Custom", systemImage: "creditcard.badge.plus")
                            }
                            
                            Button {
                                showingTemplates = true
                            } label: {
                                Label("Quick Trial Card", systemImage: "bolt.fill")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                store.logout()
                            } label: {
                                Label("Disconnect Privacy.com", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateCardSheet()
            }
            .sheet(isPresented: $showingTemplates) {
                CardTemplatesSheet()
            }
            .sheet(item: $selectedCard) { card in
                CardDetailSheet(card: card)
            }
        }
    }
    
    // MARK: - Header Stats
    
    private var headerStats: some View {
        HStack(spacing: 20) {
            StatBadge(
                value: "\(store.activeCards.count)",
                label: "Active",
                icon: "creditcard.fill",
                color: .green
            )
            
            StatBadge(
                value: "\(store.stats.trialsProtected)",
                label: "Trials",
                icon: "shield.checkered",
                color: .purple
            )
            
            StatBadge(
                value: currencyManager.format(store.estimatedMoneySaved),
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
    
    // MARK: - Auth Required View
    
    private var authRequiredView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            // Text
            VStack(spacing: 12) {
                Text("Virtual Cards Coming Soon")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Virtual card protection for free trials will be available soon. Get notified when this feature launches!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Features
            VStack(alignment: .leading, spacing: 16) {
                CardFeatureRow(icon: "clock.fill", text: "Coming soon - real cards for trials")
                CardFeatureRow(icon: "clock.fill", text: "Set spending limits per card")
                CardFeatureRow(icon: "clock.fill", text: "Auto-close when trial ends")
                CardFeatureRow(icon: "clock.fill", text: "Privacy.com integration planned")
            }
            .padding(.horizontal, 40)
            
            if let error = authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // Connect button - Coming Soon
            Button {
                // Coming soon - virtual cards feature is not yet implemented
            } label: {
                HStack {
                    Image(systemName: "link")
                    Text("Coming Soon")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .cornerRadius(12)
            }
            .disabled(true)
            .padding(.horizontal, 32)

            Spacer()
        }
    }
    
    private func authenticateWithPrivacy() {
        isAuthenticating = true
        authError = nil
        
        Task {
            do {
                try await store.authenticateWithPrivacy()
                await MainActor.run {
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    authError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(CardTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    // MARK: - Active Cards Section
    
    private var activeCardsSection: some View {
        Group {
            if store.activeCards.isEmpty {
                EmptyStateView(
                    icon: "creditcard",
                    title: "Coming Soon",
                    message: "Virtual cards will be available soon"
                )
            } else {
                ForEach(store.activeCards) { card in
                    VirtualCardCell(card: card) {
                        selectedCard = card
                    }
                }
            }
        }
    }
    
    // MARK: - Trials Section
    
    private var trialsSection: some View {
        Group {
            if store.trialCards.isEmpty {
                EmptyStateView(
                    icon: "shield.checkered",
                    title: "Coming Soon",
                    message: "Trial protection coming soon"
                )
            } else {
                // Trials ending soon warning
                if !store.trialsEndingSoon.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Ending Soon", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(store.trialsEndingSoon) { card in
                            VirtualCardTrialEndingCard(card: card)
                        }
                    }
                    .padding(.bottom)
                }
                
                ForEach(store.trialCards) { card in
                    VirtualCardCell(card: card) {
                        selectedCard = card
                    }
                }
            }
        }
    }
    
    // MARK: - Closed Cards Section
    
    private var closedCardsSection: some View {
        Group {
            let closedCards = store.cards.filter { $0.status != .active }
            if closedCards.isEmpty {
                EmptyStateView(
                    icon: "archivebox",
                    title: "No Closed Cards",
                    message: "Closed and expired cards will appear here"
                )
            } else {
                ForEach(closedCards) { card in
                    VirtualCardCell(card: card) {
                        selectedCard = card
                    }
                }
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            // Protection summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Protection Summary")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                StatRow(
                    icon: "creditcard.badge.plus",
                    title: "Cards Created",
                    value: "\(store.stats.totalCardsCreated)",
                    color: .blue
                )
                
                StatRow(
                    icon: "shield.checkered",
                    title: "Trials Protected",
                    value: "\(store.stats.trialsProtected)",
                    color: .purple
                )
                
                StatRow(
                    icon: "xmark.shield.fill",
                    title: "Auto-Closed",
                    value: "\(store.stats.autoClosedCount)",
                    color: .green
                )
                
                StatRow(
                    icon: "dollarsign.circle.fill",
                    title: "Est. Money Saved",
                    value: currencyManager.format(store.estimatedMoneySaved),
                    color: .yellow
                )
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            
            // How it works
            VStack(alignment: .leading, spacing: 12) {
                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.primary)

                VirtualCardHowItWorksStep(
                    number: 1,
                    title: "Virtual Cards",
                    description: "Coming soon - real virtual cards for trial protection"
                )

                VirtualCardHowItWorksStep(
                    number: 2,
                    title: "Stay Tuned",
                    description: "We're working on integrating virtual card protection"
                )

                VirtualCardHowItWorksStep(
                    number: 3,
                    title: "Auto-Close",
                    description: "Cards will auto-close when trials end"
                )
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - Virtual Card Cell

struct VirtualCardCell: View {
    let card: VirtualCard
    let onTap: () -> Void
    @State private var isRevealed = false
    @ObservedObject private var store = VirtualCardStore.shared
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Card visual
                cardVisual
                
                // Info bar
                infoBar
            }
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var cardVisual: some View {
        ZStack {
            // Card background gradient based on type
            RoundedRectangle(cornerRadius: 12)
                .fill(cardGradient)
            
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Logo and type
                HStack {
                    Image(systemName: card.cardType.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(card.cardType.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Card number
                HStack(spacing: 12) {
                    Text(card.maskedNumber)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            isRevealed.toggle()
                        }
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Card details
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EXPIRES")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text(card.formattedExpiry)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    if isRevealed {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CVV")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            Text(card.cvv)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    CardStatusBadge(status: card.status)
                }
            }
            .padding()
        }
        .frame(height: 180)
        .padding(8)
    }
    
    private var infoBar: some View {
        HStack {
            // Trial countdown or spending
            if let daysRemaining = card.trialDaysRemaining {
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.caption)
                    Text("\(daysRemaining) days left")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(daysRemaining <= 2 ? .orange : .secondary)
            } else if let remaining = card.remainingLimit {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle")
                        .font(.caption)
                    Text("\(CurrencyManager.shared.format(remaining)) left")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Linked subscription
            if let linkedName = card.linkedSubscriptionName {
                Text(linkedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.5))
    }
    
    private var cardGradient: LinearGradient {
        switch card.cardType {
        case .trial:
            return LinearGradient(
                colors: [Color.purple, Color.purple.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .burner:
            return LinearGradient(
                colors: [Color.orange, Color.red.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .merchantLocked:
            return LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .recurring:
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var cardBorderColor: Color {
        switch card.cardType {
        case .trial: return .purple.opacity(0.3)
        case .burner: return .orange.opacity(0.3)
        case .merchantLocked: return .blue.opacity(0.3)
        case .recurring: return .green.opacity(0.3)
        }
    }
}

// MARK: - Virtual Card Trial Ending Card

struct VirtualCardTrialEndingCard: View {
    let card: VirtualCard
    @ObservedObject private var store = VirtualCardStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("\(card.name) trial ends soon!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(card.trialDaysRemaining ?? 0) days")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text("Trial protection coming soon - cards will auto-close when trials end.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button {
                    Task {
                        await store.closeCard(card)
                    }
                } label: {
                    Text("Let it Close")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                
                Button {
                    // Extend trial - would update card in real implementation
                } label: {
                    Text("Extend")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
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
    }
}

// MARK: - Status Badge

struct CardStatusBadge: View {
    let status: VirtualCard.CardStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .cornerRadius(6)
    }
}

// MARK: - Virtual Card Supporting Views

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

struct VirtualCardHowItWorksStep: View {
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
                .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
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

// MARK: - Feature Row (for auth view)

struct CardFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.system(size: 16, weight: .semibold))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Previews

struct VirtualCardView_Previews: PreviewProvider {
    static var previews: some View {
        VirtualCardView()
    }
}
