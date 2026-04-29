import SwiftUI

struct NameStepView: View {
    @Binding var name: String
    @Binding var selectedCategory: NeuralSubscriptionCategory

    let categories: [(NeuralSubscriptionCategory, String, String)] = [
        (.entertainment, "film.fill", "Entertainment"),
        (.lifestyle, "heart.fill", "Lifestyle"),
        (.essential, "checkmark.shield.fill", "Essential"),
        (.utility, "bolt.fill", "Utility"),
        (.luxury, "crown.fill", "Luxury")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("What's the subscription?")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)

                    Text("Enter the name of the service you're subscribing to")
                        .font(.body)
                        .foregroundColor(TextColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Name input
                PremiumTextField(placeholder: "e.g. Netflix, Spotify", text: $name)
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("serviceNameTextField")

                // Category selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Category")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                        ForEach(categories, id: \.0) { category, icon, label in
                            SubscriptionCategoryButton(
                                icon: icon,
                                label: label,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
        }
    }
}
