//
//  SubscriptionSharingView.swift
//  Pausely
//
//  Split subscription costs with friends, family, roommates
//

import SwiftUI

struct SubscriptionSharingView: View {
    let subscription: Subscription
    @ObservedObject private var sharingManager = SubscriptionSharingManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddParticipant = false
    @State private var newParticipantName = ""
    @State private var newParticipantShare: Double = 0.5
    @State private var showingResetConfirm = false

    var record: SubscriptionShareRecord? {
        sharingManager.record(for: subscription.id)
    }

    var yourShareAmount: Decimal {
        guard let record = record, let you = record.participants.first else { return subscription.amount }
        return subscription.amount * Decimal(you.sharePercentage)
    }

    var yourMonthlySavings: Decimal {
        subscription.monthlyCost - (subscription.monthlyCost * Decimal(record?.participants.first?.sharePercentage ?? 1.0))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let record = record {
                        // Your share card
                        shareSummaryCard

                        // Participants list
                        participantsSection(record: record)

                        // Payment status
                        paymentStatusSection(record: record)

                        // Savings insight
                        if yourMonthlySavings > 0 {
                            savingsInsightCard
                        }
                    } else {
                        // Empty state
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle("Cost Sharing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if record != nil {
                        Menu {
                            Button {
                                showingResetConfirm = true
                            } label: {
                                Label("Reset Payments", systemImage: "arrow.counterclockwise")
                            }
                            Button(role: .destructive) {
                                sharingManager.deleteRecord(for: subscription.id)
                            } label: {
                                Label("Stop Sharing", systemImage: "person.2.slash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddParticipant) {
                addParticipantSheet
            }
            .alert("Reset Payment Status?", isPresented: $showingResetConfirm) {
                Button("Reset", role: .destructive) {
                    if let record = record {
                        sharingManager.resetPaymentStatus(for: record.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Mark all participants as unpaid for the current billing period.")
            }
        }
    }

    // MARK: - Share Summary Card

    private var shareSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Share")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    let converted = currencyManager.convertToSelected(yourShareAmount, from: subscription.currency)
                    Text(currencyManager.format(converted))
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .foregroundStyle(.primary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.luxuryPurple.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundStyle(Color.luxuryPurple)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Price")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    let fullConverted = currencyManager.convertToSelected(subscription.amount, from: subscription.currency)
                    Text(currencyManager.format(fullConverted))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .strikethrough()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("You Save")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    let savedConverted = currencyManager.convertToSelected(subscription.amount - yourShareAmount, from: subscription.currency)
                    Text(currencyManager.format(savedConverted))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.semanticSuccess)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.luxuryPurple.opacity(0.2), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Participants Section

    private func participantsSection(record: SubscriptionShareRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Participants")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Spacer()
                Text("\(record.participants.count)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.obsidianElevated)
                    .clipShape(Capsule())
            }

            VStack(spacing: 8) {
                ForEach(record.participants) { participant in
                    ParticipantRow(
                        participant: participant,
                        subscriptionAmount: subscription.amount,
                        subscriptionCurrency: subscription.currency
                    )
                }
            }

            if !record.isFullyAllocated {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.semanticWarning)
                    Text("Shares total \(String(format: "%.0f", record.totalPercentage * 100))% — adjust to 100%")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.semanticWarning)
                    Spacer()
                }
                .padding(12)
                .background(Color.semanticWarning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showingAddParticipant = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Participant")
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.luxuryPurple)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.luxuryPurple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Payment Status

    private func paymentStatusSection(record: SubscriptionShareRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Payment Status")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Spacer()
                if record.allPaid {
                    Label("All Paid", systemImage: "checkmark.circle.fill")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.semanticSuccess)
                } else {
                    Label("\(record.unpaidParticipants.count) Pending", systemImage: "clock.fill")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.semanticWarning)
                }
            }

            VStack(spacing: 8) {
                ForEach(record.participants) { participant in
                    PaymentStatusRow(
                        participant: participant,
                        isPaid: participant.hasPaidCurrentPeriod
                    ) { isPaid in
                        sharingManager.updateParticipantPayment(
                            recordId: record.id,
                            participantId: participant.id,
                            hasPaid: isPaid
                        )
                    }
                }
            }
        }
    }

    // MARK: - Savings Insight

    private var savingsInsightCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.semanticSuccess.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.semanticSuccess)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly Savings")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                let saved = currencyManager.convertToSelected(yourMonthlySavings, from: subscription.currency)
                Text("You're saving \(currencyManager.format(saved)) every month by sharing this subscription.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.semanticSuccess.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.semanticSuccess.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.luxuryPurple.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.2")
                    .font(.largeTitle)
                    .foregroundStyle(Color.luxuryPurple)
            }

            VStack(spacing: 8) {
                Text("Split the Cost")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text("Share this subscription with friends or family and track who has paid their share.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                let you = SubscriptionParticipant(
                    name: "You",
                    sharePercentage: 0.5,
                    colorName: "luxuryPurple"
                )
                sharingManager.createRecord(for: subscription.id, participants: [you])
                showingAddParticipant = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Start Sharing")
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.luxuryPurple)
                .clipShape(Capsule())
            }

            Spacer()
        }
    }

    // MARK: - Add Participant Sheet

    private var addParticipantSheet: some View {
        NavigationStack {
            Form {
                Section("Participant Details") {
                    TextField("Name", text: $newParticipantName)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share: \(Int(newParticipantShare * 100))%")
                            .font(.system(.subheadline, design: .rounded))
                        Slider(value: $newParticipantShare, in: 0.05...0.95, step: 0.05)
                    }

                    let shareAmount = subscription.amount * Decimal(newParticipantShare)
                    let converted = currencyManager.convertToSelected(shareAmount, from: subscription.currency)
                    Text("They pay: \(currencyManager.format(converted)) / \(subscription.billingFrequency.shortDisplay)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        newParticipantName = ""
                        newParticipantShare = 0.5
                        showingAddParticipant = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        guard !newParticipantName.isEmpty else { return }
                        let participant = SubscriptionParticipant(
                            name: newParticipantName,
                            sharePercentage: newParticipantShare
                        )
                        if let record = record {
                            sharingManager.addParticipant(to: record.id, participant: participant)
                        }
                        newParticipantName = ""
                        newParticipantShare = 0.5
                        showingAddParticipant = false
                    }
                    .disabled(newParticipantName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Participant Row

struct ParticipantRow: View {
    let participant: SubscriptionParticipant
    let subscriptionAmount: Decimal
    let subscriptionCurrency: String
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(colorFromName(participant.colorName).opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(String(participant.name.prefix(1)))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(colorFromName(participant.colorName))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("\(Int(participant.sharePercentage * 100))% share")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let shareAmount = subscriptionAmount * Decimal(participant.sharePercentage)
            let converted = currencyManager.convertToSelected(shareAmount, from: subscriptionCurrency)
            Text(currencyManager.format(converted))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(14)
        .background(Color.obsidianElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "luxuryPurple": return .luxuryPurple
        case "luxuryGold": return .luxuryGold
        case "accentMint": return .accentMint
        case "luxuryPink": return .luxuryPink
        case "semanticSuccess": return .semanticSuccess
        case "semanticWarning": return .semanticWarning
        case "semanticDestructive": return .semanticDestructive
        default: return .luxuryPurple
        }
    }
}

// MARK: - Payment Status Row

struct PaymentStatusRow: View {
    let participant: SubscriptionParticipant
    let isPaid: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isPaid ? Color.semanticSuccess : .secondary)

            Text(participant.name)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))

            Spacer()

            Toggle("", isOn: Binding(
                get: { isPaid },
                set: { onToggle($0) }
            ))
            .tint(.semanticSuccess)
        }
        .padding(14)
        .background(Color.obsidianElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
