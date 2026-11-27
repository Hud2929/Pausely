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
        "abos", "daueraufträge", "lastschriften", "abonnements", "prélèvements", "pagos recurrentes", "suscripciones",
        "定期支払い", "サブスクリプション", "المدفوعات المتكررة", "الاشتراكات"
    ]

    /// Explicit Apple Settings › Subscriptions markers (in all six languages).
    static let appleExplicitMarkers: Set<String> = [
        "apple account", "apple id", "share new subscriptions", "renewal receipts", "share with family",
        "edit subscription", "neue abos teilen", "verlängerungsbelege", "abo bearbeiten",
        "partager les nouveaux abonnements", "reçus de renouvellement", "modifier l'abonnement",
        "compartir suscripciones nuevas", "recibos de renovación", "editar suscripción",
        "新しいサブスクリプションを共有", "更新領収書", "サブスクリプションを編集",
        "مشاركة الاشتراكات الجديدة", "إيصالات التجديد", "تعديل الاشتراك"
    ]

    /// Markers that prove the screenshot is from a non-Apple store or a bank/card app.
    static let nonAppleSourceMarkers: [String] = [
        "google play", "play store", "paypal", "prime video channels", "amazon channels",
        "available balance", "current balance", "current account", "checking", "recent transactions",
        "transactions", "card payment", "direct debit", "standing order", "recurring payments"
    ]

    /// Lines that begin alternative plan tiers or footer actions on an Edit Subscription screen.
    static func isSingleSubscriptionScreen(_ lines: [VisualLine]) -> Bool {
        let headers: Set<String> = [
            "edit subscription", "abo bearbeiten", "modifier l'abonnement", "editar suscripción",
            "サブスクリプションを編集", "تعديل الاشتراك"
        ]
        return lines.contains { headers.contains($0.text.lowercased().trimmingCharacters(in: .whitespaces)) }
    }

    static func isEditScreenCutoff(_ lower: String) -> Bool {
        let trimmed = lower.trimmingCharacters(in: .whitespaces)
        let exact: Set<String> = [
            "see all plans", "other plans", "available plans", "options", "cancel subscription", "cancel free trial",
            "alle abos anzeigen", "abo kündigen", "voir tous les forfaits", "annuler l'abonnement",
            "ver todos los planes", "cancelar suscripción", "すべてのプランを表示", "サブスクリプションをキャンセル",
            "عرض جميع الباقات", "إلغاء الاشتراك"
        ]
        if exact.contains(trimmed) { return true }
        return trimmed.hasPrefix("if you cancel") || trimmed.hasPrefix("when you cancel")
            || trimmed.hasPrefix("wenn du kündigst") || trimmed.hasPrefix("si vous résiliez")
            || trimmed.hasPrefix("si cancelas")
    }

    /// Money coming in, never a subscription: a "+" before the amount, or a word that says so.
    static func isIncomeOrTransfer(_ lower: String, inAppleSubscriptions: Bool = false) -> Bool {
        // The "+" stands on its own: in "Disney+ $159.99" it is part of a name.
        if lower.range(of: #"(?<![\p{L}\p{N}])\+\s*(?:(?:[a-z]{1,3})?[€$£¥₹₺₩₽]|[a-z]{3}\s)?\s*\d"#, options: .regularExpression) != nil {
            return true
        }
        // Word-boundary ASCII words so "Pinterest" does not match "interest".
        if lower.range(of: #"\b(?:salary|payroll|paycheck|deposit|refund|transfer|interest|cashback|reimbursement)\b"#,
                       options: .regularExpression) != nil {
            return true
        }
        if !inAppleSubscriptions {
            if lower.range(of: #"\b(?:available\s+balance|current\s+balance|account\s+balance|total\s+balance|ending\s+balance|balance|available)\b"#,
                           options: .regularExpression) != nil {
                return true
            }
        }
        let localized = [
            "gehalt", "lohn", "überweisung", "erstattung", "salaire", "virement", "remboursement",
            "nómina", "salario", "transferencia", "reembolso", "給与", "振込", "返金", "راتب", "تحويل", "استرداد"
        ]
        return localized.contains { lower.contains($0) }
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
         "tous les 2 mois", "cada 2 meses", "2か月ごと", "2ヶ月ごと", "كل شهرين"].contains { lower.contains($0) }
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

    private static let trialDurationStripRegex = try? NSRegularExpression(
        pattern: #"(?i)(?:\b(?:free\s+(?:for\s+)?)?\d+\s*[-]?\s*(?:days?|weeks?|wks?|months?|mos?|years?|yrs?)\s+free\b|\bfree\s+for\s+\d+\s*(?:days?|weeks?|months?|years?)\b|\b(?:free\s+)?trial\s*[:\-–]\s*\d+\s*(?:days?|weeks?|wks?|months?|mos?|years?|yrs?)\b|\b\d+\s*(?:mois\s+offerts?|monate\s+kostenlos|meses\s+gratis)\b|\d+\s*(?:か月|ヶ月|週間|日間)\s*無料)"#
    )

    static func extractFrequency(in rawLower: String) -> BillingFrequency? {
        if isEveryFourWeeks(rawLower) || isEveryTwoMonths(rawLower) { return nil }
        // Strip trial-length phrases ("3 months free", "1 month free") so a free-trial banner never
        // sets the paid billing frequency to quarterly or monthly.
        let stripped = trialDurationStripRegex.map {
            $0.stringByReplacingMatches(in: rawLower, range: NSRange(location: 0, length: (rawLower as NSString).length), withTemplate: " ")
        } ?? rawLower
        // Normalize OCR spaces around slashes ("$19.99 / month" -> "$19.99/month").
        let lower = stripped.replacingOccurrences(of: #"\s*/\s*"#, with: "/", options: .regularExpression)

        // Check biweekly BEFORE weekly ("biweekly" contains "weekly").
        if lower.range(of: #"/2wk(?![a-z])"#, options: .regularExpression) != nil
            || lower.contains("/2 weeks") || lower.contains("every 2 weeks")
            || lower.contains("biweekly") || lower.contains("bi-weekly") || lower.contains("fortnightly")
            || lower.contains("alle 2 wochen") || lower.contains("toutes les 2 semaines")
            || lower.contains("cada 2 semanas") || lower.contains("2週間") || lower.contains("كل أسبوعين") {
            return .biweekly
        }
        if lower.range(of: #"/(?:wk|week|w)(?![a-z])"#, options: .regularExpression) != nil
            || lower.contains("per week") || lower.contains("weekly")
            || lower.contains("every week") || lower.contains("a week")
            || lower.contains("/woche") || lower.contains("pro woche") || lower.contains("wöchentlich")
            || lower.contains("/semaine") || lower.contains("par semaine") || lower.contains("hebdomadaire")
            || lower.contains("/semana") || lower.contains("semanal") || lower.contains("cada semana")
            || lower.contains("/週") || lower.contains("週額") || lower.contains("毎週")
            || lower.contains("/أسبوع") || lower.contains("أسبوعي") || lower.contains("في الأسبوع") {
            return .weekly
        }
        if lower.range(of: #"/3mo(?![a-z])"#, options: .regularExpression) != nil
            || lower.contains("/3 months") || lower.contains("every 3 months")
            || lower.contains("quarterly") || lower.contains("3 months") || lower.contains("every quarter")
            || lower.contains("vierteljährlich") || lower.contains("alle 3 monate") || lower.contains("quartalsweise")
            || lower.contains("trimestriel") || lower.contains("tous les 3 mois")
            || lower.contains("trimestral") || lower.contains("cada 3 meses")
            || lower.contains("3か月") || lower.contains("3ヶ月") || lower.contains("四半期")
            || lower.contains("ربع سنوي") || lower.contains("كل 3 أشهر") {
            return .quarterly
        }
        // Check semiannual BEFORE yearly ("semi-annual" and "biannual" contain "annual").
        if lower.range(of: #"/6mo(?![a-z])"#, options: .regularExpression) != nil
            || lower.contains("/6 months") || lower.contains("every 6 months")
            || lower.contains("semiannual") || lower.contains("semi-annual") || lower.contains("biannual")
            || lower.contains("bi-annual") || lower.contains("6 months")
            || lower.contains("halbjährlich") || lower.contains("alle 6 monate")
            || lower.contains("semestriel") || lower.contains("tous les 6 mois")
            || lower.contains("semestral") || lower.contains("cada 6 meses")
            || lower.contains("6か月") || lower.contains("6ヶ月") || lower.contains("半年")
            || lower.contains("نصف سنوي") || lower.contains("كل 6 أشهر") {
            return .semiannual
        }
        if lower.range(of: #"/(?:yr|year|y|jahr|an|année|año)(?![a-zà-ÿ])"#, options: .regularExpression) != nil
            || lower.contains("/1 year") || lower.contains("per year")
            || lower.contains("per yr") || lower.contains("yearly") || lower.contains("every year")
            || lower.contains("every 12 months") || lower.contains("per annum") || lower.contains("a year")
            || lower.contains("annual") || lower.contains("1 year")
            || lower.contains("pro jahr") || lower.contains("jährlich")
            || lower.contains("par an") || lower.contains("annuel")
            || lower.contains("al año") || lower.contains("por año") || lower.contains("cada año") || lower.contains("anual")
            || lower.contains("/年") || lower.contains("年額") || lower.contains("年間") || lower.contains("毎年")
            || lower.contains("/سنة") || lower.contains("في السنة") || lower.contains("سنوي") {
            return .yearly
        }
        if lower.range(of: #"/(?:mo|month|m|monat|mois|mes)(?![a-zà-ÿ])"#, options: .regularExpression) != nil
            || lower.contains("per month") || lower.contains("monthly")
            || lower.contains("every month") || lower.contains("a month") || lower.contains("1 month")
            || lower.contains("pro monat") || lower.contains("monatlich")
            || lower.contains("par mois") || lower.contains("mensuel")
            || lower.contains("al mes") || lower.contains("por mes") || lower.contains("cada mes") || lower.contains("mensual")
            || lower.contains("/月") || lower.contains("月額") || lower.contains("毎月") || lower.contains("1か月") || lower.contains("1ヶ月")
            || lower.contains("/شهر") || lower.contains("في الشهر") || lower.contains("شهري") {
            return .monthly
        }
        return nil
    }

    static func isActiveHeader(_ lower: String) -> Bool {
        ["active", "active subscriptions", "actifs", "aktiv", "activas", "有効", "نشطة"].contains(lower.trimmingCharacters(in: .whitespaces))
    }

    static func isInactiveHeader(_ lower: String) -> Bool {
        ["inactive", "expired", "inactive subscriptions", "cancelled", "canceled",
         "inactifs", "inaktiv", "abgelaufen", "gekündigt", "inactivas", "期限切れ", "منتهية", "غير نشطة", "ملغاة"]
            .contains(lower.trimmingCharacters(in: .whitespaces))
    }

    static func containsPastExpiryWord(_ lower: String) -> Bool {
        let localized = [
            "abgelaufen", "gekündigt", "beendet", "expiré", "résilié", "annulé",
            "venció", "caducó", "caducada", "expiró", "cancelada", "cancelado",
            "期限切れ", "解約済み", "キャンセル済み", "منتهي", "ملغى", "ملغاة"
        ]
        if localized.contains(where: { lower.contains($0) }) { return true }
        return lower.range(of: #"\b(?:expired|cancelled|canceled|ended)\b"#, options: .regularExpression) != nil
    }

    static func containsExpiryWord(_ lower: String) -> Bool {
        if containsPastExpiryWord(lower) { return true }
        return lower.range(of: #"\bexpires\b"#, options: .regularExpression) != nil
    }

    static func containsTrialWord(_ lower: String) -> Bool {
        ["free trial", "trial ends", "trial expires", "offer expires", "free period expires", "free period ends",
         "essai gratuit", "l'essai expire", "essai expire", "kostenlose testphase", "gratiszeitraum", "testphase läuft ab",
         "prueba gratis", "prueba gratuita", "prueba vence", "無料トライアル", "無料体験",
         "تجربة مجانية", "فترة تجريبية", "تنتهي التجربة", "ينتهي العرض"]
            .contains { lower.contains($0) }
    }

    static func startsWithDateOrBillingKeyword(_ lower: String) -> Bool {
        let trimmed = lower.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactPromo: Set<String> = [
            "was", "now", "save", "only", "just", "then", "from", "regular", "promo", "intro", "instead"
        ]
        if exactPromo.contains(trimmed) { return true }
        let prefixes = ["renews", "renew", "expires", "expired", "trial", "free trial", "total", "subtotal", "tax",
                        "next ", "billed ", "charged ", "due ", "upcoming", "monthly total", "yearly total",
                        "estimated total", "upcoming total", "total spent",
                        // "Then $13.99 per month" / "Was $22.99 Now $15.49" are price lines, not service names.
                        "then ", "was ", "now ", "save ", "only ", "just ", "starting ", "intro ",
                        "after ", "afterwards", "from ", "per ", "renewal price", "regular price", "new price",
                        "danach", "ensuite", "después", "その後", "ثم",
                        "verlängert", "se renouvelle", "se renueva", "يتجدد"]
        return prefixes.contains { trimmed.hasPrefix($0) }
    }

    static func isChromeNoise(_ raw: String, lower: String) -> Bool {
        let trimmed = lower.trimmingCharacters(in: .whitespaces)
        // Time in iOS status bar ("9:41", "10:25 AM")
        if raw.range(of: #"^\d{1,2}:\d{2}(?:\s?[AP]M)?$"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        // Battery % or carrier indicator
        if raw.range(of: #"^\d{1,3}%$"#, options: .regularExpression) != nil { return true }
        if ["5g", "4g", "lte", "wi-fi", "wifi", "sos", "carrier"].contains(trimmed) { return true }
        if recurringListHeaders.contains(trimmed) || appleExplicitMarkers.contains(trimmed) { return true }
        let chrome: Set<String> = [
            "subscriptions", "my subscriptions", "manage subscriptions", "apple subscriptions",
            "settings", "back", "done", "edit", "search", "cancel", "cancel subscription", "cancel free trial",
            "see all plans", "other plans", "available plans", "change plan", "manage subscription", "options",
            "resubscribe", "billing history", "payment method", "about subscriptions and privacy",
            "transactions", "recent transactions", "all transactions", "current account", "checking", "savings",
            "statement", "account summary", "monthly total", "yearly total", "upcoming total",
            "manage", "see all", "view all", "filter", "sort", "today", "yesterday", "this month", "next month",
            "einstellungen", "réglages", "configuración", "設定", "الإعدادات"
        ]
        if chrome.contains(trimmed) { return true }
        if trimmed.hasPrefix("a receipt will be sent") || trimmed.hasPrefix("subscriptions you share")
            || trimmed.hasPrefix("automatically share") || trimmed.hasPrefix("if you cancel") { return true }
        return false
    }
}
