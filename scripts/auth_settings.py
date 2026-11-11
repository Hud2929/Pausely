#!/usr/bin/env python3
"""The live project's sign-in settings: what they are, what the app needs, and the change.

  python3 scripts/auth_settings.py show     every setting the app depends on, live value against needed
  python3 scripts/auth_settings.py apply    set the ones that hold no secret (codes, wording, addresses)
  python3 scripts/auth_settings.py apple    switch on Sign in with Apple for the app's bundle id
  RESEND_API_KEY=re_... python3 scripts/auth_settings.py smtp    send account email through Resend
  python3 scripts/auth_settings.py hook     or: have Supabase Auth call the auth-email function
                                            (deploy it first; the mail key stays in its secrets)

Why this exists: until 2026-11-11 the live project still had Supabase's defaults. The emails carried a
link to localhost instead of the 6-digit code the app asks for, codes were 8 digits long, and the
built-in mailer delivers only to members of the project, two emails an hour. Nobody else could sign up.

`apply` first saves the settings it is about to change to private/audits/, so they can be put back.
It uses the sign-in the Supabase CLI holds on this Mac (see scripts/db_apply.py). No secret is printed.
"""

import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import db_apply  # noqa: E402  (the same sign-in and project)

ROOT = db_apply.ROOT
BUNDLE_ID = "com.pausely.app.Pausely"
SUBJECT = "Your Pausely code: {{ .Token }}"
SENTENCES = {
    "confirmation": "Enter it in Pausely to finish creating your account.",
    "magic_link": "Enter it in Pausely to sign in.",
    "recovery": "Enter it in Pausely to choose a new password.",
}


KEYCHAIN_ITEM = "Pausely Resend API key"


def mail_key_from_keychain():
    """The Resend key, kept in this Mac's login Keychain and nowhere in the repository."""
    import subprocess
    found = subprocess.run(["security", "find-generic-password", "-s", KEYCHAIN_ITEM, "-a", "pausely", "-w"],
                           capture_output=True, text=True)
    return found.stdout.strip()


def call(method, body=None):
    request = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{db_apply.project_ref()}/config/auth",
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": "Bearer " + db_apply.access_token(), "Content-Type": "application/json",
                 "User-Agent": "db-apply-script"},
        method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return True, json.load(response)
    except urllib.error.HTTPError as error:
        return False, f"HTTP {error.code}: {error.read().decode(errors='replace')[:400]}"
    except urllib.error.URLError as error:
        return False, f"Could not reach Supabase: {error.reason}"


def email_page(sentence):
    """The one page all account emails share, from SUPABASE_EMAIL_TEMPLATES.md."""
    document = open(os.path.join(ROOT, "SUPABASE_EMAIL_TEMPLATES.md")).read()
    page = re.search(r"```html\n(.*?)\n```", document, re.S)
    if not page or "{{ .Token }}" not in page.group(1) or "SENTENCE" not in page.group(1):
        db_apply.fail("SUPABASE_EMAIL_TEMPLATES.md no longer holds the page with {{ .Token }} and SENTENCE.")
    return page.group(1).replace("SENTENCE", sentence)


def needed():
    """Settings that hold no secret."""
    settings = {
        "site_url": "https://pausely.pro",
        "uri_allow_list": "pausely://auth/confirm,pausely://auth/reset-password",
        "mailer_otp_length": 6,
    }
    for name, sentence in SENTENCES.items():
        settings[f"mailer_subjects_{name}"] = SUBJECT
        settings[f"mailer_templates_{name}_content"] = email_page(sentence)
    return settings


def short(value):
    text = " ".join(str(value).split())
    return text if len(text) <= 70 else text[:67] + "..."


def show():
    ok, live = call("GET")
    if not ok:
        db_apply.fail(live)
    wrong = 0
    print("Settings the app depends on (live value, then what it needs):")
    for key, want in needed().items():
        have = live.get(key)
        same = have == want
        wrong += 0 if same else 1
        print(f"  {'ok     ' if same else 'CHANGE '} {key}: {short(have)!r}" + ("" if same else f"  ->  {short(want)!r}"))
    for name in SENTENCES:
        body = live.get(f"mailer_templates_{name}_content") or ""
        code = "{{ .Token }}" in body
        wrong += 0 if code else 1
        print(f"  {'ok     ' if code else 'CHANGE '} the '{name}' email carries the 6-digit code: {'yes' if code else 'no'}")

    custom_mail = bool(live.get("smtp_host")) or bool(live.get("hook_send_email_enabled"))
    print("\nDelivery:")
    route = ("the auth-email function" if live.get("hook_send_email_enabled")
             else live.get("smtp_host") or "the built-in mailer (project members only)")
    print(f"  {'ok     ' if custom_mail else 'CHANGE '} account email goes through: {route}")
    hourly = live.get("rate_limit_email_sent")
    print(f"  {'ok     ' if (hourly or 0) >= 30 else 'CHANGE '} emails allowed per hour: {hourly}")
    apple = bool(live.get("external_apple_enabled")) and BUNDLE_ID in str(live.get("external_apple_client_id") or "")
    print(f"  {'ok     ' if apple else 'CHANGE '} Sign in with Apple is on for {BUNDLE_ID}: {'yes' if apple else 'no'}")
    wrong += (0 if custom_mail else 1) + (0 if (hourly or 0) >= 30 else 1) + (0 if apple else 1)
    print(f"\n{wrong} to change." if wrong else "\nEverything the app depends on is set.")
    return 1 if wrong else 0


def keep_copy(live, keys):
    folder = os.path.join(ROOT, "private", "audits")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, f"auth_settings_before_{datetime.datetime.now():%Y-%m-%d_%H%M%S}.json")
    json.dump({key: live.get(key) for key in keys}, open(path, "w"), indent=1)
    print(f"Saved the settings being replaced to {os.path.relpath(path, ROOT)}")


def change(settings, secret_keys=()):
    ok, live = call("GET")
    if not ok:
        db_apply.fail(live)
    keep_copy(live, [key for key in settings if key not in secret_keys])
    ok, result = call("PATCH", settings)
    if not ok:
        db_apply.fail(f"Nothing was changed. {result}")
    print("Changed:", ", ".join(key for key in settings if key not in secret_keys)
          + (" (and the mail password, not shown)" if secret_keys else ""))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "show":
        return show()
    if mode == "apply":
        change(needed())
        return show()
    if mode == "apple":
        change({"external_apple_enabled": True, "external_apple_client_id": BUNDLE_ID})
        return show()
    if mode == "smtp":
        key = os.environ.get("RESEND_API_KEY", "").strip() or mail_key_from_keychain()
        if not key.startswith("re_"):
            db_apply.fail("No mail key. Set RESEND_API_KEY for this one command, or store it in the Keychain:\n"
                          f'  security add-generic-password -U -a pausely -s "{KEYCHAIN_ITEM}" -w <key>')
        change({"smtp_host": "smtp.resend.com", "smtp_port": "465", "smtp_user": "resend", "smtp_pass": key,
                "smtp_admin_email": "hello@pausely.pro", "smtp_sender_name": "Pausely",
                "rate_limit_email_sent": 100}, secret_keys=("smtp_pass",))
        return show()
    if mode == "hook":
        return point_auth_at_the_email_function()
    db_apply.fail(__doc__)


def point_auth_at_the_email_function():
    """After `supabase functions deploy auth-email`: give the function and Supabase Auth one new signing
    secret, and have Supabase Auth call the function instead of the built-in mailer. The mail key stays
    where it is, in the function's own secrets. To go back: set hook_send_email_enabled to false."""
    import base64
    import subprocess
    import tempfile
    secret = "v1,whsec_" + base64.b64encode(os.urandom(32)).decode()
    with tempfile.NamedTemporaryFile("w", suffix=".env", delete=False) as handle:
        os.chmod(handle.name, 0o600)
        handle.write(f"SEND_EMAIL_HOOK_SECRET={secret}\n")
    try:
        done = subprocess.run(["supabase", "secrets", "set", "--env-file", handle.name,
                               "--project-ref", db_apply.project_ref()], capture_output=True, text=True)
    finally:
        os.remove(handle.name)
    if done.returncode != 0:
        db_apply.fail("The function's signing secret could not be set. Nothing else was changed.\n" + done.stderr[-300:])
    change({"hook_send_email_enabled": True,
            "hook_send_email_uri": f"https://{db_apply.project_ref()}.supabase.co/functions/v1/auth-email",
            "hook_send_email_secrets": secret}, secret_keys=("hook_send_email_secrets",))
    return show()


if __name__ == "__main__":
    sys.exit(main())
