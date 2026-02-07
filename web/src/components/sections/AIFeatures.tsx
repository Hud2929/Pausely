import { useEffect, useRef, useState } from 'react'
import { Bot, PauseCircle, Mail, Sparkles } from 'lucide-react'

const aiFeatures = [
  {
    icon: Bot,
    title: 'AI Cancellation Agent',
    description: 'Our AI drafts cancellation emails and negotiates retention offers for you. No more awkward phone calls.',
    color: 'from-purple-500 to-pink-500',
    bgColor: 'bg-purple-500/10',
    iconColor: 'text-purple-400',
  },
  {
    icon: PauseCircle,
    title: 'AI Smart Pausing',
    description: 'Detects unused subscriptions and suggests pausing them. Automatically tracks your usage patterns.',
    color: 'from-blue-500 to-cyan-500',
    bgColor: 'bg-blue-500/10',
    iconColor: 'text-blue-400',
  },
  {
    icon: Mail,
    title: 'AI Daily Briefing',
    description: 'Morning email with personalized insights. Know exactly what you saved and what to optimize next.',
    color: 'from-orange-500 to-amber-500',
    bgColor: 'bg-orange-500/10',
    iconColor: 'text-orange-400',
  },
]

export default function AIFeatures() {
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

    const cards = sectionRef.current?.querySelectorAll('.ai-feature-card')
    cards?.forEach((card) => observer.observe(card))

    return () => observer.disconnect()
  }, [])

  return (
    <section ref={sectionRef} className="section">
      <div className="container">
        {/* Header */}
        <div className="text-center max-w-2xl mx-auto mb-20">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass mb-8">
            <Sparkles className="w-4 h-4 text-purple-400" />
            <span className="text-sm text-purple-400 font-medium">Powered by AI</span>
          </div>
          
          <h2 className="headline-medium mb-6">
            Three AI agents.
            <br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-purple-400 via-pink-400 to-orange-400">Zero effort.</span>
          </h2>
          
          <p className="body-large">
            Our AI handles the hard work. You just approve.
          </p>
        </div>

        {/* AI Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-5xl mx-auto">
          {aiFeatures.map((feature, index) => {
            const Icon = feature.icon
            const isVisible = visibleCards.has(index)

            return (
              <div
                key={index}
                data-index={index}
                className={`ai-feature-card group relative overflow-hidden rounded-3xl glass p-10 transition-all duration-700 ${
                  isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-12'
                }`}
                style={{ transitionDelay: `${index * 150}ms` }}
              >
                {/* Gradient Glow */}
                <div 
                  className={`absolute -top-20 -right-20 w-40 h-40 rounded-full bg-gradient-to-br ${feature.color} opacity-20 blur-3xl group-hover:opacity-30 transition-opacity`} 
                />

                {/* Icon */}
                <div className={`relative w-16 h-16 rounded-2xl ${feature.bgColor} flex items-center justify-center mb-8`}>
                  <Icon className={`w-8 h-8 ${feature.iconColor}`} />
                </div>

                {/* Content */}
                <h3 className="text-2xl font-semibold mb-4 relative">{feature.title}</h3>
                
                <p className="text-white/50 text-lg leading-relaxed relative">
                  {feature.description}
                </p>

                {/* Feature Number */}
                <div className="absolute top-8 right-8 text-6xl font-bold text-white/5">
                  0{index + 1}
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
