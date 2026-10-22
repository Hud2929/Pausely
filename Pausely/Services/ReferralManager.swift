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


// MARK: - Referral Manager

@MainActor
class ReferralManager: ObservableObject {
    static let shared = ReferralManager()
    
    // MARK: - Published Properties
    @Published var currentUserReferralCode: String?
    @Published var referralData: ReferralData?
    @Published var conversions: [ReferralConversion] = []
    @Published var isLoading = false
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

        // Update referrer's pending conversions (read-modify-write)
        let referrerData: [ReferralData] = try await client
            .from("referral_codes")
            .select()
            .eq("code", value: code.uppercased())
            .execute()
            .value

        if let data = referrerData.first {
            try await client
                .from("referral_codes")
                .update(["pending_conversions": data.pendingConversions + 1])
                .eq("code", value: code.uppercased())
                .execute()
        }
        
        self.referrerCodeUsed = code.uppercased()
        self.appliedReferralDiscount = true
        self.referralDiscountUsed = false // Reset to ensure discount is available
        
        // Sync to database
        await syncReferralDiscountUsedToDatabase()
    }
    
    // MARK: - Conversion Tracking
    
    
    // MARK: - Free Pro Eligibility
    
    
    
    // MARK: - Referral Discount Management (First Month Only)
    
    
    
    
    
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
    /// - https://pausely.pro/r/CODE
    /// - https://pausely.pro/referral?code=CODE
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
        let isUniversalLink = scheme == "https" && (url.host?.lowercased() == "pausely.pro" || url.host?.lowercased() == "www.pausely.pro")
        
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

        // Handle pausely://r/CODE or https://pausely.pro/r/CODE
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
    
    
    
    // MARK: - Helper Methods
    
    private func generateUniqueCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed confusing characters
        var code = ""
        for _ in 0..<8 {
            code.append(characters.randomElement() ?? Character("X"))
        }
        return code
    }
    
    

    // MARK: - Share Helpers


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
}
