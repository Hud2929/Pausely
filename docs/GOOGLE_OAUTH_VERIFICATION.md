# Google OAuth Verification — Submission Guide

Use this file when submitting Pausely for Google OAuth app verification at:
**console.cloud.google.com → APIs & Services → OAuth consent screen → Submit for verification**

---

## App Name
Pausely

## App Homepage URL
https://pausely.pro

## Privacy Policy URL
https://pausely.pro/privacy.html

---

## Scopes Requested

| Scope | Justification |
|---|---|
| `https://www.googleapis.com/auth/gmail.readonly` | Read email receipts to detect subscription services |

---

## Scope Justification (paste this into the "Justification" field)

> Pausely is a subscription management app that helps users track, analyze, and optimize their recurring subscriptions. The `gmail.readonly` scope is required to scan email receipts and billing confirmations from subscription services, so users don't have to enter subscriptions manually.
>
> **How we use Gmail data:**
> - We search only for likely billing mail (known billing senders and receipt words in the subject, last 2 years), read those messages' headers (From, Subject, Date), and open the full message only for the ones that look like receipts
> - All email processing happens on the user's device — email content is never transmitted to Pausely's servers
> - Spam and Trash are never read; nothing is marked as read, changed or deleted
> - We extract only the subscription name, billing amount, and billing date, which are saved to the user's account
> - We do not read, store, or process emails unrelated to subscription billing
> - We do not use Gmail data for advertising, profiling, or any purpose beyond subscription detection
>
> **Why gmail.readonly is necessary:**
> Subscription receipts come from many different senders (Stripe, Apple, Google Play, PayPal, etc.) and cannot be detected without reading email body content. A metadata-only scope would miss the billing amounts and service names contained in receipt bodies.
>
> **Data minimization:**
> We request only `gmail.readonly`. We do not request `gmail.modify`, `gmail.compose`, `mail.google.com`, or any write scope.

---

## Application Description (paste into the "Application description" field)

> Pausely helps users track all their recurring subscriptions in one place. The Gmail integration scans billing receipts to automatically detect subscription services — so users can see everything they're paying for without manual entry. Email content is processed entirely on the user's device. Only the extracted subscription details (service name, amount, billing date) are saved to the user's account. Pausely never stores email content, cannot send or delete emails, and does not use Gmail data for any purpose other than subscription detection.

---

## Demo Video / Steps to Reproduce (Google requires this for restricted scopes)

Record a short screen recording (current app, 1.0.4 or later with Gmail turned on) showing:
1. Open Pausely → Profile → "Find subscriptions in email"
2. Show the privacy notice: "Your email never leaves your iPhone."
3. Tap "Gmail — Sign in with Google" → Google's consent screen shows the gmail.readonly scope
4. Grant access → tap "Find subscriptions" → the results list each subscription with the receipts it came from ("Show why")
5. Select some and tap "Import" → they appear in the subscription list
6. Tap the inbox's options (…) → "Disconnect" → the token is revoked at Google and the inbox and its receipt facts are removed from the phone

Upload to YouTube (unlisted) or Google Drive and paste the link in the verification form.

---

## Limited Use Compliance Statement

Pausely's use of data received from Gmail APIs:
- Is limited to providing subscription detection features to the user
- Does not transfer Gmail data to third parties
- Does not use Gmail data for advertising
- Does not allow humans to read user email unless required by law or explicitly requested by the user for support
- Complies with the Google API Services User Data Policy including Limited Use requirements

---

## What Happens After Submission

- Google reviews take **4–6 weeks** for restricted scopes
- You'll receive email updates at the Google account associated with the Cloud project
- During review, the app is capped at **100 test users** (add them at OAuth consent screen → Test users)
- If rejected, Google will explain why — common reasons: privacy policy doesn't mention Gmail, justification too vague, no demo video
- If approved, the "unverified app" warning screen goes away for all users

---

## CASA Tier 2 Assessment

Because Pausely uses a restricted Gmail scope, Google may require a **CASA (Cloud Application Security Assessment) Tier 2** audit before approval.

**Key fact to document for the assessor:**
- Raw email content is fetched via Gmail API directly to the user's iPhone
- It is parsed on-device in `GmailSubscriptionScanner.swift`
- Only structured subscription data (name, amount, date) is written to Supabase
- The Supabase server never receives or processes raw email content

**Approved CASA assessors:** NowSecure, Bishop Fox, Leviathan Security Group, Coalfire
**Cost:** ~$3,000–8,000 USD
**Timeline:** 4–8 weeks

Start the assessor engagement at the same time as the Google verification submission — they run in parallel.
