//
//  CatalogValidator.swift
//  Pausely
//
//  Debug-only price sanity checks for catalog entries
//

import Foundation
import os.log

/// Validates catalog data for suspicious prices and inconsistencies.
/// Only runs in DEBUG builds to catch bad data before shipping.
enum CatalogValidator {

    enum ValidationIssue: CustomStringConvertible {
        case suspiciouslyHigh(name: String, price: Double, currency: String, category: SubscriptionCategory, limit: Double)
        case suspiciouslyLow(name: String, price: Double, currency: String, category: SubscriptionCategory, limit: Double)
        case missingAnnualPrice(name: String)
        case annualNotCheaper(name: String, monthly: Double, annual: Double, currency: String)
        case currencyMismatch(name: String, region: Region, currencyCode: String)
        case duplicateBundleId(name: String, bundleId: String)
        case emptyTiers(name: String)

        var description: String {
            switch self {
            case .suspiciouslyHigh(let name, let price, let currency, let category, let limit):
                return "[CatalogValidator] \(name) (\(category.displayName)): \(currency) \(String(format: "%.2f", price))/mo exceeds expected max of \(currency) \(String(format: "%.2f", limit))/mo"
            case .suspiciouslyLow(let name, let price, let currency, let category, let limit):
                return "[CatalogValidator] \(name) (\(category.displayName)): \(currency) \(String(format: "%.2f", price))/mo below expected min of \(currency) \(String(format: "%.2f", limit))/mo"
            case .missingAnnualPrice(let name):
                return "[CatalogValidator] \(name): has monthly price but no annual price"
            case .annualNotCheaper(let name, let monthly, let annual, let currency):
                let monthlyTimes12 = monthly * 12
                return "[CatalogValidator] \(name): annual \(currency) \(String(format: "%.2f", annual)) is not cheaper than monthly x12 = \(currency) \(String(format: "%.2f", monthlyTimes12))"
            case .currencyMismatch(let name, let region, let currencyCode):
                return "[CatalogValidator] \(name): region \(region.displayName) expects \(region.currencyCode) but tier has \(currencyCode)"
            case .duplicateBundleId(let name, let bundleId):
                return "[CatalogValidator] duplicate bundleId '\(bundleId)' for entry '\(name)'"
            case .emptyTiers(let name):
                return "[CatalogValidator] \(name): no pricing tiers defined"
            }
        }
    }

    struct PriceRange {
        let min: Double
        let max: Double
    }

    /// Category-specific expected monthly price ranges (in USD or equivalent)
    static let categoryRanges: [SubscriptionCategory: PriceRange] = [
        .entertainment:    PriceRange(min: 3,   max: 25),
        .music:            PriceRange(min: 3,   max: 20),
        .productivity:     PriceRange(min: 3,   max: 30),
        .healthFitness:    PriceRange(min: 5,   max: 50),
        .cloudStorage:     PriceRange(min: 1,   max: 30),
        .education:        PriceRange(min: 3,   max: 50),
        .news:             PriceRange(min: 3,   max: 25),
        .utilities:        PriceRange(min: 20,  max: 200),
        .social:           PriceRange(min: 0,   max: 15),
        .shopping:         PriceRange(min: 3,   max: 15),
        .food:             PriceRange(min: 5,   max: 50),
        .sports:           PriceRange(min: 5,   max: 30),
        .finance:          PriceRange(min: 0,   max: 25),
        .phone:            PriceRange(min: 10,  max: 100),
        .insurance:        PriceRange(min: 20,  max: 500),
        .gym:              PriceRange(min: 20,  max: 350),
        .automotive:       PriceRange(min: 5,   max: 100),
        .home:             PriceRange(min: 5,   max: 100),
        .pet:              PriceRange(min: 10,  max: 100),
        .personalCare:     PriceRange(min: 5,   max: 50),
        .aiTools:          PriceRange(min: 10,  max: 250),
        .gaming:           PriceRange(min: 5,   max: 20),
        .developerTools:   PriceRange(min: 5,   max: 50),
        .creator:          PriceRange(min: 5,   max: 50),
        .travel:           PriceRange(min: 5,   max: 100),
        .dating:           PriceRange(min: 10,  max: 50),
        .kids:             PriceRange(min: 3,   max: 20),
        .security:         PriceRange(min: 3,   max: 30),
        .other:            PriceRange(min: 0,   max: 500),
    ]

    /// Services that legitimately have no annual discount (e.g., some AI tools)
    static let annualExemptions: Set<String> = [
        "com.openai.chatgpt",
        "com.openai.chatgpt.pro100",
        "com.openai.chatgpt.pro200",
        "com.anthropic.claude",
        "com.anthropic.claude.max5x",
        "com.anthropic.claude.max20x",
        "com.anthropic.claude.team",
        "com.midjourney.midjourney",
        "com.runwayml.runway",
        "com.elevenlabs.elevenlabs",
    ]

    /// Services whose prices are intentionally outside normal ranges
    static let priceExemptions: Set<String> = [
        "com.equinox.equinox",          // high-end gym ($250)
        "com.wework.allaccess",         // coworking ($299)
        "com.prioritypass.standard",    // lounge access ($99/yr)
        "com.prioritypass.prestige",    // lounge access ($429/yr)
        "com.tsa.precheck",             // $78/5yr → effectively $0/mo
    ]

    /// Run all validations on the catalog. Logs warnings in DEBUG builds.
    static func validate(_ entries: [CatalogEntry]) {
        #if DEBUG
        var issues: [ValidationIssue] = []

        // Check for duplicate bundleIds
        var seenBundleIds: [String: String] = [:]
        for entry in entries {
            if let existing = seenBundleIds[entry.bundleId] {
                issues.append(.duplicateBundleId(name: entry.name, bundleId: entry.bundleId))
            } else {
                seenBundleIds[entry.bundleId] = entry.name
            }
        }

        // Validate each entry
        for entry in entries {
            issues.append(contentsOf: validateEntry(entry))
        }

        // Log results
        if issues.isEmpty {
            os_log("[CatalogValidator] All %d entries passed validation", log: .default, type: .info, entries.count)
        } else {
            os_log("[CatalogValidator] Found %d issues in %d entries:", log: .default, type: .info, issues.count, entries.count)
            for issue in issues {
                os_log("%@", log: .default, type: .debug, issue.description)
                // Also print to console for visibility in Xcode
                print(issue.description)
            }
        }
        #endif
    }

    // MARK: - Private

    private static func validateEntry(_ entry: CatalogEntry) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        guard !entry.supportedTiers.isEmpty else {
            issues.append(.emptyTiers(name: entry.name))
            return issues
        }

        for tier in entry.supportedTiers {
            // Currency/region consistency
            if tier.currencyCode != tier.region.currencyCode {
                issues.append(.currencyMismatch(name: entry.name, region: tier.region, currencyCode: tier.currencyCode))
            }

            let monthly = tier.monthlyPriceUSD
            let currency = tier.currencyCode

            // Price range validation (skip exempt services)
            if !priceExemptions.contains(entry.bundleId),
               let range = categoryRanges[entry.category] {
                if monthly > range.max {
                    issues.append(.suspiciouslyHigh(name: entry.name, price: monthly, currency: currency, category: entry.category, limit: range.max))
                }
                if monthly > 0 && monthly < range.min {
                    issues.append(.suspiciouslyLow(name: entry.name, price: monthly, currency: currency, category: entry.category, limit: range.min))
                }
            }

            // Annual price sanity checks
            if let annual = tier.annualPriceUSD {
                let monthlyTimes12 = monthly * 12
                if annual >= monthlyTimes12 {
                    issues.append(.annualNotCheaper(name: entry.name, monthly: monthly, annual: annual, currency: currency))
                }
            } else if monthly > 0, !annualExemptions.contains(entry.bundleId) {
                // Flag services that have a monthly price but no annual option
                // (many services do offer annual — this is a gentle nudge, not an error)
                // Only flag if not exempt
                issues.append(.missingAnnualPrice(name: entry.name))
            }
        }

        return issues
    }
}
