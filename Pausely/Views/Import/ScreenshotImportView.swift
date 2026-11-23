import PhotosUI
import SwiftUI

/// On-device screenshot import: pick one or more screenshots of Apple *Settings › Subscriptions*
/// or a bank's recurring charges, review what Vision read on-device, and add selected items.
struct ScreenshotImportView: View {
    var onFinished: (() -> Void)? = nil
    #if DEBUG
    var startWithDemoResults: Bool = false
    #endif

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var payments = PaymentManager.shared

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var phase: Phase = .ready
    @State private var detected: [ScreenshotParser.DetectedItem] = []
    @State private var selectedIDs: Set<String> = []
    @State private var editingPrice: ScreenshotParser.DetectedItem?
    @State private var outcome: TallyImporter.Outcome?
    @State private var showingPaywall = false
    @State private var showingManualAdd = false
    @State private var showingFreePicker = false
    @State private var isAdding = false

    private enum Phase {
        case ready
        case reading(count: Int)
        case review
        case nothingFound
    }

    private var canBatchImport: Bool { payments.isUnlocked(.unlimitedSubscriptions) }
    private var maxPhotos: Int { canBatchImport ? 10 : 1 }

    private var activeDetected: [ScreenshotParser.DetectedItem] {
        detected.filter { !$0.isCancelled }
    }

    private var inactiveDetected: [ScreenshotParser.DetectedItem] {
        detected.filter(\.isCancelled)
    }

    private var chosenItems: [ScreenshotParser.DetectedItem] {
        activeDetected.filter { selectedIDs.contains($0.id) && $0.amount != nil }
    }

    var body: some View {
        ActionScreen {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LeaveButton("Close") { dismiss() }
                        .accessibilityIdentifier("screenshotImportClose")
                    Spacer()
                }

                if let outcome {
                    outcomeContent(outcome)
                } else {
                    switch phase {
                    case .ready:
                        readyContent
                    case .reading(let count):
                        readingContent(count: count)
                    case .review:
                        reviewContent
                    case .nothingFound:
                        nothingFoundContent
                    }
                }
            }
            .padding(.horizontal, Layout.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        } actions: {
            actionButtons
                .padding(.horizontal, Layout.margin)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .inkScreen()
        .presentationSizing(.page)
        .preferredColorScheme(.dark)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await process(items) }
        }
        .onAppear {
            #if DEBUG
            if startWithDemoResults, detected.isEmpty {
                loadDemoResults()
            }
            #endif
        }
        .sheet(item: $editingPrice) { item in
            PriceSheet(name: item.name, placeholder: item.amount, currency: item.currency) { amount in
                updateAmount(amount, for: item.id)
            }
        }
        .sheet(isPresented: $showingPaywall) { StoreKitUpgradeView() }
        .sheet(isPresented: $showingManualAdd) { AddSubscriptionView() }
        .sheet(isPresented: $showingFreePicker) { freePickerSheet }
    }

    // MARK: - Ready

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Import from screenshots")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            Text("Take a screenshot of Apple Subscriptions or your bank's recurring charges. Pausely reads it on this iPhone and never uploads the image.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            PaperSlip(tornTop: true, tornBottom: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How it works")
                        .font(.subheadline.weight(.semibold))
                    stepLine(1, L10n.string("Open Apple Subscriptions or your bank's recurring charges."))
                    stepLine(2, L10n.string("Take one or more screenshots of your active list."))
                    stepLine(3, L10n.string("Pick the screenshots here to review and add them in seconds."))
                    Perforation().padding(.vertical, 2)
                    Text("100% on-device. Photos are read in memory and never saved or sent anywhere.")
                        .font(.footnote)
                        .foregroundStyle(Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 24)

            if !canBatchImport {
                Text("Free imports one screenshot at a time. Pausely Pro reads up to 10 screenshots in one batch.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
            }
        }
    }

    private func stepLine(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: L10n.number(number))
                .font(.proof(.footnote, weight: .bold))
            Text(verbatim: text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Reading

    private func readingContent(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(count == 1 ? L10n.string("Reading your screenshot…")
                            : L10n.string("Reading \(count) screenshots…"))
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                ProgressView().tint(Color.inkTextMuted)
                Text("Recognizing services, prices, and renewal dates on this iPhone.")
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Review

    private var reviewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(activeDetected.count == 1
                 ? L10n.string("Found 1 subscription")
                 : L10n.string("Found \(activeDetected.count) subscriptions"))
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            Text("Tap a row to select or unselect. Tap a missing price to enter it.")
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            if !activeDetected.isEmpty {
                PaperSlip(tornTop: true, tornBottom: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(activeDetected.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Perforation().padding(.vertical, 8) }
                            detectedRow(item)
                        }
                    }
                }
                .padding(.top, 20)
            }

            if !inactiveDetected.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expired or cancelled")
                        .font(.headline)
                        .foregroundStyle(Color.inkText)
                        .padding(.top, 24)
                        .accessibilityAddTraits(.isHeader)
                    Text("Left out of your active list automatically.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(inactiveDetected.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Hairline() }
                        inactiveRow(item)
                    }
                }
            }
        }
    }

    private func detectedRow(_ item: ScreenshotParser.DetectedItem) -> some View {
        let onList = existingSubscription(for: item) != nil
        let fillsDate = existingSubscription(for: item)?.nextBillingDate == nil && item.renewalDate != nil
        let isOn = selectedIDs.contains(item.id)

        return Button {
            if item.amount == nil {
                editingPrice = item
            } else {
                toggle(item.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.paperInk : Color.paperMuted)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    LineOrStack(spacing: 8, lineSpacing: 2, spread: true, besideShare: 0.45) {
                        Text(verbatim: item.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.paperInk)
                            .multilineTextAlignment(.leading)
                        if let amount = item.amount {
                            Text(verbatim: item.frequency.pricedShort(MoneyFormat.string(amount, item.currency, locale: L10n.locale)))
                                .font(.proof(.subheadline, weight: .bold))
                                .foregroundStyle(Color.paperInk)
                        } else {
                            Text("Add price")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.paperDue)
                                .underline()
                        }
                    }

                    if let detail = detailLine(for: item, onList: onList, fillsDate: fillsDate) {
                        Facts(detail)
                            .font(.footnote)
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier("screenshotRow_\(item.name)")
    }

    private func inactiveRow(_ item: ScreenshotParser.DetectedItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: item.name)
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .strikethrough(true, color: Color.inkTextFaint)
            if let amount = item.amount {
                Text(verbatim: item.frequency.pricedShort(MoneyFormat.string(amount, item.currency, locale: L10n.locale)))
                    .font(.footnote)
                    .foregroundStyle(Color.inkTextFaint)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Nothing Found

    private var nothingFoundContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No subscriptions found in that image.")
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            Text("Try a screenshot of Apple Settings › Subscriptions or a bank screen showing service names and prices.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Outcome

    private func outcomeContent(_ result: TallyImporter.Outcome) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(result.added.isEmpty && !result.datesFilled.isEmpty
                 ? L10n.string("Renewal dates updated")
                 : L10n.string("Added to your list"))
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            PaperSlip(tornTop: true, tornBottom: true) {
                VStack(alignment: .leading, spacing: 10) {
                    if !result.added.isEmpty {
                        ProofLine(label: L10n.string("Added"), value: L10n.number(result.added.count), emphasised: true)
                        Text(verbatim: result.added.joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !result.datesFilled.isEmpty {
                        if !result.added.isEmpty { Perforation() }
                        ProofLine(label: L10n.string("Renewal dates added"), value: L10n.number(result.datesFilled.count))
                    }
                    if !result.waiting.isEmpty {
                        Perforation()
                        ProofLine(label: L10n.string("Waiting for room"), value: L10n.number(result.waiting.count))
                        Text(L10n.string("Home shows the rest so you can choose which \(FreeTier.subscriptionLimit) to track or go Pro."))
                            .font(.footnote)
                            .foregroundStyle(Color.paperMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        if let outcome {
            VStack(spacing: 10) {
                if !outcome.waiting.isEmpty, !payments.isUnlocked(.unlimitedSubscriptions) {
                    Button { showingPaywall = true } label: { Text("Track all with Pro") }
                        .buttonStyle(.ink)
                }
                Button {
                    if let onFinished { onFinished() } else { dismiss() }
                } label: {
                    Text("Done")
                }
                .buttonStyle(.ink(outcome.waiting.isEmpty ? .main : .quiet))
                .accessibilityIdentifier("screenshotDoneButton")
            }
        } else {
            switch phase {
            case .ready:
                VStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos, matching: .images) {
                        Text(canBatchImport ? L10n.string("Choose screenshots") : L10n.string("Choose a screenshot"))
                    }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("chooseScreenshotsButton")

                    Button {
                        if let url = CancelHelp.applesSubscriptions { openURL(url) }
                    } label: {
                        Text("Open Apple subscriptions")
                    }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("openAppleSubscriptionsButton")
                }
            case .reading:
                EmptyView()
            case .review:
                VStack(spacing: 10) {
                    Button {
                        handleAddTapped()
                    } label: {
                        Text(isAdding ? L10n.string("Adding…")
                                      : L10n.string("Add \(chosenItems.count) to my list"))
                    }
                    .buttonStyle(.ink)
                    .disabled(chosenItems.isEmpty || isAdding)
                    .accessibilityIdentifier("confirmScreenshotImportButton")

                    PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos, matching: .images) {
                        Text("Scan more screenshots")
                    }
                    .buttonStyle(.ink(.quiet))
                }
            case .nothingFound:
                VStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos, matching: .images) {
                        Text("Try another screenshot")
                    }
                    .buttonStyle(.ink)

                    Button { showingManualAdd = true } label: { Text("Add your own") }
                        .buttonStyle(.ink(.quiet))
                }
            }
        }
    }

    // MARK: - Helpers

    private func existingSubscription(for item: ScreenshotParser.DetectedItem) -> Subscription? {
        store.subscriptions.first { ServiceName.same($0.name, item.name) }
    }

    private func detailLine(for item: ScreenshotParser.DetectedItem, onList: Bool, fillsDate: Bool) -> String? {
        var parts: [String] = []
        if item.isTrial, let trial = item.trialEndsAt {
            parts.append(L10n.string("Trial ends \(L10n.day(trial))"))
        } else if let renewal = item.renewalDate {
            parts.append(L10n.string("Renews \(L10n.day(renewal))"))
        }
        if fillsDate {
            parts.append(L10n.string("Adds renewal date"))
        } else if onList {
            parts.append(L10n.string("Already on your list"))
        }
        return parts.isEmpty ? nil : L10n.breakingAfterDots(parts.joined(separator: " · "))
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            Feel.selection()
        } else {
            selectedIDs.insert(id)
            Feel.tick()
        }
    }

    private func updateAmount(_ amount: Decimal, for id: String) {
        guard let idx = detected.firstIndex(where: { $0.id == id }) else { return }
        detected[idx].amount = amount
        selectedIDs.insert(id)
    }

    private func process(_ items: [PhotosPickerItem]) async {
        phase = .reading(count: items.count)
        let currency = currencyManager.selectedCurrency
        var pages: [[ScreenshotParser.TextObservation]] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let observations = try? await ScreenshotOCR.recognizeText(in: image) {
                pages.append(observations)
            }
        }

        let parsed = ScreenshotParser.parse(pages: pages, defaultCurrency: currency)
        pickerItems = []

        if parsed.isEmpty {
            phase = .nothingFound
            return
        }

        // Merge with any earlier batch scanned in this sheet session.
        var combined = detected
        for item in parsed {
            if let idx = combined.firstIndex(where: { ServiceName.same($0.name, item.name) }) {
                if combined[idx].amount == nil { combined[idx].amount = item.amount }
                if combined[idx].renewalDate == nil { combined[idx].renewalDate = item.renewalDate }
                if combined[idx].trialEndsAt == nil { combined[idx].trialEndsAt = item.trialEndsAt }
            } else {
                combined.append(item)
            }
        }
        detected = combined
        selectedIDs = Set(combined.filter { item in
            guard !item.isCancelled, item.amount != nil else { return false }
            if let existing = existingSubscription(for: item) {
                return existing.nextBillingDate == nil && item.renewalDate != nil
            }
            return true
        }.map(\.id))
        phase = .review
        Feel.landed()
    }

    private func handleAddTapped() {
        let lines = chosenItems.compactMap { $0.tallyLine() }
        guard !lines.isEmpty else { return }
        let room = FreeTier.room(in: store.subscriptions)
        let newCount = lines.filter { line in
            !store.subscriptions.contains { ServiceName.same($0.name, line.name) }
        }.count
        if !payments.isUnlocked(.unlimitedSubscriptions), room > 0, newCount > room {
            showingFreePicker = true
            return
        }
        Task { await commitImport(lines: lines, preferredNames: []) }
    }

    private var freePickerSheet: some View {
        let display = currencyManager.selectedCurrency
        let rates = currencyManager.rates
        let lines = chosenItems.compactMap { $0.tallyLine() }.filter { line in
            !store.subscriptions.contains { ServiceName.same($0.name, line.name) }
        }
        return FreeLimitPickerSheet(
            candidates: lines.map { line in
                FreeLimitPickerSheet.Candidate(
                    name: line.name,
                    category: line.category,
                    amount: line.amount,
                    currency: line.currency,
                    frequency: line.frequency ?? .monthly,
                    yearlyInDisplay: rates.convert(line.yearlyCost, from: line.currency, to: display) ?? line.yearlyCost
                )
            },
            initialSelection: [],
            maxSelection: max(1, FreeTier.room(in: store.subscriptions)),
            onSave: { chosen in
                Task { await commitImport(lines: chosenItems.compactMap { $0.tallyLine() }, preferredNames: chosen) }
            },
            onSeePro: { showingPaywall = true }
        )
    }

    private func commitImport(lines: [TallyLine], preferredNames: Set<String>) async {
        isAdding = true
        defer { isAdding = false }
        let result = await TallyImporter.add(lines, into: store, payments: payments, preferredNames: preferredNames)
        Feel.landed()
        withAnimation(Motion.unlessReduced(Motion.arrive)) {
            outcome = result
        }
    }

    #if DEBUG
    private func loadDemoResults() {
        let cal = Calendar.billing
        let now = Date()
        let dec14 = cal.date(byAdding: .day, value: 14, to: now)
        let dec3 = cal.date(byAdding: .day, value: 5, to: now)
        let dec1 = cal.date(byAdding: .day, value: 9, to: now)
        let currency = currencyManager.selectedCurrency
        detected = [
            ScreenshotParser.DetectedItem(id: "netflix", name: "Netflix", category: "Entertainment",
                                          amount: Decimal(string: "19.99"), currency: currency,
                                          frequency: .monthly, renewalDate: dec14, trialEndsAt: nil, isCancelled: false),
            ScreenshotParser.DetectedItem(id: "duolingo", name: "Duolingo", category: "Education",
                                          amount: Decimal(string: "83.99"), currency: currency,
                                          frequency: .yearly, renewalDate: dec3, trialEndsAt: dec3, isCancelled: false),
            ScreenshotParser.DetectedItem(id: "icloud+", name: "iCloud+", category: "Cloud Storage",
                                          amount: Decimal(string: "2.99"), currency: currency,
                                          frequency: .monthly, renewalDate: dec1, trialEndsAt: nil, isCancelled: false),
            ScreenshotParser.DetectedItem(id: "hulu", name: "Hulu", category: "Entertainment",
                                          amount: Decimal(string: "18.99"), currency: currency,
                                          frequency: .monthly, renewalDate: nil, trialEndsAt: nil, isCancelled: true),
        ]
        selectedIDs = ["netflix", "duolingo", "icloud+"]
        phase = .review
    }
    #endif
}
