---
name: pausely-design
description: The rules, checks and rating bar for every Pausely screen (Ink and Paper). Use whenever a view is added, rebuilt or restyled; when choosing a colour, font, spacing, animation or haptic; when writing paywall or onboarding copy; and before saying any screen is finished.
---

# Pausely design: Ink and Paper

The system lives in `Pausely/DesignSystem/InkPaper.swift`; the reasoning in `REDESIGN_PLAN.md`
section 3. See every part on one screen with the DEBUG launch argument `--demo-design`.

## The identity, in five rules

1. **Ink.** Screens are `Color.ink`. Raised surfaces (`inkRaised`) are rare; rows are separated by
   `Hairline()`, not a card each.
2. **Paper** (`PaperSlip`) appears only where money is decided or proven: the verdict slip, the
   Savings Receipt, the first-run tally, the share card, Pausely's own slip on the paywall.
3. **Mint (`Color.kept`) means money kept.** Never a spend total, a tab, a toggle, a generic icon or a
   call to action. The one exception is the Keep button. Spend is `inkText` (white).
4. **Serif asks and totals** (`Font.question`): one question or one number per screen. **Mono proves**
   (`Font.proof`, `ProofLine`): receipt lines. Everything else is the system face, default design.
5. **State has a colour and a symbol** (`MoneyState`, `StateMark`): decide = amber, due = coral,
   paused = sky, kept = mint.

## Craft checks (each is a fail, not a preference)

- No gradients, no glows, no coloured shadows, no `.ultraThinMaterial` cards. Glass only on the tab
  bar, toolbars and the decision bar, behind `#available(iOS 26, *)`.
- No `.tracking`/`.kerning` on localised text. No `design: .rounded`. Weights stop at bold.
- Spacing from the 4-pt scale; side margin `Layout.margin`; radii from `Layout`. The gap inside a
  group is visibly smaller than the gap between groups.
- One element per screen is allowed to be big. One main button (`.buttonStyle(.ink)`) per screen;
  the second action is `.ink(.quiet)` or plain text.
- Every screen has designed loading, empty and error states with real copy.
- Motion: `Motion.touch/arrive/leave`, wrapped in `Motion.unlessReduced`. Nothing loops. Numbers
  change with `.contentTransition(.numericText())`.
- Haptics only through `Feel`.
- Do the sum for the reader: show totals, dates and "cancel by" days; never make them calculate.
- Cut anything that doesn't help someone decide to keep or cancel.

## Every screen must also

- Use `MoneyFormat` for amounts (the `pausely-currency` skill) and StoreKit prices on the paywall.
- Have all five translations for every string; work right to left (leading/trailing, never
  left/right; no mirrored numbers).
- Switch horizontal rows to vertical stacks at accessibility text sizes
  (`dynamicTypeSize.isAccessibilitySize`); never clip or truncate a price.
- Read as sentences in VoiceOver (`.accessibilityElement(children: .combine)`), with a button or
  action for every gesture; tap targets at least `Layout.tapTarget`.
- Apply `.readableWidth()` on full-screen covers (iPad).

## Honest persuasion (App Store 3.1.2 and the founder's rule)

Allowed: the user's own numbers, the true price as the largest price, a trial timeline with the
charge date, "cancel anytime" with how. Never: countdowns, "only today", guilt copy on the decline
button, a hidden or delayed close button, a pre-selected plan that costs more than the one shown,
claims the build can't prove.

## Old UI is not allowed to remain

A screen is rebuilt only when this prints nothing for its files:

```bash
grep -nE "accentMint|obsidian|glassCard|glassBackground|\.glass\(|premiumButton|AnimatedGradientBackground|PremiumBackground|LinearGradient|RadialGradient|\.shadow\(|ultraThinMaterial|surfaceCard|BrandColors|STFont|AppTypography|HapticStyle|STAnimation|PrimaryButtonStyle|GhostButtonStyle" <files>
```

`REDESIGN_PLAN.md` section 11 lists every view file and whether it is rebuilt. Update it in the
same commit.

## Rating (never round up)

Rate each screen 0–10 on seven dimensions: clarity, hierarchy, identity, craft, accessibility,
honesty, delight. The score is the mean, capped at one point above the weakest dimension. Compare
against the best shipped apps in any category (principles only; never copy a look, layout, icon or
signature interaction). A screen is done at 9.0 with no dimension under 8.5, checked on screen in
English, one right-to-left language and the largest text size.
