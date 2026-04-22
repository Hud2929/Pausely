//
//  TrialProtectionStore.swift
//  Pausely
//
//  Revolutionary trial protection WITHOUT needing virtual cards
//  Tracks trials, sends reminders, provides one-tap cancel
//

import Foundation
import SwiftUI
import Supabase
import os.log

/// Represents a free trial being tracked
struct TrackedTrial: Identifiable, Codable {
    let id: UUID
    var serviceName: String
    var startDate: Date
    var endDate: Date
    var costAfterTrial: Decimal
    var currency: String
    var category: String
    var status: TrialStatus
    var cancelURL: String?
    var notes: String
    var reminderDates: [Date]
    var hasBeenReminded: Bool
    
    enum TrialStatus: String, Codable {
        case active = "active"         // Currently in trial period
        case endingSoon = "ending_soon" // Less than 48 hours left
        case converted = "converted"    // User decided to keep it
        case cancelled = "cancelled"    // User cancelled
        case expired = "expired"        // Trial ended without action
        
        var displayName: String {
            switch self {
            case .active: return "Active Trial"
            case .endingSoon: return "Ending Soon!"
            case .converted: return "Converted"
            case .cancelled: return "Cancelled"
            case .expired: return "Expired"
            }
        }
        
        var color: Color {
            switch self {
            case .active: return .blue
            case .endingSoon: return .orange
            case .converted: return .green
            case .cancelled: return .gray
            case .expired: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "clock.fill"
            case .endingSoon: return "exclamationmark.triangle.fill"
            case .converted: return "checkmark.circle.fill"
            case .cancelled: return "xmark.circle.fill"
            case .expired: return "clock.badge.xmark"
            }
        }
    }
    
    /// Total hours remaining in trial — computed correctly using day*24 + hour
    var daysRemaining: Int {
        let components = Calendar.current.dateComponents([.day, .hour], from: Date(), to: endDate)
        let totalHours = (components.day ?? 0) * 24 + (components.hour ?? 0)
        return max(0, totalHours) / 24
    }

    /// Total hours remaining (not hour-of-day) for "ending soon" detection
    var hoursRemaining: Int {
        let components = Calendar.current.dateComponents([.day, .hour], from: Date(), to: endDate)
        let totalHours = (components.day ?? 0) * 24 + (components.hour ?? 0)
        return max(0, totalHours)
    }
    
    /// Whether trial is ending within 48 hours
    var isEndingSoon: Bool {
        hoursRemaining <= 48 && hoursRemaining > 0 && status == .active
    }
    
    /// Progress percentage (0-100)
    var progressPercentage: Double {
        let totalDuration = endDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        return min(100, max(0, (elapsed / totalDuration) * 100))
    }
    
    /// Estimated savings if cancelled
    var estimatedAnnualSavings: Decimal {
        costAfterTrial * 12
    }
}

@MainActor
class TrialProtectionStore: ObservableObject {
    static let shared = TrialProtectionStore()

    @Published var trials: [TrackedTrial] = []
    @Published var stats: TrialStats = .empty
    @Published var isLoading = false
    @Published var showCelebration = false
    @Published var lastSavedAmount: Decimal = 0

    private let userDefaultsKey = "tracked_trials"
    private let statsKey = "trial_stats"
    private var checkTimer: Timer?
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private init() {
        loadTrials()
        loadStats()
        startMonitoring()
        Task { await loadTrialsFromSupabase() }
    }
    
    deinit {
        checkTimer?.invalidate()
    }
    
    // MARK: - Trial Management
    
    /// Add a new trial to track
    func addTrial(
        serviceName: String,
        durationDays: Int,
        costAfterTrial: Decimal,
        currency: String = "USD",
        category: String = "Entertainment",
        cancelURL: String? = nil
    ) -> TrackedTrial {
        let now = Date()
        let calculatedEndDate = Calendar.current.date(byAdding: .day, value: durationDays, to: now) ?? now

        // Set reminder dates (2 days before, 1 day before, day of)
        let twoDaysBefore = Calendar.current.date(byAdding: .day, value: -2, to: calculatedEndDate)
        let oneDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: calculatedEndDate)
        let reminderDates: [Date] = [
            twoDaysBefore ?? calculatedEndDate,
            oneDayBefore ?? calculatedEndDate,
            calculatedEndDate
        ]

        let trial = TrackedTrial(
            id: UUID(),
            serviceName: serviceName,
            startDate: now,
            endDate: calculatedEndDate,
            costAfterTrial: costAfterTrial,
            currency: currency,
            category: category,
            status: .active,
            cancelURL: cancelURL,
            notes: "",
            reminderDates: reminderDates,
            hasBeenReminded: false
        )

        trials.append(trial)
        saveTrials()
        updateStats()

        // Sync to Supabase
        Task {
            try? await saveTrialToSupabase(trial)
        }

        return trial
    }
    
    /// Quick add from template
    func quickAddTrial(from template: TrialTemplate) -> TrackedTrial {
        addTrial(
            serviceName: template.serviceName,
            durationDays: template.trialDays,
            costAfterTrial: template.monthlyCost,
            currency: CurrencyManager.shared.selectedCurrency,
            category: template.category,
            cancelURL: template.cancelURL
        )
    }
    
    /// Mark trial as cancelled (user saved money!)
    func cancelTrial(_ trial: TrackedTrial) {
        if let index = trials.firstIndex(where: { $0.id == trial.id }) {
            trials[index].status = .cancelled
            saveTrials()

            // Update stats with savings
            var newStats = stats
            newStats.totalTrialsCancelled += 1
            newStats.totalMoneySaved += trial.estimatedAnnualSavings
            stats = newStats
            saveStats()

            // Show celebration
            lastSavedAmount = trial.estimatedAnnualSavings
            showCelebration = true

            // Hide celebration after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showCelebration = false
            }

            // Sync to Supabase
            Task {
                try? await saveTrialToSupabase(trials[index])
            }
        }
    }

    /// Mark trial as converted (user decided to keep)
    func convertTrial(_ trial: TrackedTrial) {
        if let index = trials.firstIndex(where: { $0.id == trial.id }) {
            trials[index].status = .converted
            saveTrials()
            updateStats()

            // Sync to Supabase
            Task {
                try? await saveTrialToSupabase(trials[index])
            }
        }
    }

    /// Update trial status based on time
    func updateTrialStatus(_ trial: TrackedTrial) {
        if let index = trials.firstIndex(where: { $0.id == trial.id }) {
            // Check if trial has ended
            if Date() > trial.endDate && trial.status == .active {
                trials[index].status = .expired
                saveTrials()
                updateStats()
            }
            // Check if ending soon
            else if trial.isEndingSoon && trial.status == .active {
                trials[index].status = .endingSoon
                saveTrials()
            }

            // Sync to Supabase
            Task {
                try? await saveTrialToSupabase(trials[index])
            }
        }
    }

    /// Delete a trial
    func deleteTrial(_ trial: TrackedTrial) {
        trials.removeAll { $0.id == trial.id }
        saveTrials()
        updateStats()

        // Delete from Supabase
        Task {
            try? await deleteTrialFromSupabase(trial.id)
        }
    }
    
    // MARK: - Computed Properties
    
    var activeTrials: [TrackedTrial] {
        trials.filter { $0.status == .active || $0.status == .endingSoon }
            .sorted { $0.endDate < $1.endDate }
    }
    
    var trialsEndingSoon: [TrackedTrial] {
        trials.filter { $0.isEndingSoon }
    }
    
    var pastTrials: [TrackedTrial] {
        trials.filter { $0.status == .cancelled || $0.status == .converted || $0.status == .expired }
            .sorted { $0.endDate > $1.endDate }
    }
    
    var totalSaved: Decimal {
        stats.totalMoneySaved
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // Check every hour for trial status updates
        checkTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAllTrials()
            }
        }
        
        // Initial check
        checkAllTrials()
    }
    
    func checkAllTrials() {
        for trial in trials {
            updateTrialStatus(trial)
        }
    }
    
    // MARK: - Supabase Sync

    /// Load trials from Supabase and merge with local storage
    func loadTrialsFromSupabase() async {
        guard let userId = RevolutionaryAuthManager.shared.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: [TrackedTrialDBModel] = try await client
                .from("tracked_trials")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // Merge Supabase data with local
            let remoteTrials = response.map { $0.toTrackedTrial() }
            let localTrials = loadLocalTrials()

            // Merge: prefer remote for matching IDs, add local-only as new
            var mergedTrials: [TrackedTrial] = []

            for remote in remoteTrials {
                if let local = localTrials.first(where: { $0.id == remote.id }) {
                    // Update status if remote is newer
                    var updated = remote
                    if local.status != .cancelled && local.status != .converted {
                        updated.status = remote.status
                    }
                    mergedTrials.append(updated)
                } else {
                    mergedTrials.append(remote)
                }
            }

            // Add local-only trials to Supabase
            for local in localTrials {
                if !remoteTrials.contains(where: { $0.id == local.id }) {
                    try await saveTrialToSupabase(local)
                    mergedTrials.append(local)
                }
            }

            await MainActor.run {
                self.trials = mergedTrials
                self.saveTrials()
            }

            os_log("✅ Loaded %d trials from Supabase", log: .default, type: .info, remoteTrials.count)
        } catch {
            os_log("❌ Failed to load trials from Supabase: %{public}@", log: .default, type: .error, error.localizedDescription)
            // Fall back to local
            loadTrials()
        }
    }

    /// Save a single trial to Supabase
    private func saveTrialToSupabase(_ trial: TrackedTrial) async throws {
        guard let userId = RevolutionaryAuthManager.shared.currentUser?.id else { return }

        let dbModel = TrackedTrialDBModel(from: trial, userId: userId)

        try await client
            .from("tracked_trials")
            .upsert(dbModel)
            .execute()
    }

    /// Delete a trial from Supabase
    private func deleteTrialFromSupabase(_ trialId: UUID) async throws {
        guard let userId = RevolutionaryAuthManager.shared.currentUser?.id else { return }

        try await client
            .from("tracked_trials")
            .delete()
            .eq("id", value: trialId.uuidString)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Persistence

    private func saveTrials() {
        if let data = try? JSONEncoder().encode(trials) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadTrials() {
        let loaded = loadLocalTrials()
        if !loaded.isEmpty {
            trials = loaded
        }
    }

    private func loadLocalTrials() -> [TrackedTrial] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([TrackedTrial].self, from: data)) ?? []
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }

    private func loadStats() {
        guard let data = UserDefaults.standard.data(forKey: statsKey) else { return }
        if let loaded = try? JSONDecoder().decode(TrialStats.self, from: data) {
            stats = loaded
        }
    }
    
    private func updateStats() {
        let activeCount = trials.filter { $0.status == .active }.count
        _ = trials.filter { $0.status == .cancelled }.count
        _ = trials.filter { $0.status == .converted }.count
        
        var newStats = stats
        newStats.totalTrialsTracked = trials.count
        newStats.activeTrials = activeCount
        // Keep the saved amount as is (it's cumulative)
        stats = newStats
        saveStats()
    }
    
    // MARK: - Cancel URL Helpers
    
    func getCancelURL(for service: String) -> URL? {
        let lowercased = service.lowercased()
        
        let urls: [String: String] = [
            "netflix": "https://www.netflix.com/cancelplan",
            "spotify": "https://www.spotify.com/account/subscription/",
            "disney": "https://www.disneyplus.com/account",
            "disney+": "https://www.disneyplus.com/account",
            "hulu": "https://secure.hulu.com/account",
            "hbo": "https://www.max.com/manage-subscription",
            "hbo max": "https://www.max.com/manage-subscription",
            "max": "https://www.max.com/manage-subscription",
            "youtube": "https://www.youtube.com/paid_memberships",
            "apple": "https://apps.apple.com/account/subscriptions",
            "apple tv": "https://apps.apple.com/account/subscriptions",
            "amazon": "https://www.amazon.com/gp/mc/pd",
            "prime": "https://www.amazon.com/gp/mc/pd",
            "adobe": "https://account.adobe.com/plans",
            "canva": "https://www.canva.com/settings/billing",
            "notion": "https://www.notion.so/settings/billing",
            "figma": "https://www.figma.com/settings",
            "chatgpt": "https://chat.openai.com/settings",
            "openai": "https://chat.openai.com/settings",
            "midjourney": "https://www.midjourney.com/account",
            "duolingo": "https://www.duolingo.com/settings/super",
            "headspace": "https://www.headspace.com/settings",
            "peloton": "https://members.onepeloton.com/preferences/subscription"
        ]
        
        // Try exact match first
        if let url = urls[lowercased] {
            return URL(string: url)
        }
        
        // Try partial match
        for (key, url) in urls {
            if lowercased.contains(key) {
                return URL(string: url)
            }
        }
        
        return nil
    }
}

// MARK: - Trial Stats

struct TrialStats: Codable {
    var totalTrialsTracked: Int
    var totalTrialsCancelled: Int
    var activeTrials: Int
    var totalMoneySaved: Decimal
    
    static var empty: TrialStats {
        TrialStats(
            totalTrialsTracked: 0,
            totalTrialsCancelled: 0,
            activeTrials: 0,
            totalMoneySaved: 0
        )
    }
}

// MARK: - Trial Templates

struct TrialTemplate: Identifiable {
    let id = UUID()
    let serviceName: String
    let icon: String
    let trialDays: Int
    let monthlyCost: Decimal
    let category: String
    let cancelURL: String?
    let color: Color
}

extension TrialProtectionStore {
    static let templates: [TrialTemplate] = [
        TrialTemplate(
            serviceName: "Netflix",
            icon: "play.tv.fill",
            trialDays: 0,
            monthlyCost: 15.49,
            category: "Streaming",
            cancelURL: "https://www.netflix.com/cancelplan",
            color: .red
        ),
        TrialTemplate(
            serviceName: "Spotify Premium",
            icon: "music.note",
            trialDays: 30,
            monthlyCost: 10.99,
            category: "Music",
            cancelURL: "https://www.spotify.com/account/subscription/",
            color: .green
        ),
        TrialTemplate(
            serviceName: "Disney+",
            icon: "star.circle.fill",
            trialDays: 7,
            monthlyCost: 7.99,
            category: "Streaming",
            cancelURL: "https://www.disneyplus.com/account",
            color: .blue
        ),
        TrialTemplate(
            serviceName: "Hulu",
            icon: "tv.fill",
            trialDays: 30,
            monthlyCost: 7.99,
            category: "Streaming",
            cancelURL: "https://secure.hulu.com/account",
            color: .green
        ),
        TrialTemplate(
            serviceName: "HBO Max",
            icon: "film.fill",
            trialDays: 7,
            monthlyCost: 15.99,
            category: "Streaming",
            cancelURL: "https://www.max.com/manage-subscription",
            color: .purple
        ),
        TrialTemplate(
            serviceName: "YouTube Premium",
            icon: "play.rectangle.fill",
            trialDays: 30,
            monthlyCost: 11.99,
            category: "Streaming",
            cancelURL: "https://www.youtube.com/paid_memberships",
            color: .red
        ),
        TrialTemplate(
            serviceName: "Apple TV+",
            icon: "apple.logo",
            trialDays: 7,
            monthlyCost: 6.99,
            category: "Streaming",
            cancelURL: "https://apps.apple.com/account/subscriptions",
            color: .black
        ),
        TrialTemplate(
            serviceName: "Adobe Creative Cloud",
            icon: "photo.fill",
            trialDays: 7,
            monthlyCost: 54.99,
            category: "Productivity",
            cancelURL: "https://account.adobe.com/plans",
            color: .red
        ),
        TrialTemplate(
            serviceName: "Canva Pro",
            icon: "paintbrush.fill",
            trialDays: 30,
            monthlyCost: 12.99,
            category: "Productivity",
            cancelURL: "https://www.canva.com/settings/billing",
            color: .blue
        ),
        TrialTemplate(
            serviceName: "Notion",
            icon: "doc.text.fill",
            trialDays: 0,
            monthlyCost: 10.00,
            category: "Productivity",
            cancelURL: "https://www.notion.so/settings/billing",
            color: .gray
        ),
        TrialTemplate(
            serviceName: "ChatGPT Plus",
            icon: "bubble.left.fill",
            trialDays: 0,
            monthlyCost: 20.00,
            category: "Productivity",
            cancelURL: "https://chat.openai.com/settings",
            color: .green
        ),
        TrialTemplate(
            serviceName: "Amazon Prime",
            icon: "cart.fill",
            trialDays: 30,
            monthlyCost: 14.99,
            category: "Shopping",
            cancelURL: "https://www.amazon.com/gp/mc/pd",
            color: .orange
        ),
        TrialTemplate(
            serviceName: "Duolingo Plus",
            icon: "character.book.closed.fill",
            trialDays: 14,
            monthlyCost: 6.99,
            category: "Education",
            cancelURL: "https://www.duolingo.com/settings/super",
            color: .green
        ),
        TrialTemplate(
            serviceName: "Headspace",
            icon: "brain.head.profile",
            trialDays: 14,
            monthlyCost: 12.99,
            category: "Health",
            cancelURL: "https://www.headspace.com/settings",
            color: .orange
        ),
        TrialTemplate(
            serviceName: "Peloton",
            icon: "bicycle",
            trialDays: 30,
            monthlyCost: 12.99,
            category: "Health",
            cancelURL: "https://members.onepeloton.com/preferences/subscription",
            color: .red
        )
    ]
}

// MARK: - Supabase Database Model

/// Database model for Supabase sync
struct TrackedTrialDBModel: Codable {
    let id: UUID
    let userId: String
    let serviceName: String
    let startDate: Date
    let endDate: Date
    let costAfterTrial: Decimal
    let currency: String
    let category: String
    let status: String
    let cancelURL: String?
    let notes: String
    let reminderDates: [Date]
    let hasBeenReminded: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case serviceName = "service_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case costAfterTrial = "cost_after_trial"
        case currency
        case category
        case status
        case cancelURL = "cancel_url"
        case notes
        case reminderDates = "reminder_dates"
        case hasBeenReminded = "has_been_reminded"
    }

    init(from trial: TrackedTrial, userId: String) {
        self.id = trial.id
        self.userId = userId
        self.serviceName = trial.serviceName
        self.startDate = trial.startDate
        self.endDate = trial.endDate
        self.costAfterTrial = trial.costAfterTrial
        self.currency = trial.currency
        self.category = trial.category
        self.status = trial.status.rawValue
        self.cancelURL = trial.cancelURL
        self.notes = trial.notes
        self.reminderDates = trial.reminderDates
        self.hasBeenReminded = trial.hasBeenReminded
    }

    func toTrackedTrial() -> TrackedTrial {
        TrackedTrial(
            id: id,
            serviceName: serviceName,
            startDate: startDate,
            endDate: endDate,
            costAfterTrial: costAfterTrial,
            currency: currency,
            category: category,
            status: TrackedTrial.TrialStatus(rawValue: status) ?? .active,
            cancelURL: cancelURL,
            notes: notes,
            reminderDates: reminderDates,
            hasBeenReminded: hasBeenReminded
        )
    }
}
