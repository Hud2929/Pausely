#!/bin/zsh
# Builds and runs the money tests: the source guard, formatting, rates and totals.
# Usage: check_money.sh [simulator-id]   (defaults to the first booted or available iPhone)
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

SIM="${1:-$(xcrun simctl list devices booted | grep -m1 -oE '[0-9A-F-]{36}' || true)}"
if [[ -z "$SIM" ]]; then
  SIM="$(xcrun simctl list devices available | grep -m1 'iPhone' | grep -oE '[0-9A-F-]{36}')"
fi
LOG="${TMPDIR:-/tmp}/pausely-money-$$.log"

xcodebuild build-for-testing -project Pausely.xcodeproj -scheme Pausely \
  -destination "id=$SIM" -derivedDataPath /tmp/PauselyBuild -quiet > "$LOG" 2>&1 || {
  grep -E "error:" "$LOG" | sort -u; echo "Build failed (log: $LOG)"; exit 1; }

xcodebuild test-without-building -project Pausely.xcodeproj -scheme Pausely \
  -destination "id=$SIM" -derivedDataPath /tmp/PauselyBuild -parallel-testing-enabled NO \
  -only-testing:PauselyTests/CurrencyGuardTests \
  -only-testing:PauselyTests/MoneyFormatTests \
  -only-testing:PauselyTests/CurrencyRatesTests \
  -only-testing:PauselyTests/MoneyMathTests \
  -only-testing:PauselyTests/CurrencyManagerTests \
  -only-testing:PauselyTests/WidgetDataStoreTests > "$LOG" 2>&1 && STATUS=0 || STATUS=$?

grep -E "Executed [0-9]+ tests" "$LOG" | tail -1
awk '/Money handled outside Core\/Money:/{f=1} f{print} /testMoneyIsOnlyHandledByTheMoneyEngine.*(passed|failed)/{f=0}' "$LOG"
grep -E "error: -" "$LOG" | grep -v CurrencyGuardTests || true
[[ $STATUS -eq 0 ]] && echo "Money checks passed." || echo "Money checks failed (log: $LOG)"
exit $STATUS
