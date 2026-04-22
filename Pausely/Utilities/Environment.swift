//
//  Environment.swift
//  Pausely
//
//  Minimal environment config that wraps CredentialsManager
//  All credentials should be accessed via CredentialsManager.shared
//

import Foundation

enum EnvironmentConfig {
    static var supabaseURL: String {
        CredentialsManager.shared.get(.supabaseURL) ?? ""
    }

    static var supabaseAnonKey: String {
        CredentialsManager.shared.get(.supabaseAnonKey) ?? ""
    }

    static var supabaseServiceRoleKey: String {
        CredentialsManager.shared.get(.supabaseServiceRoleKey) ?? ""
    }

    static func validate() -> Bool {
        return !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }
}
