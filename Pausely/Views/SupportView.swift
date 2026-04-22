import SwiftUI
import MessageUI

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var subject = ""
    @State private var message = ""
    @State private var category: SupportCategory = .general
    @State private var showMailComposer = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    
    enum SupportCategory: String, CaseIterable {
        case general = "General Question"
        case account = "Account Issue"
        case billing = "Billing & Payments"
        case bug = "Bug Report"
        case feature = "Feature Request"
        case email = "Email Not Received"
        
        var icon: String {
            switch self {
            case .general: return "questionmark.circle"
            case .account: return "person.crop.circle"
            case .billing: return "creditcard"
            case .bug: return "ant"
            case .feature: return "lightbulb"
            case .email: return "envelope.badge.shield"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "headset")
                                .font(.system(size: 50))
                                .foregroundStyle(Color.luxuryGold)
                            
                            Text("How Can We Help?")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Our support team is here for you 24/7")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        // Quick Contact
                        SupportGlassCard {
                            VStack(spacing: 16) {
                                Text("Quick Contact")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                HStack(spacing: 20) {
                                    SupportContactButton(
                                        icon: "envelope.fill",
                                        title: "Email Us",
                                        color: Color.luxuryGold
                                    ) {
                                        SupportEmailContact.supportRequest(
                                            userEmail: email,
                                            issue: "Support request from app"
                                        ).openMail()
                                    }
                                    
                                    SupportContactButton(
                                        icon: "doc.text.fill",
                                        title: "FAQ",
                                        color: Color.luxuryPurple
                                    ) {
                                        // Open FAQ
                                        if let url = URL(string: AppConfig.websiteURL + "/faq") {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        // Support Form
                        SupportGlassCard {
                            VStack(spacing: 20) {
                                Text("Send us a message")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                // Category Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                    
                                    Picker("Category", selection: $category) {
                                        ForEach(SupportCategory.allCases, id: \.self) { cat in
                                            HStack {
                                                Image(systemName: cat.icon)
                                                Text(cat.rawValue)
                                            }
                                            .tag(cat)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundStyle(.white)
                                }
                                
                                // Name Field
                                SupportTextField(
                                    title: "Your Name",
                                    text: $name,
                                    icon: "person",
                                    submitLabel: .next
                                )
                                
                                // Email Field
                                SupportTextField(
                                    title: "Your Email",
                                    text: $email,
                                    icon: "envelope",
                                    keyboardType: .emailAddress,
                                    submitLabel: .next
                                )
                                
                                // Subject Field
                                SupportTextField(
                                    title: "Subject",
                                    text: $subject,
                                    icon: "text.quote",
                                    submitLabel: .next
                                )
                                
                                // Message Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Message")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                    
                                    TextEditor(text: $message)
                                        .frame(height: 120)
                                        .padding(12)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)
                                        .foregroundStyle(.white)
                                        .toolbar {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Spacer()
                                                Button("Done") {
                                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                                }
                                            }
                                        }
                                }
                                
                                // Submit Button
                                Button(action: submitSupportRequest) {
                                    HStack {
                                        Image(systemName: "paperplane.fill")
                                        Text("Send Message")
                                    }
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Color.luxuryPurple, Color.luxuryPink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                                }
                                .disabled(name.isEmpty || email.isEmpty || message.isEmpty)
                                .opacity(name.isEmpty || email.isEmpty || message.isEmpty ? 0.6 : 1)
                            }
                            .padding()
                        }
                        
                        // Support Info
                        VStack(spacing: 8) {
                            Text("Support Email:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text(AppConfig.supportEmail)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.luxuryGold)
                            
                            Text("Response time: \(AppConfig.averageResponseTime)")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Message Sent!", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("We'll get back to you at \(email) within 24 hours.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { showErrorAlert = false }
            } message: {
                Text("Please make sure you have an email app installed on your device.")
            }
        }
    }
    
    private func submitSupportRequest() {
        let support = SupportEmailContact.supportRequest(
            userEmail: email,
            issue: "[\(category.rawValue)] \(subject)\n\nFrom: \(name)\n\n\(message)"
        )
        
        if let url = support.mailtoURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            showSuccessAlert = true
        } else {
            showErrorAlert = true
        }
    }
}

struct SupportContactButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct SupportTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.luxuryGold)
                    .frame(width: 24)

                TextField("", text: $text)
                    .foregroundStyle(.white)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .submitLabel(submitLabel)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct SupportGlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}

struct SupportView_Previews: PreviewProvider {
    static var previews: some View {
        SupportView()
    }
}
