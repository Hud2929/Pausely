# Account emails (Supabase)

Pausely's sign-up, sign-in and password-reset emails are sent by Supabase. Their wording lives in the
Supabase dashboard, not in the app, so this file is the copy to paste there. It replaces the three older
notes that disagreed with each other.

**What the app expects:** every one of these emails carries a **6-digit code** (`{{ .Token }}`). The app
asks for that code on the screen that follows. If a template carries a link instead, the app still signs
the person in when the link is opened on the iPhone (`AuthLink`, `RevolutionaryAuthManager.handleDeepLink`),
but a link opened on another device goes nowhere. Codes work everywhere, so the templates use codes only.

## Settings to check once (Supabase dashboard → Authentication)

1. **Sign In / Providers → Email**: "Confirm email" on; **Email OTP length: 6**.
2. **URL Configuration → Redirect URLs**: add `pausely://auth/confirm` and `pausely://auth/reset-password`.
   These are where a link would come back to if a template ever carries one again.
3. **Emails → Templates**: paste the three templates below into **Confirm signup**, **Magic Link** and
   **Reset Password**. The app sends "Confirm signup" to a new address and "Magic Link" to one that
   already has an account, so both need the code.

Then test with an address that has never signed up: create an account in the app, and the email should
show a code that the app accepts.

## The template

All three emails use the same page; only the subject and one sentence change. No images, no web fonts,
no links: nothing to load and nothing for a mail scanner to "click".

| Template | Subject | Sentence under the code |
|---|---|---|
| Confirm signup | `Your Pausely code: {{ .Token }}` | `Enter it in Pausely to finish creating your account.` |
| Magic Link | `Your Pausely code: {{ .Token }}` | `Enter it in Pausely to sign in.` |
| Reset Password | `Your Pausely code: {{ .Token }}` | `Enter it in Pausely to choose a new password.` |

Paste this body into each, and replace `SENTENCE` with that template's sentence:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
  <title>Your Pausely code</title>
</head>
<body style="margin:0; padding:0; background-color:#0A0B0D;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0A0B0D;">
    <tr>
      <td align="center" style="padding:40px 20px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:440px;">
          <tr>
            <td style="font-family:Georgia,'Times New Roman',serif; font-size:22px; font-weight:bold; color:#F5F4F0; padding-bottom:28px;">
              Pausely
            </td>
          </tr>
          <tr>
            <td style="background-color:#ECE7DC; border-radius:6px; padding:28px 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:13px; color:#5A574E; padding-bottom:10px;">
                    Your code
                  </td>
                </tr>
                <tr>
                  <td style="font-family:ui-monospace,Menlo,Consolas,'Courier New',monospace; font-size:38px; font-weight:bold; letter-spacing:6px; color:#1A1A17; padding-bottom:16px;">
                    {{ .Token }}
                  </td>
                </tr>
                <tr>
                  <td style="border-top:1px dashed #B9B3A4; padding-top:16px; font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:15px; line-height:22px; color:#1A1A17;">
                    SENTENCE It can be used once.
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#A6A8AD; padding-top:24px;">
              If you didn't ask for this, you can ignore this email.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

The colours are the app's own (`Palette` in `Pausely/DesignSystem/InkPaper.swift`): ink background, the
code on a paper slip.
