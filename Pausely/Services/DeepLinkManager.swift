//
//  DeepLinkManager.swift
//  Pausely
//
//  Where a link into the app goes: account links from email, and a subscription's own screen.
//

import Foundation
import os.log

enum DeepLinkRoute {
    case authConfirm
    case authResetPassword
    case subscriptionManage(id: UUID)
    case unknown
}

@MainActor
final class DeepLinkManager {
    static let shared = DeepLinkManager()

    private var authDeepLinkTask: Task<Void, Never>?

    private init() {}

    /// Where a link goes. In `pausely://auth/confirm` the first part ("auth") is the URL's host, not
    /// its path, so routing uses `routeSegments`, which treats both link styles the same way.
    func handle(_ url: URL) -> DeepLinkRoute {
        let scheme = url.scheme?.lowercased()
        let isUniversalLink = scheme == "https" && ["pausely.pro", "www.pausely.pro"].contains(url.host?.lowercased() ?? "")
        guard scheme == "pausely" || isUniversalLink else { return .unknown }

        // The link itself is never logged: account links carry sign-in tokens and an email address.
        let parts = url.routeSegments

        switch parts.first?.lowercased() {
        case "auth" where scheme == "pausely":
            // pausely://auth/reset-password; confirm and callback links go to the same handler
            return parts.dropFirst().first?.lowercased() == "reset-password" ? .authResetPassword : .authConfirm
        case "subscription" where parts.dropFirst().first?.lowercased() == "manage":
            // pausely://subscription/manage?id=UUID
            if let idString = url.queryParameters?["id"], let id = UUID(uuidString: idString) {
                return .subscriptionManage(id: id)
            }
            return .unknown
        default:
            return .unknown
        }
    }

    func process(_ url: URL) {
        let route = handle(url)

        switch route {
        case .authConfirm:
            authDeepLinkTask?.cancel()
            authDeepLinkTask = Task {
                _ = await RevolutionaryAuthManager.shared.handleDeepLink(url)
            }

        case .authResetPassword:
            authDeepLinkTask?.cancel()
            authDeepLinkTask = Task {
                _ = await RevolutionaryAuthManager.shared.handleDeepLink(url)
            }

        case .subscriptionManage(let id):
            NotificationCenter.default.post(
                name: .showSubscriptionManagement,
                object: nil,
                userInfo: ["subscription_id": id.uuidString]
            )

        case .unknown:
            os_log("A link the app has no screen for was opened (scheme %{public}@)", log: .default, type: .info, url.scheme ?? "none")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showSubscriptionManagement = Notification.Name("showSubscriptionManagement")
}

// MARK: - URL Query Parameters Helper

extension URL {
    /// The meaningful parts of a link: ["auth", "confirm"] for `pausely://auth/confirm` (where "auth"
    /// is the host) and ["subscription", "manage"] for `https://pausely.pro/subscription/manage` (where it's the path).
    var routeSegments: [String] {
        let path = pathComponents.filter { $0 != "/" && !$0.isEmpty }
        if scheme?.lowercased() == "pausely", let host, !host.isEmpty {
            return [host] + path
        }
        return path
    }

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
