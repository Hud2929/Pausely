#!/bin/bash
# Proves Pausely's database rules against a throwaway local Postgres that stands in for Supabase.
# Nothing here touches the real project.
#
#   bash scripts/dbtest/run.sh            every starting state, then the checks
#   KEEP=1 bash scripts/dbtest/run.sh     leave the container running afterwards, to look around
#
# It builds six starting states a real database could be in, applies supabase/APPLY_*.sql twice to
# each (a second run must change nothing and must not fail), verifies exact schema parity between
# `nov6 + APPLY` and `fresh`, and acts as a signed-out visitor, two signed-in people and the
# service role to check what each can and cannot do.
#   minimal  only the first migration
#   old      migrations up to 2026-05-20 (a database that never got the October and November files)
#   oct22    migrations up to 20261022b (ratings exist, but one person could still rate a service twice)
#   nov6     every migration up to 20261106 (including mixed-case + lowercase duplicate ratings!)
#   live     the shape of the real project on 2026-11-11: only the migrations that were ever run
#            there, plus an earlier payment system that is in no migration (live_extras.sql)
#   fresh    every migration in filename order, without the APPLY file
# Needs Docker (Colima is fine). Exits 1 if any check fails.
set -uo pipefail

if ! command -v docker >/dev/null 2>&1 && [ -x "$HOME/.local/bin/docker" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

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

sql_stream() {  # sql_stream <db>   (SQL on stdin, output as a person would see it)
  docker exec -i "$CONTAINER" psql -U postgres -X -v ON_ERROR_STOP=1 -q -d "$1" 2>&1
}

# Everything a rehearsal could leave behind if it were not fully undone.
FINGERPRINT="select md5(coalesce(string_agg(item, ',' order by item), '')) from (
  select 'trigger ' || c.relname || '.' || t.tgname as item from pg_trigger t join pg_class c on c.oid = t.tgrelid where not t.tgisinternal
  union all select 'policy ' || tablename || '.' || policyname from pg_policies
  union all select 'function ' || p.proname || ' ' || md5(p.prosrc) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'
  union all select 'column ' || table_name || '.' || column_name from information_schema.columns where table_schema = 'public'
  union all select 'index ' || indexname from pg_indexes where schemaname = 'public'
  union all select 'grant ' || table_name || ' ' || grantee || ' ' || privilege_type from information_schema.role_table_grants where table_schema = 'public'
  union all select 'realtime ' || tablename from pg_publication_tables where pubname = 'supabase_realtime'
  union all select 'rows ' || c.relname || ' ' || (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from public.%I', c.relname), false, true, '')))[1]::text
            from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r'
) everything"

# Schema-only fingerprint (excludes row counts & whitespace differences in function bodies) for nov6+APPLY vs fresh parity.
SCHEMA_FINGERPRINT="select md5(coalesce(string_agg(item, E'\n' order by item), '')) from (
  select 'trigger ' || c.relname || '.' || t.tgname as item from pg_trigger t join pg_class c on c.oid = t.tgrelid where not t.tgisinternal
  union all select 'policy ' || tablename || '.' || policyname || ' ' || cmd || ' ' || roles::text from pg_policies where schemaname = 'public'
  union all select 'function ' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' || ' ' || coalesce(array_to_string(p.proconfig, ','), '')
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'
  union all select 'column ' || table_name || '.' || column_name || ' ' || data_type from information_schema.columns where table_schema = 'public'
  union all select 'index ' || indexname from pg_indexes where schemaname = 'public'
  union all select 'constraint ' || conrelid::regclass::text || '.' || conname from pg_constraint c join pg_namespace n on n.oid = c.connamespace where n.nspname = 'public' and contype = 'c'
  union all select 'grant ' || table_name || ' ' || grantee || ' ' || privilege_type from information_schema.role_table_grants where table_schema = 'public'
  union all select 'realtime ' || tablename from pg_publication_tables where pubname = 'supabase_realtime'
) schema_items"

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

build_live() {  # what python3 scripts/db_apply.py state showed on the real project
  local db=$1 name out
  printf 'drop database if exists %s;\ncreate database %s;\n' "$db" "$db" | docker exec -i "$CONTAINER" psql -U postgres -X -q -d postgres >/dev/null 2>&1
  apply_file "$db" "$STUB" >/dev/null
  for name in 20260304173000_fix_and_create_all_tables.sql 20260305000000_add_usage_ai_tables.sql \
              20260507000000_add_waitlist_and_affiliates.sql 20261005_age_consent.sql \
              20261007_restore_subscriptions_amount_column.sql 20261008_add_missing_subscription_columns.sql; do
    if ! out=$(apply_file "$db" "$MIGRATIONS/$name" -1); then
      fail "$db: migration $name applies" "$(printf '%s' "$out" | grep -m1 ERROR)"
    fi
  done
  if ! out=$(apply_file "$db" "$ROOT/scripts/dbtest/live_extras.sql" -1); then
    fail "$db: the earlier payment system's objects are created" "$(printf '%s' "$out" | grep -m1 ERROR)"
  fi
}

seed() {  # rows that exist before the fix is applied, wherever the table exists
  admin "$1" >/dev/null <<SQL
insert into auth.users (id, email) values
  ('$A', 'a@example.test'), ('$B', 'b@example.test'), ('$C', 'c@example.test'), ('$D', 'd@example.test');
insert into public.profiles (id, display_name, is_pro) values ('$A', 'A', false), ('$B', 'B', true), ('$D', 'D', false)
  on conflict (id) do update set display_name = excluded.display_name, is_pro = excluded.is_pro;
delete from public.profiles where id = '$C';
do \$\$
declare amount_column text := (select column_name from information_schema.columns
    where table_schema = 'public' and table_name = 'subscriptions' and column_name in ('amount', 'cost') limit 1);
begin
  execute format('insert into public.subscriptions (user_id, name, %I) values (\$1, ''Netflix'', 15.49), (\$2, ''Spotify'', 9.99), (\$3, ''Hulu'', 7.99)', amount_column)
    using '$A'::uuid, '$B'::uuid, '$D'::uuid;
  if to_regclass('public.referral_codes') is not null then
    insert into public.referral_codes (code, referrer_user_id, conversions) values ('BCODE', '$B', 2), ('DCODE', '$D', 0);
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
  if to_regclass('public.user_subscriptions') is not null then
    insert into public.user_subscriptions (user_id, tier, status, payment_failed, payment_failed_at)
      values ('$B', 'pro', 'active', true, now() - interval '2 days');
  end if;
  if to_regclass('public.cancel_difficulty_ratings') is not null then
    -- Legacy states seed mixed-case duplicates:
    --   oct22 (no unique index): two 'Netflix' rows
    --   nov6  (unique index already installed!): both 'Netflix' (old client) AND 'netflix' (new client) -> proves P0-1 dedup-before-UPDATE!
    --   fresh (slug CHECK already exists): canonical 'netflix'
    if exists (select 1 from pg_constraint where conname = 'cancel_difficulty_service_slug') then
      insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('netflix', 4, '$B');
    elsif exists (select 1 from pg_indexes where indexname = 'cancel_difficulty_one_per_user') then
      insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id, created_at)
        values ('Netflix', 2, '$B', now() - interval '2 days');
      insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id)
        values ('netflix', 4, '$B');
    else
      insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id, created_at)
        values ('Netflix', 2, '$B', now() - interval '2 days');
      insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id)
        values ('Netflix', 4, '$B');
    end if;
  end if;
end \$\$;
SQL
}

seed_after() {  # states that had no ratings table before the fix get the same single rating now
  admin "$1" >/dev/null <<SQL
insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id)
select 'netflix', 4, '$B'
where not exists (select 1 from public.cancel_difficulty_ratings where user_id = '$B' and service_name = 'netflix');
SQL
}

# ---- what an unfixed database allows (run on "old"; each line passing means the hole is real) ----

holes() {
  local db=$1
  printf '  %s before the fix: these must succeed, or the checks below prove nothing\n' "$db"
  END=rollback works  "a person can mark themselves Pro"            "$db" authenticated "$A" "update public.profiles set is_pro = true where id = '$A' returning 1"
  END=rollback gives  "a signed-out visitor can read affiliate payment details" "account 000-111" "$db" anon - "select payment_details from public.affiliates"
  END=rollback gives  "a signed-out visitor can list referral codes" 2 "$db" anon - "select count(*) from public.referral_codes"
  END=rollback works  "a signed-out visitor can read anyone's monthly spend" "$db" anon - "select public.calculate_monthly_spend('$B')"
  END=rollback works  "a signed-out visitor can write to the waitlist" "$db" anon - "insert into public.waitlist (email) values ('x@example.test')"
  END=rollback gives  "a person can give their referral code free-Pro status" t "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id, is_eligible_for_free_pro) values ('ACODE', '$A', true) returning is_eligible_for_free_pro"
}

holes_live() {
  local db=$1
  printf '  %s before the fix: the earlier payment views, which no migration knows about\n' "$db"
  END=rollback gives  "a signed-out visitor can read a payer's email through an old view" "b@example.test" "$db" anon - "select user_email from public.payment_failures"
  END=rollback gives  "and can list every active payer" 1 "$db" anon - "select count(*) from public.active_subscriptions"
  END=rollback works  "a person can mark themselves Pro"            "$db" authenticated "$A" "update public.profiles set is_pro = true where id = '$A' returning 1"
  END=rollback gives  "a signed-out visitor can read affiliate payment details" "account 000-111" "$db" anon - "select payment_details from public.affiliates"
}

# ---- what a fixed database allows -------------------------------------------------------------

checks() {
  local db=$1
  printf '  %s after the fix\n' "$db"

  # Pro & Age Consent integrity
  refused "a person cannot mark themselves Pro"                 "$db" authenticated "$A" "update public.profiles set is_pro = true where id = '$A'"
  refused "a person cannot change their Pro tier"               "$db" authenticated "$A" "update public.profiles set pro_tier = 'lifetime' where id = '$A'"
  works   "a person can still edit their own profile"           "$db" authenticated "$A" "update public.profiles set display_name = 'New name' where id = '$A'"
  works   "a granted-Pro person can edit their profile"         "$db" authenticated "$B" "update public.profiles set display_name = 'B again' where id = '$B'"
  owner_sees "and keeps Pro afterwards" t "$db" "select is_pro from public.profiles where id = '$B'"
  works   "the app's age-consent upsert works"                  "$db" authenticated "$A" "insert into public.profiles (id, age_confirmed_at, age_minimum_met, age_minimum_required, consent_policy_version, consent_app_version) values ('$A', now(), true, 16, '2026-10', '1.0.3') on conflict (id) do update set age_confirmed_at = excluded.age_confirmed_at, age_minimum_met = excluded.age_minimum_met, age_minimum_required = excluded.age_minimum_required, consent_policy_version = excluded.consent_policy_version, consent_app_version = excluded.consent_app_version"
  works   "the app's age-consent upsert works on a granted-Pro user" "$db" authenticated "$B" "insert into public.profiles (id, age_confirmed_at, age_minimum_met, age_minimum_required, consent_policy_version, consent_app_version) values ('$B', now(), true, 16, '2026-11', '1.0.4') on conflict (id) do update set age_confirmed_at = excluded.age_confirmed_at, age_minimum_met = excluded.age_minimum_met, age_minimum_required = excluded.age_minimum_required, consent_policy_version = excluded.consent_policy_version, consent_app_version = excluded.consent_app_version"
  owner_sees "and the Pro user keeps Pro with age consent saved" "t|t" "$db" "select is_pro, age_minimum_met from public.profiles where id = '$B'"
  refused "a person cannot erase their confirmed age-consent record" "$db" authenticated "$A" "update public.profiles set age_confirmed_at = null, age_minimum_met = null where id = '$A'"
  refused "a person cannot backdate their confirmed age-consent timestamp" "$db" authenticated "$A" "update public.profiles set age_confirmed_at = '2024-02-01T00:00:00Z' where id = '$A'"
  refused "a person cannot downgrade their confirmed minimum age" "$db" authenticated "$A" "update public.profiles set age_minimum_required = 15 where id = '$A'"
  refused "oversized profile display_name (>120 chars) is rejected" "$db" authenticated "$A" "update public.profiles set display_name = repeat('x', 121) where id = '$A'"
  admin "$db" >/dev/null <<< "delete from public.profiles where id = '$C';"
  refused "forged pre-2024 age_confirmed_at on insert is rejected" "$db" authenticated "$C" "insert into public.profiles (id, age_confirmed_at, age_minimum_met, age_minimum_required) values ('$C', '1970-01-01T00:00:00Z', true, 16)"
  works   "a new person can create their profile, asking for Pro and hijacked fields" "$db" authenticated "$C" "insert into public.profiles (id, display_name, is_pro, pro_tier, subscription_count_limit, affiliate_code, attributed_at) values ('$C', 'C', true, 'lifetime', 999, 'HIJACK', now())"
  owner_sees "and the row is saved without Pro or hijacked server fields" "f||5||" "$db" "select is_pro, pro_tier, subscription_count_limit, affiliate_code, attributed_at from public.profiles where id = '$C'"
  gives   "a person cannot edit someone else's profile" 0       "$db" authenticated "$A" "with changed as (update public.profiles set display_name = 'hacked' where id = '$B' returning 1) select count(*) from changed"
  gives   "a person cannot read someone else's profile" 0       "$db" authenticated "$A" "select count(*) from public.profiles where id = '$B'"
  hidden  "a signed-out visitor sees no profiles"               "$db" anon - "select count(*) from public.profiles"
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
  hidden  "a signed-out visitor sees no subscriptions"          "$db" anon - "select count(*) from public.subscriptions"
  refused "a signed-out visitor cannot add a subscription"      "$db" anon - "insert into public.subscriptions (user_id, name, amount) values ('$A', 'Planted', 1)"

  # The three requests the app's sync queue makes (SyncQueue.swift), as the API runs them.
  local synced=5eed0000-0000-4000-8000-000000000001 theirs
  local upsert="insert into public.subscriptions (id, user_id, name, amount) values ('%s', '$A', 'Synced', %s) on conflict (id) do update set user_id = excluded.user_id, name = excluded.name, amount = excluded.amount"
  works   "the app's add creates the subscription"              "$db" authenticated "$A" "$(printf "$upsert" "$synced" 5)"
  works   "the same add sent again is accepted"                 "$db" authenticated "$A" "$(printf "$upsert" "$synced" 6)"
  owner_sees "and is still one subscription, with the later copy" "1|6" "$db" "select count(*), max(amount)::int from public.subscriptions where id = '$synced'"
  theirs=$(printf "select id from public.subscriptions where user_id = '$B' limit 1;\n" | admin "$db")
  refused "the app's add cannot take over someone else's subscription" "$db" authenticated "$A" "$(printf "$upsert" "$theirs" 1)"
  owner_sees "which still belongs to them, unchanged" "$B|Spotify" "$db" "select user_id, name from public.subscriptions where id = '$theirs'"
  gives   "the app's edit of a subscription another device deleted changes nothing, without an error" 0 "$db" authenticated "$A" "with changed as (update public.subscriptions set amount = 9 where id = '5eed0000-0000-4000-8000-00000000dead' returning 1) select count(*) from changed"
  works   "the app's delete removes it"                         "$db" authenticated "$A" "delete from public.subscriptions where id = '$synced'"
  works   "the same delete sent again is not an error"          "$db" authenticated "$A" "delete from public.subscriptions where id = '$synced'"
  owner_sees "and it is gone" 0 "$db" "select count(*) from public.subscriptions where id = '$synced'"

  # Cancel-difficulty ratings (canonical slug + >= 3 ratings privacy threshold)
  owner_sees "an earlier double rating was normalized and reduced to the latest one" "1|4" "$db" "select count(*), max(difficulty_rating) from public.cancel_difficulty_ratings where user_id = '$B' and service_name = 'netflix'"
  refused "an unnormalized or injected service name is rejected" "$db" authenticated "$A" "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('Netflix! <script>', 5, '$A')"
  works   "a person can rate a service"                         "$db" authenticated "$A" "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('netflix', 5, '$A')"
  refused "but not twice"                                       "$db" authenticated "$A" "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('netflix', 1, '$A')"
  refused "a person cannot rate under someone else's id"        "$db" authenticated "$A" "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('hulu', 1, '$B')"
  refused "a signed-out visitor cannot rate"                    "$db" anon - "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating) values ('hulu', 1)"
  hidden  "nobody can read individual ratings"                  "$db" authenticated "$A" "select count(*) from public.cancel_difficulty_ratings"
  gives   "fewer than 3 ratings are not exposed publicly" 0     "$db" anon - "select count(*) from public.service_difficulty_scores where service_name = 'netflix'"
  works   "a third person can rate the service"                 "$db" authenticated "$C" "insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('netflix', 3, '$C')"
  gives   "once 3+ ratings exist anyone can read the average" "netflix|4.0|3" "$db" anon - "select service_name, avg_difficulty, rating_count from public.service_difficulty_scores where service_name = 'netflix'"

  # Settings (including cross-user UPDATE & DELETE isolation)
  works   "a person can save their settings row"                "$db" authenticated "$A" "insert into public.user_settings (user_id, referral_discount_used) values ('$A', true) on conflict (user_id) do update set referral_discount_used = excluded.referral_discount_used"
  gives   "a person cannot read someone else's settings" 0      "$db" authenticated "$B" "select count(*) from public.user_settings where user_id = '$A'"
  refused "a person cannot write someone else's settings"       "$db" authenticated "$B" "insert into public.user_settings (user_id) values ('$C')"
  gives   "a person cannot update someone else's settings" 0    "$db" authenticated "$B" "with c as (update public.user_settings set referral_discount_used = false where user_id = '$A' returning 1) select count(*) from c"
  gives   "a person cannot delete someone else's settings" 0    "$db" authenticated "$B" "with c as (delete from public.user_settings where user_id = '$A' returning 1) select count(*) from c"

  # The deletion log & edge rate limits
  hidden  "nobody can read the deletion log"                    "$db" authenticated "$A" "select count(*) from public.deletion_requests"
  refused "nobody can write to the deletion log"                "$db" authenticated "$A" "insert into public.deletion_requests (user_id) values ('$A')"
  refused "a signed-in person cannot read edge_rate_limits"     "$db" authenticated "$A" "select count(*) from public.edge_rate_limits"
  refused "a visitor cannot read edge_rate_limits"              "$db" anon - "select count(*) from public.edge_rate_limits"
  refused "a signed-in person cannot call consume_rate_limit"   "$db" authenticated "$A" "select public.consume_rate_limit('k', 2, 60)"
  refused "a visitor cannot call consume_rate_limit"            "$db" anon - "select public.consume_rate_limit('k', 2, 60)"
  gives   "service role consume_rate_limit allows hit 1 of 2" t "$db" service_role - "select public.consume_rate_limit('test:rl', 2, 3600)"
  gives   "service role consume_rate_limit allows hit 2 of 2" t "$db" service_role - "select public.consume_rate_limit('test:rl', 2, 3600)"
  gives   "service role consume_rate_limit blocks hit 3 of 2" f "$db" service_role - "select public.consume_rate_limit('test:rl', 2, 3600)"

  # Referral codes
  if has "$db" referral_codes; then
    hidden  "a signed-out visitor cannot list referral codes"   "$db" anon - "select count(*) from public.referral_codes"
    gives   "a person does not see someone else's referral code" 0 "$db" authenticated "$A" "select count(*) from public.referral_codes"
    gives   "a person sees their own referral code" 1           "$db" authenticated "$B" "select count(*) from public.referral_codes"
    gives   "anyone can ask whether a code exists" t            "$db" anon - "select public.referral_code_exists('bcode')"
    gives   "and gets no for one that does not" f               "$db" anon - "select public.referral_code_exists('NOPE')"
    refused "oversized referral code (>64 chars) is rejected"   "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id) values (repeat('X', 65), '$A')"
    works   "a person can create their own code, asking for free Pro and earnings" "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id, conversions, total_earnings, is_eligible_for_free_pro) values ('ACODE', '$A', 99, 500, true)"
    owner_sees "and the code is saved with zeroed statistics" "0|0|0.00|f" "$db" "select conversions, pending_conversions, total_earnings, is_eligible_for_free_pro from public.referral_codes where code = 'ACODE'"
    refused "a person cannot create a code for someone else"    "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id) values ('FORB', '$B')"
    gives   "a person cannot raise someone else's referral count" 0 "$db" authenticated "$A" "with changed as (update public.referral_codes set pending_conversions = 50 where code = 'BCODE' returning 1) select count(*) from changed"
    gives   "a person cannot change their own referral statistics" 0 "$db" authenticated "$A" "with changed as (update public.referral_codes set is_eligible_for_free_pro = true where code = 'ACODE' returning 1) select count(*) from changed"
    works   "a person can hold a few codes"                     "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id) values ('A2', '$A'), ('A3', '$A'), ('A4', '$A'), ('A5', '$A')"
    refused "but not more than the limit"                       "$db" authenticated "$A" "insert into public.referral_codes (code, referrer_user_id) values ('A6', '$A')"
    refused "a person cannot record a referral conversion"      "$db" authenticated "$A" "insert into public.referral_conversions (referrer_code, referred_user_id) values ('BCODE', '$C')"
    gives   "a person cannot mark a conversion as converted" 0  "$db" authenticated "$B" "with changed as (update public.referral_conversions set status = 'converted' returning 1) select count(*) from changed"
    [ "$db" = "fresh" ] || owner_sees "stored referral emails were cleared" 0 "$db" "select count(*) from public.referral_conversions where referred_user_email is not null"
  fi

  # Tables & compliance views no build uses
  local table
  for table in affiliates affiliate_conversions waitlist user_profiles usage_snapshots user_devices ai_insights_log alternatives tracked_trials profiles_missing_age_consent; do
    if has "$db" "$table"; then
      hidden "a signed-in person cannot read $table"            "$db" authenticated "$A" "select count(*) from public.$table"
      hidden "a signed-out visitor cannot read $table"          "$db" anon - "select count(*) from public.$table"
      owner_sees "$table is not broadcast in realtime" 0 "$db" "select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename = '$table'"
    fi
  done

  # New multi-device sync tables (lifecycle_events, pause_plans) and atomic App Store entitlements RPC
  local ev_id=6eed0000-0000-4000-8000-000000000001
  works   "a person can save their own lifecycle event"         "$db" authenticated "$A" "insert into public.lifecycle_events (id, user_id, subscription_id, subscription_name, kind, occurred_at, amount, currency, frequency) values ('$ev_id', '$A', '$synced', 'Netflix', 'cancelled', now(), 8.995, 'USD', 'monthly')"
  gives   "lifecycle_events preserves sub-cent precision on sync" "8.995000" "$db" authenticated "$A" "select amount::text from public.lifecycle_events where id = '$ev_id'"
  gives   "a person sees their own lifecycle events" 1          "$db" authenticated "$A" "select count(*) from public.lifecycle_events"
  gives   "a person cannot read someone else's lifecycle events" 0 "$db" authenticated "$B" "select count(*) from public.lifecycle_events"
  gives   "a person cannot update someone else's lifecycle events" 0 "$db" authenticated "$B" "with c as (update public.lifecycle_events set amount = 0 where id = '$ev_id' returning 1) select count(*) from c"
  gives   "a person cannot delete someone else's lifecycle events" 0 "$db" authenticated "$B" "with c as (delete from public.lifecycle_events where id = '$ev_id' returning 1) select count(*) from c"
  refused "a person cannot insert a lifecycle event for someone else" "$db" authenticated "$A" "insert into public.lifecycle_events (id, user_id, subscription_id, subscription_name, kind, occurred_at, amount, currency, frequency) values ('6eed0000-0000-4000-8000-000000000002', '$B', '$synced', 'Netflix', 'cancelled', now(), 15.99, 'USD', 'monthly')"

  works   "a person can save their own pause plan with savings_since" "$db" authenticated "$A" "insert into public.pause_plans (user_id, subscription_ids, started_on, savings_since) values ('$A', array['$synced'::uuid], '2026-04-01T12:00:00Z', '2026-01-01T12:00:00Z') on conflict (user_id) do update set subscription_ids = excluded.subscription_ids, savings_since = excluded.savings_since"
  gives   "pause_plans round-trips savings_since cleanly" "2026-01-01T12:00:00Z" "$db" authenticated "$A" "select to_char(savings_since at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') from public.pause_plans where user_id = '$A'"
  works   "a pause plan update can carry a client LWW timestamp" "$db" authenticated "$A" "update public.pause_plans set ended_at = '2026-01-02T03:04:05Z', updated_at = '2026-01-02T03:04:05Z' where user_id = '$A'"
  gives   "pause_plans preserves the client updated_at timestamp on update" "2026-01-02T03:04:05Z" "$db" authenticated "$A" "select to_char(updated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') from public.pause_plans where user_id = '$A'"
  refused "pause_plans rejects arrays larger than 50 ids"       "$db" authenticated "$A" "update public.pause_plans set subscription_ids = array(select gen_random_uuid() from generate_series(1, 51)) where user_id = '$A'"
  gives   "a person cannot read someone else's pause plan" 0    "$db" authenticated "$B" "select count(*) from public.pause_plans"
  gives   "a person cannot update someone else's pause plan" 0  "$db" authenticated "$B" "with c as (update public.pause_plans set ended_at = null where user_id = '$A' returning 1) select count(*) from c"
  gives   "a person cannot delete someone else's pause plan" 0  "$db" authenticated "$B" "with c as (delete from public.pause_plans where user_id = '$A' returning 1) select count(*) from c"
  refused "a person cannot write someone else's pause plan"     "$db" authenticated "$B" "insert into public.pause_plans (user_id, subscription_ids, started_on) values ('$A', array['$synced'::uuid], now())"

  # App Store entitlements + atomic replay-safe RPC
  refused "a signed-in person cannot read app_store_entitlements" "$db" authenticated "$A" "select count(*) from public.app_store_entitlements"
  refused "a visitor cannot read app_store_entitlements"        "$db" anon - "select count(*) from public.app_store_entitlements"
  refused "a signed-in person cannot call upsert_app_store_entitlement" "$db" authenticated "$A" "select * from public.upsert_app_store_entitlement('tx-h', '$A', 'com.pausely.premium.annual', 'active', 'Production', true, now(), 'SUBSCRIBED', now())"
  refused "a visitor cannot call upsert_app_store_entitlement"  "$db" anon - "select * from public.upsert_app_store_entitlement('tx-h', '$A', 'com.pausely.premium.annual', 'active', 'Production', true, now(), 'SUBSCRIBED', now())"
  gives   "atomic ASSN RPC inserts initial trial entitlement" "t|trial" "$db" service_role - "select applied, current_status from public.upsert_app_store_entitlement('tx-1', '$A', 'com.pausely.premium.annual', 'trial', 'Production', true, '2026-12-01T00:00:00Z', 'SUBSCRIBED:INITIAL_BUY', '2026-11-01T00:00:00Z')"
  gives   "atomic ASSN RPC preserves user_id on renewal omitting user_id" "t|active" "$db" service_role - "select applied, current_status from public.upsert_app_store_entitlement('tx-1', null, 'com.pausely.premium.annual', 'active', 'Production', null, '2027-12-01T00:00:00Z', 'DID_RENEW', '2026-11-10T00:00:00Z')"
  owner_sees "user_id and will_auto_renew were preserved" "$A|t" "$db" "select user_id, will_auto_renew from public.app_store_entitlements where original_transaction_id = 'tx-1'"
  gives   "atomic ASSN RPC records newer refund and clears auto_renew" "t|refunded" "$db" service_role - "select applied, current_status from public.upsert_app_store_entitlement('tx-1', null, 'com.pausely.premium.annual', 'refunded', 'Production', null, '2027-12-01T00:00:00Z', 'REFUND', '2026-11-20T00:00:00Z')"
  gives   "atomic ASSN RPC rejects stale out-of-order replay without reverting refund" "f|refunded" "$db" service_role - "select applied, current_status from public.upsert_app_store_entitlement('tx-1', null, 'com.pausely.premium.annual', 'active', 'Production', true, '2027-12-01T00:00:00Z', 'DID_RENEW', '2026-11-15T00:00:00Z')"
  owner_sees "refunded status and will_auto_renew=false held against stale replay" "refunded|f" "$db" "select status, will_auto_renew from public.app_store_entitlements where original_transaction_id = 'tx-1'"
  gives   "atomic ASSN RPC falls back to user_id=null on deleted-user FK" "t|refunded" "$db" service_role - "select applied, current_status from public.upsert_app_store_entitlement('tx-fk', '99999999-0000-4000-8000-000000000099', 'com.pausely.premium.monthly', 'refunded', 'Production', false, null, 'REFUND', '2026-11-20T00:00:00Z')"
  owner_sees "and stored tx-fk with null user_id" "t" "$db" "select user_id is null from public.app_store_entitlements where original_transaction_id = 'tx-fk'"

  # Subscriptions precision & storage-DoS checks
  works   "a person can save high-denomination and 3-decimal amounts" "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount, currency, notes, payment_method, split_count) values ('$A', 'IDR Plan', 1500000000, 'IDR', 'Split with roommate', 'Apple Card', 1), ('$A', 'KWD Plan', 1.255, 'KWD', null, null, 1)"
  gives   "high-denomination and 3-decimal amounts round-trip cleanly" "1500000000.0000|1.2550" "$db" authenticated "$A" "select max(amount) filter (where name = 'IDR Plan') || '|' || max(amount) filter (where name = 'KWD Plan') from public.subscriptions where user_id = '$A'"
  works   "and delete them cleanly afterwards" "$db" authenticated "$A" "delete from public.subscriptions where user_id = '$A' and name in ('IDR Plan', 'KWD Plan')"
  refused "negative subscription amounts are rejected"          "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount) values ('$A', 'Bad Neg', -1)"
  refused "oversized subscription notes (>2000 chars) are rejected" "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount, notes) values ('$A', 'Huge Notes', 10, repeat('x', 2001))"
  refused "split count must be between 1 and 20"                "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount, split_count) values ('$A', 'Bad Split', 10, 0)"
  refused "negative notify_before_days is rejected"             "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount, notify_before_days) values ('$A', 'Bad Days', 10, -1)"
  refused "excessive notify_before_days (>365) is rejected"     "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount, notify_before_days) values ('$A', 'Bad Days', 10, 400)"
  if [ "$(printf "select count(*) from information_schema.columns where table_schema='public' and table_name='subscriptions' and column_name='tags';\n" | admin "$db")" = "1" ]; then
    refused "oversized tags[] element (>1024 bytes) is rejected" "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount, tags) values ('$A', 'Huge Tag', 10, array[repeat('z', 1500)])"
  fi
  owner_sees "unused realtime broadcasts are removed" 0 "$db" "select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename in ('subscriptions', 'referral_codes', 'referral_conversions')"

  # Waitlist + atomic join_waitlist RPC
  if has "$db" waitlist; then
    refused "a signed-out visitor cannot write to the waitlist" "$db" anon - "insert into public.waitlist (email) values ('x@example.test')"
    refused "a signed-out visitor cannot call join_waitlist"    "$db" anon - "select public.join_waitlist('x@example.test', 'other', 10)"
    refused "a signed-in person cannot call join_waitlist"      "$db" authenticated "$A" "select public.join_waitlist('x@example.test', 'other', 10)"
    gives   "service role join_waitlist inserts a new address" "inserted" "$db" service_role - "select public.join_waitlist('via-rpc@example.test', 'tiktok', 10)"
    gives   "service role join_waitlist treats duplicates idempotently" "existing" "$db" service_role - "select public.join_waitlist('via-rpc@example.test', 'tiktok', 10)"
    gives   "service role join_waitlist enforces atomic hourly ceiling" "rate_limited" "$db" service_role - "select public.join_waitlist('over-cap@example.test', 'tiktok', 2)"
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

  # The earlier payment system (on the live project only)
  if has "$db" user_subscriptions; then
    local object
    for object in orders user_subscriptions active_subscriptions expiring_subscriptions payment_failures; do
      refused "a signed-out visitor cannot read $object"        "$db" anon - "select count(*) from public.$object"
      refused "a signed-in person cannot read $object"          "$db" authenticated "$A" "select count(*) from public.$object"
    done
    gives   "the service role still reads the old payment views" 1 "$db" service_role - "select count(*) from public.payment_failures"
    works   "a payment recorded by the service role still marks the account Pro" "$db" service_role - "insert into public.user_subscriptions (user_id, tier, status) values ('$A', 'pro', 'active')"
    owner_sees "and the account is Pro" "t|pro" "$db" "select is_pro, pro_tier from public.profiles where id = '$A'"
    works   "an ended payment takes Pro away again"             "$db" service_role - "update public.user_subscriptions set status = 'ended' where user_id = '$A'"
    owner_sees "and the account is no longer Pro" "f|" "$db" "select is_pro, pro_tier from public.profiles where id = '$A'"
  fi

  # Legacy calculate_monthly_spend is completely removed
  owner_sees "legacy calculate_monthly_spend function is removed" 0 "$db" "select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'calculate_monthly_spend'"

  # Automatic auth.users -> profiles trigger
  local E=eeeeeeee-0000-4000-8000-000000000005 out_e
  if out_e=$(printf "insert into auth.users (id, email) values ('%s', 'e@example.test');\n" "$E" | admin "$db"); then
    pass "a new auth user triggers profile creation"
  else
    fail "a new auth user triggers profile creation" "$(printf '%s' "$out_e" | tail -1)"
  fi
  owner_sees "their profile exists and is not Pro" "1|f|e@example.test" "$db" "select count(*), bool_or(is_pro), max(email) from public.profiles where id = '$E'"
  if out_e=$(printf "delete from auth.users where id = '%s';\n" "$E" | admin "$db"); then
    pass "cleanup test user E"
  else
    fail "cleanup test user E" "$(printf '%s' "$out_e" | tail -1)"
  fi

  # Comprehensive Account Deletion (every user table + waitlist by email & converted_user_id + SET NULL anonymization)
  works   "user D has lifecycle history, pause plan, settings, and rating before deleting" "$db" authenticated "$D" "insert into public.lifecycle_events (id, user_id, subscription_id, subscription_name, kind, occurred_at, amount, currency, frequency) values ('6eed0000-0000-4000-8000-000000000009', '$D', '6eed0000-0000-4000-8000-000000000010', 'Hulu', 'cancelled', now(), 7.99, 'USD', 'monthly'); insert into public.pause_plans (user_id, subscription_ids, started_on, ended_at) values ('$D', array['6eed0000-0000-4000-8000-000000000010'::uuid], now(), null); insert into public.user_settings (user_id, referral_discount_used) values ('$D', true); insert into public.cancel_difficulty_ratings (service_name, difficulty_rating, user_id) values ('hulu', 3, '$D')"
  works   "user D has an App Store entitlement row" "$db" service_role - "select * from public.upsert_app_store_entitlement('tx-d', '$D', 'com.pausely.premium.monthly', 'active', 'Production', true, '2027-01-01T00:00:00Z', 'SUBSCRIBED', '2026-11-01T00:00:00Z')"
  if has "$db" waitlist; then
    admin "$db" >/dev/null <<< "insert into public.waitlist (email) values ('D@example.test'); insert into public.waitlist (email, converted_user_id) values ('other-d@example.test', '$D');"
  fi
  refused "a signed-out visitor cannot call account deletion"   "$db" anon - "select public.delete_my_account()"
  works   "a person can delete their own account"               "$db" authenticated "$D" "select public.delete_my_account()"
  owner_sees "their account, profile, subscriptions, lifecycle events, pause plan and settings are gone" "0|0|0|0|0|0" "$db" "select (select count(*) from auth.users where id = '$D'), (select count(*) from public.profiles where id = '$D'), (select count(*) from public.subscriptions where user_id = '$D'), (select count(*) from public.lifecycle_events where user_id = '$D'), (select count(*) from public.pause_plans where user_id = '$D'), (select count(*) from public.user_settings where user_id = '$D')"
  owner_sees "their rating and entitlement were anonymized (user_id set null)" "1|1" "$db" "select (select count(*) from public.cancel_difficulty_ratings where service_name = 'hulu' and user_id is null), (select count(*) from public.app_store_entitlements where original_transaction_id = 'tx-d' and user_id is null)"
  if has "$db" waitlist; then
    owner_sees "their waitlist rows (by email and converted_user_id) were erased while others stayed" "0|2" "$db" "select (select count(*) from public.waitlist where lower(email) in ('d@example.test', 'other-d@example.test') or converted_user_id = '$D'), (select count(*) from public.waitlist)"
  fi
  if has "$db" referral_codes; then
    owner_sees "their referral codes were cascaded away" 0 "$db" "select count(*) from public.referral_codes where referrer_user_id = '$D'"
  fi
  owner_sees "the deletion was logged" 1 "$db" "select count(*) from public.deletion_requests where notes = 'Deleted from the app'"
  owner_sees "nobody else's rows were touched" "3|2" "$db" "select (select count(*) from auth.users), (select count(*) from public.subscriptions)"
}

row_cap_check() {  # subscription ceiling (including idempotent upsert at cap) + lifecycle_events retention pruning
  local db=$1
  local sub_two=5eed0000-0000-4000-8000-000000000022
  printf "drop trigger enforce_row_cap on public.subscriptions;\ncreate trigger enforce_row_cap before insert on public.subscriptions for each row execute function public.enforce_row_cap('user_id', '3');\n" | admin "$db" >/dev/null
  works   "a person can add subscriptions up to the ceiling"    "$db" authenticated "$A" "insert into public.subscriptions (id, user_id, name, amount) values ('$sub_two', '$A', 'Two', 1), (gen_random_uuid(), '$A', 'Three', 1)"
  refused "and is stopped at it"                                "$db" authenticated "$A" "insert into public.subscriptions (user_id, name, amount) values ('$A', 'Four', 1)"
  works   "an idempotent UPSERT on an existing row succeeds even at the ceiling" "$db" authenticated "$A" "insert into public.subscriptions (id, user_id, name, amount) values ('$sub_two', '$A', 'Two Updated', 2) on conflict (id) do update set name = excluded.name, amount = excluded.amount"
  works   "the service role is not held to the ceiling"         "$db" service_role - "insert into public.subscriptions (user_id, name, amount) values ('$A', 'Imported', 1)"

  # Lifecycle events rolling retention pruning (proved with keep_limit=2 so it runs fast)
  printf "drop trigger prune_lifecycle_events_retention on public.lifecycle_events;\ncreate trigger prune_lifecycle_events_retention after insert on public.lifecycle_events for each row execute function public.prune_lifecycle_events_retention('2');\n" | admin "$db" >/dev/null
  works   "lifecycle_events accepts new rows and prunes oldest past retention window" "$db" authenticated "$A" "insert into public.lifecycle_events (id, user_id, subscription_id, subscription_name, kind, occurred_at, amount, currency, frequency) values ('6eed0000-0000-4000-8000-000000000021', '$A', '$sub_two', 'Oldest', 'added', '2026-01-01T00:00:00Z', 5, 'USD', 'monthly'), ('6eed0000-0000-4000-8000-000000000022', '$A', '$sub_two', 'Newest', 'renewed', '2026-12-01T00:00:00Z', 5, 'USD', 'monthly')"
  owner_sees "only the newest 2 lifecycle events are retained (never bricks at 5,000)" "2|0" "$db" "select count(*), count(*) filter (where subscription_name = 'Oldest') from public.lifecycle_events where user_id = '$A'"
}

# ---- run --------------------------------------------------------------------------------------

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1
  docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=localonly "$IMAGE" >/dev/null || { echo "Could not start Postgres. Is Docker running?"; exit 1; }
fi
# Asked over TCP: while the image sets itself up it runs a first server on the socket only, then
# restarts, and a state built in that gap is lost (the "minimal" state failed that way on a cold start).
for _ in $(seq 1 60); do docker exec "$CONTAINER" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1 && break; sleep 1; done

printf 'Applying %s\n\n' "$(basename "$APPLY")"

NOV6_SCHEMA=""
FRESH_SCHEMA=""

for state in "minimal 20260304173000" "old 20260520000001" "oct22 20261022b" "nov6 20261106" "live -" "fresh 99999999"; do
  set -- $state
  db=$1
  if [ "$db" = "live" ]; then build_live "$db"; else build "$db" "$2"; fi
  seed "$db"
  [ "$db" = "old" ] && holes "$db"
  [ "$db" = "live" ] && holes_live "$db"
  if [ "$db" = "oct22" ]; then
    owner_sees "oct22 starts with one person's double rating" 2 "$db" "select count(*) from public.cancel_difficulty_ratings where user_id = '$B' and service_name = 'Netflix'"
  fi
  if [ "$db" = "nov6" ]; then
    owner_sees "nov6 starts with mixed-case 'Netflix' and 'netflix' duplicates under unique index" 2 "$db" "select count(*) from public.cancel_difficulty_ratings where user_id = '$B' and lower(service_name) = 'netflix'"
  fi
  if [ "$db" != "fresh" ]; then
    before=$(printf '%s;\n' "$FINGERPRINT" | admin "$db")
    out=$(python3 "$ROOT/scripts/db_apply.py" wrap rehearse | sql_stream "$db")
    if printf '%s' "$out" | grep -q 'REHEARSAL_ROLLED_BACK' && ! printf '%s' "$out" | grep -q 'NOT OK'; then
      pass "$db: a rehearsal runs to its end and reports an all-ok checklist"
    else
      fail "$db: a rehearsal runs to its end and reports an all-ok checklist" "$(printf '%s' "$out" | grep -m1 -E 'ERROR|NOT OK')"
    fi
    if [ "$before" = "$(printf '%s;\n' "$FINGERPRINT" | admin "$db")" ]; then
      pass "$db: the rehearsal left nothing behind"
    else
      fail "$db: the rehearsal left nothing behind" "the schema or the rows it touches differ from before"
    fi

    for run in "as one statement" "pasted, on top"; do
      if [ "$run" = "as one statement" ]; then
        out=$(python3 "$ROOT/scripts/db_apply.py" wrap | sql_stream "$db"); status=$?
      else
        out=$(apply_file "$db" "$APPLY"); status=$?
      fi
      if [ "$status" -ne 0 ]; then
        fail "$db: the APPLY file runs ($run)" "$(printf '%s' "$out" | grep -m1 ERROR)"
      elif printf '%s' "$out" | grep -q 'NOT OK'; then
        fail "$db: the APPLY file's checklist is all ok ($run)" "$(printf '%s' "$out" | grep 'NOT OK' | head -1)"
      else
        pass "$db: the APPLY file runs and its checklist is all ok ($run)"
      fi
    done
  fi
  [ "$db" = "nov6" ] && NOV6_SCHEMA="$(printf '%s;\n' "$SCHEMA_FINGERPRINT" | admin "$db")"
  [ "$db" = "fresh" ] && FRESH_SCHEMA="$(printf '%s;\n' "$SCHEMA_FINGERPRINT" | admin "$db")"
  seed_after "$db"
  checks "$db"
  row_cap_check "$db"
  echo
done

if [ -n "$NOV6_SCHEMA" ] && [ "$NOV6_SCHEMA" = "$FRESH_SCHEMA" ]; then
  pass "schema parity: nov6 + APPLY matches fresh migrations 100%"
else
  fail "schema parity: nov6 + APPLY matches fresh migrations 100%" "nov6=$NOV6_SCHEMA fresh=$FRESH_SCHEMA"
fi

[ "${KEEP:-0}" = "1" ] || docker rm -f "$CONTAINER" >/dev/null 2>&1
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
