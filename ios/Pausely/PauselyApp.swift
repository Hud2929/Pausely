import SwiftUI
import Supabase

@main
struct PauselyApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
        }
    }
}

// MARK: - Auth Manager
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        checkSession()
    }
    
    func checkSession() {
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                await MainActor.run {
                    self.currentUser = session.user
                    self.isAuthenticated = true
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    func signOut() {
        Task {
            try? await SupabaseManager.shared.client.auth.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
            }
        }
    }
}
