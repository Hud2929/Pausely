#!/usr/bin/env bash
# Apply Pausely's store listing, subscription text, prices and free trial to App Store Connect.
#
#   scripts/asc_apply.sh            READ-ONLY: checks access, shows what differs, dry-runs every change
#   scripts/asc_apply.sh --apply    performs the changes (only after you have reviewed the read-only run)
#
# Prerequisite: the Account Holder has accepted the agreements, so `asc apps list` no longer says
# "A required agreement is missing or has expired".
#
# NOTE: written while the account was blocked, so it has NOT been run against the live API.
# The read-only mode is the first test. Read its output before using --apply.
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="com.pausely.app.Pausely"
VERSION="1.0.3"
MONTHLY_ID="com.pausely.premium.monthly"; MONTHLY_PRICE="4.99"
ANNUAL_ID="com.pausely.premium.annual";   ANNUAL_PRICE="29.99"
APPLY=0; [[ "${1:-}" == "--apply" ]] && APPLY=1

say() { printf '\n== %s\n' "$*"; }
run() { if (( APPLY )); then "$@"; else printf '   [dry-run] %s\n' "$*"; fi; }

say "1. Local copy checks"
python3 scripts/store_copy.py --check
asc metadata validate --dir ./metadata --subscription-app --output table

say "2. Account access"
APPS_JSON=$(asc apps list --output json) || { echo "App Store Connect still refuses access. The Account Holder must accept the agreements first."; exit 1; }
APP_ID=$(printf '%s' "$APPS_JSON" | python3 -c '
import json, sys
want = sys.argv[1]
d = json.load(sys.stdin)
items = d.get("data", d) if isinstance(d, dict) else d
for it in items:
    attrs = it.get("attributes", it)
    if attrs.get("bundleId") == want:
        print(it.get("id", "")); break
' "$BUNDLE_ID")
[[ -n "$APP_ID" ]] || { echo "No app with bundle id $BUNDLE_ID found. Create the app record in App Store Connect first."; exit 1; }
echo "   app id: $APP_ID"
export ASC_APP_ID="$APP_ID"

say "3. Store listing (name, subtitle, keywords, description, promo text, what's new) for 11 locales"
mkdir -p metadata_remote
asc metadata pull --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata_remote || echo "   (could not pull: the $VERSION version may not exist yet; create it in App Store Connect)"
echo "   Differences, remote vs local (first 40 lines):"
diff -ru metadata_remote metadata | head -40 || true
asc metadata push --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata --dry-run --output table
if (( APPLY )); then asc metadata push --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata; fi

say "4. Subscription names and descriptions for every locale"
SUB_TSV=$(mktemp)
python3 - <<'PY' > "$SUB_TSV"
import json
d = json.load(open("appstore_products.json", encoding="utf-8"))
for p in d["products"]:
    for l in p["localization"]:
        print("\t".join([p["product_id"], l["locale"], l["display_name"], l["description"]]))
PY
while IFS=$'\t' read -r PRODUCT LOCALE NAME DESC; do
  EXISTING=$(asc subscriptions localizations list --subscription-id "$PRODUCT" --app "$APP_ID" --output json 2>/dev/null | python3 -c '
import json, sys
loc = sys.argv[1]
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
items = d.get("data", d) if isinstance(d, dict) else d
for it in items:
    attrs = it.get("attributes", it)
    if attrs.get("locale") == loc: print(it.get("id", "")); break
' "$LOCALE" || true)
  if [[ -n "$EXISTING" ]]; then
    run asc subscriptions localizations update --id "$EXISTING" --name "$NAME" --description "$DESC"
  else
    run asc subscriptions localizations create --subscription-id "$PRODUCT" --app "$APP_ID" --locale "$LOCALE" --name "$NAME" --description "$DESC"
  fi
done < "$SUB_TSV"
rm -f "$SUB_TSV"

say "5. Prices: US base price, every other country equalized by Apple"
asc subscriptions pricing equalize --subscription-id "$MONTHLY_ID" --app "$APP_ID" --base-price "$MONTHLY_PRICE" --dry-run
asc subscriptions pricing equalize --subscription-id "$ANNUAL_ID"  --app "$APP_ID" --base-price "$ANNUAL_PRICE"  --dry-run
if (( APPLY )); then
  asc subscriptions pricing equalize --subscription-id "$MONTHLY_ID" --app "$APP_ID" --base-price "$MONTHLY_PRICE" --confirm
  asc subscriptions pricing equalize --subscription-id "$ANNUAL_ID"  --app "$APP_ID" --base-price "$ANNUAL_PRICE"  --confirm
fi

say "6. 7-day free trial (introductory offer) on both plans"
for ID in "$MONTHLY_ID" "$ANNUAL_ID"; do
  COUNT=$(asc subscriptions offers introductory list --subscription-id "$ID" --app "$APP_ID" --output json 2>/dev/null | python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: print(0); sys.exit(0)
items = d.get("data", d) if isinstance(d, dict) else d
print(len(items))' || echo 0)
  if [[ "$COUNT" == "0" ]]; then
    run asc subscriptions offers introductory create --subscription-id "$ID" --app "$APP_ID" --offer-duration ONE_WEEK --offer-mode FREE_TRIAL --number-of-periods 1
  else
    echo "   $ID already has $COUNT introductory offer(s); leaving as is. Check it is a 7-day free trial."
  fi
done

say "Done ($([[ $APPLY == 1 ]] && echo applied || echo 'read-only: nothing was changed'))"
(( APPLY )) || echo "   Review the output above, then run: scripts/asc_apply.sh --apply"
