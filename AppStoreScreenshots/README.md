# Pausely App Store Assets

This directory contains all assets and documentation for optimizing the Pausely App Store listing for maximum conversion.

## Directory Contents

### Screenshot Compositions (SwiftUI Views)
These are runnable SwiftUI views that compose the app's real components into screenshot-ready layouts. Each is designed for iPhone 16 Pro (6.7") at 1290x2796 resolution.

| File | Purpose | Key Visual |
|------|---------|-----------|
| `Screenshot1View.swift` | Dashboard Hero | Spend chart, subscription count, monthly total |
| `Screenshot2View.swift` | Cost Per Use | Cost-per-hour cards with color-coded value badges |
| `Screenshot3View.swift` | Smart Alerts | Notification preview, renewal calendar, price hike alert |
| `Screenshot4View.swift` | Subscription Detail | Usage chart, pause/cancel actions, alternatives |
| `Screenshot5View.swift` | Premium Paywall | Feature checklist, trial CTA, plan selection |

### Strategy Documents

| File | Contents |
|------|----------|
| `PreviewVideoScript.md` | 15-second silent App Preview video script with scene-by-scene breakdown, timestamps, transitions, and production notes |
| `AppStoreMetadata.md` | Title, subtitle, keywords (100 char), description, What's New template, A/B testing plan, localization notes |
| `ReviewPromptStrategy.md` | 5 positive trigger moments, pre-prompt wording, rate limiting logic, negative review response templates |
| `PromotionalText.md` | Free trial promotion, cost-per-use feature announcement, seasonal messaging (New Year, back-to-school, Black Friday), localization templates |

## Design System Reference

All screenshot views use the app's actual design system:

- **Colors:** `Color.obsidianBlack`, `Color.luxuryGold`, `Color.luxuryPurple`, `Color.luxuryPink`, `Color.accentMint`
- **Typography:** `AppTypography` (SF Rounded with Dynamic Type)
- **Cards:** `glassCard()`, `glassBackground()`, `GlassModifier`
- **Background:** `AnimatedGradientBackground` (orbs + blur)
- **Components:** Real app components where possible (HeroSpendCard, QuickActionsGrid, etc.)

## How to Render Screenshots

1. Open `Pausely.xcodeproj` in Xcode
2. Add the `AppStoreScreenshots/` directory to the project (do not add to any target)
3. Create a new SwiftUI Preview target or use the existing preview canvas
4. For each screenshot view, run on iPhone 16 Pro simulator
5. Use `xcrun simctl io booted screenshot screenshot1.png` or Capture in Xcode
6. Ensure device bezel is hidden for clean captures

## Screenshot Specifications

| Device | Resolution | Required Count |
|--------|-----------|----------------|
| iPhone 16 Pro (6.7") | 1290 x 2796 | 5 (all provided) |
| iPhone 15 Pro (6.1") | 1179 x 2556 | Optional - scale down |
| iPad Pro 12.9" | 2048 x 2732 | Optional - requires separate compositions |

## ASO Checklist

- [ ] Title: "Pausely: Subscription Tracker"
- [ ] Subtitle: "Track, analyze & save on subscriptions"
- [ ] Keywords: 99/100 characters used
- [ ] Description: Hook + 5 bullets + social proof + premium + support
- [ ] 5 screenshots uploaded (iPhone 6.7")
- [ ] App Preview video (15s, optional but recommended)
- [ ] What's New text for current version
- [ ] Promotional text updated
- [ ] Review prompt implemented in app
- [ ] Localized for priority markets (en-US, en-GB, de-DE, fr-FR, es-ES, ja-JP)
