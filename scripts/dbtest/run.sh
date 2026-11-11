#!/bin/bash
# Proves Pausely's database rules against a throwaway local Postgres that stands in for Supabase.
# Nothing here touches the real project.
#
#   bash scripts/dbtest/run.sh            every starting state, then the checks
#   KEEP=1 bash scripts/dbtest/run.sh     leave the container running afterwards, to look around
#
# It builds four starting states a real database could be in, applies supabase/APPLY_*.sql twice to
# each (a second run must change nothing and must not fail), and then acts as a signed-out visitor,
# as two signed-in people and as the service role to check what each can and cannot do.
#   minimal  only the first migration
#   old      migrations up to 2026-05-20 (a database that never got the October and November files)
#   oct22    migrations up to 20261022b (ratings exist, but one person could still rate a service twice)
#   nov6     every migration up to 20261106
#   fresh    every migration in filename order, without the APPLY file
# Needs Docker (Colima is fine). Exits 1 if any check fails.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATIONS="$ROOT/supabase/migrations"
APPLY="$(ls "$ROOT"/supabase/APPLY_*.sql | sort | tail -1)"
STUB="$ROOT/scripts/dbtest/supabase_stub.sql"
CONTAINER=pausely-dbtest
IMAGE=postgres:17-alpine

if [ -z "${DOCKER_HOST:-}" ] && [ -S "$HOME/.colima/default/docker.sock" ]; then
  export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
fi

A=aaaaaaaa-0000-4000-8000-000000000001   # an ordinary signed-in person
B=bbbbbbbb-0000-4000-8000-000000000002   # a person Pausely granted Pro
C=cccccccc-0000-4000-8000-000000000003   # signed in, no profile row yet
D=dddddddd-0000-4000-8000-000000000004   # deletes their account

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '    pass  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '    FAIL  %s\n          %s\n' "$1" "$2"; }

# ---- plumbing --------------------------------------------------------------------------------

admin() {  # admin <db>   (SQL on stdin, run as the database owner)
  docker exec -i "$CONTAINER" psql -U postgres -X -v ON_ERROR_STOP=1 -qAt -d "$1" 2>&1
}

apply_file() {  # apply_file <db> <file> [single-transaction flag]
  docker exec -i "$CONTAINER" psql -U postgres -X -v ON_ERROR_STOP=1 -q ${3:-} -d "$1" < "$2" 2>&1
}

# as <db> <role> <user id or -> <sql>: runs the SQL the way the API would for that caller.
# END=rollback leaves no trace.
as() {
  local db=$1 role=$2 uid=$3 sql=$4 claims email
  case "$uid" in
    "$A") email=a@example.test ;; "$B") email=b@example.test ;;
    "$C") email=c@example.test ;; "$D") email=d@example.test ;; *) email= ;;
  esac
  if [ "$uid" = "-" ]; then claims="{\"role\":\"$role\"}"
  else claims="{\"sub\":\"$uid\",\"role\":\"$role\",\"email\":\"$email\"}"; fi
  printf "begin;\nset local request.jwt.claims = '%s';\nset local role %s;\n%s;\n%s;\n" \
    "$claims" "$role" "$sql" "${END:-commit}" | admin "$db"
}

works()  { local label=$1; shift; local out; if out=$(as "$@"); then pass "$label"; else fail "$label" "$(printf '%s' "$out" | tail -1)"; fi; }
refused() { local label=$1; shift; local out; if out=$(as "$@"); then fail "$label" "it was allowed"; else pass "$label"; fi; }
gives()  { local label=$1 want=$2; shift 2; local out; out=$(as "$@" | tail -1)
           if [ "$out" = "$want" ]; then pass "$label"; else fail "$label" "wanted '$want', got '$out'"; fi; }
# hidden: the caller either is refused or sees no rows.
hidden() { local label=$1; shift; local out; if out=$(as "$@"); then
             if [ "$(printf '%s' "$out" | tail -1)" = "0" ]; then pass "$label"; else fail "$label" "rows were visible: $(printf '%s' "$out" | tail -1)"; fi
           else pass "$label"; fi; }
owner_sees() { local label=$1 want=$2 db=$3 sql=$4 out; out=$(printf '%s;\n' "$sql" | admin "$db" | tail -1)
               if [ "$out" = "$want" ]; then pass "$label"; else fail "$label" "wanted '$want', got '$out'"; fi; }
has() { [ "$(printf "select to_regclass('public.%s') is not null;\n" "$2" | admin "$1")" = "t" ]; }

# ---- starting states -------------------------------------------------------------------------

build() {  # build <db> <newest migration to include, by filename prefix>
  local db=$1 upto=$2 file name out
  printf 'drop database if exists %s;\ncreate database %s;\n' "$db" "$db" | docker exec -i "$CONTAINER" psql -U postgres -X -q -d postgres >/dev/null 2>&1
  apply_file "$db" "$STUB" >/dev/null
  for file in $(ls "$MIGRATIONS"/*.sql | sort); do
    name=$(basename "$file")
    [[ "${name%%_*}" > "$upto" ]] && continue
    if ! out=$(apply_file "$db" "$file" -1); then
      fail "$db: migration $name applies" "$(printf '%s' "$out" | grep -m1 ERROR)"
    fi
  done
}

seed() {  # rows that exist before the fix is applied, wherever the table exists
  admin "$1" >/dev/null <<SQL
insert into auth.users (id, email) values
  ('$A', 'a@example.test'), ('$B', 'b@example.test'), ('$C', 'c@example.test'), ('$D', 'd@example.test');
insert into public.profiles (id, display_name, is_pro) values ('$A', 'A', false), ('$B', 'B', true), ('$D', 'D', false);
do \$\$
declare amount_column text := (select column_name from information_schema.columns
    where table_schema = 'public' and table_name = 'subscriptions' and column_name in ('amount', 'cost') limit 1);
begin
  execute format('insert into public.subscriptions (user_id, name, %I) values (\$1, ''Netflix'', 15.49), (\$2, ''Spotify'', 9.99), (\$3, ''Hulu'', 7.99)', amount_column)
    using '$A'::uuid, '$B'::uuid, '$D'::uuid;
  if to_regclass('public.referral_codes') is not null then
    insert into public.referral_codes (code, referrer_user_id, conversions) values ('BCODE', '$B', 2);
    insert into public.referral_conversions (referrer_code, referred_user_id, referred_user_email) values ('BCODE', '$A', 'a@example.test');
  end if;
  if to_regclass('public.affiliates') is not null then
    insert into public.affiliates (name, code, payment_method, payment_details) values ('An affiliate', 'AFF1', 'bank', 'account 000-111');
  end if;
  if to_regclass('public.waitlist') is not null then
    insert into public.waitlist (email) values ('waiting@example.test');
  end if;
  if to_regclass('public.user_profiles') is not null then
    insert into public.user_profiles (id) values ('$A');
  end if;
  if to_regclass('public.cancel_difficulty_ratings') is not null then
    -- The same person rated one service twice before the one-per-person rule existed.
    if not exists (select 1 from pg_indexes where indexname = 'cancel_difficulty_one_per_user') then
      insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id, created_at)
        values ('Netflix', 2, '$B', now() - interval '2 days');
    end if;
    insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('Netflix', 4, '$B');
  end if;
end \$\$;
SQL
}

seed_after() {  # states that had no ratings table before the fix get the same single rating now
  admin "$1" >/dev/null <<SQL
insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id)
select 'Netflix', 4, '$B'
where not exists (select 1 from public.cancel_difficulty_ratings where user_id = '$B' and service_name = 'Netflix');
SQL
}

# ---- what an unfixed database allows (run on "old"; each line passing means the hole is real) ----

holes() {
  local db=$1
  printf '  %s before the fix: these must succeed, or the checks below prove nothing\n' "$db"
  END=rollback works  "a person can mark themselves Pro"            "$db" authenticated "$A" "update public.profiles set is_pro = true where id = '$A' returning 1"
  END=rollback gives  "a signed-out visitor can read affiliate payment details" "account 000-111" "$db" anon - "select payment_details from public.affiliates"
  END=rollback gives  "a signed-out visitor can list referral codes" 1 "$db" anon - "select count(*) from public.referral_codes"
  END=rollback works  "a signed-out visitor can read anyone's monthly spend" "$db" anon - "select public.calculate_monthly_spend('$B')"
  END=rollback works  "a signed-out visitor can write to the waitlist" "$db" anon - "insert into public.waitlist (email) values ('x@example.test')"
  END=rollback gives  "a person can give their referral code free-Pro status" t "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id, is_eligible_for_free_pro) values ('ACODE', '$A', true) returning is_eligible_for_free_pro"
}

# ---- what a fixed database allows -------------------------------------------------------------

checks() {
  local db=$1
  printf '  %s after the fix\n' "$db"

  # Pro
  refused "a person cannot mark themselves Pro"                 "$db" authenticated "$A" "update public.profiles set is_pro = true where id = '$A'"
  refused "a person cannot change their Pro tier"               "$db" authenticated "$A" "update public.profiles set pro_tier = 'lifetime' where id = '$A'"
  works   "a person can still edit their own profile"           "$db" authenticated "$A" "update public.profiles set display_name = 'New name' where id = '$A'"
  works   "a granted-Pro person can edit their profile"         "$db" authenticated "$B" "update public.profiles set display_name = 'B again' where id = '$B'"
  owner_sees "and keeps Pro afterwards" t "$db" "select is_pro from public.profiles where id = '$B'"
  works   "the app's age-consent upsert works"                  "$db" authenticated "$A" "insert into public.profiles (id, age_confirmed_at, age_minimum_met, age_minimum_required, consent_policy_version, consent_app_version) values ('$A', now(), true, 16, '2026-10', '1.0.3') on conflict (id) do update set age_confirmed_at = excluded.age_confirmed_at, age_minimum_met = excluded.age_minimum_met, age_minimum_required = excluded.age_minimum_required, consent_policy_version = excluded.consent_policy_version, consent_app_version = excluded.consent_app_version"
  works   "a new person can create their profile, asking for Pro" "$db" authenticated "$C" "insert into public.profiles (id, display_name, is_pro, pro_tier) values ('$C', 'C', true, 'lifetime')"
  owner_sees "and the row is saved without Pro" "f|" "$db" "select is_pro, pro_tier from public.profiles where id = '$C'"
  gives   "a person cannot edit someone else's profile" 0       "$db" authenticated "$A" "with changed as (update public.profiles set display_name = 'hacked' where id = '$B' returning 1) select count(*) from changed"
  gives   "a person cannot read someone else's profile" 0       "$db" authenticated "$A" "select count(*) from public.profiles where id = '$B'"
  gives   "a signed-out visitor sees no profiles" 0             "$db" anon - "select count(*) from public.profiles"
  works   "the service role can grant Pro"                      "$db" service_role - "update public.profiles set is_pro = true, pro_tier = 'lifetime' where id = '$C'"
  owner_sees "and the grant is saved" "t|lifetime" "$db" "select is_pro, pro_tier from public.profiles where id = '$C'"
  works   "the service role can take Pro away again"            "$db" service_role - "update public.profiles set is_pro = false, pro_tier = null where id = '$C'"

  # Other server-kept profile fields
  works   "an update that tries to change server-kept fields goes through" "$db" authenticated "$A" "update public.profiles set subscription_count_limit = 999, affiliate_code = 'SELF', attributed_at = now(), email = 'someone-else@example.test', display_name = 'A2' where id = '$A'"
  owner_sees "but those fields are unchanged and the email is the account's" "5|||a@example.test|A2" "$db" "select subscription_count_limit, affiliate_code, attributed_at, email, display_name from public.profiles where id = '$A'"

  # Subscriptions: the table the app lives on
  works   "a person can add a subscription"                     "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount) values ('$A', 'Disney+', 7.99)"
  gives   "a person sees only their own subscriptions" 2        "$db" authenticated "$A" "select count(*) from public.subscriptions"
  works   "a person can edit their own subscription"            "$db" authenticated "$A" "update public.subscriptions set amount = 8.99 where user_id = '$A' and name = 'Disney+'"
  works   "a person can delete their own subscription"          "$db" authenticated "$A" "delete from public.subscriptions where user_id = '$A' and name = 'Disney+'"
  refused "a person cannot add a subscription to someone else's account" "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount) values ('$B', 'Planted', 1)"
  refused "a person cannot hand their subscription to someone else" "$db" authenticated "$A" "update public.subscriptions set user_id = '$B' where user_id = '$A'"
  gives   "a person cannot edit someone else's subscription" 0  "$db" authenticated "$A" "with changed as (update public.subscriptions set amount = 0 where user_id = '$B' returning 1) select count(*) from changed"
  gives   "a person cannot delete someone else's subscription" 0 "$db" authenticated "$A" "with gone as (delete from public.subscriptions where user_id = '$B' returning 1) select count(*) from gone"
  gives   "a signed-out visitor sees no subscriptions" 0        "$db" anon - "select count(*) from public.subscriptions"
  refused "a signed-out visitor cannot add a subscription"      "$db" anon - "insert into public.subscriptions (user_id, name, amount) values ('$A', 'Planted', 1)"

  # Cancel-difficulty ratings
  owner_sees "an earlier double rating was reduced to the latest one" "1|4" "$db" "select count(*), max(difficulty_rating) from public.cancel_difficulty_ratings where user_id = '$B' and service_name = 'Netflix'"
  works   "a person can rate a service"                         "$db" authenticated "$A" "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('Netflix', 5, '$A')"
  refused "but not twice"                                       "$db" authenticated "$A" "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('Netflix', 1, '$A')"
  refused "a person cannot rate under someone else's id"        "$db" authenticated "$A" "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('Hulu', 1, '$B')"
  refused "a signed-out visitor cannot rate"                    "$db" anon - "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating) values ('Hulu', 1)"
  hidden  "nobody can read individual ratings"                  "$db" authenticated "$A" "select count(*) from public.cancel_difficulty_ratings"
  gives   "anyone can read the per-service average" "Netflix|4.5|2" "$db" anon - "select service_name, avg_difficulty, rating_count from public.service_difficulty_scores"

  # Settings (build 11 reads and writes them)
  works   "a person can save their settings row"                "$db" authenticated "$A" "insert into public.user_settings (user_id, referral_discount_used) values ('$A', true) on conflict (user_id) do update set referral_discount_used = excluded.referral_discount_used"
  gives   "a person cannot read someone else's settings" 0      "$db" authenticated "$B" "select count(*) from public.user_settings where user_id = '$A'"
  refused "a person cannot write someone else's settings"       "$db" authenticated "$B" "insert into public.user_settings (user_id) values ('$C')"

  # The deletion log
  hidden  "nobody can read the deletion log"                    "$db" authenticated "$A" "select count(*) from public.deletion_requests"
  refused "nobody can write to the deletion log"                "$db" authenticated "$A" "insert into public.deletion_requests (user_id) values ('$A')"

  # Referral codes (older builds and build 11)
  if has "$db" referral_codes; then
    hidden  "a signed-out visitor cannot list referral codes"   "$db" anon - "select count(*) from public.referral_codes"
    gives   "a person does not see someone else's referral code" 0 "$db" authenticated "$A" "select count(*) from public.referral_codes"
    gives   "a person sees their own referral code" 1           "$db" authenticated "$B" "select count(*) from public.referral_codes"
    gives   "anyone can ask whether a code exists" t            "$db" anon - "select public.referral_code_exists('bcode')"
    gives   "and gets no for one that does not" f               "$db" anon - "select public.referral_code_exists('NOPE')"
    works   "a person can create their own code, asking for free Pro and earnings" "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id, conversions, total_earnings, is_eligible_for_free_pro) values ('ACODE', '$A', 99, 500, true)"
    owner_sees "and the code is saved with zeroed statistics" "0|0|0.00|f" "$db" "select conversions, pending_conversions, total_earnings, is_eligible_for_free_pro from public.referral_codes where code = 'ACODE'"
    refused "a person cannot create a code for someone else"    "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id) values ('FORB', '$B')"
    gives   "a person cannot raise someone else's referral count" 0 "$db" authenticated "$A" "with changed as (update public.referral_codes set pending_conversions = 50 where code = 'BCODE' returning 1) select count(*) from changed"
    gives   "a person cannot change their own referral statistics" 0 "$db" authenticated "$A" "with changed as (update public.referral_codes set is_eligible_for_free_pro = true where code = 'ACODE' returning 1) select count(*) from changed"
    works   "a person can hold a few codes"                     "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id) values ('A2', '$A'), ('A3', '$A'), ('A4', '$A'), ('A5', '$A')"
    refused "but not more than the limit"                       "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id) values ('A6', '$A')"
    refused "a person cannot record a referral conversion"      "$db" authenticated "$A" "insert into public.referral_conversions (referrer_code, referred_user_id) values ('BCODE', '$C')"
    gives   "a person cannot mark a conversion as converted" 0  "$db" authenticated "$B" "with changed as (update public.referral_conversions set status = 'converted' returning 1) select count(*) from changed"
    # "fresh" is seeded after its migrations ran, so there was nothing for them to clear.
    [ "$db" = "fresh" ] || owner_sees "stored referral emails were cleared" 0 "$db" "select count(*) from public.referral_conversions where referred_user_email is not null"
  fi

  # Tables no build uses
  local table
  for table in affiliates affiliate_conversions waitlist user_profiles usage_snapshots user_devices ai_insights_log; do
    if has "$db" "$table"; then
      hidden "a signed-in person cannot read $table"            "$db" authenticated "$A" "select count(*) from public.$table"
      hidden "a signed-out visitor cannot read $table"          "$db" anon - "select count(*) from public.$table"
      owner_sees "$table is not broadcast in realtime" 0 "$db" "select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename = '$table'"
    fi
  done
  if has "$db" waitlist; then
    refused "a signed-out visitor cannot write to the waitlist" "$db" anon - "insert into public.waitlist (email) values ('x@example.test')"
    works   "the waitlist function (service role) can"          "$db" service_role - "insert into public.waitlist (email) values ('via-function@example.test')"
    owner_sees "waitlist rows were kept" 2 "$db" "select count(*) from public.waitlist"
  fi
  if has "$db" affiliates; then
    owner_sees "affiliate rows were kept" 1 "$db" "select count(*) from public.affiliates"
  fi
  if has "$db" user_profiles; then
    refused "a person cannot mark themselves premium in the old profile table" "$db" authenticated "$A" "update public.user_profiles set is_premium = true where id = '$A'"
  fi
  if has "$db" usage_snapshots; then
    refused "a person cannot fill usage_snapshots"              "$db" authenticated "$A" "insert into public.usage_snapshots (subscription_id, user_id, date) select id, user_id, current_date from public.subscriptions where user_id = '$A' limit 1"
    refused "a person cannot fill ai_insights_log"              "$db" authenticated "$A" "insert into public.ai_insights_log (user_id, insight_type, insight_text) values ('$A', 'unused', 'x')"
  fi

  # The function that summed anyone's spending
  if [ "$(printf "select count(*) from pg_proc where proname = 'calculate_monthly_spend';\n" | admin "$db")" != "0" ]; then
    refused "a signed-out visitor cannot read anyone's monthly spend" "$db" anon - "select public.calculate_monthly_spend('$B')"
    refused "nor can a signed-in person"                        "$db" authenticated "$A" "select public.calculate_monthly_spend('$B')"
  fi

  # Account deletion
  refused "a signed-out visitor cannot call account deletion"   "$db" anon - "select public.delete_my_account()"
  works   "a person can delete their own account"               "$db" authenticated "$D" "select public.delete_my_account()"
  owner_sees "their account, profile and subscriptions are gone" "0|0|0" "$db" "select (select count(*) from auth.users where id = '$D'), (select count(*) from public.profiles where id = '$D'), (select count(*) from public.subscriptions where user_id = '$D')"
  owner_sees "the deletion was logged" 1 "$db" "select count(*) from public.deletion_requests where notes = 'Deleted from the app'"
  owner_sees "nobody else's rows were touched" "3|2" "$db" "select (select count(*) from auth.users), (select count(*) from public.subscriptions)"
}

row_cap_check() {  # the subscription ceiling, proved with a low ceiling so it runs fast
  local db=$1
  printf "drop trigger enforce_row_cap on public.subscriptions;\ncreate trigger enforce_row_cap before insert on public.subscriptions for each row execute function public.enforce_row_cap('user_id', '3');\n" | admin "$db" >/dev/null
  works   "a person can add subscriptions up to the ceiling"    "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount) values ('$A', 'Two', 1), ('$A', 'Three', 1)"
  refused "and is stopped at it"                                "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount) values ('$A', 'Four', 1)"
  works   "the service role is not held to the ceiling"         "$db" service_role - "insert into public.subscriptions (user_id, name, amount) values ('$A', 'Imported', 1)"
}

# ---- run --------------------------------------------------------------------------------------

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1
  docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=localonly "$IMAGE" >/dev/null || { echo "Could not start Postgres. Is Docker running?"; exit 1; }
fi
for _ in $(seq 1 30); do docker exec "$CONTAINER" pg_isready -U postgres >/dev/null 2>&1 && break; sleep 1; done

printf 'Applying %s\n\n' "$(basename "$APPLY")"

for state in "minimal 20260304173000" "old 20260520000001" "oct22 20261022b" "nov6 20261106" "fresh 99999999"; do
  set -- $state
  db=$1
  build "$db" "$2"
  seed "$db"
  [ "$db" = "old" ] && holes "$db"
  if [ "$db" = "oct22" ]; then
    owner_sees "oct22 starts with one person's double rating" 2 "$db" "select count(*) from public.cancel_difficulty_ratings where user_id = '$B' and service_name = 'Netflix'"
  fi
  if [ "$db" != "fresh" ]; then
    for run in first second; do
      if ! out=$(apply_file "$db" "$APPLY"); then
        fail "$db: the APPLY file runs ($run time)" "$(printf '%s' "$out" | grep -m1 ERROR)"
      elif printf '%s' "$out" | grep -q 'NOT OK'; then
        fail "$db: the APPLY file's checklist is all ok ($run time)" "$(printf '%s' "$out" | grep 'NOT OK' | head -1)"
      else
        pass "$db: the APPLY file runs and its checklist is all ok ($run time)"
      fi
    done
  fi
  seed_after "$db"
  checks "$db"
  row_cap_check "$db"
  echo
done

[ "${KEEP:-0}" = "1" ] || docker rm -f "$CONTAINER" >/dev/null 2>&1
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
