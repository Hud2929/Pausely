import SwiftUI

struct SupportSection: View {
    let subscription: Subscription
    @ObservedObject var actionManager: SubscriptionActionManager

    var body: some View {
        VStack(spacing: 16) {
            Text("Need Help?")
                .font(.title2.bold())
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            let contacts = actionManager.getSupportContacts(for: subscription)
            let phoneContact = contacts.first { $0.type == .phone }
            let chatContact = contacts.first { $0.type == .chat || $0.type == .email }

            if let phone = phoneContact {
                SupportButton(
                    title: "Call Support",
                    subtitle: phone.value,
                    icon: "phone.fill",
                    color: .green
                )
            }

            if let chat = chatContact {
                SupportButton(
                    title: "Contact Support",
                    subtitle: chat.label,
                    icon: "globe",
                    color: .blue
                )
            }
        }
    }
}
