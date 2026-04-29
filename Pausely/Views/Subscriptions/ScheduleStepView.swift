import SwiftUI

struct ScheduleStepView: View {
    @Binding var nextRenewalDate: Date

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("When does it renew?")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)

                    Text("Select the next billing date for this subscription")
                        .font(.body)
                        .foregroundColor(TextColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Date picker card
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.largeTitle)
                        .foregroundColor(BrandColors.primary)

                    DatePicker(
                        "Next Renewal",
                        selection: $nextRenewalDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .colorMultiply(BrandColors.primary)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(BackgroundColors.secondary)
                    )
                }
                .padding(.horizontal, 20)

                // Quick options
                HStack(spacing: 12) {
                    QuickDateButton(title: "Today", days: 0) { nextRenewalDate = Date() }
                    QuickDateButton(title: "+7 Days", days: 7) { nextRenewalDate = Date().addingTimeInterval(7 * 24 * 60 * 60) }
                    QuickDateButton(title: "+30 Days", days: 30) { nextRenewalDate = Date().addingTimeInterval(30 * 24 * 60 * 60) }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
        }
    }
}
