import Foundation

/// Compile-time switches for features that are built but must not reach customers yet.
enum FeatureFlags {
    /// Gmail receipt scanning needs Google's approval of the restricted `gmail.readonly` scope.
    /// Until that arrives, release builds hide every entry point (an App Review tester would hit Google's
    /// "unverified app" wall). Debug builds keep it on for development and the demo launch flags.
    /// To ship it: set this to `true` once Google has approved the app.
    static let gmailImportEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Outlook, Hotmail, Live, MSN and Microsoft 365 through Microsoft Graph. Needs the app registration's
    /// client id (Info.plist MS_CLIENT_ID). Release builds stay off until real-account checks pass.
    static let microsoftImportEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// iCloud, Yahoo, AOL, Gmail (app password), GMX, WEB.DE, Zoho, Fastmail and other IMAP inboxes.
    /// Release builds stay off until real-account checks pass.
    static let imapImportEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Any way of finding subscriptions in email is available.
    static var inboxImportEnabled: Bool { gmailImportEnabled || microsoftImportEnabled || imapImportEnabled }
}
