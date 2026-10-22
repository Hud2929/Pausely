import Foundation
import UIKit
import os.log

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
        os_log("⚠️ WARNING: SUPPORT_EMAIL_PASSWORD not configured. Email features disabled.")
        #endif
        return ""
    }
    
    /// Email used for sending transactional emails (confirmations, resets)
    static let noreplyEmail = "noreply@pausely.app"
    
    /// Email used for marketing communications
    static let marketingEmail = "hello@pausely.app"
    
    // MARK: - Social & Web
    // The website is pausely.pro (served from the gh-pages branch). These URLs must match the ones in
    // App Store Connect (see scripts/store_copy.py) and must always resolve: a dead Terms or Privacy
    // link on the paywall is an App Review rejection.
    static let websiteURL = "https://pausely.pro"
    static let supportURL = "https://pausely.pro/support.html"
    static let privacyPolicyURL = "https://pausely.pro/privacy.html"
    static let termsOfServiceURL = "https://pausely.pro/terms.html"
    static let refundPolicyURL = "https://pausely.pro/refunds.html"
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


