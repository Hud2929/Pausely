import Foundation

// User model that matches Supabase Auth user
struct User: Identifiable, Codable {
    let id: String
    let email: String?
    let createdAt: Date?
    var firstName: String?
    var lastName: String?

    init(id: String, email: String? = nil, createdAt: Date? = nil,
         firstName: String? = nil, lastName: String? = nil) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
        self.firstName = firstName
        self.lastName = lastName
    }
}

// MARK: - Extensions
extension User {
    var fullName: String? {
        let parts = [firstName, lastName].compactMap { $0?.trimmed }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var displayName: String {
        fullName ?? email?.components(separatedBy: "@").first?.capitalized ?? "User"
    }

    var initials: String {
        let firstInitial = firstName?.first.map(String.init)
        let lastInitial  = lastName?.first.map(String.init)
        switch (firstInitial, lastInitial) {
        case let (f?, l?): return (f + l).uppercased()
        case let (f?, _):  return f.uppercased()
        default:           return String(email?.prefix(1).uppercased() ?? "U")
        }
    }
}

private extension String {
    var trimmed: String? {
        let t = trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }
}
