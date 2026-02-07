import { useState } from 'react'
import { Check } from 'lucide-react'

const plans = [
  {
    name: 'Free',
    priceMonthly: 0,
    priceYearly: 0,
    period: 'forever',
    features: [
      '2 bank accounts',
      '10 subscriptions',
      'Basic insights',
      'Email reports',
    ],
    cta: 'Get Started',
    popular: false
  },
  {
    name: 'Pro',
    priceMonthly: 4.99,
    priceYearly: 3.99,
    period: '/month',
    features: [
      'Unlimited accounts',
      'Unlimited subscriptions',
      'AI Cancellation Agent',
      'AI Smart Pausing',
      'AI Daily Briefing',
      'Priority support',
    ],
    cta: 'Start Trial',
    popular: true
  },
]

export default function Pricing() {
  const [isYearly, setIsYearly] = useState(false)

  const getPrice = (plan: typeof plans[0]) => {
    if (plan.priceMonthly === 0) return '$0'
    const price = isYearly ? plan.priceYearly : plan.priceMonthly
    return `$${price.toFixed(2)}`
  }

  return (
    <section id="pricing" className="section">
      <div className="container max-w-4xl">
        {/* Header */}
        <div className="text-center mb-24">
          <p className="caption mb-6">Pricing</p>
          <h2 className="headline-medium mb-8">
            Simple pricing.
          </h2>

          {/* Toggle */}
          <div className="inline-flex items-center gap-4 p-2 rounded-full glass">
            <button 
              onClick={() => setIsYearly(false)}
              className={`px-6 py-2.5 rounded-full text-sm font-medium transition-all duration-300 ${
                !isYearly ? 'bg-white text-black' : 'text-white/60 hover:text-white'
              }`}
            >
              Monthly
            </button>
            <button 
              onClick={() => setIsYearly(true)}
              className={`px-6 py-2.5 rounded-full text-sm font-medium transition-all duration-300 flex items-center gap-2 ${
                isYearly ? 'bg-white text-black' : 'text-white/60 hover:text-white'
              }`}
            >
              Yearly
              <span className="text-xs bg-green-500/20 text-green-400 px-2 py-1 rounded-full font-semibold">Save 20%</span>
            </button>
          </div>
        </div>

        {/* Plans */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          {plans.map((plan) => (
            <div
              key={plan.name}
              className={`p-10 rounded-3xl ${
                plan.popular 
                  ? 'bg-white text-black' 
                  : 'glass'
              }`}
            >
              <div className="mb-10">
                <p className={`text-sm font-medium mb-3 ${plan.popular ? 'text-black/50' : 'text-white/50'}`}>
                  {plan.name}
                </p>
                <div className="flex items-baseline gap-1">
                  <span className="text-6xl font-bold">
                    {getPrice(plan)}
                  </span>
                  <span className={`text-base ${plan.popular ? 'text-black/50' : 'text-white/40'}`}>
                    {plan.priceMonthly === 0 ? '' : isYearly ? '/month (billed yearly)' : '/month'}
                  </span>
                </div>
              </div>

              <ul className="space-y-4 mb-10">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-center gap-4">
                    <Check className={`w-5 h-5 ${plan.popular ? 'text-black/40' : 'text-white/30'}`} />
                    <span className={`text-base ${plan.popular ? 'text-black/70' : 'text-white/60'}`}>{feature}</span>
                  </li>
                ))}
              </ul>

              <button
                className={`w-full py-4 rounded-full font-medium text-base transition-all ${
                  plan.popular
                    ? 'bg-black text-white hover:bg-black/80'
                    : 'bg-white text-black hover:bg-white/90'
                }`}
                onClick={() => document.querySelector('#cta')?.scrollIntoView({ behavior: 'smooth' })}
              >
                {plan.cta}
              </button>
            </div>
          ))}
        </div>

        <p className="text-center mt-16 text-white/40 text-sm">
          14-day free trial • Cancel anytime
        </p>
      </div>
    </section>
  )
}
