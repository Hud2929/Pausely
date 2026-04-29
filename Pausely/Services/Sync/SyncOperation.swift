import Foundation

enum SyncOperationType: String, Codable, CaseIterable {
    case create
    case update
    case delete
    case updateStatus
    case pause
    case resume
}

struct SyncOperation: Codable, Identifiable, Equatable {
    let id: UUID
    let type: SyncOperationType
    let subscriptionId: UUID
    let payload: Data
    var retryCount: Int
    var lastError: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        type: SyncOperationType,
        subscriptionId: UUID,
        payload: Data,
        retryCount: Int = 0,
        lastError: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.subscriptionId = subscriptionId
        self.payload = payload
        self.retryCount = retryCount
        self.lastError = lastError
        self.createdAt = createdAt
    }

    static func == (lhs: SyncOperation, rhs: SyncOperation) -> Bool {
        lhs.id == rhs.id
    }
}
