//
//  VirtualCardStore.swift
//  Pausely
//
//  Manages virtual credit cards via Privacy.com API
//  Creates REAL cards that work on actual websites
//

import Foundation
import SwiftUI
import Combine

@MainActor
class VirtualCardStore: ObservableObject {
    static let shared = VirtualCardStore()
    
    @Published var cards: [VirtualCard] = []
    @Published var stats: VirtualCardStats = .empty
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isAuthenticated = false
    
    private let privacyService = PrivacyService.shared
    private let userDefaultsKey = "virtual_cards_metadata"
    private let statsKey = "virtual_card_stats"
    private var cancellables = Set<AnyCancellable>()
    private var trialCheckTimer: Timer?
    
    private init() {
        loadLocalMetadata()
        setupAuthObserver()
        startTrialMonitoring()
    }
    
    deinit {
        trialCheckTimer?.invalidate()
    }
    
    private func setupAuthObserver() {
        // Observe Privacy.com auth state
        isAuthenticated = privacyService.isAuthenticated
        
        privacyService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authenticated in
                self?.isAuthenticated = authenticated
                if authenticated {
                    Task { await self?.syncCardsFromPrivacy() }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication

    func authenticateWithPrivacy() async throws {
        try await privacyService.authenticate()
        try await syncCardsFromPrivacy()
    }
    
    func logout() {
        privacyService.logout()
        cards.removeAll()
        stats = .empty
        saveLocalMetadata()
    }
    
    // MARK: - Card Management (Real Privacy Cards)

    /// Create a REAL virtual card via Privacy.com
    func createCard(
        name: String,
        type: VirtualCard.CardType = .trial,
        trialDays: Int? = nil,
        spendingLimit: Decimal? = nil,
        merchantLock: String? = nil,
        linkedSubscriptionId: UUID? = nil,
        linkedSubscriptionName: String? = nil,
        notes: String = ""
    ) async throws -> VirtualCard {
        guard privacyService.isConfigured else {
            throw PrivacyError.notConfigured
        }

        // Convert VirtualCard.CardType to PrivacyCardType
        let privacyType: PrivacyCardType = {
            switch type {
            case .trial: return .merchantLocked
            case .recurring: return .merchantLocked
            case .burner: return .singleUse
            case .merchantLocked: return .merchantLocked
            }
        }()

        // Create card via Privacy.com API
        let privacyCard = try await privacyService.createCard(
            type: privacyType,
            monthlyLimit: spendingLimit,
            merchantId: merchantLock,
            name: name
        )

        // Convert PrivacyCard to VirtualCard
        let virtualCard = VirtualCard(
            id: UUID().uuidString,
            name: name,
            lastFour: privacyCard.lastFour,
            expiryMonth: String(format: "%02d", privacyCard.expMonth),
            expiryYear: String(format: "%04d", privacyCard.expYear),
            cvv: privacyCard.cvv,
            cardType: mapPrivacyCardType(privacyCard.type),
            status: mapPrivacyState(privacyCard.state),
            createdAt: privacyCard.created,
            trialEndDate: trialDays != nil ? Calendar.current.date(byAdding: .day, value: trialDays!, to: Date()) : nil,
            linkedSubscriptionId: linkedSubscriptionId,
            linkedSubscriptionName: linkedSubscriptionName,
            spendingLimit: spendingLimit,
            currentSpending: privacyCard.spend ?? 0,
            merchantLock: merchantLock,
            autoCloseOnTrialEnd: trialDays != nil,
            notificationsEnabled: true,
            notes: notes,
            provider: .privacy
        )

        cards.append(virtualCard)
        saveLocalMetadata()
        updateStatsForNewCard(type: type)

        NotificationCenter.default.post(name: .virtualCardCreated, object: virtualCard)

        return virtualCard
    }

    private func mapPrivacyState(_ state: PrivacyCard.CardState) -> VirtualCard.CardStatus {
        switch state {
        case .open: return .active
        case .paused: return .paused
        case .closed: return .closed
        }
    }

    private func mapPrivacyCardType(_ type: PrivacyCard.CardType) -> VirtualCard.CardType {
        switch type {
        case .singleUse: return .burner
        case .merchant: return .merchantLocked
        case .category: return .recurring
        case .burner: return .burner
        }
    }

    private func mapVirtualCardTypeToPrivacy(_ type: VirtualCard.CardType) -> PrivacyCard.CardType {
        switch type {
        case .trial: return .category
        case .recurring: return .merchant
        case .burner: return .singleUse
        case .merchantLocked: return .merchant
        }
    }

    private func mapVirtualCardStatusToPrivacy(_ status: VirtualCard.CardStatus) -> PrivacyCard.CardState {
        switch status {
        case .active: return .open
        case .paused: return .paused
        case .closed: return .closed
        case .expired: return .closed
        case .burned: return .closed
        }
    }
    
    /// Create a quick trial card for a service
    func quickTrialCard(for serviceName: String, trialDays: Int = 7) async throws -> VirtualCard {
        let template = VirtualCardTemplates.template(for: serviceName)
        let monthlyCost = template?.typicalCharge ?? 15.00
        let merchantId = template?.merchantIdentifier ?? serviceName.lowercased()
        
        return try await createCard(
            name: "\(serviceName) Trial Protection",
            type: .trial,
            trialDays: trialDays,
            spendingLimit: monthlyCost * 1.1, // 10% buffer
            merchantLock: merchantId,
            linkedSubscriptionName: serviceName
        )
    }
    
    /// Create card from template using Privacy.com
    func createFromTemplate(_ template: VirtualCardTemplates.Template) async throws -> VirtualCard {
        let limit = template.typicalCharge * 1.1 // 10% buffer
        
        return try await createCard(
            name: "\(template.serviceName) \(template.cardType.displayName)",
            type: template.cardType,
            trialDays: template.defaultTrialDays > 0 ? template.defaultTrialDays : nil,
            spendingLimit: limit,
            merchantLock: template.merchantIdentifier,
            linkedSubscriptionName: template.serviceName
        )
    }
    
    /// Sync cards from Privacy.com API
    func syncCardsFromPrivacy() async {
        guard privacyService.isConfigured else { return }

        do {
            try await privacyService.fetchCards()
        } catch {
            errorMessage = "Failed to sync cards: \(error.localizedDescription)"
            showError = true
        }
    }

    /// Close a card via Privacy API
    func closeCard(_ card: VirtualCard) async {
        // Create a minimal PrivacyCard for the API call
        let privacyCard = PrivacyCard(
            id: card.id,
            name: card.name,
            lastFour: card.lastFour,
            expMonth: Int(card.expiryMonth) ?? 1,
            expYear: Int(card.expiryYear) ?? 2025,
            cvv: card.cvv,
            type: mapVirtualCardTypeToPrivacy(card.cardType),
            state: mapVirtualCardStatusToPrivacy(card.status),
            created: card.createdAt,
            limit: nil,
            spend: card.currentSpending
        )

        do {
            try await privacyService.closeCard(privacyCard)
            
            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index].status = .closed
                saveLocalMetadata()
                updateStatsForClosedCard()
            }
            
            NotificationCenter.default.post(
                name: .virtualCardAutoClosed,
                object: nil,
                userInfo: ["cardId": card.id, "cardName": card.name]
            )
            
        } catch {
            errorMessage = "Failed to close card: \(error.localizedDescription)"
            showError = true
        }
    }
    
    /// Pause a card (temporarily disable)
    func pauseCard(_ card: VirtualCard) {
        // Note: Privacy API doesn't support pause, so we treat as "marked to close"
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index].status = .paused
            saveLocalMetadata()
            
            var newStats = stats
            newStats.activeCards = max(0, newStats.activeCards - 1)
            stats = newStats
            saveStats()
        }
    }
    
    /// Resume a paused card
    func resumeCard(_ card: VirtualCard) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index].status = .active
            saveLocalMetadata()
            
            var newStats = stats
            newStats.activeCards += 1
            stats = newStats
            saveStats()
        }
    }
    
    /// Delete local metadata for a card
    func deleteCard(_ card: VirtualCard) async {
        if card.status != .closed {
            // Close on Privacy first
            await closeCard(card)
        }
        
        cards.removeAll { $0.id == card.id }
        saveLocalMetadata()
        
        var newStats = stats
        newStats.activeCards = max(0, newStats.activeCards - 1)
        stats = newStats
        saveStats()
    }
    
    /// Update card metadata locally
    func updateCardMetadata(_ card: VirtualCard) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
            saveLocalMetadata()
        }
    }
    
    // MARK: - Computed Properties
    
    var activeCards: [VirtualCard] {
        cards.filter { $0.status == .active }
    }
    
    var trialCards: [VirtualCard] {
        cards.filter { $0.cardType == .trial }
    }
    
    /// Get card for subscription
    func card(for subscriptionId: UUID) -> VirtualCard? {
        cards.first { $0.linkedSubscriptionId == subscriptionId }
    }
    
    var trialsEndingSoon: [VirtualCard] {
        cards.filter { $0.trialEndingSoon }
    }
    
    var expiredTrials: [VirtualCard] {
        cards.filter { card in
            guard card.cardType == .trial,
                  card.autoCloseOnTrialEnd,
                  card.status == .active,
                  let trialEnd = card.trialEndDate else { return false }
            return trialEnd < Date()
        }
    }
    
    var estimatedMoneySaved: Decimal {
        // Estimate based on auto-closed trials (average $15/mo subscription)
        let avgSubscriptionCost: Decimal = 15
        return Decimal(stats.autoClosedCount) * avgSubscriptionCost * 12 // Annual savings
    }
    
    // MARK: - Trial Monitoring
    
    private func startTrialMonitoring() {
        // Check every hour for expired trials
        trialCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkExpiredTrials()
            }
        }
        
        // Initial check
        Task { @MainActor in
            await checkExpiredTrials()
        }
    }
    
    func checkExpiredTrials() async {
        for card in expiredTrials {
            await closeCard(card)
        }
    }
    
    // MARK: - Stats Management
    
    private func updateStatsForNewCard(type: VirtualCard.CardType) {
        var newStats = stats
        newStats.totalCardsCreated += 1
        newStats.activeCards += 1
        if type == .trial {
            newStats.trialsProtected += 1
        }
        stats = newStats
        saveStats()
    }
    
    private func updateStatsForClosedCard() {
        var newStats = stats
        newStats.activeCards = max(0, newStats.activeCards - 1)
        newStats.autoClosedCount += 1
        stats = newStats
        saveStats()
    }
    
    // MARK: - Persistence
    
    private func saveLocalMetadata() {
        // Save only Pausely-specific metadata
        if let data = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadLocalMetadata() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        if let loaded = try? JSONDecoder().decode([VirtualCard].self, from: data) {
            cards = loaded
        }
    }
    
    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }
    
    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: statsKey) else { return }
        if let loaded = try? JSONDecoder().decode(VirtualCardStats.self, from: data) {
            stats = loaded
        }
    }
    
    // MARK: - Notifications
    
    private func scheduleTrialEndingNotification(for card: VirtualCard, trialEnd: Date) {
        guard let notifyDate = Calendar.current.date(byAdding: .day, value: -2, to: trialEnd),
              notifyDate > Date() else { return }
        
        // In production, use UNUserNotificationCenter
        print("📱 Scheduled trial ending notification for \(card.name) at \(notifyDate)")
    }
    
    // MARK: - Clipboard Operations
    
    func copyCardNumber(_ card: VirtualCard) {
        // Note: Privacy.com doesn't expose full card numbers via API for security
        // Users would need to view in Privacy app or use webhooks
        UIPasteboard.general.string = card.maskedNumber
    }
    
    func copyAllDetails(_ card: VirtualCard) {
        let details = """
        Card: \(card.name)
        Last 4: \(card.lastFour)
        Expiry: \(card.formattedExpiry)
        Type: \(card.cardType.displayName)
        """
        UIPasteboard.general.string = details
    }
    
    // MARK: - Bulk Operations
    
    func closeAllCards(for subscriptionId: UUID) async {
        let cardsToClose = cards.filter { $0.linkedSubscriptionId == subscriptionId && $0.status == .active }
        for card in cardsToClose {
            await closeCard(card)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let virtualCardAutoClosed = Notification.Name("virtualCardAutoClosed")
    static let virtualCardCreated = Notification.Name("virtualCardCreated")
    static let trialEndingSoon = Notification.Name("trialEndingSoon")
}
