import SwiftUI

/// One screen to give several subscriptions their renewal dates. Subscriptions added from the
/// first-run tally arrive without one, and without a date Pausely can't remind anyone of anything.
struct RenewalDatesSheet: View {
    let subscriptions: [Subscription]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var dates: [UUID: Date] = [:]
    @State private var isSaving = false
    @State private var showingScreenshotImport = false
    @State private var axPickingFor: Subscription?

    private var headingText: String {
        if subscriptions.count == 1 {
            return subscriptions[0].status == .trial
                ? L10n.string("When does \(subscriptions[0].name)'s free trial end?")
                : L10n.string("When does \(subscriptions[0].name) charge you?")
        }
        return L10n.string("When do they charge you?")
    }

    var body: some View {
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton("Not now") { dismiss() }
                    Spacer()
                }

                Text(verbatim: headingText)
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
                    .padding(.bottom, 14)

                VStack(spacing: 0) {
                    Hairline()
                    Button {
                        Feel.selection()
                        showingScreenshotImport = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fill dates from a screenshot")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.inkText)
                                    .multilineTextAlignment(.leading)
                                Text("Reads Apple Subscriptions or a bank screen on this iPhone")
                                    .font(.footnote)
                                    .foregroundStyle(Color.inkTextMuted)
                                    .multilineTextAlignment(.leading)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            RowChevron()
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("datesFromScreenshotButton")
                    Hairline()
                }
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
                     : dates.isEmpty
                        ? (subscriptions.count == 1 ? L10n.string("Save date") : L10n.string("Save dates"))
                        : (dates.count == 1 ? L10n.string("Save 1 date") : L10n.string("Save \(dates.count) dates")))
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
        .sheet(isPresented: $showingScreenshotImport) {
            ScreenshotImportView(onFinished: { dismiss() })
        }
        .sheet(item: $axPickingFor) { sub in
            let selection = Binding(get: { dates[sub.id] ?? Date() }, set: { dates[sub.id] = $0 })
            NavigationStack {
                ScrollView {
                    DatePicker(sub.status == .trial ? L10n.string("Trial ends") : L10n.string("Next renewal"),
                               selection: selection, in: Calendar.billing.startOfDay(for: Date())...,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, L10n.locale)
                        .tint(Color.inkText)
                        .padding(Layout.margin)
                }
                .readableScroll()
                .background(Color.ink.ignoresSafeArea())
                .navigationTitle(sub.status == .trial ? L10n.string("Trial ends") : L10n.string("Next renewal"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear") {
                            dates.removeValue(forKey: sub.id)
                            axPickingFor = nil
                        }
                        .foregroundStyle(Color.inkTextMuted)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { axPickingFor = nil }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.inkText)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func row(_ subscription: Subscription) -> some View {
        // Side by side, or the date under the name at the accessibility sizes: beside the button the
        // name had a third of the row ("Net-flix") and the price broke inside its number.
        SideBySide(alignment: .center) {
            MarkedWords(alignment: .center, spacing: 12) {
                ServiceLogoView(name: subscription.name, category: subscription.category, size: 40)
            } words: {
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
                if typeSize.isAccessibilitySize {
                    Button { axPickingFor = subscription } label: {
                        Text(verbatim: DayText.fullDate(date, locale: L10n.locale))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .tapArea(.leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "\(subscription.name), \(DayText.fullDate(date, locale: L10n.locale))"))
                    .accessibilityIdentifier("datePicker-\(subscription.name)")
                } else {
                    HStack(spacing: 4) {
                        DatePicker(subscription.status == .trial ? L10n.string("Trial ends") : L10n.string("Next renewal"),
                                   selection: Binding(get: { date }, set: { dates[subscription.id] = $0 }),
                                   in: Calendar.billing.startOfDay(for: Date())..., displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, L10n.locale)
                            .tint(Color.inkText)
                            .accessibilityIdentifier("datePicker-\(subscription.name)")
                        Button {
                            Feel.selection()
                            dates.removeValue(forKey: subscription.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(Color.inkTextFaint)
                                .tapArea()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "\(L10n.string("Clear")), \(subscription.name)"))
                    }
                }
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

    /// Saves each chosen date onto the latest stored subscription. Trials write `trialEndsAt`
    /// (clearing any stale `nextBillingDate`) so reminders and verdicts target the trial end.
    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        for subscription in subscriptions {
            guard let date = dates[subscription.id] else { continue }
            var updated = store.subscriptions.first(where: { $0.id == subscription.id }) ?? subscription
            let noon = Calendar.billing.noon(of: date)
            if updated.status == .trial {
                updated.trialEndsAt = noon
                updated.nextBillingDate = nil
            } else {
                updated.nextBillingDate = noon
            }
            await store.updateSubscription(updated)
        }
        Feel.landed()
        dismiss()
    }
}
