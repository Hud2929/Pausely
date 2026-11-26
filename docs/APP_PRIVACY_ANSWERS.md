# App Store Connect: "App Privacy" answers for Pausely

Written 2026-11-17 from the code (what the app sends to the server), not from marketing text. These
are the answers for App Store Connect → the app → App Privacy. They say what
`Pausely/PrivacyInfo.xcprivacy` declares and what the policy at https://pausely.pro/privacy.html
says; `PrivacyManifestTests` fails when this table and the manifest list different types.

**Tracking:** No. Pausely does not track anyone across other companies' apps or websites, has no
advertising or analytics software in it, and does not use the advertising identifier. No tracking
domains.

## Data collected (each linked to the account, each for App Functionality only, none for tracking)

| Apple category → type | What it is in Pausely | Purpose |
|---|---|---|
| Contact Info → **Email Address** | The address the account is made with and signed in by | App Functionality |
| Identifiers → **User ID** | The account's identifier | App Functionality |
| Financial Info → **Other Financial Info** | What each subscription costs, its currency, how often it charges and its next renewal or trial end | App Functionality |
| User Content → **Other User Content** | Each subscription's name, category, status and how many days before a renewal to remind | App Functionality |
| Other Data → **Other Data Types** | That the person confirmed they are old enough, and when (the date of birth is not stored), with the policy and app version in use | App Functionality |

**Where each is sent, in the code:** the account is made by Supabase sign-in (`AuthManager`); the
list is the `subscriptions` table (`Subscription.CodingKeys`, sent by `Sync/SyncQueue`); the age
confirmation is five fields on the `profiles` row (`AgeConsentManager`).

## Not collected

- **A name.** Sign in with Apple can hand over a name; it is kept on the iPhone only
  (`AccountMemory`) and never sent.
- **How long a subscription was used.** The hours are typed in by the person and stay on the iPhone
  (`UsageLog`). Pausely does not read Screen Time.
- **History, the Savings Receipt and the Pause Plan.** Stored locally under iOS hardware data protection, and synced to your Supabase account when signed in so reinstalling or switching devices preserves them (covered by **Other User Content** above; kept on-device only in optional guest mode).
- Location, contacts, photos, audio, health, browsing or search history, device or advertising
  identifiers, purchase history (payments are Apple's), diagnostics, crash data, performance data.

## Things that look like collection but are not

- **Import from screenshots (optional):** Screenshots selected from Photos are read purely in memory on
  the device using Apple's Vision framework and are never saved to disk or sent to Pausely's servers.

- **Find in Email** (switched off in release builds): mail is read on the iPhone, and only the name,
  amount and date of each charge are kept, on the iPhone. Nothing from a mailbox reaches Pausely's
  servers. If that ever changes, these answers change first.
- **Logos** are fetched from each service's own website (Duolingo's from the Amazon CloudFront address
  its site uses), and **exchange rates** from a public rates service. Neither request carries the
  account or the list.
- **Cancel help** for a service with no guide opens a Google search for its name, only when tapped.

## Other companies

- Supabase: the database and sign-in (stores the data in the table above, and the website's waitlist).
- Resend: sends the sign-in and reset codes and the waitlist's welcome email (receives the email address).
- Apple: payments and Sign in with Apple.
- Proton: the support inbox, pausely@proton.me (receives what people write to it).
- GitHub Pages: hosts pausely.pro (receives visitors' IP addresses).
- ExchangeRate-API, each service's website and Google Search: contacted as above, sent nothing about
  the person.

## Age rating

Answer Apple's questionnaire as it stands (no mature content, no gambling, no public user content).
The in-app age check is a data-consent rule, not the store rating; the questionnaire decides the rating.
