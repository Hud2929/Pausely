//
//  MVCardsScene.swift
//  Pausely
//
//  Scene 3: Subscription cards with neon glow icons + flowy slide
//

import SwiftUI


// MARK: - Demo Subscription Model
struct DemoSubscription: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let amount: Double
    let icon: String
    let color: Color
}


