import { useEffect, useRef, useState } from 'react'
import { Wallet, Gift, PauseCircle, Shield, Zap, ArrowUpRight } from 'lucide-react'

const features = [
  {
    icon: Wallet,
    title: 'Track Everything',
    description: 'Automatically finds all your subscriptions.',
    color: 'text-blue-400',
    bgColor: 'bg-blue-400/10',
  },
  {
    icon: Gift,
    title: 'Find Free Perks',
    description: 'Discover $50-100/month in unused benefits.',
    color: 'text-purple-400',
    bgColor: 'bg-purple-400/10',
  },
  {
    icon: PauseCircle,
    title: 'Pause, Not Cancel',
    description: 'Keep your data. Resume anytime.',
    color: 'text-orange-400',
    bgColor: 'bg-orange-400/10',
  },
  {
    icon: Shield,
    title: 'Bank-Level Security',
    description: 'Your data is encrypted and secure.',
    color: 'text-green-400',
    bgColor: 'bg-green-400/10',
  },
  {
    icon: Zap,
    title: 'AI Insights',
    description: 'Smart recommendations just for you.',
    color: 'text-pink-400',
    bgColor: 'bg-pink-400/10',
  },
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
      { threshold: 0.1 }
    )

    const cards = sectionRef.current?.querySelectorAll('.feature-card')
    cards?.forEach((card) => observer.observe(card))

    return () => observer.disconnect()
  }, [])

  return (
    <section id="features" ref={sectionRef} className="section">
      <div className="container">
        {/* Header */}
        <div className="text-center max-w-2xl mx-auto mb-20">
          <p className="caption mb-4">Features</p>
          <h2 className="headline-medium mb-6">
            Everything you need.
          </h2>
        </div>

        {/* Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, index) => {
            const Icon = feature.icon
            const isVisible = visibleCards.has(index)

            return (
              <div
                key={index}
                data-index={index}
                className={`feature-card group p-8 rounded-3xl bg-[#0c0c0e] transition-all duration-700 ${
                  isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
                }`}
                style={{ transitionDelay: `${index * 100}ms` }}
              >
                {/* Icon */}
                <div className={`w-12 h-12 rounded-2xl ${feature.bgColor} flex items-center justify-center mb-6`}>
                  <Icon className={`w-6 h-6 ${feature.color}`} />
                </div>

                {/* Content */}
                <h3 className="text-xl font-semibold mb-2">{feature.title}</h3>
                <p className="text-white/50">{feature.description}</p>

                {/* Arrow */}
                <div className="mt-6 w-10 h-10 rounded-full bg-white/5 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                  <ArrowUpRight className="w-5 h-5 text-white/70" />
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
