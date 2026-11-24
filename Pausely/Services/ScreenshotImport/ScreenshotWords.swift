import Foundation

/// The words the screenshot parser reads a row by: how often it charges, money coming in, a bank row's own
/// labels, bills, and the headers of a list whose every row repeats. Kept apart from the layout logic in
/// `ScreenshotParser.swift`.
extension ScreenshotParser {

    /// Whether `resolved` is `raw` with only a plan's name after it.
    static func addsOnlyAPlan(_ raw: String, to resolved: String) -> Bool {
        let plans: Set<String> = ["team", "plus", "pro", "premium", "family", "business", "enterprise", "individual",
                                  "duo", "student", "basic", "standard", "max", "ultra"]
        let r = raw.trimmingCharacters(in: .whitespaces).lowercased(), full = resolved.lowercased()
        guard full.count > r.count, full.hasPrefix(r + " ") else { return false }
        return plans.contains(String(full.dropFirst(r.count + 1)))
    }

    /// Headers of a list whose every row repeats: a bank's or card's recurring payments, standing orders.
    static let recurringListHeaders: Set<String> = [
        "recurring", "recurring payments", "recurring charges", "upcoming bills", "bills & subscriptions",
        "subscriptions & bills", "standing orders", "direct debits", "scheduled payments",
        "daueraufträge", "lastschriften", "abonnements", "prélèvements", "pagos recurrentes", "suscripciones",
        "定期支払い", "サブスクリプション", "المدفوعات المتكررة", "الاشتراكات"
    ]

    /// Money coming in, never a subscription: a "+" before the amount, or a word that says so.
    static func isIncomeOrTransfer(_ lower: String) -> Bool {
        // The "+" stands on its own: in "Disney+ $159.99" it is part of a name.
        if lower.range(of: #"(?<![\p{L}\p{N}])\+\s*(?:[€$£¥]|[a-z]{3}\s)?\s*\d"#, options: .regularExpression) != nil { return true }
        let words = ["salary", "payroll", "paycheck", "deposit", "refund", "transfer", "interest", "cashback", "reimbursement",
                     "balance", "available",
                     "gehalt", "lohn", "überweisung", "erstattung", "salaire", "virement", "remboursement",
                     "nómina", "salario", "transferencia", "reembolso", "給与", "振込", "返金", "راتب", "تحويل", "استرداد"]
        return words.contains { lower.contains($0) }
    }

    /// A row's own label in a bank's list: how it was paid, not who was paid.
    static func isRowLabel(_ lower: String) -> Bool {
        ["card payment", "card subscription", "direct debit", "standing order", "credit transfer", "debit transfer",
         "contactless", "online payment", "pending", "recurring card payment", "lastschrift", "dauerauftrag",
         "kartenzahlung", "prélèvement", "paiement par carte", "domiciliación", "pago con tarjeta", "口座振替",
         "カード払い", "خصم مباشر"].contains { lower.hasPrefix($0) }
    }

    /// "Every 2 months" and its translations.
    static func isEveryTwoMonths(_ lower: String) -> Bool {
        ["every 2 months", "every two months", "bimonthly", "bi-monthly", "every other month", "alle 2 monate",
         "tous les 2 mois", "cada 2 meses", "2か月ごと", "كل شهرين"].contains { lower.contains($0) }
    }

    /// Rent, insurance, energy and the like: recurring, but a bill rather than a subscription.
    static func isBill(_ name: String) -> Bool {
        let lower = name.lowercased()
        let words = Set(lower.split { !$0.isLetter }.map(String.init))
        let bills: Set<String> = ["rent", "insurance", "electric", "electricity", "energy", "gas", "water", "mortgage", "loan",
                                  "utility", "utilities", "hydro", "council", "miete", "versicherung", "strom", "loyer",
                                  "assurance", "électricité", "alquiler", "seguro", "luz", "家賃", "保険"]
        if !words.isDisjoint(with: bills) { return true }
        // German and Japanese compound nouns ("Hausratversicherung", "Kaltmiete", "生命保険", "家賃振込").
        let compoundRoots = ["versicherung", "miete", "strom", "家賃", "保険"]
        return compoundRoots.contains { lower.contains($0) }
    }

    /// "Every 4 weeks" and its translations.
    static func isEveryFourWeeks(_ lower: String) -> Bool {
        ["every 4 weeks", "every four weeks", "4-weekly", "four-weekly", "/4wk", "alle 4 wochen", "toutes les 4 semaines",
         "cada 4 semanas", "4週間ごと", "كل 4 أسابيع"].contains { lower.contains($0) }
    }

    static func extractFrequency(in lower: String) -> BillingFrequency? {
        if lower.contains("/wk") || lower.contains("/week") || lower.contains("per week") || lower.contains("weekly") || lower.contains("every week")
            || lower.contains("pro woche") || lower.contains("par semaine") || lower.contains("semanal") || lower.contains("週額") || lower.contains("أسبوعي") {
            return .weekly
        }
        if lower.contains("/2wk") || lower.contains("every 2 weeks") || lower.contains("biweekly") || lower.contains("bi-weekly") {
            return .biweekly
        }
        if lower.contains("/3mo") || lower.contains("every 3 months") || lower.contains("quarterly") || lower.contains("3 months")
            || lower.contains("every quarter") {
            return .quarterly
        }
        if lower.contains("/6mo") || lower.contains("every 6 months") || lower.contains("semiannual") || lower.contains("6 months") {
            return .semiannual
        }
        if lower.contains("/yr") || lower.contains("/year") || lower.contains("per year") || lower.contains("yearly")
            || lower.contains("every year") || lower.contains("every 12 months") || lower.contains("per annum") || lower.contains("a year")
            || lower.contains("annual") || lower.contains("pro jahr") || lower.contains("par an") || lower.contains("anual")
            || lower.contains("年額") || lower.contains("سنوي") {
            return .yearly
        }
        if lower.contains("/mo") || lower.contains("/month") || lower.contains("per month") || lower.contains("monthly")
            || lower.contains("every month") || lower.contains("a month")
            || lower.contains("1 month") || lower.contains("pro monat") || lower.contains("par mois") || lower.contains("mensual")
            || lower.contains("月額") || lower.contains("شهري") {
            return .monthly
        }
        return nil
    }

    static func isActiveHeader(_ lower: String) -> Bool {
        ["active", "active subscriptions", "actifs", "aktiv", "activas", "有効", "نشطة"].contains(lower.trimmingCharacters(in: .whitespaces))
    }

    static func isInactiveHeader(_ lower: String) -> Bool {
        ["inactive", "expired", "inactive subscriptions", "cancelled", "canceled",
         "inactifs", "abgelaufen", "inactivas", "期限切れ", "منتهية"].contains(lower.trimmingCharacters(in: .whitespaces))
    }

    static func containsExpiryWord(_ lower: String) -> Bool {
        let nonAscii = ["abgelaufen", "expiré", "venció", "期限切れ", "منتهي"]
        if nonAscii.contains(where: { lower.contains($0) }) { return true }
        return lower.range(of: #"\b(?:expired|expires|cancelled|canceled|ended)\b"#, options: .regularExpression) != nil
    }

    static func containsTrialWord(_ lower: String) -> Bool {
        ["free trial", "trial ends", "essai gratuit", "kostenlose testphase", "prueba gratis", "無料トライアル", "تجربة مجانية"].contains { lower.contains($0) }
    }

    static func startsWithDateOrBillingKeyword(_ lower: String) -> Bool {
        let prefixes = ["renews", "renew", "expires", "expired", "trial", "free trial", "total", "subtotal", "tax",
                        "next ", "billed ", "charged ", "due ", "upcoming", "monthly total", "yearly total",
                        // "Then $13.99 per month" under a trial is its price, not a service called "Then" (2026-11-23).
                        "then", "after ", "afterwards", "from ", "per ", "renewal price", "regular price", "new price",
                        "danach", "ensuite", "después", "その後", "ثم"]
        return prefixes.contains { lower.hasPrefix($0) }
    }

    static func isChromeNoise(_ raw: String, lower: String) -> Bool {
        // Time in iOS status bar ("9:41", "10:25 AM")
        if raw.range(of: #"^\d{1,2}:\d{2}(?:\s?[AP]M)?$"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        // Battery % or carrier indicator
        if raw.range(of: #"^\d{1,3}%$"#, options: .regularExpression) != nil { return true }
        if ["5g", "4g", "lte", "wi-fi", "wifi", "sos", "carrier"].contains(lower) { return true }
        if recurringListHeaders.contains(lower.trimmingCharacters(in: .whitespaces)) { return true }
        let chrome = [
            "subscriptions", "settings", "apple account", "apple id", "back", "done", "edit", "search", "cancel",
            "share with family", "share new subscriptions", "renewal receipts", "a receipt will be sent",
            "recurring", "recurring payments", "recurring charges", "upcoming bills", "bills & subscriptions",
            "manage", "see all", "view all", "filter", "sort", "today", "yesterday", "this month", "next month"
        ]
        if chrome.contains(lower) { return true }
        if lower.hasPrefix("a receipt will be sent") || lower.hasPrefix("subscriptions you share") || lower.hasPrefix("automatically share") { return true }
        return false
    }
}
