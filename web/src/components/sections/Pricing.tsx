import { useState } from 'react'
import { Check } from 'lucide-react'

type Currency = 'USD' | 'CAD'

const plans = [
  {
    name: 'Free',
    prices: { USD: 0, CAD: 0 },
    features: [
      '2 subscriptions only',
      'Basic insights',
      'Email reports',
    ],
    cta: 'Get Started',
    popular: false
  },
  {
    name: 'Pro',
    prices: { USD: 4.99, CAD: 6.83 },
    features: [
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
  const [currency, setCurrency] = useState<Currency>('USD')

  const getPrice = (plan: typeof plans[0]) => {
    if (plan.prices.USD === 0) return '$0'
    return `$${plan.prices[currency].toFixed(2)} ${currency}`
  }

  return (
    <section id="pricing" className="section">
      <div className="container max-w-5xl">
        <div className="text-center mb-20">
          <p className="caption mb-6">Pricing</p>
          <h2 className="headline-medium mb-12">Simple pricing.</h2>

          <div className="inline-flex items-center gap-4 p-2 rounded-full glass">
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
          {plans.map((plan) => (
            <div
              key={plan.name}
              className={`p-8 lg:p-12 rounded-3xl ${plan.popular ? 'bg-white text-black' : 'glass'}`}
            >
              <div className="mb-8">
                <p className={`text-sm font-medium mb-2 ${plan.popular ? 'text-black/50' : 'text-white/50'}`}>
                  {plan.name}
                </p>
                <div className="flex items-baseline gap-2">
                  <span className="text-5xl lg:text-6xl font-bold">{getPrice(plan)}</span>
                  {plan.prices.USD !== 0 && (
                    <span className={`text-base ${plan.popular ? 'text-black/50' : 'text-white/40'}`}>
                      /month
                    </span>
                  )}
                </div>
              </div>

              <ul className="space-y-4 mb-10">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-start gap-4">
                    <Check className={`w-5 h-5 mt-0.5 ${plan.popular ? 'text-black/40' : 'text-white/30'}`} />
                    <span className={`text-base leading-relaxed ${plan.popular ? 'text-black/70' : 'text-white/60'}`}>
                      {feature}
                    </span>
                  </li>
                ))}
              </ul>

              <button
                className={`w-full py-4 rounded-full font-medium text-base transition-all ${
                  plan.popular ? 'bg-black text-white hover:bg-black/80' : 'bg-white text-black hover:bg-white/90'
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
