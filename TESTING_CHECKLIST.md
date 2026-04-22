# StoreKit Testing Checklist - Post App Store Connect Setup
**Status:** Ready for Device Testing

---

## ✅ What You've Completed

### App Store Connect
- [x] Created subscription products (Monthly $7.99, Annual $69.99)
- [x] Created sandbox test user
- [ ] Uploaded build to App Store Connect (for TestFlight)

---

## 🔍 CRITICAL: Verify Product IDs Match

**Before testing, confirm these match EXACTLY:**

### Your App Store Connect Products Should Be:
```
Product ID 1: com.pausely.premium.monthly
Product ID 2: com.pausely.premium.annual
```

### Verify in Code:
```bash
cd ~/Desktop/Pausely
grep -A 2 "enum ProductID" Pausely/Services/StoreKitConfig.swift
```

**Expected Output:**
```swift
case monthlyPro = "com.pausely.premium.monthly"
case annualPro = "com.pausely.premium.annual"
```

⚠️ **If these don't match exactly (case-sensitive), purchases will fail!**

---

## 📱 Testing Options (Choose One)

### Option A: Simulator Testing (Fastest - No ASC Needed)
**Uses:** Configuration.storekit (local file)  
**Best for:** Quick feature testing

```bash
1. Open Xcode
2. Select iPhone 16 Simulator
3. Run (Cmd+R)
4. Add 4 subscriptions to trigger paywall
5. Tap purchase - uses local config
```

✅ **No sandbox account needed** - uses Configuration.storekit  
✅ **No App Store Connect needed** - fully local  
✅ **Instant testing** - no upload required

---

### Option B: Physical Device + Sandbox (Real Testing)
**Uses:** App Store Connect products  
**Best for:** Real-world validation before release

#### Step 1: Configure Device
1. On your iPhone/iPad:
   - Open **Settings** → **App Store**
   - Scroll to **Sandbox Account**
   - Sign out of real Apple ID if signed in
   - Sign in with your **sandbox tester email**

#### Step 2: Run from Xcode
1. Connect device to Mac
2. Select your device in Xcode (not simulator)
3. Build and run (Cmd+R)
4. Trigger paywall in app
5. Tap purchase

**Expected:** System purchase sheet appears with **"[Environment: Sandbox]"**

---

### Option C: TestFlight (Production-like)
**Uses:** App Store Connect products + distributed build  
**Best for:** Beta testing with external users

#### Step 1: Upload Build
```bash
1. In Xcode: Product → Archive
2. Window → Organizer → Select archive
3. Distribute App → App Store Connect → Upload
4. Wait for processing (5-30 min)
```

#### Step 2: Enable Testing
1. Go to App Store Connect → My Apps → Pausely
2. TestFlight tab → Internal Testing
3. Add testers (your email)
4. Select build → Start Testing

#### Step 3: Install on Device
1. Download **TestFlight** app from App Store
2. Open TestFlight invitation
3. Install Pausely
4. Sign in with **sandbox account**
5. Test purchases

---

## ⚠️ Common Issues & Solutions

### Issue 1: "Product Not Found"
**Symptoms:** Paywall shows "Subscriptions not available"

**Solutions:**
1. Check product IDs match exactly
2. Wait 15-30 min after creating products (ASC propagation)
3. Ensure build has correct bundle ID
4. Clean build folder: Cmd+Shift+K → Cmd+B

### Issue 2: "Cannot Connect to iTunes Store"
**Symptoms:** Purchase fails immediately

**Solutions:**
1. Check internet connection
2. Ensure signed into sandbox account (not real Apple ID)
3. Restart device
4. Try different sandbox tester

### Issue 3: "This Apple ID has not been used in the iTunes Store"
**Symptoms:** Can't sign in with sandbox account

**Solutions:**
1. Go to https://appstoreconnect.apple.com
2. Users and Access → Sandbox Testers
3. Click on tester → "Agree to Terms"
4. Or create new sandbox tester

### Issue 4: Products Load But Purchase Fails
**Symptoms:** Can see products but purchase errors

**Solutions:**
1. Check device is logged into sandbox (not real account)
2. Verify products are "Cleared for Sale" in ASC
3. Check subscription group is properly configured

---

## ✅ Final Pre-Flight Checklist

### Code Verification
```bash
cd ~/Desktop/Pausely

# 1. Verify bundle ID
grep "PRODUCT_BUNDLE_IDENTIFIER" Pausely.xcodeproj/project.pbxproj | head -1
# Expected: com.pausely.app.Pausely

# 2. Verify product IDs
grep "premium.monthly\|premium.annual" Pausely/Services/StoreKitConfig.swift

# 3. Build succeeds
xcodebuild -project Pausely.xcodeproj -scheme Pausely -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### App Store Connect Verification
1. Go to https://appstoreconnect.apple.com
2. My Apps → Pausely → Subscriptions
3. Verify:
   - [ ] Both products show "Cleared for Sale"
   - [ ] Product IDs match code exactly
   - [ ] Prices are correct ($7.99 / $69.99)
   - [ ] Free trial configured (1 week)

### Sandbox Account
1. App Store Connect → Users and Access → Sandbox
2. Verify:
   - [ ] Tester email created
   - [ ] Password set
   - [ ] Country/Region set (matches your store)
   - [ ] "Agree to Terms" completed

---

## 🧪 Quick Test Protocol

### Test 1: Simulator (2 minutes)
```
1. Run in iPhone 16 Simulator
2. Skip onboarding
3. Add 4 subscriptions
4. Verify paywall appears
5. Verify products show prices
6. Tap purchase (should show mock system dialog)
```
✅ **This confirms code is working**

### Test 2: Device + Sandbox (5 minutes)
```
1. Sign into sandbox account on device
2. Run from Xcode on device
3. Trigger paywall
4. Purchase (should show "[Environment: Sandbox]")
5. Verify success
```
✅ **This confirms App Store Connect integration**

### Test 3: TestFlight (15 minutes)
```
1. Upload build to ASC
2. Install via TestFlight
3. Sign in with sandbox account
4. Complete purchase flow
5. Verify subscription active
```
✅ **This confirms production readiness**

---

## 📝 Summary

### For Immediate Testing:
**Option A (Simulator)** is sufficient and requires:
- ✅ Xcode
- ✅ Configuration.storekit (already done)
- ❌ No App Store Connect needed
- ❌ No sandbox account needed

### For Production Validation:
**Option B (Device)** requires:
- ✅ App Store Connect products (you have this)
- ✅ Sandbox test user (you have this)
- ✅ Physical device
- ✅ Build uploaded (optional for direct testing)

### For Beta Distribution:
**Option C (TestFlight)** requires:
- ✅ App Store Connect products
- ✅ Sandbox test users
- ✅ Build uploaded to ASC
- ✅ TestFlight app on device

---

## 🎯 Recommendation

### If you want to test RIGHT NOW:
Use **Simulator** - it's already configured and ready.

### If you want to test on real device:
You have everything needed! Just:
1. Sign into sandbox account on device
2. Run from Xcode on device
3. Test purchase

### If you want external beta testers:
Upload build to App Store Connect → TestFlight.

---

## Questions?

**Q: Do I need to upload to App Store Connect to test?**  
A: No! Use Simulator or run directly on device with sandbox.

**Q: How long do products take to appear?**  
A: Usually 15-30 minutes after creation in App Store Connect.

**Q: Can I use my real Apple ID for testing?**  
A: No! Must use sandbox test account. Real Apple ID = real charges!

**Q: Do products work in Simulator?**  
A: Yes, but uses Configuration.storekit (local), not App Store Connect.

---

**Status:** ✅ Ready for testing
**Next Step:** Choose Option A, B, or C above
