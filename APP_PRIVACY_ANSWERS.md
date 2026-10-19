# App Store Connect: "App Privacy" answers for Pausely

Prepared 2026-10-19 from the code (what the app actually sends to the server), not from marketing text.
Enter these in App Store Connect → your app → App Privacy. They must match `Pausely/PrivacyInfo.xcprivacy`
(already updated to the same list) and the Privacy Policy at https://pausely.pro/privacy.html.

**Tracking:** No. Pausely does not track users across other companies' apps or websites, has no advertising
SDK, and does not use the advertising identifier. No tracking domains.

## Data collected (all "linked to the user's identity", none used for tracking)

| Apple category → type | What it is in Pausely | Purpose |
|---|---|---|
| Contact Info → **Email Address** | Used to create the account and sign in | App Functionality |
| Contact Info → **Name** | Optional first and last name given at sign-up | App Functionality |
| Identifiers → **User ID** | The account identifier | App Functionality |
| Financial Info → **Other Financial Info** | The subscription prices and billing dates the user enters | App Functionality |
| User Content → **Other User Content** | Subscription names, categories, and cancellation-difficulty ratings the user adds | App Functionality |
| Usage Data → **Other Usage Data** | Minutes of use per subscription, only if the user grants Screen Time access | App Functionality |
| Other Data → **Other Data Types** | A record that the user confirmed they are 16 or older (yes/no and a timestamp). The date of birth itself is not stored | App Functionality |

**Checked in the code:** the per-subscription usage minutes (`monthly_usage_minutes`) are part of the record
synced to the database (`SupabaseManager.swift`), so "Other Usage Data" is correct. The value stays 0 unless the
user grants Screen Time access.

**Website wording to fix after Google approves the Gmail scope** (editing the privacy page during review is risky):
`privacy.html` says Screen Time powers a "Smart Pause feature" (that feature does not exist) and that "detailed app
usage data" is not transmitted. Aggregate usage minutes per subscription are. Reword both to match this table.

## Data NOT collected
Location, contacts, photos, audio, health, browsing or search history, advertising or device identifiers,
purchases history held by Pausely (payments are handled by Apple), diagnostics, crash data and performance data
(there is no analytics or crash-reporting SDK in the app).

## Things that look like collection but are not
- **Gmail receipt scanning** (hidden in release builds until Google approves it): messages are read and processed
  on the device only, and only the extracted subscription facts are saved. Nothing is sent to Pausely's servers,
  so email content is not "collected" in Apple's sense. If that ever changes, the answers must change first.
- **Screen Time (Family Controls)** data is processed on the device by Apple's frameworks.

## Third parties
- Supabase: database and sign-in provider (processor; stores the data listed above).
- Apple: payments, Sign in with Apple, Screen Time APIs.
- Google: sign-in and Gmail access, only once the Gmail feature ships.

## Age rating
Answer Apple's current questionnaire honestly (no mature content, no gambling, no user-generated public content).
The in-app 16+ gate is a data-consent rule, not the store rating; the questionnaire decides the rating.
