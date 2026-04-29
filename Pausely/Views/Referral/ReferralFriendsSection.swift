import SwiftUI

struct ReferralFriendsSection: View {
    let conversions: [ReferralConversion]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Referred Friends")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            if conversions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.3))

                    Text("No referrals yet")
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Share your code to start earning!")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 12) {
                    ForEach(conversions.prefix(3), id: \.id) { conversion in
                        ConversionRow(conversion: conversion)
                    }

                    ForEach(0..<max(0, 3 - conversions.count), id: \.self) { _ in
                        EmptyFriendRow()
                    }
                }
            }
        }
    }
}
