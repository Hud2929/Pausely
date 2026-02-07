import { useState } from 'react'
import { Check, Crown } from 'lucide-react'

interface PricingProps {
  onGetStarted?: () => void
}

type Currency = 'USD' | 'CAD'
type BillingPeriod = 'monthly' | 'yearly'

// Pricing configuration

const PRICES = {
  monthly: { USD: 4.99, CAD: 6.83 },
  yearly: { USD: 49.99, CAD: 68.50 }
}

const PLANS = {
  free: {
    id: 'free',
    name: 'Free',
    price: 0,
    features: [
      '2 subscriptions only',
      'Basic insights',
      'Email reports'
    ]
  },
  pro: {
    id: 'pro', 
    name: 'Pro',
    features: [
      '- Unlimited subscriptions',
      '- AI Cancellation Agent',
      '- AI Smart Pausing',
      '- AI Daily Briefing',
      '- Priority support',
      '- 7-day free trial'
    ]
  }
}

export default function Pricing({ onGetStarted }: PricingProps) {
  const [currency, setCurrency] = useState<Currency>('USD')
  const [billingPeriod, setBillingPeriod] = useState<BillingPeriod>('monthly')

  const getPrice = () => {
    const price = PRICES[billingPeriod][currency]
    return `$${price.toFixed(2)}`
  }

  const getYearlySavings = () => {
    const monthlyTotal = PRICES.monthly[currency] * 12
    const yearlyTotal = PRICES.yearly[currency]
    const savings = monthlyTotal - yearlyTotal
    return `$${savings.toFixed(0)}`
  }

  const handlePlanSelect = () => {
    onGetStarted?.()
  }

  return (
    <section id="pricing" className="section">
      <div className="container max-w-5xl">
        <div className="text-center mb-20">
          <p className="caption mb-6">Pricing</p>
          <h2 className="headline-medium mb-12">Simple pricing.</h2>

          {/* Currency Toggle */}
          <div className="inline-flex items-center gap-4 p-2 rounded-full glass mb-8">
            <button 
              onClick={() => setCurrency('USD')}
              className={`px-6 py-2.5 rounded-full text-sm font-medium transition-all ${
                currency === 'USD' ? 'bg-white text-black' : 'text-white/60 hover:text-white'
              }`}
            >
              USD
            </button>
            <button 
              onClick={() => setCurrency('CAD')}
              className={`px-6 py-2.5 rounded-full text-sm font-medium transition-all ${
                currency === 'CAD' ? 'bg-white text-black' : 'text-white/60 hover:text-white'
              }`}
            >
              CAD
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 lg:gap-12">
          {/* Free Plan */}
          <div className="p-8 lg:p-10 rounded-3xl glass">
            <div className="mb-6">
              <p className="text-sm font-medium mb-1 text-white/50">{PLANS.free.name}</p>
              <div className="flex items-baseline gap-2">
                <span className="text-4xl lg:text-5xl font-bold">Free</span>
              </div>
            </div>

            <ul className="space-y-3 mb-8">
              {PLANS.free.features.map((feature) => (
                <li key={feature} className="flex items-start gap-3">
                  <Check className="w-4 h-4 mt-0.5 text-white/30 flex-shrink-0" />
                  <span className="text-sm text-white/60">{feature}</span>
                </li>
              ))}
            </ul>

            <button
              onClick={() => handlePlanSelect()}
              className="w-full py-3 rounded-full font-medium text-sm transition-all bg-white text-black hover:bg-white/90"
            >
              Get Started
            </button>
          </div>

          {/* Pro Plan */}
          <div className="relative p-8 lg:p-12 rounded-3xl bg-gradient-to-br from-white to-gray-100 text-black">
            {/* Most Popular Badge - Top right */}
            <div className="absolute -top-3 right-8">
              <span className="inline-flex items-center gap-1 px-3 py-1 rounded-full bg-gradient-to-r from-yellow-400 to-orange-500 text-white text-xs font-medium">
                <Crown className="w-3 h-3" />
                Most Popular
              </span>
            </div>

            <div className="mb-5 pl-10 pt-2">
              <p className="text-base font-semibold mb-2 text-black/70">{PLANS.pro.name}</p>
              
              {/* Billing Period Toggle */}
              <div className="inline-flex items-center gap-2 p-1.5 rounded-full bg-black/5 mb-4">
                <button
                  onClick={() => setBillingPeriod('monthly')}
                  className={`px-4 py-2 rounded-full text-sm font-medium transition-all ${
                    billingPeriod === 'monthly' 
                      ? 'bg-black text-white' 
                      : 'text-black/60 hover:text-black'
                  }`}
                >
                  Monthly
                </button>
                <button
                  onClick={() => setBillingPeriod('yearly')}
                  className={`px-4 py-2 rounded-full text-sm font-medium transition-all flex items-center gap-1.5 ${
                    billingPeriod === 'yearly' 
                      ? 'bg-black text-white' 
                      : 'text-black/60 hover:text-black'
                  }`}
                >
                  Yearly
                  <span className="text-xs bg-green-500 text-white px-2 py-0.5 rounded-full">Save {getYearlySavings()}</span>
                </button>
              </div>

              <div className="flex items-baseline gap-2">
                <span className="text-5xl lg:text-6xl font-bold">{getPrice()}</span>
                <span className="text-base text-black/50">/{billingPeriod === 'monthly' ? 'month' : 'year'}</span>
              </div>
              
              {billingPeriod === 'yearly' && (
                <p className="text-sm text-green-600 mt-2 font-medium">
                  You save {getYearlySavings()} per year
                </p>
              )}
            </div>

            <ul className="space-y-4 mb-10 pl-10">
              {PLANS.pro.features.map((feature) => (
                <li key={feature} className="flex items-start gap-3">
                  <Check className="w-5 h-5 mt-0.5 text-black/40 flex-shrink-0" />
                  <span className="text-base text-black/70">{feature}</span>
                </li>
              ))}
            </ul>

            <div className="px-10">
              <button
                onClick={() => handlePlanSelect()}
                className="w-full py-4 rounded-full font-medium text-base transition-all bg-black text-white hover:bg-black/80"
              >
                Start Free Trial
              </button>
            </div>
          </div>
        </div>

        <div className="text-center mt-16 space-y-2">
          <p className="text-white/40 text-sm">7-day free trial • Cancel anytime • No credit card required</p>
        </div>
      </div>
    </section>
  )
}
