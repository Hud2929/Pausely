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
    // Primary spring — used for most interactive transitions
    static let spring = Animation.spring(duration: 0.5, bounce: 0.2)
    
    // Snappy — for toggles, buttons, small elements
    static let snappy = Animation.spring(duration: 0.3, bounce: 0.15)
    
    // Gentle — for sheets, large surface transitions
    static let gentle = Animation.spring(duration: 0.6, bounce: 0.1)
    
    // Stagger delay between list items
    static let staggerInterval: Double = 0.05
    
    // Number counter animation duration
    static let counterDuration: Double = 1.2
    
    // MARK: - Haptics
    static func impactLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func impactMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func impactHeavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
