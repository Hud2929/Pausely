#!/bin/bash
# The whole proof in one command, cheapest step first. Each step prints one line; the run stops at
# the first step that fails and exits non-zero, naming the log to read.
#   scripts/proof.sh                    the mechanical checks, unit tests, the mail rig, UI tests, a Release build
#   scripts/proof.sh unit ui            only the steps named: checks | unit | mail | ui | release | db
# `mail` writes the synthetic mailbox, serves it on this Mac and runs the tests that a plain run skips
# for want of a mail server: the scan scored against the mailbox's truth, the app's own IMAP stack end
# to end, and the walk through the mailbox screens. Nothing leaves this Mac.
# `db` is the database rig and the three function rigs. It needs Docker, so it runs only when named.
# The simulator is PAUSELY_SIM=<simulator id>, or the first iPhone simulator there is.
# The UI tests are in the plain run on purpose: left out of it, one of them failed unseen for four days.
# The screen tour is not: it takes pictures, it does not pass or fail (see CLAUDE.md).
cd "$(dirname "$0")/.." || exit 2
steps=("$@"); [ ${#steps[@]} -eq 0 ] && steps=(checks unit mail ui release)
sim="${PAUSELY_SIM:-$(xcrun simctl list devices available | grep -m1 -oE 'iPhone[^(]*\([0-9A-F-]{36}\)' | grep -oE '[0-9A-F-]{36}')}"
[ -n "$sim" ] || { echo "no iPhone simulator found: set PAUSELY_SIM"; exit 2; }
build="${PAUSELY_BUILD_DIR:-/tmp/PauselyBuild}"
mkdir -p "$build"

said() {  # the line of a log that says how it went; a function rig's checks are counted
  local checks; checks=$(grep -acE '^ +pass  ' "$1")
  if [ "$checks" -gt 0 ]; then echo "$checks checks passed"; return; fi
  local score; score=$(grep -a 'SCORE found' "$1" | tail -1 | sed 's/^.*SCORE //')
  if [ -n "$score" ]; then echo "$score; $(grep -ac "' passed (" "$1") tests passed, $(grep -ac "' skipped (" "$1") skipped (real providers, real inboxes)"; return; fi
  grep -aoE 'Executed [0-9]+ tests?, with ([0-9]+ tests? skipped and )?[0-9]+ failures|^TOTAL +[0-9]+|[0-9]+ passed, [0-9]+ failed|BUILD SUCCEEDED' "$1" | tail -1
}
step() {  # name, log, command
  local name="$1" log="$2"; shift 2
  if "$@" > "$log" 2>&1; then
    printf '%-13s passed   %s\n' "$name" "$(said "$log")"
  else
    printf '%-13s FAILED   read %s\n' "$name" "$log"
    grep -aE '^/.*: error: |error: -\[|FAIL  |[1-9][0-9]* failed|^[a-z].* +[1-9][0-9]*$' "$log" | head -20 | cut -c1-220
    exit 1
  fi
}
tests() {  # target, then anything else for xcodebuild
  local target="$1"; shift
  xcodebuild test -scheme Pausely -destination "id=$sim" -derivedDataPath "$build" \
    -only-testing:"$target" -parallel-testing-enabled NO -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 300 "$@"
}

mail_rig() {  # the synthetic mailbox, served here, and every test that needs a mail server
  local box port=1143 spec server code
  box=$(mktemp -d "$build/proof_mailbox.XXXXXX") || return 1
  python3 scripts/mailtest/make_test_mailbox.py "$box" || return 1
  python3 scripts/mailtest/imap_test_server.py --port "$port" --account "tester@pausely.test:app-pass-1234:$box" \
    > "$build/proof_mail_server.log" 2>&1 &
  server=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do nc -z 127.0.0.1 "$port" 2>/dev/null && break; sleep 1; done
  spec="127.0.0.1:$port:tester@pausely.test:app-pass-1234"
  TEST_RUNNER_PAUSELY_LOCAL_IMAP="$spec" TEST_RUNNER_PAUSELY_LOCAL_IMAP_APP="$spec" \
  TEST_RUNNER_PAUSELY_MAIL_TRUTH_DIR="$box" TEST_RUNNER_PAUSELY_REAL_MAIL_DIR="$box/INBOX" \
    tests PauselyTests/MailTruthTests -only-testing:PauselyTests/LiveMailboxTests \
  && TEST_RUNNER_PAUSELY_LOCAL_IMAP_UI="$spec" TEST_RUNNER_PAUSELY_LOCAL_IMAP_UI_EXPECT="Netflix,Spotify,Ironside Fitness" \
    tests PauselyUITests/InboxWorkflowUITests
  code=$?
  kill "$server" 2>/dev/null; wait "$server" 2>/dev/null
  return $code
}

for s in "${steps[@]}"; do
  case "$s" in
    checks)  step checks "$build/proof_checks.log" bash scripts/gold_check.sh -v ;;
    unit)    step unit "$build/proof_unit.log" tests PauselyTests ;;
    mail)    step mail "$build/proof_mail.log" mail_rig ;;
    ui)      step ui "$build/proof_ui.log" tests PauselyUITests -skip-testing:PauselyUITests/ScreenTourTests ;;
    release) step release "$build/proof_release.log" xcodebuild build -scheme Pausely -configuration Release \
               -destination "id=$sim" -derivedDataPath "${build}Release" ;;
    db)      step database "$build/proof_db.log" bash scripts/dbtest/run.sh
             step waitlist "$build/proof_waitlist.log" bash scripts/dbtest/waitlist_function.sh
             step auth-email "$build/proof_auth_email.log" bash scripts/dbtest/auth_email_function.sh
             step apple-revoke "$build/proof_apple_revoke.log" bash scripts/dbtest/apple_revoke_function.sh
             step appstore-v2 "$build/proof_appstore_v2.log" bash scripts/dbtest/appstore_notifications_function.sh ;;
    *)       echo "unknown step: $s (checks | unit | mail | ui | release | db)"; exit 2 ;;
  esac
done
