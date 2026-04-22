# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pausely is an iOS SwiftUI app for subscription management. Users track, pause, and analyze their recurring subscriptions with cost-per-hour ROI scoring. Backend is Supabase (auth + database) with Lemon Squeezy (web checkout) or StoreKit as the payment provider.

## Building

Build and run exclusively through Xcode — open `Pausely.xcodeproj`. There is no CLI build system configured. Deep links (`pausely://`) require a real device; they do not work in the simulator.

## Architecture

### App Entry & State Machine

`Pausely/PauselyApp.swift` is the root. It switches on `RevolutionaryAuthManager.shared.state` (an `AuthState` enum) to show one of: `LoadingView`, `MainTabView`, `EmailConfirmationView`, or `EnhancedLoginView`. Deep links for auth, checkout returns, and referral codes are dispatched from `handleDeepLink(url:)` here.

### Services Layer (Singletons)

All business logic lives in `Pausely/Services/` as `@MainActor` `ObservableObject` singletons:

- **`RevolutionaryAuthManager`** — primary auth manager. Supports magic link (OTP) and email/password. Handles deep link verification for email confirmation and password reset. The legacy `AuthManager` class is deprecated; always use `RevolutionaryAuthManager.shared`.
- **`SupabaseManager`** — wraps `SupabaseClient`. Supabase project: `ddaotwyaowspwspyddzs.supabase.co`. Also defines `AuthState`, `AuthError`, and `CurrencyManager`.
- **`PaymentManager`** — subscription tier management (`SubscriptionTier`: free / premium / premiumAnnual). Controls `activatePremium(source:)` / `deactivatePremium()`.
- **`LemonSqueezyManager`** — web checkout via Lemon Squeezy. Reads credentials from `Info.plist` keys: `LEMON_SQUEEZY_API_KEY`, `LEMON_SQUEEZY_STORE_ID`, `LEMON_SQUEEZY_WEBHOOK_SECRET`, `LEMON_SQUEEZY_MONTHLY_VARIANT_ID`, `LEMON_SQUEEZY_ANNUAL_VARIANT_ID`. Falls back to demo mode (simulated purchases) when keys are absent.
- **`AppConfiguration`** — selects payment provider (`lemonSqueezy` vs `storekit`), configured at launch.
- **`ReferralManager`** — referral code validation, application, and deep link handling (`pausely://r/CODE` and `https://pausely.app/r/CODE`).
- **`ScreenTimeManager`** — Screen Time / Family Controls integration for usage tracking.
- **`ThemeManager`** — light/dark theme preference stored in `UserDefaults`.
- **`KeychainManager`** — secure credential storage.

### ViewModels

`Pausely/ViewModels/` contains three `ObservableObject` stores:
- **`SubscriptionStore`** — fetches/caches subscriptions from Supabase table `subscriptions`, with local storage fallback.
- **`TrialProtectionStore`** — trial state management.
- **`VirtualCardStore`** — privacy virtual card management.

### Views

`Pausely/Views/` contains all SwiftUI screens. Navigation root after auth is `MainTabView` (Dashboard → Subscriptions → Perks → Profile tabs).

### Models

`Pausely/Models/`: `Subscription` (core model with `BillingFrequency`, `SubscriptionStatus`, ROI calculation), `User`, `VirtualCard`, `UserPerk`, `Currency` (lives in `SupabaseManager.swift`).

### Design System

`Pausely/DesignSystem/GlassModifier.swift` provides the glass morphism UI components. Custom colors used throughout: `Color.luxuryGold`, `Color.luxuryPurple`, `Color.luxuryPink`. Key reusable modifiers: `.glass(intensity:tint:)`, `GlassCard`. Background: `AnimatedGradientBackground()`. Haptics: `HapticStyle.light.trigger()` / `.medium.trigger()`.

## Deep Link URL Scheme

URL scheme: `pausely://`

| Path | Purpose |
|------|---------|
| `pausely://auth/confirm` | Email confirmation |
| `pausely://auth/reset-password` | Password reset |
| `pausely://auth/callback` | Auth callback |
| `pausely://checkout/success` | Lemon Squeezy checkout return |
| `pausely://r/CODE` | Referral code |

Supabase redirect URLs must match: `pausely://auth/confirm`, `pausely://auth/reset-password`, `pausely://auth/callback`.

## Backend

- **Supabase**: Auth (magic link + email/password), database (`subscriptions` table, referral tables). SQL migrations in `supabase/migrations/`.
- **Supabase Edge Functions**: `supabase/functions/lemon-squeezy-webhook/` — processes Lemon Squeezy webhook events server-side.
- **MissionControl/**: Companion web app (`app.js`, `index.html`) for admin/revenue dashboard.

## Configuration Notes

- Lemon Squeezy credentials go in `Info.plist` (not hardcoded). Demo mode activates automatically if keys are missing, enabling simulated purchases for development.
- `AppConfig.swift` contains app-wide constants (support email, URL scheme, deep link paths). Credentials should not be added to `AppConfig.swift` directly — that file currently has a plaintext password that should be moved to Keychain.
- `AppConfiguration.swift` contains a hardcoded Lemon Squeezy API key in `ProductionKeys` — this should be moved to `Info.plist` or environment config, not left in source.
