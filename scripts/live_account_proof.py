#!/usr/bin/env python3
"""The live account path, proved before a submission, on a fresh install of the Release build.

  signup   A new person signs up on the live project. The address is Resend's own test inbox, so no
           person receives anything. The auth-email function mails the code; this script reads it back
           from Resend and hands it to the test, which types it. Then the database is read (the account,
           confirmed, with its profile and the two subscriptions made before signing up), the account
           is deleted from inside the app, and the database is read again.
  review   The account App Store Connect gives to App Review signs in, and signs out.

Usage:  python3 scripts/live_account_proof.py <simulator id> [signup] [review]
Needs:  the Supabase CLI and asc signed in, the Keychain item "Pausely Resend API key", and the
        Release build from `scripts/proof.sh release`.
The pictures of every step are left in the folder it prints. No password is printed or kept."""
import json, os, plistlib, re, subprocess, sys, time, urllib.error, urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import db_apply  # noqa: E402  (run(sql): the Management API, with the CLI's sign-in)

APP_ID = "6759973158"
BUNDLE = "com.pausely.app.Pausely"
BUILD = Path("/tmp/PauselyBuild")
RELEASE_APP = Path("/tmp/PauselyBuildRelease/Build/Products/Release-iphonesimulator/Pausely.app")
TESTS = {"signup": "testANewPersonSignsUpTypesTheMailedCodeAndDeletesTheAccount",
         "review": "testTheAccountGivenToAppReviewSignsIn"}
results = []


def note(ok, text):
    results.append(bool(ok))
    print(f"  {'ok  ' if ok else 'FAIL'}  {text}", flush=True)


def sh(*args, env=None):
    done = subprocess.run(args, capture_output=True, text=True, env=env)
    return done.returncode, done.stdout, done.stderr


def asc(*args):
    env = dict(os.environ, PATH=os.path.expanduser("~/.blitz/bin") + ":" + os.environ["PATH"])
    code, out, err = sh("asc", *args, "--output", "json", env=env)
    if code:
        sys.exit(f"asc {' '.join(args[:2])} failed: {err[:300]}")
    return json.loads(out)


def sql(query):
    ok, rows = db_apply.run(query)
    if not ok:
        sys.exit(f"The database could not be read: {rows}")
    return rows


def resend(path):
    key = sh("security", "find-generic-password", "-s", "Pausely Resend API key", "-a", "pausely", "-w")[1].strip()
    request = urllib.request.Request("https://api.resend.com" + path,
                                     headers={"Authorization": "Bearer " + key, "User-Agent": "pausely-proof"})
    try:
        with urllib.request.urlopen(request, timeout=30) as reply:
            return json.loads(reply.read())
    except urllib.error.HTTPError as error:
        return {"error": f"{error.code} {error.read().decode()[:200]}"}


def mailed(address):
    """The email Resend holds for this address, if it has arrived: (id, subject, last event)."""
    for email in resend("/emails?limit=30").get("data", []):
        if address in (email.get("to") or []):
            return email["id"], email.get("subject") or "", email.get("last_event")
    return None


def account(address):
    rows = sql(f"""select u.id::text as id, (u.email_confirmed_at is not null) as confirmed,
                          (select count(*) from public.profiles p where p.id = u.id) as profiles,
                          (select count(*) from public.subscriptions s where s.user_id = u.id) as subscriptions,
                          (select string_agg(s.name, ', ' order by s.name) from public.subscriptions s where s.user_id = u.id) as names
                   from auth.users u where u.email = '{address}'""")
    return rows[0] if rows else None


def remove_leftovers():
    """Test accounts a failed run left behind: only this script's own addresses at Resend's test inbox."""
    mine = "email ~ '^delivered\\+pausely[0-9]+@resend\\.dev$'"
    left = sql(f"select id::text as id, email from auth.users where {mine}")
    for row in left:
        sql(f"delete from auth.users where id = '{row['id']}' and {mine}")
        rest = sql(f"""select (select count(*) from public.subscriptions where user_id = '{row['id']}')
                            + (select count(*) from public.profiles where id = '{row['id']}') as n""")[0]["n"]
        print(f"  note  removed the test account an earlier run left ({row['email']}); rows still under it: {rest}")


def release_test_run():
    """The test-run file, with the Release app in place of the Debug one as the app under test."""
    source = next((BUILD / "Build/Products").glob("Pausely_*.xctestrun"))
    with open(source, "rb") as file:
        plan = plistlib.load(file)

    def targets(node):
        if isinstance(node, dict):
            if "UITargetAppPath" in node:
                yield node
            for value in node.values():
                yield from targets(value)
        elif isinstance(node, list):
            for value in node:
                yield from targets(value)

    changed = 0
    for target in targets(plan):
        debug_app = target["UITargetAppPath"]
        target["UITargetAppPath"] = str(RELEASE_APP)
        target["DependentProductPaths"] = [str(RELEASE_APP) if path == debug_app else path
                                           for path in target.get("DependentProductPaths", [])]
        changed += 1
    if not changed:
        sys.exit("The test-run file names no app under test.")
    out = source.with_name("live_release.xctestrun")
    with open(out, "wb") as file:
        plistlib.dump(plan, file)
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sim, parts = sys.argv[1], [p for p in sys.argv[2:] if p in TESTS] or list(TESTS)
    os.chdir(Path(__file__).parent.parent)
    if not RELEASE_APP.exists():
        sys.exit("No Release build: run scripts/proof.sh release first.")
    with open(RELEASE_APP / "Info.plist", "rb") as file:
        info = plistlib.load(file)
    print(f"Release build {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}), live project {db_apply.project_ref()}")

    folder = BUILD / f"live_proof_{time.strftime('%Y%m%d_%H%M%S')}"
    folder.mkdir(parents=True)
    os.chmod(folder, 0o700)
    code, _, err = sh("xcodebuild", "build-for-testing", "-scheme", "Pausely", "-destination", f"id={sim}",
                      "-derivedDataPath", str(BUILD))
    if code:
        sys.exit("The tests did not build:\n" + err[-1500:])
    test_run = release_test_run()

    address = f"delivered+pausely{int(time.time())}@resend.dev"
    (folder / "signup_email.txt").write_text(address)
    login = folder / "review_login.txt"
    if "review" in parts:
        version = next(v for v in asc("versions", "list", "--app", APP_ID)["data"]
                       if v["attributes"]["appStoreState"] != "READY_FOR_SALE")
        detail = asc("review", "details-for-version", "--version-id", version["id"])["data"]["attributes"]
        login.touch(mode=0o600)
        login.write_text(f"{detail['demoAccountName']}\n{detail['demoAccountPassword']}")
        print(f"Review sign-in read from App Store Connect, version {version['attributes']['versionString']}: {detail['demoAccountName']}")
        answered = sql(f"""select coalesce(p.age_minimum_met, false) as answered from auth.users u
                           join public.profiles p on p.id = u.id where u.email = '{detail['demoAccountName']}'""")
        if not answered:
            sys.exit(f"The live project has no account {detail['demoAccountName']}: App Review could not sign in.")
        (folder / "review_age_answered.txt").write_text("yes" if answered[0]["answered"] else "no")
        print("It has answered the age check before: the test fails if it is asked again." if answered[0]["answered"]
              else "It has not answered the age check: the test answers it, as App Review will.")

    if "signup" in parts:
        remove_leftovers()
    all_passed = True
    for part in parts:
        print(f"\n{part}:", flush=True)
        # A fresh install: no app, and no session left in the simulator's keychain by an earlier run.
        sh("xcrun", "simctl", "bootstatus", sim, "-b")
        sh("xcrun", "simctl", "uninstall", sim, BUNDLE)
        sh("xcrun", "simctl", "keychain", sim, "reset")
        log = open(folder / f"{part}.log", "w")
        run = subprocess.Popen(
            ["xcodebuild", "test-without-building", "-xctestrun", str(test_run), "-destination", f"id={sim}",
             f"-only-testing:PauselyUITests/LiveAccountTests/{TESTS[part]}", "-parallel-testing-enabled", "NO"],
            stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, TEST_RUNNER_PAUSELY_LIVE_DIR=str(folder)))
        email_id = user_id = None
        while run.poll() is None:
            time.sleep(3)
            if part != "signup":
                continue
            if (folder / "waiting_for_code").exists() and not (folder / "code.txt").exists():
                found = mailed(address)
                digits = re.search(r"\b(\d{6})\b", found[1]) if found else None
                if digits:
                    email_id = found[0]
                    note(True, f"the auth-email function mailed the code; subject \"{re.sub(r'[0-9]{6}', '••••••', found[1])}\"")
                    (folder / "code.txt").write_text(digits.group(1))
            if (folder / "ready_for_server_check").exists() and not (folder / "server_checked.txt").exists():
                row = None
                for _ in range(20):   # the list is sent by the sync queue, a moment after it is shown
                    row = account(address)
                    if row and row["subscriptions"] == 2:
                        break
                    time.sleep(3)
                user_id = row["id"] if row else None
                note(row and row["confirmed"], "the account is in the database, confirmed by the code")
                note(row and row["profiles"] == 1, "it has its profile row")
                note(row and row["subscriptions"] == 2, f"the list made before signing up reached the database: {row and row['names']}")
                (folder / "server_checked.txt").write_text(json.dumps(row))
        log.close()
        # Nothing of the account is left on the simulator, pass or fail. A failed run once left it signed
        # in, and the unit tests that ran next (inside the app) crashed on a Home screen they never expect.
        sh("xcrun", "simctl", "terminate", sim, BUNDLE)
        sh("xcrun", "simctl", "uninstall", sim, BUNDLE)
        sh("xcrun", "simctl", "keychain", sim, "reset")
        passed = run.returncode == 0
        all_passed = all_passed and passed
        note(passed, f"the test passed on the simulator ({TESTS[part]})" if passed
             else f"the test failed: see {folder}/{part}.log and the pictures beside it")
        if part == "signup":
            left = account(address)
            note(left is None, "deleting the account in the app removed it from the database")
            if user_id:
                rows = sql(f"""select (select count(*) from public.subscriptions where user_id = '{user_id}')
                                    + (select count(*) from public.profiles where id = '{user_id}') as n""")
                note(rows[0]["n"] == 0, "and its profile and subscriptions with it")
            if left is not None:
                remove_leftovers()
            if email_id:
                event = None
                for _ in range(10):
                    event = (mailed(address) or (None, None, None))[2]
                    if event == "delivered":
                        break
                    time.sleep(3)
                note(event == "delivered", f"Resend reports the email as: {event}")

    if login.exists():
        login.unlink()
    for marker in ("code.txt", "signup_email.txt"):
        (folder / marker).unlink(missing_ok=True)
    print(f"\n{sum(results)} of {len(results)} steps passed. Pictures: {folder}")
    sys.exit(0 if all(results) and all_passed else 1)


if __name__ == "__main__":
    main()
