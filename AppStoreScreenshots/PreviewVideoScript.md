# Pausely App Preview Video Script

## Overview
- **Duration:** 15 seconds
- **Format:** Vertical (9:16) for App Store, 30fps
- **Audio:** Silent design (no narration, text overlays only)
- **Target:** iPhone 16 Pro (6.7" display)
- **Style:** Dark theme, glass morphism, premium feel

---

## Scene Breakdown

### Scene 1: Hook (0:00 - 0:03)
**Duration:** 3 seconds
**Screen:** Dashboard Hero (Screenshot 1 composition)

**Visual:**
- Animated gradient background with floating orbs
- Dashboard appears with staggered card animations
- Hero spend card with circular chart animating to 75%
- Quick actions grid slides up

**Text Overlay:**
- "All your subscriptions in one place" (appears at 0:01, fades at 0:03)
- Font: Bold rounded, 28pt, white with subtle shadow

**Transition:** Quick fade to next scene

---

### Scene 2: The Problem (0:03 - 0:06)
**Duration:** 3 seconds
**Screen:** Cost Per Use (Screenshot 2 composition)

**Visual:**
- Cost-per-hour cards stack in with spring animation
- Featured card (Netflix - Great Value) pulses subtly
- Value badges color-code in (green, yellow, red)
- Usage bar charts grow from left to right

**Text Overlay:**
- "Know what each subscription costs per use" (appears at 0:04)
- Adobe CC card highlights in red (poor value) at 0:05

**Transition:** Slide left

---

### Scene 3: The Solution (0:06 - 0:10)
**Duration:** 4 seconds
**Screen:** Smart Alerts (Screenshot 3 composition)

**Visual:**
- Notification preview drops in from top with bounce
- Renewal calendar cards cascade in
- Price hike alert pulses with orange glow at 0:08
- "Find Cheaper Alternative" button highlights

**Text Overlay:**
- "Get alerts before renewals and price hikes" (appears at 0:07)
- "+17%" on price hike card zooms slightly at 0:09

**Transition:** Scale up + fade

---

### Scene 4: The Action (0:10 - 0:13)
**Duration:** 3 seconds
**Screen:** Subscription Detail (Screenshot 4 composition)

**Visual:**
- Netflix detail view slides up
- Usage ring animates to 69%
- Daily bar chart grows
- Action buttons (Cancel, Pause, Edit) slide in from bottom

**Text Overlay:**
- "Track usage and find savings" (appears at 0:11)
- "Save $90/yr" badge on alternative pulses at 0:12

**Transition:** Fade to black, then reveal

---

### Scene 5: The CTA (0:13 - 0:15)
**Duration:** 2 seconds
**Screen:** Premium Paywall (Screenshot 5 composition)

**Visual:**
- Premium gradient background with floating orbs
- Crown icon with rotating gradient ring
- "Start Free Trial" CTA button pulses with gold glow
- Feature checklist checks animate in rapidly

**Text Overlay:**
- "Unlock premium features" (appears at 0:13)
- "7-day free trial" badge sparkles at 0:14

**End Card:**
- App icon + "Pausely" logo centers at 0:14.5
- "Download on the App Store" fades in
- Hold for 0.5 seconds

---

## Animation Guidelines

### Timing
- All entrance animations: 0.3-0.5s easeOut
- Stagger between elements: 0.1s
- Text overlay fade in: 0.2s
- Transitions between scenes: 0.3s

### Easing
- Cards: `easeOut(duration: 0.5)`
- Charts: `easeOut(duration: 1.0)`
- Buttons: `spring(response: 0.3, dampingFraction: 0.7)`
- Text: `easeInOut(duration: 0.3)`

### Color Palette
- Background: `#09090B` (obsidian black)
- Primary accent: `#34D399` (electric mint)
- Premium gold: `#F5C94D`
- Premium purple: `#8B5CF6`
- Premium pink: `#EC4899`
- Text primary: `#FAFAFA`
- Text secondary: `#A1A1AA`

### Typography
- Headlines: SF Rounded Bold, 28-34pt
- Body: SF Rounded Regular, 15-17pt
- Labels: SF Rounded Medium, 11-13pt
- All text uses `.multilineTextAlignment(.center)` for overlays

---

## Production Notes

### Recording
1. Use iPhone 16 Pro simulator at 1290x2796 resolution
2. Enable "Show Device Bezels" OFF for clean capture
3. Record at 60fps for smooth animations, export at 30fps
4. Use QuickTime or simctl for capture

### Post-Production
1. Add text overlays in Final Cut Pro, After Effects, or Canva
2. Ensure text has 10% drop shadow for readability
3. Add subtle motion blur to fast transitions
4. Export H.264, 30fps, stereo audio (silent track)

### App Store Requirements
- Max file size: 500MB
- Max duration: 30 seconds (this script is 15s)
- Accepted formats: MOV, M4V, MP4
- Required for: iPhone 6.7" display
- Optional: iPhone 5.5", iPad Pro 12.9"

---

## Silent Design Principles

1. **No narration needed:** Text overlays tell the full story
2. **Visual rhythm:** Fast cuts (3s each) maintain engagement
3. **Motion communicates:** Animations show interactivity without sound
4. **Color coding:** Green = good, red = warning, gold = premium
5. **Progressive disclosure:** Each scene builds on the previous
