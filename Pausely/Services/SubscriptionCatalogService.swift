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

    private init() {}

    // MARK: - Subscriptions (for tracking compatibility)

    /// Returns all known subscriptions as simple structs for tracking
    var subscriptions: [CatalogSubscription] {
        catalog.map { CatalogSubscription(from: $0) }
    }

    /// Find bundle ID for a subscription name
    func findBundleId(for name: String) -> String? {
        let lowercased = name.lowercased()
        // Try exact match first
        if let exact = catalog.first(where: { $0.name.lowercased() == lowercased }) {
            return exact.bundleId
        }
        // Try partial match
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

        // 1. Try remote Teenybase API
        if let remote = await fetchFromRemote() {
            catalog = remote
            lastFetchDate = Date()
            isFromCache = false
            cacheLocally(remote)
            return
        }

        // 2. Fall back to local cache
        if let cached = loadFromCache() {
            catalog = cached
            isFromCache = true
            lastFetchDate = UserDefaults.standard.object(forKey: cacheDateKey) as? Date
            return
        }

        // 3. Fall back to hardcoded catalog
        catalog = buildHardcodedCatalog()
        isFromCache = false
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

                tierList.append(TierPricing(
                    tier: tier,
                    region: region,
                    monthlyPriceUSD: monthlyUSD,
                    annualPriceUSD: annualUSD,
                    isBestValue: bestValue
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
        catalog.first { $0.bundleId == bundleId }
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
        case .other: return "square.grid.2x2"
        }
    }
}
