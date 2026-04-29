import Foundation

// MARK: - Cancellation Service
/// Manages cancellation requests locally. MVP stores requests in AppSettings.
/// Future: sync to Supabase `cancellation_requests` table.
@MainActor
final class CancellationService: ObservableObject {
    static let shared = CancellationService()

    @Published var requests: [CancellationRequest] = []

    private let storageKey = "cancellation_requests"

    private init() {
        loadRequests()
    }

    // MARK: - Submit

    func submitRequest(
        subscriptionName: String,
        accountEmail: String,
        reason: CancellationReason,
        notes: String
    ) -> CancellationRequest {
        let request = CancellationRequest(
            subscriptionName: subscriptionName,
            accountEmail: accountEmail,
            reason: reason,
            notes: notes,
            status: .pending
        )
        requests.append(request)
        saveRequests()
        return request
    }

    // MARK: - Payment

    func markPaymentCompleted(for requestId: UUID) {
        guard let index = requests.firstIndex(where: { $0.id == requestId }) else { return }
        var updated = requests[index]
        updated = CancellationRequest(
            id: updated.id,
            subscriptionName: updated.subscriptionName,
            accountEmail: updated.accountEmail,
            reason: updated.reason,
            notes: updated.notes,
            status: .inProgress,
            createdAt: updated.createdAt,
            updatedAt: Date(),
            paymentCompleted: true
        )
        requests[index] = updated
        saveRequests()
    }

    // MARK: - Status Updates

    func updateStatus(for requestId: UUID, to status: CancellationStatus) {
        guard let index = requests.firstIndex(where: { $0.id == requestId }) else { return }
        var updated = requests[index]
        updated = CancellationRequest(
            id: updated.id,
            subscriptionName: updated.subscriptionName,
            accountEmail: updated.accountEmail,
            reason: updated.reason,
            notes: updated.notes,
            status: status,
            createdAt: updated.createdAt,
            updatedAt: Date(),
            paymentCompleted: updated.paymentCompleted
        )
        requests[index] = updated
        saveRequests()
    }

    // MARK: - Delete

    func deleteRequest(id: UUID) {
        requests.removeAll { $0.id == id }
        saveRequests()
    }

    // MARK: - Persistence

    private func saveRequests() {
        if let data = try? JSONEncoder().encode(requests) {
            AppSettings.shared.cancellationRequests = data
        }
    }

    private func loadRequests() {
        let data = AppSettings.shared.cancellationRequests
        guard !data.isEmpty,
              let decoded = try? JSONDecoder().decode([CancellationRequest].self, from: data) else {
            return
        }
        requests = decoded
    }
}
