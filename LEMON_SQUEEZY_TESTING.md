# LemonSqueezy Integration Testing Checklist

Complete testing guide for validating the LemonSqueezy integration in Pausely.

## Pre-Testing Setup

### 1. Environment Configuration

Ensure you have:
- [ ] LemonSqueezy test account created
- [ ] Test products set up (Monthly $7.99, Annual $69.99)
- [ ] Test API key configured in app
- [ ] Test webhook secret configured
- [ ] ngrok installed for local webhook testing (optional)

### 2. App Configuration

Update `Services/LemonSqueezyManager.swift`:
```swift
static let monthlyVariantID = "YOUR_TEST_MONTHLY_VARIANT_ID"
static let annualVariantID = "YOUR_TEST_ANNUAL_VARIANT_ID"
```

## Manual Testing Scenarios

### Scenario 1: New User Subscribes via Web Checkout

**Steps:**
1. Create new test user account
2. Navigate to Paywall
3. Select Monthly plan
4. Tap "Web Checkout" button
5. Complete purchase with test card `4242 4242 4242 4242`
6. Return to app via deep link

**Expected Results:**
- [ ] Checkout URL opens in Safari
- [ ] Test payment succeeds
- [ ] Deep link returns to app automatically
- [ ] Premium activates within 5 seconds
- [ ] PaymentManager shows `isPremium = true`
- [ ] Current tier is `.premium`
- [ ] Success notification shown

**Verify:**
```swift
// In console or debugger
PaymentManager.shared.isPremium // Should be true
PaymentManager.shared.currentTier // Should be .premium
PaymentManager.shared.paymentSource // Should be .lemonSqueezy
```

---

### Scenario 2: User Subscribes to Annual Plan

**Steps:**
1. Create new test user account
2. Navigate to Paywall
3. Select Annual plan
4. Tap "Web Checkout"
5. Complete purchase

**Expected Results:**
- [ ] Annual plan activated
- [ ] Current tier is `.premiumAnnual`
- [ ] Order stored with correct variant ID

---

### Scenario 3: Webhook Handling

**Steps:**
1. Set up ngrok tunnel to local server
2. Configure webhook URL in LemonSqueezy to ngrok URL
3. Make a test purchase
4. Monitor webhook payload receipt

**Expected Results:**
- [ ] Webhook received within 5 seconds
- [ ] Signature verified successfully
- [ ] Order created event processed
- [ ] Order paid event processed
- [ ] Subscription created event processed
- [ ] User premium status updated

**Test Webhook Payload:**
```json
{
  "meta": {
    "event_name": "order_paid",
    "custom_data": {
      "user_id": "test-user-id"
    }
  },
  "data": {
    "id": "ord_test_123",
    "type": "orders",
    "attributes": {
      "order_number": 12345,
      "status": "paid",
      "custom_data": {
        "user_id": "test-user-id"
      }
    }
  }
}
```

---

### Scenario 4: Subscription Renewal

**Steps:**
1. Create active subscription
2. Trigger webhook `subscription_payment_success`
3. Verify renewal date updated

**Expected Results:**
- [ ] Renewal date extended
- [ ] Premium remains active
- [ ] Grace period cleared (if applicable)

---

### Scenario 5: Subscription Cancellation

**Steps:**
1. Create active subscription
2. Cancel subscription in LemonSqueezy customer portal
3. Receive `subscription_cancelled` webhook

**Expected Results:**
- [ ] Cancellation webhook received
- [ ] Premium remains active until period end
- [ ] User notified of upcoming cancellation
- [ ] Deactivation scheduled for end date

---

### Scenario 6: Subscription Expiration

**Steps:**
1. Have cancelled subscription nearing end date
2. Receive `subscription_expired` webhook

**Expected Results:**
- [ ] Premium deactivated
- [ ] User downgraded to free tier
- [ ] Appropriate UI updates shown

---

### Scenario 7: Failed Payment (Grace Period)

**Steps:**
1. Create active subscription
2. Trigger `subscription_payment_failed` webhook

**Expected Results:**
- [ ] Grace period entered (3 days)
- [ ] User notified of payment failure
- [ ] Premium features still accessible during grace period
- [ ] Warning shown in UI

---

### Scenario 8: Payment Recovery

**Steps:**
1. Have subscription in grace period
2. Trigger `subscription_payment_recovered` webhook

**Expected Results:**
- [ ] Grace period exited
- [ ] Premium re-confirmed
- [ ] Recovery notification shown

---

### Scenario 9: Configuration Validation

**Steps:**
1. Check configuration status

**Expected Results:**
```swift
let status = LemonSqueezyManager.shared.validateConfiguration()
// Should show all required fields as true when configured
```

---

### Scenario 10: Error Handling

**Test Cases:**

#### Missing User ID
- [ ] Webhook without user_id handled gracefully
- [ ] Error logged appropriately
- [ ] No crash occurs

#### Invalid Signature
- [ ] Webhook with invalid signature rejected
- [ ] 401 response returned
- [ ] Error notification sent

#### Network Failure
- [ ] App handles network errors gracefully
- [ ] Retry mechanism works
- [ ] User-friendly error messages shown

---

## Automated Testing

### Unit Tests

Create test file: `Tests/LemonSqueezyTests.swift`

```swift
import XCTest
@testable import Pausely

class LemonSqueezyTests: XCTestCase {
    
    func testConfigurationValidation() {
        let manager = LemonSqueezyManager.shared
        let status = manager.validateConfiguration()
        
        // Test with valid config
        XCTAssertNotNil(status)
    }
    
    func testSignatureVerification() {
        let handler = LemonSqueezyWebhookHandler.shared
        let payload = "test payload".data(using: .utf8)!
        let secret = "test_secret"
        
        // Create valid signature
        let signature = createSignature(payload: payload, secret: secret)
        
        // Test verification
        let result = handler.verifySignature(payload: payload, signature: signature)
        XCTAssertTrue(result)
    }
    
    func testTierDetection() {
        XCTAssertEqual(SubscriptionTier.fromVariantID(LemonSqueezyConfig.monthlyVariantID), .premium)
        XCTAssertEqual(SubscriptionTier.fromVariantID(LemonSqueezyConfig.annualVariantID), .premiumAnnual)
    }
    
    private func createSignature(payload: Data, secret: String) -> String {
        let key = SymmetricKey(data: secret.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return Data(signature).base64EncodedString()
    }
}
```

### UI Tests

```swift
func testPaywallWebCheckout() {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to paywall
    app.buttons["Upgrade"].tap()
    
    // Select plan
    app.buttons["Monthly"].tap()
    
    // Open web checkout
    app.buttons["Web Checkout"].tap()
    
    // Verify Safari opens
    XCTAssertTrue(app.otherElements["Safari"].waitForExistence(timeout: 5))
}
```

---

## Webhook Testing with cURL

### Test Order Paid Webhook

```bash
curl -X POST https://your-webhook-url.com/webhooks/lemon-squeezy \
  -H "Content-Type: application/json" \
  -H "X-Signature: YOUR_SIGNATURE" \
  -d '{
    "meta": {
      "event_name": "order_paid",
      "custom_data": {"user_id": "test-user-123"}
    },
    "data": {
      "id": "ord_test_123",
      "type": "orders",
      "attributes": {
        "order_number": 12345,
        "status": "paid",
        "custom_data": {"user_id": "test-user-123"},
        "first_order_item": {
          "id": "ord_item_123",
          "variant_id": 12345,
          "subscription": {
            "id": "sub_123",
            "renews_at": "2024-12-31T00:00:00Z"
          }
        }
      }
    }
  }'
```

### Test Subscription Cancelled

```bash
curl -X POST https://your-webhook-url.com/webhooks/lemon-squeezy \
  -H "Content-Type: application/json" \
  -H "X-Signature: YOUR_SIGNATURE" \
  -d '{
    "meta": {
      "event_name": "subscription_cancelled",
      "custom_data": {"user_id": "test-user-123"}
    },
    "data": {
      "id": "sub_123",
      "type": "subscriptions",
      "attributes": {
        "status": "cancelled",
        "ends_at": "2024-12-31T00:00:00Z",
        "custom_data": {"user_id": "test-user-123"}
      }
    }
  }'
```

---

## Debugging Tips

### Enable Verbose Logging

Add to `LemonSqueezyManager.swift`:
```swift
#if DEBUG
print("📤 API Request: \(request.url?.absoluteString ?? "unknown")")
print("📥 API Response: \(String(data: data, encoding: .utf8) ?? "no data")")
#endif
```

### Check Pending Checkouts

```swift
// In debugger
LemonSqueezyManager.shared.pendingCheckout
```

### Verify Stored Data

```swift
// Check UserDefaults
UserDefaults.standard.dictionaryRepresentation()
    .filter { $0.key.contains("lemon_squeezy") }
```

---

## Performance Testing

### Load Testing Webhooks

Use Apache Bench (ab) or similar:
```bash
ab -n 1000 -c 10 -p webhook_payload.json -T application/json \
   -H "X-Signature: signature" \
   https://your-webhook-url.com/webhooks/lemon-squeezy
```

### Expected Performance

- Webhook processing: < 500ms
- Checkout URL generation: < 100ms
- Order verification: < 1s
- Deep link handling: < 100ms

---

## Security Testing

### Test Signature Validation

```swift
// Invalid signature should fail
let invalidPayload = "tampered".data(using: .utf8)!
let result = verifySignature(payload: invalidPayload, signature: "valid_sig", secret: "secret")
assert(!result)
```

### Test Replay Attack Prevention

- [ ] Same webhook payload with new timestamp handled
- [ ] Duplicate event IDs detected and ignored
- [ ] Idempotency key checked

---

## Production Readiness Checklist

Before deploying to production:

### Configuration
- [ ] Production API key configured
- [ ] Production webhook secret configured
- [ ] Production variant IDs set
- [ ] Webhook URL is HTTPS
- [ ] Deep link URL scheme registered

### Security
- [ ] Webhook signatures verified
- [ ] API keys not in version control
- [ ] Secrets stored in Keychain/secure storage
- [ ] HTTPS enforced for all endpoints

### Error Handling
- [ ] All error cases handled gracefully
- [ ] User-friendly error messages
- [ ] Error tracking integrated (Sentry, Crashlytics)
- [ ] Fallback mechanisms in place

### Testing
- [ ] All test scenarios passed
- [ ] Edge cases handled
- [ ] Performance requirements met
- [ ] Security audit completed

### Monitoring
- [ ] Webhook logs configured
- [ ] Payment analytics set up
- [ ] Error alerting configured
- [ ] Dashboard created

---

## Common Issues & Solutions

### Issue: "Invalid API Key"

**Cause:** Using test key in production or vice versa

**Solution:**
- Check environment configuration
- Verify key has correct permissions
- Regenerate key if necessary

### Issue: "Webhook not received"

**Cause:** URL not accessible, firewall blocking

**Solution:**
- Verify webhook URL is publicly accessible
- Check server logs for incoming requests
- Test with curl/Postman

### Issue: "Premium not activating"

**Cause:** User ID mismatch, webhook not processed

**Solution:**
- Check custom_data contains correct user_id
- Verify webhook signature
- Check error logs

### Issue: "Checkout URL not working"

**Cause:** Invalid variant ID, unpublished product

**Solution:**
- Verify variant ID is correct
- Ensure product is published in LemonSqueezy
- Check store URL format

---

## Support Resources

- **LemonSqueezy Docs**: https://docs.lemonsqueezy.com
- **API Reference**: https://docs.lemonsqueezy.com/api
- **Webhook Guide**: https://docs.lemonsqueezy.com/guides/webhooks
- **Test Cards**: https://docs.lemonsqueezy.com/guides/testing
- **Discord Community**: https://discord.gg/lemonsqueezy

---

## Sign-Off

| Tester | Date | Result |
|--------|------|--------|
|        |      | ⬜ Pass / ⬜ Fail |

Notes:
