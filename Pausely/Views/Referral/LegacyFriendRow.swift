import SwiftUI

// MARK: - Legacy Support

struct ReferredFriend: Identifiable {
    let id = UUID()
    let name: String
    let status: FriendStatus
    let date: Date?
    let avatar: String
}

enum FriendStatus {
    case completed, pending, empty
}

