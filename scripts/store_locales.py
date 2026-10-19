# Per-locale search metadata. Executed by store_copy.py (shares its LOCALES dict).
# Evidence: scripts/aso_scan_2026-10-19.json (US/CA) and scripts/aso_scan_locales_2026-10-19.json (other storefronts).
# Apple indexes TWO locales per storefront, so complementary (not identical) keyword sets double the vocabulary:
#   US store: en-US + es-MX | Canada: en-CA + fr-CA | UK: en-GB + en-AU | Australia: en-AU + en-GB

EN_A = "cancel,find,alert,manager,manage,forgotten,hidden,bill,cost,recurring,payment,price,increase,track"

LOCALES.update({
 # ----- English
 "en-US": dict(lang="en", name="Pausely: Subscription Tracker", subtitle="Trial & Renewal Reminders", keywords=EN_A,
               storefronts="United States", notes="Head term in the name; winnable trial/renewal/reminder terms in the subtitle."),
 "en-CA": dict(lang="en", name="Pausely: Subscription Tracker", subtitle="Trial & Renewal Reminders", keywords=EN_A,
               storefronts="Canada (also indexed with fr-CA)", notes="Primary market. Same English set as US; French carries the complementary vocabulary."),
 "en-GB": dict(lang="en", name="Pausely: Subscription Tracker", subtitle="Trial & Renewal Reminders", keywords=EN_A,
               storefronts="United Kingdom (also indexed with en-AU)", notes="Indexed together with en-AU: keep the two sets different."),
 "en-AU": dict(lang="en", name="Pausely: Subscription Manager", subtitle="Find & Stop Hidden Charges",
               keywords="cheaper,alternative,monthly,yearly,spend,saver,unused,waste,payments,money,credit,card,direct,debit",
               storefronts="Australia (also indexed with en-GB)", notes="Complementary words to en-GB so both stores gain ~200 characters of English keywords."),
 # ----- French
 "fr-CA": dict(lang="fr", name="Pausely: Suivi d'abonnements", subtitle="Gestionnaire et rappels",
               keywords="annuler,essai,renouvellement,facture,recurrent,paiement,cache,oublie,prix,hausse,alerte,cout,trouver",
               storefronts="Canada (Quebec)", notes="Near-empty competition: all top-10 for 'suivi abonnements' are tiny apps."),
 "fr-FR": dict(lang="fr", name="Pausely: Suivi d'abonnements", subtitle="Gestionnaire et rappels",
               keywords="resilier,annuler,essai,renouvellement,facture,recurrent,paiement,cache,oublie,prix,hausse,alerte",
               storefronts="France", notes="France says 'résilier'; Canada says 'annuler'."),
 # ----- Spanish
 "es-MX": dict(lang="es", name="Pausely: Gestor Suscripciones", subtitle="Control y recordatorio de pago",
               keywords="cancelar,renovación,prueba,pagos,recurrentes,rastreador,administrar,gastos,mensual,precio,alerta",
               storefronts="Mexico and the US Hispanic audience (also indexed in the US store)", notes="Median competitor has 0 to 17 ratings."),
 "es-ES": dict(lang="es", name="Pausely: Gestor Suscripciones", subtitle="Control y recordatorio de pago",
               keywords="cancelar,renovación,prueba,pagos,recurrentes,rastreador,administrar,gastos,mensual,precio,alerta",
               storefronts="Spain", notes="Same set as Mexico; 'coste' (Spain) vs 'costo' (Mexico) handled in the description."),
 # ----- German
 "de-DE": dict(lang="de", name="Pausely: Abo Tracker & Manager", subtitle="Abos verwalten & kündigen",
               keywords="erinnerung,probeabo,verlängerung,wiederkehrend,zahlung,kosten,preis,erhöhung,versteckt,vergessen",
               storefronts="Germany, Austria, Switzerland", notes="Germans say 'Abo'. Top-5 competitors have a median of 1 to 176 ratings."),
 # ----- Japanese
 "ja": dict(lang="ja", name="Pausely - サブスク管理・解約リマインダー", subtitle="更新日と値上げを通知・固定費を見える化",
            keywords="サブスクリプション,定額,固定費,解約,支払い,契約,家計簿,節約,トライアル,通知,値上げ,更新,忘れ防止,支出",
            storefronts="Japan", notes="'サブスク管理' is the dominant head term (30 of top-10 titles)."),
 # ----- Arabic
 "ar-SA": dict(lang="ar", name="Pausely: إدارة الاشتراكات", subtitle="تذكير التجديد، تتبع الفواتير",
               keywords="إلغاء,تجربة,تنبيه,سعر,ارتفاع,دفعات,متكررة,مصاريف,شهرية,خفية,منسية",
               storefronts="Saudi Arabia, UAE and other Arabic storefronts", notes="Every top-10 app has a median of 0 to 19 ratings."),
})
