import { useState } from 'react'
import { Link2, Search, Gift, TrendingDown, Check } from 'lucide-react'

const steps = [
  {
    number: '01',
    title: 'Connect Your Accounts',
    description: 'Securely link your bank accounts in seconds. We use Plaid, the same technology Venmo and Robinhood use. Your credentials are never stored on our servers.',
    icon: Link2,
    color: 'bg-blue-500',
    lightColor: 'bg-blue-500/10',
    textColor: 'text-blue-400'
  },
  {
    number: '02',
    title: 'Discover Hidden Subscriptions',
    description: 'Our AI scans your transactions and identifies every recurring charge — even ones you forgot about. The average user finds 12+ forgotten subscriptions.',
    icon: Search,
    color: 'bg-purple-500',
    lightColor: 'bg-purple-500/10',
    textColor: 'text-purple-400'
  },
  {
    number: '03',
    title: 'Find Free Alternatives',
    description: 'We cross-reference your subscriptions with perks you already have. Credit card benefits, employer programs, library access — most people have $50-100/month in unused free services.',
    icon: Gift,
    color: 'bg-green-500',
    lightColor: 'bg-green-500/10',
    textColor: 'text-green-400'
  },
  {
    number: '04',
    title: 'Pause or Optimize',
    description: 'Choose to pause subscriptions instead of canceling, or switch to free alternatives. Our one-click actions save you hours of customer service calls.',
    icon: TrendingDown,
    color: 'bg-orange-500',
    lightColor: 'bg-orange-500/10',
    textColor: 'text-orange-400'
  }
]

export default function HowItWorks() {
  const [activeStep, setActiveStep] = useState(0)

  return (
    <section id="how-it-works" className="section bg-black overflow-hidden">
      <div className="container">
        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-16 md:mb-24">
          <p className="caption mb-4 md:mb-6">How It Works</p>
          <h2 className="headline-medium">
            Save money in{' '}
            <span className="gradient-text">four simple steps.</span>
          </h2>
        </div>

        {/* Desktop Layout */}
        <div className="hidden lg:grid lg:grid-cols-2 gap-16 items-center">
          {/* Left Side - Steps List */}
          <div className="space-y-4">
            {steps.map((step, index) => {
              const isActive = index === activeStep
              const StepIcon = step.icon

              return (
                <button
                  key={index}
                  onClick={() => setActiveStep(index)}
                  className={`w-full text-left p-6 rounded-2xl transition-all duration-300 ${
                    isActive 
                      ? 'bg-white/5 border border-white/10' 
                      : 'hover:bg-white/[0.02] border border-transparent'
                  }`}
                >
                  <div className="flex items-start gap-5">
                    {/* Number Badge */}
                    <div className={`flex-shrink-0 w-12 h-12 rounded-xl ${step.lightColor} flex items-center justify-center`}>
                      <StepIcon className={`w-6 h-6 ${step.textColor}`} />
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <span className={`text-xs font-bold px-2 py-1 rounded ${step.lightColor} ${step.textColor}`}>
                          {step.number}
                        </span>
                      </div>
                      
                      <h3 className={`text-xl font-semibold mb-2 transition-colors ${
                        isActive ? 'text-white' : 'text-white/70'
                      }`}>
                        {step.title}
                      </h3>
                      
                      <p className={`text-base leading-relaxed transition-all duration-300 ${
                        isActive ? 'text-white/60 max-h-40' : 'text-white/40 max-h-0 overflow-hidden'
                      }`}>
                        {step.description}
                      </p>
                    </div>

                    {/* Checkmark for completed steps */}
                    <div className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center transition-all ${
                      index < activeStep 
                        ? 'bg-green-500/20 text-green-400' 
                        : isActive 
                          ? 'bg-white/10 text-white' 
                          : 'bg-white/5 text-white/30'
                    }`}>
                      {index < activeStep ? (
                        <Check className="w-4 h-4" />
                      ) : (
                        <span className="text-xs">{step.number}</span>
                      )}
                    </div>
                  </div>
                </button>
              )
            })}
          </div>

          {/* Right Side - Visual */}
          <div className="relative">
            <div className="relative aspect-square max-w-lg mx-auto">
              {/* Background Glow */}
              <div 
                className="absolute inset-0 rounded-full opacity-40 blur-3xl transition-colors duration-700"
                style={{
                  background: `radial-gradient(circle, ${
                    activeStep === 0 ? 'rgba(59,130,246,0.5)' :
                    activeStep === 1 ? 'rgba(168,85,247,0.5)' :
                    activeStep === 2 ? 'rgba(34,197,94,0.5)' :
                    'rgba(249,115,22,0.5)'
                  }, transparent 60%)`
                }}
              />

              {/* Central Icon */}
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="relative w-56 h-56">
                  {steps.map((step, index) => {
                    const StepIcon = step.icon
                    const isActive = index === activeStep

                    return (
                      <div
                        key={index}
                        className={`absolute inset-0 flex items-center justify-center transition-all duration-500 ${
                          isActive ? 'opacity-100 scale-100' : 'opacity-0 scale-90'
                        }`}
                      >
                        <div className={`w-44 h-44 rounded-3xl ${step.lightColor} backdrop-blur-xl border border-white/10 flex items-center justify-center`}
                        >
                          <StepIcon className={`w-20 h-20 ${step.textColor}`} />
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            </div>

            {/* Step Indicator */}
            <div className="flex items-center justify-center gap-3 mt-8">
              {steps.map((_, index) => (
                <button
                  key={index}
                  onClick={() => setActiveStep(index)}
                  className={`h-2 rounded-full transition-all duration-300 ${
                    index === activeStep ? 'w-10 bg-white' : 'w-2 bg-white/20 hover:bg-white/40'
                  }`}
                  aria-label={`Go to step ${index + 1}`}
                />
              ))}
            </div>
          </div>
        </div>

        {/* Mobile Layout - Vertical Cards */}
        <div className="lg:hidden space-y-5">
          {steps.map((step, index) => {
            const StepIcon = step.icon

            return (
              <div
                key={index}
                className="bg-[#1c1c1e] rounded-3xl p-6 border border-white/[0.06]"
              >
                <div className="flex items-start gap-4">
                  {/* Icon */}
                  <div className={`flex-shrink-0 w-14 h-14 rounded-2xl ${step.lightColor} flex items-center justify-center`}>
                    <StepIcon className={`w-7 h-7 ${step.textColor}`} />
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-2">
                      <span className={`text-xs font-bold px-2 py-1 rounded ${step.lightColor} ${step.textColor}`}>
                        {step.number}
                      </span>
                    </div>
                    
                    <h3 className="text-xl font-semibold mb-3">{step.title}</h3>
                    
                    <p className="text-white/60 text-base leading-relaxed">
                      {step.description}
                    </p>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
