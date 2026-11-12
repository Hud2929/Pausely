//
//  CatalogModels.swift
//  Pausely
//
//  The categories a subscription is filed under, and one row of the catalog.
//

import Foundation

enum SubscriptionCategory: String, Codable, CaseIterable, Identifiable {

    /// What to show for a stored category, which may be a raw value ("entertainment", from the catalog)
    /// or a display name ("Entertainment", from the edit screen).
    static func label(for stored: String?) -> String {
        guard let stored, !stored.isEmpty else { return SubscriptionCategory.other.displayName }
        let match = allCases.first {
            $0.rawValue.caseInsensitiveCompare(stored) == .orderedSame || $0.displayName.caseInsensitiveCompare(stored) == .orderedSame
        }
        return match?.displayName ?? stored
    }
    /// The category for a name from somewhere else (the receipt engine's merchant list, the catalog):
    /// a raw value, a display name, or one of a few names that differ. "Other" when nothing fits.
    static func matching(_ text: String?) -> SubscriptionCategory {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return .other }
        if let match = allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(text) == .orderedSame || $0.displayName.caseInsensitiveCompare(text) == .orderedSame
        }) { return match }
        switch text.lowercased() {
        case "ai tools": return .aiTools
        case "utilities": return .utilities
        case "food & delivery": return .food
        case "transportation": return .travel
        case "design": return .productivity
        default: return .other
        }
    }

    case entertainment
    case music
    case productivity
    case healthFitness
    case cloudStorage
    case education
    case news
    case utilities
    case social
    case shopping
    case food
    case sports
    case finance
    case phone
    case insurance
    case gym
    case automotive
    case home
    case pet
    case personalCare
    case aiTools
    case gaming
    case developerTools
    case creator
    case travel
    case dating
    case kids
    case security
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .entertainment: return "Entertainment"
        case .music: return "Music"
        case .productivity: return "Productivity"
        case .healthFitness: return "Health & Fitness"
        case .cloudStorage: return "Cloud Storage"
        case .education: return "Education"
        case .news: return "News"
        case .utilities: return "Utilities & Internet"
        case .social: return "Social"
        case .shopping: return "Shopping"
        case .food: return "Food"
        case .sports: return "Sports"
        case .finance: return "Finance"
        case .phone: return "Phone & Mobile"
        case .insurance: return "Insurance"
        case .gym: return "Gym & Fitness"
        case .automotive: return "Automotive"
        case .home: return "Home & Security"
        case .pet: return "Pet"
        case .personalCare: return "Personal Care"
        case .aiTools: return "AI & Creativity"
        case .gaming: return "Gaming"
        case .developerTools: return "Developer Tools"
        case .creator: return "Creator Economy"
        case .travel: return "Travel"
        case .dating: return "Dating"
        case .kids: return "Kids & Family"
        case .security: return "Security"
        case .other: return "Other"
        }
    }

    /// The name in the reader's language. `displayName` stays English: it is what gets stored.
    var localizedName: String {
        switch self {
        case .entertainment: return L10n.string("Entertainment")
        case .music: return L10n.string("Music")
        case .productivity: return L10n.string("Productivity")
        case .healthFitness: return L10n.string("Health & Fitness")
        case .cloudStorage: return L10n.string("Cloud Storage")
        case .education: return L10n.string("Education")
        case .news: return L10n.string("News")
        case .utilities: return L10n.string("Utilities & Internet")
        case .social: return L10n.string("Social")
        case .shopping: return L10n.string("Shopping")
        case .food: return L10n.string("Food")
        case .sports: return L10n.string("Sports")
        case .finance: return L10n.string("Finance")
        case .phone: return L10n.string("Phone & Mobile")
        case .insurance: return L10n.string("Insurance")
        case .gym: return L10n.string("Gym & Fitness")
        case .automotive: return L10n.string("Automotive")
        case .home: return L10n.string("Home & Security")
        case .pet: return L10n.string("Pet")
        case .personalCare: return L10n.string("Personal Care")
        case .aiTools: return L10n.string("AI & Creativity")
        case .gaming: return L10n.string("Gaming")
        case .developerTools: return L10n.string("Developer Tools")
        case .creator: return L10n.string("Creator Economy")
        case .travel: return L10n.string("Travel")
        case .dating: return L10n.string("Dating")
        case .kids: return L10n.string("Kids & Family")
        case .security: return L10n.string("Security")
        case .other: return L10n.string("Other")
        }
    }

    /// The name to show for a stored category, in the reader's language. A category the person
    /// typed themselves is shown as typed.
    static func localizedLabel(for stored: String?) -> String {
        guard let stored, !stored.isEmpty else { return SubscriptionCategory.other.localizedName }
        let match = allCases.first {
            $0.rawValue.caseInsensitiveCompare(stored) == .orderedSame || $0.displayName.caseInsensitiveCompare(stored) == .orderedSame
        }
        return match?.localizedName ?? stored
    }
}

// MARK: - Pricing Tier

/// One service in the catalog: what it is called, where it is filed, and the link to its own site
/// where it is cancelled, when Pausely has one that was requested and answered.
struct CatalogEntry: Identifiable, Equatable {
    let name: String
    let category: SubscriptionCategory
    let cancellationURL: String?

    var id: String { name }

    init(_ name: String, _ category: SubscriptionCategory, _ cancellationURL: String?) {
        self.name = name
        self.category = category
        self.cancellationURL = cancellationURL
    }
}
