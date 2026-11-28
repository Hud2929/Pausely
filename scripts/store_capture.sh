#!/bin/zsh
# Takes the eight App Store captures in every listing locale, on one simulator.
# Usage: scripts/store_capture.sh <iphone-6.9|ipad-13> <simulator id> [locale …]
# Writes AppStoreScreenshots/captures/<locale>/<device>/01_verdict.png … 08_wrapped.png.
# The frames with captions are made from these by scripts/store_frames.swift.
#
# The first pass is thrown away: it lets the app fetch the logos. Then the clock is set (9:41).
set -uo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

device="${1:?iphone-6.9 or ipad-13}"; sim="${2:?simulator id}"; shift 2
locales=("$@"); [ ${#locales[@]} -gt 0 ] || locales=(en_CA en_US en_GB en_AU fr_CA fr_FR es_MX es_ES de_DE ja_JP ar_SA)
build=/tmp/PauselyBuild
logs="$build/store_capture_logs"; mkdir -p "$logs"

run() {  # locale, folder
  TEST_RUNNER_PAUSELY_TOUR_DIR="$2" TEST_RUNNER_PAUSELY_STORE_LOCALE="$1" \
    xcodebuild test-without-building -scheme Pausely -destination "id=$sim" -derivedDataPath "$build" \
    -only-testing:PauselyUITests/ScreenTourTests/testStoreScreenshots -parallel-testing-enabled NO \
    > "$logs/$device-$1.log" 2>&1
}

xcodebuild build-for-testing -scheme Pausely -destination "id=$sim" -derivedDataPath "$build" \
  > "$logs/$device-build.log" 2>&1 || { echo "build failed: $logs/$device-build.log"; exit 1; }

# Booted here, so it stays up between runs: a simulator that xcodebuild boots for itself is shut
# down again when the run ends, and the clock set on it is forgotten.
xcrun simctl bootstatus "$sim" -b > /dev/null || { echo "simulator did not boot"; exit 1; }
run en_CA "$build/store_warmup_$device" || echo "warm-up pass failed (see $logs/$device-en_CA.log)"
clock() {
  xcrun simctl status_bar "$sim" override --time 9:41 --batteryState discharging --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 --dataNetwork wifi
}
# The iPad's status bar carries the date, and the system writes it in the simulator's own language
# whatever language the app was started in. So the simulator is put into each locale before its run.
speak() {  # locale
  # Up first: after a run the simulator is sometimes found shutting down, and a setting written
  # then is lost without the run failing (the Arabic pictures once carried a Japanese date).
  xcrun simctl bootstatus "$sim" -b > /dev/null || return 1
  xcrun simctl spawn "$sim" defaults write "Apple Global Domain" AppleLanguages -array "${1/_/-}" || return 1
  xcrun simctl spawn "$sim" defaults write "Apple Global Domain" AppleLocale -string "$1" || return 1
  xcrun simctl shutdown "$sim"; xcrun simctl bootstatus "$sim" -b > /dev/null && clock
}

clock || { echo "clock not set"; exit 1; }

failed=0
for locale in "${locales[@]}"; do
  out="$PWD/AppStoreScreenshots/captures/$locale/$device"; mkdir -p "$out"
  if [ "$device" = ipad-13 ]; then speak "$locale" || { echo "FAIL $locale (simulator language)"; failed=1; continue; }; fi
  if run "$locale" "$out" && [ "$(ls "$out"/*.png 2>/dev/null | wc -l | tr -d ' ')" = 8 ]; then
    echo "ok   $locale"
  else
    echo "FAIL $locale (see $logs/$device-$locale.log)"; failed=1
  fi
done
[ "$device" = ipad-13 ] && speak en_US  # left as it was found
xcrun simctl shutdown "$sim" 2>/dev/null
exit $failed
