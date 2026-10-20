# Can Pausely sell customer data or analytics?

Written 2026-10-20. This is research, not legal advice. Have a privacy lawyer review before any data is sold.

## Short answer
- **Selling personal customer data: no.** It is blocked by Pausely's own promises, by Google's rules for Gmail data,
  by Apple's rules, and by privacy law, and the brand depends on trust.
- **Selling aggregated, de-identified insights: possible later**, only from data users type in themselves, only with
  clear disclosure and (recommended) opt-in consent, and after a lawyer reviews it. Never from Gmail or Screen Time data.
- **Better: sell your own catalog data, which is not customer data at all.** See the end.

## What stands in the way
1. **Pausely's own public promises.** The store description says "we never sell your data". The privacy policy and the
   in-app copy say the same. Selling anything personal would make those statements false, which is a legal problem on its
   own: the FTC treats breaking a "we never..." promise as deception.
   Precedent: Unroll.Me (an email subscription tool) let its parent company sell "anonymized" receipt data to Uber. Users
   revolted within a day and the FTC later filed a complaint because the app had told people it would "never touch your
   personal stuff" ([Privacy International](https://privacyinternational.org/examples/1919/ubers-use-unrollme-data-watch-lyft-sparks-backlash),
   [summary](https://leavemealone.com/blog/unroll-me-data-selling-explained/)). Pausely sells itself on the opposite.
2. **Google's rules (Gmail scanner).** For the restricted Gmail scope, data may not be sold or used for advertising, and
   Google user data may only be used for user-facing features that are prominent in the app; human access to it is
   limited, with aggregated and anonymized use allowed only for internal operations
   ([Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy)).
   Anything derived from Gmail is off the table, even "anonymized". Breaking this ends the Gmail approval and the feature.
3. **Apple's rules.** Apps may not use, transmit or share personal data without permission and a clear explanation of
   how and where it is used, and data collected for one purpose may not be repurposed without further consent
   ([Guideline 5.1.2](https://developer.apple.com/forums/thread/701508)). Selling to data brokers also counts as
   "tracking" in Apple's terms, which would require the App Tracking Transparency prompt, a different App Privacy label,
   and would change the "no tracking" answers in `APP_PRIVACY_ANSWERS.md`.
4. **Screen Time data.** Apple's Screen Time frameworks keep raw usage on the device by design. Pausely only saves the
   total minutes per subscription. Do not build anything that tries to export more.
5. **Privacy law.** Under California's CCPA/CPRA a "sale" needs notice, a "Do Not Sell or Share" opt-out, and special
   handling for minors; the EU's GDPR typically needs explicit, specific consent. De-identified or aggregated data is exempt only if it
   cannot reasonably be re-identified and you publicly commit to keeping it that way
   ([overview](https://www.cookieyes.com/blog/cpra-exemptions/)). Pausely also has a 16+ age gate, which limits what can be done with younger users' data.

## What could be legitimate later (needs a lawyer first)
- Aggregate statistics built from what users type in themselves: for example "which services are most tracked",
  "typical price per service in each country", "how often prices change".
- Rules: no row-level data, no identifiers, groups of at least ~50 people, no Gmail or Screen Time data, an opt-in toggle
  ("Share anonymous statistics"), the privacy policy and App Privacy labels updated first, and the wording changed from
  "we never sell your data" to "we never sell your personal data".

## The better idea: sell the catalog, not the customers
Pausely already owns data that is not customer data: about 1,190 services with their prices, plans, cancellation links and
cancellation-difficulty ratings. Options that carry no privacy risk:
- License the catalog or a price-change feed (API) to other apps, finance tools or publishers.
- Publish "what streaming costs in 2026" style content (also good for search ranking).
- Affiliate or partner offers on the cheaper-alternatives screen, clearly labeled as such.

## Until then
Do not collect extra data "for later sale". Collecting less is the safest position, and it keeps the "we never sell your
data" promise true.
