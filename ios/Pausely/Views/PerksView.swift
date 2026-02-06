import SwiftUI

struct PerksView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Free Perks")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Connect your accounts to discover free subscriptions you already have access to")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    PerkSourceRow(icon: "creditcard", title: "Credit Cards", subtitle: "Chase, Amex, Citi perks")
                    PerkSourceRow(icon: "building.2", title: "Employer Benefits", subtitle: "Wellness, learning stipends")
                    PerkSourceRow(icon: "book", title: "Library", subtitle: "Free streaming, audiobooks")
                    PerkSourceRow(icon: "shield", title: "Insurance", subtitle: "Health, auto perks")
                }
                .padding()
                
                Spacer()
                
                Button("Connect Accounts") {
                    // TODO: Implement account connection
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
            .navigationTitle("Free Perks")
        }
    }
}

struct PerkSourceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.email ?? "User")
                                .font(.headline)
                            
                            Text("Free Plan")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Preferences") {
                    NavigationLink("Notifications") {
                        Text("Notification Settings")
                    }
                    NavigationLink("Connected Banks") {
                        Text("Bank Connections")
                    }
                    NavigationLink("Screen Time") {
                        Text("Screen Time Settings")
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        authManager.signOut()
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
