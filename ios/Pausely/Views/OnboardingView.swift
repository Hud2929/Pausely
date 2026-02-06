import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showLogin = false
    
    let pages = [
        OnboardingPage(
            icon: "chart.pie.fill",
            title: "Track Your Subscriptions",
            description: "Connect your bank accounts to automatically detect all your recurring charges in one place."
        ),
        OnboardingPage(
            icon: "dollarsign.circle.fill",
            title: "See True Value",
            description: "See cost per hour instead of monthly fees. \"Netflix - $8/hour\" tells a different story than \"$15.99/month\"."
        ),
        OnboardingPage(
            icon: "gift.fill",
            title: "Unlock Free Perks",
            description: "Discover $50-100/month in free alternatives you already have access to through your credit cards, employer, and library."
        ),
        OnboardingPage(
            icon: "pause.circle.fill",
            title: "Pause, Don't Cancel",
            description: "Many services let you pause instead of cancel. Less scary, keeps your data, reactivate instantly."
        )
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            VStack(spacing: 16) {
                Button("Get Started") {
                    showLogin = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                
                Button("I already have an account") {
                    showLogin = true
                }
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 100))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
    }
}

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            Text("Sign In")
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                }
                
                Section {
                    Button("Create Account") {
                        // TODO: Implement sign up
                    }
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    func signIn() {
        isLoading = true
        // TODO: Implement actual sign in with Supabase
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            dismiss()
        }
    }
}
