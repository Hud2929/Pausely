import SwiftUI

/// One screen to give several subscriptions their renewal dates. Subscriptions added from the
/// first-run tally arrive without one, and without a date Pausely can't remind anyone of anything.
struct RenewalDatesSheet: View {
    let subscriptions: [Subscription]

    @Environment(\.dismiss) private var dismiss
    @State private var dates: [UUID: Date] = [:]
    @State private var isSaving = false

    var body: some View {
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton("Not now") { dismiss() }
                    Spacer()
                }

                Text(subscriptions.count == 1 ? L10n.string("When does \(subscriptions[0].name) charge you?")
                                              : L10n.string("When do they charge you?"))
                    .font(.question(.title))
                    .foregroundStyle(Color.inkText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)

                Text(subscriptions.count == 1
                     ? L10n.string("Pausely asks you before that day whether to keep it. Your bank statement or the service's account page shows the date.")
                     : L10n.string("Pausely asks you before each of these days whether to keep it. Your bank statement or the service's account page shows the date. Skip any you don't know."))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, subscription in
                    if index > 0 { Hairline() }
                    row(subscription)
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 16)
        } actions: {
            Button { Task { await save() } } label: {
                Text(isSaving ? L10n.string("Saving…")
                     : dates.isEmpty ? L10n.string("Save dates") : L10n.string("Save \(dates.count) dates"))
            }
            .buttonStyle(.ink)
            .disabled(dates.isEmpty || isSaving)
            .accessibilityIdentifier("saveDatesButton")
            .padding(.horizontal, Layout.margin)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .inkScreen()
        .preferredColorScheme(.dark)
    }

    private func row(_ subscription: Subscription) -> some View {
        // Side by side, or the date under the name at the accessibility sizes: beside the button the
        // name had a third of the row ("Net-flix") and the price broke inside its number.
        SideBySide(alignment: .center) {
            HStack(spacing: 12) {
                ServiceLogoView(name: subscription.name, category: subscription.category, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: subscription.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: subscription.billingFrequency.pricedShort(subscription.chargeText))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                        // "$54.99/mo" is read out as "$54.99 a month".
                        .accessibilityLabel(Text(verbatim: subscription.billingFrequency.priced(subscription.chargeText)))
                }
            }
        } trailing: {
            if let date = dates[subscription.id] {
                DatePicker(L10n.string("Next renewal"),
                           selection: Binding(get: { date }, set: { dates[subscription.id] = $0 }),
                           in: Calendar.billing.startOfDay(for: Date())..., displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, L10n.locale)
                    .tint(Color.inkText)
                    .accessibilityIdentifier("datePicker-\(subscription.name)")
            } else {
                Button {
                    Feel.selection()
                    // The picker opens on today, as "Set date" does everywhere else. It used to open two
                    // weeks out: a plausible-looking guess that could be saved without anyone choosing it.
                    dates[subscription.id] = Date()
                } label: {
                    Text("Add date")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 34)
                        .overlay(Capsule().stroke(Color.outline, lineWidth: 1))
                        .tapArea()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n.string("Add date") + ", " + subscription.name))
                .accessibilityIdentifier("addDate-\(subscription.name)")
            }
        }
        .padding(.vertical, 10)
    }

    /// Saves each chosen date as the subscription's billing anchor. The store reschedules reminders.
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        for subscription in subscriptions {
            guard let date = dates[subscription.id] else { continue }
            var updated = subscription
            updated.nextBillingDate = Calendar.billing.noon(of: date)
            await SubscriptionStore.shared.updateSubscription(updated)
        }
        Feel.landed()
        dismiss()
    }
}
