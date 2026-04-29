import Foundation
import os.log

@MainActor
final class SyncQueue: ObservableObject {
    static let shared = SyncQueue()

    @Published var pendingOperations: [SyncOperation] = []
    @Published var isSyncing = false
    @Published var lastSyncError: Error?

    private let client = SupabaseManager.shared.client
    private var processTask: Task<Void, Never>?
    private let maxRetries = 3

    private init() {
        loadPendingOperations()
    }

    // MARK: - Enqueue

    func enqueue(_ operation: SyncOperation) {
        pendingOperations.append(operation)
        savePendingOperations()
        os_log("Enqueued sync operation: %{public}@ for subscription %{public}@", log: .default, type: .info, String(describing: operation.type), operation.subscriptionId.uuidString)
    }

    // MARK: - Process

    func processQueue() async {
        guard !isSyncing else { return }
        guard !pendingOperations.isEmpty else { return }
        guard client.auth.currentSession != nil else {
            os_log("SyncQueue: No auth session, skipping sync", log: .default, type: .info)
            return
        }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        var remaining: [SyncOperation] = []

        for operation in pendingOperations {
            do {
                try await execute(operation)
                os_log("SyncQueue: Operation %{public}@ succeeded", log: .default, type: .info, operation.id.uuidString)
            } catch {
                var updated = operation
                updated.retryCount += 1
                updated.lastError = error.localizedDescription

                if updated.retryCount < maxRetries {
                    remaining.append(updated)
                    os_log("SyncQueue: Operation %{public}@ failed (retry %{public}d/%{public}d): %{public}@", log: .default, type: .error, operation.id.uuidString, updated.retryCount, maxRetries, error.localizedDescription)
                } else {
                    os_log("SyncQueue: Operation %{public}@ permanently failed after %{public}d retries: %{public}@", log: .default, type: .error, operation.id.uuidString, maxRetries, error.localizedDescription)
                }
            }
        }

        pendingOperations = remaining
        savePendingOperations()
    }

    // MARK: - Execute Individual Operation

    private func execute(_ operation: SyncOperation) async throws {
        switch operation.type {
        case .create:
            try await executeCreate(operation)
        case .update:
            try await executeUpdate(operation)
        case .delete:
            try await executeDelete(operation)
        case .updateStatus:
            try await executeUpdateStatus(operation)
        case .pause:
            try await executePause(operation)
        case .resume:
            try await executeResume(operation)
        }
    }

    private func executeCreate(_ operation: SyncOperation) async throws {
        let record = try JSONDecoder().decode(SubscriptionRecord.self, from: operation.payload)
        _ = try await client
            .from("subscriptions")
            .insert(record)
            .select()
            .execute()
    }

    private func executeUpdate(_ operation: SyncOperation) async throws {
        let record = try JSONDecoder().decode(SubscriptionRecord.self, from: operation.payload)
        _ = try await client
            .from("subscriptions")
            .update(record)
            .eq("id", value: operation.subscriptionId)
            .execute()
    }

    private func executeDelete(_ operation: SyncOperation) async throws {
        try await client
            .from("subscriptions")
            .delete()
            .eq("id", value: operation.subscriptionId)
            .execute()
    }

    private func executeUpdateStatus(_ operation: SyncOperation) async throws {
        let payload = try JSONDecoder().decode([String: String].self, from: operation.payload)
        guard let status = payload["status"] else { throw NSError(domain: "SyncQueue", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing status in payload"]) }
        try await client
            .from("subscriptions")
            .update(["status": status])
            .eq("id", value: operation.subscriptionId)
            .execute()
    }

    private func executePause(_ operation: SyncOperation) async throws {
        let payload = try JSONDecoder().decode([String: String].self, from: operation.payload)
        guard let dateString = payload["paused_until"] else { throw NSError(domain: "SyncQueue", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing paused_until in payload"]) }
        try await client
            .from("subscriptions")
            .update(["paused_until": dateString])
            .eq("id", value: operation.subscriptionId)
            .execute()
    }

    private func executeResume(_ operation: SyncOperation) async throws {
        struct ResumePayload: Encodable {
            let paused_until: String?
        }
        try await client
            .from("subscriptions")
            .update(ResumePayload(paused_until: nil))
            .eq("id", value: operation.subscriptionId)
            .execute()
    }

    // MARK: - Persistence

    private func savePendingOperations() {
        do {
            let data = try JSONEncoder().encode(pendingOperations)
            AppSettings.shared.syncQueueOperations = data
        } catch {
            os_log("SyncQueue save failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    private func loadPendingOperations() {
        let data = AppSettings.shared.syncQueueOperations
        guard !data.isEmpty else { return }
        do {
            pendingOperations = try JSONDecoder().decode([SyncOperation].self, from: data)
        } catch {
            os_log("SyncQueue load failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    // MARK: - Helpers

    func clearQueue() {
        pendingOperations.removeAll()
        savePendingOperations()
    }

    func cancelProcessing() {
        processTask?.cancel()
        isSyncing = false
    }
}
