import Foundation
import UIKit

/// Pausely App Configuration
/// Contains all app-wide settings including email configuration
enum AppConfig {
    // MARK: - App Info
    static let appName = "Pausely"
    static let appSlogan = "Take Control of Your Subscriptions"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    // MARK: - Support Email Configuration
    /// Primary support email - used for user inquiries, feedback, and support
    static let supportEmail = "pausely@proton.me"
    
    /// Support email password - MUST be set via environment variable
    /// NEVER hardcode passwords in source code
    static var supportEmailPassword: String {
        // Try environment variable first
        if let envPassword = ProcessInfo.processInfo.environment["SUPPORT_EMAIL_PASSWORD"],
           !envPassword.isEmpty {
            return envPassword
        }
        
        // Try XCConfig
        if let configPassword = Bundle.main.object(forInfoDictionaryKey: "SUPPORT_EMAIL_PASSWORD") as? String,
           !configPassword.isEmpty,
           !configPassword.contains("$") {
            return configPassword
        }
        
        // Return empty string - functionality will be disabled
        // This is intentional - passwords should NEVER be in source code
        #if DEBUG
        print("⚠️ WARNING: SUPPORT_EMAIL_PASSWORD not configured. Email features disabled.")
        #endif
        return ""
    }
    
    /// Email used for sending transactional emails (confirmations, resets)
    static let noreplyEmail = "noreply@pausely.app"
    
    /// Email used for marketing communications
    static let marketingEmail = "hello@pausely.app"
    
    // MARK: - Social & Web
    // All legal URLs use pausely.app domain — must match App Store Connect
    static let websiteURL = "https://pausely.app"
    static let supportURL = "https://pausely.app/support"
    static let privacyPolicyURL = "https://pausely.app/privacy"
    static let termsOfServiceURL = "https://pausely.app/terms"
    static let twitterURL = "https://twitter.com/pausely"
    static let instagramURL = "https://instagram.com/pausely.app"
    
    // MARK: - Deep Link Configuration
    static let urlScheme = "pausely"
    static let authCallbackPath = "auth/callback"
    static let confirmEmailPath = "auth/confirm"
    static let resetPasswordPath = "auth/reset-password"
    
    // MARK: - Email Template Configuration
    static let emailBrandColor = "#8B5CF6" // Purple
    static let emailSecondaryColor = "#EC4899" // Pink
    static let emailAccentColor = "#F59E0B" // Gold
    static let emailBackgroundColor = "#0F0F0F" // Dark
    static let emailTextColor = "#FFFFFF" // White
    
    // MARK: - Marketing
    static let newsletterSignupEnabled = true
    static let welcomeEmailEnabled = true
    static let tipsAndTricksEnabled = true
    
    // MARK: - Support
    static let supportHours = "24/7"
    static let averageResponseTime = "Within 24 hours"
    static let enableInAppSupport = true
    static let enableEmailSupport = true
}

// MARK: - Email Types
enum EmailType {
    case welcome
    case confirmation
    case passwordReset
    case magicLink
    case marketing
    case support
    
    var fromEmail: String {
        switch self {
        case .welcome, .confirmation, .passwordReset, .magicLink:
            return AppConfig.noreplyEmail
        case .marketing:
            return AppConfig.marketingEmail
        case .support:
            return AppConfig.supportEmail
        }
    }
    
    var subject: String {
        switch self {
        case .welcome:
            return "Welcome to Pausely - Your Subscription Journey Begins"
        case .confirmation:
            return "Confirm Your Email - Pausely"
        case .passwordReset:
            return "Reset Your Pausely Password"
        case .magicLink:
            return "Your Magic Link to Pausely"
        case .marketing:
            return "Discover More with Pausely"
        case .support:
            return "Pausely Support - We're Here to Help"
        }
    }
}

// MARK: - Support Email Contact
struct SupportEmailContact {
    let email: String
    let subject: String
    let body: String
    
    static func supportRequest(userEmail: String?, issue: String) -> SupportEmailContact {
        let deviceInfo = "\n\n--- Device Info ---\nApp Version: \(AppConfig.appVersion)\nDevice: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)"
        
        return SupportEmailContact(
            email: AppConfig.supportEmail,
            subject: "Pausely Support Request",
            body: "From: \(userEmail ?? "Anonymous")\n\nIssue:\(issue)\(deviceInfo)"
        )
    }
    
    static func feedback(message: String) -> SupportEmailContact {
        return SupportEmailContact(
            email: AppConfig.supportEmail,
            subject: "Pausely Feedback",
            body: message
        )
    }
    
    public var mailtoURL: URL? {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)")
    }
    
    func openMail() {
        guard let url = mailtoURL else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - Marketing Preferences
struct MarketingPreferences {
    var subscribedToNewsletter: Bool
    var subscribedToProductUpdates: Bool
    var subscribedToTips: Bool
    
    static var `default`: MarketingPreferences {
        MarketingPreferences(
            subscribedToNewsletter: true,
            subscribedToProductUpdates: true,
            subscribedToTips: true
        )
    }
    
    static func load() -> MarketingPreferences {
        let defaults = UserDefaults.standard
        return MarketingPreferences(
            subscribedToNewsletter: defaults.bool(forKey: "marketing_newsletter"),
            subscribedToProductUpdates: defaults.bool(forKey: "marketing_updates"),
            subscribedToTips: defaults.bool(forKey: "marketing_tips")
        )
    }
    
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(subscribedToNewsletter, forKey: "marketing_newsletter")
        defaults.set(subscribedToProductUpdates, forKey: "marketing_updates")
        defaults.set(subscribedToTips, forKey: "marketing_tips")
    }
}
