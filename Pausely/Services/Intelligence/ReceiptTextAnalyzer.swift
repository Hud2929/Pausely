import Foundation

// MARK: - Receipt Text Analyzer
/// Pure, on-device text analysis for a single email. No network, no storage, no UI.
/// It answers: "what was charged, and does the language say recurring subscription or one-time order?"
enum ReceiptTextAnalyzer {

    // MARK: Types

    struct Money: Equatable {
        let amount: Decimal
        /// ISO code when the email states it explicitly (C$, CAD, €, …). nil for a bare "$".
        let currency: String?
    }

    struct LanguageFlags: Equatable {
        var renewal = false
        var oneTime = false
        var trialStart = false
        var trialEnding = false
        var priceChange = false
        var cancelled = false
        var marketing = false
        var refund = false
        var paymentFailed = false
    }

    struct Analysis: Equatable {
        var money: Money?
        var flags: LanguageFlags
        var frequency: BillingFrequency?
        var trialDays: Int?
        var productHint: String?
        var kind: EmailKind
        /// The price after an introductory one ("$134.99 for 1 year, then $269.99/year").
        var nextAmount: Decimal? = nil
    }

    // MARK: Entry point

    static func analyze(subject: String, body: String, promotional: Bool = false) -> Analysis {
        let cappedBody = String(body.prefix(24_000))
        let period = servicePeriod(in: cappedBody)
        let flags = languageFlags(subject: subject, body: cappedBody, promotional: promotional, servicePeriod: period != nil)
        let money = extractChargeAmount(subject: subject, body: cappedBody)
        let frequency = explicitFrequency(subject: subject, body: cappedBody) ?? period
        let trialDays = extractTrialDays(subject + " " + cappedBody)
        var product = productHint(subject: subject, body: cappedBody)
        // A brand mentioned only in passing (e.g. "DashPass savings" on an order) must not rename that order.
        if product != nil, productHint(subject: subject, body: "") == nil, flags.oneTime || !flags.renewal { product = nil }
        let kind = classify(flags: flags, hasAmount: money != nil)
        var next = introductoryPriceEnd(in: subject + "\n" + cappedBody)
        if let current = money?.amount, let later = next, later <= current { next = nil }
        return Analysis(money: money, flags: flags, frequency: frequency,
                        trialDays: trialDays, productHint: product, kind: kind, nextAmount: next)
    }

    // MARK: Classification

    static func classify(flags: LanguageFlags, hasAmount: Bool) -> EmailKind {
        if flags.cancelled { return .cancellation }
        // A declined card is not a charge, whatever amount the email mentions.
        if flags.paymentFailed { return .paymentFailed }
        if flags.trialEnding { return .trialEnding }
        if flags.priceChange && !flags.refund { return .priceChange }
        if flags.trialStart && !hasAmount { return .trialStarted }
        if flags.trialStart && flags.renewal && !flags.oneTime { return .trialStarted }
        if hasAmount && !flags.refund { return .charge }
        if flags.renewal && hasAmount { return .renewalNotice }
        return .other
    }

    // MARK: Language flags

    static func languageFlags(subject: String, body: String, promotional: Bool, servicePeriod: Bool = false) -> LanguageFlags {
        let subjectLower = subject.lowercased()
        let text = (subjectLower + "\n" + body.lowercased())
        var flags = LanguageFlags()

        flags.renewal = containsAny(text, [
            "auto-renew", "auto renew", "autorenew", "automatically renew", "will renew", "renews", "renewed on", "renews automatically",
            "renewal date", "next billing date", "next payment", "next charge", "your next bill", "billing period",
            "your subscription", "your membership", "recurring", "billed monthly", "billed annually", "billed yearly",
            "subscription receipt", "membership fee", "subscription renewal", "plan renews", "per month", "/month", "/mo ",
            "per year", "/year", "monthly plan", "annual plan", "monthly subscription", "annual subscription"
        ]) || containsAny(text, [
            // Français
            "renouvelle", "renouvellement", "votre abonnement", "abonnement mensuel", "abonnement annuel", "par mois", "/mois",
            "par an", "/an ", "prochain paiement", "prochaine facturation", "facturé mensuellement", "facturé annuellement",
            "paiement récurrent", "votre adhésion",
            // Español
            "se renovará", "renovación", "tu suscripción", "su suscripción", "suscripción mensual", "suscripción anual",
            "por mes", "al mes", "por año", "próximo pago", "próxima factura", "pago recurrente", "tu membresía",
            // Deutsch
            "verlängert sich", "automatische verlängerung", "ihr abonnement", "dein abonnement", "monatlich", "pro monat",
            "pro jahr", "jährlich", "nächste zahlung", "nächste abrechnung", "ihre mitgliedschaft"
        ]) || containsAny(text, [
            // Italiano
            "si rinnova", "rinnovo automatico", "il tuo abbonamento", "al mese", "all'anno", "prossimo pagamento",
            "abbonamento mensile", "abbonamento annuale",
            // Português
            "renova automaticamente", "renovação automática", "sua assinatura", "por mês", "por ano", "próximo pagamento",
            "assinatura mensal", "assinatura anual",
            // 日本語
            "自動更新", "自動的に更新", "定期購入", "サブスクリプション", "月額", "年額", "毎月", "次回の更新", "次回のお支払い", "更新日",
            // العربية
            "يتجدد تلقائيًا", "يتجدد تلقائيا", "التجديد التلقائي", "اشتراكك", "شهريًا", "شهريا", "سنويًا", "الدفعة التالية", "تاريخ التجديد",
            // 한국어
            "자동 갱신", "자동갱신", "정기 결제", "정기결제", "구독", "매월", "다음 결제"
        ])

        // One-time words come in two strengths. Receipts for real subscriptions routinely carry the weak ones
        // (Stripe's "Qty 1", Google Play's "Order number", "free shipping" in a Prime welcome), so those only
        // count when nothing in the email says it renews.
        let strongOneTime = containsAny(text, [
            "order confirmation", "shipped", "tracking number", "out for delivery", "has been delivered", "was delivered",
            "thanks for your order", "thank you for your order", "pickup", "pick-up", "e-ticket", "your tickets", "ticket order",
            "reservation", "booking confirmation", "itinerary", "boarding", "check-in", "gift card", "donation", "tip for",
            "your tip", "your ride", "trip receipt", "your trip", "trip with", "thanks for riding", "driver", "your parking",
            "parking session", "your delivery", "order from", "rent a video", "your rental", "unexpired rentals", "you rented",
            "purchase details",
            // Money transfers and payouts are not subscriptions ("You received this email because…" is a footer, not money)
            "e-transfer", "etransfer", "sent you money", "sent you a payment", "sent you $", "you received a payment",
            "you received money", "you've received a payment", "money request", "has deposited", "direct deposit", "payout",
            // Français
            "votre commande", "expédié", "billets", "réservation", "merci pour votre achat",
            // Español
            "tu pedido", "su pedido", "entradas", "reserva", "gracias por tu compra",
            // Deutsch
            "ihre bestellung", "deine bestellung", "versandt", "buchungsbestätigung"
        ])
        let weakOneTime = containsAny(text, [
            "order #", "order number", "order no", "order id", "your order", "shipping", "item(s)", "qty", "quantity",
            "delivery fee", "numéro de commande", "livraison", "número de pedido", "envío", "bestellnummer", "lieferung"
        ])
        let statesRenewal = servicePeriod || containsAny(text, [
            "auto-renew", "auto renew", "autorenew", "automatically renew", "renews automatically", "renewed automatically",
            "will renew", "will be renewed", "renews ", "renews:", "until canceled", "until cancelled", "unless canceled", "unless cancelled",
            "next renewal", "renewal date", "membership renews", "plan renews", "subscription renews", "recurring payment",
            "recurring charge", "billing period", "se renouvelle", "se renovará", "verlängert sich", "si rinnova",
            "renova automaticamente", "自動更新", "자동 갱신"
        ])
        flags.oneTime = strongOneTime || (weakOneTime && !statesRenewal)
        if servicePeriod { flags.renewal = true }

        flags.trialEnding = containsAny(text, [
            "trial ends in", "trial ends on", "trial ends tomorrow", "trial ends today", "trial is ending", "trial will end",
            "trial expires", "trial ending", "last day of your trial", "free trial ends", "free trial is ending",
            "trial is almost over", "trial is about to end", "trial ends soon",
            "l'essai se termine", "votre essai gratuit se termine", "tu prueba gratuita termina", "ihre testphase endet",
            "la prova gratuita termina", "seu teste grátis termina", "sua avaliação gratuita termina",
            "無料体験は", "無料期間が終了", "無料体験の終了", "トライアル終了", "تنتهي الفترة التجريبية", "무료 체험이 종료"
        ])

        flags.trialStart = flags.trialEnding || containsAny(text, [
            "free trial", "trial has started", "your trial", "trial begins", "start your trial", "trial period",
            "welcome to your trial", "trial started", "days free",
            "essai gratuit", "prueba gratuita", "kostenlose testphase", "kostenloser test",
            "prova gratuita", "teste grátis", "avaliação gratuita", "無料体験", "無料トライアル", "お試し期間",
            "الفترة التجريبية", "تجربة مجانية", "무료 체험"
        ])

        flags.priceChange = containsAny(text, [
            "price change", "price increase", "price is changing", "price will change", "new price", "increase in price",
            "adjusting our prices", "pricing update", "updating our prices", "price adjustment", "prices are changing",
            "increase the price", "increasing the price", "rate increase",
            "changement de prix", "augmentation de prix", "nouveau prix", "cambio de precio", "aumento de precio",
            "preisänderung", "preiserhöhung", "aumento di prezzo", "aumento de preço", "料金改定", "価格改定",
            "料金の変更", "値上げ", "تغيير السعر", "زيادة السعر", "가격 인상", "요금 변경"
        ])

        // Specific phrases only: every subscription email has a "cancellation policy" or "cancel anytime" line.
        flags.cancelled = containsAny(text, [
            "subscription has been cancelled", "subscription has been canceled", "subscription was cancelled",
            "subscription was canceled", "we've cancelled your", "we've canceled your", "cancellation confirmation",
            "you've cancelled", "you've canceled", "your cancellation is confirmed", "your cancellation has been",
            "confirming your cancellation", "membership has ended", "subscription has ended", "subscription expired",
            "won't be charged again", "will not be charged again", "membership has been cancelled",
            "membership has been canceled", "your plan has been cancelled", "your plan has been canceled",
            "sorry to see you go", "we're sorry to see you go", "will not renew", "won't renew", "will no longer renew",
            "will be cancelled on", "will be canceled on", "subscription will be cancelled", "subscription will be canceled",
            "was recently cancelled", "was recently canceled", "opted out of the automatic renewal",
            "opted out of automatic renewal", "opted out of auto-renewal", "access to this subscription will end", "auto-renew is off",
            "auto-renew has been turned off", "turned off auto-renew", "your subscription will end", "membership will end",
            "abonnement a été annulé", "votre abonnement est annulé", "tu suscripción ha sido cancelada",
            "su suscripción ha sido cancelada", "ihr abonnement wurde gekündigt", "dein abonnement wurde gekündigt",
            "il tuo abbonamento è stato annullato", "sua assinatura foi cancelada", "解約が完了", "解約手続きが完了",
            "キャンセルが完了", "تم إلغاء اشتراكك", "구독이 취소"
        ])

        // "Refund Policy" and "Need a refund?" sit in the footer of ordinary receipts; only an actual refund counts.
        flags.refund = containsAny(text, [
            "refunded", "refund of", "refund for your", "refund has been", "refund was", "refund issued", "refund processed",
            "issued a refund", "issued you a refund", "processed a refund", "your refund", "credit issued", "chargeback",
            "reversal", "remboursé", "votre remboursement", "reembolsado", "tu reembolso", "erstattet", "ihre erstattung",
            "rückerstattung wurde", "rimborsato", "返金しました", "返金いたしました", "تم استرداد", "환불되었습니다", "환불 완료"
        ])

        flags.paymentFailed = containsAny(text, [
            "payment was unsuccessful", "payment failed", "payment has failed", "payment didn't go through",
            "payment did not go through", "unable to charge", "were unable to process your payment", "couldn't process your payment",
            "could not process your payment", "weren't able to charge", "were not able to charge", "couldn't charge",
            "could not charge", "payment was declined", "card was declined", "payment declined", "payment method was declined",
            "le paiement a échoué", "paiement refusé", "échec du paiement", "el pago falló", "pago rechazado",
            "no pudimos procesar tu pago", "zahlung fehlgeschlagen", "zahlung abgelehnt", "pagamento non riuscito",
            "pagamento recusado", "o pagamento falhou", "お支払いに失敗", "決済に失敗", "فشل الدفع", "결제 실패", "결제에 실패"
        ])

        flags.marketing = promotional || containsAny(subjectLower, [
            "% off", "sale", "limited time", "special offer", "exclusive offer", "newsletter", "deal of", "save up to",
            "shop now", "last chance", "don't miss", "flash sale", "black friday", "cyber monday", "new arrivals"
        ])

        return flags
    }

    // MARK: Amount extraction

    private static let currencyTokens: [(String, String?)] = [
        ("c$", "CAD"), ("ca$", "CAD"), ("cad", "CAD"), ("us$", "USD"), ("usd", "USD"), ("au$", "AUD"), ("aud", "AUD"),
        ("nz$", "NZD"), ("nzd", "NZD"), ("£", "GBP"), ("gbp", "GBP"), ("€", "EUR"), ("eur", "EUR"), ("¥", "JPY"),
        ("jpy", "JPY"), ("₹", "INR"), ("inr", "INR"), ("chf", "CHF"), ("mxn", "MXN"), ("brl", "BRL"), ("sek", "SEK"),
        ("nok", "NOK"), ("dkk", "DKK"), ("$", nil)
    ]

    private static let amountRegex: NSRegularExpression? = {
        let symbols = "(?:C\\$|CA\\$|US\\$|AU\\$|NZ\\$|CAD|USD|AUD|NZD|GBP|EUR|JPY|INR|CHF|MXN|BRL|SEK|NOK|DKK|£|€|¥|₹|\\$)"
        let number = "(\\d{1,3}(?:,\\d{3})+(?:\\.\\d{2})|\\d+(?:\\.\\d{2}))"
        let pattern = "(?i)(?:(\(symbols))\\s?\(number)|\(number)\\s?(CAD|USD|AUD|NZD|GBP|EUR|CHF)\\b)"
        return try? NSRegularExpression(pattern: pattern)
    }()

    /// Currencies written without decimals: "¥990", "￥1,200", "990円", "₩9,900", "9,900원".
    private static let wholeUnitRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(?:(¥|￥|JPY|₩|KRW)\\s?(\\d{1,3}(?:,\\d{3})+|\\d+)(?![.,]\\d)|(\\d{1,3}(?:,\\d{3})+|\\d+)\\s?(円|원))",
        options: [.caseInsensitive])

    private static let euroCommaRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: "(\\d{1,3}(?:[. \\x{00A0}]\\d{3})*,\\d{2})\\s?(€|EUR|\\$|CAD|USD)", options: [.caseInsensitive])

    private static let positiveContext: [(String, Int)] = [
        ("amount charged", 4), ("amount paid", 4), ("amount due", 3), ("you paid", 4), ("you were charged", 4),
        ("you've been charged", 4), ("we charged", 4), ("charged", 3), ("billed", 3), ("payment of", 3), ("your payment", 2),
        ("total", 2), ("price", 1), ("per month", 2), ("/month", 2), ("/mo", 2), ("per year", 2), ("/year", 2),
        ("monthly", 1), ("annual", 1), ("subscription", 1), ("plan", 1), ("renew", 1), ("membership", 1),
        ("montant", 3), ("facturé", 3), ("payé", 3), ("abonnement", 1), ("importe", 3), ("cobrado", 3), ("pagado", 3),
        ("suscripción", 1), ("betrag", 3), ("gesamt", 2), ("abgerechnet", 3), ("abonnement", 1),
        ("請求額", 4), ("ご請求", 4), ("お支払い", 3), ("支払金額", 4), ("合計", 2), ("月額", 2), ("年額", 2),
        ("결제 금액", 4), ("결제금액", 4), ("합계", 2)
    ]

    private static let negativeContext: [(String, Int)] = [
        ("subtotal", 3), ("save", 4), (" off", 3), ("discount", 3), ("coupon", 3), ("was ", 3), ("regularly", 3),
        ("list price", 3), ("gift card", 3), ("credit", 2), ("points", 3), ("tax", 3), ("shipping", 3), ("refund", 5),
        ("up to", 3), ("starting at", 3), ("starts at", 3), ("from $", 3), ("limit", 2), ("delivery fee", 2), ("service fee", 2), ("booking fee", 2), ("processing fee", 2), ("tip", 2),
        ("balance", 2), ("rewards", 3), ("cashback", 3), ("minimum", 2), ("spend $", 4), ("spend", 2), ("over $", 3),
        ("rabais", 3), ("économ", 3), ("livraison", 2), ("descuento", 3), ("ahorra", 3), ("rabatt", 3), ("sparen", 3),
        ("割引", 3), ("ポイント", 3), ("送料", 2), ("値引", 3), ("할인", 3), ("포인트", 3)
    ]

    /// Picks the amount that was actually charged, not the first dollar figure in the email.
    static func extractChargeAmount(subject: String, body: String) -> Money? {
        let text = subject + "\n" + body
        let ns = text as NSString
        var candidates: [(money: Money, score: Int, position: Int)] = []

        func consider(amountString: String, currency: String?, range: NSRange, decimalComma: Bool = false) {
            var cleaned = amountString
            if decimalComma {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "\u{00A0}", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
            // Yen and won amounts run into the tens of thousands for ordinary yearly plans.
            let ceiling: Decimal = (currency == "JPY" || currency == "KRW") ? 2_000_000 : 10_000
            guard let value = Decimal(string: cleaned), value > 0, value < ceiling else { return }

            let beforeStart = max(0, range.location - 70)
            let before = ns.substring(with: NSRange(location: beforeStart, length: range.location - beforeStart)).lowercased()
            let afterEnd = min(ns.length, range.location + range.length + 40)
            let after = ns.substring(with: NSRange(location: range.location + range.length, length: afterEnd - (range.location + range.length))).lowercased()
            let context = before + "|" + after

            var score = 0
            for (word, weight) in positiveContext where context.contains(word) { score += weight }
            for (word, weight) in negativeContext where context.contains(word) { score -= weight }
            // "total" inside "subtotal" must not count as positive
            if context.contains("subtotal") { score -= 2 }
            // "$134.99 for 1 year, then $269.99/year": the price after "then" is a later one, not today's charge.
            if before.range(of: #"(then|after that|thereafter|afterwards)\W{0,3}[a-z$€£¥]{0,3}\s?$"#, options: .regularExpression) != nil {
                score -= 6
            }

            var resolvedCurrency = currency
            if resolvedCurrency == nil {
                let trailing = after.trimmingCharacters(in: .whitespaces).prefix(4).uppercased()
                for code in ["USD", "CAD", "AUD", "GBP", "EUR", "NZD", "CHF"] where trailing.hasPrefix(code) { resolvedCurrency = code }
            }
            candidates.append((Money(amount: value, currency: resolvedCurrency), score, range.location))
        }

        let full = NSRange(location: 0, length: ns.length)

        amountRegex?.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match else { return }
            if match.range(at: 1).location != NSNotFound, match.range(at: 2).location != NSNotFound {
                let symbol = ns.substring(with: match.range(at: 1))
                let number = ns.substring(with: match.range(at: 2))
                consider(amountString: number, currency: currencyCode(forToken: symbol), range: match.range)
            } else if match.range(at: 3).location != NSNotFound, match.range(at: 4).location != NSNotFound {
                let number = ns.substring(with: match.range(at: 3))
                let code = ns.substring(with: match.range(at: 4)).uppercased()
                consider(amountString: number, currency: code, range: match.range)
            }
        }

        wholeUnitRegex?.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match else { return }
            if match.range(at: 1).location != NSNotFound, match.range(at: 2).location != NSNotFound {
                let symbol = ns.substring(with: match.range(at: 1)).uppercased()
                let code = (symbol == "₩" || symbol == "KRW") ? "KRW" : "JPY"
                consider(amountString: ns.substring(with: match.range(at: 2)), currency: code, range: match.range)
            } else if match.range(at: 3).location != NSNotFound, match.range(at: 4).location != NSNotFound {
                let code = ns.substring(with: match.range(at: 4)) == "원" ? "KRW" : "JPY"
                consider(amountString: ns.substring(with: match.range(at: 3)), currency: code, range: match.range)
            }
        }

        euroCommaRegex?.enumerateMatches(in: text, range: full) { match, _, _ in
            guard let match, match.range(at: 1).location != NSNotFound else { return }
            let symbol = ns.substring(with: match.range(at: 2)).uppercased()
            let code: String? = (symbol == "€" || symbol == "EUR") ? "EUR" : (symbol == "$" ? nil : symbol)
            consider(amountString: ns.substring(with: match.range(at: 1)), currency: code, range: match.range, decimalComma: true)
        }

        guard !candidates.isEmpty else { return nil }
        // Highest score wins; on ties prefer the later one ("Total" sits at the bottom of receipts).
        let best = candidates.max { lhs, rhs in
            lhs.score == rhs.score ? lhs.position < rhs.position : lhs.score < rhs.score
        }
        guard let best, best.score >= 0 else { return nil }
        return best.money
    }

    static func currencyCode(forToken token: String) -> String? {
        let lower = token.lowercased()
        return currencyTokens.first { $0.0 == lower }?.1 ?? nil
    }

    // MARK: Frequency

    /// Only returns a frequency when the email states one clearly. The engine prefers real charge dates over this.
    static func explicitFrequency(subject: String, body: String) -> BillingFrequency? {
        let text = (subject + " " + body.prefix(8_000)).lowercased()
        var found: [BillingFrequency] = []
        if containsAny(text, ["billed monthly", "per month", "/month", "/mo ", "every month", "monthly plan", "monthly subscription", "monthly membership"]) { found.append(.monthly) }
        if containsAny(text, ["billed annually", "billed yearly", "per year", "/year", "every year", "annual plan", "yearly plan", "annual subscription", "annual membership", "yearly subscription"]) { found.append(.yearly) }
        if containsAny(text, ["per week", "/week", "every week", "weekly subscription", "billed weekly"]) { found.append(.weekly) }
        if containsAny(text, ["quarterly", "every 3 months", "every three months"]) { found.append(.quarterly) }
        if containsAny(text, ["every 6 months", "every six months", "semi-annual", "semiannual"]) { found.append(.semiannual) }
        return found.count == 1 ? found.first : nil
    }

    /// The billing period printed on invoices ("Oct 20–Nov 20, 2026", "Sep 26, 2025 – Sep 26, 2026",
    /// "2026-10-20 – 2026-11-20"). Stripe, Paddle and most SaaS billing systems print it on every
    /// subscription invoice, and never on a one-off purchase. Trial periods are ignored.
    static func servicePeriod(in text: String) -> BillingFrequency? {
        let sample = String(text.prefix(12_000))
        let ns = sample as NSString
        let month = "(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\\.?"
        let dash = "\\s*(?:–|—|-|to|through|until)\\s*"
        let patterns: [(String, (NSTextCheckingResult) -> (DateComponents, DateComponents)?)] = [
            // Oct 20–Nov 20, 2026 · Oct 20, 2026 – Nov 20, 2026
            ("\(month)\\s+(\\d{1,2})(?:,?\\s+(\\d{4}))?\(dash)\(month)\\s+(\\d{1,2}),?\\s+(\\d{4})", { match in
                let startMonth = monthNumber(ns.substring(with: match.range(at: 1)))
                let endMonth = monthNumber(ns.substring(with: match.range(at: 4)))
                guard let startMonth, let endMonth,
                      let startDay = Int(ns.substring(with: match.range(at: 2))),
                      let endDay = Int(ns.substring(with: match.range(at: 5))),
                      let endYear = Int(ns.substring(with: match.range(at: 6))) else { return nil }
                let startYear = match.range(at: 3).location != NSNotFound
                    ? Int(ns.substring(with: match.range(at: 3))) ?? endYear
                    : (startMonth > endMonth ? endYear - 1 : endYear)
                return (DateComponents(year: startYear, month: startMonth, day: startDay),
                        DateComponents(year: endYear, month: endMonth, day: endDay))
            }),
            // 20 Oct – 20 Nov 2026 · 20 Oct 2026 – 20 Nov 2026
            ("(\\d{1,2})\\s+\(month)(?:\\s+(\\d{4}))?\(dash)(\\d{1,2})\\s+\(month)\\s+(\\d{4})", { match in
                let startMonth = monthNumber(ns.substring(with: match.range(at: 2)))
                let endMonth = monthNumber(ns.substring(with: match.range(at: 5)))
                guard let startMonth, let endMonth,
                      let startDay = Int(ns.substring(with: match.range(at: 1))),
                      let endDay = Int(ns.substring(with: match.range(at: 4))),
                      let endYear = Int(ns.substring(with: match.range(at: 6))) else { return nil }
                let startYear = match.range(at: 3).location != NSNotFound
                    ? Int(ns.substring(with: match.range(at: 3))) ?? endYear
                    : (startMonth > endMonth ? endYear - 1 : endYear)
                return (DateComponents(year: startYear, month: startMonth, day: startDay),
                        DateComponents(year: endYear, month: endMonth, day: endDay))
            }),
            // 2026-10-20 – 2026-11-20
            ("(\\d{4})\\s?-\\s?(\\d{2})\\s?-\\s?(\\d{2})\(dash)(\\d{4})\\s?-\\s?(\\d{2})\\s?-\\s?(\\d{2})", { match in
                let values = (1...6).compactMap { Int(ns.substring(with: match.range(at: $0))) }
                guard values.count == 6 else { return nil }
                return (DateComponents(year: values[0], month: values[1], day: values[2]),
                        DateComponents(year: values[3], month: values[4], day: values[5]))
            })
        ]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        for (pattern, read) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: sample, range: NSRange(location: 0, length: ns.length)) {
                let lead = ns.substring(with: NSRange(location: max(0, match.range.location - 40),
                                                      length: min(40, match.range.location))).lowercased()
                if ["trial", "essai", "prueba", "testphase", "testzeitraum", "prova", "teste", "体験"].contains(where: lead.contains) { continue }
                guard let (startParts, endParts) = read(match),
                      let start = calendar.date(from: startParts), let end = calendar.date(from: endParts),
                      let days = calendar.dateComponents([.day], from: start, to: end).day else { continue }
                switch days {
                case 27...32: return .monthly
                case 84...93: return .quarterly
                case 178...186: return .semiannual
                case 360...367: return .yearly
                default: continue
                }
            }
        }
        return nil
    }

    private static func monthNumber(_ token: String) -> Int? {
        let names = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        let prefix = String(token.lowercased().prefix(3))
        return names.firstIndex(of: prefix).map { $0 + 1 }
    }

    /// "…, then $269.99/year" → 269.99: what an introductory price turns into.
    static func introductoryPriceEnd(in text: String) -> Decimal? {
        let pattern = #"(?i)\bthen\s+(?:C\$|CA\$|US\$|A\$|AU\$|\$|€|£)\s?(\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: min(ns.length, 12_000))) else { return nil }
        return Decimal(string: ns.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: ""))
    }

    // MARK: Trial

    static func extractTrialDays(_ text: String) -> Int? {
        let pattern = "(\\d{1,3})[- ]day(?:s)?(?: free)? trial|trial (?:of|for) (\\d{1,3}) days|(\\d{1,3}) days free"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        for i in 1...3 where match.range(at: i).location != NSNotFound {
            if let days = Int(ns.substring(with: match.range(at: i))), (1...365).contains(days) { return days }
        }
        return nil
    }

    // MARK: Product hints
    /// Resolves product-level names that live under big, mixed-commerce brands
    /// (an Amazon *Prime* receipt is a subscription; an Amazon *order* is not).
    private static let productNeedles: [(String, String)] = [
        // "Amazon Prime Video" is the video service, not the Prime membership, so it is checked first.
        ("amazon prime video", "Prime Video"), ("amazon prime", "Amazon Prime"), ("prime membership", "Amazon Prime"),
        ("prime video", "Prime Video"),
        ("amazon music unlimited", "Amazon Music Unlimited"), ("kindle unlimited", "Kindle Unlimited"), ("audible", "Audible"),
        ("dashpass", "DashPass"), ("uber one", "Uber One"), ("walmart+", "Walmart+"), ("walmart plus", "Walmart+"),
        ("instacart+", "Instacart+"), ("instacart plus", "Instacart+"), ("switch online", "Nintendo Switch Online"),
        ("playstation plus", "PlayStation Plus"), ("ps plus", "PlayStation Plus"), ("game pass", "Xbox Game Pass"),
        ("microsoft 365", "Microsoft 365"), ("office 365", "Microsoft 365"), ("google one", "Google One"),
        ("google workspace", "Google Workspace"), ("youtube premium", "YouTube Premium"), ("youtube music", "YouTube Music"),
        ("youtube tv", "YouTube TV"), ("apple one", "Apple One"), ("icloud+", "iCloud+"), ("icloud storage", "iCloud+"),
        ("apple music", "Apple Music"), ("apple tv+", "Apple TV+"), ("apple arcade", "Apple Arcade"),
        ("chatgpt plus", "ChatGPT Plus"), ("chatgpt pro", "ChatGPT Pro"), ("chatgpt team", "ChatGPT Team"),
        ("claude pro", "Claude Pro"), ("claude max", "Claude Max"), ("github copilot", "GitHub Copilot"),
        ("disney+", "Disney+"), ("disney plus", "Disney+"), ("paramount+", "Paramount+"), ("peacock", "Peacock"),
        ("discord nitro", "Discord Nitro"), ("nitro", "Discord Nitro"), ("lyft pink", "Lyft Pink"), ("grubhub+", "Grubhub+")
    ]

    static func productHint(subject: String, body: String) -> String? {
        if let channel = storeChannel(in: subject + "\n" + body.prefix(6_000)) { return channel }
        let text = (subject + " " + body.prefix(6_000)).lowercased()
        // Prefer products named in the subject
        let subjectLower = subject.lowercased()
        if let hit = productNeedles.first(where: { subjectLower.contains($0.0) }) { return hit.1 }
        if let hit = productNeedles.first(where: { text.contains($0.0) && $0.0 != "nitro" && $0.0 != "audible" && $0.0 != "peacock" }) { return hit.1 }
        return nil
    }

    /// A channel sold through a video store ("Your subscription to Vivéo on Prime Video", "Crunchyroll on Prime
    /// Video", "HBO Max via Apple TV"): the channel is what's billed, not the store's own membership.
    static func storeChannel(in text: String) -> String? {
        let pattern = #"(?i)(?:subscription to|subscribed to|subscribe to|membership to|trial (?:offer )?(?:for|of))\s+([^\n\[\]<>()]{2,40}?)\s*(?:\[[^\]\n]*\]\s*|\([^)\n]*\)\s*)?(?:on|via|through)\s+(?:amazon\s+)?(?:prime video|apple tv|youtube|roku)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let name = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = name.lowercased()
        guard name.count >= 2, !["prime", "amazon prime", "the channel", "this channel", "a channel"].contains(lower) else { return nil }
        return name
    }

    // MARK: Helpers

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}

// MARK: - Email Kind

enum EmailKind: String, Codable, Equatable {
    case charge
    case renewalNotice
    case trialStarted
    case trialEnding
    case priceChange
    case cancellation
    /// The card was declined. Shows the subscription exists; it is never counted as a charge.
    case paymentFailed
    case other
}
