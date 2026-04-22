#!/bin/bash
set -e

APP_BUNDLE="/Users/hudson/Library/Developer/Xcode/DerivedData/Pausely-dduvrsbllizxjngngvjicaolukvh/Build/Products/Debug-iphonesimulator/Pausely.app"
BUNDLE_ID="com.pausely.app.Pausely"
DEVICE="iPhone 16"

# Install app
xcrun simctl install "$DEVICE" "$APP_BUNDLE"
echo "✅ App installed"

# Launch app
xcrun simctl launch --console "$DEVICE" "$BUNDLE_ID" &
PID=$!
echo "✅ App launched with PID $PID"

# Let it run
sleep 5
echo "✅ App running - taking screenshot..."

# Screenshot
xcrun simctl io "$DEVICE" screenshot /tmp/pausely_dashboard.png
echo "✅ Screenshot saved"

# Keep running a bit more
sleep 3

# Keep alive without blocking
wait $PID || true
