#!/usr/bin/env python3
"""Runs the newest supabase/APPLY_*.sql on the live Supabase project, carefully.

  python3 scripts/db_apply.py state      what the live database looks like now (read-only)
  python3 scripts/db_apply.py rehearse   run the file for real, then roll all of it back
  python3 scripts/db_apply.py apply      run it and keep it, then print the file's checklist
  python3 scripts/db_apply.py verify     act as a visitor and as a signed-in person; nothing is kept
  python3 scripts/db_apply.py wrap [rehearse]   print the SQL that apply (or rehearse) sends

Order: scripts/dbtest/run.sh (the proof, on a local stand-in), then state, rehearse, apply, verify.

It talks to the Supabase Management API with the sign-in the Supabase CLI already holds on this Mac
(Keychain item "Supabase CLI"), or SUPABASE_ACCESS_TOKEN when set. The token is never printed.
Reports are counts and yes/no answers; no row of anyone's data is fetched.

The file is sent as one statement (a DO block that EXECUTEs the file's body), so it either runs
whole or changes nothing, and no transaction is ever left open on a pooled connection.
"""

import base64
import glob
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://api.supabase.com/v1/projects/{ref}/database/query"
BODY_START = "BEGIN;"
BODY_END = "COMMIT;"
CHECKLIST_MARK = "-- ======================== Checklist ========================"
OUTER_TAG = "$pausely_apply$"
SCRIPT_TAG = "$pausely_script$"
REHEARSAL = "REHEARSAL_ROLLED_BACK"
VERIFIED = "VERIFY_ROLLED_BACK"


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


# ---- the file ---------------------------------------------------------------------------------

def newest_apply():
    files = sorted(glob.glob(os.path.join(ROOT, "supabase", "APPLY_*.sql")))
    if not files:
        fail("No supabase/APPLY_*.sql file.")
    return files[-1]


def split_apply(text):
    """The statements between BEGIN and COMMIT, and the checklist query that follows them."""
    lines = text.splitlines()
    try:
        start = next(i for i, line in enumerate(lines) if line.strip() == BODY_START)
        end = next(i for i, line in enumerate(lines) if line.strip() == BODY_END)
        mark = next(i for i, line in enumerate(lines) if line.strip() == CHECKLIST_MARK)
    except StopIteration:
        fail("The APPLY file must have BEGIN;, COMMIT; and the Checklist marker, each on its own line.")
    if not start < end < mark:
        fail("The APPLY file's BEGIN;, COMMIT; and Checklist marker are out of order.")
    body = "\n".join(lines[start + 1:end])
    checklist = "\n".join(line for line in lines[mark + 1:] if not line.strip().startswith("--")).strip().rstrip(";")
    if OUTER_TAG in body or SCRIPT_TAG in body:
        fail("The APPLY file uses a dollar-quote tag this script needs for itself.")
    if not checklist.upper().startswith("SELECT"):
        fail("The Checklist section must be one SELECT.")
    return body, checklist


def wrapped(body, checklist, rehearse):
    """One statement: run the whole body; for a rehearsal, report the checklist and undo everything."""
    if rehearse:
        ending = f"""
    SELECT string_agg(c."check" || ' = ' || c.result, E'\\n') INTO report FROM (
{checklist}
    ) AS c;
    RAISE EXCEPTION '{REHEARSAL}%', E'\\n' || report;"""
    else:
        ending = ""
    return f"""DO {OUTER_TAG}
DECLARE
    report text;
BEGIN
    EXECUTE {SCRIPT_TAG}
{body}
    {SCRIPT_TAG};{ending}
END {OUTER_TAG};"""


# ---- the live project ---------------------------------------------------------------------------

def access_token():
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
    if not token:
        found = subprocess.run(["security", "find-generic-password", "-s", "Supabase CLI", "-a", "supabase", "-w"],
                               capture_output=True, text=True)
        token = found.stdout.strip()
        if token.startswith("go-keyring-base64:"):
            token = base64.b64decode(token.split(":", 1)[1]).decode()
    if not token:
        fail("Not signed in: run `supabase login`, or set SUPABASE_ACCESS_TOKEN.")
    return token


def project_ref():
    ref = os.environ.get("SUPABASE_PROJECT_REF", "").strip()
    if not ref:
        try:
            ref = open(os.path.join(ROOT, "supabase", ".temp", "project-ref")).read().strip()
        except OSError:
            fail("No linked project: run `supabase link`, or set SUPABASE_PROJECT_REF.")
    return ref


def run(sql):
    """Returns (ok, rows or error text)."""
    request = urllib.request.Request(
        API.format(ref=project_ref()),
        data=json.dumps({"query": sql}).encode(),
        headers={"Authorization": "Bearer " + access_token(), "Content-Type": "application/json",
                 "User-Agent": "db-apply-script"},
        method="POST")
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            text = response.read().decode()
            return True, (json.loads(text) if text.strip() else [])
    except urllib.error.HTTPError as error:
        text = error.read().decode(errors="replace")
        try:
            text = json.loads(text).get("message", text)
        except (ValueError, AttributeError):
            pass
        return False, f"HTTP {error.code}: {text}"
    except urllib.error.URLError as error:
        return False, f"Could not reach Supabase: {error.reason}"


# ---- state: what is there now -------------------------------------------------------------------

STATE_SQL = """
select json_build_object(
  'running_as', current_user,
  'postgres', current_setting('server_version'),
  'tables', (select json_agg(t order by t.name) from (
      select c.relname as name, c.relrowsecurity as rls, pg_get_userbyid(c.relowner) as owner,
             (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from public.%I', c.relname), false, true, '')))[1]::text::bigint as rows,
             has_table_privilege('anon', c.oid, 'SELECT') as anon_select,
             has_table_privilege('authenticated', c.oid, 'INSERT') as signed_in_insert
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r') t),
  'views', (select json_agg(c.relname order by c.relname) from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'v'),
  'policies', (select json_agg(json_build_object('table', tablename, 'name', policyname, 'for', cmd,
                                                 'to', roles, 'using', qual, 'check', with_check)
                               order by tablename, policyname)
               from pg_policies where schemaname = 'public'),
  'triggers', (select json_agg(json_build_object('table', c.relname, 'name', t.tgname) order by c.relname, t.tgname)
               from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace
               where n.nspname = 'public' and not t.tgisinternal),
  'functions', (select json_agg(json_build_object('name', p.proname, 'owner_rights', p.prosecdef,
                                                  'owner', pg_get_userbyid(p.proowner),
                                                  'visitor_can_call', has_function_privilege('anon', p.oid, 'EXECUTE'),
                                                  'signed_in_can_call', has_function_privilege('authenticated', p.oid, 'EXECUTE'))
                                order by p.proname)
                from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'),
  'realtime', (select json_agg(tablename order by tablename) from pg_publication_tables
               where pubname = 'supabase_realtime' and schemaname = 'public'),
  'realtime_owner', (select pg_get_userbyid(pubowner) from pg_publication where pubname = 'supabase_realtime'),
  'columns', (select json_object_agg(table_name, cols) from (
      select table_name, json_agg(column_name || ' ' || data_type || case when is_nullable = 'NO' and column_default is null then ' (required)' else '' end order by ordinal_position) as cols
      from information_schema.columns
      where table_schema = 'public' and table_name in ('profiles', 'subscriptions', 'lifecycle_events', 'pause_plans', 'app_store_entitlements', 'edge_rate_limits', 'referral_codes', 'waitlist', 'user_settings')
      group by table_name) x),
  'constraints_on_profiles', (select json_agg(conname order by conname) from pg_constraint where conrelid = to_regclass('public.profiles')),
  'indexes_on_ratings', (select json_agg(indexname order by indexname) from pg_indexes
                         where schemaname = 'public' and tablename = 'cancel_difficulty_ratings'),
  'accounts', (select count(*) from auth.users),
  'marked_pro', (select count(*) from public.profiles where is_pro)
) as state;
"""


def show_state():
    ok, result = run(STATE_SQL)
    if not ok:
        fail(result)
    state = result[0]["state"]
    print(f"Live database: Postgres {state['postgres']}, statements run as {state['running_as']}")
    print(f"Accounts: {state['accounts']}   marked Pro: {state['marked_pro']}   realtime owned by: {state['realtime_owner']}")
    print("\nTables (rows | row security | owner | a visitor may read | a signed-in person may insert)")
    for table in state["tables"] or []:
        print(f"  {table['name']:28s} {table['rows']:>6} | {'on ' if table['rls'] else 'OFF'} | {table['owner']:10s} | "
              f"{'yes' if table['anon_select'] else 'no '} | {'yes' if table['signed_in_insert'] else 'no'}")
    print("\nViews:", ", ".join(state["views"] or []) or "none")
    print("\nPolicies")
    for policy in state["policies"] or []:
        roles = ",".join(policy["to"]) if isinstance(policy["to"], list) else str(policy["to"]).strip("{}")
        print(f"  {policy['table']:26s} {policy['for']:7s} to {roles:14s} \"{policy['name']}\"")
        print(f"      using: {policy['using']}   check: {policy['check']}")
    print("\nTriggers")
    for trigger in state["triggers"] or []:
        print(f"  {trigger['table']:28s} {trigger['name']}")
    print("\nFunctions (owner rights | owner | a visitor may call | a signed-in person may call)")
    for function in state["functions"] or []:
        print(f"  {function['name']:30s} {'yes' if function['owner_rights'] else 'no '} | {function['owner']:10s} | "
              f"{'yes' if function['visitor_can_call'] else 'no '} | {'yes' if function['signed_in_can_call'] else 'no'}")
    print("\nBroadcast in realtime:", ", ".join(state["realtime"] or []) or "none")
    for table, columns in sorted((state["columns"] or {}).items()):
        print(f"\nColumns of {table}: {', '.join(columns)}")
    print("\nConstraints on profiles:", ", ".join(state["constraints_on_profiles"] or []) or "none")
    print("Indexes on ratings:", ", ".join(state["indexes_on_ratings"] or []) or "none (no such table)")


# ---- verify: act as the people the rules are for ----------------------------------------------

VERIFY_SQL = f"""
DO $verify$
DECLARE
    someone uuid;
    found integer;
    closed text;
    closed_objects text[] := ARRAY['affiliates', 'affiliate_conversions', 'waitlist', 'user_profiles',
                                   'usage_snapshots', 'user_devices', 'ai_insights_log', 'alternatives',
                                   'tracked_trials', 'app_store_entitlements', 'deletion_requests',
                                   'edge_rate_limits', 'profiles_missing_age_consent',
                                   'orders', 'user_subscriptions', 'active_subscriptions',
                                   'expiring_subscriptions', 'payment_failures'];
    report text := '';
BEGIN
    SELECT id INTO someone FROM public.profiles ORDER BY created_at LIMIT 1;
    IF someone IS NULL THEN
        -- No profile rows yet: borrow an account and give it one for the length of this check.
        SELECT id INTO someone FROM auth.users ORDER BY created_at LIMIT 1;
        IF someone IS NOT NULL THEN
            INSERT INTO public.profiles (id) VALUES (someone);
        END IF;
    END IF;

    -- As a signed-in person, on their own row.
    IF someone IS NULL THEN
        report := report || 'a person cannot mark themselves Pro = SKIPPED (no accounts)' || E'\\n';
    ELSE
        PERFORM set_config('request.jwt.claims',
                           json_build_object('sub', someone, 'role', 'authenticated', 'email', 'verify@example.test')::text, true);
        SET LOCAL ROLE authenticated;
        BEGIN
            UPDATE public.profiles SET is_pro = NOT coalesce(is_pro, false) WHERE id = someone;
            GET DIAGNOSTICS found = ROW_COUNT;
            report := report || format('a person cannot mark themselves Pro = NOT OK (%s row changed)', found) || E'\\n';
        EXCEPTION WHEN insufficient_privilege THEN
            report := report || 'a person cannot mark themselves Pro = ok' || E'\\n';
        END;
        BEGIN
            SELECT count(*) INTO found FROM public.subscriptions WHERE user_id <> someone;
            report := report || format('a person sees only their own subscriptions = %s', CASE WHEN found = 0 THEN 'ok' ELSE 'NOT OK (' || found || ' of others)' END) || E'\\n';
        EXCEPTION WHEN insufficient_privilege THEN
            report := report || 'a person sees only their own subscriptions = NOT OK (refused outright)' || E'\\n';
        END;
        BEGIN
            SELECT count(*) INTO found FROM public.profiles WHERE id <> someone;
            report := report || format('a person sees only their own profile = %s', CASE WHEN found = 0 THEN 'ok' ELSE 'NOT OK (' || found || ' of others)' END) || E'\\n';
        EXCEPTION WHEN insufficient_privilege THEN
            report := report || 'a person sees only their own profile = NOT OK (refused outright)' || E'\\n';
        END;
        -- Closed means refused outright: an empty answer would hide an open view over an empty table.
        FOREACH closed IN ARRAY closed_objects LOOP
            BEGIN
                EXECUTE format('SELECT count(*) FROM public.%I', closed) INTO found;
                report := report || format('a signed-in person cannot read %s = NOT OK (readable, %s rows)', closed, found) || E'\\n';
            EXCEPTION WHEN insufficient_privilege THEN
                report := report || format('a signed-in person cannot read %s = ok', closed) || E'\\n';
            WHEN undefined_table THEN
                report := report || format('a signed-in person cannot read %s = ok (no such table)', closed) || E'\\n';
            END;
        END LOOP;
        BEGIN
            PERFORM public.calculate_monthly_spend(someone);
            report := report || 'the monthly-spend function is closed = NOT OK' || E'\\n';
        EXCEPTION WHEN insufficient_privilege THEN
            report := report || 'the monthly-spend function is closed = ok' || E'\\n';
        WHEN undefined_function THEN
            report := report || 'the monthly-spend function is closed = ok (no such function)' || E'\\n';
        END;
        RESET ROLE;
    END IF;

    -- As a signed-out visitor.
    PERFORM set_config('request.jwt.claims', '{{"role":"anon"}}', true);
    SET LOCAL ROLE anon;
    BEGIN
        SELECT count(*) INTO found FROM public.profiles;
        report := report || format('a visitor sees no profiles = %s', CASE WHEN found = 0 THEN 'ok' ELSE 'NOT OK (' || found || ')' END) || E'\\n';
    EXCEPTION WHEN insufficient_privilege THEN
        report := report || 'a visitor sees no profiles = ok' || E'\\n';
    END;
    BEGIN
        SELECT count(*) INTO found FROM public.subscriptions;
        report := report || format('a visitor sees no subscriptions = %s', CASE WHEN found = 0 THEN 'ok' ELSE 'NOT OK (' || found || ')' END) || E'\\n';
    EXCEPTION WHEN insufficient_privilege THEN
        report := report || 'a visitor sees no subscriptions = ok' || E'\\n';
    END;
    FOREACH closed IN ARRAY closed_objects LOOP
        BEGIN
            EXECUTE format('SELECT count(*) FROM public.%I', closed) INTO found;
            report := report || format('a visitor cannot read %s = NOT OK (readable, %s rows)', closed, found) || E'\\n';
        EXCEPTION WHEN insufficient_privilege THEN
            report := report || format('a visitor cannot read %s = ok', closed) || E'\\n';
        WHEN undefined_table THEN
            report := report || format('a visitor cannot read %s = ok (no such table)', closed) || E'\\n';
        END;
    END LOOP;
    BEGIN
        SELECT count(*) INTO found FROM public.referral_codes;
        report := report || format('a visitor cannot list referral codes = %s', CASE WHEN found = 0 THEN 'ok' ELSE 'NOT OK (' || found || ' visible)' END) || E'\\n';
    EXCEPTION WHEN insufficient_privilege THEN
        report := report || 'a visitor cannot list referral codes = ok' || E'\\n';
    WHEN undefined_table THEN
        report := report || 'a visitor cannot list referral codes = ok (no such table)' || E'\\n';
    END;
    BEGIN
        INSERT INTO public.waitlist (email) VALUES ('verify-not-kept@example.test');
        report := report || 'a visitor cannot write to the waitlist = NOT OK' || E'\\n';
    EXCEPTION WHEN insufficient_privilege THEN
        report := report || 'a visitor cannot write to the waitlist = ok' || E'\\n';
    WHEN undefined_table THEN
        report := report || 'a visitor cannot write to the waitlist = ok (no such table)' || E'\\n';
    END;
    BEGIN
        PERFORM public.delete_my_account();
        report := report || 'a visitor cannot call account deletion = NOT OK' || E'\\n';
    EXCEPTION WHEN insufficient_privilege THEN
        report := report || 'a visitor cannot call account deletion = ok' || E'\\n';
    WHEN undefined_function THEN
        report := report || 'a visitor cannot call account deletion = NOT OK (not installed)' || E'\\n';
    WHEN OTHERS THEN
        -- Reaching the function at all means a visitor may call it, even though it then refuses.
        report := report || 'a visitor cannot call account deletion = NOT OK (callable: ' || SQLERRM || ')' || E'\\n';
    END;
    BEGIN
        SELECT count(*) INTO found FROM public.service_difficulty_scores;
        report := report || 'a visitor can read the per-service averages = ok' || E'\\n';
    EXCEPTION WHEN OTHERS THEN
        report := report || 'a visitor can read the per-service averages = NOT OK (' || SQLERRM || ')' || E'\\n';
    END;
    RESET ROLE;

    -- Raising undoes everything above, whatever it managed to do.
    RAISE EXCEPTION '{VERIFIED}%', E'\\n' || report;
END $verify$;
"""


def report_from(error_text, marker):
    """The lines a deliberate rollback carried back, or None when the failure was a real one."""
    if marker not in error_text:
        return None
    lines = error_text.split(marker, 1)[1].replace("\\n", "\n").splitlines()
    kept = []
    for line in lines:
        line = line.strip().strip('"')
        if not line:
            continue
        if line.startswith(("CONTEXT:", "PL/pgSQL", "SQL statement")):
            break
        kept.append(line)
    return kept


def print_report(lines):
    worst = 0
    for line in lines:
        print("  " + line)
        if "NOT OK" in line:
            worst = 1
    return worst


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "state":
        show_state()
        return 0

    if mode == "verify":
        ok, result = run(VERIFY_SQL)
        lines = None if ok else report_from(result, VERIFIED)
        if lines is None:
            fail(f"The verification did not run to its end: {result}")
        print("Acting as a signed-in person and as a visitor (nothing was kept):")
        return print_report(lines)

    if mode not in ("rehearse", "apply", "wrap"):
        fail(__doc__)

    path = newest_apply()
    body, checklist = split_apply(open(path).read())

    if mode == "wrap":
        rehearse = len(sys.argv) > 2 and sys.argv[2] == "rehearse"
        print(wrapped(body, checklist, rehearse))
        if not rehearse:
            print(checklist + ";")
        return 0

    name = os.path.basename(path)
    if mode == "rehearse":
        ok, result = run(wrapped(body, checklist, rehearse=True))
        lines = None if ok else report_from(result, REHEARSAL)
        if lines is None:
            fail(f"{name} does NOT run on the live database. Nothing was changed.\n{result}")
        print(f"{name} ran to its end on the live database and was rolled back. Its checklist would read:")
        return print_report(lines)

    ok, result = run(wrapped(body, checklist, rehearse=False))
    if not ok:
        fail(f"{name} failed. It runs as one statement, so nothing was changed.\n{result}")
    print(f"{name} is applied.")
    run("NOTIFY pgrst, 'reload schema';")
    ok, result = run(checklist + ";")
    if not ok:
        fail(f"Applied, but the checklist could not be read: {result}")
    return print_report([f"{row['check']} = {row['result']}" for row in result])


if __name__ == "__main__":
    sys.exit(main())
