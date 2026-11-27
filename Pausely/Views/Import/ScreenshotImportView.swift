import PhotosUI
import SwiftUI

/// On-device screenshot import: pick one or more screenshots of Apple *Settings › Subscriptions*
/// or a bank's recurring charges, review what Vision read on-device, and add selected items.
struct ScreenshotImportView: View {
    var onFinished: (() -> Void)? = nil
    /// When provided (e.g. during first run), returns selected lines directly to the caller instead
    /// of committing immediately into `SubscriptionStore`.
    var onPickForTally: (([TallyLine]) -> Void)? = nil
    #if DEBUG
    var startWithDemoResults: Bool = false
    #endif

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var payments = PaymentManager.shared

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var phase: Phase = .ready
    @State private var detected: [ScreenshotParser.DetectedItem] = []
    @State private var selectedIDs: Set<String> = []
    @State private var editingPrice: ScreenshotParser.DetectedItem?
    @State private var outcome: TallyImporter.Outcome?
    @State private var scanNote: String?
    @State private var paywallTrigger: ProFeature?
    @State private var showingManualAdd = false
    @State private var showingFreePicker = false
    @State private var pendingPaywallFromPicker = false
    @State private var isAdding = false
    @State private var scanTask: Task<Void, Never>?

    private enum Phase {
        case ready
        case reading(count: Int)
        case review
        case nothingFound
    }

    private var canBatchImport: Bool { payments.isUnlocked(.batchScreenshotImport) }
    private var maxPhotos: Int { canBatchImport ? ScreenshotImportReadyView.proBatch : 1 }

    private var activeDetected: [ScreenshotParser.DetectedItem] {
        detected.filter { !$0.isCancelled }
    }

    private var inactiveDetected: [ScreenshotParser.DetectedItem] {
        detected.filter(\.isCancelled)
    }

    private var chosenItems: [ScreenshotParser.DetectedItem] {
        activeDetected.filter { item in
            guard selectedIDs.contains(item.id), let amount = item.amount, amount > 0 else { return false }
            if onPickForTally == nil, let existing = existingSubscription(for: item) {
                return ScreenshotImportSupport.canFillDate(existing: existing, item: item)
                    || ScreenshotImportSupport.canUpdatePrice(existing: existing, item: item)
            }
            return true
        }
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
                    ScreenshotImportOutcomeView(result: outcome)
                } else {
                    switch phase {
                    case .ready:
                        ScreenshotImportReadyView(canBatchImport: canBatchImport, onSeeBatchPro: {
                            paywallTrigger = .batchScreenshotImport
                        })
                    case .reading(let count):
                        ScreenshotReadingView(count: count)
                    case .review:
                        reviewContent
                    case .nothingFound:
                        ScreenshotNothingFoundView(note: scanNote)
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
        // The outcome is a new page that starts at its title: at the largest text it opened scrolled to its
        // end, its heading out of sight (the reach rating of 2026-11-23).
        .id(outcome == nil ? "choosing" : "outcome")
        .inkScreen()
        .presentationSizing(.page)
        .preferredColorScheme(.dark)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            scanTask?.cancel()
            scanTask = Task { await process(items) }
        }
        .onDisappear {
            scanTask?.cancel()
            scanTask = nil
        }
        .onAppear {
            #if DEBUG
            if startWithDemoResults, detected.isEmpty {
                loadDemoResults()
            }
            #endif
        }
        .sheet(item: $editingPrice) { item in
            PriceSheet(name: item.name, placeholder: item.amount, currency: item.currency, frequency: item.frequency,
                       onSaveFrequency: { freq in updateFrequency(freq, for: item.id) }) { amount in
                updateAmount(amount, for: item.id)
            }
        }
        .sheet(item: $paywallTrigger) { trigger in
            StoreKitUpgradeView(context: ScreenshotImportSupport.paywallContext(
                trigger: trigger, chosenItems: chosenItems, existingCharging: store.subscriptions.charging,
                outcome: outcome, displayCurrency: currencyManager.selectedCurrency, rates: currencyManager.rates
            )) {
                if trigger == .unlimitedSubscriptions {
                    if let current = outcome {
                        outcome = ScreenshotImportSupport.promotedOutcome(current)
                    } else if !chosenItems.isEmpty {
                        let lines = chosenItems.compactMap { $0.tallyLine() }
                        Task { await commitImport(lines: lines, preferredNames: []) }
                    }
                }
            }
        }
        .sheet(isPresented: $showingManualAdd) { AddSubscriptionView() }
        .sheet(isPresented: $showingFreePicker, onDismiss: {
            if pendingPaywallFromPicker {
                pendingPaywallFromPicker = false
                paywallTrigger = .unlimitedSubscriptions
            }
        }) { freePickerSheet }
    }

    // MARK: - Review

    private var reviewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(activeDetected.isEmpty
                 ? L10n.string("No active subscriptions found")
                 : activeDetected.count == 1
                 ? L10n.string("Found 1 subscription")
                 : L10n.string("Found \(activeDetected.count) subscriptions"))
                .font(.question(.title))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            if !activeDetected.isEmpty {
                Text("Tap a row to select or unselect. Tap any price to edit it.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            if let scanNote {
                Text(verbatim: scanNote)
                    .font(.footnote)
                    .foregroundStyle(Color.decide)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }

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
                        ScreenshotInactiveRow(item: item)
                    }
                }
            }

            if !canBatchImport {
                Button {
                    Feel.selection()
                    paywallTrigger = .batchScreenshotImport
                } label: {
                    HStack(spacing: 10) {
                        LineOrStack(spacing: 8, lineSpacing: 4) {
                            Text("Import up to \(ScreenshotImportReadyView.proBatch) screenshots at once")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.inkText)
                                .multilineTextAlignment(.leading)
                            ProPill()
                        }
                        Spacer(minLength: 8)
                        RowChevron()
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("reviewBatchProButton")
                .padding(.top, 16)
            }
        }
    }

    private func detectedRow(_ item: ScreenshotParser.DetectedItem) -> some View {
        let existing = onPickForTally == nil ? existingSubscription(for: item) : nil
        let onList = existing != nil
        let fillsDate = existing.map { ScreenshotImportSupport.canFillDate(existing: $0, item: item) } ?? false
        let updatesPrice = existing.map { ScreenshotImportSupport.canUpdatePrice(existing: $0, item: item) } ?? false
        let keptForLater = isKeptForLater(item)
        let selectable = !onList || fillsDate || updatesPrice
        let isOn = selectable && selectedIDs.contains(item.id)

        return MarkedWords(alignment: .top, spacing: 12) {
            Image(systemName: selectable ? (isOn ? "checkmark.circle.fill" : "circle") : "checkmark.circle")
                .font(.title3)
                .foregroundStyle(isOn ? Color.paperInk : Color.paperMuted)
                .tapArea(.topLeading)
                .accessibilityHidden(true)
        } words: {
            VStack(alignment: .leading, spacing: 4) {
                LineOrStack(spacing: 8, lineSpacing: 4, spread: true, besideShare: 0.45) {
                    Text(verbatim: item.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(selectable ? Color.paperInk : Color.paperMuted)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        Feel.selection()
                        editingPrice = item
                    } label: {
                        Group {
                            if let amount = item.amount {
                                PricePerPeriod(
                                    amount: MoneyFormat.string(amount, item.currency, locale: L10n.locale),
                                    frequency: item.frequency,
                                    amountFont: .subheadline.weight(.bold).monospacedDigit(),
                                    periodFont: .footnote.weight(.medium),
                                    periodColor: .paperMuted
                                )
                                .foregroundStyle(Color.paperInk)
                                .underline(true, color: Color.paperInk.opacity(0.35))
                            } else {
                                Text("Add price")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.paperDue)
                                    .underline()
                            }
                        }
                        .tapArea(.trailing)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.amount != nil
                                        ? L10n.string("Edit price for \(item.name)")
                                        : L10n.string("Add price for \(item.name)"))
                }

                if let detail = ScreenshotImportSupport.detailLine(for: item, existing: existing, fillsDate: fillsDate,
                                                                   updatesPrice: updatesPrice, keptForLater: keptForLater) {
                    let isHike = updatesPrice && existing.map {
                        ScreenshotImportSupport.isPriceIncrease(existing: $0, item: item, rates: currencyManager.rates)
                    } == true
                    Facts(detail)
                        .font(.footnote)
                        .foregroundStyle(isHike ? Color.paperDue : Color.paperMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            guard selectable else { return }
            if item.amount == nil { editingPrice = item } else { toggle(item.id) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: ScreenshotImportSupport.rowSummary(
            item, existing: existing, fillsDate: fillsDate, updatesPrice: updatesPrice, keptForLater: keptForLater)))
        .accessibilityAddTraits(selectable ? (isOn ? [.isButton, .isSelected] : .isButton) : [])
        .accessibilityAction {
            guard selectable else { return }
            if item.amount == nil { editingPrice = item } else { toggle(item.id) }
        }
        .accessibilityAction(named: item.amount != nil ? Text("Edit price") : Text("Add price")) { editingPrice = item }
        .accessibilityIdentifier("screenshotRow_\(item.name)")
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        if let outcome {
            // Done is the main button, Pro the second: the end of an import pushed "Track all with Pro" as
            // the main action, where Find in Email makes Done the main one (the rating of 2026-11-23).
            VStack(spacing: 10) {
                Button {
                    if let onFinished { onFinished() } else { dismiss() }
                } label: {
                    Text("Done")
                }
                .buttonStyle(.ink)
                .accessibilityIdentifier("screenshotDoneButton")
                if !outcome.waiting.isEmpty, !payments.isUnlocked(.unlimitedSubscriptions) {
                    Button { paywallTrigger = .unlimitedSubscriptions } label: { Text("Track all with Pro") }
                        .buttonStyle(.ink(.quiet))
                }
            }
        } else {
            switch phase {
            case .ready:
                let batchTitle = canBatchImport ? L10n.string("Choose screenshots") : L10n.string("Choose a screenshot")
                VStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos, matching: .images) {
                        Text(verbatim: batchTitle)
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
                let scanTitle = canBatchImport ? L10n.string("Scan more screenshots") : L10n.string("Scan another screenshot")
                VStack(spacing: 10) {
                    if !activeDetected.isEmpty {
                        Button {
                            handleAddTapped()
                        } label: {
                            Text(verbatim: reviewPrimaryTitle)
                        }
                        .buttonStyle(.ink)
                        .disabled(chosenItems.isEmpty || isAdding)
                        .accessibilityIdentifier("confirmScreenshotImportButton")

                        PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos, matching: .images) {
                            Text(verbatim: scanTitle)
                        }
                        .buttonStyle(.ink(.quiet))
                        .disabled(isAdding)
                    } else {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos, matching: .images) {
                            Text(verbatim: scanTitle)
                        }
                        .buttonStyle(.ink)
                        .disabled(isAdding)
                    }
                }
            case .nothingFound:
                VStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos, matching: .images) {
                        Text("Try another screenshot")
                    }
                    .buttonStyle(.ink)

                    if onPickForTally != nil {
                        Button { dismiss() } label: { Text("Back to list") }
                            .buttonStyle(.ink(.quiet))
                    } else {
                        Button { showingManualAdd = true } label: { Text("Add your own") }
                            .buttonStyle(.ink(.quiet))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func existingSubscription(for item: ScreenshotParser.DetectedItem) -> Subscription? {
        store.subscriptions.charging.first { ServiceName.same($0.name, item.name) }
    }

    /// Kept for later from an earlier add: known already, so not chosen again (its price was overwritten by each
    /// import, the rating of 2026-11-23).
    private func isKeptForLater(_ item: ScreenshotParser.DetectedItem) -> Bool {
        TallyImporter.waitingLines().contains { ServiceName.same($0.name, item.name) }
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
        guard amount > 0, let idx = detected.firstIndex(where: { $0.id == id }) else { return }
        detected[idx].amount = amount
        selectedIDs.insert(id)
    }

    private func updateFrequency(_ frequency: BillingFrequency, for id: String) {
        guard let idx = detected.firstIndex(where: { $0.id == id }) else { return }
        detected[idx].frequency = frequency
    }

    private var reviewPrimaryTitle: String {
        ScreenshotImportSupport.reviewPrimaryTitle(
            isAdding: isAdding, isForTally: onPickForTally != nil,
            chosen: chosenItems, existingFor: existingSubscription(for:)
        )
    }

    private func process(_ items: [PhotosPickerItem]) async {
        phase = .reading(count: items.count)
        scanNote = nil
        let currency = currencyManager.selectedCurrency
        var pages: [[ScreenshotParser.TextObservation]] = []
        var failedCount = 0

        for item in items {
            if Task.isCancelled { return }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    failedCount += 1
                    continue
                }
                let observations = try await ScreenshotOCR.recognizeText(in: data)
                pages.append(observations)
            } catch is CancellationError {
                return
            } catch {
                failedCount += 1
            }
        }
        if Task.isCancelled { return }

        let parsed = ScreenshotParser.parse(pages: pages, defaultCurrency: currency, rates: currencyManager.rates)
        pickerItems = []
        let failureNote = ScreenshotImportSupport.unreadableNote(failed: failedCount, total: items.count)

        if parsed.isEmpty {
            if detected.isEmpty {
                scanNote = failureNote
                phase = .nothingFound
            } else {
                scanNote = failureNote ?? (items.count == 1
                    ? L10n.string("No more subscriptions found in that screenshot.")
                    : L10n.string("No more subscriptions found in those screenshots."))
                phase = .review
            }
            return
        }

        // Merge with any earlier batch scanned in this sheet session without losing user edits or ticks.
        var combined = detected
        let addedIDs = ScreenshotParser.mergeBatch(parsed, into: &combined, defaultCurrency: currency, rates: currencyManager.rates)
        detected = combined
        for item in combined where addedIDs.contains(item.id) {
            guard !item.isCancelled, let amount = item.amount, amount > 0,
                  item.doubt != .mayNotRepeat, item.doubt != .aBill,
                  !isKeptForLater(item) else { continue }
            if onPickForTally == nil, let existing = existingSubscription(for: item) {
                if ScreenshotImportSupport.canFillDate(existing: existing, item: item)
                    || ScreenshotImportSupport.canUpdatePrice(existing: existing, item: item) {
                    selectedIDs.insert(item.id)
                }
            } else {
                selectedIDs.insert(item.id)
            }
        }
        scanNote = failureNote
        phase = .review
        Feel.landed()
    }

    private func handleAddTapped() {
        let lines = chosenItems.compactMap { $0.tallyLine() }
        guard !lines.isEmpty else { return }
        if let onPickForTally {
            Feel.landed()
            onPickForTally(lines)
            dismiss()
            return
        }
        let room = FreeTier.room(in: store.subscriptions)
        let newCount = lines.filter { line in
            !store.subscriptions.charging.contains { ServiceName.same($0.name, line.name) }
        }.count
        if !payments.isUnlocked(.unlimitedSubscriptions), newCount > room {
            showingFreePicker = true
            return
        }
        Task { await commitImport(lines: lines, preferredNames: []) }
    }

    private var freePickerSheet: some View {
        let display = currencyManager.selectedCurrency
        let rates = currencyManager.rates
        let room = FreeTier.room(in: store.subscriptions)
        let newLines = chosenItems.compactMap { $0.tallyLine() }.filter { line in
            !store.subscriptions.charging.contains { ServiceName.same($0.name, line.name) }
        }
        if room == 0 {
            let activeCandidates = store.subscriptions.charging.map { sub in
                FreeLimitPickerSheet.Candidate(
                    name: sub.name, category: sub.category ?? SubscriptionCategory.other.rawValue,
                    amount: sub.amount, currency: sub.currency, frequency: sub.billingFrequency,
                    yearlyInDisplay: rates.convert(sub.annualCost, from: sub.currency, to: display)
                )
            }
            let newCandidates = newLines.map { line in
                FreeLimitPickerSheet.Candidate(
                    name: line.name, category: line.category, amount: line.amount, currency: line.currency,
                    frequency: line.frequency ?? .monthly,
                    yearlyInDisplay: rates.convert(line.yearlyCost, from: line.currency, to: display)
                )
            }
            let existingWaiting = TallyImporter.waitingLines().map { line in
                FreeLimitPickerSheet.Candidate(
                    name: line.name, category: line.category, amount: line.amount, currency: line.currency,
                    frequency: line.frequency ?? .monthly,
                    yearlyInDisplay: rates.convert(line.yearlyCost, from: line.currency, to: display)
                )
            }
            return FreeLimitPickerSheet(
                candidates: activeCandidates + newCandidates + existingWaiting,
                initialSelection: Set(store.subscriptions.charging.map(\.name)),
                maxSelection: FreeTier.room(in: []),
                displayCurrency: display,
                onSave: { chosen in
                    Task { await commitSwapImport(lines: chosenItems.compactMap { $0.tallyLine() }, chosenActiveNames: chosen) }
                },
                onSeePro: { pendingPaywallFromPicker = true }
            )
        }
        return FreeLimitPickerSheet(
            candidates: newLines.map { line in
                FreeLimitPickerSheet.Candidate(
                    name: line.name, category: line.category, amount: line.amount, currency: line.currency,
                    frequency: line.frequency ?? .monthly,
                    yearlyInDisplay: rates.convert(line.yearlyCost, from: line.currency, to: display)
                )
            },
            initialSelection: [],
            maxSelection: max(1, room),
            displayCurrency: display,
            onSave: { chosen in
                Task { await commitImport(lines: chosenItems.compactMap { $0.tallyLine() }, preferredNames: chosen) }
            },
            onSeePro: { pendingPaywallFromPicker = true }
        )
    }

    private func commitSwapImport(lines: [TallyLine], chosenActiveNames: Set<String>) async {
        isAdding = true
        defer { isAdding = false }
        let beforeNames = Set(store.subscriptions.charging.map { $0.name.lowercased() })
        let initial = await TallyImporter.add(lines, into: store, payments: payments, updatePriceChanges: true)
        await TallyImporter.applyChoice(selectedNames: chosenActiveNames, into: store, payments: payments)
        let afterActive = store.subscriptions.charging
        let added = afterActive.filter { !beforeNames.contains($0.name.lowercased()) }.map(\.name)
        let waiting = TallyImporter.waitingLines().map(\.name)
        Feel.landed()
        withAnimation(Motion.unlessReduced(Motion.arrive)) {
            outcome = TallyImporter.Outcome(added: added, waiting: waiting,
                                            alreadyListed: initial.alreadyListed,
                                            datesFilled: initial.datesFilled,
                                            pricesUpdated: initial.pricesUpdated)
        }
    }

    private func commitImport(lines: [TallyLine], preferredNames: Set<String>) async {
        isAdding = true
        defer { isAdding = false }
        let result = await TallyImporter.add(lines, into: store, payments: payments,
                                             preferredNames: preferredNames, updatePriceChanges: true)
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
            ScreenshotParser.DetectedItem(id: "paramount+", name: "Paramount+", category: "Entertainment",
                                          amount: Decimal(string: "12.99"), currency: currency,
                                          frequency: .monthly, renewalDate: dec14, trialEndsAt: nil, isCancelled: false, paymentMethod: "Apple"),
            ScreenshotParser.DetectedItem(id: "headspace", name: "Headspace", category: "Health & Fitness",
                                          amount: Decimal(string: "69.99"), currency: currency,
                                          frequency: .yearly, renewalDate: dec3, trialEndsAt: dec3, isCancelled: false, paymentMethod: "Apple"),
            ScreenshotParser.DetectedItem(id: "dropbox", name: "Dropbox", category: "Cloud Storage",
                                          amount: Decimal(string: "11.99"), currency: currency,
                                          frequency: .monthly, renewalDate: dec1, trialEndsAt: nil, isCancelled: false, paymentMethod: "Apple"),
            ScreenshotParser.DetectedItem(id: "hulu", name: "Hulu", category: "Entertainment",
                                          amount: Decimal(string: "18.99"), currency: currency,
                                          frequency: .monthly, renewalDate: nil, trialEndsAt: nil, isCancelled: true, paymentMethod: "Apple"),
        ]
        selectedIDs = ["paramount+", "headspace", "dropbox"]
        phase = .review
    }
    #endif
}
