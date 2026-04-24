//
//  SubscriptionSharingModels.swift
//  Pausely
//
//  Shared subscription tracking — split costs with friends, family, roommates
//

import Foundation

// MARK: - Participant
struct SubscriptionParticipant: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var sharePercentage: Double
    var hasPaidCurrentPeriod: Bool
    var colorName: String

    init(id: UUID = UUID(), name: String, sharePercentage: Double, hasPaidCurrentPeriod: Bool = false, colorName: String = "luxuryPurple") {
        self.id = id
        self.name = name
        self.sharePercentage = max(0, min(1, sharePercentage))
        self.hasPaidCurrentPeriod = hasPaidCurrentPeriod
        self.colorName = colorName
    }

    var shareAmount: Decimal {
        Decimal(sharePercentage)
    }
}

// MARK: - Share Record
struct SubscriptionShareRecord: Codable, Identifiable {
    let id: UUID
    let subscriptionId: UUID
    var participants: [SubscriptionParticipant]
    var createdAt: Date
    var updatedAt: Date

    init(subscriptionId: UUID, participants: [SubscriptionParticipant] = []) {
        self.id = UUID()
        self.subscriptionId = subscriptionId
        self.participants = participants
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var totalPercentage: Double {
        participants.reduce(0) { $0 + $1.sharePercentage }
    }

    var isFullyAllocated: Bool {
        abs(totalPercentage - 1.0) < 0.001
    }

    var unpaidParticipants: [SubscriptionParticipant] {
        participants.filter { !$0.hasPaidCurrentPeriod }
    }

    var allPaid: Bool {
        participants.allSatisfy { $0.hasPaidCurrentPeriod }
    }
}
