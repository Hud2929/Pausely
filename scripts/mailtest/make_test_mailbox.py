#!/usr/bin/env python3
"""Builds a synthetic mailbox for Pausely's end-to-end mail tests, and the truth it must produce.

    python3 scripts/mailtest/make_test_mailbox.py /tmp/somewhere/mailbox [--now 2026-10-20]

Writes INBOX/, Archive/, Trash/ and Junk/ folders of .eml files (real MIME: multipart, quoted-printable,
base64, ISO-2022-JP, ISO-8859-1) and truth.json beside them: the subscriptions a scan must find, with
amount, currency, period and state, and the names that must never be listed.

Brand names appear because merchant matching has to be exercised. Every body is original test text;
nothing here is copied from a real email, and no real mailbox is involved.
"""
import argparse
import calendar
import datetime
import json
import os
import shutil
from email.message import EmailMessage
from email.utils import format_datetime

parser = argparse.ArgumentParser()
parser.add_argument("out")
parser.add_argument("--now", default=None, help="YYYY-MM-DD; charges are dated back from this day")
arguments = parser.parse_args()

NOW = (datetime.datetime.strptime(arguments.now, "%Y-%m-%d") if arguments.now else datetime.datetime.utcnow())
NOW = NOW.replace(hour=12, minute=0, second=0, microsecond=0, tzinfo=datetime.timezone.utc)

OUT = arguments.out
if os.path.isdir(OUT):
    shutil.rmtree(OUT)
counter = 0
truth = {"now": NOW.strftime("%Y-%m-%d"), "expect": [], "reject": [], "notes": []}


def months_back(count, day, hour=9):
    """The given day of the month `count` months before NOW (clamped to the month's length)."""
    year, month = NOW.year, NOW.month - count
    while month <= 0:
        month += 12
        year -= 1
    day = min(day, calendar.monthrange(year, month)[1])
    return datetime.datetime(year, month, day, hour, 14, 0, tzinfo=datetime.timezone.utc)


def days_back(count, hour=10):
    return (NOW - datetime.timedelta(days=count)).replace(hour=hour)


def recent_monthly(day, count):
    """`count` monthly dates on `day`, the latest one in the past."""
    start = 0 if months_back(0, day) <= NOW else 1
    return [months_back(start + i, day) for i in range(count)][::-1]


def page(body, preheader="", footer=True, ld=None):
    script = ""
    if ld is not None:
        script = '<script type="application/ld+json">%s</script>' % json.dumps(ld)
    foot = ""
    if footer:
        foot = ('<table role="presentation" width="100%"><tr><td style="font-size:11px;color:#888">'
                'You received this email because you have an account with us. '
                '<a href="https://example.com/privacy">Privacy Policy</a> &middot; '
                '<a href="https://example.com/terms">Terms of Use</a> &middot; '
                '<a href="https://example.com/refunds">Refund Policy</a> &middot; '
                'Questions about cancellation? See our cancellation policy.</td></tr></table>')
    return ('<!DOCTYPE html><html><head><meta charset="utf-8"><style>td{font-family:Helvetica,Arial}'
            '.muted{color:#777}</style>%s</head><body>'
            '<div style="display:none;max-height:0;overflow:hidden">%s</div>'
            '<table role="presentation" width="600" align="center"><tr><td>%s</td></tr></table>%s'
            '</body></html>') % (script, preheader, body, foot)


def rows(pairs):
    return "".join('<tr><td>%s</td><td align="right">%s</td></tr>' % pair for pair in pairs)


def add(date, sender, subject, text=None, html=None, folder="INBOX", charset="utf-8", cte=None,
        auth=None, unsubscribe=False, message_id=None, extra=None):
    """Writes one message. `auth` is the registrable domain the receiving server verified (DKIM + SPF),
    or "fail" for a message that failed DMARC."""
    global counter
    counter += 1
    message = EmailMessage()
    message["From"] = sender
    message["To"] = "Test Person <tester@pausely.test>"
    message["Subject"] = subject
    message["Date"] = format_datetime(date)
    message["Message-ID"] = message_id or "<pausely-test-%04d@mail.pausely.test>" % counter
    if auth == "fail":
        message["Authentication-Results"] = ("mx.pausely.test; dkim=fail header.i=@bulk-sender.example; "
                                             "spf=softfail smtp.mailfrom=bulk-sender.example; dmarc=fail header.from=%s"
                                             % sender.split("@")[-1].strip(">"))
    elif auth:
        message["Authentication-Results"] = ("mx.pausely.test; dkim=pass header.i=@%s header.s=s1; "
                                             "spf=pass smtp.mailfrom=bounce.%s; dmarc=pass header.from=%s"
                                             % (auth, auth, auth))
    if unsubscribe:
        message["List-Unsubscribe"] = "<mailto:unsubscribe@example.com>, <https://example.com/unsubscribe>"
        message["Precedence"] = "bulk"
    for key, value in (extra or {}).items():
        message[key] = value
    if text is not None:
        message.set_content(text, charset=charset, cte=cte or ("7bit" if charset == "iso-2022-jp" else "quoted-printable"))
        if html is not None:
            message.add_alternative(html, subtype="html", charset="utf-8", cte="quoted-printable")
    elif html is not None:
        message.set_content(html, subtype="html", charset=charset, cte=cte or "base64")
    else:
        message.set_content("")
    directory = os.path.join(OUT, folder)
    os.makedirs(directory, exist_ok=True)
    name = "%s_%04d.eml" % (date.strftime("%Y%m%dT%H%M"), counter)
    with open(os.path.join(directory, name), "wb") as handle:
        handle.write(message.as_bytes())
    return message["Message-ID"]


def expect(name, amount, currency, period, state="active", tier="likely", why=""):
    truth["expect"].append({"name": name, "amount": amount, "currency": currency, "period": period,
                            "state": state, "minTier": tier, "why": why})


def reject(name, why):
    truth["reject"].append({"name": name, "why": why})


def english_date(date):
    return "%s %d, %d" % (date.strftime("%b"), date.day, date.year)


# =====================================================================================
# SUBSCRIPTIONS (every one must be found)
# =====================================================================================

# --- Netflix: six monthly receipts, multipart, signed. One copy also sits in Archive (same Message-ID).
netflix_dates = recent_monthly(12, 6)
for index, date in enumerate(netflix_dates):
    next_date = english_date(months_back(-1, 12) if index == len(netflix_dates) - 1 else netflix_dates[index + 1])
    text = ("Hi Tester,\n\nThanks for being a member. Here is your receipt.\n\nPlan: Standard\n"
            "Billing period: monthly\nAmount charged: $15.49\nPayment method: Visa ending 4242\n"
            "Your membership renews on %s.\n\nQuestions? Visit the Help Centre.\n" % next_date)
    html = page("<h1>Your receipt</h1><table>%s</table><p class='muted'>Your membership renews on %s.</p>"
                % (rows([("Plan", "Standard"), ("Billing period", "Monthly"), ("Amount charged", "$15.49")]), next_date),
                preheader="Your monthly receipt is ready")
    mid = add(date, "Netflix <info@account.netflix.com>", "Your Netflix receipt", text=text, html=html, auth="netflix.com")
    if index == 2:
        add(date, "Netflix <info@account.netflix.com>", "Your Netflix receipt", text=text, html=html,
            auth="netflix.com", folder="Archive", message_id=mid)
expect("Netflix", "15.49", "USD", "monthly", tier="confirmed", why="six signed receipts; the forged one must not win")

# A forged "Netflix" receipt that failed DMARC: must not change the amount or count as proof.
add(days_back(4), "Netflix <billing@netflix.com>", "Your Netflix payment receipt",
    text="Your Netflix membership was renewed.\nAmount charged: $99.99\nYour membership renews monthly.\n", auth="fail")
# A promotion from the real sender. IMAP has no "Promotions" label; the wording has to be enough.
add(days_back(9), "Netflix <info@members.netflix.com>", "New this week, picked for you",
    html=page("<p>Tonight's picks are in.</p><p>Thinking about a different plan? Plans from $7.99/month.</p>"),
    auth="netflix.com", unsubscribe=True)
# A refund: not a charge.
add(months_back(4, 20), "Netflix <info@account.netflix.com>", "Your refund is on its way",
    text="We have refunded $15.49 to your Visa ending 4242. It can take 5 to 7 days to appear.\n", auth="netflix.com")

# --- Spotify, in German, euros with a decimal comma, HTML only (base64).
for date in recent_monthly(5, 5):
    add(date, "Spotify <no-reply@spotify.com>", "Deine Quittung von Spotify",
        html=page("<h2>Quittung</h2><table>%s</table><p>Dein Abonnement verlängert sich automatisch jeden Monat.</p>"
                  % rows([("Spotify Premium Individual", "10,99 €"), ("Gesamt", "10,99 €"),
                          ("Zahlungsmethode", "Visa •••• 4242")])),
        auth="spotify.com")
expect("Spotify", "10.99", "EUR", "monthly", tier="confirmed", why="German receipt, decimal comma, HTML only")
add(days_back(12), "Spotify <no-reply@spotify.com>", "3 Monate Premium für 0,00 €",
    html=page("<p>Nur für kurze Zeit: 3 Monate Premium für 0,00 €, danach 10,99 € pro Monat.</p>"),
    auth="spotify.com", unsubscribe=True)

# --- Apple receipts, HTML only: each lists TWO subscriptions with their own price and renewal line.
for date in recent_monthly(3, 4):
    renews = english_date(months_back(-1, 3) if date == recent_monthly(3, 4)[-1] else date + datetime.timedelta(days=31))
    body = ("<h1>Receipt</h1><p>APPLE ACCOUNT tester@pausely.test &nbsp; DATE %s</p>"
            "<p>ORDER ID MXT4%04d &nbsp; DOCUMENT NO. 1650%05d</p><table>"
            "<tr><td><b>iCloud+</b><br>iCloud+ with 200 GB of Storage (Monthly)<br><span class='muted'>Renews %s</span></td>"
            "<td align='right'>$2.99</td></tr>"
            "<tr><td><b>Duolingo - Language Lessons</b><br>Super Duolingo (Monthly)<br><span class='muted'>Renews %s</span></td>"
            "<td align='right'>$12.99</td></tr>"
            "<tr><td>Subtotal</td><td align='right'>$15.98</td></tr><tr><td>Tax</td><td align='right'>$0.00</td></tr>"
            "<tr><td><b>TOTAL</b></td><td align='right'><b>$15.98</b></td></tr></table>"
            "<p class='muted'>If you have any questions about your bill, visit Apple Support. "
            "You can manage your subscriptions in Settings.</p>") % (english_date(date), date.day, date.month, renews, renews)
    add(date, "Apple <no_reply@email.apple.com>", "Your receipt from Apple.", html=page(body, footer=False), auth="apple.com")
expect("iCloud+", "2.99", "USD", "monthly", tier="likely", why="first item on a two-item App Store receipt")
expect("Duolingo", "12.99", "USD", "monthly", tier="likely", why="second item on the same App Store receipts")

# An App Store receipt for one-time purchases: no renewal line, so not a subscription.
add(days_back(40), "Apple <no_reply@email.apple.com>", "Your receipt from Apple.",
    html=page("<h1>Receipt</h1><table><tr><td><b>Castle Siege</b><br>Sack of Gems<br><span class='muted'>In-App Purchase</span></td>"
              "<td align='right'>$4.99</td></tr><tr><td><b>TOTAL</b></td><td align='right'><b>$4.99</b></td></tr></table>",
              footer=False), auth="apple.com")
add(days_back(71), "Apple <no_reply@email.apple.com>", "Your receipt from Apple.",
    html=page("<h1>Receipt</h1><table><tr><td><b>Pocket Planner Pro</b><br>App<br></td>"
              "<td align='right'>$9.99</td></tr><tr><td><b>TOTAL</b></td><td align='right'><b>$9.99</b></td></tr></table>",
              footer=False), auth="apple.com")
reject("Castle Siege", "one-time in-app purchase on an App Store receipt")
reject("Pocket Planner", "one-time app purchase on an App Store receipt")
reject("Sack of Gems", "one-time in-app purchase")

# --- Disney+ in Japanese, yen, ISO-2022-JP text.
for date in recent_monthly(21, 4):
    add(date, "Disney+ <disneyplus@mail.disneyplus.com>", "Disney+ ご利用料金のお知らせ",
        text="いつもご利用いただきありがとうございます。\n\nプラン: スタンダード（月額）\nご請求額: ¥990\n"
             "お支払い方法: クレジットカード\nサブスクリプションは毎月自動更新されます。\n",
        charset="iso-2022-jp", auth="disneyplus.com")
expect("Disney+", "990", "JPY", "monthly", tier="confirmed", why="Japanese receipt in ISO-2022-JP")

# --- YouTube Premium through Google Play.
for date in recent_monthly(18, 4):
    add(date, "Google Play <googleplay-noreply@google.com>", "Your YouTube Premium subscription from Google Play",
        text="Thank you.\n\nYou've been charged for your subscription to YouTube Premium on Google Play.\n\n"
             "Order number: GPA.3345-%04d-1123-55601\nOrder date: %s\n\nItem: YouTube Premium (YouTube)\nPrice: $13.99/month\n"
             "Total: $13.99\n\nYour subscription renews automatically each month until you cancel.\n" % (date.day * 37, english_date(date)),
        auth="google.com")
expect("YouTube Premium", "13.99", "USD", "monthly", tier="confirmed", why="Google Play subscription receipt")

# --- An unknown SaaS billed through Stripe: quantity line, service period, no renewal wording.
for date in recent_monthly(1, 5):
    end = date + datetime.timedelta(days=30)
    period = "%s – %s" % (date.strftime("%b %-d"), english_date(end))
    text = ("Receipt from Linear Orbit\nReceipt #2041-%04d\n\nAmount paid\n$12.00\nDate paid\n%s\nPayment method\nVisa - 4242\n\n"
            "Summary\n%s\nStarter plan\nQty 1\n$12.00\n\nSubtotal\n$12.00\nAmount paid\n$12.00\n\n"
            "If you have any questions, contact us at hello@linearorbit.example.\n") % (date.day * 91, english_date(date), period)
    add(date, "Linear Orbit <invoice+statements@stripe.com>", "Your receipt from Linear Orbit #2041-%04d" % (date.day * 91),
        text=text, html=page("<pre>%s</pre>" % text, footer=False), auth="stripe.com")
expect("Linear Orbit", "12.00", "USD", "monthly", tier="likely", why="unknown merchant, Stripe receipt with a service period")

# --- PayPal automatic payment to a small merchant.
for date in recent_monthly(14, 4):
    add(date, "service@paypal.com <service@paypal.com>", "You sent an automatic payment to Cloudvault",
        text="Hello Test Person,\n\nYou sent an automatic payment of $6.00 USD to Cloudvault.\n\n"
             "Transaction ID: 9X4%05dT\nNext payment due: %s\nPaid with: Visa x-4242\n\n"
             "You can manage automatic payments in your PayPal settings.\n" % (date.day * 311, english_date(date + datetime.timedelta(days=30))),
        auth="paypal.com")
expect("Cloudvault", "6.00", "USD", "monthly", tier="likely", why="PayPal automatic payment")

# --- Adobe, yearly; the older receipt sits in Archive. The renewal is under 45 days away.
adobe_last = NOW - datetime.timedelta(days=335)
for date, folder in [(adobe_last - datetime.timedelta(days=365), "Archive"), (adobe_last, "INBOX")]:
    add(date.replace(hour=8), "Adobe <mail@mail.adobe.com>", "Your Adobe subscription receipt",
        html=page("<h2>Thanks for your payment</h2><table>%s</table><p>Your annual plan renews automatically on %s each year.</p>"
                  % (rows([("Creative Cloud All Apps", "Annual plan, prepaid"), ("Amount charged", "US$239.88")]),
                     date.strftime("%B %-d"))),
        folder=folder, auth="adobe.com")
expect("Adobe Creative Cloud", "239.88", "USD", "yearly", tier="likely", why="two receipts a year apart, one archived")

# --- Amazon Prime membership (while Amazon orders are not subscriptions).
for date in recent_monthly(9, 5):
    add(date, "Amazon.com <auto-confirm@amazon.com>", "Your Amazon Prime membership payment",
        text="Hello,\n\nWe charged $14.99 to your Visa ending in 4242 for your Prime membership.\n"
             "Your membership renews monthly. You can manage it under Your Account.\n", auth="amazon.com")
expect("Amazon Prime", "14.99", "USD", "monthly", tier="confirmed", why="membership fee, not an order")

# --- A local gym nobody has heard of, billed directly.
for date in recent_monthly(3, 4):
    add(date, "Ironside Fitness <billing@ironsidefitness.example>", "Membership payment received",
        text="Thank you. We received your monthly membership payment of $34.99.\n"
             "Your membership renews on the 3rd of each month.\n")
expect("Ironside Fitness", "34.99", "USD", "monthly", tier="likely", why="unknown merchant with steady charges")

# --- A free trial that started three days ago.
add(days_back(3), "Notion <team@mail.notion.so>", "Your free trial has started",
    text="Welcome to your 14-day free trial of Notion Plus.\nWhen the trial ends you'll be billed $10.00 per month unless you cancel.\n",
    auth="notion.so")
expect("Notion", "10.00", "USD", "monthly", state="trial", tier="likely", why="trial start, no charge yet")

# --- Hulu: three receipts, the last one six months ago.
for count in (8, 7, 6):
    add(months_back(count, 8), "Hulu <hulu@hulumail.com>", "Your Hulu receipt",
        text="Hulu (No Ads)\nTotal: $18.99 billed monthly.\nYour subscription renews each month.\n", auth="hulu.com",
        extra={"Reply-To": "support@hulu.com"})
expect("Hulu", "18.99", "USD", "monthly", state="ended", tier="likely", why="no charge for six months")

# --- Paramount+: paid, then cancelled.
for count in (4, 3, 2):
    add(months_back(count, 16), "Paramount+ <paramountplus@email.paramountplus.com>", "Your Paramount+ receipt",
        text="Paramount+ Essential\nTotal: $7.99 per month. Your subscription renews monthly.\n", auth="paramountplus.com")
add(months_back(1, 2), "Paramount+ <paramountplus@email.paramountplus.com>", "Your subscription has been cancelled",
    text="We're sorry to see you go. Your Paramount+ subscription has been cancelled and you won't be charged again.\n",
    auth="paramountplus.com")
expect("Paramount+", "7.99", "USD", "monthly", state="cancelled", tier="likely", why="cancellation email after the last charge")

# --- ChatGPT Plus.
for date in recent_monthly(27, 5):
    add(date, "OpenAI <noreply@tm.openai.com>", "Your ChatGPT Plus receipt",
        html=page("<h2>Receipt</h2><table>%s</table><p>ChatGPT Plus Subscription, billed monthly.</p>"
                  % rows([("ChatGPT Plus Subscription", "$20.00"), ("Tax", "$0.00"), ("Total", "$20.00"), ("Amount paid", "$20.00")])),
        auth="openai.com")
expect("ChatGPT Plus", "20.00", "USD", "monthly", tier="confirmed", why="known service, five receipts")

# --- Deezer in French, Windows-1252 quoted-printable (the euro sign is not in ISO-8859-1).
for date in recent_monthly(7, 4):
    add(date, "Deezer <noreply@deezer.com>", "Votre reçu Deezer Premium",
        text="Bonjour,\n\nMerci pour votre paiement.\n\nOffre : Deezer Premium\nMontant facturé : 11,99 €\n"
             "Votre abonnement mensuel se renouvelle automatiquement.\n\nL'équipe Deezer\n",
        charset="windows-1252", auth="deezer.com")
expect("Deezer", "11.99", "EUR", "monthly", tier="confirmed", why="French receipt in Windows-1252")

# --- Max in Spanish.
for date in recent_monthly(23, 4):
    add(date, "Max <ayuda@mail.max.com>", "Tu recibo de Max",
        text="Hola:\n\nGracias por tu pago.\n\nPlan: Estándar\nImporte cobrado: 9,99 €\nTu suscripción se renovará cada mes.\n",
        auth="max.com")
expect("Max", "9.99", "EUR", "monthly", tier="confirmed", why="Spanish receipt")

# --- 1Password: one yearly receipt, five months old.
add(months_back(5, 11), "1Password <billing@1password.com>", "Your 1Password receipt",
    text="Thanks for your payment.\n\n1Password Individual, billed annually\nAmount paid: $35.88\n"
         "Your subscription will renew automatically next year.\n", auth="1password.com")
expect("1Password", "35.88", "USD", "yearly", tier="likely", why="a single receipt that says billed annually")

# --- Crunchyroll: the price went up.
for index, date in enumerate(recent_monthly(25, 5)):
    amount = "7.99" if index < 3 else "9.99"
    add(date, "Crunchyroll <no-reply@crunchyroll.com>", "Your Crunchyroll receipt",
        text="Crunchyroll Fan\nAmount charged: $%s\nYour membership renews monthly.\n" % amount, auth="crunchyroll.com")
add(months_back(3, 2), "Crunchyroll <no-reply@crunchyroll.com>", "An update to your membership price",
    text="Starting with your next bill, the price of Crunchyroll Fan will change to $9.99 per month.\n", auth="crunchyroll.com")
expect("Crunchyroll", "9.99", "USD", "monthly", state="priceIncreased", tier="confirmed", why="7.99 then 9.99")

# --- The Economist, quarterly, pounds.
for count in (7, 4, 1):
    add(months_back(count, 19), "The Economist <subscriptions@e.economist.com>", "Your subscription payment",
        text="Thank you for subscribing.\n\nDigital subscription\nAmount paid: £29.00\nBilled every 3 months. "
             "Your subscription will renew automatically.\n", auth="economist.com")
expect("The Economist", "29.00", "GBP", "quarterly", tier="confirmed", why="three charges three months apart")

# --- An Arabic receipt in Saudi riyals.
for date in recent_monthly(10, 4):
    add(date, "Shahid <no-reply@shahid.example>", "إيصال اشتراكك في شاهد",
        text="مرحبًا،\n\nشكرًا لاشتراكك.\n\nالباقة: VIP\nالمبلغ المدفوع: 29.99 ر.س\n"
             "يتجدد اشتراكك تلقائيًا كل شهر.\n", cte="base64")
expect("Shahid", "29.99", "SAR", "monthly", tier="likely", why="Arabic receipt, riyals")

# --- A plan whose price has no cents.
for date in recent_monthly(15, 4):
    add(date, "Fathom Notes <billing@fathomnotes.example>", "Your Fathom Notes invoice",
        text="Invoice paid.\n\nFathom Notes Pro\n$8 per month\nTotal: $8\nYour plan renews monthly.\n")
expect("Fathom Notes", "8", "USD", "monthly", tier="likely", why="whole-dollar price")

# =====================================================================================
# NOT SUBSCRIPTIONS (none may be listed)
# =====================================================================================

orders = [(3, "42.17"), (17, "18.99"), (33, "126.40"), (52, "33.15"), (70, "64.80"), (95, "21.99")]
for index, (ago, total) in enumerate(orders):
    ld = None
    if index % 3 == 0:
        ld = [{"@context": "http://schema.org", "@type": "Order", "seller": {"@type": "Organization", "name": "Amazon.com"},
               "orderNumber": "112-%07d" % (index * 7919), "priceCurrency": "USD", "price": total,
               "acceptedOffer": {"@type": "Offer", "price": total, "priceCurrency": "USD"}},
              {"@context": "http://schema.org", "@type": "ParcelDelivery", "provider": {"@type": "Organization", "name": "Amazon.com"}}]
    add(days_back(ago), "Amazon.com <shipment-tracking@amazon.com>", "Your Amazon.com order #112-%07d has shipped" % (index * 7919),
        text="Thanks for your order.\nOrder #112-%07d\nTracking number 1Z999\nOrder Total: $%s\n" % (index * 7919, total),
        html=page("<p>Your package is on its way.</p><p>Order Total: $%s</p>" % total, ld=ld), auth="amazon.com")
reject("Amazon", "orders, not the membership (Amazon Prime is listed separately)")

for ago, total in [(2, "23.45"), (11, "14.10"), (24, "31.80"), (38, "12.95"), (51, "27.60"), (66, "19.35")]:
    add(days_back(ago, hour=22), "Uber Receipts <noreply@uber.com>", "Your Tuesday evening trip with Uber",
        text="Thanks for riding, Tester\nTotal $%s\nTrip fare $%s\nYou rode with Sam\n" % (total, total), auth="uber.com")
reject("Uber", "rides")

for ago, total in [(1, "33.83"), (8, "21.50"), (29, "48.04"), (43, "12.90"), (60, "27.30")]:
    add(days_back(ago, hour=19), "DoorDash <no-reply@doordash.com>", "Order Confirmation for Tester from Pizza Palace",
        text="Your order from Pizza Palace\nOrder #55%d\nDashPass savings: $3.00\nDelivery fee $0.00\nTotal $%s\n" % (ago, total),
        auth="doordash.com")
reject("DoorDash", "food orders that mention DashPass savings")
reject("DashPass", "only mentioned as a saving on orders")

add(days_back(48), "Frontgate Tickets <orders@frontgatetickets.example>", "Your tickets for Summer Fest",
    text="E-tickets attached. Order #44721. 2 x General Admission. Total: $394.99\n")
reject("Frontgate", "tickets")
add(days_back(77), "Air Example <bookings@airexample.example>", "Your itinerary",
    html=page("<p>Booking confirmed. Total paid $612.40</p>",
              ld={"@context": "http://schema.org", "@type": "FlightReservation",
                  "reservationFor": {"@type": "Flight", "flightNumber": "AX123"}, "totalPrice": "612.40", "priceCurrency": "USD"}))
reject("Air Example", "a flight")
add(days_back(30), "Harbour Hotel <reservations@harbourhotel.example>", "Booking confirmation 88213",
    text="Your reservation is confirmed. 2 nights. Total: $418.00. Check-in from 3 pm.\n")
reject("Harbour Hotel", "a hotel booking")

for count, amount in [(4, "82.14"), (3, "91.50"), (2, "77.02"), (1, "120.33")]:
    add(months_back(count, 28), "City Hydro <billing@cityhydro.example>", "Your bill is ready",
        text="Your electricity bill is ready.\nAmount due: $%s\nDue date: in 14 days.\n" % amount)
reject("City Hydro", "a utility bill that changes every month")

for ago in (6, 37, 67):
    add(days_back(ago), "Interac e-Transfer <notify@payments.interac.example>", "INTERAC e-Transfer: You sent money",
        text="You sent $1,200.00 to Landlord Property Mgmt. The money has been deposited.\n")
reject("Interac", "money transfers")
reject("Landlord", "rent sent by transfer")

for ago, amount in [(5, "350.00"), (35, "410.22"), (66, "298.10")]:
    add(days_back(ago), "Northern Bank <alerts@northernbank.example>", "We received your credit card payment",
        text="Thank you. Your payment of $%s to your Northern Bank Visa was received.\nYour new balance is $1,204.19.\n" % amount)
reject("Northern Bank", "credit card payments")

for ago in (3, 10, 17, 24):
    add(days_back(ago), "Best Deals Weekly <deals@bestdeals.example>", "This week's best deals: up to 60% off",
        html=page("<p>Headphones $59.99 (was $149.99)</p><p>Streaming stick $24.99</p><p>12 months of cloud storage $19.99/year</p>"),
        unsubscribe=True)
reject("Best Deals", "a weekly promotion full of prices")

for ago in (4, 9, 16, 31, 44):
    add(days_back(ago, hour=8), "ParkRight <receipts@parkright.example>", "Your parking session receipt",
        text="Parking session ended.\nZone 4412 · 1 h 30 min\nTotal charged: $3.50\n")
reject("ParkRight", "parking sessions that happen to cost the same")

add(days_back(58), "Paddle.com <help@paddle.com>", "Your receipt for Sketchbook Studio",
    text="Thanks for your purchase.\n\nSketchbook Studio — lifetime licence\nQuantity: 1\nTotal: US$49.00\n"
         "This is a one-time purchase. Paddle.com is the reseller of this product.\n", auth="paddle.com")
reject("Sketchbook", "a one-time licence sold through Paddle")

add(days_back(20), "Riverbank Shelter <giving@riverbankshelter.example>", "Thank you for your donation",
    text="Thank you for your one-time donation of $50.00. This email is your tax receipt.\n")
reject("Riverbank", "a one-time donation")

add(days_back(15), "Maple Outfitters <orders@mapleoutfitters.example>", "Your order has shipped",
    text="Good news. Order #88120 is on its way.\nSubtotal $89.00\nShipping $9.00\nTotal $98.00\nTracking number 7Z1234\n")
reject("Maple Outfitters", "a shipped order")

for ago in (7, 14, 21):
    add(days_back(ago), "The Daily Brief <news@dailybrief.example>", "Your weekly newsletter",
        text="Top stories this week. Plans start at $5 a month for members. Unsubscribe any time.\n", unsubscribe=True)
reject("Daily Brief", "a newsletter")

# Folders that must never be searched.
for count in (3, 2, 1):
    add(months_back(count, 6), "Tidal <no-reply@tidal.com>", "Your TIDAL receipt",
        text="TIDAL HiFi\nAmount charged: $10.99\nYour subscription renews monthly.\n", folder="Trash", auth="tidal.com")
reject("Tidal", "receipts that are in the Trash")
add(days_back(2), "Apple Support <billing@apple-id-renewal.example>", "Your subscription renewal: $49.99",
    text="Your Apple ID subscription was renewed for $49.99. If this wasn't you, click here.\n", folder="Junk")
reject("Apple Support", "phishing in Junk")

# =====================================================================================
with open(os.path.join(OUT, "truth.json"), "w") as handle:
    json.dump(truth, handle, indent=2, ensure_ascii=False)

total = sum(len(files) for _, _, files in os.walk(OUT)) - 1
print("wrote %d messages to %s (%d subscriptions expected, %d names rejected)"
      % (total, OUT, len(truth["expect"]), len(truth["reject"])))
