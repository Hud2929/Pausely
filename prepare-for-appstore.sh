#!/bin/bash

echo "🚀 Pausely App Store Preparation Script"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track issues
ERRORS=0
WARNINGS=0

echo "📋 Running Pre-flight Checks..."
echo ""

# Check 1: Info.plist
echo "✓ Checking Info.plist..."
if [ ! -f "Info.plist" ]; then
    echo "${RED}✗ Info.plist not found${NC}"
    ERRORS=$((ERRORS+1))
else
    echo "${GREEN}✓ Info.plist found${NC}"
    
    # Check required fields
    if grep -q "CFBundleShortVersionString" Info.plist; then
        echo "  ${GREEN}✓ Version string configured${NC}"
    else
        echo "  ${RED}✗ Version string missing${NC}"
        ERRORS=$((ERRORS+1))
    fi
fi

# Check 2: App Icons
echo ""
echo "✓ Checking App Icons..."
ICON_PATH="Pausely/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICON_PATH" ]; then
    ICON_COUNT=$(ls -1 "$ICON_PATH"/*.png 2>/dev/null | wc -l)
    if [ $ICON_COUNT -ge 6 ]; then
        echo "${GREEN}✓ Found $ICON_COUNT app icons${NC}"
    else
        echo "${YELLOW}⚠ Only $ICON_COUNT icons found (recommend 6+)${NC}"
        WARNINGS=$((WARNINGS+1))
    fi
else
    echo "${RED}✗ AppIcon.appiconset not found${NC}"
    ERRORS=$((ERRORS+1))
fi

# Check 3: Privacy Info
echo ""
echo "✓ Checking PrivacyInfo.xcprivacy..."
if [ -f "PrivacyInfo.xcprivacy" ]; then
    echo "${GREEN}✓ Privacy manifest found${NC}"
else
    echo "${RED}✗ PrivacyInfo.xcprivacy missing (REQUIRED for iOS 17+)${NC}"
    ERRORS=$((ERRORS+1))
fi

# Check 4: Build succeeds
echo ""
echo "✓ Testing build..."
xcodebuild clean -project Pausely.xcodeproj -scheme Pausely > /tmp/build.log 2>&1
xcodebuild -project Pausely.xcodeproj -scheme Pausely -destination 'platform=iOS Simulator,name=iPhone 16' build CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO > /tmp/build.log 2>&1

if [ $? -eq 0 ]; then
    echo "${GREEN}✓ Build successful${NC}"
else
    echo "${RED}✗ Build failed - check /tmp/build.log${NC}"
    ERRORS=$((ERRORS+1))
fi

# Check 5: Swift Package Dependencies
echo ""
echo "✓ Checking package dependencies..."
if [ -d "Pausely.xcodeproj/project.xcworkspace/xcshareddata/swiftpm" ]; then
    echo "${GREEN}✓ Swift Package Manager configured${NC}"
else
    echo "${YELLOW}⚠ SPM packages may need to be resolved${NC}"
    WARNINGS=$((WARNINGS+1))
fi

# Check 6: Mission Control Setup
echo ""
echo "✓ Checking Mission Control..."
if [ -d "MissionControl" ]; then
    echo "${GREEN}✓ Mission Control dashboard created${NC}"
    if [ -f "MissionControl/supabase-setup.sql" ]; then
        echo "  ${GREEN}✓ Database schema ready${NC}"
    fi
else
    echo "${YELLOW}⚠ Mission Control not found${NC}"
fi

# Summary
echo ""
echo "======================================"
echo "📊 Pre-flight Check Summary"
echo "======================================"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "${GREEN}🎉 All checks passed! Ready for App Store submission.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Create App Store Connect record"
    echo "2. Take screenshots (see APP_STORE_RELEASE.md)"
    echo "3. Archive and upload build"
    echo "4. Submit for review"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "${YELLOW}⚠ $WARNINGS warning(s) found (non-blocking)${NC}"
    echo ""
    echo "You can proceed but consider fixing warnings."
    exit 0
else
    echo "${RED}✗ $ERRORS error(s) found - must fix before submission${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo "${YELLOW}⚠ $WARNINGS warning(s) also found${NC}"
    fi
    echo ""
    echo "Fix errors above, then run this script again."
    exit 1
fi
