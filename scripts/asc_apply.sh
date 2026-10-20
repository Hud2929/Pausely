#!/usr/bin/env bash
# Apply Pausely's store listing, free trial, subscription text and prices to App Store Connect.
#
#   scripts/asc_apply.sh                          read-only: shows what differs and dry-runs the SAFE sections
#   scripts/asc_apply.sh --apply                  applies the SAFE sections: listing, trial
#   scripts/asc_apply.sh [--apply] --only text    runs one section (listing | trial | text | prices)
#
# Sections:
#   listing  the 11-locale listing for the EDITABLE version (the live listing is never touched); read-back verified
#   trial    the 7-day free trial in every territory (existing offers are reported as duplicates, not errors)
#   text     subscription names/descriptions in all 11 locales (appstore_products.json)
#   prices   makes both subscriptions available in every territory and schedules the launch prices
#
# Prices are NOT in the default run. Pausely 1.0.1 is live and both subscriptions are approved and on sale, so:
#   - a price DECREASE moves existing subscribers to the lower price automatically and cannot be undone;
#   - `asc subscriptions pricing equalize --confirm` does NOT work on approved subscriptions (Apple refuses to
#     create "initial" prices again). Prices must be created as DATED changes, which is what this script does:
#     it takes Apple's equalized price point for each country from `equalize --dry-run`, then imports them
#     with a start date. Countries already at the target price are skipped by Apple automatically.
#
# History: 2026-10-20 listing, trial (US+CA, then all 175 territories), availability (all 175 territories) and
# prices ($4.99 / $29.99, starting 2026-10-21, verified for every country) were applied with these commands.
# Re-running `prices` is only for a NEW price change.
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="com.pausely.app.Pausely"
VERSION="1.0.3"
MONTHLY_ID="com.pausely.premium.monthly"; MONTHLY_PRICE="4.99"
ANNUAL_ID="com.pausely.premium.annual";   ANNUAL_PRICE="29.99"
PRICE_START="${PRICE_START:-$(date -v+1d +%Y-%m-%d)}"      # dated price changes take effect on this date
APPLY=0; SECTIONS=()
while (( $# )); do
  case "$1" in
    --apply) APPLY=1 ;;
    --only) shift; SECTIONS+=("${1:?--only needs a section name}") ;;
    *) echo "unknown option: $1"; exit 2 ;;
  esac
  shift
done
(( ${#SECTIONS[@]} )) || SECTIONS=(listing trial)
wants() { local s; for s in "${SECTIONS[@]}"; do [[ "$s" == "$1" ]] && return 0; done; return 1; }

say() { printf '\n== %s\n' "$*"; }
run() { if (( APPLY )); then "$@"; else printf '   [dry-run] %s\n' "$*"; fi; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

say "Local copy checks"
python3 scripts/store_copy.py --check
asc metadata validate --dir ./metadata --subscription-app --output table | sed -n 2,3p

say "Account access"
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
asc pricing territories list --paginate --output json 2>/dev/null | python3 -c '
import json, sys
print("\n".join(x["id"] for x in json.load(sys.stdin).get("data", [])))' > "$TMP/territories.txt"
echo "   territories: $(wc -l < "$TMP/territories.txt" | tr -d ' ')"

if wants listing; then
  say "listing: 11 locales for version $VERSION (must be PREPARE_FOR_SUBMISSION)"
  asc versions list --app "$APP_ID" --output table || true
  mkdir -p "$TMP/remote"
  asc metadata pull --app "$APP_ID" --version "$VERSION" --platform IOS --dir "$TMP/remote" >/dev/null || echo "   (could not pull: is $VERSION editable?)"
  asc metadata push --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata --dry-run --output table | tail -8
  if (( APPLY )); then
    # Apple occasionally rejects a locale create transiently; the push is idempotent, so retry once.
    asc metadata push --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata >/dev/null \
      || { echo "   first attempt failed, retrying once"; asc metadata push --app "$APP_ID" --version "$VERSION" --platform IOS --dir ./metadata >/dev/null; }
    rm -rf "$TMP/remote"; mkdir -p "$TMP/remote"
    asc metadata pull --app "$APP_ID" --version "$VERSION" --platform IOS --dir "$TMP/remote" >/dev/null
    python3 - "$TMP/remote" <<'PY'
import glob, json, os, sys
remote = sys.argv[1]
bad = checked = 0
for scope in ("app-info", "version/1.0.3"):
    for lf in sorted(glob.glob(f"metadata/{scope}/*.json")):
        rf = f"{remote}/{scope}/{os.path.basename(lf)}"
        if not os.path.exists(rf): print("   MISSING:", rf); bad += 1; continue
        L = json.load(open(lf, encoding="utf-8")); R = json.load(open(rf, encoding="utf-8"))
        for k, v in L.items():
            checked += 1
            if R.get(k) != v: bad += 1; print("   DIFF:", rf, k)
print(f"   verified {checked} fields, {bad} mismatches")
sys.exit(1 if bad else 0)
PY
  fi
fi

if wants trial; then
  say "trial: 7-day free trial in every territory"
  { echo "territory"; cat "$TMP/territories.txt"; } > "$TMP/trial.csv"
  for ID in "$MONTHLY_ID" "$ANNUAL_ID"; do
    FLAG=(); (( APPLY )) || FLAG=(--dry-run)
    asc subscriptions offers introductory import --subscription-id "$ID" --app "$APP_ID" --input "$TMP/trial.csv" \
      --offer-duration ONE_WEEK --offer-mode FREE_TRIAL --number-of-periods 1 "${FLAG[@]}" --output json | tail -c 400 || true
    echo
  done
fi

if wants text; then
  say "text: subscription names and descriptions, 11 locales"
  python3 - <<'PY' > "$TMP/sub_text.tsv"
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
  done < "$TMP/sub_text.tsv"
fi

if wants prices; then
  say "prices: available in every territory, then dated price changes starting $PRICE_START"
  IDS=$(paste -sd, "$TMP/territories.txt")
  for ID in "$MONTHLY_ID" "$ANNUAL_ID"; do
    run asc subscriptions pricing availability edit --subscription-id "$ID" --app "$APP_ID" --territories "$IDS" --available-in-new-territories=true --output json
  done
  for PAIR in "$MONTHLY_ID:$MONTHLY_PRICE" "$ANNUAL_ID:$ANNUAL_PRICE"; do
    ID="${PAIR%%:*}"; PRICE="${PAIR##*:}"
    asc subscriptions pricing equalize --subscription-id "$ID" --app "$APP_ID" --base-price "$PRICE" --dry-run --output json > "$TMP/eq.out" 2>&1 || true
    python3 - "$TMP/eq.out" "$TMP/prices_$ID.csv" <<'PY'
import csv, json, sys
line = [l for l in open(sys.argv[1], encoding="utf-8") if l.startswith("{")][-1]
d = json.loads(line)
with open(sys.argv[2], "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh); w.writerow(["territory", "price", "price_point_id"])
    for r in d["territories"]: w.writerow([r["territory"], r["price"], r["pricePointId"]])
print(f"   {d['total']} equalized prices resolved for base ${d['basePrice']}")
PY
    FLAG=(); (( APPLY )) || FLAG=(--dry-run)
    asc subscriptions pricing prices import --subscription-id "$ID" --app "$APP_ID" --input "$TMP/prices_$ID.csv" \
      --start-date "$PRICE_START" "${FLAG[@]}" --output json | tail -c 300
    echo
  done
fi

say "Done ($( (( APPLY )) && echo applied || echo 'read-only: nothing was changed'))"
(( APPLY )) || echo "   Review the output above, then add --apply"
