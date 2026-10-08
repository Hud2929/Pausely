import Foundation

// MARK: - Structured Receipt Parser
/// Reads the machine-readable receipt data (schema.org JSON-LD) that many merchants embed in their emails.
/// This is the same markup Gmail and other inboxes consume to render "order cards", so when it exists it is far
/// more reliable than guessing from prose: it states the merchant, the amount, the currency and the billing period.
enum StructuredReceiptParser {

    enum Kind: String, Codable, Equatable {
        /// Explicit recurring billing (billingPeriod / unit price specification).
        case subscription
        /// An invoice without a stated recurring period.
        case invoice
        /// A one-off purchase (Order without recurrence).
        case order
        /// Shipping/delivery notice.
        case parcel
        /// Travel, event or table reservations.
        case reservation

        var isOneTime: Bool { self == .order || self == .parcel || self == .reservation }
    }

    struct Result: Equatable {
        var kind: Kind
        var merchant: String?
        var amount: Decimal?
        var currency: String?
        var cadence: BillingFrequency?
    }

    // MARK: Entry point

    /// Returns the strongest structured finding in the HTML, or nil when the email carries no usable markup.
    static func parse(html: String) -> Result? {
        let blocks = jsonLDBlocks(in: html)
        guard !blocks.isEmpty else { return nil }

        var findings: [Result] = []
        for block in blocks {
            guard let data = block.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            collect(from: json, into: &findings)
        }
        // Subscription > invoice > order > reservation > parcel
        let rank: [Kind: Int] = [.subscription: 5, .invoice: 4, .order: 3, .reservation: 2, .parcel: 1]
        return findings.max { (rank[$0.kind] ?? 0) < (rank[$1.kind] ?? 0) }
    }

    // MARK: JSON-LD discovery

    private static let scriptRegex = try? NSRegularExpression(
        pattern: "<script[^>]*type\\s*=\\s*[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>",
        options: [.caseInsensitive, .dotMatchesLineSeparators])

    static func jsonLDBlocks(in html: String) -> [String] {
        guard let scriptRegex else { return [] }
        let ns = html as NSString
        return scriptRegex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap {
            guard $0.numberOfRanges > 1 else { return nil }
            return ns.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: Walking the graph

    private static func collect(from node: Any, into findings: inout [Result]) {
        if let array = node as? [Any] {
            for item in array { collect(from: item, into: &findings) }
            return
        }
        guard let object = node as? [String: Any] else { return }

        if let graph = object["@graph"] { collect(from: graph, into: &findings) }

        let types = typeNames(object["@type"])
        if let result = interpret(object: object, types: types) { findings.append(result) }

        // Nested objects can carry the invoice/order too (e.g. a Message wrapping an Order).
        for key in ["about", "mainEntity", "object", "result", "orderedItem", "partOfOrder"] {
            if let nested = object[key] { collect(from: nested, into: &findings) }
        }
    }

    private static func typeNames(_ raw: Any?) -> [String] {
        if let single = raw as? String { return [single.lowercased()] }
        if let many = raw as? [Any] { return many.compactMap { ($0 as? String)?.lowercased() } }
        return []
    }

    private static let reservationTypes: Set<String> = [
        "reservation", "flightreservation", "lodgingreservation", "eventreservation", "foodestablishmentreservation",
        "rentalcarreservation", "reservationpackage", "trainreservation", "busreservation", "boatreservation", "ticket"
    ]

    private static func interpret(object: [String: Any], types: [String]) -> Result? {
        if types.contains("parceldelivery") {
            return Result(kind: .parcel, merchant: organizationName(object["provider"] ?? object["partOfOrder"]),
                          amount: nil, currency: nil, cadence: nil)
        }
        if !reservationTypes.isDisjoint(with: Set(types)) {
            let price = readPrice(object)
            return Result(kind: .reservation, merchant: organizationName(object["provider"] ?? object["reservationFor"]),
                          amount: price.amount, currency: price.currency, cadence: nil)
        }
        if types.contains("invoice") {
            let price = readPrice(object)
            let cadence = durationCadence(object["billingPeriod"] as? String)
            let merchant = organizationName(object["provider"] ?? object["seller"])
            return Result(kind: cadence != nil ? .subscription : .invoice, merchant: merchant,
                          amount: price.amount, currency: price.currency, cadence: cadence)
        }
        if types.contains("order") {
            let price = readPrice(object)
            let merchant = organizationName(object["seller"] ?? object["merchant"] ?? object["broker"])
            let recurring = recurringCadence(in: object)
            return Result(kind: recurring != nil ? .subscription : .order, merchant: merchant,
                          amount: price.amount, currency: price.currency, cadence: recurring)
        }
        return nil
    }

    // MARK: Field readers

    private static func organizationName(_ raw: Any?) -> String? {
        if let name = raw as? String { return name }
        if let object = raw as? [String: Any] { return object["name"] as? String ?? object["legalName"] as? String }
        return nil
    }

    private static func readPrice(_ object: [String: Any]) -> (amount: Decimal?, currency: String?) {
        // Gmail's Invoice markup: totalPaymentDue { price, priceCurrency }
        if let due = object["totalPaymentDue"] as? [String: Any] { return decimalPair(due) }
        // Order markup: price / priceCurrency directly, or acceptedOffer price
        let direct = decimalPair(object)
        if direct.amount != nil { return direct }
        if let offer = object["acceptedOffer"] { return decimalPair(firstObject(offer)) }
        if let spec = object["priceSpecification"] { return decimalPair(firstObject(spec)) }
        return (nil, nil)
    }

    private static func decimalPair(_ object: [String: Any]) -> (amount: Decimal?, currency: String?) {
        let rawPrice = object["price"] ?? object["totalPrice"] ?? object["value"]
        var amount: Decimal?
        if let number = rawPrice as? NSNumber { amount = number.decimalValue }
        else if let string = rawPrice as? String {
            amount = Decimal(string: string.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "$€£ ")))
        }
        if let value = amount, value <= 0 || value >= 10_000 { amount = nil }
        let currency = (object["priceCurrency"] as? String ?? object["currency"] as? String)?.uppercased()
        return (amount, currency)
    }

    private static func firstObject(_ raw: Any) -> [String: Any] {
        if let object = raw as? [String: Any] { return object }
        if let array = raw as? [Any], let first = array.first as? [String: Any] { return first }
        return [:]
    }

    // MARK: Recurrence

    /// Looks for a recurring unit price (schema.org UnitPriceSpecification) inside an Order's offers.
    private static func recurringCadence(in order: [String: Any]) -> BillingFrequency? {
        var specs: [[String: Any]] = []
        func gatherSpecs(from raw: Any?) {
            guard let raw else { return }
            if let array = raw as? [Any] { array.forEach { gatherSpecs(from: $0) }; return }
            guard let object = raw as? [String: Any] else { return }
            if let spec = object["priceSpecification"] { gatherSpecs(from: spec) }
            if object["unitCode"] != nil || object["billingDuration"] != nil || object["billingIncrement"] != nil { specs.append(object) }
            if let offer = object["acceptedOffer"] { gatherSpecs(from: offer) }
        }
        gatherSpecs(from: order["acceptedOffer"])
        gatherSpecs(from: order["priceSpecification"])
        if let items = order["orderedItem"] { gatherSpecs(from: items) }

        for spec in specs {
            if let period = durationCadence(spec["billingDuration"] as? String) { return period }
            if let code = (spec["unitCode"] as? String)?.uppercased() {
                let increment = (spec["billingIncrement"] as? NSNumber)?.intValue ?? 1
                switch (code, increment) {
                case ("MON", 1): return .monthly
                case ("MON", 3): return .quarterly
                case ("MON", 6): return .semiannual
                case ("MON", 12), ("ANN", 1): return .yearly
                case ("WEE", 1): return .weekly
                case ("WEE", 2): return .biweekly
                case ("DAY", 7): return .weekly
                case ("DAY", 14): return .biweekly
                case ("DAY", 28...31): return .monthly
                case ("DAY", 365...366): return .yearly
                default: continue
                }
            }
        }
        return nil
    }

    /// ISO 8601 durations as used by `billingPeriod`: P1M, P3M, P1Y, P12M, P1W, P7D …
    static func durationCadence(_ duration: String?) -> BillingFrequency? {
        guard let duration = duration?.uppercased(), duration.hasPrefix("P") else { return nil }
        let body = duration.dropFirst()
        guard let unit = body.last, let value = Int(body.dropLast()) else { return nil }
        switch (unit, value) {
        case ("Y", 1), ("M", 12): return .yearly
        case ("M", 1): return .monthly
        case ("M", 3): return .quarterly
        case ("M", 6): return .semiannual
        case ("W", 1), ("D", 7): return .weekly
        case ("W", 2), ("D", 14): return .biweekly
        case ("D", 28...31): return .monthly
        case ("D", 365...366): return .yearly
        default: return nil
        }
    }
}
