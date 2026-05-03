//
//  SubscriptionCatalogService.swift
//  Pausely
//
//  Remote catalog fetching with local cache fallback
//

import Foundation
import os.log

// MARK: - Catalog Subscription (for tracking)

struct CatalogSubscription: Identifiable {
    let id: UUID
    let bundleId: String
    let name: String
    let category: SubscriptionCategory

    init(from entry: CatalogEntry) {
        self.id = entry.id
        self.bundleId = entry.bundleId
        self.name = entry.name
        self.category = entry.category
    }
}

@MainActor
final class SubscriptionCatalogService: ObservableObject {
    static let shared = SubscriptionCatalogService()

    @Published private(set) var catalog: [CatalogEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastFetchDate: Date?
    @Published private(set) var isFromCache = false

    private let cacheKey = "subscription_catalog_cache"
    private let cacheDateKey = "subscription_catalog_date"
    private let currencyManager = CurrencyManager.shared

    // MARK: - Dictionary Indexes (O(1) lookups for 500+ entries)
    private var entryByBundleId: [String: CatalogEntry] = [:]
    private var entryByName: [String: CatalogEntry] = [:]

    private init() {}

    /// Set catalog and rebuild lookup indexes
    private func setCatalog(_ entries: [CatalogEntry]) {
        catalog = entries
        rebuildIndexes()
    }

    private func rebuildIndexes() {
        // Build indexes safely, handling duplicates by keeping the last occurrence
        var bundleDict: [String: CatalogEntry] = [:]
        var nameDict: [String: CatalogEntry] = [:]
        for entry in catalog {
            bundleDict[entry.bundleId] = entry
            nameDict[entry.name.lowercased()] = entry
        }
        entryByBundleId = bundleDict
        entryByName = nameDict
    }

    // MARK: - Subscriptions (for tracking compatibility)

    /// Returns all known subscriptions as simple structs for tracking
    var subscriptions: [CatalogSubscription] {
        catalog.map { CatalogSubscription(from: $0) }
    }

    /// Find bundle ID for a subscription name (O(1) exact, O(n) partial fallback)
    func findBundleId(for name: String) -> String? {
        let lowercased = name.lowercased()
        // Try exact match first (O(1))
        if let exact = entryByName[lowercased] {
            return exact.bundleId
        }
        // Try partial match (O(n) fallback)
        if let partial = catalog.first(where: { $0.name.lowercased().contains(lowercased) }) {
            return partial.bundleId
        }
        return nil
    }

    /// Returns all bundle IDs in the catalog
    var allBundleIds: [String] {
        catalog.map { $0.bundleId }
    }

    /// Returns the app name for a bundle ID
    func appName(for bundleId: String) -> String? {
        entry(for: bundleId)?.name
    }

    // MARK: - Load Catalog

    func loadCatalog() async {
        isLoading = true
        defer { isLoading = false }

        // Always start with hardcoded catalog as the base
        var merged = buildHardcodedCatalog()

        // 1. Try to supplement with remote Teenybase API
        if let remote = await fetchFromRemote(), !remote.isEmpty {
            merged = mergeCatalogs(base: merged, updates: remote)
            lastFetchDate = Date()
            isFromCache = false
            cacheLocally(merged)
        }
        // 2. Fall back to local cache only if remote failed AND hardcoded is empty
        else if merged.isEmpty, let cached = loadFromCache() {
            merged = cached
            isFromCache = true
            lastFetchDate = UserDefaults.standard.object(forKey: cacheDateKey) as? Date
        }

        setCatalog(merged)
        CatalogValidator.validate(merged)
    }

    /// Merge remote updates into the hardcoded base catalog.
    /// Remote entries override hardcoded ones by bundleId; new entries are appended.
    private func mergeCatalogs(base: [CatalogEntry], updates: [CatalogEntry]) -> [CatalogEntry] {
        var dict = Dictionary(uniqueKeysWithValues: base.map { ($0.bundleId, $0) })
        for entry in updates {
            dict[entry.bundleId] = entry
        }
        return Array(dict.values).sorted { $0.name < $1.name }
    }

    // MARK: - Remote Fetch

    private func fetchFromRemote() async -> [CatalogEntry]? {
        // Get Teenybase URL and token from environment/backend
        guard let baseURL = getTeenybaseURL() else { return nil }

        let urlString = "\(baseURL)/api/v1/table/subscription_catalog/list"
        guard let url = URL(string: urlString) else { return nil }

        guard let token = getAdminToken() else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "limit": 500,
            "order": "name"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                #if DEBUG
                os_log("CatalogService: Remote fetch failed with status %d", log: .default, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)
                #endif
                return nil
            }

            // Parse Teenybase response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let records = json["records"] as? [[String: Any]] {
                return try parseCatalogRecords(records)
            }

            return nil
        } catch {
            #if DEBUG
            os_log("CatalogService: Remote fetch error - %{public}@", log: .default, type: .error, error.localizedDescription)
            #endif
            return nil
        }
    }

    private func parseCatalogRecords(_ records: [[String: Any]]) throws -> [CatalogEntry] {
        var entries: [CatalogEntry] = []

        for record in records {
            guard let id = record["id"] as? String,
                  let bundleId = record["bundle_id"] as? String,
                  let name = record["name"] as? String,
                  let categoryStr = record["category"] as? String,
                  let description = record["description"] as? String,
                  let supportedTiersData = record["supported_tiers"] as? [[String: Any]] else {
                continue
            }

            let category = SubscriptionCategory(rawValue: categoryStr) ?? .other
            let uuid = UUID(uuidString: id) ?? UUID()

            // Parse supported tiers
            var tierList: [TierPricing] = []
            for tierData in supportedTiersData {
                guard let tierStr = tierData["tier"] as? String,
                      let regionStr = tierData["region"] as? String,
                      let monthlyUSD = tierData["monthlyPriceUSD"] as? Double else {
                    continue
                }

                let tier = PricingTier(rawValue: tierStr) ?? .individual
                let region = Region(rawValue: regionStr) ?? .global
                let annualUSD = tierData["annualPriceUSD"] as? Double
                let bestValue = tierData["isBestValue"] as? Bool ?? false
                let currencyCode = tierData["currencyCode"] as? String

                tierList.append(TierPricing(
                    tier: tier,
                    region: region,
                    monthlyPriceUSD: monthlyUSD,
                    annualPriceUSD: annualUSD,
                    isBestValue: bestValue,
                    currencyCode: currencyCode
                ))
            }

            let entry = CatalogEntry(
                id: uuid,
                bundleId: bundleId,
                name: name,
                category: category,
                description: description,
                iconName: record["icon_name"] as? String ?? "square.grid.2x2",
                appStoreProductId: record["app_store_product_id"] as? String,
                websiteURL: record["website_url"] as? String ?? "https://\(bundleId)",
                cancellationURL: record["cancellation_url"] as? String,
                trialDays: record["trial_days"] as? Int ?? 0,
                canPause: record["can_pause"] as? Bool ?? true,
                supportedTiers: tierList,
                lastUpdated: Date()
            )
            entries.append(entry)
        }

        return entries
    }

    // MARK: - Cache

    private func cacheLocally(_ entries: [CatalogEntry]) {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheDateKey)
        }
    }

    private func loadFromCache() -> [CatalogEntry]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let entries = try? JSONDecoder().decode([CatalogEntry].self, from: data) else {
            return nil
        }
        return entries
    }

    // MARK: - Search

    func search(_ query: String, category: SubscriptionCategory?) -> [CatalogEntry] {
        var results = catalog

        if let cat = category {
            results = results.filter { $0.category == cat }
        }

        if !query.isEmpty {
            let q = query.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(q) ||
                $0.category.rawValue.lowercased().contains(q) ||
                $0.description.lowercased().contains(q)
            }
        }

        return results
    }

    func entry(for bundleId: String) -> CatalogEntry? {
        entryByBundleId[bundleId]
    }

    // MARK: - Helpers

    private func getTeenybaseURL() -> String? {
        // Try environment variable first
        if let url = ProcessInfo.processInfo.environment["TEENYBASE_URL"] {
            return url
        }
        // Default to local dev server
        return "http://localhost:8787"
    }

    private func getAdminToken() -> String? {
        // Read from backend .dev.vars
        let devVarsPath = "backend/.dev.vars"
        guard let content = try? String(contentsOfFile: devVarsPath, encoding: .utf8) else { return nil }

        for line in content.components(separatedBy: .newlines) {
            if line.hasPrefix("ADMIN_SERVICE_TOKEN=") {
                return String(line.dropFirst("ADMIN_SERVICE_TOKEN=".count))
            }
        }
        return nil
    }

    // MARK: - Hardcoded Fallback (50 popular subscriptions)

    private func buildHardcodedCatalog() -> [CatalogEntry] {
        var entries: [CatalogEntry] = []

        // ENTERTAINMENT
        entries.append(contentsOf: buildEntertainmentCatalog())

        // MUSIC
        entries.append(contentsOf: buildMusicCatalog())

        // PRODUCTIVITY
        entries.append(contentsOf: buildProductivityCatalog())

        // CLOUD STORAGE
        entries.append(contentsOf: buildCloudStorageCatalog())

        // HEALTH & FITNESS
        entries.append(contentsOf: buildHealthCatalog())

        // EDUCATION
        entries.append(contentsOf: buildEducationCatalog())

        // NEWS
        entries.append(contentsOf: buildNewsCatalog())

        // UTILITIES
        entries.append(contentsOf: buildUtilitiesCatalog())

        // SOCIAL
        entries.append(contentsOf: buildSocialCatalog())

        // SHOPPING
        entries.append(contentsOf: buildShoppingCatalog())

        // FOOD
        entries.append(contentsOf: buildFoodCatalog())

        // SPORTS
        entries.append(contentsOf: buildSportsCatalog())

        // FINANCE
        entries.append(contentsOf: buildFinanceCatalog())

        // PHONE & MOBILE
        entries.append(contentsOf: buildPhoneCatalog())

        // INSURANCE
        entries.append(contentsOf: buildInsuranceCatalog())

        // GYM & FITNESS
        entries.append(contentsOf: buildGymCatalog())

        // AUTOMOTIVE
        entries.append(contentsOf: buildAutomotiveCatalog())

        // HOME & SECURITY
        entries.append(contentsOf: buildHomeCatalog())

        // PET
        entries.append(contentsOf: buildPetCatalog())

        // PERSONAL CARE
        entries.append(contentsOf: buildPersonalCareCatalog())

        // EXPANDED CATALOG (~350 new entries)
        entries.append(contentsOf: buildExpandedCatalog())

        return entries
    }

    private func buildEntertainmentCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.netflix.Netflix", name: "Netflix", category: .entertainment,
                      description: "Stream thousands of TV shows, movies, and originals.",
                      cancellationURL: "https://www.netflix.com/cancelplan",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.49, annualPriceUSD: 139.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 22.99, annualPriceUSD: 229.99, isBestValue: true),
                          TierPricing(tier: .student, region: .us, monthlyPriceUSD: 7.99, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 10.99, annualPriceUSD: 99.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .ca, monthlyPriceUSD: 14.99, annualPriceUSD: 139.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.disney.disneyplus", name: "Disney+", category: .entertainment,
                      description: "Stream Disney, Pixar, Marvel, Star Wars, and more.",
                      cancellationURL: "https://www.disneyplus.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 13.99, annualPriceUSD: 139.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 19.99, annualPriceUSD: 199.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 10.99, annualPriceUSD: 109.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.hbo.hbomax", name: "Max", category: .entertainment,
                      description: "Stream HBO Originals, Warner Bros. movies, and DC content.",
                      cancellationURL: "https://www.max.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.99, annualPriceUSD: 149.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 20.99, annualPriceUSD: 199.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 11.99, annualPriceUSD: 109.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.hulu.plus", name: "Hulu", category: .entertainment,
                      description: "Stream TV shows, originals, and 100+ channels.",
                      cancellationURL: "https://secure.hulu.com/account",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 17.99, annualPriceUSD: 179.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 22.99, annualPriceUSD: 229.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.amazon.aiv.AIVApp", name: "Prime Video", category: .entertainment,
                      description: "Stream Amazon Originals, movies, and TV shows.",
                      cancellationURL: "https://www.amazon.com/gp/prime/manage",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 139.00, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 8.99, annualPriceUSD: 89.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "tv.twitch", name: "Twitch", category: .entertainment,
                      description: "Live streaming for gamers and creators.",
                      cancellationURL: "https://www.twitch.tv/subscriptions",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 4.99, annualPriceUSD: 49.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 3.99, annualPriceUSD: 39.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.youtube.youtube", name: "YouTube Premium", category: .entertainment,
                      description: "Ad-free YouTube, Originals, and YouTube Music.",
                      cancellationURL: "https://www.youtube.com/paid_memberships",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 13.99, annualPriceUSD: 139.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 22.99, annualPriceUSD: 229.99, isBestValue: true),
                          TierPricing(tier: .student, region: .us, monthlyPriceUSD: 7.99, annualPriceUSD: 79.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 11.99, annualPriceUSD: 119.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.apple.AppleTVApp", name: "Apple TV+", category: .entertainment,
                      description: "Stream Apple Originals and exclusive shows.",
                      cancellationURL: "https://apps.apple.com/account/subscriptions",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.peacocktv.peacock", name: "Peacock", category: .entertainment,
                      description: "Stream NBCUniversal content, sports, and news.",
                      cancellationURL: "https://www.peacocktv.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 5.99, annualPriceUSD: 55.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 13.99, annualPriceUSD: 139.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.crunchyroll.crunchyroll", name: "Crunchyroll", category: .entertainment,
                      description: "Stream anime and manga content.",
                      cancellationURL: "https://www.crunchyroll.com/account/membership",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 7.99, annualPriceUSD: 79.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 149.99, isBestValue: true),
                          TierPricing(tier: .student, region: .us, monthlyPriceUSD: 4.99, annualPriceUSD: 49.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.pluto.tv", name: "Pluto TV", category: .entertainment,
                      description: "Free streaming with 100s of live TV channels.",
                      cancellationURL: "https://account.pluto.tv/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.tubi.Tubi", name: "Tubi", category: .entertainment,
                      description: "Free movies and TV shows with ads.",
                      cancellationURL: "https://help.tubitv.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.paramount.ParamountPlus", name: "Paramount+", category: .entertainment,
                      description: "Stream CBS, MTV, Paramount movies and originals.",
                      cancellationURL: "https://www.paramountplus.com/account/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 11.99, annualPriceUSD: 119.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 15.99, annualPriceUSD: 159.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.discovery.discoveryplus", name: "Discovery+", category: .entertainment,
                      description: "HGTV, Food Network, TLC and more on-demand.",
                      cancellationURL: "https://www.discoveryplus.com/account",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 8.99, annualPriceUSD: 89.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 13.99, annualPriceUSD: 139.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.sling.sling", name: "Sling TV", category: .entertainment,
                      description: "Live TV streaming with flexible packages.",
                      cancellationURL: "https://www.sling.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 40.00, annualPriceUSD: 400.00, isBestValue: false),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 55.00, annualPriceUSD: 550.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.philo.philo", name: "Philo", category: .entertainment,
                      description: "Affordable live TV and on-demand streaming.",
                      cancellationURL: "https://www.philo.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 25.00, annualPriceUSD: 250.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.shudder.shudder", name: "Shudder", category: .entertainment,
                      description: "Horror, thriller, and supernatural streaming.",
                      cancellationURL: "https://www.shudder.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 6.99, annualPriceUSD: 71.88, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.britbox.britbox", name: "BritBox", category: .entertainment,
                      description: "British TV and classic BBC shows.",
                      cancellationURL: "https://www.britbox.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 8.99, annualPriceUSD: 89.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.starz.starz", name: "Starz", category: .entertainment,
                      description: "Premium movies and original series.",
                      cancellationURL: "https://www.starz.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 74.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.showtime.showtime", name: "Paramount+ with Showtime", category: .entertainment,
                      description: "Hit movies, docs, and Showtime originals.",
                      cancellationURL: "https://www.paramountplus.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 11.99, annualPriceUSD: 119.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.acorn.acorn", name: "Acorn TV", category: .entertainment,
                      description: "British and international mysteries and dramas.",
                      cancellationURL: "https://acorn.tv/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 7.99, annualPriceUSD: 79.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.youtube.youtubetv", name: "YouTube TV", category: .entertainment,
                      description: "Live TV streaming with 100+ channels and unlimited DVR.",
                      cancellationURL: "https://tv.youtube.com/settings/membership",
                      tiers: [
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 72.99, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.directv.directvstream", name: "DirecTV Stream", category: .entertainment,
                      description: "Live TV streaming with regional sports.",
                      cancellationURL: "https://www.directv.com/support/account-management/cancel",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 79.99, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.plex.plexpass", name: "Plex Pass", category: .entertainment,
                      description: "Ad-free streaming and live TV with your own media library.",
                      cancellationURL: "https://www.plex.tv/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 4.99, annualPriceUSD: 39.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 119.99, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.mubi.mubi", name: "Mubi", category: .entertainment,
                      description: "Curated independent, classic, and award-winning films.",
                      cancellationURL: "https://mubi.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.99, annualPriceUSD: 95.88, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.criterion.criterionchannel", name: "Criterion Channel", category: .entertainment,
                      description: "Classic and contemporary films from the Criterion Collection.",
                      cancellationURL: "https://www.criterionchannel.com/account",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.99, annualPriceUSD: 99.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.audible.audible", name: "Audible", category: .entertainment,
                      description: "Audiobooks, podcasts, and exclusive audio content.",
                      cancellationURL: "https://www.audible.com/account/cancellation",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.95, annualPriceUSD: 149.50, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.amazon.kindleunlimited", name: "Kindle Unlimited", category: .entertainment,
                      description: "Unlimited reading from over 2 million ebooks.",
                      cancellationURL: "https://www.amazon.com/kindleunlimited",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 11.99, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.scribd.scribd", name: "Scribd", category: .entertainment,
                      description: "Unlimited ebooks, audiobooks, and documents.",
                      cancellationURL: "https://www.scribd.com/account_settings",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 11.99, annualPriceUSD: 119.88, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.patreon.patreon", name: "Patreon", category: .entertainment,
                      description: "Support creators with monthly memberships.",
                      cancellationURL: "https://www.patreon.com/settings/memberships",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 5.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.substack.substack", name: "Substack", category: .entertainment,
                      description: "Independent newsletters and podcasts from writers.",
                      cancellationURL: "https://substack.com/settings",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 5.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
        ]
    }

    private func buildMusicCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.spotify.client", name: "Spotify", category: .music,
                      description: "Stream millions of songs and podcasts ad-free.",
                      cancellationURL: "https://www.spotify.com/account/subscription/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.99, annualPriceUSD: 109.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 16.99, annualPriceUSD: 169.99, isBestValue: true),
                          TierPricing(tier: .student, region: .us, monthlyPriceUSD: 5.99, annualPriceUSD: 59.99, isBestValue: false),
                          TierPricing(tier: .duo, region: .us, monthlyPriceUSD: 13.99, annualPriceUSD: 139.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .ca, monthlyPriceUSD: 10.99, annualPriceUSD: 109.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.apple.Music", name: "Apple Music", category: .music,
                      description: "Stream 100M+ songs, album art, and live radio.",
                      cancellationURL: "https://apps.apple.com/account/subscriptions",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.99, annualPriceUSD: 109.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 16.99, annualPriceUSD: 169.99, isBestValue: true),
                          TierPricing(tier: .student, region: .us, monthlyPriceUSD: 5.99, annualPriceUSD: 59.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 10.99, annualPriceUSD: 109.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.amazon.echo", name: "Amazon Music Unlimited", category: .music,
                      description: "Stream 100M+ songs with Alexa integration.",
                      cancellationURL: "https://www.amazon.com/music/manageaccount",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 15.99, annualPriceUSD: 159.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.pandora", name: "Pandora", category: .music,
                      description: "Personalized radio and on-demand music streaming.",
                      cancellationURL: "https://www.pandora.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 89.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 149.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.soundcloud.TuneCore", name: "SoundCloud Go+", category: .music,
                      description: "Stream and discover new music ad-free.",
                      cancellationURL: "https://soundcloud.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.aspiro.TIDAL", name: "Tidal", category: .music,
                      description: "Hi-Fi music streaming with Dolby Atmos.",
                      cancellationURL: "https://account.tidal.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.99, annualPriceUSD: 99.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 15.99, annualPriceUSD: 159.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.qobuz.Qobuz", name: "Qobuz", category: .music,
                      description: "Hi-Res music streaming up to 24-bit/192kHz.",
                      cancellationURL: "https://www.qobuz.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 129.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 11.99, annualPriceUSD: 119.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.deezer.Deezer", name: "Deezer", category: .music,
                      description: "Music streaming with Flow and live radio.",
                      cancellationURL: "https://www.deezer.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.99, annualPriceUSD: 99.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 16.99, annualPriceUSD: 169.99, isBestValue: true),
                          TierPricing(tier: .student, region: .us, monthlyPriceUSD: 5.99, annualPriceUSD: 59.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.amazon.echoplus", name: "Amazon Music Prime", category: .music,
                      description: "Included with Prime, 100M+ songs.",
                      cancellationURL: "https://www.amazon.com/gp/prime/manage",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.google.youtubemusic", name: "YouTube Music Premium", category: .music,
                      description: "Ad-free music, background play, and offline downloads.",
                      cancellationURL: "https://www.youtube.com/paid_memberships",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.99, annualPriceUSD: 109.99, isBestValue: true),
                      ]),
        ]
    }

    private func buildProductivityCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.microsoft.Office", name: "Microsoft 365", category: .productivity,
                      description: "Word, Excel, PowerPoint, and more.",
                      cancellationURL: "https://account.microsoft.com/services",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: true),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 129.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .ca, monthlyPriceUSD: 10.99, annualPriceUSD: 109.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.apple.pages", name: "Apple iWork", category: .productivity,
                      description: "Pages, Numbers, and Keynote for Apple devices.",
                      cancellationURL: "https://apps.apple.com/account/subscriptions",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 79.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.notion.id", name: "Notion", category: .productivity,
                      description: "All-in-one workspace for notes, docs, and wikis.",
                      cancellationURL: "https://www.notion.so/settings/billing",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 8.00, annualPriceUSD: 80.00, isBestValue: true),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 144.00, isBestValue: false),
                          TierPricing(tier: .student, region: .us, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.figma.Desktop", name: "Figma", category: .productivity,
                      description: "Collaborative design and prototyping tool.",
                      cancellationURL: "https://www.figma.com/billing/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.00, annualPriceUSD: 144.00, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 45.00, annualPriceUSD: 540.00, isBestValue: true),
                          TierPricing(tier: .enterprise, region: .us, monthlyPriceUSD: 75.00, annualPriceUSD: 900.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "us.zoom.xos", name: "Zoom", category: .productivity,
                      description: "Video conferencing and webinars.",
                      cancellationURL: "https://zoom.us/billing",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 149.90, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 19.99, annualPriceUSD: 199.90, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.slack.Slack", name: "Slack", category: .productivity,
                      description: "Business communication and collaboration platform.",
                      cancellationURL: "https://slack.com/billing",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 7.25, annualPriceUSD: 72.50, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 12.50, annualPriceUSD: 125.00, isBestValue: true),
                          TierPricing(tier: .enterprise, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 150.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.evernote.Evernote", name: "Evernote", category: .productivity,
                      description: "Notes, tasks, and organization tool.",
                      cancellationURL: "https://www.evernote.com/BillingInfo.action",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 7.99, annualPriceUSD: 79.99, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 149.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.todoist", name: "Todoist", category: .productivity,
                      description: "Task and project management.",
                      cancellationURL: "https://todoist.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 4.00, annualPriceUSD: 36.00, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 6.00, annualPriceUSD: 60.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.adobe.Photoshop", name: "Adobe Creative Cloud", category: .productivity,
                      description: "Photoshop, Illustrator, and all Adobe apps.",
                      cancellationURL: "https://account.adobe.com/plans",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 22.99, annualPriceUSD: 239.88, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 54.99, annualPriceUSD: 599.88, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.asana.ios", name: "Asana", category: .productivity,
                      description: "Team work and project management.",
                      cancellationURL: "https://asana.com/comission",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.00, annualPriceUSD: 100.00, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 13.50, annualPriceUSD: 162.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.monday.monday", name: "Monday.com", category: .productivity,
                      description: "Work management platform for teams.",
                      cancellationURL: "https://auth.monday.com/users/microsoft_login_options",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.00, annualPriceUSD: 90.00, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 12.00, annualPriceUSD: 144.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.37signals.Basecamp", name: "Basecamp", category: .productivity,
                      description: "All-in-one project management and team communication.",
                      cancellationURL: "https://basecamp.com/your_account/billing",
                      tiers: [
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 150.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.morgan horde", name: "ClickUp", category: .productivity,
                      description: "One platform for all your work.",
                      cancellationURL: "https://clickup.com/settings/billing",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 7.00, annualPriceUSD: 70.00, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 5.00, annualPriceUSD: 50.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.linear.Linear", name: "Linear", category: .productivity,
                      description: "Streamlined issue tracking for software teams.",
                      cancellationURL: "https://linear.app/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 8.00, annualPriceUSD: 80.00, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 14.00, annualPriceUSD: 140.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.canva.canva", name: "Canva Pro", category: .productivity,
                      description: "Graphic design tool with templates and assets.",
                      cancellationURL: "https://www.canva.com/settings/billing",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 119.99, isBestValue: true),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 149.90, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.github.github", name: "GitHub Copilot", category: .productivity,
                      description: "AI-powered code completion and assistance.",
                      cancellationURL: "https://github.com/settings/billing",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.00, annualPriceUSD: 100.00, isBestValue: true),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 19.00, annualPriceUSD: 190.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.loom.loom", name: "Loom", category: .productivity,
                      description: "Async video messaging for work.",
                      cancellationURL: "https://www.loom.com/settings/billing",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.50, annualPriceUSD: 120.00, isBestValue: true),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 20.00, annualPriceUSD: 192.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.setapp.setapp", name: "Setapp", category: .productivity,
                      description: "Subscription suite of 240+ Mac apps.",
                      cancellationURL: "https://setapp.com/account",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.00, isBestValue: true),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 150.00, isBestValue: false),
                      ]),
        ]
    }

    private func buildCloudStorageCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.apple.CloudServices", name: "iCloud+", category: .cloudStorage,
                      description: "Apple's cloud storage with Photos, Drive, and more.",
                      cancellationURL: "https://apps.apple.com/account/subscriptions",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 2.99, annualPriceUSD: 29.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 6.99, annualPriceUSD: 69.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 2.99, annualPriceUSD: 29.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.google.drive", name: "Google One", category: .cloudStorage,
                      description: "Storage for Google Drive, Gmail, and Photos.",
                      cancellationURL: "https://one.google.com/storage/settings",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 2.99, annualPriceUSD: 29.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 6.99, annualPriceUSD: 69.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 2.49, annualPriceUSD: 24.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.getdropbox.Dropbox", name: "Dropbox", category: .cloudStorage,
                      description: "Cloud storage and file synchronization.",
                      cancellationURL: "https://www.dropbox.com/account/plan",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 11.99, annualPriceUSD: 119.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 22.99, annualPriceUSD: 229.99, isBestValue: true),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 18.00, annualPriceUSD: 180.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.box.Box", name: "Box", category: .cloudStorage,
                      description: "Enterprise content management and collaboration.",
                      cancellationURL: "https://account.box.com/settings",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.00, annualPriceUSD: 100.00, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 25.00, annualPriceUSD: 250.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.microsoft.OneDrive", name: "OneDrive", category: .cloudStorage,
                      description: "Microsoft's cloud storage with Office integration.",
                      cancellationURL: "https://account.microsoft.com/services",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 1.99, annualPriceUSD: 19.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 6.99, annualPriceUSD: 69.99, isBestValue: true),
                      ]),
        ]
    }

    private func buildHealthCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.peloton.app", name: "Peloton", category: .healthFitness,
                      description: "Fitness classes, workouts, and training.",
                      cancellationURL: "https://www.onepeloton.com/subscriptions",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 129.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 19.99, annualPriceUSD: 199.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.strava.strava", name: "Strava", category: .healthFitness,
                      description: "Track runs, rides, and fitness activities.",
                      cancellationURL: "https://www.strava.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 5.99, annualPriceUSD: 59.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 4.99, annualPriceUSD: 49.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.headspace.headspace", name: "Headspace", category: .healthFitness,
                      description: "Guided meditation and mindfulness.",
                      cancellationURL: "https://www.headspace.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 69.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 19.99, annualPriceUSD: 99.99, isBestValue: true),
                          TierPricing(tier: .student, region: .us, monthlyPriceUSD: 6.99, annualPriceUSD: 49.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.calm", name: "Calm", category: .healthFitness,
                      description: "Sleep, meditation, and relaxation content.",
                      cancellationURL: "https://www.calm.com/account/settings",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 69.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 24.99, annualPriceUSD: 119.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.myfitnesspal.mfp", name: "MyFitnessPal", category: .healthFitness,
                      description: "Food tracking and nutrition logging.",
                      cancellationURL: "https://www.myfitnesspal.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 19.99, annualPriceUSD: 79.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 9.99, annualPriceUSD: 49.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.noom.noom", name: "Noom", category: .healthFitness,
                      description: "Psychology-based weight loss and healthy habit coaching.",
                      cancellationURL: "https://www.noom.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 59.00, annualPriceUSD: 199.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.fitbit.premium", name: "Fitbit Premium", category: .healthFitness,
                      description: "Guided workouts, sleep insights, and wellness reports.",
                      cancellationURL: "https://www.fitbit.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 79.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.nike.ntc", name: "Nike Training Club Premium", category: .healthFitness,
                      description: "Expert-led workouts and personalized training plans.",
                      cancellationURL: "https://www.nike.com/membership/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: nil, isBestValue: false),
                      ]),
        ]
    }

    private func buildEducationCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.duolingo.Duolingo", name: "Duolingo", category: .education,
                      description: "Language learning with gamified lessons.",
                      cancellationURL: "https://www.duolingo.com/settings/plus",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 79.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 23.99, annualPriceUSD: 119.99, isBestValue: true),
                          TierPricing(tier: .student, region: .us, monthlyPriceUSD: 6.99, annualPriceUSD: 39.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.masterclass.MasterClass", name: "MasterClass", category: .education,
                      description: "Learn from world-renowned experts.",
                      cancellationURL: "https://www.masterclass.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 120.00, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 10.00, annualPriceUSD: 90.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.coursera.Coursera", name: "Coursera", category: .education,
                      description: "Online courses and professional certificates.",
                      cancellationURL: "https://www.coursera.org/account/subscriptions",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 49.00, annualPriceUSD: 399.00, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 14.00, annualPriceUSD: 168.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.linkedin.LinkedInLearning", name: "LinkedIn Learning", category: .education,
                      description: "Business, tech, and creative skills courses.",
                      cancellationURL: "https://www.linkedin.com/mypreferences/d/manage-subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 29.99, annualPriceUSD: 299.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 24.99, annualPriceUSD: 249.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.skillshare.Skillshare", name: "Skillshare", category: .education,
                      description: "Creative and entrepreneurial skills.",
                      cancellationURL: "https://www.skillshare.com/settings/billing",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 13.99, annualPriceUSD: 99.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 9.99, annualPriceUSD: 79.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.udemy.ios", name: "Udemy Business", category: .education,
                      description: "Unlimited access to 22K+ courses.",
                      cancellationURL: "https://business.udemy.com/admin/settings/billing/",
                      tiers: [
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 12.50, annualPriceUSD: 150.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.pluralsight.ios", name: "Pluralsight", category: .education,
                      description: "Technology and creative skills training.",
                      cancellationURL: "https://www.pluralsight.com/profile/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 29.00, annualPriceUSD: 299.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.treehouse.Treehouse", name: "Treehouse", category: .education,
                      description: "Learn coding, design, and business skills.",
                      cancellationURL: "https://teamtreehouse.com/account/billing",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 25.00, annualPriceUSD: 250.00, isBestValue: true),
                      ]),
        ]
    }

    private func buildNewsCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.nytimes NYT", name: "New York Times", category: .news,
                      description: "News, investigations, and opinion.",
                      cancellationURL: "https://account.nytimes.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 17.00, annualPriceUSD: 204.00, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 25.00, annualPriceUSD: 300.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "wsj.WSJ", name: "Wall Street Journal", category: .news,
                      description: "Business news and financial analysis.",
                      cancellationURL: "https://account.wsj.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 179.00, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 12.99, annualPriceUSD: 159.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.washingtonpost.WP", name: "Washington Post", category: .news,
                      description: "National and international news coverage.",
                      cancellationURL: "https://www.washingtonpost.com/subscribe/manage/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.00, annualPriceUSD: 100.00, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 150.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.medium.medium", name: "Medium", category: .news,
                      description: "Writing and ideas from independent voices.",
                      cancellationURL: "https://medium.com/me/settings/membership",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 5.00, annualPriceUSD: 50.00, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 4.00, annualPriceUSD: 40.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.ft.FT", name: "Financial Times", category: .news,
                      description: "Global business and financial news.",
                      cancellationURL: "https://www.ft.com/myaccount/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 180.00, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 10.00, annualPriceUSD: 120.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.economist.Economist", name: "The Economist", category: .news,
                      description: "International news and business analysis.",
                      cancellationURL: "https://subscription.economist.com",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.00, annualPriceUSD: 144.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.thenation.thenation", name: "The Atlantic", category: .news,
                      description: "Journalism on politics, culture, and ideas.",
                      cancellationURL: "https://www.theatlantic.com/subscription/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 129.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.wired.wired", name: "Wired", category: .news,
                      description: "Technology and its impact on culture.",
                      cancellationURL: "https://www.wired.com/subscription/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.00, annualPriceUSD: 100.00, isBestValue: true),
                      ]),
        ]
    }

    // MARK: - Utilities
    private func buildUtilitiesCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.nordvpn.NordVPN", name: "NordVPN", category: .utilities,
                      description: "Secure VPN for privacy and security.",
                      cancellationURL: "https://my.nordaccount.com/dashboard/nordvpn/subscription/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 59.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 9.99, annualPriceUSD: 49.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.expressvpn.ExpressVPN", name: "ExpressVPN", category: .utilities,
                      description: "Lightning-fast VPN for secure browsing.",
                      cancellationURL: "https://www.expressvpn.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.95, annualPriceUSD: 95.75, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.1password.1password", name: "1Password", category: .utilities,
                      description: "Password manager for individuals and teams.",
                      cancellationURL: "https://my.1password.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 2.99, annualPriceUSD: 35.88, isBestValue: true),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 4.99, annualPriceUSD: 59.88, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 7.99, annualPriceUSD: 95.88, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.lastpass.LastPass", name: "LastPass", category: .utilities,
                      description: "Password manager and secure vault.",
                      cancellationURL: "https://lastpass.com/account.php",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 3.00, annualPriceUSD: 36.00, isBestValue: true),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 4.00, annualPriceUSD: 48.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.bitwarden.desktop", name: "Bitwarden", category: .utilities,
                      description: "Open source password manager.",
                      cancellationURL: "https://vault.bitwarden.com/#/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 3.33, annualPriceUSD: 40.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.surfshark.Surfshark", name: "Surfshark VPN", category: .utilities,
                      description: "Unlimited devices with secure VPN.",
                      cancellationURL: "https://my.surfshark.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.95, annualPriceUSD: 47.77, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 9.99, annualPriceUSD: 38.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.cyberghostvpn.ios", name: "CyberGhost VPN", category: .utilities,
                      description: "Privacy-focused VPN with global servers.",
                      cancellationURL: "https://account.cyberghostvpn.com/my-account/subscription/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 56.94, isBestValue: true),
                      ]),
            makeEntry(bundleId: "ch.protonvpn", name: "ProtonVPN", category: .utilities,
                      description: "Secure Swiss VPN with no logs.",
                      cancellationURL: "https://account.protonvpn.com/account",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 4.99, annualPriceUSD: 47.88, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 95.88, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.mullvad.MullvadVPN", name: "Mullvad VPN", category: .utilities,
                      description: "Anonymous VPN focused on privacy.",
                      cancellationURL: "https://mullvad.net/account/subscription/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 5.50, annualPriceUSD: 55.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.xfinity.xfinity", name: "Xfinity Internet", category: .utilities,
                      description: "High-speed cable internet from Comcast.",
                      cancellationURL: "https://www.xfinity.com/support/articles/cancel-xfinity-internet",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 50.00, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 80.00, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.spectrum.spectrum", name: "Spectrum Internet", category: .utilities,
                      description: "Cable internet with no data caps.",
                      cancellationURL: "https://www.spectrum.net/support/cancel-service",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 49.99, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 69.99, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.attfiber.attfiber", name: "AT&T Fiber", category: .utilities,
                      description: "Fiber optic internet with symmetric speeds.",
                      cancellationURL: "https://www.att.com/support/article/wireless/KM1218200/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 55.00, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 80.00, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.verizonfios.verizonfios", name: "Verizon Fios", category: .utilities,
                      description: "100% fiber-optic internet, TV, and phone.",
                      cancellationURL: "https://www.verizon.com/support/manage-account/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 49.99, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 79.99, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.cox.cox", name: "Cox Internet", category: .utilities,
                      description: "Cable internet with Panoramic Wi-Fi.",
                      cancellationURL: "https://www.cox.com/residential/support/cancelling-cox-service.html",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 49.99, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.centurylink.centurylink", name: "CenturyLink", category: .utilities,
                      description: "DSL and fiber internet with price for life.",
                      cancellationURL: "https://www.centurylink.com/help/contact-us.html",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 50.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.frontier.frontier", name: "Frontier Internet", category: .utilities,
                      description: "Fiber and DSL internet service.",
                      cancellationURL: "https://frontier.com/helpcenter/categories/cancelling",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 44.99, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.googlefiber.googlefiber", name: "Google Fiber", category: .utilities,
                      description: "High-speed fiber internet with no contracts.",
                      cancellationURL: "https://fiber.google.com/support/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 70.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
        ]
    }

    // MARK: - Social
    private func buildSocialCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.tinder.Tinder", name: "Tinder+", category: .social,
                      description: "Dating app with unlimited likes and more.",
                      cancellationURL: "https://tinder.com/profile/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 29.99, annualPriceUSD: 299.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 24.99, annualPriceUSD: 249.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.bumble.Bumble", name: "Bumble Boost", category: .social,
                      description: "Dating app where women make the first move.",
                      cancellationURL: "https://bumble.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 24.99, annualPriceUSD: 179.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 19.99, annualPriceUSD: 149.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.hinge.Hinge", name: "Hinge Preferred", category: .social,
                      description: "Dating app designed to be deleted.",
                      cancellationURL: "https://hinge.co/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 24.99, annualPriceUSD: 209.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.discord.Discord", name: "Discord Nitro", category: .social,
                      description: "Enhanced Discord with perks and upgrades.",
                      cancellationURL: "https://discord.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 8.99, annualPriceUSD: 89.99, isBestValue: false),
                      ]),
        ]
    }

    // MARK: - Shopping
    private func buildShoppingCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.amazon.aiv.AIVApp", name: "Amazon Prime", category: .shopping,
                      description: "Free shipping, streaming, and more.",
                      cancellationURL: "https://www.amazon.com/gp/prime/manage",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 139.00, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 8.99, annualPriceUSD: 89.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.costcoplus.costco", name: "Costco Membership", category: .shopping,
                      description: "Warehouse club with bulk savings.",
                      cancellationURL: "https://www.costco.com/join-costco.html",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 6.00, annualPriceUSD: 60.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.walmart.Walmart", name: "Walmart+", category: .shopping,
                      description: "Free delivery, fuel discounts, and more.",
                      cancellationURL: "https://www.walmart.com/account/membership",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.95, annualPriceUSD: 98.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.target.Target", name: "Target Circle", category: .shopping,
                      description: "Savings and exclusive deals at Target.",
                      cancellationURL: "https://www.target.com/circle",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.samsclub.samsclub", name: "Sam's Club", category: .shopping,
                      description: "Warehouse membership with bulk savings and same-day delivery.",
                      cancellationURL: "https://www.samsclub.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 4.17, annualPriceUSD: 50.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.bjs.bjs", name: "BJ's", category: .shopping,
                      description: "Warehouse club with low prices and gas savings.",
                      cancellationURL: "https://www.bjs.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 4.58, annualPriceUSD: 55.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.instacart.instacartplus", name: "Instacart+", category: .shopping,
                      description: "Unlimited free delivery on groceries and essentials.",
                      cancellationURL: "https://www.instacart.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.00, isBestValue: true),
                      ]),
        ]
    }

    // MARK: - Food
    private func buildFoodCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.doordash.DoorDash", name: "DashPass", category: .food,
                      description: "Free delivery and reduced fees on orders.",
                      cancellationURL: "https://www.doordash.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 95.00, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 7.99, annualPriceUSD: 79.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.ubereats.UberEats", name: "Uber Eats Pass", category: .food,
                      description: "Unlimited free delivery on orders.",
                      cancellationURL: "https://www.ubereats.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.grubhub.grubhub", name: "Grubhub+", category: .food,
                      description: "Free delivery and exclusive offers.",
                      cancellationURL: "https://www.grubhub.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.hellofresh.HelloFresh", name: "HelloFresh", category: .food,
                      description: "Meal kit delivery service.",
                      cancellationURL: "https://www.hellofresh.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 59.99, isBestValue: true),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 89.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.blueapron.BlueApron", name: "Blue Apron", category: .food,
                      description: "Chef-designed recipes with fresh ingredients delivered weekly.",
                      cancellationURL: "https://www.blueapron.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 47.95, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.factor.factor", name: "Factor", category: .food,
                      description: "Fresh, dietitian-approved prepared meals delivered weekly.",
                      cancellationURL: "https://www.factor75.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 60.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.dailyharvest.dailyharvest", name: "Daily Harvest", category: .food,
                      description: "Organic, plant-based smoothies and bowls delivered weekly.",
                      cancellationURL: "https://www.dailyharvest.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 71.91, annualPriceUSD: nil, isBestValue: false),
                      ]),
        ]
    }

    // MARK: - Sports
    private func buildSportsCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.espn.espn-plus", name: "ESPN+", category: .sports,
                      description: "Live sports, original shows, and exclusives.",
                      cancellationURL: "https://www.espn.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.99, annualPriceUSD: 109.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.nfl.nfl-plus", name: "NFL+", category: .sports,
                      description: "Stream live NFL games and on-demand content.",
                      cancellationURL: "https://www.nfl.com/plus/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 6.99, annualPriceUSD: 49.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 13.99, annualPriceUSD: 99.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.nba.league", name: "NBA League Pass", category: .sports,
                      description: "Watch every NBA game live or on-demand.",
                      cancellationURL: "https://www.nba.com/watch/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 99.99, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 24.99, annualPriceUSD: 149.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.mlbf一次性.MLB", name: "MLB.TV", category: .sports,
                      description: "Watch live out-of-market MLB games.",
                      cancellationURL: "https://www.mlb.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 99.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.nhl.GC", name: "NHL Live", category: .sports,
                      description: "Stream live and archived hockey games.",
                      cancellationURL: "https://www.nhl.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 12.99, annualPriceUSD: 99.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.microsoft.xboxgamepass", name: "Xbox Game Pass Ultimate", category: .sports,
                      description: "Console, PC gaming, and cloud gaming in one.",
                      cancellationURL: "https://account.microsoft.com/services",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 16.99, annualPriceUSD: 169.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.playstation.plus", name: "PlayStation Plus", category: .sports,
                      description: "Online multiplayer and free monthly games.",
                      cancellationURL: "https://store.playstation.com/subscriptions",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 59.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 17.99, annualPriceUSD: 119.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 22.99, annualPriceUSD: 159.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.nintendo.SwitchOnline", name: "Nintendo Switch Online", category: .sports,
                      description: "Online multiplayer and classic game library.",
                      cancellationURL: "https://accounts.nintendo.com/membership",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 3.99, annualPriceUSD: 34.99, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 7.99, annualPriceUSD: 49.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.dazn.dazn", name: "DAZN", category: .sports,
                      description: "Live and on-demand boxing, MMA, and combat sports streaming.",
                      cancellationURL: "https://www.dazn.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 19.99, annualPriceUSD: 224.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.fubo.fubotv", name: "FuboTV", category: .sports,
                      description: "Live sports and TV streaming with cloud DVR.",
                      cancellationURL: "https://www.fubo.tv/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 79.99, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.ea.EAPlay", name: "EA Play", category: .sports,
                      description: "Play new games first and get rewards.",
                      cancellationURL: "https://www.ea.com/account/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 4.99, annualPriceUSD: 39.99, isBestValue: false),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 3.99, annualPriceUSD: 34.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.ubisoft.ubisoft", name: "Ubisoft+", category: .sports,
                      description: "Access to Ubisoft's full game library.",
                      cancellationURL: "https://account.ubisoft.com/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 17.99, annualPriceUSD: 119.99, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 29.99, annualPriceUSD: 299.99, isBestValue: true),
                      ]),
        ]
    }

    // MARK: - Finance
    private func buildFinanceCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.ynab.YNAB", name: "YNAB", category: .finance,
                      description: "Budgeting app for financial peace of mind.",
                      cancellationURL: "https://app.youneedabudget.com/settings/account",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 99.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 11.99, annualPriceUSD: 79.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.rocketmoney.RocketMoney", name: "Rocket Money", category: .finance,
                      description: "Track and cancel subscriptions, negotiate bills.",
                      cancellationURL: "https://app.rocketmoney.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 6.00, annualPriceUSD: 48.00, isBestValue: true),
                          TierPricing(tier: .individual, region: .uk, monthlyPriceUSD: 4.99, annualPriceUSD: 39.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.clearchannel.iHeartRadio", name: "iHeartRadio All Access", category: .finance,
                      description: "Music, radio, and podcasts with premium.",
                      cancellationURL: "https://www.iheart.com/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 9.99, annualPriceUSD: 99.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.tradingview.TradingView", name: "TradingView", category: .finance,
                      description: "Charts, market data, and trading insights.",
                      cancellationURL: "https://www.tradingview.com/subscription/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 14.99, annualPriceUSD: 155.88, isBestValue: false),
                          TierPricing(tier: .team, region: .us, monthlyPriceUSD: 29.95, annualPriceUSD: 299.40, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.empiretoday.Robinhood", name: "Robinhood Gold", category: .finance,
                      description: "Premium investing with instant deposits and more.",
                      cancellationURL: "https://robinhood.com/account/settings/subscription",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 5.00, annualPriceUSD: 60.00, isBestValue: true),
                      ]),
        ]
    }

    // MARK: - Helper

    private func buildPhoneCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.verizon.vzw", name: "Verizon", category: .phone,
                      description: "Nationwide 5G wireless service.",
                      cancellationURL: "https://www.verizon.com/support/manage-account/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 70.00, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 55.00, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.att.att", name: "AT&T", category: .phone,
                      description: "Wireless, fiber internet, and TV bundles.",
                      cancellationURL: "https://www.att.com/support/article/wireless/KM1218200/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 65.99, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 50.99, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.tmobile.tmobile", name: "T-Mobile", category: .phone,
                      description: "Unlimited 5G wireless with no annual contracts.",
                      cancellationURL: "https://www.t-mobile.com/responsibility/legal/cancel-service",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 60.00, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 45.00, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.mintmobile.mint", name: "Mint Mobile", category: .phone,
                      description: "Budget prepaid wireless with bulk pricing.",
                      cancellationURL: "https://www.mintmobile.com/help/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 180.00, isBestValue: true),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 20.00, annualPriceUSD: 240.00, isBestValue: false),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 30.00, annualPriceUSD: 360.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.google.projectfi", name: "Google Fi", category: .phone,
                      description: "Flexible pay-for-what-you-use wireless.",
                      cancellationURL: "https://fi.google.com/account",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 20.00, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 50.00, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.cricket.cricket", name: "Cricket Wireless", category: .phone,
                      description: "AT&T-powered prepaid wireless.",
                      cancellationURL: "https://www.cricketwireless.com/support/account-management/cancel-service.html",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 30.00, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 25.00, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.boost.boost", name: "Boost Mobile", category: .phone,
                      description: "Prepaid wireless with no annual contract.",
                      cancellationURL: "https://www.boost.com/support",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 25.00, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 40.00, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.visible.visible", name: "Visible", category: .phone,
                      description: "Verizon-powered unlimited prepaid wireless.",
                      cancellationURL: "https://www.visible.com/help",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 25.00, annualPriceUSD: 275.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.xfinitymobile.xfinity", name: "Xfinity Mobile", category: .phone,
                      description: "Wireless service for Xfinity Internet customers.",
                      cancellationURL: "https://www.xfinity.com/support/articles/cancel-xfinity-mobile",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: nil, isBestValue: true),
                      ]),
        ]
    }

    private func buildInsuranceCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.geico.geico", name: "Geico", category: .insurance,
                      description: "Auto insurance with competitive rates.",
                      cancellationURL: "https://www.geico.com/manageyourpolicy/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 85.00, annualPriceUSD: 900.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.progressive.progressive", name: "Progressive", category: .insurance,
                      description: "Auto, home, and renters insurance.",
                      cancellationURL: "https://www.progressive.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 95.00, annualPriceUSD: 1000.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.statefarm.statefarm", name: "State Farm", category: .insurance,
                      description: "Auto, home, and life insurance.",
                      cancellationURL: "https://www.statefarm.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 110.00, annualPriceUSD: 1200.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.allstate.allstate", name: "Allstate", category: .insurance,
                      description: "Auto, home, and renters insurance.",
                      cancellationURL: "https://www.allstate.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 105.00, annualPriceUSD: 1150.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.lemonade.lemonade", name: "Lemonade", category: .insurance,
                      description: "Digital renters, home, and pet insurance.",
                      cancellationURL: "https://www.lemonade.com/help-center/cancelling-policy",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 155.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.root.root", name: "Root Insurance", category: .insurance,
                      description: "Usage-based car insurance.",
                      cancellationURL: "https://www.joinroot.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 70.00, annualPriceUSD: 750.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.oscar.oscar", name: "Oscar Health", category: .insurance,
                      description: "Individual and family health insurance.",
                      cancellationURL: "https://www.hioscar.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 350.00, annualPriceUSD: nil, isBestValue: false),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 850.00, annualPriceUSD: nil, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.cigna.cigna", name: "Cigna", category: .insurance,
                      description: "Health, dental, and supplemental insurance.",
                      cancellationURL: "https://www.cigna.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 300.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.deltadental.deltadental", name: "Delta Dental", category: .insurance,
                      description: "Individual and family dental insurance.",
                      cancellationURL: "https://www.deltadental.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 40.00, annualPriceUSD: 420.00, isBestValue: true),
                      ]),
        ]
    }

    private func buildGymCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.planetfitness.pf", name: "Planet Fitness", category: .gym,
                      description: "Budget-friendly gym with 24/7 access.",
                      cancellationURL: "https://www.planetfitness.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 159.00, isBestValue: true),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 25.00, annualPriceUSD: 249.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.lafitness.lafitness", name: "LA Fitness", category: .gym,
                      description: "Full-service gym with pools, courts, and classes.",
                      cancellationURL: "https://www.lafitness.com/Pages/EmailUsForm.aspx",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 39.99, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.24hourfitness.24hour", name: "24 Hour Fitness", category: .gym,
                      description: "Gym open 24 hours with group classes.",
                      cancellationURL: "https://www.24hourfitness.com/membership/cancellation",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 49.99, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.goldsgym.goldsgym", name: "Gold's Gym", category: .gym,
                      description: "Iconic gym chain with strength training focus.",
                      cancellationURL: "https://www.goldsgym.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 35.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.ymca.ymca", name: "YMCA", category: .gym,
                      description: "Community gym with pools, classes, and youth programs.",
                      cancellationURL: "https://www.ymca.org/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 55.00, annualPriceUSD: 600.00, isBestValue: true),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 85.00, annualPriceUSD: 900.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.equinox.equinox", name: "Equinox", category: .gym,
                      description: "Luxury fitness club with spa and classes.",
                      cancellationURL: "https://www.equinox.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 250.00, annualPriceUSD: 2700.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.anytimefitness.anytime", name: "Anytime Fitness", category: .gym,
                      description: "24/7 access gym with key fob entry.",
                      cancellationURL: "https://www.anytimefitness.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 45.00, annualPriceUSD: 480.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.orangetheory.orangetheory", name: "Orangetheory Fitness", category: .gym,
                      description: "Heart-rate based HIIT group workouts.",
                      cancellationURL: "https://www.orangetheory.com/en-us",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 169.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.barrys.barrys", name: "Barry's", category: .gym,
                      description: "High-intensity interval training classes.",
                      cancellationURL: "https://www.barrys.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 300.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.soulcycle.soulcycle", name: "SoulCycle", category: .gym,
                      description: "Indoor cycling studio classes.",
                      cancellationURL: "https://www.soul-cycle.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 250.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.classpass.classpass", name: "ClassPass", category: .gym,
                      description: "Access to thousands of gyms and studios.",
                      cancellationURL: "https://classpass.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 49.00, annualPriceUSD: 528.00, isBestValue: true),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 79.00, annualPriceUSD: 852.00, isBestValue: false),
                      ]),
        ]
    }

    private func buildAutomotiveCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.aaa.aaa", name: "AAA Membership", category: .automotive,
                      description: "Roadside assistance, travel discounts, and insurance.",
                      cancellationURL: "https://www.aaa.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 6.00, annualPriceUSD: 60.00, isBestValue: true),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 10.00, annualPriceUSD: 100.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.carvana.carvana", name: "Carvana", category: .automotive,
                      description: "Online used car buying with delivery.",
                      cancellationURL: "https://www.carvana.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.spothero.spothero", name: "SpotHero", category: .automotive,
                      description: "Monthly parking spot reservations.",
                      cancellationURL: "https://spothero.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 150.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.mistercarwash.mister", name: "Mister Car Wash", category: .automotive,
                      description: "Unlimited monthly car washes.",
                      cancellationURL: "https://www.mistercarwash.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 29.99, annualPriceUSD: 299.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.ezpass.ezpass", name: "E-ZPass", category: .automotive,
                      description: "Electronic toll collection for toll roads.",
                      cancellationURL: "https://www.e-zpassny.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 1.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
        ]
    }

    private func buildHomeCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.ring.ring", name: "Ring Protect", category: .home,
                      description: "Video doorbell and security camera cloud storage.",
                      cancellationURL: "https://account.ring.com/account",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 4.99, annualPriceUSD: 49.99, isBestValue: true),
                          TierPricing(tier: .family, region: .us, monthlyPriceUSD: 10.00, annualPriceUSD: 100.00, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.nestaware.nestaware", name: "Nest Aware", category: .home,
                      description: "Smart camera cloud recording and alerts.",
                      cancellationURL: "https://store.google.com/subscriptions",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 8.00, annualPriceUSD: 80.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.simplisafe.simplisafe", name: "SimpliSafe", category: .home,
                      description: "DIY home security system with monitoring.",
                      cancellationURL: "https://support.simplisafe.com/articles/cancel",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 19.99, annualPriceUSD: 199.99, isBestValue: true),
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 29.99, annualPriceUSD: 299.99, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.adt.adt", name: "ADT", category: .home,
                      description: "Professional home security monitoring.",
                      cancellationURL: "https://www.adt.com/help",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 45.99, annualPriceUSD: 499.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.wyze.wyze", name: "Wyze Cam Plus", category: .home,
                      description: "Budget smart camera cloud recording.",
                      cancellationURL: "https://services.wyze.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 1.99, annualPriceUSD: 19.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.philipshue.hue", name: "Philips Hue", category: .home,
                      description: "Smart lighting system with app control.",
                      cancellationURL: "https://www.philips-hue.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.abode.abode", name: "Abode", category: .home,
                      description: "Smart home security with automation.",
                      cancellationURL: "https://goabode.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 6.99, annualPriceUSD: 69.99, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.ecobee.ecobee", name: "Ecobee", category: .home,
                      description: "Smart thermostat with voice control.",
                      cancellationURL: "https://www.ecobee.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 0, annualPriceUSD: 0, isBestValue: false),
                      ]),
        ]
    }

    private func buildPetCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.chewy.autoship", name: "Chewy Autoship", category: .pet,
                      description: "Auto-delivered pet food and supplies.",
                      cancellationURL: "https://www.chewy.com/app/content/autoship",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 40.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.barkbox.barkbox", name: "BarkBox", category: .pet,
                      description: "Monthly dog toy and treat subscription box.",
                      cancellationURL: "https://www.barkbox.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 35.00, annualPriceUSD: 360.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.ollie.ollie", name: "Ollie", category: .pet,
                      description: "Fresh human-grade dog food delivery.",
                      cancellationURL: "https://www.myollie.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 60.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.farmersdog.farmersdog", name: "The Farmer's Dog", category: .pet,
                      description: "Fresh, vet-developed dog food delivery.",
                      cancellationURL: "https://www.thefarmersdog.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 70.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
        ]
    }

    private func buildPersonalCareCatalog() -> [CatalogEntry] {
        [
            makeEntry(bundleId: "com.dollarshaveclub.dsc", name: "Dollar Shave Club", category: .personalCare,
                      description: "Monthly razor and grooming product delivery.",
                      cancellationURL: "https://www.dollarshaveclub.com/account",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 10.00, annualPriceUSD: 100.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.harrys.harrys", name: "Harry's", category: .personalCare,
                      description: "Quality razors and shave products delivered.",
                      cancellationURL: "https://www.harrys.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 150.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.curology.curology", name: "Curology", category: .personalCare,
                      description: "Personalized skincare prescription formulas.",
                      cancellationURL: "https://www.curology.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 29.95, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.forhims.hims", name: "Hims", category: .personalCare,
                      description: "Men's health, hair loss, and skincare.",
                      cancellationURL: "https://www.forhims.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 30.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.keeps.keeps", name: "Keeps", category: .personalCare,
                      description: "Hair loss prevention for men.",
                      cancellationURL: "https://www.keeps.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 35.00, annualPriceUSD: nil, isBestValue: false),
                      ]),
            makeEntry(bundleId: "com.birchbox.birchbox", name: "Birchbox", category: .personalCare,
                      description: "Monthly beauty and grooming sample box.",
                      cancellationURL: "https://www.birchbox.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 15.00, annualPriceUSD: 156.00, isBestValue: true),
                      ]),
            makeEntry(bundleId: "com.ipsy.ipsy", name: "Ipsy", category: .personalCare,
                      description: "Monthly personalized beauty product bag.",
                      cancellationURL: "https://www.ipsy.com/",
                      tiers: [
                          TierPricing(tier: .individual, region: .us, monthlyPriceUSD: 13.00, annualPriceUSD: 143.00, isBestValue: true),
                      ]),
        ]
    }

    private func makeEntry(
        bundleId: String,
        name: String,
        category: SubscriptionCategory,
        description: String,
        cancellationURL: String? = nil,
        tiers: [TierPricing]
    ) -> CatalogEntry {
        CatalogEntry(
            id: UUID(),
            bundleId: bundleId,
            name: name,
            category: category,
            description: description,
            iconName: iconForCategory(category),
            appStoreProductId: nil,
            websiteURL: "https://\(name.lowercased().replacingOccurrences(of: " ", with: "")).com",
            cancellationURL: cancellationURL,
            trialDays: 0,
            canPause: true,
            supportedTiers: tiers,
            lastUpdated: Date()
        )
    }

    private func iconForCategory(_ category: SubscriptionCategory) -> String {
        switch category {
        case .entertainment: return "tv"
        case .music: return "music.note"
        case .productivity: return "briefcase"
        case .healthFitness: return "heart.circle"
        case .cloudStorage: return "cloud"
        case .education: return "book"
        case .utilities: return "wrench"
        case .finance: return "dollarsign.circle"
        case .food: return "fork.knife"
        case .shopping: return "cart"
        case .sports: return "sportscourt"
        case .social: return "person.2"
        case .news: return "newspaper"
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
