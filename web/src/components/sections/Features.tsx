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
    description: 'Automatically detects all your recurring charges from bank accounts and credit cards. No manual entry needed.',
    color: 'from-blue-500 to-cyan-500',
    stat: '100%',
    statLabel: 'Auto-detected'
  },
  {
    icon: Gift,
    title: 'Free Perk Discovery',
    description: 'Uncovers $50-100/month in free subscriptions you already have access to through credit cards, employers, and libraries.',
    color: 'from-purple-500 to-pink-500',
    stat: '$127',
    statLabel: 'Avg savings/month'
  },
  {
    icon: PauseCircle,
    title: "Pause, Don't Cancel",
    description: 'Many services let you pause instead of cancel. We find which ones and provide direct links to pause instantly.',
    color: 'from-orange-500 to-amber-500',
    stat: '60+',
    statLabel: 'Services supported'
  },
  {
    icon: TrendingUp,
    title: 'True Cost Analysis',
    description: 'See cost per hour of usage instead of monthly fees. "Netflix - $8/hour" reveals the real value.',
    color: 'from-green-500 to-emerald-500',
    stat: '3x',
    statLabel: 'More accurate'
  },
  {
    icon: Shield,
    title: 'Bank-Level Security',
    description: 'Your data is encrypted with AES-256. We use Plaid for secure bank connections. Never store your login credentials.',
    color: 'from-red-500 to-rose-500',
    stat: 'SOC2',
    statLabel: 'Compliant'
  },
  {
    icon: Zap,
    title: 'AI-Powered Insights',
    description: 'Machine learning analyzes your spending patterns and suggests optimizations tailored specifically to you.',
    color: 'from-violet-500 to-purple-500',
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
      { threshold: 0.2, rootMargin: '-50px' }
    )

    const cards = sectionRef.current?.querySelectorAll('.feature-card')
    cards?.forEach((card) => observer.observe(card))

    return () => observer.disconnect()
  }, [])

  return (
    <section id="features" ref={sectionRef} className="section bg-black">
      <div className="container">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <p className="caption mb-4">Features</p>
          <h2 className="headline-medium mb-6">
            Everything you need to{' '}
            <span className="gradient-text">optimize your subscriptions.</span>
          </h2>
          <p className="body-large">
            Powerful tools that work together to save you money without the hassle of canceling everything.
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid grid-3 gap-6">
          {features.map((feature, index) => {
            const Icon = feature.icon
            const isVisible = visibleCards.has(index)

            return (
              <div
                key={index}
                data-index={index}
                className={`feature-card group relative overflow-hidden rounded-3xl bg-gradient-to-br from-[#1c1c1e] to-[#161618] border border-white/5 p-8 transition-all duration-700 ${
                  isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'
                }`}
                style={{ transitionDelay: `${index * 100}ms` }}
              >
                {/* Background Gradient on Hover */}
                <div 
                  className={`absolute inset-0 bg-gradient-to-br ${feature.color} opacity-0 group-hover:opacity-10 transition-opacity duration-500`} 
                />

                {/* Icon */}
                <div className={`relative w-14 h-14 rounded-2xl bg-gradient-to-br ${feature.color} p-[1px] mb-6`}>
                  <div className="w-full h-full rounded-2xl bg-[#1c1c1e] flex items-center justify-center">
                    <Icon className="w-7 h-7 text-white" />
                  </div>
                </div>

                {/* Content */}
                <h3 className="text-xl font-semibold mb-3 text-white group-hover:text-white transition-colors">
                  {feature.title}
                </h3>
                
                <p className="text-white/60 text-sm leading-relaxed mb-6">
                  {feature.description}
                </p>

                {/* Stats */}
                <div className="flex items-center justify-between pt-4 border-t border-white/5">
                  <div>
                    <p className="text-2xl font-bold text-white">{feature.stat}</p>
                    <p className="text-xs text-white/40">{feature.statLabel}</p>
                  </div>
                  <div className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center group-hover:bg-white/10 transition-colors">
                    <ArrowUpRight className="w-5 h-5 text-white/40 group-hover:text-white transition-colors" />
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        {/* Bottom CTA */}
        <div className="mt-20 text-center">
          <p className="text-white/60 mb-6">Ready to see all your subscriptions in one place?</p>
          <a
            href="#cta"
            className="btn-primary inline-flex items-center gap-2"
            onClick={(e) => {
              e.preventDefault()
              document.querySelector('#cta')?.scrollIntoView({ behavior: 'smooth' })
            }}
          >
            Get Started Free
            <ArrowUpRight className="w-5 h-5" />
          </a>
        </div>
      </div>
    </section>
  )
}
