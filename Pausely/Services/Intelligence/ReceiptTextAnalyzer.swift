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
        /// The words around the amount say it was charged ("amount paid", "total"), not just what a plan costs.
        var chargeEvidence = false
        /// The introductory price as the email states it, before tax, when it also states what follows.
        var introAmount: Decimal? = nil
    }

    // MARK: Entry point

    static func analyze(subject: String, body: String, promotional: Bool = false) -> Analysis {
        let cappedBody = String(body.prefix(24_000))
        let period = servicePeriod(in: cappedBody)
        let flags = languageFlags(subject: subject, body: cappedBody, promotional: promotional, servicePeriod: period != nil)
        let candidate = chargeCandidate(subject: subject, body: cappedBody)
        let money = candidate?.money
        let frequency = explicitFrequency(subject: subject, body: cappedBody) ?? period
        let trialDays = extractTrialDays(subject + " " + cappedBody)
        var product = productHint(subject: subject, body: cappedBody)
        // A brand mentioned only in passing (e.g. "DashPass savings" on an order) must not rename that order.
        if product != nil, productHint(subject: subject, body: "") == nil, flags.oneTime || !flags.renewal { product = nil }
        let kind = classify(flags: flags, hasAmount: money != nil)
        let stated = introductoryPrices(in: subject + "\n" + cappedBody)
        var next = stated?.next
        if let current = stated?.intro ?? money?.amount, let later = next, later <= current { next = nil }
        return Analysis(money: money, flags: flags, frequency: frequency,
                        trialDays: trialDays, productHint: product, kind: kind, nextAmount: next,
                        chargeEvidence: candidate?.evidence ?? false, introAmount: next == nil ? nil : stated?.intro)
    }

    // MARK: Classification

    static func classify(flags: LanguageFlags, hasAmount: Bool) -> EmailKind {
        if flags.cancelled { return .cancellation }
        // A declined card is not a charge, whatever amount the email mentions.
        if flags.paymentFailed { return .paymentFailed }
        if flags.trialEnding { return .trialEnding }
        // Refunds are never charges, price changes, or renewal notices.
        if flags.refund { return .other }
        if flags.priceChange { return .priceChange }
        if flags.trialStart && !hasAmount { return .trialStarted }
        if flags.trialStart && flags.renewal && !flags.oneTime { return .trialStarted }
        if hasAmount { return .charge }
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

        let mentionsTrial = containsAny(text, [
            "free trial", "trial has started", "your trial", "trial begins", "start your trial", "trial period",
            "welcome to your trial", "trial started", "days free",
            "essai gratuit", "prueba gratuita", "kostenlose testphase", "kostenloser test",
            "prova gratuita", "teste grátis", "avaliação gratuita", "無料体験", "無料トライアル", "お試し期間",
            "الفترة التجريبية", "تجربة مجانية", "무료 체험"
        ])
        // An invitation to start a trial is not a trial. "You're eligible for 90 days free. Subscribe now"
        // is an offer; "Welcome to Prime. Plan type: 30-day free trial. Renewal date: June 10" has begun.
        let invites = containsAny(text, [
            "you're eligible", "you are eligible", "to activate", "activate your", "activate now", "claim your", "redeem",
            "subscribe now", "sign up now", "join now", "start your free trial", "start your trial", "start free trial",
            "try it free", "try free", "try now", "new subscribers only", "new members only", "limited time", "limited-time",
            "offer ends", "offer expires", "terms apply", "get started today", "don't miss",
            "profitez", "inscrivez-vous", "offre limitée", "aprovecha", "suscríbete ahora", "oferta limitada",
            "jetzt testen", "jetzt abonnieren", "nur für kurze zeit", "今すぐ登録", "今すぐ始め", "期間限定", "اشترك الآن", "عرض لفترة محدودة"
        ])
        let begun = containsAny(text, [
            "you subscribed", "you've subscribed", "you have subscribed", "successfully subscribed", "has started", "have started",
            "trial started", "started on", "welcome to", "thanks for starting", "thank you for starting", "renewal date",
            "after your trial", "trial ends on", "trial will end", "order number", "order date",
            "a commencé", "bienvenue", "ha comenzado", "te damos la bienvenida", "hat begonnen", "willkommen",
            "開始されました", "ようこそ", "بدأت", "مرحبًا بك في"
        ])
        let isInvitation = invites && !begun
        flags.trialStart = (flags.trialEnding || mentionsTrial) && !isInvitation

        flags.priceChange = containsAny(text, [
            "price change", "price increase", "price is changing", "price will change", "new price", "increase in price",
            "adjusting our prices", "pricing update", "updating our prices", "price adjustment", "prices are changing",
            "increase the price", "increasing the price", "rate increase",
            "changement de prix", "augmentation de prix", "nouveau prix", "cambio de precio", "aumento de precio",
            "preisänderung", "preiserhöhung", "aumento di prezzo", "aumento de preço", "料金改定", "価格改定",
            "料金の変更", "値上げ", "تغيير السعر", "زيادة السعر", "가격 인상", "요금 변경"
        ]) || text.range(of: #"\bprice\b[^.\n]{0,60}\b(?:will|is going to|is set to)\s+(?:change|increase|go up|rise)"#,
                         options: .regularExpression) != nil

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

        flags.marketing = promotional || (isInvitation && mentionsTrial) || containsAny(subjectLower, [
            "% off", "sale", "limited time", "special offer", "exclusive offer", "newsletter", "deal of", "save up to",
            "shop now", "last chance", "don't miss", "flash sale", "black friday", "cyber monday", "new arrivals"
        ])

        return flags
    }

    // MARK: Frequency

    /// Only returns a frequency when the email states one clearly. The engine prefers real charge dates over this.
    static func explicitFrequency(subject: String, body: String) -> BillingFrequency? {
        let text = (subject + " " + body.prefix(8_000)).lowercased()
        var found: [BillingFrequency] = []
        if containsAny(text, [
            "billed monthly", "per month", "/month", "/mo ", "every month", "each month", "monthly plan", "monthly subscription",
            "monthly membership", "renews monthly", "(monthly)",
            "par mois", "/mois", "chaque mois", "mensuel", "pro monat", "jeden monat", "monatlich", "/monat",
            "al mes", "por mes", "cada mes", "mensual", "al mese", "ogni mese", "mensile", "por mês", "mensal",
            "月額", "毎月", "كل شهر", "شهريًا", "شهريا", "매월"
        ]) { found.append(.monthly) }
        if containsAny(text, [
            "billed annually", "billed yearly", "per year", "/year", "every year", "each year", "annual plan", "yearly plan",
            "annual subscription", "annual membership", "yearly subscription", "renews annually", "renews yearly", "(annual)",
            "(yearly)", "par an", "/an ", "chaque année", "annuel", "pro jahr", "jedes jahr", "jährlich", "/jahr",
            "al año", "por año", "cada año", "anual", "all'anno", "ogni anno", "annuale", "por ano",
            "年額", "毎年", "كل سنة", "سنويًا", "سنويا", "매년"
        ]) { found.append(.yearly) }
        if containsAny(text, ["per week", "/week", "every week", "weekly subscription", "billed weekly", "par semaine", "pro woche", "por semana", "毎週", "كل أسبوع"]) { found.append(.weekly) }
        if containsAny(text, ["quarterly", "every 3 months", "every three months", "tous les 3 mois", "trimestriel", "alle 3 monate", "vierteljährlich", "cada 3 meses", "trimestral", "3か月ごと", "كل 3 أشهر"]) { found.append(.quarterly) }
        if containsAny(text, ["every 6 months", "every six months", "semi-annual", "semiannual", "tous les 6 mois", "alle 6 monate", "halbjährlich", "cada 6 meses", "semestral", "6か月ごと"]) { found.append(.semiannual) }
        return found.count == 1 ? found.first : nil
    }

    /// The subject line itself says money moved: a receipt, an invoice, a payment, a renewal.
    static func subjectSaysReceipt(_ subject: String) -> Bool {
        containsAny(subject.lowercased(), [
            "receipt", "invoice", "payment", "paid", "billed", "billing", "charged", "renewal", "renewed", "statement",
            "order", "purchase", "reçu", "facture", "paiement", "renouvellement", "recibo", "factura", "pago", "renovación",
            "quittung", "rechnung", "zahlung", "verlängerung", "beleg", "ricevuta", "fattura", "pagamento", "rinnovo",
            "fatura", "renovação", "領収", "請求", "お支払い", "ご利用料金", "更新", "إيصال", "فاتورة", "دفع", "تجديد",
            "영수증", "결제"
        ])
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

    /// "charged $134.99 for 1 year, then $269.99/year": the introductory price and what follows it, as the
    /// email states them. Both are the plan's own prices, so their difference is the real rise even when
    /// the amount charged has tax on top.
    static func introductoryPrices(in text: String) -> (intro: Decimal?, next: Decimal)? {
        let normalized = normalizingDigits(text)
        let num = #"\d{1,3}(?:[.,]\d{3})*[.,]\d{2}|\d+[.,]\d{2}|\d{1,3}(?:,\d{3})+(?![.,]\d)|\d{3,}(?![.,]\d)"#
        let sym = #"(?:C\$|CA\$|US\$|A\$|AU\$|\$|€|£|¥|￥|₹|CHF|EUR|USD|GBP|CAD|AUD)"#
        let amount = "(?:\(sym)\\s*(\(num))|(\(num))\\s*\(sym))"
        let connector = #"(?:\b(?:then|thereafter|afterwards|danach|anschließend|puis|ensuite|luego|después|poi|depois)\b|その後|以降は?|ثم)"#
        let ns = normalized as NSString
        let range = NSRange(location: 0, length: min(ns.length, 12_000))
        func value(_ match: NSTextCheckingResult, _ g1: Int, _ g2: Int) -> Decimal? {
            let token: String?
            if match.range(at: g1).location != NSNotFound { token = ns.substring(with: match.range(at: g1)) }
            else if match.range(at: g2).location != NSNotFound { token = ns.substring(with: match.range(at: g2)) }
            else { token = nil }
            return token.flatMap { parseAmount($0, currency: nil)?.value }
        }
        if let both = try? NSRegularExpression(pattern: "(?i)\(amount)[^.\\n]{0,40}?\(connector)\\s+\(amount)"),
           let match = both.firstMatch(in: normalized, range: range), let next = value(match, 3, 4) {
            return (value(match, 1, 2), next)
        }
        if let only = try? NSRegularExpression(pattern: "(?i)\(connector)\\s+\(amount)"),
           let match = only.firstMatch(in: normalized, range: range), let next = value(match, 1, 2) {
            return (nil, next)
        }
        return nil
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
