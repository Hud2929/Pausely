//
//  SubscriptionCatalogService.swift
//  Pausely
//
//  Lookups into the built-in catalog of services people subscribe to (`CatalogData`).
//

import Foundation

@MainActor
final class SubscriptionCatalogService: ObservableObject {
    static let shared = SubscriptionCatalogService()

    /// Every service in the catalog, one row per name. Built in: there from the first moment,
    /// without a network.
    let catalog: [CatalogEntry]
    private let entryByName: [String: CatalogEntry]

    private init() {
        catalog = CatalogData.entries
        entryByName = Dictionary(CatalogData.entries.map { (Self.key($0.name), $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// The catalog entry with this exact name (case-insensitive).
    func entry(named name: String) -> CatalogEntry? {
        entryByName[Self.key(name)]
    }
}
