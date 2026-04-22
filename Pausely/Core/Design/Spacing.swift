//
//  Spacing.swift
//  Pausely
//
//  4pt Base Grid System
//

import SwiftUI

// MARK: - Spacing Scale (4pt base grid)
enum STSpacing {
    static let xxs:  CGFloat = 2
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let base: CGFloat = 16
    static let lg:   CGFloat = 20
    static let xl:   CGFloat = 24
    static let xxl:  CGFloat = 32
    static let xxxl: CGFloat = 40
    static let huge: CGFloat = 56
    
    // Screen edge insets
    static let screenHorizontal: CGFloat = 20
    static let screenVertical:   CGFloat = 16
}

// MARK: - Corner Radii
enum STRadius {
    static let xs:    CGFloat = 6
    static let sm:    CGFloat = 8
    static let md:    CGFloat = 12
    static let lg:    CGFloat = 16
    static let xl:    CGFloat = 20
    static let full:  CGFloat = 999  // Capsule
}
