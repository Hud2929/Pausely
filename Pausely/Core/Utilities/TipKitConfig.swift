//
//  TipKitConfig.swift
//  Pausely
//
//  TipKit integration for contextual feature discovery
//

import TipKit
import SwiftUI
import os.log

// MARK: - TipKit Configuration
@MainActor
enum TipKitConfiguration {
    static func configure() {
        do {
            try Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
        } catch {
            os_log("TipKit configuration failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
}


