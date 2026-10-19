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
}
