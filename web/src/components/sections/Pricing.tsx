import { useState } from 'react'
import { Check } from 'lucide-react'

const plans = [
  {
    name: 'Free',
    price: '$0',
    period: 'forever',
    features: [
      '2 bank accounts',
      '10 subscriptions',
      'Basic insights',
    ],
    cta: 'Get Started',
    popular: false
  },
  {
    name: 'Pro',
    price: '$4.99',
    period: '/month',
    features: [
      'Unlimited accounts',
      'Unlimited subscriptions',
      'AI insights',
      'Free perk discovery',
      'Priority support',
    ],
    cta: 'Start Trial',
    popular: true
  },
]

export default function Pricing() {
  const [isYearly, setIsYearly] = useState(false)

  return (
    <section id="pricing" className="section">
      <div className="container max-w-4xl">
        {/* Header */}
        <div className="text-center mb-16">
          <p className="caption mb-4">Pricing</p>
          <h2 className="headline-medium mb-6">
            Simple pricing.
          </h2>

          {/* Toggle */}
          <div className="flex items-center justify-center gap-3">
            <button 
              onClick={() => setIsYearly(false)}
              className={`text-sm ${!isYearly ? 'text-white' : 'text-white/50'}`}
            >
              Monthly
            </button>
            <button 
              onClick={() => setIsYearly(true)}
              className={`text-sm ${isYearly ? 'text-white' : 'text-white/50'}`}
            >
              Yearly
              <span className="ml-2 text-xs text-green-400">Save 20%</span>
            </button>
          </div>
        </div>

        {/* Plans */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {plans.map((plan) => (
            <div
              key={plan.name}
              className={`p-8 rounded-3xl ${
                plan.popular 
                  ? 'bg-white text-black' 
                  : 'bg-[#0c0c0e]'
              }`}
            >
              <div className="mb-8">
                <h3 className="text-lg font-medium mb-2">{plan.name}</h3>
                <div className="flex items-baseline gap-1">
                  <span className="text-5xl font-semibold">
                    {isYearly && plan.price !== '$0' 
                      ? `$${(parseFloat(plan.price.replace('$', '')) * 0.8).toFixed(0)}`
                      : plan.price
                    }
                  </span>
                  <span className={`text-sm ${plan.popular ? 'text-black/60' : 'text-white/50'}`}>
                    {plan.period}
                  </span>
                </div>
              </div>

              <ul className="space-y-3 mb-8">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-center gap-3">
                    <Check className={`w-5 h-5 ${plan.popular ? 'text-black/60' : 'text-white/40'}`} />
                    <span className={plan.popular ? 'text-black/80' : 'text-white/70'}>{feature}</span>
                  </li>
                ))}
              </ul>

              <button
                className={`w-full py-4 rounded-full font-medium ${
                  plan.popular
                    ? 'bg-black text-white'
                    : 'bg-white text-black'
                }`}
                onClick={() => document.querySelector('#cta')?.scrollIntoView({ behavior: 'smooth' })}
              >
                {plan.cta}
              </button>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
