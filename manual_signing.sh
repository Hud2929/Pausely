#!/bin/bash
# Manual signing script for Pausely with DeviceActivity entitlements

TEAM_ID="YOUR_TEAM_ID_HERE"  # Replace with your Team ID
PROFILE_PATH="~/Downloads/iOS_Team_Provisioning_Profile_com.pausely.app.Pausely.mobileprovision"

echo "Building with manual signing..."

xcodebuild -project Pausely.xcodeproj \
    -scheme Pausely \
    -destination "generic/platform=iOS" \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="iPhone Distribution" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: com.pausely.app.Pausely" \
    build

echo "Build complete!"
