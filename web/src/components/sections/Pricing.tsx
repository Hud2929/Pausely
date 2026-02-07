import { useState } from 'react'
import { Check, Sparkles } from 'lucide-react'

const plans = [
  {
    name: 'Free',
    description: 'Perfect for getting started',
    price: '$0',
    period: 'forever',
    features: [
      'Connect up to 2 bank accounts',
      'Track up to 10 subscriptions',
      'Basic spending insights',
      'Monthly email reports',
      'Community support'
    ],
    cta: 'Get Started',
    popular: false
  },
  {
    name: 'Pro',
    description: 'For serious savers',
    price: '$4.99',
    period: 'per month',
    features: [
      'Unlimited bank accounts',
      'Unlimited subscriptions',
      'AI-powered insights',
      'Free perk discovery',
      'Pause recommendations',
      'Weekly email reports',
      'Priority support',
      'Export data (CSV/PDF)'
    ],
    cta: 'Start Free Trial',
    popular: true
  },
  {
    name: 'Family',
    description: 'Share with your household',
    price: '$9.99',
    period: 'per month',
    features: [
      'Everything in Pro',
      'Up to 6 family members',
      'Shared dashboard',
      'Family spending insights',
      'Custom categories',
      'API access',
      'Dedicated support',
      'White-label reports'
    ],
    cta: 'Start Free Trial',
    popular: false
  }
]

export default function Pricing() {
  const [billingCycle, setBillingCycle] = useState<'monthly' | 'yearly'>('monthly')

  return (
    <section id="pricing" className="section bg-[#0a0a0a]">
      <div className="container">
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <p className="caption mb-4">Pricing</p>
          <h2 className="headline-medium mb-6">
            Simple pricing,{' '}
            <span className="gradient-text">massive savings.</span>
          </h2>
          <p className="body-large">
            Start free, upgrade when you're ready. Most users save 10x their subscription cost in the first month.
          </p>

          {/* Billing Toggle */}
          <div className="flex items-center justify-center gap-4 mt-8">
            <button
              onClick={() => setBillingCycle('monthly')}
              className={`px-6 py-2 rounded-full text-sm font-medium transition-all ${
                billingCycle === 'monthly' 
                  ? 'bg-white text-black' 
                  : 'text-white/60 hover:text-white'
              }`}
            >
              Monthly
            </button>
            <button
              onClick={() => setBillingCycle('yearly')}
              className={`px-6 py-2 rounded-full text-sm font-medium transition-all flex items-center gap-2 ${
                billingCycle === 'yearly' 
                  ? 'bg-white text-black' 
                  : 'text-white/60 hover:text-white'
              }`}
            >
              Yearly
              <span className="text-xs bg-green-500 text-black px-2 py-0.5 rounded-full">Save 20%</span>
            </button>
          </div>
        </div>

        {/* Pricing Cards */}
        <div className="grid grid-3 gap-6 max-w-5xl mx-auto">
          {plans.map((plan, index) => (
            <div
              key={index}
              className={`relative rounded-3xl p-8 transition-all duration-500 ${
                plan.popular 
                  ? 'bg-gradient-to-b from-[#1c1c1e] to-[#161618] border-2 border-blue-500/50 scale-105 shadow-2xl shadow-blue-500/10' 
                  : 'bg-[#1c1c1e] border border-white/5 hover:border-white/10'
              }`}
            >
              {/* Popular Badge */}
              {plan.popular && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2">
                  <div className="flex items-center gap-1.5 bg-blue-500 text-white text-xs font-medium px-4 py-1.5 rounded-full">
                    <Sparkles className="w-3.5 h-3.5" />
                    Most Popular
                  </div>
                </div>
              )}

              {/* Plan Name */}
              <h3 className="text-xl font-semibold mb-2">{plan.name}</h3>
              <p className="text-sm text-white/50 mb-6">{plan.description}</p>

              {/* Price */}
              <div className="mb-8">
                <span className="text-5xl font-bold">
                  {billingCycle === 'yearly' && plan.price !== '$0' 
                    ? `$${(parseFloat(plan.price.replace('$', '')) * 0.8).toFixed(2)}`
                    : plan.price
                  }
                </span>
                <span className="text-white/40 text-sm">/{plan.period}</span>
              </div>

              {/* CTA Button */}
              <button
                className={`w-full py-4 rounded-xl font-medium mb-8 transition-all ${
                  plan.popular
                    ? 'bg-blue-500 text-white hover:bg-blue-600'
                    : 'bg-white/10 text-white hover:bg-white/20'
                }`}
                onClick={() => document.querySelector('#cta')?.scrollIntoView({ behavior: 'smooth' })}
              >
                {plan.cta}
              </button>

              {/* Features */}
              <ul className="space-y-4">
                {plan.features.map((feature, i) => (
                  <li key={i} className="flex items-start gap-3">
                    <div className={`w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5 ${
                      plan.popular ? 'bg-blue-500/20' : 'bg-white/10'
                    }`}>
                      <Check className={`w-3 h-3 ${plan.popular ? 'text-blue-400' : 'text-white/60'}`} />
                    </div>
                    <span className="text-sm text-white/70">{feature}</span>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Trust Badge */}
        <div className="mt-16 text-center">
          <p className="text-white/40 text-sm">
            14-day free trial • No credit card required • Cancel anytime
          </p>
        </div>
      </div>
    </section>
  )
}
