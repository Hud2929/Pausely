import Foundation
import UIKit
import os.log

/// Pausely App Configuration
/// Contains all app-wide settings including email configuration
enum AppConfig {
    // MARK: - App Info
    
    // MARK: - Support Email Configuration
    /// Primary support email - used for user inquiries, feedback, and support
    static let supportEmail = "pausely@proton.me"
    
    
    
    
    // MARK: - Social & Web
    static let supportURL = "https://pausely.pro/support.html"
    static let privacyPolicyURL = "https://pausely.pro/privacy.html"
    static let termsOfServiceURL = "https://pausely.pro/terms.html"
    /// Pausely's page in the App Store, opened on "write a review".
    static let writeReviewURL = "https://apps.apple.com/app/id6759973158?action=write-review"

    /// Daily exchange rates per US dollar. The only outside service the app calls besides Supabase,
    /// Apple and the mail providers a person connects; nothing about the person is sent to it.
    static let exchangeRatesURL = "https://api.exchangerate-api.com/v4/latest/USD"
    // MARK: - Deep Link Configuration
    
    // MARK: - Email Template Configuration
    
    // MARK: - Marketing
    
    // MARK: - Support
}


