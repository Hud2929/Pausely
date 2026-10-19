#!/usr/bin/env python3
"""
Single source of truth for Pausely's App Store copy in every language.

  python3 scripts/store_copy.py --check     # verify every limit (name 30, subtitle 30, keywords 100, promo 170, description 4000)
  python3 scripts/store_copy.py --write     # write metadata/ (canonical `asc metadata` layout) + AppStoreMetadata/<locale>/*.txt (human review)

Canonical layout, consumed by `asc metadata validate|push` (see .claude/skills/asc-metadata-sync):
  metadata/app-info/<locale>.json            name, subtitle, privacyPolicyUrl
  metadata/version/<VERSION>/<locale>.json   description, keywords, marketingUrl, promotionalText, supportUrl, whatsNew

Rules enforced: no word repeated across name+subtitle+keywords, no competitor/trademark terms, URLs on pausely.pro,
claims only for features the app really ships (1,000+ catalog services, 900+ cancel links, 140+ currencies,
5-subscription free tier). Translations are drafts: have a native speaker review before submitting.
"""
import argparse, os, re, sys

LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotional_text": 170, "description": 4000, "whats_new": 4000}
BANNED = {"rocket", "truebill", "trim", "bobby", "netflix", "spotify", "gmail", "google", "apple", "free", "app", "gratis", "gratuit"}

FREE_LIMIT = 5   # must equal FreeTier.subscriptionLimit in Pausely/Services/PaymentManager.swift (checked by --check)
URLS = {"terms": "https://pausely.pro/terms.html", "privacy": "https://pausely.pro/privacy.html", "support": "pausely@proton.me"}
SITE = {"marketing": "https://pausely.pro", "support": "https://pausely.pro/support.html", "privacy": "https://pausely.pro/privacy.html"}
VERSION = "1.0.3"   # MARKETING_VERSION in Pausely.xcodeproj; keep in sync with the version being submitted

# ----------------------------------------------------------------------------- descriptions (translated drafts)
DESC = {}

DESC["en"] = """Know exactly what you pay for, and when it renews.

Pausely keeps every subscription in one calm, simple place. It warns you before free trials end, prices go up, or a renewal catches you off guard.

WHAT YOU GET
• One clear dashboard with your weekly, monthly and yearly spend, your next payment and the bills due this week
• 1,000+ popular services to add in seconds, or paste a link and Pausely recognizes the service
• Renewal reminders 1, 3 or 7 days before, whichever you choose
• Free-trial protection: track trial end dates and get alerted before you are charged
• Price history for every subscription, with an alert when a price goes up
• Direct links to the cancellation page for 900+ services, plus difficulty ratings from other users
• Cheaper alternatives for the services you already pay for
• Cost per hour of use, so you can see what is really worth keeping
• 140+ currencies with automatic conversion
• Home Screen widgets, Shortcuts actions and Face ID sign-in
• Your Subscription Wrapped: a year of subscriptions at a glance
• Export your data whenever you like

FREE AND PRO
Track up to {free} subscriptions for free. Pausely Pro unlocks unlimited subscriptions, savings insights, cheaper alternatives and the guided cancel flow.

PRIVATE BY DESIGN
No ads, no third-party trackers, and we never sell your data.

Available in English, French, Spanish, German, Japanese and Arabic.

SUBSCRIPTION INFO
Pausely Pro is an auto-renewing subscription, billed monthly or yearly. Payment is charged to your Apple Account at confirmation of purchase. The subscription renews automatically unless it is canceled at least 24 hours before the end of the current period. You can manage or cancel it in your Apple Account settings after purchase.

Terms of Use: {terms}
Privacy Policy: {privacy}
Support: {support}"""

DESC["fr"] = """Sachez exactement ce que vous payez et quand ça se renouvelle.

Pausely réunit tous vos abonnements au même endroit, simplement. L'app vous prévient avant la fin d'un essai gratuit, avant une hausse de prix ou un renouvellement surprise.

CE QUE VOUS OBTENEZ
• Un tableau de bord clair : dépenses par semaine, mois et année, prochain paiement et factures de la semaine
• Plus de 1 000 services populaires à ajouter en quelques secondes, ou collez un lien et Pausely reconnaît le service
• Rappels de renouvellement 1, 3 ou 7 jours à l'avance, selon votre choix
• Protection des essais gratuits : suivez la date de fin et soyez alerté avant d'être facturé
• Historique des prix de chaque abonnement, avec une alerte en cas de hausse
• Liens directs vers la page de résiliation de plus de 900 services, et notes de difficulté des autres utilisateurs
• Des alternatives moins chères aux services que vous payez déjà
• Coût par heure d'utilisation, pour voir ce qui vaut vraiment la peine d'être gardé
• Plus de 140 devises avec conversion automatique
• Widgets d'écran d'accueil, actions Raccourcis et connexion par Face ID
• Votre bilan annuel d'abonnements en un coup d'œil
• Exportez vos données quand vous voulez

GRATUIT ET PRO
Suivez jusqu'à {free} abonnements gratuitement. Pausely Pro débloque les abonnements illimités, les analyses d'économies, les alternatives moins chères et le parcours guidé de résiliation.

CONFIDENTIALITÉ D'ABORD
Aucune publicité, aucun traceur tiers, et nous ne vendons jamais vos données.

Disponible en anglais, français, espagnol, allemand, japonais et arabe.

INFORMATIONS SUR L'ABONNEMENT
Pausely Pro est un abonnement à renouvellement automatique, facturé chaque mois ou chaque année. Le paiement est débité de votre compte Apple à la confirmation de l'achat. L'abonnement se renouvelle automatiquement, sauf s'il est annulé au moins 24 heures avant la fin de la période en cours. Vous pouvez le gérer ou l'annuler dans les réglages de votre compte Apple après l'achat.

Conditions d'utilisation : {terms}
Politique de confidentialité : {privacy}
Assistance : {support}"""

DESC["es"] = """Conoce exactamente lo que pagas y cuándo se renueva.

Pausely reúne todas tus suscripciones en un solo lugar, de forma sencilla. Te avisa antes de que termine una prueba gratuita, suba un precio o llegue una renovación inesperada.

LO QUE OBTIENES
• Un panel claro con tu gasto semanal, mensual y anual, tu próximo pago y los cobros de esta semana
• Más de 1000 servicios populares para añadir en segundos, o pega un enlace y Pausely reconoce el servicio
• Recordatorios de renovación 1, 3 o 7 días antes, como prefieras
• Protección de pruebas gratuitas: sigue la fecha de fin y recibe un aviso antes de que te cobren
• Historial de precios de cada suscripción, con una alerta cuando sube un precio
• Enlaces directos a la página de cancelación de más de 900 servicios, y valoraciones de dificultad de otros usuarios
• Alternativas más baratas para los servicios que ya pagas
• Coste por hora de uso, para ver qué merece la pena conservar
• Más de 140 monedas con conversión automática
• Widgets en la pantalla de inicio, acciones de Atajos e inicio de sesión con Face ID
• El resumen de tu año en suscripciones de un vistazo
• Exporta tus datos cuando quieras

GRATIS Y PRO
Controla hasta {free} suscripciones gratis. Pausely Pro desbloquea suscripciones ilimitadas, análisis de ahorro, alternativas más baratas y el flujo guiado para cancelar.

PRIVACIDAD ANTE TODO
Sin anuncios, sin rastreadores de terceros y nunca vendemos tus datos.

Disponible en inglés, francés, español, alemán, japonés y árabe.

INFORMACIÓN DE LA SUSCRIPCIÓN
Pausely Pro es una suscripción de renovación automática, con cobro mensual o anual. El pago se carga a tu cuenta de Apple al confirmar la compra. La suscripción se renueva automáticamente salvo que se cancele al menos 24 horas antes del final del periodo en curso. Puedes gestionarla o cancelarla en los ajustes de tu cuenta de Apple después de la compra.

Términos de uso: {terms}
Política de privacidad: {privacy}
Soporte: {support}"""

DESC["de"] = """Wissen Sie genau, wofür Sie zahlen und wann es sich verlängert.

Pausely bündelt alle Ihre Abos an einem ruhigen, übersichtlichen Ort. Die App warnt Sie, bevor eine kostenlose Testphase endet, ein Preis steigt oder eine Verlängerung Sie überrascht.

DAS BEKOMMEN SIE
• Eine klare Übersicht mit Ausgaben pro Woche, Monat und Jahr, Ihrer nächsten Zahlung und den Abbuchungen dieser Woche
• Über 1.000 beliebte Dienste in Sekunden hinzufügen, oder einen Link einfügen, und Pausely erkennt den Dienst
• Erinnerungen vor der Verlängerung: 1, 3 oder 7 Tage vorher, ganz nach Wahl
• Schutz vor Testabos: Enddatum verfolgen und vor der Abbuchung benachrichtigt werden
• Preisverlauf für jedes Abo, mit Hinweis bei Preiserhöhungen
• Direkte Links zur Kündigungsseite von über 900 Diensten, plus Schwierigkeitsbewertungen anderer Nutzer
• Günstigere Alternativen zu den Diensten, die Sie schon bezahlen
• Kosten pro Nutzungsstunde, damit Sie sehen, was sich wirklich lohnt
• Über 140 Währungen mit automatischer Umrechnung
• Widgets für den Home-Bildschirm, Kurzbefehle-Aktionen und Anmeldung mit Face ID
• Ihr Abo-Jahresrückblick auf einen Blick
• Daten jederzeit exportieren

KOSTENLOS UND PRO
Verwalten Sie bis zu {free} Abos kostenlos. Pausely Pro schaltet unbegrenzte Abos, Sparanalysen, günstigere Alternativen und den geführten Kündigungsablauf frei.

PRIVATSPHÄRE ZUERST
Keine Werbung, keine Tracker von Drittanbietern, und wir verkaufen niemals Ihre Daten.

Verfügbar auf Englisch, Französisch, Spanisch, Deutsch, Japanisch und Arabisch.

ABO-INFORMATIONEN
Pausely Pro ist ein automatisch verlängerndes Abonnement mit monatlicher oder jährlicher Abrechnung. Die Zahlung wird bei Kaufbestätigung Ihrem Apple-Account belastet. Das Abonnement verlängert sich automatisch, sofern es nicht mindestens 24 Stunden vor Ablauf des aktuellen Zeitraums gekündigt wird. Nach dem Kauf können Sie es in den Einstellungen Ihres Apple-Accounts verwalten oder kündigen.

Nutzungsbedingungen: {terms}
Datenschutzerklärung: {privacy}
Support: {support}"""

DESC["ja"] = """サブスクの支払いと更新日を、ひと目で把握。

Pauselyはすべてのサブスクリプションをひとつの画面にまとめます。無料トライアルの終了前、値上げ、思いがけない更新を事前にお知らせします。

主な機能
• 週・月・年ごとの支出、次回の支払い、今週の請求がわかるシンプルなダッシュボード
• 1,000以上の人気サービスを数秒で追加。リンクを貼るだけでサービスを自動認識
• 更新の1日前・3日前・7日前から選べるリマインダー
• 無料トライアル保護：終了日を管理し、課金前に通知
• サブスクごとの価格履歴と、値上げ時のアラート
• 900以上のサービスの解約ページへ直接リンク。他のユーザーによる解約のしやすさ評価つき
• いま支払っているサービスのより安い代替案
• 利用1時間あたりのコストで、続ける価値を判断
• 140以上の通貨に対応し、自動で換算
• ホーム画面ウィジェット、ショートカット、Face IDでのサインイン
• 1年間のサブスクをまとめて振り返るレポート
• データはいつでもエクスポート可能

無料版とPro版
無料で{free}件までのサブスクを管理できます。Pausely Proでは、無制限の登録、節約インサイト、より安い代替案、ガイド付きの解約フローが使えます。

プライバシー重視
広告なし、第三者のトラッカーなし。データを販売することは決してありません。

対応言語：英語、フランス語、スペイン語、ドイツ語、日本語、アラビア語。

サブスクリプション情報
Pausely Proは自動更新サブスクリプション（月額または年額）です。お支払いは購入確認時にAppleアカウントに請求されます。現在の期間が終了する24時間前までに解約しない限り、サブスクリプションは自動的に更新されます。購入後は、Appleアカウント設定から管理・解約できます。

利用規約：{terms}
プライバシーポリシー：{privacy}
サポート：{support}"""

DESC["ar"] = """اعرف بالضبط ما تدفعه ومتى يتجدد.

يجمع Pausely جميع اشتراكاتك في مكان واحد بسيط وواضح، وينبهك قبل انتهاء التجربة المجانية أو ارتفاع السعر أو حلول تجديد غير متوقع.

ما الذي ستحصل عليه
• لوحة واضحة تعرض إنفاقك الأسبوعي والشهري والسنوي وموعد دفعتك القادمة وفواتير هذا الأسبوع
• أكثر من 1000 خدمة شهيرة تضيفها في ثوانٍ، أو الصق رابطًا ليتعرف Pausely على الخدمة
• تذكيرات بالتجديد قبل يوم أو 3 أيام أو 7 أيام حسب اختيارك
• حماية التجارب المجانية: تابع تاريخ الانتهاء وتلقَّ تنبيهًا قبل الخصم
• سجل أسعار لكل اشتراك مع تنبيه عند ارتفاع السعر
• روابط مباشرة لصفحة الإلغاء لأكثر من 900 خدمة، مع تقييمات صعوبة الإلغاء من مستخدمين آخرين
• بدائل أرخص للخدمات التي تدفع ثمنها بالفعل
• التكلفة لكل ساعة استخدام لتعرف ما يستحق الاحتفاظ به
• أكثر من 140 عملة مع تحويل تلقائي
• أدوات الشاشة الرئيسية وإجراءات الاختصارات وتسجيل الدخول بـ Face ID
• ملخص سنتك في الاشتراكات في نظرة واحدة
• صدّر بياناتك متى شئت

مجاني وPro
تابع حتى {free} اشتراكات مجانًا. يتيح Pausely Pro اشتراكات غير محدودة وتحليلات التوفير وبدائل أرخص ومسار إلغاء موجّهًا.

الخصوصية أولًا
لا إعلانات ولا متتبعات من أطراف خارجية، ولا نبيع بياناتك أبدًا.

متوفر بالإنجليزية والفرنسية والإسبانية والألمانية واليابانية والعربية.

معلومات الاشتراك
Pausely Pro اشتراك يتجدد تلقائيًا ويُفوتر شهريًا أو سنويًا. يُخصم المبلغ من حساب Apple عند تأكيد الشراء. يتجدد الاشتراك تلقائيًا ما لم يُلغَ قبل 24 ساعة على الأقل من نهاية الفترة الحالية. يمكنك إدارته أو إلغاؤه من إعدادات حساب Apple بعد الشراء.

شروط الاستخدام: {terms}
سياسة الخصوصية: {privacy}
الدعم: {support}"""

# ----------------------------------------------------------------------------- promo text, what's new, captions
PROMO = {
 "en": "Never be surprised by a renewal again. Track every subscription, get alerts before free trials end and prices rise, and see what each one really costs.",
 "fr": "Fini les renouvellements surprises. Suivez chaque abonnement, soyez alerté avant la fin des essais gratuits et les hausses de prix, et voyez ce que chacun coûte vraiment.",
 "es": "Que ninguna renovación te sorprenda. Controla cada suscripción, recibe avisos antes de que terminen las pruebas o suban los precios y descubre cuánto cuesta cada una.",
 "de": "Nie wieder von Verlängerungen überrascht. Behalten Sie jedes Abo im Blick, werden Sie vor Testende und Preiserhöhungen gewarnt und sehen Sie, was jedes wirklich kostet.",
 "ja": "更新で驚かない。サブスクをまとめて管理し、無料トライアルの終了や値上げを事前に通知。それぞれの本当のコストもひと目でわかります。",
 "ar": "لا مفاجآت في التجديد بعد اليوم. تابع كل اشتراك، وتلقَّ تنبيهًا قبل انتهاء التجارب المجانية وارتفاع الأسعار، واعرف التكلفة الحقيقية لكل اشتراك.",
}
WHATS_NEW = {
 "en": "Welcome to Pausely. Track your subscriptions, get renewal and free-trial alerts, and see what each one really costs.",
 "fr": "Bienvenue sur Pausely. Suivez vos abonnements, recevez des alertes de renouvellement et de fin d'essai, et voyez ce que chacun coûte vraiment.",
 "es": "Te damos la bienvenida a Pausely. Controla tus suscripciones, recibe avisos de renovación y fin de prueba, y descubre cuánto cuesta cada una.",
 "de": "Willkommen bei Pausely. Behalten Sie Ihre Abos im Blick, erhalten Sie Hinweise zu Verlängerungen und Testphasen und sehen Sie, was jedes wirklich kostet.",
 "ja": "Pauselyへようこそ。サブスクを管理し、更新や無料トライアル終了の通知を受け取り、それぞれの本当のコストを確認できます。",
 "ar": "مرحبًا بك في Pausely. تابع اشتراكاتك وتلقَّ تنبيهات التجديد وانتهاء التجربة المجانية واعرف التكلفة الحقيقية لكل اشتراك.",
}
CAPTIONS = {
 "en": ["Every subscription in one calm place", "Alerts before trials end and prices rise", "See what each one really costs", "Add 1,000+ services in seconds", "Find cheaper alternatives", "Your year in subscriptions"],
 "fr": ["Tous vos abonnements au même endroit", "Alertes avant la fin des essais et les hausses", "Voyez ce que chacun coûte vraiment", "Plus de 1 000 services en quelques secondes", "Trouvez des alternatives moins chères", "Votre année en abonnements"],
 "es": ["Todas tus suscripciones en un solo lugar", "Avisos antes de que acaben las pruebas y suban los precios", "Descubre cuánto cuesta cada una", "Más de 1000 servicios en segundos", "Encuentra alternativas más baratas", "Tu año en suscripciones"],
 "de": ["Alle Abos an einem Ort", "Warnungen vor Testende und Preiserhöhung", "Sehen Sie, was jedes wirklich kostet", "Über 1.000 Dienste in Sekunden", "Günstigere Alternativen finden", "Ihr Abo-Jahr im Überblick"],
 "ja": ["すべてのサブスクをひとつに", "トライアル終了と値上げを事前に通知", "それぞれの本当のコストがわかる", "1,000以上のサービスを数秒で追加", "より安い代替案を見つける", "1年間のサブスクを振り返る"],
 "ar": ["كل اشتراكاتك في مكان واحد", "تنبيهات قبل انتهاء التجربة وارتفاع السعر", "اعرف التكلفة الحقيقية لكل اشتراك", "أكثر من 1000 خدمة في ثوانٍ", "اعثر على بدائل أرخص", "سنتك في الاشتراكات"],
}

# ----------------------------------------------------------------------------- per-locale search metadata (filled from storefront research)
LOCALES = {}   # locale -> dict(lang, name, subtitle, keywords, storefronts, notes)

def variants():
    """Region tweaks applied to the base language copy."""
    return {
        "es-MX": [("Coste por hora", "Costo por hora"), ("valoraciones", "calificaciones")],
    }

def render(locale):
    meta = LOCALES[locale]
    lang = meta["lang"]
    desc = DESC[lang].format(free=FREE_LIMIT, **URLS)
    for old, new in variants().get(locale, []):
        desc = desc.replace(old, new)
    return {
        "name": meta["name"], "subtitle": meta["subtitle"], "keywords": meta["keywords"],
        "promotional_text": PROMO[lang], "description": desc, "whats_new": WHATS_NEW[lang],
        "screenshot_captions": "\n".join(f"{i+1}. {c}" for i, c in enumerate(CAPTIONS[lang])),
    }

def words(s):
    return re.findall(r"[\w']+", s.lower().replace("'", " "), re.UNICODE)

def check():
    problems = []
    swift = os.path.join(os.path.dirname(__file__), "..", "Pausely", "Services", "PaymentManager.swift")
    m = re.search(r"enum FreeTier\s*\{\s*static let subscriptionLimit = (\d+)", open(swift, encoding="utf-8").read())
    if not m: problems.append("could not find FreeTier.subscriptionLimit in PaymentManager.swift")
    elif int(m.group(1)) != FREE_LIMIT: problems.append(f"free limit mismatch: store copy {FREE_LIMIT} vs app {m.group(1)}")
    import json
    prods = json.load(open(os.path.join(os.path.dirname(__file__), "..", "appstore_products.json"), encoding="utf-8"))
    for prod in prods["products"]:
        have = {l["locale"] for l in prod["localization"]}
        for loc in LOCALES:
            if loc not in have: problems.append(f"{prod['product_id']}: missing subscription localization for {loc}")
        for l in prod["localization"]:
            if len(l["display_name"]) > 30: problems.append(f"{prod['product_id']} {l['locale']}: display name over 30")
            if len(l["description"]) > 45: problems.append(f"{prod['product_id']} {l['locale']}: description {len(l['description'])}/45")
    for loc in LOCALES:
        c = render(loc)
        for field, limit in LIMITS.items():
            if len(c[field]) > limit:
                problems.append(f"{loc}: {field} is {len(c[field])}/{limit}")
        kw = c["keywords"].split(",")
        seen = set(words(c["name"])) | set(words(c["subtitle"]))
        for w in kw:
            if w in seen: problems.append(f"{loc}: keyword '{w}' repeats name/subtitle")
        if len(set(kw)) != len(kw): problems.append(f"{loc}: duplicate keywords")
        for w in set(kw) | set(words(c["name"])) | set(words(c["subtitle"])):
            if w in BANNED: problems.append(f"{loc}: banned term '{w}'")
        if " " in c["keywords"]: problems.append(f"{loc}: keywords contain spaces")
        if "pausely.app" in c["description"]: problems.append(f"{loc}: wrong domain")
    return problems

def write(root, version=VERSION):
    """root = repo root. Writes the canonical asc layout and the per-locale .txt review files."""
    import json
    def dump(path, obj):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False, indent=2); f.write("\n")
    for loc in LOCALES:
        c = render(loc)
        dump(os.path.join(root, "metadata", "app-info", loc + ".json"),
             {"name": c["name"], "subtitle": c["subtitle"], "privacyPolicyUrl": SITE["privacy"]})
        dump(os.path.join(root, "metadata", "version", version, loc + ".json"),
             {"description": c["description"], "keywords": c["keywords"], "marketingUrl": SITE["marketing"],
              "promotionalText": c["promotional_text"], "supportUrl": SITE["support"], "whatsNew": c["whats_new"]})
        d = os.path.join(root, "AppStoreMetadata", loc); os.makedirs(d, exist_ok=True)
        for field, text in c.items():
            with open(os.path.join(d, field + ".txt"), "w", encoding="utf-8") as f:
                f.write(text + "\n")


LISTING_TEMPLATE = """# Pausely - App Store Listing (English master)

> **Generated file. Do not edit by hand.** Source of truth: `scripts/store_copy.py` (copy) and `scripts/store_locales.py` (per-locale name, subtitle, keywords).
> Regenerate with `python3 scripts/store_copy.py --write`; verify with `python3 scripts/store_copy.py --check` and `asc metadata validate --dir ./metadata --subscription-app`.
> Everything below describes only what the app does today. See **APP_STORE_LISTING_PLAN.md** for the full store, ASO and account plan.

## App information (en-US)

| Field | Value | Length |
|---|---|---|
| Name | {name} | {n_name}/30 |
| Subtitle | {subtitle} | {n_sub}/30 |
| Keywords | `{keywords}` | {n_kw}/100 |
| Promotional text | see below | {n_promo}/170 |
| Primary category | Finance (Personal Finance) | |
| Secondary category | Productivity | |
| Price | Free, with in-app subscription (Pausely Pro) | |
| Support URL | {support_url} | |
| Marketing URL | {marketing_url} | |
| Privacy Policy URL | {privacy_url} | |
| Terms of Use (EULA) | {terms_url} (linked in the description; also set as a custom EULA or keep Apple's standard) | |

## Promotional text
```
{promo}
```

## Description
```
{description}
```

## What's New (version {version})
```
{whats_new}
```

## Screenshot captions (en)
{captions}

## Pausely Pro (auto-renewing subscription group `com.pausely.premium`)

| Product | ID | Period | Price (USD) |
|---|---|---|---|
| Monthly | `com.pausely.premium.monthly` | 1 month | 9.99 (as returned by StoreKit on 2026-10-19) |
| Annual | `com.pausely.premium.annual` | 1 year | 39.99 (as returned by StoreKit on 2026-10-19; older repo docs said 79.99) |

The 7-day free trial is configured as an introductory offer in `appstore_products.json`. **Whether it exists in App Store Connect is unverified**; check before using the word "trial" in screenshots or the description's offer wording. The prices above were observed live through StoreKit in a clean simulator; confirm them in App Store Connect once the agreement block is cleared. The launch price is still being decided (see `PRICING_PLAN` notes in `APP_STORE_LISTING_PLAN.md`).

## App Review notes (paste into App Store Connect; credentials go ONLY in the App Review Information fields there)
```
{review_notes}
```

## What this listing must never claim
- "Smart Pause", automatic pausing, or "AI-powered" anything: the app does not do these.
- User counts, ratings, awards, press quotes, testimonials, or average-savings numbers: unreleased app, nothing is measured.
- Gmail / email receipt scanning, until Google approves the restricted `gmail.readonly` scope and the feature ships to everyone.
- Importing subscriptions "from the App Store": iOS does not allow one app to read another app's subscriptions.
- Competitor or Apple trademarks in any field; the word "free" or "app" in the keyword field.
- Prices in the description (Apple shows the localized price from the in-app purchase).

## Other languages
Each locale has its own name, subtitle and keywords (see the matrix in APP_STORE_LISTING_PLAN.md). Files: `metadata/app-info/<locale>.json` and `metadata/version/{version}/<locale>.json`.

{locale_table}
"""

def write_listing(root, version=VERSION):
    import json
    c = render("en-US")
    prod = json.load(open(os.path.join(root, "appstore_products.json"), encoding="utf-8"))
    rows = ["| Locale | Name | Subtitle | Keywords |", "|---|---|---|---|"]
    for loc in LOCALES:
        r = render(loc)
        rows.append(f"| {loc} | {r['name']} | {r['subtitle']} | {len(r['keywords'])} chars |")
    text = LISTING_TEMPLATE.format(
        name=c["name"], subtitle=c["subtitle"], keywords=c["keywords"], promo=c["promotional_text"],
        description=c["description"], whats_new=c["whats_new"], version=version,
        n_name=len(c["name"]), n_sub=len(c["subtitle"]), n_kw=len(c["keywords"]), n_promo=len(c["promotional_text"]),
        support_url=SITE["support"], marketing_url=SITE["marketing"], privacy_url=SITE["privacy"], terms_url=URLS["terms"],
        captions=c["screenshot_captions"], review_notes=prod["app_review_info"]["notes"], locale_table="\n".join(rows))
    with open(os.path.join(root, "APP_STORE_LISTING.md"), "w", encoding="utf-8") as f:
        f.write(text)

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--check", action="store_true"); ap.add_argument("--write", action="store_true")
    a = ap.parse_args()
    exec(open(os.path.join(os.path.dirname(__file__), "store_locales.py"), encoding="utf-8").read())
    probs = check()
    for p in probs: print("PROBLEM:", p)
    print(f"{len(LOCALES)} locales checked, {len(probs)} problem(s)")
    if a.write and not probs:
        root = os.path.join(os.path.dirname(__file__), ".."); write(root); write_listing(root); print("written")
    sys.exit(1 if probs else 0)
