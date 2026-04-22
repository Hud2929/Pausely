//
//  DemoModeBanner.swift
//  Pausely
//
//  Banner displayed when the app is running in demo mode
//

import SwiftUI

struct DemoModeBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Demo Mode - Data is not being saved")
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
}

#Preview {
    DemoModeBanner()
}
