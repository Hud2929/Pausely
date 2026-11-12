import SwiftUI

/// Pausely's Terms of Service and Privacy Policy.
///
/// Each has one copy, on the website. It is shown inside the app, so nobody is sent away in the
/// middle of creating an account, and the app can never show an older or different text than the site.
enum LegalPage: String, Identifiable {
    case terms, privacy

    var id: String { rawValue }

    var url: URL? {
        URL(string: self == .terms ? AppConfig.termsOfServiceURL : AppConfig.privacyPolicyURL)
    }

    @ViewBuilder var view: some View {
        if let url { SafariView(url: url).ignoresSafeArea() }
    }
}
