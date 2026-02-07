import { useEffect, useRef, useState } from 'react'
import { 
  Wallet, 
  Gift, 
  PauseCircle, 
  Shield, 
  Zap, 
  ArrowUpRight 
} from 'lucide-react'

const features = [
  {
    icon: Wallet,
    title: 'Track Everything',
    description: 'Easily add and manage all your subscriptions in one place.',
    color: 'text-blue-400',
    bgColor: 'bg-blue-400/10',
  },
  {
    icon: Gift,
    title: 'Find Free Perks',
    description: 'Discover $50-100/month in unused benefits you already have.',
    color: 'text-purple-400',
    bgColor: 'bg-purple-400/10',
  },
  {
    icon: PauseCircle,
    title: 'Pause, Not Cancel',
    description: 'Keep your data and history. Resume anytime with one click.',
    color: 'text-orange-400',
    bgColor: 'bg-orange-400/10',
  },
  {
    icon: Shield,
    title: 'Privacy First',
    description: 'Your data stays private. No bank connections required.',
    color: 'text-green-400',
    bgColor: 'bg-green-400/10',
  },
  {
    icon: Zap,
    title: 'AI Insights',
    description: 'Smart recommendations personalized just for you.',
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
      { threshold: 0.1, rootMargin: '50px' }
    )

    const cards = sectionRef.current?.querySelectorAll('.feature-card')
    cards?.forEach((card) => observer.observe(card))

    return () => observer.disconnect()
  }, [])

  return (
    <section id="features" ref={sectionRef} className="section">
      <div className="container">
        {/* Header */}
        <div className="text-center max-w-2xl mx-auto mb-24">
          <p className="caption mb-6">Features</p>
          <h2 className="headline-medium mb-8">
            Everything you need.
          </h2>
          <p className="body-large">
            Five powerful tools to optimize your subscriptions.
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, index) => {
            const Icon = feature.icon
            const isVisible = visibleCards.has(index)

            return (
              <div
                key={index}
                data-index={index}
                className={`feature-card group p-10 rounded-3xl glass transition-all duration-700 ${
                  isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
                }`}
                style={{ transitionDelay: `${index * 100}ms` }}
              >
                {/* Icon */}
                <div className={`w-14 h-14 rounded-2xl ${feature.bgColor} flex items-center justify-center mb-8`}>
                  <Icon className={`w-7 h-7 ${feature.color}`} />
                </div>

                {/* Content */}
                <h3 className="text-2xl font-semibold mb-3">{feature.title}</h3>
                <p className="text-white/50 text-lg leading-relaxed mb-8">{feature.description}</p>

                {/* Arrow */}
                <div className="w-12 h-12 rounded-full bg-white/5 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all group-hover:bg-white/10">
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
