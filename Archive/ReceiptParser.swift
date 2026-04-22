//
//  ReceiptParser.swift
//  Pausely
//
//  App Store Receipt Parser
//  Reads local receipt data to auto-detect App Store subscriptions.
//  No bank access, no login — all on-device.
//

import Foundation
import StoreKit

// MARK: - Receipt Parse Error

enum ReceiptParseError: Error, LocalizedError {
    case noReceipt
    case receiptCorrupted
    case parseFailed
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .noReceipt:
            return "No App Store receipt found. This device hasn't made App Store purchases."
        case .receiptCorrupted:
            return "Receipt file is corrupted."
        case .parseFailed:
            return "Failed to parse receipt data."
        case .notConfigured:
            return "Receipt parsing not available."
        }
    }
}

// MARK: - In-App Purchase Receipt

/// Represents a single in-app purchase from the receipt
struct IAPReceipt: Identifiable, Equatable {
    let id = UUID()
    let productId: String
    let quantity: Int
    let purchaseDate: Date
    let originalPurchaseDate: Date
    let subscriptionExpirationDate: Date?
    let cancellationDate: Date?
    let isTrial: Bool
    let isIntroductoryOffer: Bool
    let webOrderLineItemId: String?

    var isActive: Bool {
        if let expiration = subscriptionExpirationDate {
            return cancellationDate == nil && expiration > Date()
        }
        return cancellationDate == nil
    }

    var isSubscription: Bool {
        productId.contains(".") && (
            productId.contains("monthly") ||
            productId.contains("annual") ||
            productId.contains("yearly") ||
            productId.contains("premium") ||
            productId.contains("subscription") ||
            productId.contains("pro")
        )
    }
}

// MARK: - Receipt Parse Result

struct ReceiptParseResult {
    let iaps: [IAPReceipt]
    let appReceipt: AppReceipt?
    let parsedAt: Date

    var activeSubscriptions: [IAPReceipt] {
        iaps.filter { $0.isSubscription && $0.isActive }
    }

    var hasActiveSubscriptions: Bool {
        !activeSubscriptions.isEmpty
    }
}

// MARK: - App Receipt (Bundle-level)

struct AppReceipt {
    let bundleId: String
    let appVersion: String
    let originalAppVersion: String
    let purchaseDate: Date
    let receiptCreationDate: Date
}

// MARK: - Receipt Parser

/// Parses the local App Store receipt to detect subscriptions.
/// No network access required — reads from device storage.
///
/// Receipt location: /var/mobile/Library/Receipts/sandboxReceipt or production receipt
/// For sandbox: ~/Library/Containers/.../Data/Library/Receipts/
@MainActor
final class ReceiptParser: ObservableObject {
    static let shared = ReceiptParser()

    // MARK: - Published State

    @Published private(set) var lastParseResult: ReceiptParseResult?
    @Published private(set) var isLoading = false
    @Published private(set) var parseError: ReceiptParseError?
    @Published private(set) var hasReceipt = false

    // MARK: - Private

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let simpleDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private init() {
        checkForReceipt()
    }

    // MARK: - Public Methods

    /// Check if a receipt exists on this device
    @available(iOS, deprecated: 18.0)
    func checkForReceipt() {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            hasReceipt = false
            return
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: receiptURL.path, isDirectory: &isDirectory)
        hasReceipt = exists && !isDirectory.boolValue
    }

    /// Parse the App Store receipt and return all IAPs
    /// - Returns: ReceiptParseResult containing all in-app purchases found
    @available(iOS, deprecated: 18.0)
    func parseReceipt() async -> ReceiptParseResult? {
        isLoading = true
        parseError = nil
        defer { isLoading = false }

        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            parseError = .noReceipt
            #if DEBUG
            print("ReceiptParser: No receipt URL found")
            #endif
            return nil
        }

        do {
            let receiptData = try Data(contentsOf: receiptURL)
            let result = try parseReceiptData(receiptData)
            lastParseResult = result
            #if DEBUG
            print("ReceiptParser: Found \(result.iaps.count) IAPs, \(result.activeSubscriptions.count) active subscriptions")
            #endif
            return result
        } catch let error as ReceiptParseError {
            parseError = error
            #if DEBUG
            print("ReceiptParser: Error - \(error.localizedDescription)")
            #endif
            return nil
        } catch {
            parseError = .parseFailed
            #if DEBUG
            print("ReceiptParser: Failed to read receipt - \(error)")
            #endif
            return nil
        }
    }

    /// Get detected subscriptions from receipt, matched against our catalog
    /// - Returns: Subscriptions from the catalog that match IAPs in the receipt
    func detectCatalogSubscriptions() async -> [SubscriptionInfo] {
        guard let result = await parseReceipt() else { return [] }

        let activeProductIds = Set(result.activeSubscriptions.map { $0.productId })
        let catalog = SubscriptionCatalogService.shared.catalog
        var matched: [SubscriptionInfo] = []

        for productId in activeProductIds {
            // Try exact match on appStoreProductId
            if let entry = catalog.first(where: { $0.appStoreProductId == productId }),
               let info = SubscriptionInfo(from: entry) {
                if !matched.contains(where: { $0.bundleId == info.bundleId }) {
                    matched.append(info)
                }
            }
        }

        #if DEBUG
        print("ReceiptParser: Matched \(matched.count) catalog subscriptions from receipt")
        #endif

        return matched
    }

    /// Convert detected IAPs to Subscription models ready for adding to user's list
    func createSubscriptionsFromReceipt() async -> [Subscription] {
        guard let result = await parseReceipt() else { return [] }

        let catalog = SubscriptionCatalogService.shared.catalog
        var subscriptions: [Subscription] = []

        for iap in result.activeSubscriptions {
            // Try to match with catalog
            if let entry = catalog.first(where: { $0.appStoreProductId == iap.productId }),
               let info = SubscriptionInfo(from: entry) {
                let sub = Subscription(
                    name: info.name,
                    bundleIdentifier: info.bundleId,
                    category: info.category.rawValue,
                    amount: Decimal(info.defaultPrice),
                    billingFrequency: info.frequency,
                    nextBillingDate: iap.subscriptionExpirationDate,
                    monthlyUsageMinutes: 0,
                    status: .active,
                    isDetected: true
                )
                subscriptions.append(sub)
            } else {
                // Unknown IAP — create generic entry
                let sub = Subscription(
                    name: displayNameFromProductId(iap.productId),
                    category: "Other",
                    amount: 0,
                    billingFrequency: .monthly,
                    nextBillingDate: iap.subscriptionExpirationDate,
                    status: .active,
                    isDetected: true
                )
                subscriptions.append(sub)
            }
        }

        return subscriptions
    }

    // MARK: - Private Methods

    private func parseReceiptData(_ data: Data) throws -> ReceiptParseResult {
        // The receipt is a PKCS7 signed data structure
        // We need to extract the inner content (an ASN.1 sequence)

        var iaps: [IAPReceipt] = []
        var appReceipt: AppReceipt?

        // Try to parse as ASN.1
        guard let asn1 = parseASN1(data) else {
            throw ReceiptParseError.receiptCorrupted
        }

        // Receipt structure: [0] = receipt data (set of attributes)
        // Each attribute: [0] = type, [1] = version, [2] = value (octet string containing another ASN.1)
        if let receiptSet = asn1.first(where: { $0.tag == 0x31 }) { // SET tag
            for item in receiptSet.children ?? [] {
                if item.tag == 0x30 { // SEQUENCE
                    let attrs = parseAttributes(item)
                    iaps.append(contentsOf: attrs.iaps)
                    if let app = attrs.appReceipt {
                        appReceipt = app
                    }
                }
            }
        }

        // Also try the outer container if no receipt found
        if iaps.isEmpty {
            for node in asn1 {
                let attrs = parseAttributes(node)
                iaps.append(contentsOf: attrs.iaps)
                if let app = attrs.appReceipt {
                    appReceipt = app
                }
            }
        }

        return ReceiptParseResult(
            iaps: iaps,
            appReceipt: appReceipt,
            parsedAt: Date()
        )
    }

    private struct ParseAttributesResult {
        var iaps: [IAPReceipt] = []
        var appReceipt: AppReceipt?
    }

    private func parseAttributes(_ seq: ASN1Node) -> ParseAttributesResult {
        var result = ParseAttributesResult()
        var iapNodes: [ASN1Node] = []

        for child in seq.children ?? [] {
            if child.tag == 0x30 { // SEQUENCE of attribute
                var type: UInt64?
                var valueData: Data?

                for pair in child.children ?? [] {
                    if pair.tag == 0x02 { // INTEGER type
                        type = decodeInteger(pair.value)
                    } else if pair.tag == 0x04 { // OCTET STRING value
                        valueData = pair.value
                    }
                }

                // OID types for IAP receipts
                // 17 = InAppPurchaseReceipt (iOS 3.0+)
                // 18 = SubscriptionTrial (iOS 5.0+)
                // 19 = SubscriptionIntroductoryOffer (iOS 5.0+)
                // 20 = SubscriptionExpiration (iOS 5.0+)
                // 21 = AppReceiptCreation (iOS 3.0+)
                // AppleReceiptAttributeType values

                if let t = type, let data = valueData {
                    if t == 17 || t == 18 || t == 19 || t == 20 {
                        // Parse the inner IAP receipt data
                        if let inner = parseASN1(data), let iapSeq = inner.first(where: { $0.tag == 0x30 }) {
                            if let iap = parseIAPReceipt(iapSeq) {
                                iapNodes.append(iapSeq)
                                result.iaps.append(iap)
                            }
                        }
                    } else if t == 21 {
                        // App receipt
                        if let inner = parseASN1(data), let appSeq = inner.first(where: { $0.tag == 0x30 }) {
                            result.appReceipt = parseAppReceipt(appSeq)
                        }
                    }
                }
            }
        }

        return result
    }

    private func parseIAPReceipt(_ seq: ASN1Node) -> IAPReceipt? {
        // InAppPurchaseReceipt fields (by index):
        // 0: quantity (INT)
        // 1: product_id (STRING)
        // 2: transaction_id (STRING)
        // 3: original_transaction_id (STRING)
        // 4: purchase_date (STRING - ISO8601)
        // 5: original_purchase_date (STRING - ISO8601)
        // 6: subscription_expiration_date (STRING, optional)
        // 7: cancellation_date (STRING, optional)
        // 8: web_order_line_item_id (STRING, optional)
        // 9: is_trial_period (BOOL)
        // 10: is_in_intro_offer_period (BOOL)

        var productId: String?
        var quantity = 1
        var purchaseDate: Date?
        var originalPurchaseDate: Date?
        var subscriptionExpirationDate: Date?
        var cancellationDate: Date?
        var isTrial = false
        var isIntroductoryOffer = false
        let webOrderLineItemId: String? = nil

        let children = seq.children ?? []

        for (index, child) in children.enumerated() {
            switch child.tag {
            case 0x02: // INTEGER
                if index == 0 {
                    quantity = Int(decodeInteger(child.value))
                }
            case 0x0C: // UTF8 STRING
                let str = String(data: child.value, encoding: .utf8) ?? ""
                if productId == nil && str.contains(".") {
                    productId = str
                } else if str.contains("@") == false && str.contains("/") == false {
                    // Date string
                    if purchaseDate == nil {
                        purchaseDate = parseDate(str)
                    } else if originalPurchaseDate == nil {
                        originalPurchaseDate = parseDate(str)
                    }
                }
            case 0x04: // OCTET STRING (for strings in some formats)
                let str = String(data: child.value, encoding: .utf8) ?? ""
                if str.contains(".") && productId == nil {
                    productId = str
                }
            case 0x01: // BOOLEAN
                if index == 9 {
                    isTrial = decodeBool(child.value)
                } else if index == 10 {
                    isIntroductoryOffer = decodeBool(child.value)
                }
            default:
                break
            }
        }

        // Fallback: extract strings from all children
        let allStrings = extractStrings(from: seq)
        for str in allStrings {
            if str.contains(".") && productId == nil && str.count < 200 {
                productId = str
            } else if productId != nil && purchaseDate == nil {
                purchaseDate = parseDate(str)
            } else if purchaseDate != nil && originalPurchaseDate == nil {
                originalPurchaseDate = parseDate(str)
            } else if str.hasPrefix("+") || str.hasPrefix("-") {
                // Relative date for expiration - skip
            } else if parseDate(str) != nil && str.contains("-") && subscriptionExpirationDate == nil {
                subscriptionExpirationDate = parseDate(str)
            } else if parseDate(str) != nil && str.contains("-") && cancellationDate == nil && str != purchaseDate?.description {
                cancellationDate = parseDate(str)
            }
        }

        // Parse dates from raw value strings
        for child in children {
            let str = String(data: child.value, encoding: .utf8) ?? ""
            if str.contains("-") && str.contains(":") {
                if subscriptionExpirationDate == nil && (str.contains("+") || str.contains("Z")) {
                    subscriptionExpirationDate = parseDate(str)
                } else if cancellationDate == nil {
                    let d = parseDate(str)
                    if d != nil && d != purchaseDate && d != originalPurchaseDate {
                        if subscriptionExpirationDate == nil {
                            subscriptionExpirationDate = d
                        } else {
                            cancellationDate = d
                        }
                    }
                }
            }
        }

        guard let product = productId,
              let purchased = purchaseDate ?? originalPurchaseDate else {
            return nil
        }

        return IAPReceipt(
            productId: product,
            quantity: quantity,
            purchaseDate: purchased,
            originalPurchaseDate: originalPurchaseDate ?? purchased,
            subscriptionExpirationDate: subscriptionExpirationDate,
            cancellationDate: cancellationDate,
            isTrial: isTrial,
            isIntroductoryOffer: isIntroductoryOffer,
            webOrderLineItemId: webOrderLineItemId
        )
    }

    private func parseAppReceipt(_ seq: ASN1Node) -> AppReceipt? {
        let strings = extractStrings(from: seq)

        var bundleId: String?
        var appVersion: String?
        var originalAppVersion: String?
        var purchaseDate: Date?
        var receiptCreationDate: Date?

        for str in strings {
            if bundleId == nil && str.contains("com.") {
                bundleId = str
            } else if appVersion == nil && str.count < 20 && str.first?.isNumber == true {
                appVersion = str
            } else if originalAppVersion == nil && str.count < 20 && str.first?.isNumber == true && str != appVersion {
                originalAppVersion = str
            }
        }

        for str in strings {
            let d = parseDate(str)
            if d != nil {
                if purchaseDate == nil {
                    purchaseDate = d
                } else {
                    receiptCreationDate = d
                }
            }
        }

        guard let bundle = bundleId,
              let version = appVersion ?? originalAppVersion,
              let created = purchaseDate ?? receiptCreationDate else {
            return nil
        }

        return AppReceipt(
            bundleId: bundle,
            appVersion: version,
            originalAppVersion: originalAppVersion ?? version,
            purchaseDate: created,
            receiptCreationDate: receiptCreationDate ?? created
        )
    }

    // MARK: - ASN.1 Parsing

    private struct ASN1Node {
        let tag: UInt8
        let value: Data
        var children: [ASN1Node]?
    }

    private func parseASN1(_ data: Data) -> [ASN1Node]? {
        var index = 0
        return parseASN1Recursive(data, index: &index)
    }

    private func parseASN1Recursive(_ data: Data, index: inout Int) -> [ASN1Node]? {
        var nodes: [ASN1Node] = []

        while index < data.count {
            guard index + 2 <= data.count else { break }

            let tag = data[index]
            index += 1

            let lengthByte = data[index]
            index += 1

            var length: Int
            if lengthByte < 0x80 {
                length = Int(lengthByte)
            } else {
                let numBytes = Int(lengthByte & 0x7F)
                guard index + numBytes <= data.count else { break }
                length = 0
                for i in 0..<numBytes {
                    length = length * 256 + Int(data[index + i])
                }
                index += numBytes
            }

            guard index + length <= data.count else { break }

            let contentStart = index
            let contentEnd = index + length
            index = contentEnd

            var node = ASN1Node(tag: tag, value: data[contentStart..<contentEnd])

            // If constructed (bit 6 set), parse children
            if (tag & 0x20) != 0 {
                var childIndex = 0
                node.children = parseASN1Recursive(data[contentStart..<contentEnd], index: &childIndex)
            } else if (tag & 0xC0) == 0xC0 {
                // Context-specific constructed
                var childIndex = 0
                node.children = parseASN1Recursive(data[contentStart..<contentEnd], index: &childIndex)
            }

            nodes.append(node)
        }

        return nodes.isEmpty ? nil : nodes
    }

    private func decodeInteger(_ data: Data) -> UInt64 {
        guard !data.isEmpty else { return 0 }
        var result: UInt64 = 0
        for byte in data {
            result = result * 256 + UInt64(byte)
        }
        return result
    }

    private func decodeBool(_ data: Data) -> Bool {
        guard let first = data.first else { return false }
        return first != 0
    }

    private func parseDate(_ string: String) -> Date? {
        let cleaned = string.replacingOccurrences(of: "Z", with: "+00:00")
        if let date = dateFormatter.date(from: cleaned) {
            return date
        }
        if let date = simpleDateFormatter.date(from: cleaned) {
            return date
        }
        // Try without fractional seconds
        var noFraction = cleaned
        if let range = noFraction.range(of: "\\.\\d+", options: .regularExpression) {
            noFraction.removeSubrange(range)
        }
        if let date = simpleDateFormatter.date(from: noFraction) {
            return date
        }
        return nil
    }

    private func extractStrings(from node: ASN1Node) -> [String] {
        var strings: [String] = []
        if node.tag == 0x0C || node.tag == 0x13 || node.tag == 0x04 {
            if let str = String(data: node.value, encoding: .utf8) {
                strings.append(str)
            }
        }
        if let children = node.children {
            for child in children {
                strings.append(contentsOf: extractStrings(from: child))
            }
        }
        return strings
    }

    private func deduplicateASN1(_ nodes: [ASN1Node]) -> [ASN1Node] {
        var seen = Set<String>()
        var unique: [ASN1Node] = []
        for node in nodes {
            let key = node.value.base64EncodedString()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(node)
            }
        }
        return unique
    }

    private func displayNameFromProductId(_ productId: String) -> String {
        let parts = productId.components(separatedBy: ".")
        return parts.last ?? productId
            .replacingOccurrences(of: "monthly", with: "")
            .replacingOccurrences(of: "annual", with: "")
            .replacingOccurrences(of: "yearly", with: "")
            .replacingOccurrences(of: "subscription", with: "")
            .replacingOccurrences(of: "pro", with: "")
            .capitalized
    }
}

// MARK: - Preview Support

#if DEBUG
extension ReceiptParser {
    static var previewEmpty: ReceiptParser {
        let parser = ReceiptParser()
        return parser
    }

    static var previewWithSubscriptions: ReceiptParser {
        let parser = ReceiptParser()
        parser.lastParseResult = ReceiptParseResult(
            iaps: [
                IAPReceipt(
                    productId: "com.pausely.premium.monthly",
                    quantity: 1,
                    purchaseDate: Date().addingTimeInterval(-86400 * 30),
                    originalPurchaseDate: Date().addingTimeInterval(-86400 * 30),
                    subscriptionExpirationDate: Date().addingTimeInterval(86400 * 1),
                    cancellationDate: nil,
                    isTrial: false,
                    isIntroductoryOffer: false,
                    webOrderLineItemId: nil
                )
            ],
            appReceipt: nil,
            parsedAt: Date()
        )
        return parser
    }
}
#endif
