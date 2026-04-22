# 🚀 PAUSELY DEVELOPMENT SETUP GUIDE

**Version:** 1000/10 Revolutionary Setup  
**Prerequisites:** macOS 15+, Xcode 16+, iOS 18+ SDK

---

## 📋 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/pausely/ios-app.git
cd Pausely

# 2. Install dependencies (if using Swift Package Manager)
# Dependencies are automatically resolved by Xcode

# 3. Configure environment
./scripts/setup-env.sh

# 4. Open in Xcode
open Pausely.xcodeproj

# 5. Build and run
# Press Cmd+R in Xcode
```

---

## 🔐 Environment Configuration

### 1. Create Environment File

```bash
# Copy the template
cp Configuration/Development.xcconfig.template Configuration/Development.xcconfig
```

### 2. Set Up Supabase

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Get your project URL and anon key from Settings → API
3. Add to `Configuration/Development.xcconfig`:

```bash
# Development.xcconfig
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
```

Or set as environment variables:

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"
```

### 3. Set Up RevenueCat

1. Create account at [revenuecat.com](https://revenuecat.com)
2. Get your API key from Settings → API Keys
3. Add to configuration:

```bash
REVENUECAT_API_KEY = your-revenuecat-key
```

### 4. Set Up Plaid (Optional)

1. Create account at [plaid.com](https://plaid.com)
2. Get client ID and secret
3. Add to configuration:

```bash
PLAID_CLIENT_ID = your-plaid-client-id
PLAID_SECRET = your-plaid-secret
```

---

## 🛠️ Build Configurations

### Available Schemes

| Scheme | Purpose | Bundle ID |
|--------|---------|-----------|
| Pausely Dev | Development | com.pausely.dev |
| Pausely Staging | Beta testing | com.pausely.staging |
| Pausely | Production | com.pausely.app |

### Switching Environments

```bash
# Development (default)
# Uses: Development.xcconfig

# Staging
# Edit scheme → Build Configuration → Release (Staging)
# Uses: Staging.xcconfig

# Production
# Edit scheme → Build Configuration → Release
# Uses: Production.xcconfig
```

---

## 🧪 Running Tests

### Unit Tests
```bash
# In Xcode
Cmd+U

# Or via command line
xcodebuild test -project Pausely.xcodeproj -scheme "Pausely Dev" -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Test Coverage
```bash
# Generate coverage report
xcodebuild test -project Pausely.xcodeproj -scheme "Pausely Dev" -destination 'platform=iOS Simulator,name=iPhone 16' -enableCodeCoverage YES

# Open coverage report
open DerivedData/Pausely/Build/ProfileData/*/Coverage.profdata
```

---

## 📱 Device Setup

### Simulator
1. Select target device in Xcode
2. Press Cmd+R to build and run

### Physical Device
1. Connect your iPhone
2. Select device in Xcode
3. Configure code signing
4. Build and run

**Note:** Screen Time features require the Device Activity entitlement from Apple.

---

## 🐛 Debugging

### Enable Debug Logging
```swift
// In AppDelegate or main app init
#if DEBUG
ConfigurationValidator.printValidationReport()
DIContainer.shared.printRegistrationReport()
#endif
```

### Common Issues

#### Issue: "Supabase URL not configured"
**Solution:** Check your `Development.xcconfig` or environment variables

#### Issue: "Build failed: No such module"
**Solution:** Clean build folder (Cmd+Shift+K) and rebuild

#### Issue: "Screen Time authorization failed"
**Solution:** Device Activity entitlement required for physical devices

---

## 🔄 Continuous Integration

### GitHub Actions
```yaml
# .github/workflows/ios.yml
name: iOS Build & Test

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: xcodebuild build -project Pausely.xcodeproj -scheme "Pausely Dev"
      - name: Test
        run: xcodebuild test -project Pausely.xcodeproj -scheme "Pausely Dev" -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## 📦 Dependencies

### Swift Packages
All dependencies managed via Swift Package Manager:

| Package | Purpose | Version |
|---------|---------|---------|
| Supabase | Backend/Auth | Latest |
| StoreKit | In-App Purchases | System |
| FamilyControls | Screen Time | System |
| CryptoKit | Security | System |

### Updating Dependencies
```bash
# In Xcode
File → Packages → Update to Latest Package Versions
```

---

## 🚀 Deployment

### TestFlight
1. Archive the app (Product → Archive)
2. Distribute App → App Store Connect → TestFlight

### App Store
1. Ensure all assets are ready (screenshots, description)
2. Increment version number
3. Archive and submit for review

---

## 📚 Additional Resources

- [Architecture Documentation](ARCHITECTURE.md)
- [API Documentation](https://docs.pausely.com)
- [Contributing Guidelines](CONTRIBUTING.md)

---

## 💬 Support

- GitHub Issues: [github.com/pausely/ios-app/issues](https://github.com/pausely/ios-app/issues)
- Email: dev@pausely.com
- Slack: [pausely.slack.com](https://pausely.slack.com)

---

**Happy Coding! 🚀**
