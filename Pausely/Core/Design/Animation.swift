//
//  Animation.swift
//  Pausely
//
//  Animation Constants & Haptics
//

import SwiftUI
import UIKit

// MARK: - Animation
enum STAnimation {
    
    // Snappy — for toggles, buttons, small elements
    static let snappy = Animation.spring(duration: 0.3, bounce: 0.15)
    
    
    
    
    // MARK: - Haptics
    static func impactLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func impactMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    
}
