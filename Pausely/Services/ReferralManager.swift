import Foundation
import SwiftUI
import Supabase
import Auth
import PostgREST
import os.log

// MARK: - Referral Data Models

struct ReferralData: Codable {
    let code: String
    let referrerUserId: String
    var conversions: Int
    var pendingConversions: Int
    var totalEarnings: Decimal
    let createdAt: Date
    var isEligibleForFreePro: Bool
    
    enum CodingKeys: String, CodingKey {
        case code
        case referrerUserId = "referrer_user_id"
        case conversions
        case pendingConversions = "pending_conversions"
        case totalEarnings = "total_earnings"
        case createdAt = "created_at"
        case isEligibleForFreePro = "is_eligible_for_free_pro"
    }
}

struct ReferralConversion: Codable {
    let id: String
    let referrerCode: String
    let referredUserId: String
    let referredUserEmail: String?
    var status: ConversionStatus
    let createdAt: Date
    var convertedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case referrerCode = "referrer_code"
        case referredUserId = "referred_user_id"
        case referredUserEmail = "referred_user_email"
        case status
        case createdAt = "created_at"
        case convertedAt = "converted_at"
    }
}

enum ConversionStatus: String, Codable {
    case pending = "pending"
    case converted = "converted"
    case cancelled = "cancelled"
}

struct ReferralValidationResponse: Codable {
    let valid: Bool
    let code: String?
    let message: String?
}

// MARK: - Referral Manager

@MainActor
class ReferralManager: ObservableObject {
    static let shared = ReferralManager()
    
    // MARK: - Published Properties
    @Published var currentUserReferralCode: String?
    @Published var referralData: ReferralData?
    @Published var conversions: [ReferralConversion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pendingReferralCode: String? {
        didSet {
            UserDefaults.standard.set(pendingReferralCode, forKey: Self.pendingReferralCodeKey)
        }
    }
    @Published var appliedReferralDiscount: Bool {
        didSet {
            UserDefaults.standard.set(appliedReferralDiscount, forKey: Self.appliedDiscountKey)
        }
    }
    @Published var referrerCodeUsed: String? {
        didSet {
            UserDefaults.standard.set(referrerCodeUsed, forKey: Self.referrerCodeKey)
        }
    }
    /// Tracks if the referral discount has been consumed (used for first payment)
    @Published var referralDiscountUsed: Bool {
        didSet {
            UserDefaults.standard.set(referralDiscountUsed, forKey: Self.referralDiscountUsedKey)
            // Sync to database when flag changes
            Task { [weak self] in
                guard let self = self else { return }
                await self.syncReferralDiscountUsedToDatabase()
            }
        }
    }
    
    // MARK: - Constants
    static let pendingReferralCodeKey = "pending_referral_code"
    static let appliedDiscountKey = "applied_referral_discount"
    static let referrerCodeKey = "referrer_code_used"
    static let referralDiscountUsedKey = "referral_discount_used"
    static let freeProThreshold = 3
    static let referralDiscountPercentage: Double = 0.30 // 30%
    
    // MARK: - Private Properties
    private var client: SupabaseClient { SupabaseManager.shared.client }
    
    // MARK: - Initialization
    private init() {
        self.pendingReferralCode = UserDefaults.standard.string(forKey: Self.pendingReferralCodeKey)
        self.appliedReferralDiscount = UserDefaults.standard.bool(forKey: Self.appliedDiscountKey)
        self.referrerCodeUsed = UserDefaults.standard.string(forKey: Self.referrerCodeKey)
        self.referralDiscountUsed = UserDefaults.standard.bool(forKey: Self.referralDiscountUsedKey)
        
        // Load locally saved code first (for immediate display)
        if let savedCode = UserDefaults.standard.string(forKey: "local_referral_code") {
            self.currentUserReferralCode = savedCode
            #if DEBUG
            os_log("ReferralManager: Loaded saved code: %{public}@", log: .default, type: .info, savedCode)
            #endif
        } else {
            // Generate a code immediately if none exists
            let code = generateUniqueCode()
            self.currentUserReferralCode = code
            UserDefaults.standard.set(code, forKey: "local_referral_code")
            #if DEBUG
            os_log("ReferralManager: Generated new code: %{public}@", log: .default, type: .info, code)
            #endif
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            await self.loadCurrentUserReferralData()
            await self.loadReferralDiscountUsedFromDatabase()
        }
    }
    
    // MARK: - Referral Code Generation
    
    func generateReferralCode(for userId: String) async throws -> String {
        // Generate a unique 8-character code
        let code = generateUniqueCode()
        
        let referralData = ReferralData(
            code: code,
            referrerUserId: userId,
            conversions: 0,
            pendingConversions: 0,
            totalEarnings: 0,
            createdAt: Date(),
            isEligibleForFreePro: false
        )
        
        // Store in Supabase
        try await client
            .from("referral_codes")
            .insert(referralData)
            .execute()
        
        self.currentUserReferralCode = code
        self.referralData = referralData
        
        return code
    }
    
    func getOrCreateReferralCode(for userId: String) async throws -> String {
        // First check if user already has a code
        if let existingCode = currentUserReferralCode {
            return existingCode
        }
        
        // Try to fetch existing code from database
        do {
            let response: [ReferralData] = try await client
                .from("referral_codes")
                .select()
                .eq("referrer_user_id", value: userId)
                .execute()
                .value
            
            if let existing = response.first {
                self.currentUserReferralCode = existing.code
                self.referralData = existing
                return existing.code
            }
        } catch {
            #if DEBUG
            os_log("No existing referral code found, creating new one", log: .default, type: .info)
            #endif
        }
        
        // Create new code
        return try await generateReferralCode(for: userId)
    }
    
    // MARK: - Referral Code Validation
    
    func validateReferralCode(_ code: String) async -> Bool {
        let uppercasedCode = code.uppercased()
        
        guard uppercasedCode.count >= 6 else { return false }
        
        // Prevent self-referral
        if uppercasedCode == currentUserReferralCode?.uppercased() {
            #if DEBUG
            os_log("Self-referral prevented", log: .default, type: .info)
            #endif
            return false
        }

        // Check local storage for valid codes (for offline support)
        if let localCodes = UserDefaults.standard.array(forKey: "valid_referral_codes") as? [String],
           localCodes.contains(uppercasedCode) {
            #if DEBUG
            os_log("Validated code from local storage: %{public}@", log: .default, type: .info, uppercasedCode)
            #endif
            return true
        }
        
        // Try server validation
        do {
            let response: [ReferralData] = try await client
                .from("referral_codes")
                .select()
                .eq("code", value: uppercasedCode)
                .execute()
                .value
            
            let isValid = !response.isEmpty
            
            // Cache valid code locally for offline use
            if isValid {
                var cachedCodes = UserDefaults.standard.array(forKey: "valid_referral_codes") as? [String] ?? []
                if !cachedCodes.contains(uppercasedCode) {
                    cachedCodes.append(uppercasedCode)
                    UserDefaults.standard.set(cachedCodes, forKey: "valid_referral_codes")
                }
            }
            
            return isValid
        } catch {
            #if DEBUG
            os_log("Error validating referral code: %{public}@", log: .default, type: .error, error.localizedDescription)
            #endif
            // Fail-closed: reject codes when server is unavailable
            return false
        }
    }
    
    // MARK: - Referral Application
    
    func applyReferralCode(_ code: String, for userId: String, email: String?) async throws {
        guard await validateReferralCode(code) else {
            throw ReferralError.invalidCode
        }
        
        // Check if user already used a referral code
        if referrerCodeUsed != nil {
            throw ReferralError.alreadyUsedReferral
        }
        
        // Create conversion record
        let conversion = ReferralConversion(
            id: UUID().uuidString,
            referrerCode: code.uppercased(),
            referredUserId: userId,
            referredUserEmail: email,
            status: .pending,
            createdAt: Date(),
            convertedAt: nil
        )
        
        try await client
            .from("referral_conversions")
            .insert(conversion)
            .execute()
        
        // Update referrer's pending conversions
        try await client
            .from("referral_codes")
            .update(["pending_conversions": 1])
            .eq("code", value: code.uppercased())
            .execute()
        
        self.referrerCodeUsed = code.uppercased()
        self.appliedReferralDiscount = true
        self.referralDiscountUsed = false // Reset to ensure discount is available
        
        // Sync to database
        await syncReferralDiscountUsedToDatabase()
    }
    
    // MARK: - Conversion Tracking
    
    func markConversionAsPaid(referredUserId: String) async throws {
        // Update conversion status
        try await client
            .from("referral_conversions")
            .update([
                "status": ConversionStatus.converted.rawValue,
                "converted_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("referred_user_id", value: referredUserId)
            .execute()
        
        // Get the conversion to find the referrer
        let conversions: [ReferralConversion] = try await client
            .from("referral_conversions")
            .select()
            .eq("referred_user_id", value: referredUserId)
            .eq("status", value: ConversionStatus.converted.rawValue)
            .execute()
            .value
        
        guard let conversion = conversions.first else { return }
        
        // Update referrer stats using RPC or direct increment
        // First update count fields
        try await client
            .from("referral_codes")
            .update([
                "conversions": 1,
                "pending_conversions": -1
            ])
            .eq("code", value: conversion.referrerCode)
            .execute()

        // Then update earnings separately as a raw query
        let newEarnings = 500 // $5.00 = 500 cents
        try await client
            .from("referral_codes")
            .update(["total_earnings": newEarnings])
            .eq("code", value: conversion.referrerCode)
            .execute()
        
        // Check if referrer qualifies for free Pro
        try await checkAndUpdateFreeProEligibility(code: conversion.referrerCode)
        
        await loadCurrentUserReferralData()
    }
    
    // MARK: - Free Pro Eligibility
    
    func checkAndUpdateFreeProEligibility(code: String) async throws {
        let response: [ReferralData] = try await client
            .from("referral_codes")
            .select()
            .eq("code", value: code)
            .execute()
            .value
        
        guard let data = response.first else { return }
        
        let isEligible = data.conversions >= Self.freeProThreshold
        
        if isEligible && !data.isEligibleForFreePro {
            try await client
                .from("referral_codes")
                .update(["is_eligible_for_free_pro": true])
                .eq("code", value: code)
                .execute()
            
            // Grant free Pro to referrer
            grantFreeProToReferrer(userId: data.referrerUserId)
        }
    }
    
    func grantFreeProToReferrer(userId: String) {
        // Update payment manager to grant free Pro
        PaymentManager.shared.grantFreeProForReferrals()
    }
    
    // MARK: - Referral Discount Management (First Month Only)
    
    /// Checks if the user has an active referral discount that hasn't been used yet
    func hasActiveReferralDiscount() -> Bool {
        return appliedReferralDiscount && !referralDiscountUsed && referrerCodeUsed != nil
    }
    
    /// Marks the referral discount as used (called after first successful payment)
    func markReferralDiscountAsUsed() {
        guard !referralDiscountUsed else { return }
        
        referralDiscountUsed = true
        #if DEBUG
        os_log("✅ Referral discount marked as used - will not apply to future payments", log: .default, type: .info)
        #endif
        
        // Sync to database
        Task { [weak self] in
            guard let self = self else { return }
            await self.syncReferralDiscountUsedToDatabase()
        }
    }
    
    /// Clears the referral discount (used for testing or if purchase fails)
    func clearReferralDiscount() {
        appliedReferralDiscount = false
        referralDiscountUsed = false
        UserDefaults.standard.removeObject(forKey: Self.appliedDiscountKey)
        UserDefaults.standard.removeObject(forKey: Self.referralDiscountUsedKey)
    }
    
    /// Gets the discounted price if referral discount is active and unused
    func getDiscountedPrice(originalPrice: Decimal) -> Decimal {
        guard hasActiveReferralDiscount() else { return originalPrice }
        return originalPrice * Decimal(0.7) // 30% off = 70% of original price
    }
    
    // MARK: - Database Sync for Referral Discount Used
    
    private func syncReferralDiscountUsedToDatabase() async {
        guard let userId = RevolutionaryAuthManager.shared.currentUser?.id else { return }
        
        do {
            try await client
                .from("user_settings")
                .update(["referral_discount_used": referralDiscountUsed])
                .eq("user_id", value: userId)
                .execute()
        } catch {
            #if DEBUG
            os_log("Error syncing referral discount used to database: %{public}@", log: .default, type: .error, error.localizedDescription)
            #endif
        }
    }

    private func loadReferralDiscountUsedFromDatabase() async {
        guard let userId = RevolutionaryAuthManager.shared.currentUser?.id else { return }

        do {
            let response: [UserSettings] = try await client
                .from("user_settings")
                .select("referral_discount_used")
                .eq("user_id", value: userId)
                .execute()
                .value

            if let settings = response.first {
                self.referralDiscountUsed = settings.referralDiscountUsed
            }
        } catch {
            #if DEBUG
            os_log("Error loading referral discount used from database: %{public}@", log: .default, type: .error, error.localizedDescription)
            #endif
        }
    }
    
    // MARK: - Data Loading
    
    func loadCurrentUserReferralData() async {
        guard let userId = RevolutionaryAuthManager.shared.currentUser?.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get referral code
            let codes: [ReferralData] = try await client
                .from("referral_codes")
                .select()
                .eq("referrer_user_id", value: userId)
                .execute()
                .value
            
            if let data = codes.first {
                self.currentUserReferralCode = data.code
                self.referralData = data
            }
            
            // Get conversions
            let conversions: [ReferralConversion] = try await client
                .from("referral_conversions")
                .select()
                .eq("referrer_code", value: codes.first?.code ?? "")
                .execute()
                .value
            
            self.conversions = conversions
        } catch {
            #if DEBUG
            os_log("Error loading referral data: %{public}@", log: .default, type: .error, error.localizedDescription)
            #endif
        }
    }

    // MARK: - Deep Link Handling
    
    /// Handles referral deep links from both URL schemes and universal links
    /// Supports formats:
    /// - pausely://r/CODE
    /// - pausely://referral?code=CODE
    /// - https://pausely.app/r/CODE
    /// - https://pausely.app/referral?code=CODE
    func handleReferralDeepLink(_ url: URL) -> Bool {
        #if DEBUG
        os_log("🔗 ReferralManager handling URL: %{public}@", log: .default, type: .info, url.absoluteString)
        os_log("   - scheme: %{public}@", log: .default, type: .info, url.scheme ?? "nil")
        os_log("   - host: %{public}@", log: .default, type: .info, url.host ?? "nil")
        os_log("   - path: %{public}@", log: .default, type: .info, url.path)
        os_log("   - pathComponents: %{public}@", log: .default, type: .info, String(describing: url.pathComponents))
        #endif
        
        // Check if this is a supported scheme (pausely URL scheme or https universal link)
        let scheme = url.scheme?.lowercased() ?? ""
        let isPauselyScheme = scheme == "pausely"
        let isUniversalLink = scheme == "https" && (url.host?.lowercased() == "pausely.app" || url.host?.lowercased() == "www.pausely.app")
        
        guard isPauselyScheme || isUniversalLink else {
            #if DEBUG
            os_log("   ❌ Not a pausely URL scheme or universal link", log: .default, type: .info)
            #endif
            return false
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Get path components (removing empty strings from leading/trailing slashes)
        let pathComponents = url.pathComponents.filter { !$0.isEmpty }
        #if DEBUG
        os_log("   - filtered pathComponents: %{public}@", log: .default, type: .info, String(describing: pathComponents))
        #endif

        // Handle pausely://r/CODE or https://pausely.app/r/CODE
        if pathComponents.count >= 1 && (pathComponents[0].lowercased() == "r" || pathComponents[0].lowercased() == "referral") {
            // Check for code in path: /r/CODE or /referral/CODE
            if pathComponents.count >= 2 {
                let code = pathComponents[1]
                #if DEBUG
                os_log("   ✅ Found code in path: %{public}@", log: .default, type: .info, code)
                #endif
                handleIncomingReferralCode(code, source: "deep_link_path")
                return true
            }

            // Check for code in query: /r?code=CODE
            if let code = queryItems.first(where: { $0.name.lowercased() == "code" })?.value {
                #if DEBUG
                os_log("   ✅ Found code in query: %{public}@", log: .default, type: .info, code)
                #endif
                handleIncomingReferralCode(code, source: "deep_link_query")
                return true
            }
        }

        // Handle legacy format: pausely://referral?code=CODE (no path, just query)
        if pathComponents.isEmpty {
            if let code = queryItems.first(where: { $0.name.lowercased() == "code" })?.value {
                #if DEBUG
                os_log("   ✅ Found code in query (legacy format): %{public}@", log: .default, type: .info, code)
                #endif
                handleIncomingReferralCode(code, source: "deep_link_legacy")
                return true
            }
        }

        #if DEBUG
        os_log("   ❌ No referral code found in URL", log: .default, type: .info)
        #endif
        return false
    }
    
    func handleIncomingReferralCode(_ code: String, source: String = "unknown") {
        let cleanCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate code format (alphanumeric, 6+ characters)
        let validCharacters = CharacterSet.alphanumerics
        guard cleanCode.count >= 6,
              cleanCode.rangeOfCharacter(from: validCharacters.inverted) == nil else {
            #if DEBUG
            os_log("❌ Invalid referral code format: %{public}@", log: .default, type: .error, cleanCode)
            #endif
            NotificationCenter.default.post(
                name: .referralCodeInvalid,
                object: cleanCode
            )
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            let isValid = await self.validateReferralCode(cleanCode)

            await MainActor.run {
                if isValid {
                    self.pendingReferralCode = cleanCode
                    #if DEBUG
                    os_log("✅ Referral code stored: %{public}@ (source: %{public}@)", log: .default, type: .info, cleanCode, source)
                    #endif

                    // Show success notification
                    NotificationCenter.default.post(
                        name: .referralCodeReceived,
                        object: cleanCode,
                        userInfo: ["source": source, "valid": true]
                    )
                } else {
                    #if DEBUG
                    os_log("❌ Invalid referral code: %{public}@", log: .default, type: .error, cleanCode)
                    #endif

                    // Show invalid code notification
                    NotificationCenter.default.post(
                        name: .referralCodeInvalid,
                        object: cleanCode,
                        userInfo: ["source": source, "reason": "invalid_or_expired"]
                    )
                }
            }
        }
    }
    
    // MARK: - Referral Share URL
    
    func getReferralShareURL() -> URL? {
        guard let code = currentUserReferralCode else { return nil }
        return URL(string: "https://pausely.app/r/\(code)")
    }
    
    func getReferralShareText() -> String {
        guard let code = currentUserReferralCode else {
            return "Check out Pausely - the smart subscription manager!"
        }
        return "Get 30% off your first month of Pausely Pro! Use my referral code: \(code)\n\nhttps://pausely.app/r/\(code)"
    }
    
    // MARK: - Helper Methods
    
    private func generateUniqueCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed confusing characters
        var code = ""
        for _ in 0..<8 {
            code.append(characters.randomElement() ?? Character("X"))
        }
        return code
    }
    
    func clearPendingReferralCode() {
        pendingReferralCode = nil
        UserDefaults.standard.removeObject(forKey: Self.pendingReferralCodeKey)
    }
    
    func hasReferralDiscount() -> Bool {
        return hasActiveReferralDiscount()
    }

    // MARK: - Share Helpers

    /// Returns the full referral link string
    func referralLinkString() -> String {
        guard let code = currentUserReferralCode else {
            return "https://pausely.app/download"
        }
        return "https://pausely.app/r/\(code)"
    }

    /// Returns the display code or a fallback
    func displayCode() -> String {
        currentUserReferralCode ?? "Loading..."
    }

    /// Opens Messages with a pre-filled referral message
    func shareViaMessages() {
        let code = displayCode()
        let link = referralLinkString()
        let message = "Get Pausely and manage your subscriptions smarter! Use my code \(code) for 30% off. Get Pro FREE when you refer 3 friends! \(link)"

        guard let encodedBody = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "sms:&body=\(encodedBody)") else { return }

        UIApplication.shared.open(url)
    }

    /// Opens Mail with a pre-filled referral message
    func shareViaEmail() {
        let code = displayCode()
        let link = referralLinkString()
        let subject = "Get 30% off Pausely - Subscription Manager"
        let body = "Hey!\n\nI've been using Pausely to track and manage my subscriptions. It's saved me hundreds!\n\nUse my referral code \(code) to get 30% off. Plus, if you refer 3 friends, you get Pro FREE forever!\n\n\(link)"

        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:?subject=\(encodedSubject)&body=\(encodedBody)") else { return }

        UIApplication.shared.open(url)
    }

    /// Copies the referral message to the clipboard
    func copyToClipboard() -> String {
        let text = "Use my code \(displayCode()) to get 30% off Pausely! \(referralLinkString())"
        UIPasteboard.general.string = text
        return text
    }

    /// Presents a system share sheet with the referral content
    func shareViaSystem(presentingFrom rootVC: UIViewController?) {
        let code = displayCode()
        let link = referralLinkString()
        let text = "Get Pausely and manage your subscriptions smarter! Use my code \(code) for 30% off. Get Pro FREE when you refer 3 friends!"

        var shareItems: [Any] = [text]

        if let url = URL(string: link), link != "https://pausely.app/download" {
            shareItems.append(url)
        } else {
            shareItems.append("Download at: https://pausely.app")
        }

        let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .saveToCameraRoll
        ]

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC?.view
            popover.sourceRect = CGRect(x: rootVC?.view.bounds.midX ?? 0, y: rootVC?.view.bounds.midY ?? 0, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        rootVC?.present(activityVC, animated: true)
    }
}

// MARK: - User Settings Model for Database

struct UserSettings: Codable {
    let userId: String
    var referralDiscountUsed: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case referralDiscountUsed = "referral_discount_used"
    }
}

// MARK: - Errors

enum ReferralError: Error, LocalizedError {
    case invalidCode
    case alreadyUsedReferral
    case selfReferral
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "This referral code is invalid or expired."
        case .alreadyUsedReferral:
            return "You've already used a referral code."
        case .selfReferral:
            return "You can't refer yourself!"
        case .networkError:
            return "Network error. Please try again."
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let referralCodeReceived = Notification.Name("referralCodeReceived")
    static let referralCodeInvalid = Notification.Name("referralCodeInvalid")
    static let referralConversionsUpdated = Notification.Name("referralConversionsUpdated")
    static let referralDiscountUsedNotification = Notification.Name("referralDiscountUsed")
}
