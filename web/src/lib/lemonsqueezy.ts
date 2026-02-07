// LemonSqueezy Payment Integration
// Configure these in your Supabase environment variables or .env file

const LEMONSQUEEZY_STORE_ID = import.meta.env.VITE_LEMONSQUEEZY_STORE_ID || ''
const LEMONSQUEEZY_PRO_VARIANT_ID = import.meta.env.VITE_LEMONSQUEEZY_PRO_VARIANT_ID || ''

export interface LemonSqueezyConfig {
  storeId: string
  proVariantId: string
  checkoutUrl: string
}

export function getLemonSqueezyConfig(): LemonSqueezyConfig {
  return {
    storeId: LEMONSQUEEZY_STORE_ID,
    proVariantId: LEMONSQUEEZY_PRO_VARIANT_ID,
    checkoutUrl: `https://pausely.lemonsqueezy.com/checkout/buy/${LEMONSQUEEZY_PRO_VARIANT_ID}`
  }
}

// Generate checkout URL with custom data
export function generateCheckoutUrl(userId: string, email: string): string {
  const config = getLemonSqueezyConfig()
  const params = new URLSearchParams({
    'checkout[custom][user_id]': userId,
    'checkout[email]': email,
    'checkout[redirect_url]': `${window.location.origin}/dashboard?payment=success`,
    'checkout[cancel_url]': `${window.location.origin}/dashboard?payment=cancelled`
  })
  
  return `${config.checkoutUrl}?${params.toString()}`
}

// Plan details
export const PLANS = {
  free: {
    id: 'free',
    name: 'Free',
    price: 0,
    description: 'Get started with subscription tracking',
    features: [
      'Track up to 2 subscriptions',
      'Basic AI insights',
      'Monthly spending overview',
      'Email notifications'
    ],
    limits: {
      subscriptions: 2,
      aiRequests: 5,
      cancellationDrafts: 2
    }
  },
  pro: {
    id: 'pro',
    name: 'Pro',
    price: 4.99,
    priceYearly: 49.99,
    description: 'Unlimited subscription management',
    features: [
      'Unlimited subscriptions',
      'Full AI features',
      'Cancellation agent',
      'Smart pausing',
      'Daily AI briefings',
      'Priority support',
      'Advanced analytics'
    ],
    limits: {
      subscriptions: Infinity,
      aiRequests: Infinity,
      cancellationDrafts: Infinity
    }
  }
}

// Open checkout in new window
export function openCheckout(userId: string, email: string): void {
  const checkoutUrl = generateCheckoutUrl(userId, email)
  window.open(checkoutUrl, '_blank', 'noopener,noreferrer')
}

// Handle successful payment callback
export async function handlePaymentSuccess(
  subscriptionId: string,
  customerId: string,
  userId: string
): Promise<boolean> {
  try {
    // Update user's profile to pro plan
    const { supabase } = await import('./supabase')
    const { error } = await supabase
      .from('user_profiles')
      .update({
        plan_type: 'pro',
        lemonsqueezy_subscription_id: subscriptionId,
        lemonsqueezy_customer_id: customerId,
        updated_at: new Date().toISOString()
      })
      .eq('user_id', userId)
    
    if (error) {
      console.error('Error updating user plan:', error)
      return false
    }
    
    return true
  } catch (error) {
    console.error('Error handling payment success:', error)
    return false
  }
}

// Webhook handler for LemonSqueezy (to be used in Edge Function)
export interface LemonSqueezyWebhookPayload {
  meta: {
    event_name: string
    custom_data?: {
      user_id: string
    }
  }
  data: {
    id: string
    attributes: {
      customer_id: string
      status: string
      product_name: string
      variant_name: string
    }
  }
}
