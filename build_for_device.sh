#!/bin/bash
# Build script for physical device testing
# This temporarily disables DeviceActivity entitlements for device builds

set -e

echo "🔨 Building Pausely for Device (without DeviceActivity extensions)..."

# Build for generic device
xcodebuild -project Pausely.xcodeproj \
    -scheme Pausely \
    -destination "generic/platform=iOS" \
    -configuration Debug \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="Apple Development" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=YOUR_TEAM_ID \
    build

echo "✅ Build successful!"
echo ""
echo "Note: DeviceActivity features require special Apple approval."
echo "To submit to App Store, you must:"
echo "1. Request Family Controls entitlement: https://developer.apple.com/contact/request/family-controls"
echo "2. Wait for Apple approval"
echo "3. Regenerate provisioning profiles with the entitlement"
