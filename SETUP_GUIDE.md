# StoreKit Setup Guide - Pausely

## Quick Start (Choose ONE method)

### Method 1: Terminal Script (Easiest)

1. **Open Terminal**
2. **Type this command:**
   ```bash
   cd ~/Desktop/Pausely && ./setup_storekit.sh
   ```
3. **Follow the instructions printed**

### Method 2: Manual Setup

#### Step 1: Find the Config File
The file `Products.storekit` already exists in:
```
/Users/hudson/Desktop/Pausely/Products.storekit
```

#### Step 2: Add to Xcode
1. Open **Pausely.xcodeproj** in Xcode
2. Find `Products.storekit` in Finder (Desktop/Pausely)
3. **Drag** it into Xcode's left sidebar (project navigator)
4. Check "Copy items if needed" → **Finish**

#### Step 3: Enable StoreKit Testing
1. Click **scheme dropdown** (next to Run button ▶️)
2. Select **"Edit Scheme..."**
3. Click **"Run"** on left sidebar
4. Click **"Options"** tab
5. Under **"StoreKit Configuration"** → Select **"Products"**
6. Click **Close**

#### Step 4: Add In-App Purchase Capability
1. Click **Pausely** project (blue icon)
2. Click **Targets** → **Pausely**
3. Click **"Signing & Capabilities"**
4. Click **"+ Capability"**
5. Search **"In-App Purchase"** → Double click

## Test Your Setup

1. Press **⌘+R** to run
2. Tap **"Upgrade to Pro"**
3. See the futuristic JARVIS UI
4. Tap **"Start Free Trial"**
5. **It works!** 🎉

## Troubleshooting

### "No products found"
- Make sure Products.storekit is selected in scheme options
- Check that In-App Purchase capability is added

### "Can't find file"
- Run: `cd ~/Desktop/Pausely && ls -la Products.storekit`
- If missing, run the setup script again

## Product Details

| Product | ID | Price | Period |
|---------|-----|-------|--------|
| Monthly Pro | com.pausely.premium.monthly | $7.99 CAD | Monthly |
| Annual Pro | com.pausely.premium.annual | $69.99 CAD | Yearly (27% savings) |

Both include 7-day free trial!
