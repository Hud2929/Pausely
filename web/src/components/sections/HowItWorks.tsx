import { useEffect, useRef, useState } from 'react'
import { Link2, Search, PauseCircle, TrendingDown } from 'lucide-react'

const steps = [
  {
    number: '01',
    title: 'Connect Your Accounts',
    description: 'Securely link your bank accounts in seconds. We use Plaid, the same technology Venmo and Robinhood use. Your credentials are never stored on our servers.',
    icon: Link2,
    color: 'blue'
  },
  {
    number: '02',
    title: 'Discover Hidden Subscriptions',
    description: 'Our AI scans your transactions and identifies every recurring charge — even ones you forgot about. The average user finds 12+ forgotten subscriptions.',
    icon: Search,
    color: 'purple'
  },
  {
    number: '03',
    title: 'Find Free Alternatives',
    description: 'We cross-reference your subscriptions with perks you already have. Credit card benefits, employer programs, library access — most people have $50-100/month in unused free services.',
    icon: PauseCircle,
    color: 'green'
  },
  {
    number: '04',
    title: 'Pause or Optimize',
    description: 'Choose to pause subscriptions instead of canceling, or switch to free alternatives. Our one-click actions save you hours of customer service calls.',
    icon: TrendingDown,
    color: 'orange'
  }
]

export default function HowItWorks() {
  const sectionRef = useRef<HTMLDivElement>(null)
  const [activeStep, setActiveStep] = useState(0)

  useEffect(() => {
    const handleScroll = () => {
      if (!sectionRef.current) return
      
      const rect = sectionRef.current.getBoundingClientRect()
      const sectionHeight = rect.height
      const scrolled = -rect.top
      const viewportHeight = window.innerHeight
      
      // Calculate progress through section
      const scrollProgress = Math.max(0, Math.min(1, scrolled / (sectionHeight - viewportHeight)))
      
      // Determine active step based on scroll
      const stepIndex = Math.min(3, Math.floor(scrollProgress * 4))
      setActiveStep(stepIndex)
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  const colorClasses: Record<string, string> = {
    blue: 'bg-blue-500 text-blue-400',
    purple: 'bg-purple-500 text-purple-400',
    green: 'bg-green-500 text-green-400',
    orange: 'bg-orange-500 text-orange-400'
  }

  return (
    <section 
      id="how-it-works" 
      ref={sectionRef}
      className="relative bg-black"
      style={{ height: '300vh' }}
    >
      <div className="sticky top-0 h-screen flex items-center overflow-hidden">
        <div className="container">
          <div className="grid lg:grid-cols-2 gap-16 items-center">
            {/* Left Side - Steps */}
            <div className="space-y-8">
              <div className="mb-12">
                <p className="caption mb-4">How It Works</p>
                <h2 className="headline-medium">
                  Save money in{' '}
                  <span className="gradient-text">four simple steps.</span>
                </h2>
              </div>

              <div className="space-y-6">
                {steps.map((step, index) => {
                  const isActive = index === activeStep
                  const isPast = index < activeStep

                  return (
                    <div
                      key={index}
                      className={`relative pl-8 transition-all duration-500 ${
                        isActive ? 'opacity-100' : 'opacity-40'
                      }`}
                    >
                      {/* Progress Line */}
                      {index < steps.length - 1 && (
                        <div 
                          className="absolute left-[11px] top-10 w-[2px] h-full bg-white/10"
                          style={{
                            background: isPast 
                              ? 'linear-gradient(to bottom, rgba(255,255,255,0.3), rgba(255,255,255,0.3))' 
                              : 'linear-gradient(to bottom, rgba(255,255,255,0.3), rgba(255,255,255,0.1))'
                          }}
                        />
                      )}

                      {/* Step Number */}
                      <div 
                        className={`absolute left-0 top-0 w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold transition-all duration-500 ${
                          isActive || isPast
                            ? colorClasses[step.color].split(' ')[0]
                            : 'bg-white/10'
                        }`}
                      >
                        {isPast ? '✓' : step.number}
                      </div>

                      <div className="pb-8">
                        <h3 className={`text-xl font-semibold mb-2 transition-colors duration-300 ${
                          isActive ? 'text-white' : 'text-white/60'
                        }`}>
                          {step.title}
                        </h3>
                        <p className={`text-sm leading-relaxed transition-all duration-500 ${
                          isActive ? 'text-white/70 max-h-40' : 'text-white/40 max-h-0 overflow-hidden'
                        }`}>
                          {step.description}
                        </p>
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>

            {/* Right Side - Visual */}
            <div className="relative hidden lg:block">
              <div className="relative aspect-square max-w-lg mx-auto">
                {/* Background Glow */}
                <div 
                  className="absolute inset-0 rounded-full opacity-30 blur-3xl transition-colors duration-700"
                  style={{
                    background: `radial-gradient(circle, ${
                      activeStep === 0 ? 'rgba(0,122,255,0.4)' :
                      activeStep === 1 ? 'rgba(175,82,222,0.4)' :
                      activeStep === 2 ? 'rgba(52,199,89,0.4)' :
                      'rgba(255,149,0,0.4)'
                    }}, transparent 70%)`
                  }}
                />

                {/* Central Icon */}
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="relative w-64 h-64">
                    {steps.map((step, index) => {
                      const Icon = step.icon
                      const isActive = index === activeStep

                      return (
                        <div
                          key={index}
                          className={`absolute inset-0 flex items-center justify-center transition-all duration-700 ${
                            isActive ? 'opacity-100 scale-100' : 'opacity-0 scale-75'
                          }`}
                        >
                          <div className={`w-48 h-48 rounded-3xl bg-gradient-to-br ${
                            index === 0 ? 'from-blue-500/20 to-cyan-500/20' :
                            index === 1 ? 'from-purple-500/20 to-pink-500/20' :
                            index === 2 ? 'from-green-500/20 to-emerald-500/20' :
                            'from-orange-500/20 to-amber-500/20'
                          } backdrop-blur-xl border border-white/10 flex items-center justify-center`}
                          >
                            <Icon className={`w-24 h-24 ${
                              index === 0 ? 'text-blue-400' :
                              index === 1 ? 'text-purple-400' :
                              index === 2 ? 'text-green-400' :
                              'text-orange-400'
                            }`} />
                          </div>
                        </div>
                      )
                    })}
                  </div>
                </div>

                {/* Orbiting Elements */}
                <div 
                  className="absolute inset-0 animate-spin"
                  style={{ animationDuration: '20s' }}
                >
                  {[0, 1, 2, 3].map((i) => (
                    <div
                      key={i}
                      className="absolute w-4 h-4 rounded-full bg-white/20"
                      style={{
                        top: `${50 + 40 * Math.sin((i * Math.PI) / 2)}%`,
                        left: `${50 + 40 * Math.cos((i * Math.PI) / 2)}%`,
                        transform: 'translate(-50%, -50%)'
                      }}
                    />
                  ))}
                </div>
              </div>

              {/* Progress Indicator */}
              <div className="absolute bottom-0 left-1/2 -translate-x-1/2 flex items-center gap-2">
                {steps.map((_, index) => (
                  <div
                    key={index}
                    className={`w-2 h-2 rounded-full transition-all duration-300 ${
                      index === activeStep ? 'w-8 bg-white' : 'bg-white/20'
                    }`}
                  />
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
