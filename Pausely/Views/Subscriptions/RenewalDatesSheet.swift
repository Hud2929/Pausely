import SwiftUI

/// One screen to give several subscriptions their renewal dates. Subscriptions added from the
/// first-run tally arrive without one, and without a date Pausely can't remind anyone of anything.
struct RenewalDatesSheet: View {
    let subscriptions: [Subscription]

    @Environment(\.dismiss) private var dismiss
    @State private var dates: [UUID: Date] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Text("Not now")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inkTextMuted)
                                .frame(minHeight: Layout.tapTarget)
                                .contentShape(Rectangle())
                        }
                        Spacer()
                    }

                    Text("When do they charge you?")
                        .font(.question(.title))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .accessibilityAddTraits(.isHeader)

                    Text("Pausely asks you before each of these days whether to keep it. Your bank statement or the service's account page shows the date. Skip any you don't know.")
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
            }

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
            .background(Color.ink)
        }
        .background(Color.ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .errorBanner($errorMessage)
    }

    private func row(_ subscription: Subscription) -> some View {
        HStack(spacing: 12) {
            ServiceLogoView(name: subscription.name, category: subscription.category, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: subscription.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.inkText)
                Text(verbatim: subscription.chargeText + subscription.billingFrequency.shortDisplay)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
            }
            Spacer(minLength: 8)
            if let date = dates[subscription.id] {
                DatePicker(L10n.string("Next payment"),
                           selection: Binding(get: { date }, set: { dates[subscription.id] = $0 }),
                           in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(Color.inkText)
                    .accessibilityIdentifier("datePicker-\(subscription.name)")
            } else {
                Button {
                    Feel.selection()
                    // Start a month out: the most likely place for a monthly charge, and never in the past.
                    dates[subscription.id] = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
                } label: {
                    Text("Add date")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 34)
                        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        .frame(minHeight: Layout.tapTarget)
                        .contentShape(Rectangle())
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
        var failed = 0
        for subscription in subscriptions {
            guard let date = dates[subscription.id] else { continue }
            var updated = subscription
            updated.nextBillingDate = Calendar.current.noon(of: date)
            do { try await SubscriptionStore.shared.updateSubscription(updated) } catch { failed += 1 }
        }
        if failed == 0 {
            Feel.landed()
            dismiss()
        } else {
            errorMessage = L10n.string("Some dates couldn't be saved. Try again.")
        }
    }
}
