#!/usr/bin/env bash
# Preflight SDK check, Release archive, export, and optional App Store Connect upload for Pausely.
#
#   bash scripts/release_archive.sh --check          verify active Xcode / iOS SDK (no build or upload)
#   bash scripts/release_archive.sh                  archive + export signed IPA locally in /tmp/PauselyRelease
#   bash scripts/release_archive.sh --bump --upload  bump build number, archive, export, and upload to ASC (--wait)
#
# Enforces Apple's ITMS-90725 iOS 27 SDK requirement (mandatory April 2027, Xcode 27+ on macOS 26.6+):
# warns before April 2027 and blocks on/after 2027-04-01 (or when --require-ios27 is passed) unless
# --allow-older-sdk is explicitly supplied. Never submits to App Review automatically.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="6759973158"
TEAM_ID="5LV4LWYXGD"
SCHEME="Pausely"
PROJECT="Pausely.xcodeproj"
OUT_DIR="${PAUSELY_RELEASE_DIR:-/tmp/PauselyRelease}"
MIN_SDK_MAJOR=27

CHECK_ONLY=0
BUMP=0
UPLOAD=0
REQUIRE_IOS27=0
ALLOW_OLDER_SDK=0

while (( $# )); do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --bump) BUMP=1 ;;
    --upload) UPLOAD=1 ;;
    --require-ios27) REQUIRE_IOS27=1 ;;
    --allow-older-sdk) ALLOW_OLDER_SDK=1 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

XCODE_VER="$(xcodebuild -version | tr '\n' ' ' | sed 's/  */ /g; s/ $//')"
SDK_VER="$(xcodebuild -sdk iphoneos -version SDKVersion 2>/dev/null || echo "0.0")"
SDK_MAJOR="${SDK_VER%%.*}"
TODAY_YM="$(date +%Y%m)"

echo "== Toolchain =="
echo "   $XCODE_VER"
echo "   iOS SDK: $SDK_VER (required >= ${MIN_SDK_MAJOR}.0 starting April 2027)"

if (( SDK_MAJOR < MIN_SDK_MAJOR )); then
  MSG="ITMS-90725: Active iOS SDK is $SDK_VER (< ${MIN_SDK_MAJOR}.0). Install macOS 26.6+ and Xcode 27+ for App Store submissions starting April 2027."
  if (( ALLOW_OLDER_SDK == 0 )) && (( REQUIRE_IOS27 == 1 || TODAY_YM >= 202704 )); then
    echo "ERROR: $MSG" >&2
    exit 1
  else
    echo "WARNING: $MSG"
  fi
else
  echo "   SDK compliance: OK (iOS $SDK_VER meets April 2027 iOS 27+ requirement)"
fi

if (( CHECK_ONLY )); then
  VERSION="$(grep -m1 'MARKETING_VERSION = ' "$PROJECT/project.pbxproj" | sed 's/.*= //; s/;//; s/ *$//')"
  BUILD="$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PROJECT/project.pbxproj" | sed 's/.*= //; s/;//; s/ *$//')"
  echo "   Project: Pausely ${VERSION:-?} (Build ${BUILD:-?})"
  exit 0
fi

if (( BUMP )); then
  NEXT_BUILD="$(asc builds list --app "$APP_ID" --limit 1 --output json | python3 -c '
import json, sys
d = json.load(sys.stdin)
items = d.get("data", [])
cur = int(items[0]["attributes"]["version"]) if items else 0
print(cur + 1)
')"
  echo "== Bumping build number to $NEXT_BUILD =="
  asc xcode version edit --project "$PROJECT" --build-number "$NEXT_BUILD" --output json
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "== Archiving Release build =="
asc xcode archive \
  --project "$PROJECT" \
  --scheme "$SCHEME" \
  --configuration Release \
  --clean \
  --archive-path "$OUT_DIR/Pausely.xcarchive" \
  --xcodebuild-flag=-destination \
  --xcodebuild-flag=generic/platform=iOS \
  --xcodebuild-flag=-allowProvisioningUpdates \
  --output json

cat > "$OUT_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>destination</key>
    <string>export</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

echo "== Exporting signed App Store IPA =="
asc xcode export \
  --archive-path "$OUT_DIR/Pausely.xcarchive" \
  --export-options "$OUT_DIR/ExportOptions.plist" \
  --ipa-path "$OUT_DIR/Pausely.ipa" \
  --xcodebuild-flag=-allowProvisioningUpdates \
  --output json

if (( UPLOAD )); then
  echo "== Uploading IPA to App Store Connect ($APP_ID) =="
  asc builds upload --app "$APP_ID" --ipa "$OUT_DIR/Pausely.ipa" --wait --output json
else
  echo "Done: signed IPA ready at $OUT_DIR/Pausely.ipa (re-run with --upload to upload to App Store Connect)."
fi
