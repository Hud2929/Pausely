#!/usr/bin/env bash
# Apply Pausely's store listing, free trial and (optionally) prices to App Store Connect.
#
#   scripts/asc_apply.sh                        READ-ONLY: shows what differs and dry-runs every change
#   scripts/asc_apply.sh --apply                applies the SAFE parts: the 11-locale listing for the editable
#                                               version, and the 7-day free trial
#   scripts/asc_apply.sh --apply --with-prices  ALSO changes the live subscription names/descriptions and prices
#
# Why prices are separate: Pausely 1.0.1 is live and both subscriptions are approved and on sale. A price
# DECREASE moves every existing subscriber to the lower price automatically and cannot be undone.
# Only use --with-prices after checking Sales and Trends shows no subscribers you would not want to discount,
# and after setting the subscriptions' territories (they are sold only in USA and CAN today; `equalize` needs
# every priced territory to be available: `asc subscriptions pricing availability edit`).
#
# History: first used 2026-10-20. The listing push and the trial import below were run for real and verified
# (99/99 listing fields matched on read-back). The price section has never been applied.
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="com.pausely.app.Pausely"
VERSION="1.0.3"
MONTHLY_ID="com.pausely.premium.monthly"; MONTHLY_PRICE="4.99"
ANNUAL_ID="com.pausely.premium.annual";   ANNUAL_PRICE="29.99"
TRIAL_TERRITORIES=(USA CAN)    # where the subscriptions are sold today
APPLY=0; PRICES=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --with-prices) PRICES=1 ;;
    *) echo "unknown option: $arg"; exit 2 ;;
  esac
done
if (( PRICES && ! APPLY )); then echo "--with-prices needs --apply"; exit 2; fi

say() { printf '\n== %s\n' "$*"; }
run() { if (( APPLY )); then "$@"; else printf '   [dry-run] %s\n' "$*"; fi; }

say "1. Local copy checks"
python3 scripts/store_copy.py --check
asc metadata validate --dir ./metadata --subscription-app --output table

say "2. Account access"
APPS_JSON=$(asc apps list --output json) || { echo "App Store Connect refuses access. The Account Holder must accept the agreements first."; exit 1; }
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
[[ -n "$APP_ID" ]] || { echo "No app with bundle id $BUNDLE_ID found."; exit 1; }
echo "   app id: $APP_ID (other apps in the account are never touched)"
export ASC_APP_ID="$APP_ID"
asc versions list --app "$APP_ID" --output table || true
echo "   The version below must be PREPARE_FOR_SUBMISSION to accept listing changes: $VERSION"

say "3. Store listing for 11 locales (editable version only; the live listing is not touched)"
rm -rf metadata_remote && mkdir -p metadata_remote
asc metadata pull --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata_remote >/dev/null || echo "   (could not pull: is $VERSION an editable version?)"
echo "   Differences, remote vs local (first 30 lines):"
diff -ru metadata_remote metadata | head -30 || true
asc metadata push --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata --dry-run --output table | tail -8
if (( APPLY )); then
  # Apple occasionally rejects a locale create transiently; the push is idempotent, so retry once.
  asc metadata push --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata >/dev/null \
    || { echo "   first attempt failed, retrying once"; asc metadata push --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata >/dev/null; }
  echo "   Verifying by reading the draft back..."
  rm -rf metadata_remote && mkdir -p metadata_remote
  asc metadata pull --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata_remote >/dev/null
  python3 - <<'PY'
import glob, json, os, sys
bad = checked = 0
for scope in ("app-info", "version/1.0.3"):
    for lf in sorted(glob.glob(f"metadata/{scope}/*.json")):
        rf = f"metadata_remote/{scope}/{os.path.basename(lf)}"
        if not os.path.exists(rf): print("   MISSING:", rf); bad += 1; continue
        L = json.load(open(lf, encoding="utf-8")); R = json.load(open(rf, encoding="utf-8"))
        for k, v in L.items():
            checked += 1
            if R.get(k) != v: bad += 1; print("   DIFF:", rf, k)
print(f"   verified {checked} fields, {bad} mismatches")
sys.exit(1 if bad else 0)
PY
fi
rm -rf metadata_remote

say "4. 7-day free trial for the territories where the plans are sold"
TRIAL_CSV=$(mktemp); { echo "territory"; printf '%s\n' "${TRIAL_TERRITORIES[@]}"; } > "$TRIAL_CSV"
for ID in "$MONTHLY_ID" "$ANNUAL_ID"; do
  COUNT=$(asc subscriptions offers introductory list --subscription-id "$ID" --app "$APP_ID" --output json 2>/dev/null | python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: print(0); sys.exit(0)
items = d.get("data", d) if isinstance(d, dict) else d
print(len(items))' || echo 0)
  if [[ "$COUNT" == "0" ]]; then
    if (( APPLY )); then
      asc subscriptions offers introductory import --subscription-id "$ID" --app "$APP_ID" --input "$TRIAL_CSV" \
        --offer-duration ONE_WEEK --offer-mode FREE_TRIAL --number-of-periods 1
    else
      asc subscriptions offers introductory import --subscription-id "$ID" --app "$APP_ID" --input "$TRIAL_CSV" \
        --offer-duration ONE_WEEK --offer-mode FREE_TRIAL --number-of-periods 1 --dry-run
    fi
  else
    echo "   $ID already has $COUNT introductory offer(s); leaving as is."
  fi
done
rm -f "$TRIAL_CSV"

if (( PRICES )); then
  say "5. Subscription names and descriptions (all 11 locales) and prices ($MONTHLY_PRICE / $ANNUAL_PRICE)"
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
      asc subscriptions localizations update --id "$EXISTING" --name "$NAME" --description "$DESC"
    else
      asc subscriptions localizations create --subscription-id "$PRODUCT" --app "$APP_ID" --locale "$LOCALE" --name "$NAME" --description "$DESC"
    fi
  done < "$SUB_TSV"
  rm -f "$SUB_TSV"
  asc subscriptions pricing equalize --subscription-id "$MONTHLY_ID" --app "$APP_ID" --base-price "$MONTHLY_PRICE" --confirm
  asc subscriptions pricing equalize --subscription-id "$ANNUAL_ID"  --app "$APP_ID" --base-price "$ANNUAL_PRICE"  --confirm
else
  say "5. Prices and subscription text: NOT changed (needs --apply --with-prices; read the header first)"
  asc subscriptions pricing summary --app "$APP_ID" --output table || true
fi

say "Done ($( (( APPLY )) && echo applied || echo 'read-only: nothing was changed'))"
(( APPLY )) || echo "   Review the output above, then run: scripts/asc_apply.sh --apply"
