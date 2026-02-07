import { useEffect, useRef, useState } from 'react'
import { 
  Wallet, 
  Gift, 
  PauseCircle, 
  TrendingUp, 
  Shield, 
  Zap,
  ArrowUpRight
} from 'lucide-react'

const features = [
  {
    icon: Wallet,
    title: 'Smart Subscription Tracking',
    description: 'Automatically detects all your recurring charges from bank accounts and credit cards.',
    color: 'from-blue-500 to-cyan-500',
    bgColor: 'bg-blue-500/10',
    iconColor: 'text-blue-400',
    stat: '100%',
    statLabel: 'Auto-detected'
  },
  {
    icon: Gift,
    title: 'Free Perk Discovery',
    description: 'Uncovers $50-100/month in free subscriptions you already have access to.',
    color: 'from-purple-500 to-pink-500',
    bgColor: 'bg-purple-500/10',
    iconColor: 'text-purple-400',
    stat: '$127',
    statLabel: 'Avg savings'
  },
  {
    icon: PauseCircle,
    title: "Pause, Don't Cancel",
    description: 'Pause subscriptions instead of canceling. Keep your data and resume anytime.',
    color: 'from-orange-500 to-amber-500',
    bgColor: 'bg-orange-500/10',
    iconColor: 'text-orange-400',
    stat: '60+',
    statLabel: 'Services'
  },
  {
    icon: TrendingUp,
    title: 'True Cost Analysis',
    description: 'See cost per hour of usage. "Netflix - $8/hour" reveals real value.',
    color: 'from-green-500 to-emerald-500',
    bgColor: 'bg-green-500/10',
    iconColor: 'text-green-400',
    stat: '3x',
    statLabel: 'More accurate'
  },
  {
    icon: Shield,
    title: 'Bank-Level Security',
    description: 'AES-256 encryption. We use Plaid. Never store your login credentials.',
    color: 'from-red-500 to-rose-500',
    bgColor: 'bg-red-500/10',
    iconColor: 'text-red-400',
    stat: 'SOC2',
    statLabel: 'Compliant'
  },
  {
    icon: Zap,
    title: 'AI-Powered Insights',
    description: 'Machine learning analyzes patterns and suggests personalized optimizations.',
    color: 'from-violet-500 to-purple-500',
    bgColor: 'bg-violet-500/10',
    iconColor: 'text-violet-400',
    stat: '24/7',
    statLabel: 'Monitoring'
  }
]

export default function Features() {
  const sectionRef = useRef<HTMLDivElement>(null)
  const [visibleCards, setVisibleCards] = useState<Set<number>>(new Set())

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const index = parseInt(entry.target.getAttribute('data-index') || '0')
            setVisibleCards((prev) => new Set([...prev, index]))
          }
        })
      },
      { threshold: 0.1, rootMargin: '-50px' }
    )

    const cards = sectionRef.current?.querySelectorAll('.feature-card')
    cards?.forEach((card) => observer.observe(card))

    return () => observer.disconnect()
  }, [])

  return (
    <section id="features" ref={sectionRef} className="section bg-black">
      <div className="container">
        {/* Section Header */}
        <div className="text-center max-w-4xl mx-auto mb-12 md:mb-20">
          <p className="caption mb-4 md:mb-6">Features</p>
          <h2 className="headline-medium mb-6 md:mb-8">
            Everything you need to{' '}
            <span className="gradient-text">optimize your subscriptions.</span>
          </h2>
          <p className="body-large text-lg md:text-xl px-4">
            Powerful tools that work together to save you money without the hassle of canceling everything.
          </p>
        </div>

        {/* Features Grid - Mobile: 1 col, Tablet: 2 col, Desktop: 3 col */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6">
          {features.map((feature, index) => {
            const Icon = feature.icon
            const isVisible = visibleCards.has(index)

            return (
              <div
                key={index}
                data-index={index}
                className={`feature-card group relative overflow-hidden rounded-2xl md:rounded-3xl bg-gradient-to-br from-[#1c1c1e] to-[#161618] border border-white/[0.06] p-6 md:p-8 lg:p-10 transition-all duration-700 hover:border-white/[0.12] ${
                  isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
                }`}
                style={{ transitionDelay: `${index * 80}ms` }}
              >
                {/* Background Gradient on Hover */}
                <div 
                  className={`absolute inset-0 bg-gradient-to-br ${feature.color} opacity-0 group-hover:opacity-5 transition-opacity duration-500`} 
                />

                {/* Icon */}
                <div className={`relative w-12 h-12 md:w-14 md:h-14 rounded-xl md:rounded-2xl ${feature.bgColor} flex items-center justify-center mb-5 md:mb-6`}>
                  <Icon className={`w-6 h-6 md:w-7 md:h-7 ${feature.iconColor}`} />
                </div>

                {/* Content */}
                <h3 className="text-lg md:text-xl lg:text-2xl font-semibold mb-2 md:mb-3 text-white">
                  {feature.title}
                </h3>
                
                <p className="text-white/60 text-sm md:text-base leading-relaxed mb-4 md:mb-6">
                  {feature.description}
                </p>

                {/* Stats */}
                <div className="flex items-center justify-between pt-4 md:pt-6 border-t border-white/5">
                  <div>
                    <p className="text-2xl md:text-3xl font-bold text-white">{feature.stat}</p>
                    <p className="text-xs md:text-sm text-white/40 mt-0.5">{feature.statLabel}</p>
                  </div>
                  <div className="w-10 h-10 md:w-12 md:h-12 rounded-full bg-white/5 flex items-center justify-center group-hover:bg-white/10 transition-colors">
                    <ArrowUpRight className="w-5 h-5 md:w-6 md:h-6 text-white/40 group-hover:text-white transition-colors" />
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        {/* Bottom CTA */}
        <div className="mt-16 md:mt-20 text-center">
          <p className="text-white/60 mb-6 text-base md:text-lg">Ready to see all your subscriptions in one place?</p>
          <a
            href="#cta"
            className="btn-primary inline-flex items-center gap-2 text-base md:text-lg px-8 md:px-10 py-3.5 md:py-4"
            onClick={(e) => {
              e.preventDefault()
              document.querySelector('#cta')?.scrollIntoView({ behavior: 'smooth' })
            }}
          >
            Get Started Free
            <ArrowUpRight className="w-4 h-4 md:w-5 md:h-5" />
          </a>
        </div>
      </div>
    </section>
  )
}
