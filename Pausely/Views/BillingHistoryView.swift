import SwiftUI


struct BillingTransaction: Identifiable {
    let id: String
    let title: String
    let description: String
    let amount: Double
    let date: Date
    let type: TransactionType
    let status: TransactionStatus
    let paymentMethod: String
    let icon: String
    
    enum TransactionType {
        case payment, refund, credit
    }
    
    enum TransactionStatus {
        case completed, pending, failed
    }
}


