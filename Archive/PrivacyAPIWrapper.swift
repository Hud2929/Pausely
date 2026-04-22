//
//  PrivacyAPIWrapper.swift
//  Pausely
//
//  Privacy.com REST API integration for virtual card management
//  API docs: https://privacycom.github.ioPrivacy-API/
//

import Foundation

// MARK: - Privacy API Wrapper

/// Real Privacy.com API client
/// IMPORTANT: Privacy.com requires server-side card number handling for PCI compliance.
/// This client works with a Pausely backend proxy that handles sensitive card data.
actor PrivacyAPIWrapper {
    static let shared = PrivacyAPIWrapper()

    // Privacy.com API base
    private let productionBaseURL = "https://api.privacy.com/v1"
    private let sandboxBaseURL = "https://api-sbox.privacy.com/v1"

    nonisolated private var apiKey: String? { CredentialsManager.shared.get(.privacyAPIKey) }
    private var isSandbox: Bool { apiKey?.contains("sandbox") ?? true }

    private var baseURL: String {
        isSandbox ? sandboxBaseURL : productionBaseURL
    }

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - API Key Validation

    nonisolated var isConfigured: Bool {
        guard let key = apiKey, !key.isEmpty, !key.contains("$") else { return false }
        return true
    }

    // MARK: - Authentication

    /// Verify API key is valid by calling the /merchants/auth endpoint
    func authenticate() async throws -> PrivacyMerchant {
        guard let key = apiKey else {
            throw PrivacyAPIError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/merchants/auth")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let merchantResponse = try JSONDecoder().decode(PrivacyMerchantResponse.self, from: data)
        return merchantResponse.merchant
    }

    // MARK: - Card Management

    /// List all cards for the account
    func listCards() async throws -> [PrivacyCard] {
        guard let key = apiKey else {
            throw PrivacyAPIError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/cards")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let cardsResponse = try JSONDecoder().decode(PrivacyCardsResponse.self, from: data)
        return cardsResponse.cards
    }

    /// Create a new virtual card
    /// - Parameters:
    ///   - type: Card type (single_use, merchant_locked, etc.)
    ///   - limit: Spending limit amount in cents
    ///   - limitFrequency: How often the limit resets (monthly, per_transaction, etc.)
    ///   - merchantId: Optional merchant ID to lock card to specific merchant
    ///   - cardName: Display name for the card
    ///   - expiry: Optional expiry date (defaults to 30 days)
    func createCard(
        type: PrivacyCardType = .singleUse,
        limit: Int? = nil,
        limitFrequency: PrivacyLimitFrequency = .monthly,
        merchantId: String? = nil,
        cardName: String? = nil,
        expiry: Date? = nil
    ) async throws -> PrivacyCard {
        guard let key = apiKey else {
            throw PrivacyAPIError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/card")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = [
            "type": type.rawValue,
            "limit_frequency": limitFrequency.rawValue
        ]

        if let limit = limit {
            body["limit"] = limit
        }
        if let merchantId = merchantId {
            body["merchant_lock"] = merchantId
        }
        if let cardName = cardName {
            body["card_name"] = cardName
        }
        if let expiry = expiry {
            let formatter = ISO8601DateFormatter()
            body["expires_at"] = formatter.string(from: expiry)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let cardResponse = try JSONDecoder().decode(PrivacyCardResponse.self, from: data)
        return cardResponse.card
    }

    /// Pause an active card
    func pauseCard(cardId: String) async throws -> PrivacyCard {
        guard let key = apiKey else {
            throw PrivacyAPIError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/card/\(cardId)/pause")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let cardResponse = try JSONDecoder().decode(PrivacyCardResponse.self, from: data)
        return cardResponse.card
    }

    /// Resume a paused card
    func resumeCard(cardId: String) async throws -> PrivacyCard {
        guard let key = apiKey else {
            throw PrivacyAPIError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/card/\(cardId)/resume")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let cardResponse = try JSONDecoder().decode(PrivacyCardResponse.self, from: data)
        return cardResponse.card
    }

    /// Permanently close a card
    func closeCard(cardId: String) async throws {
        guard let key = apiKey else {
            throw PrivacyAPIError.notConfigured
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/card/\(cardId)/close")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Private Helpers

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PrivacyAPIError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw PrivacyAPIError.unauthorized
        case 403:
            throw PrivacyAPIError.forbidden
        case 404:
            throw PrivacyAPIError.notFound
        case 429:
            throw PrivacyAPIError.rateLimited
        case 500...599:
            throw PrivacyAPIError.serverError(httpResponse.statusCode)
        default:
            throw PrivacyAPIError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - Response Types

struct PrivacyMerchantResponse: Codable {
    let merchant: PrivacyMerchant
}

struct PrivacyMerchant: Codable {
    let id: String
    let businessName: String
    let email: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id = "merchant_id"
        case businessName = "business_name"
        case email
        case status
    }
}

struct PrivacyCardsResponse: Codable {
    let cards: [PrivacyCard]
}

struct PrivacyCardResponse: Codable {
    let card: PrivacyCard
}

// MARK: - API Error

enum PrivacyAPIError: LocalizedError {
    case notConfigured
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case networkError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Privacy.com API key not configured. Add PRIVACY_API_KEY to Info.plist or environment."
        case .unauthorized:
            return "Invalid Privacy.com API key. Check your credentials."
        case .forbidden:
            return "Privacy.com API access forbidden. Verify your account permissions."
        case .notFound:
            return "Resource not found."
        case .rateLimited:
            return "Privacy.com API rate limit exceeded. Try again later."
        case .serverError(let code):
            return "Privacy.com server error (\(code)). Try again later."
        case .httpError(let code):
            return "Privacy.com API error (\(code))."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .invalidResponse:
            return "Invalid response from Privacy.com"
        }
    }
}

// MARK: - Card Type

enum PrivacyCardType: String, Codable, CaseIterable {
    case singleUse = "single_use"
    case merchantLocked = "merchant_locked"
    case categoryLocked = "category_locked"
    case burner = "burner"

    var displayName: String {
        switch self {
        case .singleUse: return "Single Use"
        case .merchantLocked: return "Merchant Locked"
        case .categoryLocked: return "Category Locked"
        case .burner: return "Burner"
        }
    }

    var description: String {
        switch self {
        case .singleUse:
            return "Closes after one transaction. Best for trials."
        case .merchantLocked:
            return "Works only at one merchant. Best for subscriptions."
        case .categoryLocked:
            return "Works only in one spending category."
        case .burner:
            return "Temporary card with low limit. Best for one-time purchases."
        }
    }
}

// MARK: - Limit Frequency

enum PrivacyLimitFrequency: String, Codable {
    case monthly
    case perTransaction = "per_transaction"
    case daily
    case weekly
    case annually
    case forever
}

// MARK: - Privacy.com API Card (from API)

struct PrivacyAPICard: Codable {
    let cardId: String
    let lastFour: String
    let brand: String
    let expMonth: Int
    let expYear: Int
    let type: String
    let status: String
    let limit: Int?
    let limitFrequency: String?
    let merchantLock: String?
    let spend: Int?
    let spendLimit: Int?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case cardId = "card_id"
        case lastFour = "last_four"
        case brand
        case expMonth = "exp_month"
        case expYear = "exp_year"
        case type
        case status
        case limit
        case limitFrequency = "limit_frequency"
        case merchantLock = "merchant_lock"
        case spend
        case spendLimit = "spend_limit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Convert API card to app PrivacyCard model
    func toPrivacyCard() -> PrivacyCard {
        let cardState: PrivacyCard.CardState = {
            switch status.lowercased() {
            case "open": return .open
            case "paused": return .paused
            case "closed": return .closed
            default: return .open
            }
        }()

        let cardType: PrivacyCard.CardType = {
            switch type.lowercased() {
            case "single_use": return .singleUse
            case "merchant_locked": return .merchant
            case "category_locked": return .category
            case "burner": return .burner
            default: return .burner
            }
        }()

        let limitStruct: PrivacyCard.Limit? = {
            guard let lim = limit else { return nil }
            return PrivacyCard.Limit(amount: Decimal(lim) / 100, frequency: limitFrequency ?? "monthly")
        }()

        let dateFormatter = ISO8601DateFormatter()
        let created = dateFormatter.date(from: createdAt) ?? Date()

        return PrivacyCard(
            id: cardId,
            name: "Privacy Card",
            lastFour: lastFour,
            expMonth: expMonth,
            expYear: expYear,
            cvv: "***",
            type: cardType,
            state: cardState,
            created: created,
            limit: limitStruct,
            spend: spend != nil ? Decimal(spend!) / 100 : nil
        )
    }
}

// MARK: - PrivacyCard Extension for API Conversion

extension PrivacyCard {
    /// Create from Privacy.com API response
    init(from apiCard: PrivacyAPICard) {
        self.init(
            id: apiCard.cardId,
            name: "Privacy Card",
            lastFour: apiCard.lastFour,
            expMonth: apiCard.expMonth,
            expYear: apiCard.expYear,
            cvv: "***",
            type: apiCard.toPrivacyCard().type,
            state: apiCard.toPrivacyCard().state,
            created: apiCard.toPrivacyCard().created,
            limit: apiCard.toPrivacyCard().limit,
            spend: apiCard.toPrivacyCard().spend
        )
    }
}

// MARK: - App-Level Privacy Service (SwiftUI-friendly)

@MainActor
final class PrivacyService: ObservableObject {
    static let shared = PrivacyService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published private(set) var error: PrivacyAPIError?
    @Published var cards: [PrivacyCard] = []
    @Published private(set) var configured: Bool = false

    private let wrapper = PrivacyAPIWrapper.shared

    var isConfigured: Bool { configured }

    private init() {
        Task { configured = await wrapper.isConfigured }
    }

    /// Sign out - clears local session state
    func logout() {
        isAuthenticated = false
        cards.removeAll()
        error = nil
    }

    /// Authenticate with Privacy.com API
    func authenticate() async throws {
        // Check configuration first
        if !configured {
            throw PrivacyAPIError.notConfigured
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await wrapper.authenticate()
            isAuthenticated = true
            error = nil
        } catch let apiError as PrivacyAPIError {
            error = apiError
            isAuthenticated = false
            throw apiError
        }
    }

    /// Fetch all cards
    func fetchCards() async throws {
        if !configured {
            throw PrivacyAPIError.notConfigured
        }

        isLoading = true
        defer { isLoading = false }

        do {
            cards = try await wrapper.listCards()
        } catch let apiError as PrivacyAPIError {
            error = apiError
            throw apiError
        }
    }

    /// Create a new virtual card
    func createCard(
        type: PrivacyCardType = .merchantLocked,
        monthlyLimit: Decimal? = nil,
        merchantId: String? = nil,
        name: String? = nil
    ) async throws -> PrivacyCard {
        if !configured {
            throw PrivacyAPIError.notConfigured
        }

        isLoading = true
        defer { isLoading = false }

        let limitCents = monthlyLimit.map { Int(truncating: ($0 * 100) as NSDecimalNumber) }

        do {
            let card = try await wrapper.createCard(
                type: type,
                limit: limitCents,
                limitFrequency: .monthly,
                merchantId: merchantId,
                cardName: name
            )
            cards.append(card)
            return card
        } catch let apiError as PrivacyAPIError {
            error = apiError
            throw apiError
        }
    }

    /// Pause a card
    func pauseCard(_ card: PrivacyCard) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await wrapper.pauseCard(cardId: card.id)
            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index] = updated
            }
        } catch let apiError as PrivacyAPIError {
            error = apiError
            throw apiError
        }
    }

    /// Resume a card
    func resumeCard(_ card: PrivacyCard) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let updated = try await wrapper.resumeCard(cardId: card.id)
            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index] = updated
            }
        } catch let apiError as PrivacyAPIError {
            error = apiError
            throw apiError
        }
    }

    /// Close a card
    func closeCard(_ card: PrivacyCard) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await wrapper.closeCard(cardId: card.id)
            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index] = PrivacyCard(
                    id: card.id,
                    name: card.name,
                    lastFour: card.lastFour,
                    expMonth: card.expMonth,
                    expYear: card.expYear,
                    cvv: card.cvv,
                    type: card.type,
                    state: .closed,
                    created: card.created,
                    limit: card.limit,
                    spend: card.spend
                )
            }
        } catch let apiError as PrivacyAPIError {
            error = apiError
            throw apiError
        }
    }
}
