//
//  DeepLinkManager.swift
//  Pausely
//
//  Handles all app deep links: referral codes, auth callbacks, subscription management
//

import Foundation
import os.log

enum DeepLinkRoute {
    case referral(code: String)
    case authConfirm
    case authResetPassword
    case subscriptionManage(id: UUID)
    case unknown
}

@MainActor
final class DeepLinkManager {
    static let shared = DeepLinkManager()

    private init() {}

    func handle(_ url: URL) -> DeepLinkRoute {
        guard url.scheme == "pausely" else {
            return .unknown
        }

        let path = url.pathComponents
        os_log("Handling deep link: %{public}@ path=%{public}@", log: .default, type: .info, url.absoluteString, path.description)

        // pausely://r/CODE or pausely://referral/CODE
        if path.contains("r") || path.contains("referral"),
           let code = url.pathComponents.last, code.count > 3 {
            return .referral(code: code)
        }

        // pausely://auth/confirm
        if path.contains("auth") && path.contains("confirm") {
            return .authConfirm
        }

        // pausely://auth/reset-password
        if path.contains("auth") && path.contains("reset-password") {
            return .authResetPassword
        }

        // pausely://subscription/manage?id=UUID
        if path.contains("subscription") && path.contains("manage") {
            if let idString = url.queryParameters?["id"],
               let id = UUID(uuidString: idString) {
                return .subscriptionManage(id: id)
            }
        }

        return .unknown
    }

    func process(_ url: URL) {
        let route = handle(url)

        switch route {
        case .referral:
            _ = ReferralManager.shared.handleReferralDeepLink(url)

        case .authConfirm:
            Task {
                _ = await RevolutionaryAuthManager.shared.handleDeepLink(url)
            }

        case .authResetPassword:
            Task {
                _ = await RevolutionaryAuthManager.shared.handleDeepLink(url)
            }

        case .subscriptionManage(let id):
            NotificationCenter.default.post(
                name: .showSubscriptionManagement,
                object: nil,
                userInfo: ["subscription_id": id.uuidString]
            )

        case .unknown:
            os_log("Unknown deep link: %{public}@", log: .default, type: .info, url.absoluteString)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showSubscriptionManagement = Notification.Name("showSubscriptionManagement")
}

// MARK: - URL Query Parameters Helper

extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.reduce(into: [:]) { result, item in
            result[item.name] = item.value
        }
    }
}
