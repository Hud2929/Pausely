//
//  CatalogModels.swift
//  Pausely
//
//  Multi-tier, multi-region subscription database models
//

import Foundation

// MARK: - Region

enum Region: String, Codable, CaseIterable {
    case us = "US"
    case uk = "UK"
    case ca = "CA"
    case eu = "EU"
    case au = "AU"
    case global = "Global"

    var currencyCode: String {
        switch self {
        case .us, .global: return "USD"
        case .ca: return "CAD"
        case .uk: return "GBP"
        case .eu: return "EUR"
        case .au: return "AUD"
        }
    }

    var displayName: String {
        switch self {
        case .us: return "United States"
        case .uk: return "United Kingdom"
        case .ca: return "Canada"
        case .eu: return "Europe"
        case .au: return "Australia"
        case .global: return "Global"
        }
    }
}

// MARK: - Subscription Category

enum SubscriptionCategory: String, Codable, CaseIterable, Identifiable {
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

    var icon: String {
        switch self {
        case .entertainment: return "tv"
        case .music: return "music.note"
        case .productivity: return "briefcase"
        case .healthFitness: return "heart.circle"
        case .cloudStorage: return "cloud"
        case .education: return "book"
        case .news: return "newspaper"
        case .utilities: return "wifi"
        case .social: return "person.2"
        case .shopping: return "cart"
        case .food: return "fork.knife"
        case .sports: return "sportscourt"
        case .finance: return "dollarsign.circle"
        case .phone: return "iphone"
        case .insurance: return "shield.checkered"
        case .gym: return "dumbbell"
        case .automotive: return "car"
        case .home: return "house"
        case .pet: return "pawprint"
        case .personalCare: return "sparkles"
        case .aiTools: return "sparkles.square.fill.on.square"
        case .gaming: return "gamecontroller"
        case .developerTools: return "chevron.left.forwardslash.chevron.right"
        case .creator: return "pencil.circle"
        case .travel: return "airplane"
        case .dating: return "heart"
        case .kids: return "figure.and.child.holdinghands"
        case .security: return "lock.shield"
        case .other: return "square.grid.2x2"
        }
    }
}

// MARK: - Pricing Tier

enum PricingTier: String, Codable, CaseIterable, Identifiable {
    case individual
    case family
    case student
    case duo
    case team
    case enterprise

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .family: return "Family"
        case .student: return "Student"
        case .duo: return "Duo"
        case .team: return "Team"
        case .enterprise: return "Enterprise"
        }
    }

    var maxUsers: Int? {
        switch self {
        case .family: return 6
        case .duo: return 2
        case .team: return nil
        default: return 1
        }
    }

    var icon: String {
        switch self {
        case .individual: return "person"
        case .family: return "person.3"
        case .student: return "graduationcap"
        case .duo: return "person.2"
        case .team: return "person.3.fill"
        case .enterprise: return "building.2"
        }
    }
}

// MARK: - Tier Pricing

struct TierPricing: Codable, Equatable, Identifiable {
    var id: String { "\(tier.rawValue)-\(region.rawValue)" }

    let tier: PricingTier
    let region: Region
    let monthlyPriceUSD: Double
    let annualPriceUSD: Double?
    let isBestValue: Bool
    let currencyCode: String

    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case tier, region, monthlyPriceUSD, annualPriceUSD, isBestValue, currencyCode
    }

    // MARK: - Memberwise Initializer
    init(
        tier: PricingTier,
        region: Region,
        monthlyPriceUSD: Double,
        annualPriceUSD: Double? = nil,
        isBestValue: Bool = false,
        currencyCode: String? = nil
    ) {
        self.tier = tier
        self.region = region
        self.monthlyPriceUSD = monthlyPriceUSD
        self.annualPriceUSD = annualPriceUSD
        self.isBestValue = isBestValue
        self.currencyCode = currencyCode ?? region.currencyCode
    }

    var monthlyPricePerUser: Double? {
        guard tier == .family, let max = tier.maxUsers, max > 0 else { return nil }
        return monthlyPriceUSD / Double(max)
    }

    /// Returns the monthly price in the requested currency, converting from the tier's true currency if needed.
    func monthlyPrice(in targetCurrency: String, rates: [String: Double]) -> Double {
        guard targetCurrency != currencyCode else { return monthlyPriceUSD }
        guard let sourceRate = rates[currencyCode], let targetRate = rates[targetCurrency] else { return monthlyPriceUSD }
        let amountInUSD = monthlyPriceUSD / sourceRate
        return amountInUSD * targetRate
    }

    /// Returns the annual price in the requested currency, converting from the tier's true currency if needed.
    func annualPrice(in targetCurrency: String, rates: [String: Double]) -> Double? {
        guard let annual = annualPriceUSD else { return nil }
        guard targetCurrency != currencyCode else { return annual }
        guard let sourceRate = rates[currencyCode], let targetRate = rates[targetCurrency] else { return annual }
        let amountInUSD = annual / sourceRate
        return amountInUSD * targetRate
    }
}

// MARK: - Catalog Entry

struct CatalogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let bundleId: String
    let name: String
    let category: SubscriptionCategory
    let description: String
    let iconName: String
    let appStoreProductId: String?
    let websiteURL: String
    let cancellationURL: String?
    let trialDays: Int
    let canPause: Bool
    let supportedTiers: [TierPricing]
    let lastUpdated: Date

    // MARK: - Memberwise Initializer
    init(
        id: UUID = UUID(),
        bundleId: String,
        name: String,
        category: SubscriptionCategory,
        description: String,
        iconName: String,
        appStoreProductId: String? = nil,
        websiteURL: String,
        cancellationURL: String? = nil,
        trialDays: Int = 0,
        canPause: Bool = true,
        supportedTiers: [TierPricing] = [],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.bundleId = bundleId
        self.name = name
        self.category = category
        self.description = description
        self.iconName = iconName
        self.appStoreProductId = appStoreProductId
        self.websiteURL = websiteURL
        self.cancellationURL = cancellationURL
        self.trialDays = trialDays
        self.canPause = canPause
        self.supportedTiers = supportedTiers
        self.lastUpdated = lastUpdated
    }

    func pricing(for tier: PricingTier, in region: Region = .us) -> TierPricing? {
        // Try exact region match first
        supportedTiers.first { $0.tier == tier && $0.region == region }
            // Fall back to global
            ?? supportedTiers.first { $0.tier == tier && $0.region == .global }
            // Fall back to any region
            ?? supportedTiers.first { $0.tier == tier }
    }

    var defaultIndividualPricing: TierPricing? { pricing(for: .individual) }
    var bestValueTier: TierPricing? { supportedTiers.first { $0.isBestValue } }

    /// Default price as a Double for compatibility with existing code
    var defaultPrice: Double { defaultIndividualPricing?.monthlyPriceUSD ?? 0 }

    var availableTiers: [PricingTier] {
        Array(Set(supportedTiers.map { $0.tier })).sorted { $0.rawValue < $1.rawValue }
    }

    var familyPlanAvailable: Bool {
        supportedTiers.contains { $0.tier == .family }
    }
}

// MARK: - Subscription Info

/// Subscription info wrapper for catalog entries used in detection and tracking
struct SubscriptionInfo {
    let bundleId: String
    let name: String
    let category: SubscriptionCategory
    let appStoreProductId: String?
    let iconName: String
    let defaultPrice: Double
    let frequency: BillingFrequency
    let familyPlanAvailable: Bool

    init?(from entry: CatalogEntry) {
        self.bundleId = entry.bundleId
        self.name = entry.name
        self.category = entry.category
        self.appStoreProductId = entry.appStoreProductId
        self.iconName = entry.iconName
        self.defaultPrice = entry.defaultIndividualPricing?.monthlyPriceUSD ?? 0
        self.frequency = .monthly
        self.familyPlanAvailable = entry.familyPlanAvailable
    }
}
