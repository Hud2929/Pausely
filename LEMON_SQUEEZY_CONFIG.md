# LemonSqueezy Configuration Guide

This document explains how to configure LemonSqueezy for the Pausely app.

## Required Configuration

### 1. Info.plist Configuration

Add the following entries to your app's `Info.plist`:

```xml
<!-- LemonSqueezy Configuration -->
<key>LEMON_SQUEEZY_API_KEY</key>
<string>YOUR_API_KEY_HERE</string>

<key>LEMON_SQUEEZY_STORE_ID</key>
<string>YOUR_STORE_ID</string>

<key>LEMON_SQUEEZY_WEBHOOK_SECRET</key>
<string>YOUR_WEBHOOK_SIGNING_SECRET</string>
```

### 2. Update LemonSqueezyManager.swift

Edit `Services/LemonSqueezyManager.swift` and replace the placeholder values:

```swift
struct LemonSqueezyConfig {
    static let storeURL = "https://pausely.lemonsqueezy.com"
    static let monthlyVariantID = "YOUR_ACTUAL_MONTHLY_VARIANT_ID"  // From LemonSqueezy Dashboard
    static let annualVariantID = "YOUR_ACTUAL_ANNUAL_VARIANT_ID"    // From LemonSqueezy Dashboard
    static let storeID = "YOUR_ACTUAL_STORE_ID"                      // From Store Settings
    static let webhookSecret = "YOUR_ACTUAL_WEBHOOK_SECRET"          // From Webhook Settings
    static let appReturnURL = "pausely://checkout/success"
    static let apiBaseURL = "https://api.lemonsqueezy.com/v1"
}
```

### 3. URL Scheme Configuration

Ensure your `Info.plist` includes the URL scheme for deep linking:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.pausely.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>pausely</string>
        </array>
    </dict>
</array>
```

## Getting Your Credentials

### API Key

1. Log in to [LemonSqueezy Dashboard](https://app.lemonsqueezy.com)
2. Go to **Settings** → **API**
3. Click **Generate API Key**
4. Copy and save the key immediately

### Store ID

1. In the dashboard, go to **Store** → **Settings**
2. Find your Store ID (usually a number)

### Variant IDs

1. Go to **Products** in the dashboard
2. Click on a product
3. Look for **Variants** section
4. Copy the Variant ID for each product:
   - Monthly: `$7.99/month`
   - Annual: `$69.99/year`

### Webhook Secret

1. Go to **Settings** → **Webhooks**
2. Create a new webhook or edit existing
3. Click **Generate** to create a signing secret
4. Copy the secret

## Webhook Configuration

### Webhook URL

Set your webhook URL in LemonSqueezy Dashboard:

```
https://your-supabase-project.supabase.co/functions/v1/lemon-squeezy-webhook
```

Or if using a custom backend:

```
https://api.pausely.app/webhooks/lemon-squeezy
```

### Required Events

Select these events in the webhook settings:

- ✅ `order_created`
- ✅ `order_paid`
- ✅ `subscription_created`
- ✅ `subscription_updated`
- ✅ `subscription_cancelled`
- ✅ `subscription_expired`
- ✅ `subscription_payment_success`
- ✅ `subscription_payment_failed`
- ✅ `subscription_payment_recovered`

## Testing

### Test Mode

Use these test card numbers in the LemonSqueezy checkout:

| Scenario | Card Number |
|----------|-------------|
| Success | `4242 4242 4242 4242` |
| Decline | `4000 0000 0000 0002` |
| Requires 3DS | `4000 0025 0000 3155` |

Use any future expiry date (e.g., 12/25) and any CVC (e.g., 123).

### Local Testing with ngrok

1. Install ngrok:
   ```bash
   brew install ngrok
   ```

2. Start a tunnel to your local server:
   ```bash
   ngrok http 3000
   ```

3. Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`)

4. Set this as your webhook URL in LemonSqueezy:
   ```
   https://abc123.ngrok.io/webhooks/lemon-squeezy
   ```

### Testing Webhook Handler

Use the debug helper in `LemonSqueezyWebhookHandler`:

```swift
#if DEBUG
let handler = LemonSqueezyWebhookHandler.shared
let result = await handler.testProcessWebhook(
    eventName: "order_paid",
    userId: "test-user-id"
)
print(result.message)
#endif
```

## Security Considerations

### Never Commit Credentials

Add these patterns to your `.gitignore`:

```
# LemonSqueezy credentials
*.xcconfig
Secrets.plist
```

Use a separate `Secrets.xcconfig` file for credentials:

```
LEMON_SQUEEZY_API_KEY = your_actual_key_here
LEMON_SQUEEZY_WEBHOOK_SECRET = your_actual_secret_here
```

### Webhook Verification

Always verify webhook signatures in production:

```swift
let isValid = verifyWebhookSignature(payload: payload, signature: signature, secret: secret)
guard isValid else {
    throw LemonSqueezyError.invalidSignature
}
```

### API Key Storage

For production apps, consider:
- Using Keychain for API keys
- Implementing a proxy server for API calls
- Rotating API keys periodically

## Troubleshooting

### "Invalid API Key" Error

- Verify you're using the correct environment (test vs live)
- Check for extra spaces in the key
- Ensure the key has the correct permissions

### "Webhook Not Received"

- Check the webhook URL is publicly accessible
- Verify HTTPS is used (required)
- Check firewall/security settings
- Review LemonSqueezy webhook logs

### "Premium Not Activating"

- Verify webhook signature verification
- Check custom_data contains user_id
- Review app logs for errors
- Test webhook payload manually

### "Checkout URL Not Working"

- Verify Variant ID is correct
- Check store URL format
- Ensure product is published in LemonSqueezy

## Migration Guide

### From App Store Only to Hybrid

If migrating from App Store only to App Store + LemonSqueezy:

1. Keep existing App Store implementation
2. Add LemonSqueezyManager integration
3. Update PaywallView to show both options
4. Test both purchase flows
5. Handle subscription syncing between sources

### User Data Migration

Existing premium users should retain their status:

```swift
// Check both sources
if hasAppStoreSubscription || hasLemonSqueezySubscription {
    isPremium = true
}
```

## Support

- LemonSqueezy Docs: https://docs.lemonsqueezy.com
- API Reference: https://docs.lemonsqueezy.com/api
- Support: support@lemonsqueezy.com
- Pausely Support: support@pausely.app
