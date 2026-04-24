//
//  AnnualSavingsCalculatorView.swift
//  Pausely
//
//  Show potential savings by switching to annual billing
//

import SwiftUI

struct AnnualSavingsCalculatorView: View {
    let subscription: Subscription
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.dismiss) private var dismiss

    var monthlyCost: Decimal { subscription.monthlyCost }
    var annualCost: Decimal { subscription.annualCost }
    var potentialSavings: Decimal { (monthlyCost * 12) - annualCost }
    var savingsPercentage: Double {
        let monthlyAnnual = Double(truncating: (monthlyCost * 12) as NSDecimalNumber)
        let annual = Double(truncating: annualCost as NSDecimalNumber)
        guard monthlyAnnual > 0 else { return 0 }
        return ((monthlyAnnual - annual) / monthlyAnnual) * 100
    }

    var fiveYearSavings: Decimal { potentialSavings * 5 }
    var tenYearSavings: Decimal { potentialSavings * 10 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.accentMint.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.title)
                                .foregroundStyle(Color.accentMint)
                        }

                        Text("Switch to Annual")
                            .font(.system(.title2, design: .rounded).weight(.bold))

                        Text("See how much you could save by paying yearly instead of monthly.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Savings card
                    savingsCard

                    // Comparison table
                    comparisonSection

                    // Long term projection
                    projectionSection

                    // Action tip
                    tipCard
                }
                .padding()
            }
            .navigationTitle("Annual Savings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var savingsCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("You Could Save")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                let converted = currencyManager.convertToSelected(potentialSavings, from: subscription.currency)
                Text(currencyManager.format(converted))
                    .font(.system(.largeTitle, design: .rounded).weight(.black))
                    .foregroundStyle(Color.accentMint)

                if savingsPercentage > 0 {
                    Text("\(String(format: "%.0f", savingsPercentage))% off equivalent monthly cost")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Total")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    let monthlyAnnual = currencyManager.convertToSelected(monthlyCost * 12, from: subscription.currency)
                    Text(currencyManager.format(monthlyAnnual))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .strikethrough()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Annual Price")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    let annualConverted = currencyManager.convertToSelected(annualCost, from: subscription.currency)
                    Text(currencyManager.format(annualConverted))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.accentMint.opacity(0.25), lineWidth: 1.5)
                )
        )
        .shadow(color: Color.accentMint.opacity(0.08), radius: 24, x: 0, y: 10)
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Comparison")
                .font(.system(.headline, design: .rounded).weight(.bold))

            VStack(spacing: 0) {
                ComparisonRow(
                    label: "Pay Monthly",
                    amount: monthlyCost * 12,
                    currency: subscription.currency,
                    isRecommended: false
                )

                Divider().padding(.leading, 16)

                ComparisonRow(
                    label: "Pay Annually",
                    amount: annualCost,
                    currency: subscription.currency,
                    isRecommended: true
                )
            }
            .background(Color.obsidianElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var projectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Long-Term Savings")
                .font(.system(.headline, design: .rounded).weight(.bold))

            HStack(spacing: 12) {
                ProjectionPill(
                    period: "5 Years",
                    savings: fiveYearSavings,
                    currency: subscription.currency
                )
                ProjectionPill(
                    period: "10 Years",
                    savings: tenYearSavings,
                    currency: subscription.currency
                )
            }
        }
    }

    private var tipCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.luxuryGold.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(Color.luxuryGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Pro Tip")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("Many services offer a free month or bonus credits when switching to annual. Contact support to ask.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.luxuryGold.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.luxuryGold.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Comparison Row

struct ComparisonRow: View {
    let label: String
    let amount: Decimal
    let currency: String
    let isRecommended: Bool
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if isRecommended {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentMint)
                }
                Text(label)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }

            Spacer()

            let converted = currencyManager.convertToSelected(amount, from: currency)
            Text(currencyManager.format(converted))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(isRecommended ? Color.accentMint : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Projection Pill

struct ProjectionPill: View {
    let period: String
    let savings: Decimal
    let currency: String
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        VStack(spacing: 6) {
            Text(period)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)

            let converted = currencyManager.convertToSelected(savings, from: currency)
            Text(currencyManager.format(converted))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Color.accentMint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.obsidianElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
