# Google OAuth Verification — Submission Guide

Use this file when submitting Pausely for Google OAuth app verification at:
**console.cloud.google.com → APIs & Services → OAuth consent screen → Submit for verification**

---

## App Name
Pausely

## App Homepage URL
https://www.pausely.app

## Privacy Policy URL
https://www.pausely.app/privacy

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
> - We read email headers (From, Subject, Date) and body content to identify subscription receipts
> - All email processing happens on the user's device — email content is never transmitted to Pausely's servers
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

Record a short screen recording showing:
1. Open Pausely → Profile → Import from Gmail
2. Tap "Connect Gmail" → OAuth consent screen appears
3. Grant access → app scans and shows found subscriptions
4. Show the privacy notice: "Your emails never leave your phone"
5. Tap Disconnect → access revoked

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
