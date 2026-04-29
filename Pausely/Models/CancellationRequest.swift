import Foundation

// MARK: - Cancellation Request
struct CancellationRequest: Identifiable, Codable, Equatable {
    let id: UUID
    let subscriptionName: String
    let accountEmail: String
    let reason: CancellationReason
    let notes: String
    let status: CancellationStatus
    let createdAt: Date
    let updatedAt: Date
    let paymentCompleted: Bool

    init(
        id: UUID = UUID(),
        subscriptionName: String,
        accountEmail: String,
        reason: CancellationReason,
        notes: String = "",
        status: CancellationStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        paymentCompleted: Bool = false
    ) {
        self.id = id
        self.subscriptionName = subscriptionName
        self.accountEmail = accountEmail
        self.reason = reason
        self.notes = notes
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.paymentCompleted = paymentCompleted
    }
}

enum CancellationReason: String, Codable, CaseIterable {
    case tooExpensive = "Too Expensive"
    case notUsing = "Not Using It"
    case foundAlternative = "Found Alternative"
    case serviceIssues = "Service Issues"
    case temporary = "Temporary Pause"
    case other = "Other"
}

enum CancellationStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case paymentRequired = "Payment Required"
    case inProgress = "In Progress"
    case completed = "Completed"
    case failed = "Failed"

    var displayName: String { rawValue }
    var color: String {
        switch self {
        case .pending: return "orange"
        case .paymentRequired: return "red"
        case .inProgress: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
    var icon: String {
        switch self {
        case .pending: return "hourglass"
        case .paymentRequired: return "creditcard.fill"
        case .inProgress: return "gearshape.2.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}
