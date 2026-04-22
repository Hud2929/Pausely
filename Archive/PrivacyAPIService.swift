//
//  PrivacyAPIService.swift
//  Pausely
//
//  STUB - Privacy.com integration not implemented
//  Virtual card features require full Privacy.com SDK integration
//

import Foundation
import Combine

@MainActor
class PrivacyAPIService: ObservableObject {
    static let shared = PrivacyAPIService()

    @Published var isAuthenticated = false
    @Published var errorMessage: String?

    private init() {}

    // MARK: - Stub Methods

    func authenticate() async throws {
        throw PrivacyError.notImplemented
    }

    func logout() {
        isAuthenticated = false
    }

    func createVirtualCard(
        name: String,
        limit: PrivacyCard.Limit?,
        type: PrivacyCard.CardType,
        merchant: String?
    ) async throws -> PrivacyCard {
        throw PrivacyError.notImplemented
    }

    func listCards() async throws -> [PrivacyCard] {
        throw PrivacyError.notImplemented
    }

    func closeCard(cardId: String) async throws {
        throw PrivacyError.notImplemented
    }

    func pauseCard(cardId: String) async throws {
        throw PrivacyError.notImplemented
    }

    func resumeCard(cardId: String) async throws {
        throw PrivacyError.notImplemented
    }
}

// MARK: - Privacy.com Types (Stub)

struct PrivacyCard: Codable {
    let id: String
    let name: String
    let lastFour: String
    let expMonth: Int
    let expYear: Int
    let cvv: String
    let type: CardType
    let state: CardState
    let created: Date
    let limit: Limit?
    let spend: Decimal?

    enum CardType: String, Codable {
        case singleUse = "SINGLE_USE"
        case merchant = "MERCHANT_LOCKED"
        case category = "CATEGORY_LOCKED"
        case burner = "BURNER"
    }

    enum CardState: String, Codable {
        case open = "OPEN"
        case paused = "PAUSED"
        case closed = "CLOSED"
    }

    struct Limit: Codable {
        let amount: Decimal
        let frequency: String
    }
}

// MARK: - Errors

enum PrivacyError: LocalizedError {
    case notAuthenticated
    case notImplemented
    case notConfigured
    case networkError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Privacy.com"
        case .notImplemented:
            return "Privacy.com integration is not yet implemented"
        case .notConfigured:
            return "Privacy.com API key not configured. Add PRIVACY_API_KEY to Info.plist."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .invalidResponse:
            return "Invalid response from Privacy.com"
        }
    }
}
