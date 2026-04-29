# EMERGS — Questions for When You Wake Up

## 1. Widget Target (Needs Xcode UI)
PauselyWidget/ has complete widget + Live Activity code, but the target is NOT in the Xcode project. I tried adding it programmatically — the xcodeproj gem can't write PBXFileSystemSynchronizedRootGroup (Xcode 16's new format). **This requires File > New > Target > Widget Extension in Xcode.**

Exact steps:
1. Open Pausely.xcodeproj in Xcode
2. File > New > Target > Widget Extension
3. Name: PauselyWidget, Bundle ID: com.pausely.app.Pausely.PauselyWidget
4. Point to existing PauselyWidget/ directory
5. Build and verify

## 2. Supabase Email Template (Dashboard Access)
You mentioned emails aren't sending during signup. The OTP code input UI was fixed, but the actual email template with "Welcome to Pausely" branding must be configured in the Supabase dashboard:
- Go to Authentication > Templates > Confirm Signup
- Add your custom HTML with the OTP code highlighted

**Do you have Supabase dashboard access, or do you need me to write the exact template HTML for you to paste in?**

## 3. Localization Priority
Localizable.xcstrings has 799 strings (English only). The strategic plan calls for 5 tier-1 languages.

**Which languages should I prioritize?** Suggestion: French, German, Spanish, Japanese, Portuguese (Brazil).

## 4. App Store Submission Timeline
App audit score: 4.5/5. Clean build, zero warnings, no crashes, accessibility in place.

**Are we submitting soon, or should I push for the full 5/5 first?** The 0.5 gap is mostly widget target + localization.

## 5. App Store Screenshots
Captured: Dashboard, Insights. Missing: Profile, Subscription detail, Genius with data.

**Should I complete the full screenshot set for all device sizes (iPhone 6.7", iPad, etc.)?**
