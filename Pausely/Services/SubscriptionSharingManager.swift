//
//  SubscriptionSharingManager.swift
//  Pausely
//
//  Split subscription costs with friends, family, roommates
//

import Foundation
import os.log

@MainActor
final class SubscriptionSharingManager: ObservableObject {
    static let shared = SubscriptionSharingManager()

    @Published var shareRecords: [SubscriptionShareRecord] = []
    @Published var isLoading = false

    private let storageKey = "subscription_share_records"

    private init() {
        loadRecords()
    }

    // MARK: - CRUD

    func record(for subscriptionId: UUID) -> SubscriptionShareRecord? {
        shareRecords.first { $0.subscriptionId == subscriptionId }
    }

    @discardableResult
    func createRecord(for subscriptionId: UUID, participants: [SubscriptionParticipant]) -> SubscriptionShareRecord {
        let record = SubscriptionShareRecord(subscriptionId: subscriptionId, participants: participants)
        shareRecords.append(record)
        saveRecords()
        return record
    }

    func updateRecord(_ record: SubscriptionShareRecord) {
        if let index = shareRecords.firstIndex(where: { $0.id == record.id }) {
            var updated = record
            updated.updatedAt = Date()
            shareRecords[index] = updated
            saveRecords()
        }
    }

    func deleteRecord(for subscriptionId: UUID) {
        shareRecords.removeAll { $0.subscriptionId == subscriptionId }
        saveRecords()
    }

    func addParticipant(to recordId: UUID, participant: SubscriptionParticipant) {
        guard let index = shareRecords.firstIndex(where: { $0.id == recordId }) else { return }
        shareRecords[index].participants.append(participant)
        shareRecords[index].updatedAt = Date()
        saveRecords()
    }

    func removeParticipant(from recordId: UUID, participantId: UUID) {
        guard let index = shareRecords.firstIndex(where: { $0.id == recordId }) else { return }
        shareRecords[index].participants.removeAll { $0.id == participantId }
        shareRecords[index].updatedAt = Date()
        saveRecords()
    }

    func updateParticipantPayment(recordId: UUID, participantId: UUID, hasPaid: Bool) {
        guard let rIndex = shareRecords.firstIndex(where: { $0.id == recordId }) else { return }
        guard let pIndex = shareRecords[rIndex].participants.firstIndex(where: { $0.id == participantId }) else { return }
        shareRecords[rIndex].participants[pIndex].hasPaidCurrentPeriod = hasPaid
        shareRecords[rIndex].updatedAt = Date()
        saveRecords()
    }

    func resetPaymentStatus(for recordId: UUID) {
        guard let index = shareRecords.firstIndex(where: { $0.id == recordId }) else { return }
        for i in shareRecords[index].participants.indices {
            shareRecords[index].participants[i].hasPaidCurrentPeriod = false
        }
        shareRecords[index].updatedAt = Date()
        saveRecords()
    }

    // MARK: - Calculations

    func yourShare(for subscription: Subscription, record: SubscriptionShareRecord?) -> Decimal {
        guard let record = record else { return subscription.amount }
        guard let yourParticipant = record.participants.first else { return subscription.amount }
        return subscription.amount * Decimal(yourParticipant.sharePercentage)
    }

    func totalOwed(for subscription: Subscription, record: SubscriptionShareRecord?) -> Decimal {
        guard let record = record else { return 0 }
        let unpaid = record.unpaidParticipants
        return unpaid.reduce(0) { $0 + (subscription.amount * Decimal($1.sharePercentage)) }
    }

    func monthlySavingsFromSharing(for subscription: Subscription, record: SubscriptionShareRecord?) -> Decimal {
        guard let record = record, let yourParticipant = record.participants.first else { return 0 }
        return subscription.monthlyCost * Decimal(yourParticipant.sharePercentage)
    }

    // MARK: - Persistence

    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(shareRecords)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            os_log("Failed to save share records: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            shareRecords = try JSONDecoder().decode([SubscriptionShareRecord].self, from: data)
        } catch {
            os_log("Failed to load share records: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
}
