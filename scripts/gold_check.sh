#!/bin/bash
# The parts of GOLD_STANDARD.md a script can measure. Prints one line per check with a count; exits
# non-zero if any count is above zero. Run from the repository root:  scripts/gold_check.sh [-v]
# With -v each check also lists what it found.
cd "$(dirname "$0")/.." || exit 2
verbose=0; [ "$1" = "-v" ] && verbose=1
total=0
VIEWS="Pausely/Views Pausely/DesignSystem Pausely/ContentView.swift PauselyWidget"

report() {  # name, lines-of-findings
  local name="$1" findings="$2" count=0
  [ -n "$findings" ] && count=$(printf '%s\n' "$findings" | wc -l | tr -d ' ')
  printf '%-44s %s\n' "$name" "$count"
  [ "$verbose" = 1 ] && [ "$count" -gt 0 ] && printf '%s\n' "$findings" | sed 's/^/    /' | cut -c1-200
  total=$((total + count))
}

search() {  # pattern, then paths; prints file:line: text, skipping comment lines and the design system's own definitions
  local pattern="$1"; shift
  grep -rnE --include='*.swift' "$pattern" "$@" 2>/dev/null | grep -vE ':[0-9]+:\s*(//|\*)' | grep -v 'gold-check: allow'
}

# --- Design rules (pausely-design skill)
report "old UI tokens"                 "$(scripts/old_ui_check.sh 2>/dev/null | grep -v '^0 files' | grep -v 'files still have old UI' )"
report "colours outside the palette"   "$(search '(\.foregroundColor|\.foregroundStyle|\.fill|\.background|\.tint|\.stroke|Color)\(?\.?(red|blue|green|yellow|orange|purple|pink|teal|indigo|mint|gray|brown|cyan)\b|Color\.(red|blue|green|yellow|orange|purple|pink|teal|indigo|mint|gray|brown|cyan|primary|secondary)\b|Color\.(white|black)(\.opacity)?|Color\(hex:|\.foregroundColor\(\.(white|black)\)' $VIEWS | grep -v 'DesignSystem/InkPaper.swift' | grep -v 'PauselyWidget/WidgetInk.swift')"
report "fixed font sizes"              "$(search '\.font\(\.system\(size:|design: \.rounded|\.fontWeight\(\.(heavy|black)\)|weight: \.(heavy|black)' $VIEWS | grep -v 'DesignSystem/InkPaper.swift')"
report "raw animations and haptics"    "$(search '\.spring\(|\.easeInOut\(|\.easeIn\(|\.easeOut\(|\.linear\(|withAnimation\(\.default|\.animation\(\.default|repeatForever|UIImpactFeedbackGenerator|UINotificationFeedbackGenerator|UISelectionFeedbackGenerator' $VIEWS | grep -v 'DesignSystem/InkPaper.swift')"
report "left/right instead of leading" "$(search 'chevron\.(right|left)\b|\.padding\(\.(left|right)|alignment: \.(left|right)\b|multilineTextAlignment\(\.(left|right)\)|arrow\.(right|left)\b' $VIEWS)"
report "numeric corner radii"          "$(search '\.cornerRadius\([0-9]|cornerRadius: [0-9]' $VIEWS | grep -v 'DesignSystem/InkPaper.swift')"
report "full-screen covers off iPad width" "$(for f in $(grep -rlE 'fullScreenCover' --include='*.swift' Pausely); do grep -q 'readableWidth' "$f" || echo "$f"; done)"

# --- Naming
report "hype names"                    "$(search '\b(struct|class|enum|actor|protocol|typealias|extension)\s+(Revolutionary|Luxury|Premium|Genius|Neural|Singularity|Artistic|Ultimate|Magic|Real[A-Z])[A-Za-z]*|REVOLUTIONARY|[Ww]orld-class|1000s of ' Pausely PauselyWidget)"
report "TODO / FIXME / HACK"           "$(grep -rnE --include='*.swift' 'TODO|FIXME|HACK|XXX' Pausely PauselyWidget PauselyTests PauselyUITests 2>/dev/null)"

# --- Dead code and size
report "declarations nothing refers to" "$(python3 scripts/dead_code_check.py 2>/dev/null | grep -v 'declarations nothing refers to')"
report "Swift files over 700 lines"    "$(find Pausely PauselyWidget -name '*.swift' -exec wc -l {} + | awk '$1 > 700 && $2 != "total" {print $2 " (" $1 " lines)"}')"

# --- Repository
ROOT_KEEP='^(\.gitignore|\.env\.example|README\.md|CLAUDE\.md|AGENTS\.md|ENGINEERING_RULES\.md|GOLD_STANDARD\.md|REDESIGN_PLAN\.md|REVOLUTION_PLAN\.md|INBOX_PLAN\.md|SUPABASE_EMAIL_TEMPLATES\.md|PRIVACY_POLICY\.md|TERMS_OF_SERVICE\.md|appstore_products\.json|CNAME)$'
report "stray files at the repository root" "$(git ls-files | grep -v / | grep -vE "$ROOT_KEEP")"

echo "--------------------------------------------"
printf '%-44s %s\n' "TOTAL" "$total"
[ "$total" -eq 0 ]
