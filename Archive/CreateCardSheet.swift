//
//  CreateCardSheet.swift
//  Pausely
//
//  Sheet for creating new virtual cards
//

import SwiftUI

struct CreateCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = VirtualCardStore.shared
    
    @State private var cardName = ""
    @State private var selectedType: VirtualCard.CardType = .trial
    @State private var trialDays = 7
    @State private var hasSpendingLimit = false
    @State private var spendingLimit = ""
    @State private var merchantLock = ""
    @State private var notes = ""
    @State private var showingSuccess = false
    @State private var createdCard: VirtualCard?
    @State private var isCreating = false
    @State private var createError: String?
    
    private var isValid: Bool {
        !cardName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [Color(.systemBackground), Color(.systemGray6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Card type selector
                        cardTypeSelector
                        
                        // Card details
                        detailsSection
                        
                        // Type-specific options
                        typeOptionsSection
                        
                        // Create button
                        createButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Virtual Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if showingSuccess, let card = createdCard {
                    SuccessOverlay(card: card) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Card Type Selector
    
    private var cardTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Type")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(VirtualCard.CardType.allCases, id: \.self) { type in
                    TypeButton(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        withAnimation {
                            selectedType = type
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Details")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Card Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., Netflix Trial", text: $cardName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes (Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $notes)
                        .frame(height: 60)
                        .padding(4)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Type Options Section
    
    private var typeOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Trial days (for trial cards)
                if selectedType == .trial {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trial Duration: \(trialDays) days")
                            .font(.subheadline)
                        
                        Slider(value: .init(
                            get: { Double(trialDays) },
                            set: { trialDays = Int($0) }
                        ), in: 1...30, step: 1)
                        
                        HStack {
                            ForEach([1, 7, 14, 30], id: \.self) { days in
                                Button {
                                    trialDays = days
                                } label: {
                                    Text("\(days)d")
                                        .font(.caption)
                                        .fontWeight(trialDays == days ? .bold : .regular)
                                        .foregroundColor(trialDays == days ? .white : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(trialDays == days ? Color.purple : Color(.systemGray5))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                // Spending limit
                Toggle("Spending Limit", isOn: $hasSpendingLimit)
                
                if hasSpendingLimit {
                    HStack {
                        Text(CurrencyManager.shared.currentCurrency.symbol)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $spendingLimit)
                            .keyboardType(.decimalPad)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
                
                // Merchant lock
                if selectedType == .merchantLocked {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lock to Merchant")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("e.g., Netflix", text: $merchantLock)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Create Button

    private var createButton: some View {
        VStack(spacing: 8) {
            Text("Virtual cards coming soon!")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                // Coming soon - virtual cards feature not implemented
            } label: {
                HStack {
                    Image(systemName: "clock.fill")
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
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func createCard() {
        isCreating = true
        createError = nil
        
        Task {
            do {
                let limit = hasSpendingLimit ? Decimal(string: spendingLimit) : nil
                
                let card = try await store.createCard(
                    name: cardName,
                    type: selectedType,
                    trialDays: selectedType == .trial ? trialDays : nil,
                    spendingLimit: limit,
                    merchantLock: merchantLock.isEmpty ? nil : merchantLock,
                    notes: notes
                )
                
                await MainActor.run {
                    isCreating = false
                    createdCard = card
                    withAnimation {
                        showingSuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    createError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Type Button

struct TypeButton: View {
    let type: VirtualCard.CardType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(type.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding()
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isSelected {
                        typeBackgroundColor
                    } else {
                        Color(.systemBackground).opacity(0.5)
                    }
                }
            )
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? typeColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var typeColor: Color {
        switch type {
        case .trial: return .purple
        case .burner: return .orange
        case .merchantLocked: return .blue
        case .recurring: return .green
        }
    }
    
    private var typeBackgroundColor: LinearGradient {
        switch type {
        case .trial:
            return LinearGradient(colors: [.purple, .purple.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .burner:
            return LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .merchantLocked:
            return LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .recurring:
            return LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Success Overlay

struct SuccessOverlay: View {
    let card: VirtualCard
    let onComplete: () -> Void
    @State private var showCard = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Card Created!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if showCard {
                    // Card preview
                    CreatedCardPreview(card: card)
                        .transition(.scale.combined(with: .opacity))
                }
                
                VStack(spacing: 12) {
                    Button {
                        // Coming soon - virtual cards not implemented
                        UIPasteboard.general.string = card.maskedNumber
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Card Number")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        onComplete()
                    } label: {
                        Text("Done")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.2)) {
                showCard = true
            }
        }
    }
}

// MARK: - Created Card Preview

struct CreatedCardPreview: View {
    let card: VirtualCard
    @State private var isRevealed = true
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(cardGradient)
            
            VStack(alignment: .leading, spacing: 16) {
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
                
                Text(card.maskedNumber)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("Virtual cards coming soon")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                
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
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CVV")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text(card.cvv)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        .frame(height: 180)
        .frame(maxWidth: 300)
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
}

// MARK: - Card Templates Sheet

struct CardTemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = VirtualCardStore.shared
    @State private var showingSuccess = false
    @State private var createdCard: VirtualCard?
    @State private var isCreating = false
    @State private var createError: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [Color(.systemBackground), Color(.systemGray6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)

                            Text("Coming Soon")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Virtual cards will be available soon!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()

                        // Coming soon message
                        Text("We're working on bringing you virtual card protection for free trials. Stay tuned!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if showingSuccess, let card = createdCard {
                    SuccessOverlay(card: card) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createCard(from template: VirtualCardTemplates.Template) {
        isCreating = true
        
        Task {
            do {
                let card = try await store.createFromTemplate(template)
                await MainActor.run {
                    isCreating = false
                    createdCard = card
                    withAnimation {
                        showingSuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    createError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: VirtualCardTemplates.Template
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                Text(template.serviceName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if template.defaultTrialDays > 0 {
                    Text("\(template.defaultTrialDays)-day trial")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No trial")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle")
                        .font(.caption2)
                    Text("~\(CurrencyManager.shared.format(template.typicalCharge))/mo")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .frame(height: 130)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(iconColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconColor: Color {
        switch template.cardType {
        case .trial: return .purple
        case .burner: return .orange
        case .merchantLocked: return .blue
        case .recurring: return .green
        }
    }
}

// MARK: - Card Detail Sheet

struct CardDetailSheet: View {
    let card: VirtualCard
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = VirtualCardStore.shared
    @State private var showingDeleteConfirmation = false
    @State private var showingCopiedToast = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [Color(.systemBackground), Color(.systemGray6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Card visual
                        cardVisual
                        
                        // Quick actions
                        quickActions
                        
                        // Details
                        detailsSection
                        
                        // Actions
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle(card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if showingCopiedToast {
                    Toast(message: "Copied to clipboard!")
                }
            }
        }
    }
    
    private var cardVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(cardGradient)
            
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: card.cardType.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(card.cardType.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Card number
                HStack {
                    Text(card.maskedNumber)
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EXPIRES")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text(card.formattedExpiry)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CVV")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text(card.cvv)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Card brand logo simulation
                    Text("VIRTUAL")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(24)
        }
        .frame(height: 220)
    }
    
    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                icon: "doc.on.doc",
                title: "Copy Number",
                subtitle: "Card number only",
                gradient: [.blue, .blue.opacity(0.7)]
            ) {
                store.copyCardNumber(card)
                showCopiedToast()
            }

            QuickActionButton(
                icon: "doc.text",
                title: "Copy All",
                subtitle: "Full details",
                gradient: [.purple, .purple.opacity(0.7)]
            ) {
                store.copyAllDetails(card)
                showCopiedToast()
            }

            QuickActionButton(
                icon: "square.and.arrow.up",
                title: "Share",
                subtitle: "Send card",
                gradient: [.green, .green.opacity(0.7)]
            ) {
                // Share card details
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Card Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                DetailRow(icon: "tag", title: "Name", value: card.name)
                DetailRow(icon: "creditcard", title: "Type", value: card.cardType.displayName)
                DetailRow(icon: "checkmark.shield", title: "Status", value: card.status.displayName)
                
                if let trialEnd = card.trialEndDate {
                    DetailRow(
                        icon: "hourglass",
                        title: "Trial Ends",
                        value: trialEnd.formatted(date: .abbreviated, time: .omitted)
                    )
                }
                
                if let limit = card.spendingLimit {
                    DetailRow(
                        icon: "dollarsign.circle",
                        title: "Spending Limit",
                        value: CurrencyManager.shared.format(limit)
                    )
                }
                
                if let merchant = card.merchantLock {
                    DetailRow(icon: "lock", title: "Locked To", value: merchant)
                }
                
                if let linked = card.linkedSubscriptionName {
                    DetailRow(icon: "link", title: "Linked To", value: linked)
                }
                
                if !card.notes.isEmpty {
                    DetailRow(icon: "note.text", title: "Notes", value: card.notes)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if card.status == .active {
                Button {
                    store.pauseCard(card)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                        Text("Pause Card")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            } else if card.status == .paused {
                Button {
                    store.resumeCard(card)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Resume Card")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Card")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .alert("Delete Card?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await store.deleteCard(card)
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This action cannot be undone. The card number will be permanently deleted.")
        }
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
    
    private func showCopiedToast() {
        withAnimation {
            showingCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingCopiedToast = false
            }
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Toast

struct Toast: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(25)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Previews

struct CreateCardSheet_Previews: PreviewProvider {
    static var previews: some View {
        CreateCardSheet()
    }
}
