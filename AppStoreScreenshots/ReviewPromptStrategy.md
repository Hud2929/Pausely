# Pausely Review Prompt Strategy

## Overview

Goal: Maximize positive App Store reviews while minimizing negative reviews and maintaining user trust.
Strategy: Use a two-stage prompt (in-app pre-prompt + system prompt) with intelligent timing and rate limiting.

---

## 5 Positive Moments to Trigger Review Request

### 1. First Subscription Added
**Trigger:** User successfully adds their 3rd subscription
**Why:** They have invested time in the app and see value in the dashboard filling up
**Pre-prompt:** "You're building a great overview of your subscriptions! Are you finding Pausely helpful so far?"
**Delay after action:** 2 seconds
**Max reviews/week from this trigger:** 1

### 2. Savings Discovered
**Trigger:** User views the Cost Per Hour screen and sees a "Poor Value" or "Fair Value" badge
**Why:** The app has just delivered an "aha" moment about their spending
**Pre-prompt:** "Pausely just helped you spot a subscription that might not be worth it. Finding insights like this helpful?"
**Delay after action:** 1.5 seconds
**Max reviews/week from this trigger:** 2

### 3. Successful Pause/Cancel Action
**Trigger:** User taps a cancel or pause link and returns to the app
**Why:** The app directly saved them money - peak satisfaction moment
**Pre-prompt:** "Taking control of your subscriptions feels great, doesn't it? Mind sharing the love with a quick rating?"
**Delay after action:** 3 seconds (allow time to process the action)
**Max reviews/week from this trigger:** 2

### 4. Renewal Alert Acknowledged
**Trigger:** User taps a renewal notification and opens the app
**Why:** The app prevented an unwanted surprise charge
**Pre-prompt:** "Glad we caught that renewal in time! Is Pausely helping you stay on top of your subscriptions?"
**Delay after action:** 1 second
**Max reviews/week from this trigger:** 1

### 5. Weekly Streak Milestone
**Trigger:** User opens the app for 7 consecutive days
**Why:** Habit formation indicates genuine engagement and value
**Pre-prompt:** "You've checked your subscriptions 7 days in a row! Thanks for making Pausely part of your routine."
**Delay after action:** 0.5 seconds
**Max reviews/week from this trigger:** 1

---

## In-App Pre-Prompt Wording

### Primary Pre-Prompt (General)
```
Title: Enjoying Pausely?
Body: Your feedback helps us improve and reach more people looking to take control of their subscriptions.
Buttons: [Yes, I love it!] [Not yet]
```

### Contextual Pre-Prompt (After savings discovery)
```
Title: Finding value in Pausely?
Body: Insights like cost-per-hour help users save an average of $240/year. Mind sharing your experience?
Buttons: [Absolutely!] [Ask me later]
```

### Contextual Pre-Prompt (After action completion)
```
Title: Pausely working for you?
Body: Taking control of subscriptions is what we're all about. A quick rating would mean the world to us.
Buttons: [Happy to help!] [Maybe later]
```

### Contextual Pre-Prompt (For engaged users)
```
Title: You're a Pausely power user!
Body: Thanks for making us part of your daily routine. Would you share what you love most?
Buttons: [Sure thing!] [Not right now]
```

### Negative Path ("Not yet" selected)
```
Title: How can we improve?
Body: We'd love to hear what's missing. Your feedback goes directly to our team.
Buttons: [Send feedback] [Dismiss]
Action: Opens email composer or in-app feedback form. Never shows system review prompt.
```

---

## Rate Limiting Strategy

### Global Limits
- **Maximum system review prompts per user:** 3 per year
- **Minimum days between prompts:** 60 days
- **Minimum app sessions before first prompt:** 5
- **Minimum days since install before first prompt:** 3

### Per-Trigger Cooldown
- Each trigger has its own 14-day cooldown
- If a trigger fires during cooldown, it is silently ignored
- The "weekly streak" trigger only fires once per user ever

### Dismissal Handling
- If user selects "Ask me later" or "Maybe later":
  - Re-prompt eligible after 30 days
  - Counts toward the 3/year limit
- If user selects "Not yet" and provides feedback:
  - Re-prompt eligible after 60 days
  - Does NOT count toward the 3/year limit (they engaged positively)
- If user completes system review prompt:
  - Never prompt that user again

### Premium User Rule
- Premium users who have been subscribed for >30 days get one additional prompt opportunity
- This recognizes their financial commitment to the app

---

## Implementation Logic

```swift
struct ReviewPromptManager {
    static let shared = ReviewPromptManager()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let lastPromptDate = "review_lastPromptDate"
        static let promptCount = "review_promptCount"
        static let hasReviewed = "review_hasReviewed"
        static let firstInstallDate = "review_firstInstallDate"
        static let sessionCount = "review_sessionCount"
        static let lastTriggerDates = "review_lastTriggerDates"
    }
    
    var canPrompt: Bool {
        guard !userDefaults.bool(forKey: Keys.hasReviewed) else { return false }
        guard promptCount < 3 else { return false }
        guard sessionCount >= 5 else { return false }
        guard daysSinceInstall >= 3 else { return false }
        guard daysSinceLastPrompt >= 60 else { return false }
        return true
    }
    
    func triggerIfAppropriate(for moment: ReviewMoment) {
        guard canPrompt else { return }
        guard !moment.isInCooldown else { return }
        
        showPrePrompt(for: moment)
    }
    
    private func showPrePrompt(for moment: ReviewMoment) {
        // Show contextual pre-prompt
        // On positive response: SKStoreReviewController.requestReview()
        // On negative response: Show feedback form
    }
}
```

---

## Response Templates for Common Negative Reviews

### Template 1: "Too expensive / Not worth the price"
```
Hi [Name], thanks for trying Pausely! We offer a free tier with up to 3 subscriptions so you can experience core features before upgrading. If you'd like to explore Pro, we have a 7-day free trial. Feel free to reach out at pausely@proton.me - we'd love to help find the right fit for you.
```

### Template 2: "App crashes / Bugs"
```
Hi [Name], sorry to hear you're experiencing issues. We take stability seriously. Could you email us at pausely@proton.me with your device model and iOS version? We'll prioritize a fix and keep you updated.
```

### Template 3: "Can't find my subscription / Missing service"
```
Hi [Name], Pausely supports thousands of services and we're adding more every week. You can add any subscription manually with custom names and amounts. If you'd like us to add a specific service to our catalog, let us know at pausely@proton.me!
```

### Template 4: "Screen Time tracking doesn't work"
```
Hi [Name], Screen Time integration requires iOS 16+ and Family Controls authorization. Go to Settings > Screen Time > App Limits and ensure Pausely has permission. For manual tracking, tap the pencil icon on any subscription detail. Need help? Email us at pausely@proton.me.
```

### Template 5: "Wants features we don't have yet"
```
Hi [Name], great suggestion! We're actively building [feature area] and your feedback helps us prioritize. Please email pausely@proton.me with details - we read every message and often incorporate user ideas into our roadmap.
```

### Template 6: "Confusing UI / Hard to use"
```
Hi [Name], sorry the experience wasn't intuitive. We're constantly refining our design. Would you mind sharing specific pain points at pausely@proton.me? Your input directly shapes our next updates.
```

### Template 7: "Data sync issues / Lost subscriptions"
```
Hi [Name], that shouldn't happen. Your data is backed up to Supabase when signed in, with local storage as fallback. Try pulling down to refresh on the dashboard. If subscriptions are still missing, email pausely@proton.me with your account email and we'll investigate immediately.
```

---

## Review Response Guidelines

### Response Timing
- Respond to all negative reviews (1-3 stars) within 24 hours
- Respond to neutral reviews (4 stars) within 48 hours
- Acknowledge positive reviews (5 stars) within 72 hours when possible

### Tone Guidelines
- Always thank the user for their time
- Never be defensive
- Offer a specific next step (email, help article, settings path)
- Personalize with their name when visible
- Keep responses under 350 characters when possible

### Escalation Path
- Reviews mentioning data loss or payment issues: Flag for immediate engineering review
- Reviews with specific feature requests: Log in product backlog
- Reviews from long-term users who are now dissatisfied: Offer personal outreach

---

## Metrics to Track

- Review prompt conversion rate (pre-prompt yes -> system prompt -> actual review)
- Average star rating trend week-over-week
- Review volume per app version
- Sentiment analysis on review text
- Correlation between review timing and app update releases
