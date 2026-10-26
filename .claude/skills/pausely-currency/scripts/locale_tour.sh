#!/bin/zsh
# Screenshots the screens with the most money on them, in several locales, using DEBUG demo data.
# Usage: locale_tour.sh [simulator-id] [output-folder]
# Then look at every image: one currency per total, symbols as that country writes them,
# parts that add up to their totals, no "$" outside dollar countries.
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

SIM="${1:-$(xcrun simctl list devices available | grep -m1 'iPhone' | grep -oE '[0-9A-F-]{36}')}"
OUT="${2:-${TMPDIR:-/tmp}/pausely-locale-tour}"
APP_ID=com.pausely.app.Pausely
mkdir -p "$OUT"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcodebuild build -project Pausely.xcodeproj -scheme Pausely -destination "id=$SIM" \
  -derivedDataPath /tmp/PauselyBuild -quiet
xcrun simctl install "$SIM" /tmp/PauselyBuild/Build/Products/Debug-iphonesimulator/Pausely.app

shoot() {  # locale name args...
  local locale=$1 name=$2; shift 2
  xcrun simctl terminate "$SIM" $APP_ID 2>/dev/null || true
  xcrun simctl launch "$SIM" $APP_ID -AppleLocale "$locale" -AppleLanguages "(${locale%%_*})" \
    -selected_currency "" --screenshots "$@" >/dev/null
  sleep 8
  xcrun simctl io "$SIM" screenshot "$OUT/${locale}-${name}.png" >/dev/null 2>&1
}

for locale in en_CA en_US de_DE ja_JP; do
  shoot $locale dashboard --demo-mode --demo-tab=0 --demo-savings
  shoot $locale subscriptions --demo-mode --demo-tab=1
  shoot $locale analysis --demo-mode --demo-tab=2
  shoot $locale verdict --demo-verdict
  shoot $locale receipt --demo-receipt
  shoot $locale paywall --demo-paywall
done
echo "Screenshots in $OUT"
